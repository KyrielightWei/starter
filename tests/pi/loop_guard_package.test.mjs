import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const packagePath = new URL("../../pi/packages/loop-guard/package.json", import.meta.url);
const extensionPath = new URL("../../pi/packages/loop-guard/index.ts", import.meta.url);

test("loop guard is packaged as a loadable Pi package", () => {
	const pkg = JSON.parse(readFileSync(packagePath, "utf8"));

	assert.equal(pkg.name, "starter-pi-loop-guard");
	assert.deepEqual(pkg.pi.extensions, ["./index.ts"]);
	assert.match(pkg.keywords.join(" "), /pi-package/);
});

test("loop guard extension installs Pi hooks", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /import type \{ ExtensionAPI/);
	assert.match(src, /export default function \(pi: ExtensionAPI\)/);
	assert.match(src, /pi\.on\("tool_call"/);
	assert.match(src, /pi\.on\("tool_result"/);
	assert.match(src, /pi\.on\("message_end"/);
	assert.match(src, /pi\.on\("context"/);
});

test("loop guard blocks repeated high-risk tool calls", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /REPEAT_LIMIT\s*=\s*readPositiveInt\("PI_LOOP_GUARD_REPEAT_LIMIT", 2\)/);
	assert.match(src, /block:\s*true/);
	assert.match(src, /what changed since the previous attempt/i);
	assert.match(src, /normalizeBashCommand/);
	assert.match(src, /"fffind"/);
});

test("loop guard detects response repetition and injects reflection context", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /RESPONSE_SIMILARITY_THRESHOLD/);
	assert.match(src, /responseLoopActive/);
	assert.match(src, /buildReflectionGate/);
	assert.match(src, /No more repeated summary or retry narration/i);
});

test("loop guard limits intentional allow-repeat bypasses", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /allowRepeats\s*=\s*new Map/);
	assert.match(src, /ALLOW_REPEAT_LIMIT/);
	assert.doesNotMatch(src, /hasAllowRepeatMarker\(input\.command\)\)\s*return undefined/);
});

test("loop guard sanitizes repeated tool call history before provider requests", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /sanitizeRepeatedToolHistory/);
	assert.match(src, /historyToolCallSignatures/);
	assert.match(src, /LoopGuard pruned repeated tool-call history/i);
});

test("loop guard exposes a runtime command for status and reset", () => {
	const src = readFileSync(extensionPath, "utf8");

	assert.match(src, /pi\.registerCommand\("loop-guard"/);
	assert.match(src, /resetLoopState/);
	assert.match(src, /Loop guard reset/);
});
