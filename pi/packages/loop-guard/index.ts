/**
 * Loop Guard Extension
 *
 * Detects high-confidence loops in three places:
 * - repeated high-risk tool calls
 * - repeated failed tool results
 * - repeated assistant responses with no visible new information
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { TextContent, ImageContent, UserMessage } from "@earendil-works/pi-ai";

// 反射门消息：UserMessage + customType（SDK 运行时支持，类型未声明）
type ReflectionGateMessage = UserMessage & { customType: string };

type Counter = {
	count: number;
	firstSeen: number;
	lastSeen: number;
	toolName: string;
	summary: string;
};

type ResponseSnapshot = {
	fingerprint: string;
	tokens: Set<string>;
	text: string;
	timestamp: number;
};

const REPEAT_LIMIT = readPositiveInt("PI_LOOP_GUARD_REPEAT_LIMIT", 2);
const FAILURE_LIMIT = readPositiveInt("PI_LOOP_GUARD_FAILURE_LIMIT", 2);
const RESPONSE_REPEAT_LIMIT = readPositiveInt(
	"PI_LOOP_GUARD_RESPONSE_REPEAT_LIMIT",
	1,
);
const RESPONSE_SIMILARITY_THRESHOLD = readFloat(
	"PI_LOOP_GUARD_RESPONSE_SIMILARITY",
	0.82,
);
const WINDOW_MS = readPositiveInt("PI_LOOP_GUARD_WINDOW_MS", 15 * 60 * 1000);
const MAX_ENTRIES = 200;
const MAX_RESPONSES = 6;
const MIN_RESPONSE_CHARS = 280;
const ALLOW_REPEAT_MARKER = "loop-guard: allow-repeat";
const ALLOW_REPEAT_LIMIT = 1;
const HISTORY_REPEAT_LIMIT = 2;
const REFLECTION_CUSTOM_TYPE = "loop-guard-reflection";
const HISTORY_PRUNE_CUSTOM_TYPE = "loop-guard-history-prune";

const guardedTools = new Set([
	"bash",
	"edit",
	"write",
	"subagent",
	"web_search",
	"fetch_content",
	"browser",
	"open_browser",
	"trace",
	"read",
	"grep",
	"fffind",
	"search",
	"taskflow",
]);

export default function (pi: ExtensionAPI) {
	let enabled = process.env.PI_LOOP_GUARD !== "0";
	let responseGuardEnabled = process.env.PI_LOOP_GUARD_RESPONSE !== "0";
	let responseLoopActive = false;
	let repeatedResponseCount = 0;
	let lastResponseScore = 0;
	let lastResponseSummary = "";
	const calls = new Map<string, Counter>();
	const allowRepeats = new Map<string, Counter>();
	const failures = new Map<string, Counter>();
	const responses: ResponseSnapshot[] = [];

	function resetLoopState() {
		calls.clear();
		allowRepeats.clear();
		failures.clear();
		responses.length = 0;
		responseLoopActive = false;
		repeatedResponseCount = 0;
		lastResponseScore = 0;
		lastResponseSummary = "";
	}

	function prune(now: number) {
		pruneMap(calls, now);
		pruneMap(allowRepeats, now);
		pruneMap(failures, now);
		for (let i = responses.length - 1; i >= 0; i--) {
			if (now - responses[i].timestamp > WINDOW_MS) responses.splice(i, 1);
		}
	}

	pi.on("turn_start", () => {
		prune(Date.now());
	});

	pi.on("context", async (event) => {
		if (!enabled) return undefined;

		const messages = event.messages.filter(
			(message) =>
				(message as Record<string, unknown>).customType !==
					REFLECTION_CUSTOM_TYPE &&
				(message as Record<string, unknown>).customType !==
					HISTORY_PRUNE_CUSTOM_TYPE,
		);
		const sanitized = sanitizeRepeatedToolHistory(messages);
		const injected: AgentMessage[] = [];

		if (sanitized.prunedCount > 0) {
			injected.push({
				role: "user",
				customType: HISTORY_PRUNE_CUSTOM_TYPE,
				content: [
					{
						type: "text",
						text: buildHistoryPruneGate(sanitized.prunedCount),
					},
				],
			} as ReflectionGateMessage);
		}

		if (responseGuardEnabled && responseLoopActive) {
			injected.push({
				role: "user",
				customType: REFLECTION_CUSTOM_TYPE,
				content: [
					{
						type: "text",
						text: buildReflectionGate(lastResponseScore, lastResponseSummary),
					},
				],
			} as ReflectionGateMessage);
		}

		if (sanitized.prunedCount === 0 && injected.length === 0) return undefined;

		return {
			messages: [
				...sanitized.messages,
				...injected,
			] as AgentMessage[],
		};
	});

	pi.on("message_end", async (event, ctx) => {
		if (!enabled || !responseGuardEnabled) return undefined;
		if (event.message.role !== "assistant") return undefined;

		const text = visibleMessageText(event.message);
		if (!shouldAnalyzeResponse(text)) return undefined;

		const now = Date.now();
		prune(now);

		const snapshot = buildResponseSnapshot(text, now);
		const previous = findMostSimilarResponse(snapshot, responses);
		responses.push(snapshot);
		while (responses.length > MAX_RESPONSES) responses.shift();

		if (!previous || previous.score < RESPONSE_SIMILARITY_THRESHOLD) {
			repeatedResponseCount = 0;
			lastResponseScore = previous?.score ?? 0;
			lastResponseSummary = summarizeResponse(text);
			return undefined;
		}

		repeatedResponseCount++;
		responseLoopActive = true;
		lastResponseScore = previous.score;
		lastResponseSummary = summarizeResponse(text);
		ctx.ui.notify(
			`Loop guard: response repetition detected (${Math.round(previous.score * 100)}%)`,
			"warning",
		);

		if (repeatedResponseCount <= RESPONSE_REPEAT_LIMIT) return undefined;

		return {
			message: appendLoopGuardNote(
				event.message,
				[
					"",
					"LoopGuard: response repetition detected.",
					"No more repeated summary or retry narration.",
					"Before continuing, state the new evidence, failed assumption, and a different next step.",
				].join("\n"),
			),
		};
	});

	pi.on("tool_call", async (event) => {
		if (!enabled) return undefined;
		if (!guardedTools.has(event.toolName)) return undefined;

		const input = event.input as Record<string, unknown>;
		const now = Date.now();
		prune(now);

		const signature = toolSignature(event.toolName, input);
		const summary = summarizeToolCall(event.toolName, input);
		const entry = bump(calls, signature, event.toolName, summary, now);
		if (event.toolName === "bash" && hasAllowRepeatMarker(input.command)) {
			const allowed = bump(
				allowRepeats,
				signature,
				event.toolName,
				summary,
				now,
			);
			if (allowed.count <= ALLOW_REPEAT_LIMIT) return undefined;

			return {
				block: true,
				reason: buildBlockReason(
					"Repeated allow-repeat tool call",
					allowed,
					[
						"remove the allow-repeat marker",
						"state what different command or diagnostic will be used",
						"answer the user with current evidence if no new tool is needed",
					],
					false,
				),
			};
		}

		if (entry.count > REPEAT_LIMIT) {
			return {
				block: true,
				reason: buildBlockReason("Repeated tool call", entry, [
					"what changed since the previous attempt",
					"what new evidence this retry will produce",
					"why this is not the same attempt",
				]),
			};
		}

		return undefined;
	});

	pi.on("tool_result", async (event) => {
		if (!enabled) return undefined;

		const failed =
			event.isError || looksLikeFailure(contentText(event.content));
		if (!failed) return undefined;

		const now = Date.now();
		prune(now);

		const fingerprint = failureSignature(
			event.toolName,
			event.input,
			event.content,
		);
		const summary = summarizeFailure(
			event.toolName,
			event.input,
			event.content,
		);
		const entry = bump(failures, fingerprint, event.toolName, summary, now);

		if (entry.count <= FAILURE_LIMIT) return undefined;

		const guardText = buildBlockReason("Repeated failed result", entry, [
			"stop retrying the same action",
			"state the observed facts",
			"name one hypothesis that changed",
			"choose a different diagnostic step before any fix",
		]);

		return {
			content: [{ type: "text", text: guardText }],
			isError: true,
			details: event.details,
		};
	});

	pi.registerCommand("loop-guard", {
		description: "Show, reset, enable, or disable loop guard state",
		handler: async (args: unknown, ctx) => {
			const action = commandText(args).trim().toLowerCase();

			if (action === "reset") {
				resetLoopState();
				ctx.ui.notify("Loop guard reset", "info");
				return;
			}
			if (action === "off" || action === "disable") {
				enabled = false;
				ctx.ui.notify("Loop guard disabled", "info");
				return;
			}
			if (action === "on" || action === "enable") {
				enabled = true;
				ctx.ui.notify("Loop guard enabled", "info");
				return;
			}
			if (action === "response-off") {
				responseGuardEnabled = false;
				responseLoopActive = false;
				ctx.ui.notify("Loop guard response checks disabled", "info");
				return;
			}
			if (action === "response-on") {
				responseGuardEnabled = true;
				ctx.ui.notify("Loop guard response checks enabled", "info");
				return;
			}

			const status = [
				`Loop guard: ${enabled ? "enabled" : "disabled"}`,
				`response guard: ${responseGuardEnabled ? "enabled" : "disabled"}`,
				`repeat limit: ${REPEAT_LIMIT}`,
				`failure limit: ${FAILURE_LIMIT}`,
				`response repeat limit: ${RESPONSE_REPEAT_LIMIT}`,
				`tracked calls: ${calls.size}`,
				`tracked allow-repeats: ${allowRepeats.size}`,
				`tracked failures: ${failures.size}`,
				`tracked responses: ${responses.length}`,
				`last response similarity: ${Math.round(lastResponseScore * 100)}%`,
				"commands: /loop-guard reset | on | off | response-on | response-off",
			].join("\n");
			ctx.ui.notify(status, "info");
		},
	});
}

function readPositiveInt(name: string, fallback: number): number {
	const raw = process.env[name];
	if (!raw) return fallback;
	const parsed = Number.parseInt(raw, 10);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function readFloat(name: string, fallback: number): number {
	const raw = process.env[name];
	if (!raw) return fallback;
	const parsed = Number.parseFloat(raw);
	return Number.isFinite(parsed) && parsed > 0 && parsed <= 1
		? parsed
		: fallback;
}

function bump(
	map: Map<string, Counter>,
	key: string,
	toolName: string,
	summary: string,
	now: number,
): Counter {
	const existing = map.get(key);
	if (existing) {
		existing.count++;
		existing.lastSeen = now;
		existing.summary = summary;
		return existing;
	}

	const entry = { count: 1, firstSeen: now, lastSeen: now, toolName, summary };
	map.set(key, entry);

	if (map.size > MAX_ENTRIES) {
		const oldest = [...map.entries()].sort(
			(a, b) => a[1].lastSeen - b[1].lastSeen,
		)[0];
		if (oldest) map.delete(oldest[0]);
	}

	return entry;
}

function pruneMap(map: Map<string, Counter>, now: number) {
	for (const [key, entry] of map) {
		if (now - entry.lastSeen > WINDOW_MS) map.delete(key);
	}
}

function toolSignature(
	toolName: string,
	input: Record<string, unknown>,
): string {
	if (toolName === "bash") {
		return `${toolName}:${normalizeBashCommand(String(input.command ?? ""))}`;
	}
	return `${toolName}:${stableStringify(input)}`;
}

function failureSignature(
	toolName: string,
	input: Record<string, unknown>,
	content: unknown[],
): string {
	const call = toolSignature(toolName, input);
	const text = normalizeFailureText(contentText(content));
	return `${call}:${text}`;
}

function sanitizeRepeatedToolHistory(messages: AgentMessage[]): {
	messages: AgentMessage[];
	prunedCount: number;
} {
	const historyToolCallSignatures = new Map<string, number>();
	const droppedToolCallIds = new Set<string>();
	const kept: AgentMessage[] = [];
	let prunedCount = 0;

	for (const message of messages) {
		if (isDroppedToolResult(message, droppedToolCallIds)) {
			prunedCount++;
			continue;
		}

		const toolCalls = toolCallsFromMessage(message);
		if (toolCalls.length === 0) {
			kept.push(message);
			continue;
		}

		const signatures = toolCalls.map((call) =>
			toolSignature(call.name, asRecord(call.arguments)),
		);
		const allRepeated = signatures.every(
			(signature) =>
				(historyToolCallSignatures.get(signature) ?? 0) >= HISTORY_REPEAT_LIMIT,
		);

		for (const signature of signatures) {
			historyToolCallSignatures.set(
				signature,
				(historyToolCallSignatures.get(signature) ?? 0) + 1,
			);
		}

		if (!allRepeated) {
			kept.push(message);
			continue;
		}

		prunedCount++;
		for (const call of toolCalls) {
			if (call.id) droppedToolCallIds.add(call.id);
		}
	}

	return { messages: kept, prunedCount };
}

function toolCallsFromMessage(message: unknown): Array<{
	id?: string;
	name: string;
	arguments: unknown;
}> {
	const msg = message as { role?: unknown; content?: unknown };
	if (msg.role !== "assistant" || !Array.isArray(msg.content)) return [];
	return msg.content
		.filter(
			(part): part is {
				type: string;
				id?: string;
				name: string;
				arguments?: unknown;
			} =>
				!!part &&
				typeof part === "object" &&
				(part as { type?: unknown }).type === "toolCall" &&
				typeof (part as { name?: unknown }).name === "string",
		)
		.map((part) => ({
			id: typeof part.id === "string" ? part.id : undefined,
			name: part.name,
			arguments: part.arguments,
		}));
}

function isDroppedToolResult(
	message: unknown,
	droppedToolCallIds: Set<string>,
): boolean {
	const msg = message as { role?: unknown; toolCallId?: unknown };
	return (
		msg.role === "toolResult" &&
		typeof msg.toolCallId === "string" &&
		droppedToolCallIds.has(msg.toolCallId)
	);
}

function asRecord(value: unknown): Record<string, unknown> {
	return value && typeof value === "object" && !Array.isArray(value)
		? (value as Record<string, unknown>)
		: {};
}

function normalizeBashCommand(command: unknown): string {
	return String(command ?? "")
		.replace(new RegExp(ALLOW_REPEAT_MARKER, "g"), "")
		.replace(/\s+/g, " ")
		.replace(/^\s*cd\s+[^&;]+&&\s*/, "")
		.trim();
}

