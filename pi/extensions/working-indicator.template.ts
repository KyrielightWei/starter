/**
 * Working Indicator Extension 模板 ⏳
 *
 * 在 agent 工作时显示进度指示器
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  功能:                                                                  ║
 * ║    - turn 开始时显示 "Working..."                                       ║
 * ║    - 显示工具调用进度                                                   ║
 * ║    - turn 结束时清除                                                   ║
 * ║                                                                        ║
 * ║  安装: 复制到 ~/.pi/agent/extensions/working-indicator.ts               ║
 * ║  重载: /reload                                                         ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const WORKING_TEXT = "Working";

export default function (pi: ExtensionAPI) {
	let spinnerIndex = 0;
	let toolCount = 0;
	let currentTool = "";
	let statusKey = "working-indicator";

	// ───────────────────────────────────────────────────────────────────────
	// 更新状态显示
	// ───────────────────────────────────────────────────────────────────────

	function updateStatus(ctx: ExtensionContext) {
		const frame = SPINNER_FRAMES[spinnerIndex];
		spinnerIndex = (spinnerIndex + 1) % SPINNER_FRAMES.length;

		let text = `${frame} ${WORKING_TEXT}`;
		if (currentTool) {
			text += ` (${currentTool})`;
		}
		if (toolCount > 0) {
			text += ` [${toolCount} tools]`;
		}

		ctx.ui.setStatus(statusKey, text);
	}

	// ───────────────────────────────────────────────────────────────────────
	// turn 开始
	// ───────────────────────────────────────────────────────────────────────

	pi.on("turn_start", async (_event, ctx: ExtensionContext) => {
		toolCount = 0;
		currentTool = "";
		updateStatus(ctx);
	});

	// ───────────────────────────────────────────────────────────────────────
	// 工具调用
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_call", async (event, ctx: ExtensionContext) => {
		toolCount++;
		currentTool = event.toolName;
		updateStatus(ctx);
	});

	// ───────────────────────────────────────────────────────────────────────
	// 工具完成
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_result", async (_event, ctx: ExtensionContext) => {
		currentTool = "";
		updateStatus(ctx);
	});

	// ───────────────────────────────────────────────────────────────────────
	// turn 结束
	// ───────────────────────────────────────────────────────────────────────

	pi.on("turn_end", async (_event, ctx: ExtensionContext) => {
		ctx.ui.setStatus(statusKey, "");  // 清除状态
		toolCount = 0;
		currentTool = "";
	});

	// ───────────────────────────────────────────────────────────────────────
	// 错误时清除
	// ───────────────────────────────────────────────────────────────────────

	pi.on("error", async (_event, ctx: ExtensionContext) => {
		ctx.ui.setStatus(statusKey, "");
	});
}