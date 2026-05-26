/**
 * Enhanced Exit Extension 模板 🚪
 *
 * 增强退出体验，防止意外退出
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  功能:                                                                  ║
 * ║    - Ctrl+C 两次确认退出                                               ║
 * ║    - 显示会话统计                                                      ║
 * ║    - 提示保存会话                                                      ║
 * ║                                                                        ║
 * ║  安装: 复制到 ~/.pi/agent/extensions/enhanced-exit.ts                  ║
 * ║  重载: /reload                                                         ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let firstCtrlC = false;
	let ctrlCTimeout: NodeJS.Timeout | null = null;

	// ───────────────────────────────────────────────────────────────────────
	// 计算会话统计
	// ───────────────────────────────────────────────────────────────────────

	function getSessionStats(ctx: ExtensionContext): {
		turns: number;
		tools: number;
		tokens: { input: number; output: number };
		duration: string;
	} {
		let turns = 0;
		let tools = 0;
		let inputTokens = 0;
		let outputTokens = 0;

		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "message") {
				if (entry.message.role === "user") {
					turns++;
				} else if (entry.message.role === "assistant") {
					const m = entry.message as Record<string, any>;
					if (m.usage) {
						inputTokens += m.usage.input ?? 0;
						outputTokens += m.usage.output ?? 0;
					}
				} else if (entry.message.role === "toolResult") {
					tools++;
				}
			}
		}

		// 计算时长
		const now = Date.now();
		const start = ctx.sessionManager.getSession()?.startTime ?? now;
		const elapsedMs = now - start;
		const minutes = Math.floor(elapsedMs / 60000);
		const seconds = Math.floor((elapsedMs % 60000) / 1000);
		const duration = `${minutes}:${seconds.toString().padStart(2, "0")}`;

		return { turns, tools, tokens: { input: inputTokens, output: outputTokens }, duration };
	}

	// ───────────────────────────────────────────────────────────────────────
	// 拦截 Ctrl+C
	// ───────────────────────────────────────────────────────────────────────

	pi.registerShortcut("ctrl+c", {
		description: "Enhanced exit with confirmation",
		handler: async (_event, ctx: ExtensionContext) => {
			if (!ctx.hasUI) return;  // 非交互模式不拦截

			if (firstCtrlC) {
				// 第二次 Ctrl+C
				if (ctrlCTimeout) {
					clearTimeout(ctrlCTimeout);
					ctrlCTimeout = null;
				}
				firstCtrlC = false;

				// 显示会话统计
				const stats = getSessionStats(ctx);

				const choice = await ctx.ui.select(
					`Exit Session?\n\n` +
					`📊 Stats:\n` +
					`  Turns: ${stats.turns}\n` +
					`  Tools: ${stats.tools}\n` +
					`  Tokens: ${stats.tokens.input.toLocaleString()} in / ${stats.tokens.output.toLocaleString()} out\n` +
					`  Duration: ${stats.duration}\n\n` +
					`Session saved automatically.`,
					["Exit", "Cancel"]
				);

				if (choice === "Exit") {
					// 正常退出
					process.exit(0);
				}
			} else {
				// 第一次 Ctrl+C
				firstCtrlC = true;
				ctx.ui.notify("Press Ctrl+C again to exit", "info");

				// 3 秒后重置
				ctrlCTimeout = setTimeout(() => {
					firstCtrlC = false;
					ctx.ui.setStatus("exit-prompt", "");
				}, 3000);
			}
		},
	});

	// ───────────────────────────────────────────────────────────────────────
	// /exit 命令
	// ───────────────────────────────────────────────────────────────────────

	pi.registerCommand("exit", {
		description: "Exit with session summary",
		handler: async (_args, ctx: ExtensionContext) => {
			if (!ctx.hasUI) {
				process.exit(0);
				return;
			}

			const stats = getSessionStats(ctx);

			const choice = await ctx.ui.select(
				`Exit Session\n\n` +
				`📊 Stats:\n` +
				`  Turns: ${stats.turns}\n` +
				`  Tools: ${stats.tools}\n` +
				`  Tokens: ${stats.tokens.input.toLocaleString()} in / ${stats.tokens.output.toLocaleString()} out\n` +
				`  Duration: ${stats.duration}`,
				["Exit", "Cancel"]
			);

			if (choice === "Exit") {
				process.exit(0);
			}
		},
	});
}