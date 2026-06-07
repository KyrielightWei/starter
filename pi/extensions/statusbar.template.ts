/**
 * Pi Custom Status Bar Extension
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import { truncateToWidth } from "@earendil-works/pi-tui";
import * as path from "node:path";
import * as fs from "node:fs";

const BAR_FULL = "█";
const BAR_EMPTY = "░";
const CHATGPT_BASE_URL = (process.env.CHATGPT_BASE_URL || "https://chatgpt.com/backend-api").replace(/\/+$/, "");
const FIVE_HOUR_SECONDS = 5 * 60 * 60;
const WEEK_SECONDS = 7 * 24 * 60 * 60;

const DEFAULT_CONFIG = {
  maxLines: 4,
  quotaCacheTtlMs: 5 * 60 * 1000,
  showChatGptQuota: true,
  adaptive: true,
};

type UsageSummary = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
  valid: boolean;
  branchLength: number;
};

type ChatGptWindow = {
  usedPercent: number;
  windowSeconds: number;
  resetAt?: number;
};

type ChatGptSnapshot = {
  fiveHour?: ChatGptWindow;
  weekly?: ChatGptWindow;
  fetchedAt: number;
};

type ChatGptAuthResult = {
  ok: boolean;
  apiKey?: string;
};

type ChatGptModelRegistry = {
  getApiKeyAndHeaders(model: NonNullable<ExtensionContext["model"]>): Promise<ChatGptAuthResult>;
};

type ChatGptCache = {
  snapshot?: ChatGptSnapshot;
  status: string;
  fetchedAt: number;
  inFlight: boolean;
  provider?: string;
};

type DisplayMode = "compact" | "normal" | "detailed";

type FooterRenderer = {
  requestRender(): void;
};

type FooterData = {
  onBranchChange(callback: () => void): void;
  getGitBranch(): string | undefined;
};

type BranchEntry = {
  type?: string;
  message?: AssistantMessage;
};

type RenderData = {
  now: number;
  curTok: number;
  ctxWin: number;
  pct: number;
  bar: string;
  usage: UsageSummary;
  cacheTot: number;
  cacheRate: number;
  dur: string;
  modelId: string;
  provider: string;
  fullModel: string;
  thinking: string;
  branch: string;
  cwd: string;
  turnSpeed: number;
  agentActive: boolean;
};

let cachedUsage: UsageSummary = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  cost: 0,
  valid: false,
  branchLength: -1,
};
let modelCosts: Record<string, { input: number; output: number }> = {};
let sessionStartTime = Date.now();
let turnStartTime = Date.now();
let turnStartTokens = 0;
let agentActive = false;
let turnSpeed = 0;
let currentModel = "";
let requestFooterRender = function() {};
let chatGptCache: ChatGptCache = {
  status: "",
  fetchedAt: 0,
  inFlight: false,
};

function fmt(n: number): string {
  if (n < 1000) return String(n);
  if (n < 1000000) return (n / 1000).toFixed(1) + "k";
  return (n / 1000000).toFixed(1) + "M";
}

function emptyUsage(branchLength = -1): UsageSummary {
  return {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    cost: 0,
    valid: false,
    branchLength,
  };
}

function loadModelCosts(): Record<string, { input: number; output: number }> {
  if (Object.keys(modelCosts).length > 0) return modelCosts;

  const home = process.env.HOME || "/root";
  const modelsPath = path.join(home, ".pi/agent/models.json");

  try {
    if (!fs.existsSync(modelsPath)) return modelCosts;

    const content = fs.readFileSync(modelsPath, "utf8");
    const models = JSON.parse(content) as unknown;
    const root = asRecord(models);
    const providers = asRecord(root?.providers);
    if (!providers) return modelCosts;

    Object.keys(providers).forEach(function(providerKey) {
      const provider = asRecord(providers[providerKey]);
      const providerModels = provider?.models;
      if (!Array.isArray(providerModels)) return;

      providerModels.forEach(function(model) {
        const record = asRecord(model);
        const cost = asRecord(record?.cost);
        if (typeof record?.id !== "string" || !cost) return;

        modelCosts[record.id] = {
          input: typeof cost.input === "number" ? cost.input : 0,
          output: typeof cost.output === "number" ? cost.output : 0,
        };
      });
    });
  } catch (_error) {
    // 忽略模型价格文件解析错误，状态栏应保持可用。
  }

  return modelCosts;
}

function calculateCost(input: number, output: number, modelId: string): number {
  const costs = loadModelCosts();
  const mc = costs[modelId] || { input: 0, output: 0 };
  return (input / 1000000) * mc.input + (output / 1000000) * mc.output;
}

function isOpenAICodexProvider(provider: string | undefined): boolean {
  return provider === "openai-codex" || /^openai-codex-\d+$/.test(provider || "");
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
  return value as Record<string, unknown>;
}

function normalizeWindow(value: unknown): ChatGptWindow | undefined {
  const record = asRecord(value);
  if (!record) return undefined;

  const usedPercent = typeof record.used_percent === "number" ? record.used_percent : undefined;
  const windowSeconds = typeof record.limit_window_seconds === "number" ? record.limit_window_seconds : undefined;
  const resetAt = typeof record.reset_at === "number" ? record.reset_at : undefined;

  if (usedPercent === undefined || windowSeconds === undefined) return undefined;
  return { usedPercent, windowSeconds, resetAt };
}

function parseChatGptSnapshot(data: unknown): ChatGptSnapshot {
  const raw = asRecord(data);
  const rateLimit = asRecord(raw?.rate_limit);
  const windows = [
    normalizeWindow(rateLimit?.primary_window),
    normalizeWindow(rateLimit?.secondary_window),
  ].filter((window): window is ChatGptWindow => Boolean(window));

  return {
    fiveHour: windows.find((window) => Math.abs(window.windowSeconds - FIVE_HOUR_SECONDS) <= 120),
    weekly: windows.find((window) => Math.abs(window.windowSeconds - WEEK_SECONDS) <= 120),
    fetchedAt: Date.now(),
  };
}

function formatPercent(window: ChatGptWindow | undefined): string {
  if (!window) return "?%";
  return Math.round(Math.max(0, Math.min(100, window.usedPercent))) + "%";
}

function formatReset(resetAt: number | undefined): string {
  if (!resetAt) return "?";

  const minutes = Math.max(0, Math.round((resetAt * 1000 - Date.now()) / 60000));
  const days = Math.floor(minutes / (60 * 24));
  const hours = Math.floor((minutes % (60 * 24)) / 60);
  if (days > 0) return "~" + days + "d";
  if (hours > 0) return "~" + hours + "h";
  return "~" + minutes + "m";
}

function chatGptColor(window: ChatGptWindow | undefined): string {
  const used = Math.max(0, Math.min(100, window?.usedPercent ?? 0));
  if (used >= 90) return "error";
  if (used >= 80) return "warning";
  return "success";
}

function isQuotaFresh(provider: string | undefined, now = Date.now()): boolean {
  return Boolean(chatGptCache.snapshot)
    && chatGptCache.provider === provider
    && now - chatGptCache.fetchedAt < DEFAULT_CONFIG.quotaCacheTtlMs;
}

function shouldFetchQuota(ctx: ExtensionContext, force: boolean): boolean {
  const provider = ctx.model?.provider;
  if (!isOpenAICodexProvider(provider)) return false;
  if (chatGptCache.inFlight) return false;
  if (force) return true;
  return !isQuotaFresh(provider);
}

function clearChatGptQuota(): void {
  chatGptCache = {
    status: "",
    fetchedAt: 0,
    inFlight: false,
  };
}

async function requestChatGptUsage(ctx: ExtensionContext, force: boolean): Promise<void> {
  const model = ctx.model;
  if (!model || !isOpenAICodexProvider(model.provider)) {
    clearChatGptQuota();
    requestFooterRender();
    return;
  }

  if (!shouldFetchQuota(ctx, force)) {
    requestFooterRender();
    return;
  }

  const previousSnapshot = chatGptCache.snapshot;
  chatGptCache = {
    snapshot: previousSnapshot,
    status: previousSnapshot ? "refreshing..." : "loading...",
    fetchedAt: chatGptCache.fetchedAt,
    inFlight: true,
    provider: model.provider,
  };
  requestFooterRender();

  try {
    const registry = ctx.modelRegistry as unknown as ChatGptModelRegistry;
    const auth = await registry.getApiKeyAndHeaders(model);
    if (!auth.ok || !auth.apiKey) {
      chatGptCache = {
        snapshot: previousSnapshot,
        status: previousSnapshot ? "stale: unavailable" : "unavailable",
        fetchedAt: chatGptCache.fetchedAt,
        inFlight: false,
        provider: model.provider,
      };
      requestFooterRender();
      return;
    }

    const response = await fetch(CHATGPT_BASE_URL + "/wham/usage", {
      headers: {
        Authorization: "Bearer " + auth.apiKey,
        Accept: "application/json",
        "User-Agent": "pi-statusbar",
      },
    });
    if (!response.ok) throw new Error("HTTP " + response.status);

    const snapshot = parseChatGptSnapshot(await response.json());
    chatGptCache = {
      snapshot,
      status: "",
      fetchedAt: snapshot.fetchedAt,
      inFlight: false,
      provider: model.provider,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "error";
    chatGptCache = {
      snapshot: previousSnapshot,
      status: previousSnapshot ? "stale: " + message : "error: " + message,
      fetchedAt: chatGptCache.fetchedAt,
      inFlight: false,
      provider: model.provider,
    };
  }

  requestFooterRender();
}

function queueChatGptUsageUpdate(ctx: ExtensionContext, force = false): void {
  void requestChatGptUsage(ctx, force).catch(function(error: unknown) {
    const message = error instanceof Error ? error.message : "error";
    chatGptCache = {
      snapshot: chatGptCache.snapshot,
      status: chatGptCache.snapshot ? "stale: " + message : "error: " + message,
      fetchedAt: chatGptCache.fetchedAt,
      inFlight: false,
      provider: ctx.model?.provider,
    };
    requestFooterRender();
  });
}

function speedColor(speed: number, active: boolean): string {
  if (!active) return "dim";
  if (speed < 100) return "warning";
  if (speed <= 3000) return "success";
  if (speed <= 8000) return "accent";
  return "error";
}

function contextColor(pct: number): string {
  if (pct > 85) return "error";
  if (pct > 60) return "warning";
  return "success";
}

function getUsage(ctx: ExtensionContext): UsageSummary {
  const branch = ctx.sessionManager.getBranch() as BranchEntry[];
  if (cachedUsage.valid && cachedUsage.branchLength === branch.length) return cachedUsage;

  const nextUsage = emptyUsage(branch.length);
  nextUsage.valid = true;
  currentModel = ctx.model?.id || "";

  branch.forEach(function(e) {
    if (e.type !== "message" || !e.message || e.message.role !== "assistant") return;

    const m = e.message as AssistantMessage;
    if (!m.usage) return;

    nextUsage.input += m.usage.input || 0;
    nextUsage.output += m.usage.output || 0;
    nextUsage.cacheRead += m.usage.cacheRead || 0;
    nextUsage.cacheWrite += m.usage.cacheWrite || 0;

    const usageRecord = asRecord(m.usage);
    const costRecord = asRecord(usageRecord?.cost);
    const apiCost = typeof costRecord?.total === "number" ? costRecord.total : 0;
    if (apiCost > 0) {
      nextUsage.cost += apiCost;
    } else {
      nextUsage.cost += calculateCost(m.usage.input || 0, m.usage.output || 0, currentModel);
    }
  });

  cachedUsage = nextUsage;
  return cachedUsage;
}

function renderChatGptLine(theme: ExtensionContext["ui"]["theme"]): string | undefined {
  if (!DEFAULT_CONFIG.showChatGptQuota) return undefined;
  if (!chatGptCache.snapshot && !chatGptCache.status) return undefined;

  const status = chatGptCache.status ? theme.fg("dim", " (" + chatGptCache.status + ")") : "";
  if (!chatGptCache.snapshot) return theme.fg("dim", "ChatGPT: " + chatGptCache.status);

  const fiveHour = chatGptCache.snapshot.fiveHour;
  const weekly = chatGptCache.snapshot.weekly;
  const parts = [
    fiveHour ? theme.fg(chatGptColor(fiveHour), "5h " + formatPercent(fiveHour) + " / " + formatReset(fiveHour.resetAt)) : "",
    weekly ? theme.fg(chatGptColor(weekly), "W " + formatPercent(weekly) + " / " + formatReset(weekly.resetAt)) : "",
  ].filter(Boolean);

  return parts.length > 0 ? "ChatGPT: " + parts.join(theme.fg("dim", " / ")) + status : undefined;
}

function buildRenderData(ctx: ExtensionContext, pi: ExtensionAPI, footerData: FooterData): RenderData {
  const now = Date.now();
  const contextUsage = ctx.getContextUsage?.();
  const curTok = contextUsage?.tokens || 0;
  const ctxWin = ctx.model?.contextWindow || 200000;
  const pct = ctxWin > 0 ? Math.min((curTok / ctxWin) * 100, 100) : 0;

  if (agentActive) {
    const turnElapsed = (now - turnStartTime) / 1000;
    if (turnElapsed > 0.5) {
      const delta = Math.max(0, curTok - turnStartTokens);
      turnSpeed = Math.round(delta / turnElapsed);
    }
  }

  const usage = getUsage(ctx);
  const cacheTot = usage.cacheRead + usage.cacheWrite;
  const cacheRate = usage.input + cacheTot > 0 ? Math.round((usage.cacheRead / (usage.input + cacheTot)) * 100) : 0;
  const sec = Math.floor((now - sessionStartTime) / 1000);
  const dur = Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0");
  const modelId = ctx.model?.id || "no-model";
  const provider = ctx.model?.provider || "";
  const filled = Math.round(pct / 10);

  return {
    now,
    curTok,
    ctxWin,
    pct,
    bar: BAR_FULL.repeat(filled) + BAR_EMPTY.repeat(10 - filled),
    usage,
    cacheTot,
    cacheRate,
    dur,
    modelId,
    provider,
    fullModel: provider ? provider + "/" + modelId : modelId,
    thinking: pi.getThinkingLevel() || "off",
    branch: footerData.getGitBranch() || "-",
    cwd: path.basename(process.cwd()),
    turnSpeed,
    agentActive,
  };
}

function renderPrimaryLine(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string {
  const statColor = data.agentActive ? theme.fg("accent", "run") : theme.fg("success", "idle");
  const tokInStr = theme.fg("muted", "in:" + fmt(data.usage.input));
  const tokOutStr = theme.fg("muted", "out:" + fmt(data.usage.output));
  const costStr = "$" + data.usage.cost.toFixed(4);
  const cacheStr = data.cacheTot > 0 ? theme.fg("success", "C:" + fmt(data.usage.cacheRead) + " " + data.cacheRate + "%") : "";
  return [statColor, tokInStr, tokOutStr, costStr, cacheStr].filter(Boolean).join("  ");
}

function renderSessionLine(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string {
  const tiColors: Record<string, string> = {
    off: "dim",
    minimal: "thinkingMinimal",
    low: "thinkingLow",
    medium: "thinkingMedium",
    high: "thinkingHigh",
    xhigh: "thinkingXhigh",
  };
  const spStr = theme.fg(speedColor(data.turnSpeed, data.agentActive), "speed:" + fmt(data.turnSpeed) + "/s");
  const durStr = theme.fg("dim", "dur:" + data.dur);
  const branchStr = theme.fg("success", "git:" + data.branch);
  const cwdStr = theme.fg("muted", "dir:" + data.cwd);
  const modelStr = theme.fg("accent", data.fullModel);
  const tiStr = theme.fg(tiColors[data.thinking] || "dim", "think:" + data.thinking);

  return [spStr, durStr, branchStr, cwdStr, modelStr, tiStr].join("  ");
}

function renderContextLine(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string {
  const pctCol = contextColor(data.pct);
  const pctNum = Math.round(data.pct);
  const pctStr = theme.fg(pctCol, pctNum + "%");
  const barStr = theme.fg(pctCol, data.bar);
  const tokStr = theme.fg("muted", fmt(data.curTok) + "/" + fmt(data.ctxWin));
  return "Ctx: " + pctStr + " " + barStr + " " + tokStr;
}

function renderCompactLines(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string[] {
  const status = data.agentActive ? theme.fg("accent", "run") : theme.fg("success", "idle");
  const pctCol = contextColor(data.pct);
  const ctxStr = theme.fg(pctCol, "Ctx " + Math.round(data.pct) + "%");
  const speedStr = theme.fg(speedColor(data.turnSpeed, data.agentActive), "speed:" + fmt(data.turnSpeed) + "/s");
  const branchStr = theme.fg("success", "git:" + data.branch);
  return [[status, ctxStr, speedStr, branchStr].join("  ")];
}

function renderNormalLines(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string[] {
  const pctCol = contextColor(data.pct);
  const status = data.agentActive ? theme.fg("accent", "run") : theme.fg("success", "idle");
  const ctxStr = theme.fg(pctCol, "Ctx " + Math.round(data.pct) + "%");
  const speedStr = theme.fg(speedColor(data.turnSpeed, data.agentActive), "speed:" + fmt(data.turnSpeed) + "/s");
  const tokenStr = theme.fg("muted", "in:" + fmt(data.usage.input) + " out:" + fmt(data.usage.output));
  const costStr = "$" + data.usage.cost.toFixed(4);
  const sessionBits = [
    theme.fg("dim", "dur:" + data.dur),
    theme.fg("success", "git:" + data.branch),
    theme.fg("muted", "dir:" + data.cwd),
    theme.fg("accent", data.fullModel),
    theme.fg("dim", "think:" + data.thinking),
  ];

  return [
    [status, ctxStr, speedStr, tokenStr, costStr].join("  "),
    sessionBits.join("  "),
  ];
}

function renderDetailedLines(data: RenderData, theme: ExtensionContext["ui"]["theme"]): string[] {
  const lines = [
    renderPrimaryLine(data, theme),
    renderSessionLine(data, theme),
    renderContextLine(data, theme),
  ];
  const chatGptLine = renderChatGptLine(theme);
  if (chatGptLine) lines.push(chatGptLine);
  return lines;
}

function getDisplayMode(width: number): DisplayMode {
  if (!DEFAULT_CONFIG.adaptive) return "detailed";
  if (width < 70) return "compact";
  if (width < 120) return "normal";
  return "detailed";
}

function renderLines(data: RenderData, theme: ExtensionContext["ui"]["theme"], width: number): string[] {
  const mode = getDisplayMode(width);
  const lines = mode === "compact"
    ? renderCompactLines(data, theme)
    : mode === "normal"
      ? renderNormalLines(data, theme)
      : renderDetailedLines(data, theme);

  return lines.slice(0, DEFAULT_CONFIG.maxLines).map(function(line) {
    return truncateToWidth(line, width);
  });
}

export default function(pi: ExtensionAPI) {
  let enabled = true;

  pi.on("session_start", function(_event: unknown, ctx: ExtensionContext) {
    sessionStartTime = Date.now();
    turnStartTime = Date.now();
    turnStartTokens = 0;
    agentActive = false;
    turnSpeed = 0;
    cachedUsage = emptyUsage();
    currentModel = "";

    if (!enabled) return;

    ctx.ui.setFooter(function(tui: FooterRenderer, theme: ExtensionContext["ui"]["theme"], footerData: FooterData) {
      requestFooterRender = function() {
        tui.requestRender();
      };
      footerData.onBranchChange(function() {
        tui.requestRender();
      });

      return {
        dispose: function() {},
        invalidate: function() {},
        render: function(w: number): string[] {
          const data = buildRenderData(ctx, pi, footerData);
          return renderLines(data, theme, w);
        },
      };
    });

    queueChatGptUsageUpdate(ctx, false);
  });

  pi.on("model_select", function(_event: unknown, ctx: ExtensionContext) {
    queueChatGptUsageUpdate(ctx, true);
  });

  pi.on("turn_start", function(_event: unknown, ctx: ExtensionContext) {
    agentActive = true;
    turnStartTime = Date.now();
    const usage = ctx.getContextUsage?.();
    turnStartTokens = usage?.tokens || 0;
    turnSpeed = 0;
  });

  pi.on("turn_end", function(_event: unknown, ctx: ExtensionContext) {
    agentActive = false;
    cachedUsage.valid = false;
    queueChatGptUsageUpdate(ctx, false);
  });

  pi.registerCommand("statusbar", {
    description: "Toggle status bar",
    handler: function(_args: unknown, ctx: ExtensionContext) {
      enabled = !enabled;
      if (!enabled) {
        ctx.ui.setFooter(undefined);
      }
      ctx.ui.notify(enabled ? "Status bar on" : "Status bar off", "info");
      return Promise.resolve();
    },
  });
}
