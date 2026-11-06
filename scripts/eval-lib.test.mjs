/**
 * Property tests for redact() in eval-lib.mjs.
 *
 * redact is applied to everything that leaves the harness (eval.mjs and
 * record-demos.mjs feed the public marketing pages), so a regex drift leaks
 * machine- or account-specific data. Line 185 holds a raw NUL byte in the
 * HOME fallback (tracked as K-ff1477): these tests set or delete
 * process.env.HOME explicitly and never depend on the fallback's content.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { redact } from "./eval-lib.mjs";

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

// No /g flag: assert.doesNotMatch with a sticky-state regex silently skips
// matches from the second call on (lastIndex carries over between inputs).
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i;
const VTX_RE = /\bvtx_[A-Za-z0-9_-]{8,}/;

const HEX = "0123456789abcdefABCDEF";
const VTX_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
const VALUE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-";
const NOISE = "abcXYZ0123 ,.;:'\"[]{}-_=+/\\\t\n";
const UNICODE = ["\u03b1", "\u4e2d", "\u00e9", "\u0000", "\u2028", "\u00ff"];

function pick(rnd, pool) {
	return pool[Math.floor(rnd() * pool.length)];
}

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
		if (rnd() < 0.3) s += pick(rnd, UNICODE);
		else s += NOISE[Math.floor(rnd() * NOISE.length)];
	}
	return s;
}

/** A text mixing sensitive material, the live HOME value, and noise. */
function generateInput(rnd, home) {
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
const EDGE_INPUTS = [
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

	const inputs = EDGE_INPUTS.slice();
	const rnd = mulberry32(0xd4a7);
	for (let i = 0; i < 2000; i++) inputs.push(generateInput(rnd, HOME));

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

	if (savedHome === undefined) delete process.env.HOME;
	else process.env.HOME = savedHome;
});