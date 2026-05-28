/**
 * Pi Custom Status Bar Extension - 最终修复版
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { truncateToWidth } from "@earendil-works/pi-tui";
import * as path from "node:path";
import * as fs from "node:fs";

const BAR_FULL = "█";
const BAR_EMPTY = "░";

let cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: false };
let modelCosts: Record<string, { input: number; output: number }> = {};
let sessionStartTime = Date.now();
let turnCount = 0;
let turnStartTime = Date.now();
let turnStartTokens = 0;
let agentActive = false;
let turnSpeed = 0;
let currentModel = "";

function fmt(n: number): string {
	if (n < 1000) return String(n);
	if (n < 1000000) return (n / 1000).toFixed(1) + "k";
	return (n / 1000000).toFixed(1) + "M";
}

function loadModelCosts() {
	if (Object.keys(modelCosts).length > 0) return modelCosts;
	
	const home = process.env.HOME || "/root";
	const modelsPath = path.join(home, ".pi/agent/models.json");
	
	try {
		if (fs.existsSync(modelsPath)) {
			const content = fs.readFileSync(modelsPath, "utf8");
			const models = JSON.parse(content);
			const providers = models.providers || {};
			
			Object.keys(providers).forEach(function(providerKey) {
				const provider = providers[providerKey];
				if (provider && provider.models) {
					provider.models.forEach(function(model) {
						if (model.id && model.cost) {
							modelCosts[model.id] = {
								input: model.cost.input || 0,
								output: model.cost.output || 0
							};
						}
					});
				}
			});
		}
	} catch (e) {
		// ignore
	}
	return modelCosts;
}

function calculateCost(input: number, output: number, modelId: string): number {
	const costs = loadModelCosts();
	const mc = costs[modelId] || { input: 0, output: 0 };
	return (input / 1000000) * mc.input + (output / 1000000) * mc.output;
}

function getUsage(ctx: ExtensionContext) {
	if (cachedUsage.valid) return cachedUsage;
	cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: true };
	currentModel = ctx.model?.id || "";
	
	ctx.sessionManager.getBranch().forEach(function(e) {
		if (e.type === "message" && e.message && e.message.role === "assistant") {
			const m = e.message as AssistantMessage;
			if (m.usage) {
				cachedUsage.input += m.usage.input || 0;
				cachedUsage.output += m.usage.output || 0;
				cachedUsage.cacheRead += m.usage.cacheRead || 0;
				cachedUsage.cacheWrite += m.usage.cacheWrite || 0;
				
				const apiCost = (m.usage as any).cost?.total || 0;
				if (apiCost > 0) {
					cachedUsage.cost += apiCost;
				} else {
					cachedUsage.cost += calculateCost(
						m.usage.input || 0,
						m.usage.output || 0,
						currentModel
					);
				}
			}
		}
	});
	return cachedUsage;
}

export default function (pi: ExtensionAPI) {
	let enabled = true;

	pi.on("session_start", function(_event, ctx: ExtensionContext) {
		sessionStartTime = Date.now();
		turnCount = 0;
		turnStartTime = Date.now();
		turnStartTokens = 0;
		agentActive = false;
		turnSpeed = 0;
		cachedUsage.valid = false;
		currentModel = "";

		if (!enabled) return;

		ctx.ui.setFooter(function(tui, theme, footerData) {
			footerData.onBranchChange(function() { tui.requestRender(); });

			return {
				dispose: function() {},
				invalidate: function() {},
				render: function(w: number): string[] {
					const now = Date.now();
					const usage = ctx.getContextUsage?.();
					const curTok = usage?.tokens || 0;
					const ctxWin = ctx.model?.contextWindow || 200000;
					const pct = ctxWin > 0 ? Math.min((curTok / ctxWin) * 100, 100) : 0;

					if (agentActive) {
						const turnElapsed = (now - turnStartTime) / 1000;
						if (turnElapsed > 0.5) {
							turnSpeed = Math.round((curTok - turnStartTokens) / turnElapsed);
						}
					}

					const u = getUsage(ctx);
					const cacheTot = u.cacheRead + u.cacheWrite;
					const cacheRate = u.input + cacheTot > 0 ? Math.round((u.cacheRead / (u.input + cacheTot)) * 100) : 0;

					const sec = Math.floor((now - sessionStartTime) / 1000);
					const dur = Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0");

					const modelId = ctx.model?.id || "no-model";
					const provider = ctx.model?.provider || "";
					const thinking = pi.getThinkingLevel() || "off";
					const branch = footerData.getGitBranch() || "—";
					const cwd = path.basename(process.cwd());

					const filled = Math.round(pct / 10);
					const bar = BAR_FULL.repeat(filled) + BAR_EMPTY.repeat(10 - filled);

					// Line 1
					const statColor = agentActive ? theme.fg("accent", "⚡ Running") : theme.fg("success", "✓ Idle");
					const tokInStr = theme.fg("muted", "↑" + fmt(u.input));
					const tokOutStr = theme.fg("muted", "↓" + fmt(u.output));
					const costStr = "$" + u.cost.toFixed(4);
					const cacheStr = cacheTot > 0 ? theme.fg("success", "C:" + fmt(u.cacheRead) + " " + cacheRate + "%") : "";
					
					const line1 = [statColor, tokInStr, tokOutStr, costStr, cacheStr].filter(Boolean).join("  ");

					// Line 2
					const speedCol = turnSpeed > 5000 ? "error" : turnSpeed > 1000 ? "warning" : "dim";
					const spStr = theme.fg(speedCol, "⚡" + fmt(turnSpeed) + "/s");
					const turnStr = theme.fg("dim", "T" + turnCount);
					const durStr = theme.fg("dim", "⏱" + dur);
					const branchStr = theme.fg("success", "⎇" + branch);
					const cwdStr = theme.fg("muted", "📁" + cwd);
					const fullModel = provider ? provider + "/" + modelId : modelId;
					const modelStr = theme.fg("accent", fullModel);
					
					const tiColors: Record<string, string> = { 
						off: "dim", minimal: "thinkingMinimal", low: "thinkingLow", 
						medium: "thinkingMedium", high: "thinkingHigh", xhigh: "thinkingXhigh" 
					};
					const tiIcons: Record<string, string> = { 
						off: "○", minimal: "◔", low: "◑", medium: "●", high: "◉", xhigh: "⬤" 
					};
					const tiStr = theme.fg(tiColors[thinking] || "dim", "🧠" + (tiIcons[thinking] || "○") + thinking);
					
					const line2 = [spStr, turnStr, durStr, branchStr, cwdStr, modelStr, tiStr].join("  ");

					// Line 3
					const pctCol = pct > 85 ? "error" : pct > 60 ? "warning" : "success";
					const pctNum = Math.round(pct);
					const pctStr = theme.fg(pctCol, pctNum + "%");
					const barStr = theme.fg(pctCol, bar);
					const tokStr = theme.fg("muted", fmt(curTok) + "/" + fmt(ctxWin));
					
					const line3 = "Ctx: " + pctStr + " " + barStr + " " + tokStr;

					return [
						truncateToWidth(line1, w),
						truncateToWidth(line2, w),
						truncateToWidth(line3, w)
					];
				}
			};
		});
	});

	pi.on("turn_start", function() {
		agentActive = true;
		turnCount++;
		turnStartTime = Date.now();
		turnStartTokens = 0;
		turnSpeed = 0;
	});

	pi.on("turn_end", function() {
		agentActive = false;
		cachedUsage.valid = false;
	});

	pi.registerCommand("statusbar", {
		description: "Toggle status bar",
		handler: function(_args, ctx) {
			enabled = !enabled;
			if (!enabled) {
				ctx.ui.setFooter(undefined);
			}
			ctx.ui.notify(enabled ? "Status bar on" : "Status bar off", "info");
			return Promise.resolve();
		}
	});
}
