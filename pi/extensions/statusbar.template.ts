/**
 * Pi Custom Status Bar Extension 模板 📊
 *
 * 三行状态栏：模式/Token 信息 / 目录/模型/版本 / 上下文进度条
 *
 * ╔════════════════════════════════════════════════════════════════════════╗
 * ║  安装: 复制到 ~/.pi/agent/extensions/statusbar.ts                     ║
 * ║  重载: /reload                                                        ║
 * ║  切换: /statusbar                                                     ║
 * ╚════════════════════════════════════════════════════════════════════════╝
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import * as path from "node:path";

const BAR_FULL = "█";
const BAR_EMPTY = ["░", "░", "░", "░", "░", "░", "░", "░", "░", "░"];
const SEP = "  │  ";

export default function (pi: ExtensionAPI) {
  let enabled = true;
  let sessionStartTime = Date.now();
  let turnCount = 0;
  let lastContextTokens = 0;
  let lastContextTime = Date.now();
  let agentActive = false;
  let requestRender: (() => void) | null = null;

  // ═════════════════════════════════════════════════════════════════════════
  // 工具函数
  // ═════════════════════════════════════════════════════════════════════════

  function fmt(n: number): string {
    if (n < 1000) return `${n}`;
    if (n < 1_000_000) return `${(n / 1000).toFixed(1)}k`;
    return `${(n / 1_000_000).toFixed(1)}M`;
  }

  type UsageAccum = { input: number; output: number; cacheRead: number; cacheWrite: number; cost: number };

  function accumulateUsage(ctx: ExtensionContext): UsageAccum {
    const u: UsageAccum = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
    for (const e of ctx.sessionManager.getBranch()) {
      if (e.type === "message" && e.message.role === "assistant") {
        const m = e.message as Record<string, any>;
        if (m.usage) {
          u.input += m.usage.input ?? 0;
          u.output += m.usage.output ?? 0;
          u.cacheRead += m.usage.cacheRead ?? 0;
          u.cacheWrite += m.usage.cacheWrite ?? 0;
          u.cost += m.usage.cost?.total ?? 0;
        }
      }
    }
    return u;
  }

  function reRender() {
    if (requestRender) requestRender();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 状态栏注册
  // ═════════════════════════════════════════════════════════════════════════

  function registerFooter(ctx: ExtensionContext) {
    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();

      return {
        dispose() { requestRender = null; },
        invalidate() {},
        render(width: number): string[] {
          const now = Date.now();
          const ctxUsage = ctx.getContextUsage?.() ?? null;
          const currentTokens = ctxUsage?.tokens ?? 0;
          const ctxWindow = ctx.model?.contextWindow ?? 0;
          const ctxPct = ctxWindow > 0 ? Math.min((currentTokens / ctxWindow) * 100, 100) : 0;

          // 速度计算
          const elapsed = (now - lastContextTime) / 1000;
          const diff = currentTokens - lastContextTokens;
          const ctxSpeed = elapsed > 0 ? Math.round(diff / elapsed) : 0;
          lastContextTokens = currentTokens;
          lastContextTime = now;

          // Token 统计
          const u = accumulateUsage(ctx);
          const totalCache = u.cacheRead + u.cacheWrite;
          const cacheRate = u.input + totalCache > 0
            ? Math.round((u.cacheRead / (u.input + totalCache)) * 100)
            : 0;

          // 会话时长
          const elapsedSec = Math.floor((now - sessionStartTime) / 1000);
          const durStr = `${Math.floor(elapsedSec / 60)}:${(elapsedSec % 60).toString().padStart(2, "0")}`;

          // 模型信息
          const modelStr = ctx.model?.id || "no-model";
          const providerStr = ctx.model?.provider || "";
          const ctxInfo = ctxWindow > 0 ? `(${fmt(ctxWindow)})` : "";
          const branch = footerData.getGitBranch() ?? "—";
          const cwdName = path.basename(process.cwd());

          // 上下文进度条
          const barFilled = Math.round(ctxPct / 10);
          let barStr = "";
          for (let i = 0; i < barFilled; i++) barStr += BAR_FULL;
          for (let i = 0; i < 10 - barFilled; i++) barStr += BAR_EMPTY[i];

          const pctColor = ctxPct > 85
            ? theme.fg("error", `${Math.round(ctxPct)}%`)
            : ctxPct > 60
              ? theme.fg("warning", `${Math.round(ctxPct)}%`)
              : theme.fg("success", `${Math.round(ctxPct)}%`);

          // ─── 第一行：模式 + Token 统计 + 速度 + 时长 ─────────────
          const statusLabel = theme.bold(agentActive ? `⚡ Running` : `✓ Idle`);
          const cacheStr = totalCache > 0 ? `C:${fmt(u.cacheRead)} ${cacheRate}%` : "";
          const line1Left = [
            statusLabel,
            `↑${fmt(u.input)}`,
            `↓${fmt(u.output)}`,
            `$${u.cost.toFixed(3)}`,
            cacheStr,
          ].filter(Boolean).join("  ");
          const line1Right = [
            `⚡${fmt(ctxSpeed)}/s`,
            `T${turnCount}`,
            `🏁${durStr}`
          ].join("  ");

          // ─── 第二行：目录 + 模型 + 版本 ──────────────────────
          const line2Left = theme.fg("dim", `⎇${branch}  📁${cwdName}`);
          const line2Right = theme.fg("dim", `${providerStr}/${modelStr}  ${ctxInfo}`);

          // ─── 第三行：上下文进度条 ─────────────────────────────
          const line3 = `Context: ${pctColor}  ${barStr}  ${fmt(currentTokens)} / ${fmt(ctxWindow)}`;

          return [
            truncateToWidth(`${line1Left}${SEP}${line1Right}`, width),
            truncateToWidth(`${line2Left}${SEP}${line2Right}`, width),
            truncateToWidth(line3, width),
          ];
        },
      };
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 事件监听
  // ═════════════════════════════════════════════════════════════════════════

  pi.on("session_start", (_event: any, ctx: ExtensionContext) => {
    sessionStartTime = Date.now();
    turnCount = 0;
    lastContextTokens = 0;
    lastContextTime = Date.now();
    agentActive = false;
    if (enabled) registerFooter(ctx);
  });

  pi.on("turn_start", () => {
    agentActive = true;
    reRender();
  });

  pi.on("turn_end", async () => {
    turnCount++;
    agentActive = false;
    reRender();
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 开关命令
  // ═════════════════════════════════════════════════════════════════════════

  pi.registerCommand("statusbar", {
    description: "Toggle custom status bar",
    handler: async (_args: any, ctx: ExtensionContext) => {
      enabled = !enabled;
      if (enabled) {
        registerFooter(ctx);
        ctx.ui.notify("Status bar enabled", "info");
      } else {
        ctx.ui.setFooter(undefined);
        ctx.ui.notify("Default footer restored", "info");
      }
    },
  });
}