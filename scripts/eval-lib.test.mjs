/**
 * Property tests for the pure extractors in eval-lib.mjs.
 *
 * Each block asserts invariants that a regex drift would silently break:
 * the corpus gate (eval.mjs layer 1) and the layer-3 hallucination check
 * both depend on advisoryIds finding every identifier in free text.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { advisoryIds } from "./eval-lib.mjs";

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
const NOISE = [
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

const UNICODE = [
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

function pick(rnd, pool) {
	return pool[Math.floor(rnd() * pool.length)];
}

/** Random free text: ids, look-alikes, unicode, whitespace and quotes. */
function generateInput(rnd) {
	const tokens = [];
	const n = 1 + Math.floor(rnd() * 30);
	for (let i = 0; i < n; i++) {
		const roll = rnd();
		if (roll < 0.25) {
			tokens.push(pick(rnd, FIXED_IDS));
		} else if (roll < 0.5) {
			tokens.push(randomId(rnd));
		} else if (roll < 0.65) {
			tokens.push(pick(rnd, NOISE));
		} else if (roll < 0.75) {
			tokens.push(pick(rnd, UNICODE));
		} else if (roll < 0.9) {
			tokens.push(pick(rnd, WHITESPACE));
		} else {
			tokens.push(pick(rnd, QUOTES));
		}
	}
	return tokens.join("");
}

/** Every input class the extractor must survive without throwing. */
const EDGE_INPUTS = [
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

	for (const input of EDGE_INPUTS) {
		assert.doesNotThrow(() => advisoryIds(input), `no panic for ${String(input)}`);
	}

	for (let i = 0; i < 2000; i++) {
		const input = generateInput(rnd);
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