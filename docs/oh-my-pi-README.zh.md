# Oh My Pi README 中文翻译

> 原仓库：<https://github.com/can1357/oh-my-pi>  
> 原文：`README.md`  
> 本文为便于阅读的中文翻译。

<p align="center">
  <img src="https://github.com/can1357/oh-my-pi/blob/main/assets/hero.png?raw=true" alt="omp">
</p>

<p align="center">
  <strong>一个与 IDE 深度连接的编码 agent。</strong>
  <strong><a href="https://omp.sh">omp.sh</a></strong>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent"><img src="https://img.shields.io/npm/v/@oh-my-pi/pi-coding-agent?style=flat&colorA=222222&colorB=CB3837" alt="npm version"></a>
  <a href="https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/CHANGELOG.md"><img src="https://img.shields.io/badge/changelog-keep-E05735?style=flat&colorA=222222" alt="Changelog"></a>
  <a href="https://github.com/can1357/oh-my-pi/actions"><img src="https://img.shields.io/github/actions/workflow/status/can1357/oh-my-pi/ci.yml?style=flat&colorA=222222&colorB=3FB950" alt="CI"></a>
  <a href="https://github.com/can1357/oh-my-pi/blob/main/LICENSE"><img src="https://img.shields.io/github/license/can1357/oh-my-pi?style=flat&colorA=222222&colorB=58A6FF" alt="License"></a>
</p>

<p align="center">
  Fork 自 <a href="https://github.com/badlogic/pi-mono">Pi</a>，原作者 <a href="https://github.com/mariozechner">@mariozechner</a>。
</p>

这是一个已经发布的、能力非常完整的 agent 界面。它基于真实使用场景持续调优——开箱即用，并且从上到下完全开源。

**40+** 提供商 · **32** 个内置工具 · **14** 个 LSP 操作 · **28** 个 DAP 操作 · **约 55k** 行 Rust 核心代码。

## 安装

**macOS · Linux**

```sh
curl -fsSL https://omp.sh/install | sh
```

**Homebrew**

```sh
brew install can1357/tap/omp
```

**Bun（推荐）**

```sh
bun install -g @oh-my-pi/pi-coding-agent
```

**Windows（PowerShell）**

```powershell
irm https://omp.sh/install.ps1 | iex
```

**固定版本（mise）**

```sh
mise use -g github:can1357/oh-my-pi
```

支持 macOS、Linux、Windows；要求 bun ≥ 1.3.14。

### Shell 补全

`omp` 会从实时命令/flag 元数据生成自己的 **bash**、**zsh** 和 **fish** 补全脚本，因此不会和实际 CLI 脱节。子命令、flag 和枚举值会静态补全；模型名（`--model`、`--smol`、`--slow`、`--plan`）会根据内置模型目录解析，`--resume` 会根据磁盘上的会话解析。

```sh
# zsh — 加到 ~/.zshrc（或把输出写入 $fpath 中的文件）
eval "$(omp completions zsh)"

# bash — 加到 ~/.bashrc
eval "$(omp completions bash)"

# fish
omp completions fish > ~/.config/fish/completions/omp.fish
```

## 每个工具都做了 benchmark 级调优

编辑第一次就成功。读取文件时返回摘要而不是直接倾倒全文。搜索即时返回。任选模型——omp 会尽力让它用对工具。

| 模型 | 指标 | 含义 |
| --- | --- | --- |
| Grok Code Fast 1 | 6.7% → 68.3% | 当编辑格式不再拖垮模型时，成功率提升十倍。 |
| Gemini 3 Flash | +5 pp | 超过 str_replace，也超过 Google 对该格式的最佳尝试。 |
| Grok 4 Fast | −61% tokens | 坏 diff 重试循环消失后，输出 token 大幅下降。 |
| MiniMax | 2.1× | 通过率翻倍以上。权重相同，prompt 相同。 |

