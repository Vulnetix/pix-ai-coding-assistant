/**
 * Property tests for the pure helpers in eval-lib.mjs.
 *
 * Each block asserts invariants that a regex or parser drift would silently
 * break, over a fixed-seed corpus so any failure reproduces:
 *
 * - parseStreamJson (via AGENTS.<agent>.parse) turns the agents' NDJSON
 *   streams into events for every layer-2 and layer-3 assertion.
 * - advisoryIds powers the corpus gate (eval.mjs layer 1) and the layer-3
 *   hallucination check.
 * - redact is applied to everything that leaves the harness (eval.mjs and
 *   record-demos.mjs feed the public marketing pages), so a drift leaks
 *   machine- or account-specific data.
 *
 * Run with `just test`.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { AGENTS, advisoryIds, redact } from "./eval-lib.mjs";

/** Seeded PRNG (mulberry32) so failures reproduce with a fixed seed. */
function mulberry32(seed) {
	let a = seed >>> 0;
	return function () {
		a |= 0;
		a = (a + 0x6d2b79f5) | 0;
		let t = Math.imul(a ^ (a >>> 15), 1 | a);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

function pick(rnd, pool) {
	return pool[Math.floor(rnd() * pool.length)];
}

// ---------------------------------------------------------------------------
// parseStreamJson
// ---------------------------------------------------------------------------

// parseStreamJson is not exported; both agents reach it through AGENTS.parse.
const parse = AGENTS.claude.parse;
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

const PARSE_EDGE_INPUTS = [
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
	const inputs = PARSE_EDGE_INPUTS.slice();
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
// ---------------------------------------------------------------------------
// advisoryIds
// ---------------------------------------------------------------------------

const ID_RE =
	/^(CVE-\d{4}-\d{4,}|GHSA-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4})$/;

const FIXED_IDS = [
	"CVE-2021-44228",
	"cve-2021-44228",
	"Cve-2021-44228",
	"GHSA-j488-84xf-5m02",
	"ghsa-j488-84xf-5m02",
	"Ghsa-J488-84xf-5m02",
	"GHSA-J488-84XF-5M02",
];

/** Look-alikes that must NOT match: truncated or malformed ids. */
const ADVISORY_NOISE = [
	"CVE",
	"GHSA",
	"CVE-2021",
	"CVE-2021-44",
	"CVE-2021-999999999",
	"GHSA-j488",
	"GHSA-j488-84xf",
	"GHSA-1234-ABC-5678",
	"44228",
	"j488",
	"84xf",
	"5m02",
	"log4j",
	"exploit",
	"vulnerability",
	"advisory",
	"fix",
];

const ADVISORY_UNICODE = [
	"\u0000",
	"\u0001",
	"\u0007",
	"\u00ff",
	"\u2028",
	"\u2029",
	"\ufeff",
	"é",
	"ñ",
	"Σ",
	"中",
	"日本語",
	"🚀",
	"π",
];

const WHITESPACE = [
	" ",
	"  ",
	"\t",
	"\n",
	"\r",
	"\v",
	"\f",
	" \t ",
	"\r\n",
	"\t\t",
];

const QUOTES = [
	"\"",
	"'",
	"`",
	"(",
	")",
	"[",
	"]",
	"{",
	"}",
	"<",
	">",
	":",
	";",
	",",
	".",
	"!",
	"?",
	"-",
	"_",
	"=",
	"+",
	"/",
	"\\",
	"|",
	"&",
	"%",
	"$",
	"#",
	"@",
	"~",
	"^",
	"*",
];

const GHSA_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

/** A syntactically valid CVE or GHSA id, sometimes lowercased. */
function randomId(rnd) {
	if (rnd() < 0.5) {
		const year = 1900 + Math.floor(rnd() * 200);
		const digits = 4 + Math.floor(rnd() * 8);
		let id = `CVE-${year}-`;
		for (let i = 0; i < digits; i++) {
			id += Math.floor(rnd() * 10);
		}
		return rnd() < 0.5 ? id : id.toLowerCase();
	}
	let id = "GHSA-";
	for (let i = 0; i < 3; i++) {
		if (i > 0) {
			id += "-";
		}
		for (let j = 0; j < 4; j++) {
			id += GHSA_CHARS[Math.floor(rnd() * GHSA_CHARS.length)];
		}
	}
	return rnd() < 0.5 ? id : id.toLowerCase();
}

/** Random free text: ids, look-alikes, unicode, whitespace and quotes. */
function generateAdvisoryInput(rnd) {
	const tokens = [];
	const n = 1 + Math.floor(rnd() * 30);
	for (let i = 0; i < n; i++) {
		const roll = rnd();
		if (roll < 0.25) {
			tokens.push(pick(rnd, FIXED_IDS));
		} else if (roll < 0.5) {
			tokens.push(randomId(rnd));
		} else if (roll < 0.65) {
			tokens.push(pick(rnd, ADVISORY_NOISE));
		} else if (roll < 0.75) {
			tokens.push(pick(rnd, ADVISORY_UNICODE));
		} else if (roll < 0.9) {
			tokens.push(pick(rnd, WHITESPACE));
		} else {
			tokens.push(pick(rnd, QUOTES));
		}
	}
	return tokens.join("");
}

/** Every input class the extractor must survive without throwing. */
const ADVISORY_EDGE_INPUTS = [
	"",
	" ",
	"\t\n",
	"CVE-2021-44228",
	"ghsa-j488-84xf-5m02",
	"CVE-2021-44228 GHSA-J488-84XF-5M02",
	"cve-2021-44228",
	"cVe-2021-44228",
	"*CVE-2021-44228*",
	"prefix CVE-2021-44228 suffix",
	"CVE-2021-44",
	"CVE-2021-44228111",
	"\u0000",
	"é\u0000日本語",
	"CVE-2021-44228\u0000GHSA-j488-84xf-5m02",
	"null",
	null,
	undefined,
	0,
	42,
	NaN,
	{},
	[],
	["CVE-2021-44228"],
];

function sameSet(a, b) {
	if (a.size !== b.size) {
		return false;
	}
	for (const member of a) {
		if (!b.has(member)) {
			return false;
		}
	}
	return true;
}

test("advisoryIds property: no panic, uppercase members, idempotence over seeded inputs", () => {
	const rnd = mulberry32(0xad15e6);

	for (const input of ADVISORY_EDGE_INPUTS) {
		assert.doesNotThrow(() => advisoryIds(input), `no panic for ${String(input)}`);
	}

	for (let i = 0; i < 2000; i++) {
		const input = generateAdvisoryInput(rnd);
		const ids = advisoryIds(input);
		assert.ok(ids instanceof Set, `Set result for input ${JSON.stringify(input)}`);

		for (const id of ids) {
			assert.equal(id, id.toUpperCase(), `uppercase member from input ${JSON.stringify(input)}`);
			assert.match(id, ID_RE, `shape of member ${id} from input ${JSON.stringify(input)}`);
		}

		const rejoined = advisoryIds(Array.from(ids).join(" "));
		assert.ok(
			sameSet(ids, rejoined),
			`idempotence for input ${JSON.stringify(input)}: ${Array.from(ids).join(", ")} vs ${Array.from(rejoined).join(", ")}`,
		);
	}
});
// ---------------------------------------------------------------------------
// redact
//
// The HOME fallback in redact holds a raw NUL byte (tracked as K-ff1477):
// this block sets or deletes process.env.HOME explicitly and never depends
// on the fallback's content.
// ---------------------------------------------------------------------------

// No /g flag: assert.doesNotMatch with a sticky-state regex silently skips
// matches from the second call on (lastIndex carries over between inputs).
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i;
const VTX_RE = /\bvtx_[A-Za-z0-9_-]{8,}/;

const HEX = "0123456789abcdefABCDEF";
const VTX_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
const VALUE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-";
const REDACT_NOISE = "abcXYZ0123 ,.;:'\"[]{}-_=+/\\\t\n";
const REDACT_UNICODE = ["\u03b1", "\u4e2d", "\u00e9", "\u0000", "\u2028", "\u00ff"];

function randomHex(rnd, n) {
	let s = "";
	for (let i = 0; i < n; i++) s += HEX[Math.floor(rnd() * HEX.length)];
	return s;
}

/** A syntactically valid UUID, sometimes uppercase. */
function randomUuid(rnd) {
	const id = `${randomHex(rnd, 8)}-${randomHex(rnd, 4)}-${randomHex(rnd, 4)}-${randomHex(rnd, 4)}-${randomHex(rnd, 12)}`;
	return rnd() < 0.5 ? id.toLowerCase() : id;
}

/** A vtx_ bearer token, 8+ chars after the prefix. */
function randomVtx(rnd) {
	let s = "vtx_";
	for (let i = 0, n = 8 + Math.floor(rnd() * 24); i < n; i++) s += VTX_CHARS[Math.floor(rnd() * VTX_CHARS.length)];
	return s;
}

/** A /home/... or /Users/... path. */
function randomPath(rnd) {
	let p = rnd() < 0.5 ? "/home" : "/Users";
	for (let i = 0, n = 1 + Math.floor(rnd() * 4); i < n; i++) {
		p += "/";
		for (let j = 0, m = 1 + Math.floor(rnd() * 12); j < m; j++) {
			p += "abcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(rnd() * 36)];
		}
	}
	return p;
}

/** An api_key=, token: or secret= style assignment with an 8+ char value. */
function randomAssignment(rnd) {
	const key = pick(rnd, ["api_key", "apikey", "api-key", "token", "secret", "API_KEY", "Token"]);
	const sep = pick(rnd, ["=", ":", " = ", ": ", "==", " : "]);
	let value = "";
	for (let i = 0, n = 8 + Math.floor(rnd() * 24); i < n; i++) value += VALUE_CHARS[Math.floor(rnd() * VALUE_CHARS.length)];
	return key + sep + value;
}

/** Random noise: unicode, NUL, whitespace, quotes and punctuation. */
function randomNoise(rnd) {
	let s = "";
	for (let i = 0, n = Math.floor(rnd() * 16); i < n; i++) {
		if (rnd() < 0.3) s += pick(rnd, REDACT_UNICODE);
		else s += REDACT_NOISE[Math.floor(rnd() * REDACT_NOISE.length)];
	}
	return s;
}

/** A text mixing sensitive material, the live HOME value, and noise. */
function generateRedactInput(rnd, home) {
	const tokens = [];
	for (let i = 0, n = 1 + Math.floor(rnd() * 10); i < n; i++) {
		const roll = rnd();
		if (roll < 0.15) tokens.push(randomUuid(rnd));
		else if (roll < 0.3) tokens.push(randomVtx(rnd));
		else if (roll < 0.45) tokens.push(randomPath(rnd));
		else if (roll < 0.6) tokens.push(randomAssignment(rnd));
		else if (roll < 0.7) tokens.push(home + (rnd() < 0.5 ? "" : "/sub/dir"));
		else tokens.push(randomNoise(rnd));
	}
	return tokens.join(rnd() < 0.5 ? " " : "");
}

/** Every input class redact must survive, with material it must strip. */
const REDACT_EDGE_INPUTS = [
	"",
	" ",
	"\t\n",
	"plain text",
	"deadbeef-dead-beef-dead-beefdeadbeef",
	"DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
	"vtx_abcdefghijklmnop",
	"api_key=supersecretvalue",
	"token = abcdefgh1234",
	"secret: xyz98765",
	"apikey==deadbeef1234",
	"API_KEY=Supersecret123",
	"/home/alice/.ssh/id_rsa",
	"/Users/bob/Downloads/file.txt",
	"/home/alice /Users/bob",
	"uuid deadbeef-dead-beef-dead-beefdeadbeef token vtx_abcdefgh",
	"\u0000",
	"\u03b1\u4e2d\u00e9\u0000\u2028",
	'"quoted" \'single\' `backtick`',
	"api_key='supersecret'",
	'secret = "anothersecret"',
	null,
	undefined,
	0,
	42,
	NaN,
	{},
	[],
	["deadbeef-dead-beef-dead-beefdeadbeef"],
	{ token: "vtx_abcdefghij" },
];

test("redact property: no panic, idempotence, sanitizer contract over seeded inputs", () => {
	const HOME = "/home/vtx-test-user";
	const savedHome = process.env.HOME;

	const inputs = REDACT_EDGE_INPUTS.slice();
	const rnd = mulberry32(0xd4a7);
	for (let i = 0; i < 2000; i++) inputs.push(generateRedactInput(rnd, HOME));

	try {
		for (const mode of ["set", "unset"]) {
			if (mode === "set") process.env.HOME = HOME;
			else delete process.env.HOME;

			for (const text of inputs) {
				// Invariant 1: no panic, and a string result.
				let once;
				assert.doesNotThrow(() => {
					once = redact(text);
				}, `no panic for ${String(text)} (HOME ${mode})`);
				assert.equal(typeof once, "string", `string result for ${String(text)} (HOME ${mode})`);

				// Invariant 3: sanitizer contract.
				assert.doesNotMatch(once, UUID_RE, `no uuid in ${JSON.stringify(once)} (HOME ${mode})`);
				assert.doesNotMatch(once, VTX_RE, `no vtx_ token in ${JSON.stringify(once)} (HOME ${mode})`);

				// Invariant 2: idempotence.
				assert.equal(redact(once), once, `idempotence for ${JSON.stringify(once)} (HOME ${mode})`);
			}
		}
	} finally {
		if (savedHome === undefined) delete process.env.HOME;
		else process.env.HOME = savedHome;
	}
});
