/**
 * Enhanced Exit Extension
 * 显示 session 信息和 resume 提示
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as path from "node:path";

export default function (pi: ExtensionAPI) {
  // 注册 /exit 命令
  pi.registerCommand("exit", {
    description: "退出 pi，显示 session resume 信息",
    handler: async (_args, ctx) => {
      ctx.shutdown();
    },
  });

  // 退出时显示 session 信息
  pi.on("session_shutdown", async (event, ctx) => {
    if (event.reason !== "quit") return;

    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!sessionFile) {
      // 无 session（ephemeral mode）
      console.log("\n👋 Session was ephemeral (not saved)\n");
      return;
    }

    // 获取 session ID（真正的 sessionId，而不是文件名时间戳前缀）
    const sessionId = ctx.sessionManager.getSessionId();
    // 生成短 ID（前 8 位）用于显示和 resume 命令
    const shortId = sessionId.slice(0, 8);

    // 获取 session name（如果有）
    const sessionName = pi.getSessionName();

    // 获取工作目录
    const cwd = ctx.cwd;
    const projectDir = path.basename(cwd);

    console.log("\n" + "─".repeat(50));
    console.log("👋 Session saved");
    console.log("─".repeat(50));

    if (sessionName) {
      console.log(`  Name: ${sessionName}`);
    }
    console.log(`  ID:   ${sessionId} (${shortId} for resume)`);
    console.log(`  File: ${sessionFile}`);
    console.log(`  Project: ${projectDir}`);
    console.log("\nResume commands:");
    console.log(`  pi -c                 # Continue most recent`);
    console.log(`  pi -r                 # Browse sessions`);
    console.log(`  pi --session ${shortId}    # Resume this session`);
    console.log("─".repeat(50) + "\n");
  });
}