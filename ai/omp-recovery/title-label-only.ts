#!/usr/bin/env bun
// Recovery patch for the installed omp bundle: terminal title = session label only.
//
// Stock omp (pi-coding-agent dist/cli.js) writes "π > <label>" (or "π : <label>" when
// working). This patch replaces the single formatter `buildTerminalTitleWithState`
// (minified `jYr` in 19.0.1) so it returns the label, or "omp" before a session exists.
// The run-state separator (spinner, ">", "!") is removed with the brand.
//
// Not part of the standalone installer: it patches a generated Bun bundle, and every
// `omp update` overwrites it. Run it after each update, then restart omp.
//
// Usage (bun):
//   bun ai/omp-recovery/title-label-only.ts --check [cli.js]   report state, change nothing
//   bun ai/omp-recovery/title-label-only.ts --apply [cli.js]   patch if the build matches
//
// Exact delta (single occurrence required):
//   PRISTINE: the full `function jYr(...)` declaration below, byte for byte
//   PATCHED:  the one-line replacement below
// Verified against omp 19.0.1, cli.js sha256 7330ccec0c97f70e920ff056255dab4137e3b02f62cb47a23a8cf062a2f55316.
// Any other build: the script refuses; port the formatter change by hand.

const DEFAULT_PATH = `${process.env.HOME}/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js`;

const PRISTINE =
	'function jYr(e,t,n,r,i=process.platform,o="braille",s=Pe,a=!1){if(!r)return e?`${iPe}: ${e}`:iPe;let l=S_n[o]??S_n.braille,c=a||WYr(i,s),d=t==="working"?c?Jhd:l[n%l.length]:t==="attention"?Qhd:Xhd;return e?`${iPe} ${d} ${e}`:`${iPe} ${d}`}';

const PATCHED = 'function jYr(e,t,n,r,i=process.platform,o="braille",s=Pe,a=!1){return e||"omp"}';

const args = process.argv.slice(2);
const mode = args.find(a => a === "--check" || a === "--apply");
const target = args.find(a => a !== "--check" && a !== "--apply") ?? DEFAULT_PATH;

if (!mode) {
	console.error("usage: title-label-only.ts --check|--apply [cli.js]");
	process.exit(2);
}

const src = await Bun.file(target).text();
const pristineCount = src.split(PRISTINE).length - 1;
const patchedCount = src.split(PATCHED).length - 1;

if (pristineCount === 1 && patchedCount === 0) {
	if (mode === "--check") {
		console.log(`${target}: pristine, patch applies`);
		process.exit(0);
	}
	await Bun.write(target, src.replace(PRISTINE, PATCHED));
	console.log(`${target}: patched`);
	process.exit(0);
}

if (patchedCount === 1 && pristineCount === 0) {
	console.log(`${target}: already patched`);
	process.exit(0);
}

console.error(
	`${target}: unrecognized build (pristine matches=${pristineCount}, patched matches=${patchedCount}); refusing to change it`,
);
process.exit(1);