function normalizeFailureText(text: string): string {
	return text
		.toLowerCase()
		.replace(/\b[0-9a-f]{7,40}\b/g, "<hex>")
		.replace(/\b\d+(\.\d+)?\b/g, "<num>")
		.replace(/\/[^\s'"`]+/g, "<path>")
		.replace(/\s+/g, " ")
		.slice(0, 500)
		.trim();
}

function hasAllowRepeatMarker(command: unknown): boolean {
	return typeof command === "string" && command.includes(ALLOW_REPEAT_MARKER);
}

function looksLikeFailure(text: string): boolean {
	return /\b(error|failed|failure|exception|referenceerror|typeerror|syntaxerror|enoent|eperm|eacces|erofs|permission denied|not found|tool .* not found|exit code [1-9])\b/i.test(
		text,
	);
}

function contentText(content: unknown[]): string {
	return content
		.map((part) => {
			if (part && typeof part === "object" && "text" in part) {
				return String((part as { text?: unknown }).text ?? "");
			}
			return "";
		})
		.join("\n");
}

function visibleMessageText(message: unknown): string {
	const content = (message as { content?: unknown })?.content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return contentText(content);
}

function shouldAnalyzeResponse(text: string): boolean {
	if (text.length < MIN_RESPONSE_CHARS) return false;
	if (/LoopGuard: response repetition detected/.test(text)) return false;
	return true;
}

function buildResponseSnapshot(
	text: string,
	timestamp: number,
): ResponseSnapshot {
	const normalized = normalizeResponseText(text);
	return {
		fingerprint: normalized.slice(0, 1000),
		tokens: tokenSet(normalized),
		text,
		timestamp,
	};
}

function normalizeResponseText(text: string): string {
	return text
		.toLowerCase()
		.replace(/```[\s\S]*?```/g, "<code>")
		.replace(/`[^`]+`/g, "<inline-code>")
		.replace(/\b[0-9a-f]{7,40}\b/g, "<hex>")
		.replace(/\b\d+(\.\d+)?\b/g, "<num>")
		.replace(/\/[^\s'"`]+/g, "<path>")
		.replace(/[^\p{L}\p{N}_\s<>-]/gu, " ")
		.replace(/\s+/g, " ")
		.trim();
}