- `read`：摘要化片段、理想默认值、selector 命中率
- `search`：极快搜索
- `lsp`：IDE 知道的一切，agent 也知道
- `prompts`：针对每个模型持续调优

[阅读完整文章 ↗](https://blog.can.ac/2026/02/12/the-harness-problem/)

## 你喜欢的 Pi，加上完整电池包

omp 最初基于 [Mario Zechner](https://github.com/mariozechner) 的优秀项目 [Pi](https://github.com/badlogic/pi-mono)，并补上了许多缺失能力。

### 01 · 带 tool-calling 的代码执行

多数 harness 给 agent 一个 Python 沙箱就结束了。omp 运行持久 Python 和 Bun worker，并且两个 kernel 都可以通过 loopback bridge 回调 agent 自身的工具——例如 read、search、task。agent 可以在 Python 内部用 `tool.read` 加载 CSV，在 JavaScript 中画图，而无需离开 cell。

### 02 · 每次写入都连接 LSP

要求重命名就会真正执行重命名。调用会经过 `workspace/willRenameFiles`，因此 re-export、barrel file、别名 import 都会在文件移动前更新。IDE 知道的一切，agent 也知道。

### 03 · 驱动真实调试器

C 二进制崩溃时，agent 会 attach lldb，step 到坏指针，读取栈帧。Go 服务卡住时，它会 attach dlv 查看 goroutine。Python 进程卡住时，它会用 debugpy 暂停、检查、求值。多数 agent 还在到处加 print。

### 04 · 可“时间旅行”的流式规则

规则平时不占用上下文，直到模型跑偏。正则匹配会在 token 流中途 abort，请求中注入系统提醒，并从同一点重试。这样可以修正方向，而不用每轮都支付上下文成本。注入规则会在 compaction 后继续保留。

### 05 · 一等公民的 subagent

把任务拆给多个 worker，得到 typed result。`task` 可以 fan out 到隔离 worktree，每个 worker 使用自己的工具面，最终产出 schema-validated 对象，父 agent 可以直接读取。无需解析散文，也避免兄弟 worker 间的 merge conflict 和孤儿编辑。

### 06 · 每一轮都有第二个模型旁观

把 reviewer 模型绑定到 `advisor` 角色，它会阅读主 agent 的每一轮操作，并内联注入建议——可能是轻声提醒、风险担忧或硬性阻断。它运行在自己的上下文和模型上，因此能发现执行者匆忙略过的问题。主 agent 会看到备注并修正，或者说明为什么不采纳。

### 07 · 给别人一个链接，就能加入

`/collab` 会把当前 live session 放到 relay 上并返回链接和二维码。队友可以从另一个终端用 `omp join` 加入，也可以在浏览器中打开。可以共享读写来一起控制同一个 agent，也可以用 `/collab view` 生成只读观看链接。帧在客户端加密，relay 看不到密钥。

### 08 · 读取 arXiv PDF，也没问题

`web_search` 串联 14 个排名提供商，把找到的 URL 直接交给 `read`。arXiv PDF、GitHub 页面、Stack Overflow 线程都会变成带锚点的结构化 Markdown——和本地文件使用同一个工具面。引用、跟踪、摘录时不会丢失来源位置。

### 09 · 真正原生，甚至支持 Windows

其他 agent 会 shell out 到 rg、grep、find、bash。很多机器上这些二进制不存在；即使存在，每次调用也有 fork-exec 成本。omp 把真实实现链接进进程内：ripgrep、glob、find 都是 in-process；brush 就是 bash，并且 session 可跨调用保留。同一个 omp 二进制可以跑在 macOS、Linux、Windows，不需要 WSL bridge。

### 10 · 带优先级和 verdict 的代码审查

代码审查会给出是否可以发布的明确 verdict，每个问题按 P0 到 P3 排序，并标注置信度。`/review` 会生成专用 reviewer subagent，并行扫描分支、单个提交或未提交修改。先处理阻塞发布的问题，重要事项不会藏在一堵散文墙里。

### 11 · Hashline：按内容 hash 编辑

更稳定的编辑，更少 token。模型指向 anchor，而不是重写要改的行，因此空白符冲突和 string-not-found 循环会停止。编辑过期文件时 anchor 会分歧，系统会在损坏文件前拒绝 patch。Grok 4 Fast 在同样任务上少花 61% 输出 token。

### 12 · GitHub 只是另一种文件系统

其他 harness 会加 `gh_issue_view`、`gh_pr_view`、`gh_search` 等工具，每个都有自己的参数。omp 跳过这层：`read` 已经处理 path；PR 也是 path。只教模型一个接口，只维护一个正确工具面。

### 13 · Hindsight：agent 自己维护的记忆

agent 可以跨会话记住代码库信息。运行中用 `retain` 写入事实，用 `recall` 取回，并把每个会话压缩成 mental model，在下一次首轮加载。默认按项目隔离，因此它学到的本 repo 信息只留在本 repo。

### 14 · ACP：可由编辑器驱动的 agent

在 Zed 中运行 omp，会得到和终端中一样的 agent：读取你正在看的 buffer，通过编辑器保存路径写入，在编辑器终端中启动 shell。破坏性工具会触发权限提示，你可以一次批准并记住。没有 bridge、没有插件、没有第二套脑子要同步。

### 15 · 继承其他工具已有配置

其他 agent 通常提供 importer，并要求你转换配置。omp 会直接读取磁盘上已有的八种格式：Cursor MDC、Cline `.clinerules`、Codex `AGENTS.md`、Copilot `applyTo` 等等。不需要迁移脚本，不需要 YAML 到 TOML，不需要“支持子集”的脚注。团队上个季度写的配置今晚仍然可用。

### 16 · `omp commit`：原子拆分与消息校验

omp 通过 `git_overview`、`git_file_diff` 和 `git_hunk` 读取工作区，然后把无关改动拆成按依赖排序的原子提交。写入前会拒绝循环依赖。源文件评分高于测试、文档和配置，因此最重要的提交排在前面。锁文件会完全排除在分析之外。

### 17 · 读取 PR、遍历 skills、从 subagent 取 JSON

十二种内部 scheme——`pr://`、`issue://`、`agent://`、`skill://`、`rule://` 等——会在 agent 已经调用的 FS-shaped 工具中透明解析。`read pr://1428` 返回和 `read src/foo.ts` 一样的形状。`search` 可以像目录一样遍历 diff。`agent://<id>/findings.0.path` 可以按路径从 subagent 输出中取字段。

### 18 · 更容易的冲突解决

每个 merge conflict 都会变成一个 URL。agent 向 `conflict://N` 写入 `@theirs`、`@ours` 或 `@base`，文件就会干净解决。批量形式是 `conflict://*`。

### 19 · 预览，然后接受

`ast_edit` 返回一个“proposed”卡片，标注替换数量。变更会暂存。agent 调用 `resolve` 并说明理由；TUI 会把它变成 **Accept** 卡片，随后原子地落盘——要么全部成功，要么全部不做。

### 20 · 驱动真实浏览器，甚至 Slack

默认 stealth，因此页面看到的是正常用户而不是 headless bot。同一 API 可以驱动任何 Electron app——指向 Slack，agent 就像读网页一样读取你的 DM。

## 任务需要什么，工具箱里已经有了

32 个工具和 `read`、`bash` 位于同一个命名空间。可以用 `--tools read,edit,bash,…` 固定活动工具集；其他工具隐藏但会被索引，`search_tool_bm25` 可以在会话中按需把相关工具找回来。

### 文件与搜索

- `read`：读取文件、目录、归档、SQLite、PDF、notebook、URL 和内部 `://` scheme。
- `write`：创建或覆盖文件、归档 entry 或 SQLite 行。
- `edit`：基于 content-hash anchor 的 hashline patch，并支持 stale-anchor 恢复。
- `ast_edit`：基于 ast-grep 的结构化重写，应用前预览。
- `ast_grep`：覆盖 50+ tree-sitter grammar 的结构化代码查询。
- `search`：对文件、glob 和内部 URL 做 regex 搜索。
- `find`：基于 glob 的路径查找；内容搜索请用 `search`。

### 运行时

- `bash`：工作区 shell，支持 PTY 或后台 job dispatch。
- `eval`：持久 Python 和 JavaScript cell，共享 prelude，并支持工具 re-entry。
- `ssh`：对配置 host 执行一条远程命令。

### 代码智能

- `lsp`：diagnostics、导航、符号、重命名、code action、raw request。
- `debug`：驱动 DAP session，包括断点、单步、线程、调用栈、变量。

### 协调

- `task`：并行 fan out subagent，可选工作区隔离。
- `irc`：当前进程中 live agent 间的短文本通信。
- `todo`：对会话 todo list 做有序变更和阶段跟踪。
- `job`：等待或取消后台 job。
- `ask`：交互式运行中的结构化追问。

### 外部世界

- `browser`：基于 Puppeteer 的 tab，可用 headless Chromium 或 CDP-attached app。
- `web_search`：跨配置提供商的一次查询，返回答案和引用。
- `github`：GitHub CLI 操作，包括 repo、PR、issue、code search、Actions run-watch。
- `generate_image`：通过 Gemini、GPT 或 xAI Grok 图像模型生成或编辑图像。
- `inspect_image`：用视觉模型分析本地图像。
- `tts`：通过 xAI Grok Voice 做文本转语音，五个内置声音，输出 WAV 或 MP3。

### 记忆与状态

- `checkpoint`：标记对话状态，以便后续折叠并报告。
- `rewind`：剪掉探索性上下文，保留简短报告。
- `retain`：把持久事实写入当前 Hindsight bank。
- `recall`：搜索 Hindsight bank 的原始记忆。
- `reflect`：让 Hindsight 基于记忆库合成答案。

### 其他

- `resolve`：应用或丢弃排队中的预览动作。
- `search_tool_bm25`：对隐藏工具索引做 BM25 搜索，并在会话中激活 top matches。

以下工具默认关闭，需要设置开启：`github`、`inspect_image`、`tts`、`checkpoint`、`rewind`、`search_tool_bm25`、`retain`、`recall`、`reflect`。可以按项目作用域打开。

[完整参考 →](https://omp.sh/docs/tools)

## 40+ 提供商、数百模型，一个 `/model` 即可切换

角色按意图路由工作。`default` 用于普通轮次，`smol` 用于便宜的 subagent fan-out，`slow` 用于深度推理，`plan` 用于计划模式，`commit` 用于 changelog。启动时可以用 `--smol`、`--slow` 或 `--plan` 覆盖；用 `Ctrl+P` 在当前角色配置的模型中循环；会话中用 `/model` 切换活动模型。

认证标签说明：`oauth` 代表用提供商账户登录，`plan` 代表通过 coding-plan 订阅路由，`local` 代表本地 server，key 可选。

### 前沿 API

直接 API 和网关，可按角色混合提供商。

Anthropic `oauth` · OpenAI · OpenAI Codex `oauth` · Google Gemini · Google Antigravity `oauth` · xAI · Mistral · Groq · Cerebras · Fireworks · Together · Hugging Face · NVIDIA · OpenRouter · Synthetic · Vercel AI Gateway · Cloudflare AI Gateway · Wafer Serverless · Perplexity `oauth`

### Coding plans

订阅路由，通过 `/login` 绑定会话。

Cursor `oauth` · GitHub Copilot `oauth` · GitLab Duo · Kimi Code `plan` · Moonshot · MiniMax Coding Plan `plan` · MiniMax Coding Plan CN `plan` · Alibaba Coding Plan `plan` · Qwen Portal · Z.AI / GLM Coding Plan `plan` · Xiaomi MiMo · Qianfan · NanoGPT · Venice · Kilo · ZenMux · OpenCode Go · OpenCode Zen

### 自己运行

OpenAI-compatible `/v1/models`。本地实例可不填 key。

Ollama `local` · Ollama Cloud · LM Studio `local` · llama.cpp `local` · vLLM `local` · LiteLLM

### 四个让路由真正有用的旋钮

- **自定义提供商**：在 `~/.omp/agent/models.yml` 中声明任何实现 `openai-completions`、`openai-responses`、`openai-codex-responses`、`azure-openai-responses`、`anthropic-messages`、`google-generative-ai` 或 `google-vertex` 的服务。
- **Fallback chains**：在 `retry.fallbackChains` 下为每个角色配置链路。当主模型返回 429 或额度耗尽时，后续模型接管本轮，并在冷却后恢复。
- **路径作用域模型**：把 `enabledModels` 和 `disabledProviders` 条目限定到 `path:` 前缀，为某个 repo 固定不同模型集合，不影响全局配置。
- **凭证轮询**：每个提供商可以堆叠多个 API key，运行时按 session affinity 和每凭证 backoff 轮转。适合避免单个 key 半天就烧完。

完整 provider 与 routing 参考：<https://omp.sh/docs/providers>。

## 14 个后端，一个 agent 已经知道的工具

`web_search` 是内置的，不是外挂。`auto` 会遍历 14 个 provider 链；也可以指定某个已付费 provider。每个命中结果背后都有 site-aware extraction，把 GitHub、registry、arXiv、Stack Overflow、文档转换成结构化 Markdown，保留 anchor 和 link target。

### 搜索提供商

| provider | 认证 |
| --- | --- |
| `auto` | chain |
| `exa` | `EXA_API_KEY`（或 mcp） |
| `brave` | `BRAVE_API_KEY` |
| `jina` | `JINA_API_KEY` |
| `kimi` | `MOONSHOT_API_KEY` |
| `zai` | `ZAI_API_KEY` |
| `anthropic` | oauth |
| `perplexity` | `PERPLEXITY_API_KEY` |
| `gemini` | oauth |
| `codex` | oauth |
| `tavily` | `TAVILY_API_KEY` |
| `parallel` | `PARALLEL_API_KEY` |
| `kagi` | `KAGI_API_KEY` |
| `synthetic` | `SYNTHETIC_API_KEY` |
| `searxng` | self-hosted |

### 专用处理器

agent 拿到的是结构化内容，而不是被剥干净的 HTML。

- **代码托管**：github、gitlab
- **包注册表**：npm、PyPI、crates.io、Hex、Hackage、NuGet、Maven、RubyGems、Packagist、pub.dev、Go packages
- **研究来源**：arxiv、semantic scholar
- **论坛**：Stack Overflow、Reddit、HN
- **文档**：MDN、Read the Docs、docs.rs

页面会转换为保留链接结构的 Markdown。agent 可以引用、跟踪和摘录而不丢失 anchor。

### 安全数据库

漏洞查询使用厂商数据，而不是博客摘要。

- **NVD**：国家漏洞数据库
- **OSV**：开源漏洞 feed
- **CISA KEV**：已知被利用漏洞

## 大约 55,000 行 Rust，在做其他 harness 会 shell out 的工作

四个 crate，一个按平台发布的 N-API addon。搜索、shell、AST、高亮、PTY、图片解码、BPE 计数——全部在 libuv 线程池中 in-process。热路径不需要 fork/exec。

主要模块包括：嵌入式 bash、regex search、键盘协议、ANSI-aware 文本宽度、tree-sitter 摘要、ast-grep、文件缓存、语法高亮、PTY、glob、workspace walker、外观检测、电源保持、任务线程池、find 替代、工作区隔离、profiling、进程树管理、剪贴板、token 计数、sixel 图片渲染、HTML 转 Markdown 等。

## 四个入口：interactive、one-shot、RPC 和 ACP

同一个 engine，四层 wrapper。`omp` 运行 TUI；`omp -p` 回答单次 prompt 后退出；Node SDK 把 session 嵌入你的进程；`omp --mode rpc` 和 `omp acp` 通过 stdio 交给其他程序控制。

### Interactive：有疑问时 agent 会询问

TUI 是默认界面。工具调用渲染成卡片，编辑在落盘前预览，歧义通过 `ask` 工具进入结构化选项选择器。键盘负责其余交互。

同样的 prompt card 会通过 ACP 暴露，因此编辑器无需自己实现 picker。

### SDK：嵌入 Node

`@oh-my-pi/pi-coding-agent`

Node 和 TypeScript 宿主可以直接加载引擎。包导出 `ModelRegistry`、`SessionManager`、`createAgentSession` 和 `discoverAuthStorage`；session 会发出 typed events 供订阅。

```ts
import {
  ModelRegistry,
  SessionManager,
  createAgentSession,
  discoverAuthStorage,
} from "@oh-my-pi/pi-coding-agent";

const auth = await discoverAuthStorage();
const models = new ModelRegistry(auth);
await models.refresh();

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  authStorage: auth,
  modelRegistry: models,
});
await session.prompt("list .ts files");
```

### RPC：通过 stdio 驱动

`omp --mode rpc`

适用于非 Node 嵌入，或需要进程隔离时。输入 NDJSON 命令，输出 response 和 event frame。`--mode rpc-ui` 增加 tool card、selector 和 dialog 作为 `extension_ui_request` frame，由宿主回答。

```text
$ omp --mode rpc --no-session
> {"id":"r1","type":"prompt","message":"list .ts files"}
< {"id":"r1","type":"response", ...}
> {"id":"r2","type":"set_model","provider":"anthropic","modelId":"sonnet-4.5"}
> {"id":"r3","type":"abort"}
```

### ACP：和编辑器通信

`omp acp`

基于 [Agent Client Protocol](https://github.com/zed-industries/agent-client-protocol) 的 JSON-RPC。当编辑器声明能力后，工具 I/O 会通过编辑器路由，写入会由 `session/request_permission` gate。

| omp tool | ACP 路由 |
| --- | --- |
| `bash` | `terminal/create + terminal/output` |
| `read` | `fs/read_text_file` |
| `write` | `fs/write_text_file` |
| `edit, bash` | `session/request_permission` |

完整参考：<https://omp.sh/docs/sdk>。

## 一个值得长期使用的 harness，不应该让你很快撞到天花板

从 **[omp.sh](https://omp.sh)** 开始。

omp 是 [Mario Zechner](https://github.com/mariozechner) 的 [Pi](https://github.com/badlogic/pi-mono) 的 fork，并被重写成 coding-first 界面：sessions、subagents、slash commands、extensions——全 TypeScript、MIT、GitHub 开源。你可以通过配置塑形、从外部 hook，或者需要时直接读源码。

### Primitives

extension 是 TypeScript 模块。和内置功能使用同样的 tool API、slash-command registry、hotkey table 和 TUI primitives。没有保留区。

### Discovery

首次运行时，omp 会继承磁盘上已有的规则、skills 和 MCP servers：来自 `.claude`、`.cursor`、`.windsurf`、`.gemini`、`.codex`、`.cline`、`.github/copilot` 和 `.vscode`。无需迁移脚本。

### Extensibility

让 omp 写出你缺失的那块，然后 `/reload-plugins`。可以保持本地、放到 `marketplace`，或发布到 npm。

## Philosophy

omp 是 [Mario Zechner](https://github.com/mariozechner) 的 [pi-mono](https://github.com/badlogic/pi-mono) 的 fork，扩展为 batteries-included 的编码工作流。

核心理念：

- 保留适合真实编码工作的交互式 terminal-first UX
- 包含实用 built-ins（tools、sessions、branching、subagents、extensibility）
- 让高级行为可配置，而不是隐藏起来

---

## Development

### 从源码开始

新 clone 需要安装 workspace 依赖，并构建本地 Rust/N-API addon，源码 CLI 才能启动。

```sh
bun setup
bun dev
```

`bun setup` 安装 Bun workspace，并构建 `@oh-my-pi/pi-natives`。修改 Rust crates 或 `packages/natives` 后，请重新运行 `bun run build:native`。

非交互 smoke check：

```sh
bun dev -- --version
```

### Debug 命令

`/debug` 会打开调试、报告和 profiling 工具。

架构与贡献指南见：`packages/coding-agent/DEVELOPMENT.md`。

---

## Monorepo Packages

| Package | 说明 |
| --- | --- |
| `@oh-my-pi/collab-web` | collab live session 的浏览器 guest client、mock host 和本地 relay |
| `@oh-my-pi/pi-ai` | 多 provider LLM client，支持 streaming 和模型/provider 集成 |
| `@oh-my-pi/pi-catalog` | 模型目录：内置模型数据库、provider descriptor 和 identity |
| `@oh-my-pi/pi-agent-core` | 带 tool calling 和状态管理的 agent runtime |
| `@oh-my-pi/pi-coding-agent` | 交互式 coding agent CLI 和 SDK |
| `@oh-my-pi/pi-tui` | 带差分渲染的终端 UI 库 |
| `@oh-my-pi/pi-natives` | grep、shell、image、text、syntax highlighting 等 N-API binding |
| `@oh-my-pi/omp-stats` | 本地 AI 使用统计观察面板 |
| `@oh-my-pi/pi-utils` | 共享工具：logging、streams、dirs/env/process helpers |
| `@oh-my-pi/pi-wire` | collab live-session 协议类型和 relay 常量 |
| `@oh-my-pi/hashline` | `edit` 工具背后的 line-anchored patch 语言和 applier |
| `@oh-my-pi/pi-mnemopi` | Oh My Pi agents 的本地 SQLite memory engine |
| `@oh-my-pi/snapcompact` | bitmap-frame context compression 包和 SQuAD eval suite |
| `@oh-my-pi/swarm-extension` | Swarm orchestration extension 包 |

### Rust Crates

| Crate | 说明 |
| --- | --- |
| `pi-natives` | `@oh-my-pi/pi-natives` 使用的核心 Rust native addon，聚合下列 crates |
| `pi-shell` | 从 `pi-natives` 拆出的 embedded shell / PTY / process management，包装 `brush-*` |
| `pi-ast` | 基于 tree-sitter 的代码摘要和 AST 工具，支持 50+ language grammar |
| `pi-iso` | task isolation 后端解析器：APFS clone、btrfs/zfs reflink、overlayfs、projfs、rcopy |
| `brush-core-vendored` | vendored fork of brush-shell，用于嵌入式 bash 执行 |
| `brush-builtins-vendored` | vendored bash builtins（cd、echo、test、printf、read、export 等） |

## Contributing

Issues 对所有人开放。**Pull request 需要 vouch**——来自未 vouch 或被 denounce 作者的 PR 会自动关闭。如果还没有 vouch，请打开 Discussion 并请求 maintainer 执行 `!vouch`，而不是直接开 PR（否则会被立即关闭）。完整政策见 `CONTRIBUTING.md` 和 `.github/VOUCHED.td`。

---

## License

MIT。见 `LICENSE`。

© 2025 Mario Zechner  
© 2025-2026 Can Bölük

_为那些一直打开的终端而生_

- [omp.sh](https://omp.sh)
- [GitHub](https://github.com/can1357/oh-my-pi)
- [Changelog](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/CHANGELOG.md)
- [npm](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent)
- [Discord](https://discord.gg/4NMW9cdXZa)
- [MIT](https://github.com/can1357/oh-my-pi/blob/main/LICENSE)
