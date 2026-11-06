import assert from "node:assert/strict";
import test from "node:test";

import { AGENTS } from "./eval-lib.mjs";

// parseStreamJson is not exported; both agents reach it through AGENTS.parse.
const parse = AGENTS.claude.parse;

/** Deterministic PRNG (mulberry32) so the corpus is reproducible. */
function mulberry32(seed) {
	return () => {
		seed |= 0;
		seed = (seed + 0x6d2b79f5) | 0;
		let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

const CHARS = "abcXYZ0123 ,.;:'\"[]{}-_=+/\\";

/** A short string mixing ASCII, unicode and NUL (escaped in the source). */
function randomString(rng) {
	let s = "";
	const n = Math.floor(rng() * 24);
	for (let i = 0; i < n; i++) {
		const pick = rng();
		if (pick < 0.04) s += "\u0000";
		else if (pick < 0.08) s += "\u03b1\u03b2\u03b3\u4e2d\u6587"[Math.floor(rng() * 5)];
		else s += CHARS[Math.floor(rng() * CHARS.length)];
	}
	return s;
}

/** A random JSON-safe value, nested up to depth levels. */
function randomJsonValue(rng, depth) {
	if (depth <= 0) {
		const pick = rng();
		if (pick < 0.2) return null;
		if (pick < 0.4) return rng() < 0.5;
		if (pick < 0.7) return Math.floor(rng() * 1e6) - 5e5;
		return randomString(rng);
	}
	switch (Math.floor(rng() * 6)) {
		case 0:
			return null;
		case 1:
			return rng() < 0.5;
		case 2:
			return Math.floor(rng() * 1e6) - 5e5;
		case 3:
			return randomString(rng);
		case 4: {
			const arr = [];
			for (let i = 0, n = Math.floor(rng() * 5); i < n; i++) arr.push(randomJsonValue(rng, depth - 1));
			return arr;
		}
		default: {
			const obj = {};
			for (let i = 0, n = Math.floor(rng() * 5); i < n; i++) {
				obj["k" + i + randomString(rng)] = randomJsonValue(rng, depth - 1);
			}
			return obj;
		}
	}
}

/** A random JSON object with at least one key. */
function randomObject(rng, depth) {
	const obj = {};
	for (let i = 0, n = 1 + Math.floor(rng() * 4); i < n; i++) obj["k" + i] = randomJsonValue(rng, depth);
	return obj;
}

/** A random JSON array with at least one element. */
function randomArray(rng, depth) {
	const arr = [];
	for (let i = 0, n = 1 + Math.floor(rng() * 4); i < n; i++) arr.push(randomJsonValue(rng, depth));
	return arr;
}

/** A random plain-text line that is not valid JSON. */
function randomPlainText(rng) {
	const chars = "plain text lorem ipsum 123 \u0000 \u03b1\u4e2d";
	let s = "";
	for (let i = 0, n = Math.floor(rng() * 30); i < n; i++) s += chars[Math.floor(rng() * chars.length)];
	return s;
}

/** A random NDJSON-ish line of one of the kinds parseStreamJson can meet. */
function randomLine(rng, depth) {
	switch (Math.floor(rng() * 8)) {
		// Valid JSON object: kept.
		case 0:
			return JSON.stringify(randomObject(rng, depth));
		// Valid JSON array: dropped (starts with "[").
		case 1:
			return JSON.stringify(randomArray(rng, depth));
		// Valid JSON string: dropped.
		case 2:
			return JSON.stringify(randomString(rng));
		// Valid JSON number: dropped.
		case 3:
			return String(Math.floor(rng() * 1e9) - 5e8);
		// Plain text: dropped.
		case 4:
			return randomPlainText(rng);
		// Truncated JSON object: starts with "{", does not parse.
		case 5:
			return JSON.stringify(randomObject(rng, depth)).slice(0, Math.floor(rng() * 8));
		// Invalid "{" line: starts with "{", does not parse.
		case 6:
			return "{" + randomPlainText(rng) + "}";
		// Empty line: dropped.
		default:
			return "";
	}
}

/** A random NDJSON-ish text: a handful of lines, some with surrounding space. */
function randomText(rng) {
	const lines = [];
	for (let i = 0, n = 1 + Math.floor(rng() * 12); i < n; i++) {
		let line = randomLine(rng, 1 + Math.floor(rng() * 6));
		if (rng() < 0.3) line = "  " + line + " \t";
		lines.push(line);
	}
	return lines.join("\n");
}

/** A genuinely deeply nested object. */
function deepObject(depth) {
	let v = 0;
	for (let i = 0; i < depth; i++) v = { a: v };
	return v;
}

const EDGE_INPUTS = [
	"",
	"\n\n\n",
	"{",
	"}",
	"{}",
	"{}\n{}\n{}",
	'{"a":1}\nplain\n[1,2]\n"str"\n42',
	'  {"spaced": true}  ',
	'{"nul":"\u0000"}',
	"\u0000",
	'{"broken":',
	JSON.stringify(deepObject(64)),
];

test("parseStreamJson property: no panic, round trip, order, capture rule", () => {
	const rng = mulberry32(0x5eed);
	const inputs = EDGE_INPUTS.slice();
	for (let i = 0; i < 2000; i++) inputs.push(randomText(rng));

	for (const text of inputs) {
		// Invariant 1: no panic, always an array.
		const events = parse(text);
		assert.ok(Array.isArray(events));

		// Invariant 3: capture rule. Kept events are exactly the lines that start
		// with "{" after trim and parse as JSON, in stream order.
		const expected = [];
		for (const raw of text.split("\n")) {
			const line = raw.trim();
			if (!line.startsWith("{")) continue;
			try {
				expected.push(JSON.parse(line));
			} catch {
				// Invalid "{" line: dropped.
			}
		}
		assert.deepStrictEqual(events, expected);

		// Invariant 2: round trip and order.
		const reserialized = events.map((e) => JSON.stringify(e)).join("\n");
		assert.deepStrictEqual(parse(reserialized), events);
	}
});