function tokenSet(text: string): Set<string> {
	const words = text.split(/\s+/).filter((word) => word.length >= 3);
	const grams = new Set<string>();
	for (let i = 0; i < words.length - 2; i++) {
		grams.add(`${words[i]} ${words[i + 1]} ${words[i + 2]}`);
	}
	if (grams.size > 0) return grams;
	return new Set(words);
}

function findMostSimilarResponse(
	current: ResponseSnapshot,
	previous: ResponseSnapshot[],
): { score: number } | null {
	let best = 0;
	for (const item of previous) {
		const tokenScore = jaccard(current.tokens, item.tokens);
		const prefixScore = current.fingerprint === item.fingerprint ? 1 : 0;
		best = Math.max(best, tokenScore, prefixScore);
	}
	return previous.length > 0 ? { score: best } : null;
}

function jaccard(a: Set<string>, b: Set<string>): number {
	if (a.size === 0 || b.size === 0) return 0;
	let intersection = 0;
	for (const item of a) {
		if (b.has(item)) intersection++;
	}
	return intersection / (a.size + b.size - intersection);
}

function summarizeResponse(text: string): string {
	return normalizeResponseText(text).slice(0, 220);
}

function appendLoopGuardNote(message: unknown, note: string): AgentMessage {
	const msg = message as Record<string, unknown>;
	const content = msg.content;
	if (typeof content === "string") {
		return { ...msg, content: `${content}\n\n${note}` } as unknown as AgentMessage;
	}
	if (Array.isArray(content)) {
		return {
			...msg,
			content: [...content, { type: "text", text: `\n\n${note}` }],
		} as unknown as AgentMessage;
	}
	return msg as unknown as AgentMessage;
}

