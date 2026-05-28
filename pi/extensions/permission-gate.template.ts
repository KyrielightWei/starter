/**
 * Permission Gate Extension 模板 ⚠️
 *
 * 安全防线扩展，统一处理危险命令和路径保护
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  功能:                                                                  ║
 * ║    1. 危险命令拦截 (rm -rf, sudo, chmod 777, dd, mkfs 等)               ║
 * ║       - 弹出确认对话框，用户可选择允许                                   ║
 * ║                                                                        ║
 * ║    2. 敏感文件保护 (.env, id_rsa, credentials 等)                      ║
 * ║       - 弹出确认对话框，用户可选择允许                                   ║
 * ║                                                                        ║
 * ║    3. 系统路径保护 (.git/, node_modules/)                              ║
 * ║       - 直接阻止，不给用户选择（防止破坏项目结构）                       ║
 * ║                                                                        ║
 * ║  安装: 复制到 ~/.pi/agent/extensions/permission-gate.ts                 ║
 * ║  重载: /reload                                                         ║
 * ║                                                                        ║
 * ║  注: 此扩展整合了 protected-paths.ts 的功能，无需同时安装               ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// ───────────────────────────────────────────────────────────────────────
	// 危险命令模式（弹出确认框）
	// ───────────────────────────────────────────────────────────────────────

	const dangerousPatterns = [
		/\brm\s+(-rf?|--recursive)/i,  // rm -rf
		/\bsudo\b/i,                   // sudo
		/\b(chmod|chown)\b.*777/i,     // chmod/chown 777
		/\bdd\b/i,                     // dd (磁盘操作)
		/\bmkfs\b/i,                   // mkfs (格式化)
		/\bshutdown\b/i,               // shutdown
		/\breboot\b/i,                 // reboot
		/\bfdisk\b/i,                  // fdisk (分区)
		/\bparted\b/i,                 // parted (分区)
	];

	// ───────────────────────────────────────────────────────────────────────
	// 敏感文件路径（弹出确认框，用户可选择允许）
	// ───────────────────────────────────────────────────────────────────────

	const sensitivePaths = [
		".env",
		".env.local",
		".env.production",
		".env.development",
		"id_rsa",
		"id_rsa.pub",
		"id_ed25519",
		"id_ed25519.pub",
		".pem",
		".key",
		".ssh/",
		"credentials",
		"secrets",
		"secret",
		"password",
		"apikey",
		"api_key",
	];

	// ───────────────────────────────────────────────────────────────────────
	// 系统路径保护（直接阻止，不给用户选择）
	// 防止破坏项目结构，避免不可逆损坏
	// ───────────────────────────────────────────────────────────────────────

	const protectedPaths = [
		".git/",        // Git 仓库核心
		".git/config",  // Git 配置
		"node_modules/", // 依赖目录（破坏后需重装）
		".pi/",         // Pi 项目配置
	];

	// ───────────────────────────────────────────────────────────────────────
	// 检测危险 bash 命令
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return undefined;

		const command = event.input.command as string;

		// 1. 检测系统路径保护（直接阻止）
		const isProtected = protectedPaths.some((p) => command.includes(p));
		if (isProtected) {
			if (ctx.hasUI) {
				ctx.ui.notify(`⛔ System path protected: command blocked`, "error");
			}
			return { block: true, reason: `System path is protected and cannot be modified` };
		}

		// 2. 检测危险命令（弹出确认框）
		const isDangerous = dangerousPatterns.some((p) => p.test(command));
		if (isDangerous) {
			if (!ctx.hasUI) {
				return { block: true, reason: "Dangerous command blocked (no UI for confirmation)" };
			}

			const choice = await ctx.ui.select(
				`⚠️ Dangerous command:\n\n  ${command}\n\nAllow?`,
				["Yes", "No", "View details"]
			);

			if (choice === "No") {
				return { block: true, reason: "Blocked by user" };
			}

			if (choice === "View details") {
				const confirm = await ctx.ui.confirm(
					"Command Details",
					"This command may:\n• Delete files permanently\n• Modify system settings\n• Expose sensitive data\n\nProceed?"
				);
				if (!confirm) {
					return { block: true, reason: "Blocked after viewing details" };
				}
			}
		}

		// 3. 检测敏感文件操作（弹出确认框）
		const hasSensitivePath = sensitivePaths.some((p) => command.includes(p));
		if (hasSensitivePath) {
			if (!ctx.hasUI) {
				return { block: true, reason: "Sensitive file operation blocked (no UI)" };
			}

			const choice = await ctx.ui.select(
				`⚠️ Command touches sensitive file:\n\n  ${command}\n\nAllow?`,
				["Yes", "No"]
			);

			if (choice === "No") {
				return { block: true, reason: "Sensitive file blocked by user" };
			}
		}

		return undefined;
	});

	// ───────────────────────────────────────────────────────────────────────
	// 检测文件写入操作 (write/edit)
	// ───────────────────────────────────────────────────────────────────────

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "write" && event.toolName !== "edit") return undefined;

		const path = event.input.path as string;

		// 1. 系统路径保护（直接阻止）
		const isProtected = protectedPaths.some((p) => path.includes(p));
		if (isProtected) {
			if (ctx.hasUI) {
				ctx.ui.notify(`⛔ System path "${path}" is protected`, "error");
			}
			return { block: true, reason: `System path "${path}" is protected` };
		}

		// 2. 敏感文件保护（弹出确认框）
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