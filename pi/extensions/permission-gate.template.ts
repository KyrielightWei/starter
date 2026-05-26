/**
 * Permission Gate Extension 模板 ⚠️
 *
 * 在执行危险命令前提示确认
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  功能:                                                                  ║
 * ║    - 检测危险 bash 命令 (rm -rf, sudo, chmod/chown 777)                ║
 * ║    - 弹出确认对话框                                                     ║
 * ║                                                                        ║
 * ║  安装: 复制到 ~/.pi/agent/extensions/permission-gate.ts                 ║
 * ║  重载: /reload                                                         ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// 危险命令模式
	const dangerousPatterns = [
		/\brm\s+(-rf?|--recursive)/i,  // rm -rf
		/\bsudo\b/i,                   // sudo
		/\b(chmod|chown)\b.*777/i,     // chmod/chown 777
		/\bdd\b/i,                     // dd (磁盘操作)
		/\bmkfs\b/i,                   // mkfs (格式化)
		/\bshutdown\b/i,               // shutdown
		/\breboot\b/i,                 // reboot
	];

	// 敏感文件路径
	const sensitivePaths = [
		".env",
		".env.local",
		".env.production",
		"id_rsa",
		"id_ed25519",
		".ssh/",
		".git/config",
		"credentials",
		"secrets",
	];

	// ───────────────────────────────────────────────────────────────────────
	// 检测危险 bash 命令
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return undefined;

		const command = event.input.command as string;

		// 检测危险命令
		const isDangerous = dangerousPatterns.some((p) => p.test(command));

		// 检测敏感文件写入
		const hasSensitivePath = sensitivePaths.some((p) => command.includes(p));

		if (isDangerous || hasSensitivePath) {
			if (!ctx.hasUI) {
				// 非交互模式，默认阻止
				return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
			}

			// 弹出确认对话框
			const choice = await ctx.ui.select(
				`⚠️ Dangerous command:\n\n  ${command}\n\nAllow?`,
				["Yes", "No", "View details"]
			);

			if (choice === "No") {
				return { block: true, reason: "Blocked by user" };
			}

			if (choice === "View details") {
				// 显示详情后再次确认
				const confirm = await ctx.ui.confirm(
					"Command Details",
					"This command may:\n• Delete files permanently\n• Modify system settings\n• Expose sensitive data\n\nProceed?"
				);
				if (!confirm) {
					return { block: true, reason: "Blocked after viewing details" };
				}
			}
		}

		return undefined;
	});

	// ───────────────────────────────────────────────────────────────────────
	// 检测敏感文件写入
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "write" && event.toolName !== "edit") return undefined;

		const path = event.input.path as string;

		// 检测敏感文件
		const isSensitive = sensitivePaths.some((p) => path.includes(p));

		if (isSensitive) {
			if (!ctx.hasUI) {
				return { block: true, reason: `Sensitive file blocked: ${path}` };
			}

			const choice = await ctx.ui.select(
				`⚠️ Sensitive file: ${path}\n\nAllow modification?`,
				["Yes", "No"]
			);

			if (choice === "No") {
				return { block: true, reason: "Sensitive file blocked by user" };
			}
		}

		return undefined;
	});
}