function summarizeToolCall(
	toolName: string,
	input: Record<string, unknown>,
): string {
	if (toolName === "bash")
		return normalizeBashCommand(input.command).slice(0, 180);
	if (typeof input.path === "string") return `${toolName} ${input.path}`;
	return `${toolName} ${stableStringify(input).slice(0, 180)}`;
}

function summarizeFailure(
	toolName: string,
	input: Record<string, unknown>,
	content: unknown[],
): string {
	const call = summarizeToolCall(toolName, input);
	const text = normalizeFailureText(contentText(content)).slice(0, 180);
	return `${call}\n${text}`;
}

function buildBlockReason(
	title: string,
	entry: Counter,
	required: string[],
	includeAllowRepeatHint = true,
): string {
	const ageSec = Math.max(
		1,
		Math.round((entry.lastSeen - entry.firstSeen) / 1000),
	);
	return [
		`LoopGuard: ${title} blocked.`,
		`Tool: ${entry.toolName}`,
		`Repeated: ${entry.count} times in ${ageSec}s`,
		`Action: ${entry.summary}`,
		"",
		"Before retrying, state:",
		...required.map((item, index) => `${index + 1}. ${item}`),
		"",
		includeAllowRepeatHint
			? `If one exact bash repeat is intentional, add "${ALLOW_REPEAT_MARKER}" to the command. Repeated marked retries are still blocked.`
			: "",
	]
		.filter((line, index, lines) => line !== "" || lines[index + 1] !== "")
		.join("\n");
}

