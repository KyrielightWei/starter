/**
 * Pi Custom Status Bar Extension - 完整修复版
 * 三行状态栏：状态/Token / 目录/模型/Thinking / 上下文进度
 * 
 * 修复:
 * 1. 速率计算只在 turn 开始时记录基准
 * 2. 如果 API 不返回 cost，使用 models.json 配置计算
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import * as path from "node:path";
import * as fs from "node:fs";

const BAR_FULL = "█";
const BAR_EMPTY = "░";

// 全局缓存
let cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: false };
let modelCosts: Record<string, { input: number; output: number }> = {};
let sessionStartTime = Date.now();
let turnCount = 0;
let lastContextTokens = 0;
let lastContextTime = Date.now();
let turnStartTime = Date.now();
let turnStartTokens = 0;
let agentActive = false;
let turnSpeed = 0;
let currentModel = "";

function fmt(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 1_000_000) return `${(n / 1000).toFixed(1)}k`;
	return `${(n / 1_000_000).toFixed(1)M}`;
}

// 加载 models.json 中的 cost 配置
function loadModelCosts() {
	if (Object.keys(modelCosts).length > 0) return modelCosts;
	
	const modelsPath = path.join(process.env.HOME || "", ".pi/agent/models.json");
	try {
		if (fs.existsSync(modelsPath)) {
			const models = JSON.parse(fs.readFileSync(modelsPath, "utf8"));
			for (const [, provider] of Object.entries(models.providers || {})) {
				for (const model of (provider as any).models || []) {
					if (model.id && model.cost) {
						modelCosts[model.id] = {
							input: model.cost.input || 0,
							output: model.cost.output || 0,
						};
					}
				}
			}
		}
	} catch (e) {
		// 静默失败
	}
	return modelCosts;
}

// 计算 cost (API 返回或配置估算)
function calculateCost(input: number, output: number, modelId: string): number {
	const costs = loadModelCosts();
	const mc = costs[modelId] || { input: 0, output: 0 };
	// cost per 1M tokens
	const inputCost = (input / 1_000_000) * mc.input;
	const outputCost = (output / 1_000_000) * mc.output;
	return inputCost + outputCost;
}

function getUsage(ctx: ExtensionContext) {
	if (cachedUsage.valid) return cachedUsage;
	cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: true };
	currentModel = ctx.model?.id || "";
	
	for (const e of ctx.sessionManager.getBranch()) {
		if (e.type === "message" && (e.message as any).role === "assistant") {
			const m = e.message as AssistantMessage;
			if (m.usage) {
				cachedUsage.input += m.usage.input ?? 0;
				cachedUsage.output += m.usage.output ?? 0;
				cachedUsage.cacheRead += m.usage.cacheRead ?? 0;
				cachedUsage.cacheWrite += m.usage.cacheWrite ?? 0;
				// 使用 API cost 或配置计算
				const apiCost = m.usage.cost?.total ?? 0;
				if (apiCost > 0) {
					cachedUsage.cost += apiCost;
				} else {
					// API 未返回 cost，使用配置估算
					cachedUsage.cost += calculateCost(
						m.usage.input ?? 0,
						m.usage.output ?? 0,
						currentModel
					);
				}
			}
		}
	}
	return cachedUsage;
}

export default function (pi: ExtensionAPI) {
	let enabled = true;

	pi.on("session_start", (_event, ctx: ExtensionContext) => {
		sessionStartTime = Date.now();
		turnCount = 0;
		lastContextTokens = 0;
		lastContextTime = Date.now();
		turnStartTime = Date.now();
		turnStartTokens = 0;
		agentActive = false;
		turnSpeed = 0;
		cachedUsage.valid = false;
		currentModel = "";

		if (!enabled) return;

		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(w: number): string[] {
					const now = Date.now();

					// 上下文信息
					const usage = ctx.getContextUsage?.();
					const curTok = usage?.tokens ?? 0;
					const ctxWin = ctx.model?.contextWindow ?? 200000;
					const pct = ctxWin > 0 ? Math.min((curTok / ctxWin) * 100, 100) : 0;

					// 实时速率计算
					if (agentActive) {
						const turnElapsed = (now - turnStartTime) / 1000;
						if (turnElapsed > 0.5) {
							const tokDiff = curTok - turnStartTokens;
							turnSpeed = Math.round(tokDiff / turnElapsed);
						}
					}

					// Token统计
					const u = getUsage(ctx);
					const cacheTot = u.cacheRead + u.cacheWrite;
					const cacheRate = u.input + cacheTot > 0 ? Math.round((u.cacheRead / (u.input + cacheTot)) * 100) : 0;

					// 时间
					const sec = Math.floor((now - sessionStartTime) / 1000);
					const dur = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;

					// 关键信息
					const modelId = ctx.model?.id ?? "no-model";
					const provider = ctx.model?.provider ?? "";
					const thinking = pi.getThinkingLevel() ?? "off";
					const branch = footerData.getGitBranch() ?? "—";
					const cwd = path.basename(process.cwd());

					// 进度条
					const filled = Math.round(pct / 10);
					const bar = BAR_FULL.repeat(filled) + BAR_EMPTY.repeat(10 - filled);

					// ═══ 第一行：Token 统计 + 成本 ═══
					const statColor = agentActive ? theme.fg("accent", "⚡ Running") : theme.fg("success", "✓ Idle");
					const tokInStr = theme.fg("muted", `↑${fmt(u.input)}`);
					const tokOutStr = theme.fg("muted", `↓${fmt(u.output)}`);
					// 显示 cost，如果为 0 也显示 (配置中可能设为 0)
					const costStr = `$${u.cost.toFixed(4)}`;
					const cacheStr = cacheTot > 0 ? theme.fg("success", `C:${fmt(u.cacheRead)} ${cacheRate}%`) : "";
					
					const line1Parts = [statColor, tokInStr, tokOutStr, costStr, cacheStr].filter(Boolean);
					const line1 = line1Parts.join("  ");

					// ═══ 第二行：会话 + 环境 + 模型 ═══
					const speedCol = turnSpeed > 5000 ? "error" : turnSpeed > 1000 ? "warning" : "dim";
					const spStr = theme.fg(speedCol, `⚡${fmt(turnSpeed)}/s`);
					const turnStr = theme.fg("dim", `T${turnCount}`);
					const durStr = theme.fg("dim", `⏱${dur}`);
					const branchStr = theme.fg("success", `⎇${branch}`);
					const cwdStr = theme.fg("muted", `📁${cwd}`);
					const fullModel = provider ? `${provider}/${modelId}` : modelId;
					const modelStr = theme.fg("accent", fullModel);
					const tiColors: Record<string, string> = { off: "dim", minimal: "thinkingMinimal", low: "thinkingLow", medium: "thinkingMedium", high: "thinkingHigh", xhigh: "thinkingXhigh" };
					const tiIcons: Record<string, string> = { off: "○", minimal: "◔", low: "◑", medium: "●", high: "◉", xhigh: "⬤" };
					const tiStr = theme.fg(tiColors[thinking] ?? "dim", `🧠${tiIcons[thinking] ?? "○"}${thinking}`);
					
					const line2Parts = [spStr, turnStr, durStr, branchStr, cwdStr, modelStr, tiStr];
					const line2 = line2Parts.join("  ");

					// ═══ 第三行：上下文进度 ═══
					const pctCol = pct > 85 ? "error" : pct > 60 ? "warning" : "success";
					const pctNum = Math.round(pct);
					const pctStr = theme.fg(pctCol, `${pctNum}%`);
					const barStr = theme.fg(pctCol, bar);
					const tokStr = theme.fg("muted", `${fmt(curTok)}/${fmt(ctxWin)}`);
					
					const line3 = `Ctx: ${pctStr} ${barStr} ${tokStr}`;

					return [
						truncateToWidth(line1, w),
						truncateToWidth(line2, w),
						truncateToWidth(line3, w),
					];
				},
			};
		});
	});

	pi.on("turn_start", () => {
		agentActive = true;
		turnCount++;
		turnStartTime = Date.now();
		turnStartTokens = 0;
		turnSpeed = 0;
	});

	pi.on("turn_end", () => {
		agentActive = false;
		cachedUsage.valid = false;
		lastContextTokens = 0;
		lastContextTime = Date.now();
	});

	pi.registerCommand("statusbar", {
		description: "Toggle status bar",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			ctx.ui.setFooter(enabled ? undefined : undefined);
			ctx.ui.notify(enabled ? "Status bar on" : "Status bar off", "info");
		},
	});
}
