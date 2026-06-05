/**
 * Pi Custom Status Bar Extension
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { truncateToWidth } from "@earendil-works/pi-tui";
import * as path from "node:path";
import * as fs from "node:fs";

var BAR_FULL = "█";
var BAR_EMPTY = "░";

function fmt(n: number): string {
	if (n < 1000) return String(n);
	if (n < 1000000) return (n / 1000).toFixed(1) + "k";
	return (n / 1000000).toFixed(1) + "M";
}

function loadModelCosts(): Record<string, { input: number; output: number }> {
	var costs: Record<string, { input: number; output: number }> = {};
	var home = process.env.HOME || "/root";
	var modelsPath = path.join(home, ".pi/agent/models.json");

	try {
		if (fs.existsSync(modelsPath)) {
			var content = fs.readFileSync(modelsPath, "utf8");
			var models = JSON.parse(content);
			var providers = models.providers || {};

			Object.keys(providers).forEach(function(providerKey) {
				var provider = providers[providerKey];
				if (provider && provider.models) {
					provider.models.forEach(function(model: any) {
						if (model.id && model.cost) {
							costs[model.id] = {
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
	return costs;
}

export default function (pi: ExtensionAPI) {
	var enabled = true;

	// session-scoped state — each call to the default export creates its own closure
	var cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: false };
	var modelCosts: Record<string, { input: number; output: number }> = {};
	var sessionStartTime = Date.now();
	var turnCount = 0;
	var turnStartTime = Date.now();
	var turnStartTokens = 0;
	var agentActive = false;
	var turnSpeed = 0;
	var currentModel = "";

	function ensureModelCosts() {
		if (Object.keys(modelCosts).length === 0) {
			modelCosts = loadModelCosts();
		}
		return modelCosts;
	}

	function calculateCost(input: number, output: number, modelId: string): number {
		var costs = ensureModelCosts();
		var mc = costs[modelId] || { input: 0, output: 0 };
		return (input / 1000000) * mc.input + (output / 1000000) * mc.output;
	}

	function getUsage(ctx: ExtensionContext) {
		if (cachedUsage.valid) return cachedUsage;
		cachedUsage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, valid: true };
		currentModel = ctx.model?.id || "";

		ctx.sessionManager.getBranch().forEach(function(e) {
			if (e.type === "message" && e.message && e.message.role === "assistant") {
				var m = e.message as AssistantMessage;
				if (m.usage) {
					cachedUsage.input += m.usage.input || 0;
					cachedUsage.output += m.usage.output || 0;
					cachedUsage.cacheRead += m.usage.cacheRead || 0;
					cachedUsage.cacheWrite += m.usage.cacheWrite || 0;

					var apiCost = (m.usage as any).cost?.total || 0;
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
					var now = Date.now();
					var usage = ctx.getContextUsage?.();
					var curTok = usage?.tokens || 0;
					var ctxWin = ctx.model?.contextWindow || 200000;
					var pct = ctxWin > 0 ? Math.min((curTok / ctxWin) * 100, 100) : 0;

					if (agentActive) {
						var turnElapsed = (now - turnStartTime) / 1000;
						if (turnElapsed > 0.5) {
							var delta = curTok - turnStartTokens;
							turnSpeed = delta > 0 ? Math.round(delta / turnElapsed) : 0;
						}
					}

					var u = getUsage(ctx);
					var cacheTot = u.cacheRead + u.cacheWrite;
					var cacheRate = u.input + cacheTot > 0 ? Math.round((u.cacheRead / (u.input + cacheTot)) * 100) : 0;

					var sec = Math.floor((now - sessionStartTime) / 1000);
					var dur = Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0");

					var modelId = ctx.model?.id || "no-model";
					var provider = ctx.model?.provider || "";
					var thinking = pi.getThinkingLevel() || "off";
					var branch = footerData.getGitBranch() || "—";
					var cwd = path.basename(process.cwd());

					var filled = Math.round(pct / 10);
					var bar = BAR_FULL.repeat(filled) + BAR_EMPTY.repeat(10 - filled);

					// Line 1: status, tokens, cost, cache
					var statColor = agentActive ? theme.fg("accent", "⚡ Running") : theme.fg("success", "✓ Idle");
					var tokInStr = theme.fg("muted", "↑" + fmt(u.input));
					var tokOutStr = theme.fg("muted", "↓" + fmt(u.output));
					var costStr = "$" + u.cost.toFixed(4);
					var cacheStr = cacheTot > 0 ? theme.fg("success", "C:" + fmt(u.cacheRead) + " " + cacheRate + "%") : "";

					var line1 = [statColor, tokInStr, tokOutStr, costStr, cacheStr].filter(Boolean).join("  ");

					// Line 2: speed, turn, duration, branch, cwd, model, thinking
					// speed color: low = red (throttled), high = green (healthy)
					var speedCol = turnSpeed < 100 ? "error" : turnSpeed < 1000 ? "warning" : "success";
					var spStr = agentActive
						? theme.fg(speedCol, "⚡" + fmt(turnSpeed) + "/s")
						: theme.fg("dim", "⚡" + fmt(turnSpeed) + "/s");
					var turnStr = theme.fg("dim", "T" + turnCount);
					var durStr = theme.fg("dim", "⏱" + dur);
					var branchStr = theme.fg("success", "⏎" + branch);
					var cwdStr = theme.fg("muted", "📁" + cwd);
					var fullModel = provider ? provider + "/" + modelId : modelId;
					var modelStr = theme.fg("accent", fullModel);

					var tiColors: Record<string, string> = {
						off: "dim", minimal: "thinkingMinimal", low: "thinkingLow",
						medium: "thinkingMedium", high: "thinkingHigh", xhigh: "thinkingXhigh"
					};
					var tiIcons: Record<string, string> = {
						off: "○", minimal: "◔", low: "◑", medium: "●", high: "◉", xhigh: "⬤"
					};
					var tiStr = theme.fg(tiColors[thinking] || "dim", "🧠" + (tiIcons[thinking] || "○") + thinking);

					var line2 = [spStr, turnStr, durStr, branchStr, cwdStr, modelStr, tiStr].join("  ");

					// Line 3: context bar
					var pctCol = pct > 85 ? "error" : pct > 60 ? "warning" : "success";
					var pctNum = Math.round(pct);
					var pctStr = theme.fg(pctCol, pctNum + "%");
					var barStr = theme.fg(pctCol, bar);
					var tokStr = theme.fg("muted", fmt(curTok) + "/" + fmt(ctxWin));

					var line3 = "Ctx: " + pctStr + " " + barStr + " " + tokStr;

					return [
						truncateToWidth(line1, w),
						truncateToWidth(line2, w),
						truncateToWidth(line3, w)
					];
				}
			};
		});
	});

	pi.on("turn_start", function(_event, ctx: ExtensionContext) {
		agentActive = true;
		turnCount++;
		turnStartTime = Date.now();
		// capture current context tokens so speed = delta / elapsed
		var usage = ctx.getContextUsage?.();
		turnStartTokens = usage?.tokens || 0;
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