function buildReflectionGate(score: number, summary: string): string {
	return [
		"[LoopGuard Reflection Gate]",
		`Your previous assistant response looked repetitive (${Math.round(score * 100)}% similarity).`,
		summary ? `Repeated content fingerprint: ${summary}` : "",
		"",
		"No more repeated summary or retry narration.",
		"Before taking another tool action or proposing another fix, answer these briefly:",
		"1. What new fact do you know now that was not known in the previous attempt?",
		"2. Which assumption failed or remains unproven?",
		"3. What different diagnostic step or strategy will you use next?",
	]
		.filter(Boolean)
		.join("\n");
}

function buildHistoryPruneGate(prunedCount: number): string {
	return [
		"[LoopGuard History Prune]",
		`LoopGuard pruned repeated tool-call history (${prunedCount} message${prunedCount === 1 ? "" : "s"}).`,
		"",
		"The previous context contained repeated identical tool calls that can trigger provider-side loop rejection.",
		"Do not retry the same tool call. Answer with current evidence or choose a different diagnostic step.",
	]
		.filter(Boolean)
		.join("\n");
}

function commandText(args: unknown): string {
	if (Array.isArray(args)) return args.map(String).join(" ");
	if (typeof args === "string") return args;
	if (args && typeof args === "object" && "args" in args) {
		const value = (args as { args?: unknown }).args;
		if (Array.isArray(value)) return value.map(String).join(" ");
		if (typeof value === "string") return value;
	}
	return "";
}

function stableStringify(value: unknown): string {
	if (value === null || typeof value !== "object") return JSON.stringify(value);
	if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;

	const obj = value as Record<string, unknown>;
	return `{${Object.keys(obj)
		.sort()
		.map((key) => `${JSON.stringify(key)}:${stableStringify(obj[key])}`)
		.join(",")}}`;
}
