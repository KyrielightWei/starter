# Phase 2: Provider Manager Detection Commands - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

用户可以手动触发检测 Provider/Model 的可用性，覆盖两个需求：
- **PMGR-05**: 用户可以通过命令手动触发检测指定 Provider/Model 的可用性
- **PMGR-06**: 用户可以通过命令手动触发检测所有 Provider/Model 的可用性

**不包含：** 自动检测结果展示（Phase 3）、Agent-Model 配置（v2）、UI 状态指示器（Phase 3）

</domain>

<decisions>
## Implementation Decisions

### 检测方式
- **D-01:** 发送最小 Chat 请求检测可用性 — 向 `/v1/chat/completions` 发送 `max_tokens=1` 的请求，检查是否返回有效响应
- **D-02:** 使用 OpenAI 兼容格式：`{"model":"<model_name>","messages":[{"role":"user","content":"hi"}],"max_tokens":1}`
- **D-03:** 复用 `fetch_models.lua` 的 curl + `io.popen()` 模式，而非引入新的 HTTP 库
- **D-04:** 检测超时使用 provider 配置的 `timeout` 字段（默认 30000ms）

### 结果展示
- **D-05:** 检测结果以浮动窗口汇总展示，表格形式呈现所有检测结果
- **D-06:** 每条结果包含：Provider 名称、Model 名称、状态标识（✓ 可用/✗ 不可用/⏱ 超时/⚠ 错误）、响应时间、错误信息
- **D-07:** 浮动窗口支持关闭操作（`q` 键）

### 执行策略
- **D-08:** 单模型检测（PMGR-05）为同步执行 — 检测单个 provider/model 后立即返回结果
- **D-09:** 全量检测（PMGR-06）使用异步并发，限制并发数为 3 — 使用 `vim.loop` 实现异步，同时最多 3 个请求并发
- **D-10:** 全量检测期间提供进度提示（如 "检测中: 3/12"）

### 缓存策略
- **D-11:** 按需检测 + 缓存结果 — 检测结果缓存到文件，日常使用读取缓存
- **D-12:** 缓存存储位置：`~/.local/state/nvim/ai_detection_cache.lua`（与 ai_keys.lua 同目录，保持一致性）
- **D-13:** 缓存失效规则：超过 provider 配置的 timeout 时间后自动失效
- **D-14:** 切换 provider 时，自动检测新 provider 的默认模型（为 Phase 3 预留接口）
- **D-15:** 手动命令驱动是主要入口，缓存用于避免重复检测

### 命令设计
- **D-16:** 提供两个用户命令：`:AICheckProvider [provider] [model]`（检测指定）和 `:AICheckAllProviders`（检测全部）
- **D-17:** 可选 keymap：`<leader>kc` 检测当前 provider，`<leader>kC` 检测所有
- **D-18:** 命令支持不指定 model 时检测 provider 的默认模型

### 模块化结构
- **D-19:** 新建 `lua/ai/provider_manager/detector.lua` — 核心检测逻辑
- **D-20:** 新建 `lua/ai/provider_manager/cache.lua` — 检测结果缓存管理
- **D-21:** 新建 `lua/ai/provider_manager/results.lua` — 浮动窗口结果展示
- **D-22:** 检测逻辑集成到 `lua/ai/provider_manager/init.lua` 的命令注册中

### the agent's Discretion
- 浮动窗口的具体样式（边框、高亮颜色、宽度）
- 具体的 vim.loop 异步实现方式（callback vs co-routine）
- 错误分类的细化程度（网络错误、认证错误、服务端错误的区分粒度）
- 测试覆盖的具体用例设计

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Definition
- `.planning/ROADMAP.md` §Phase 2 — Phase goal and success criteria
- `.planning/REQUIREMENTS.md` §PMGR-05, PMGR-06 — Acceptance criteria

### Project Context
- `.planning/PROJECT.md` — Core value, constraints (性能要求: 单次检测 < 10s)
- `.planning/phases/01-provider-manager-core-ui/01-CONTEXT.md` — Phase 1 decisions (Provider Manager 子系统结构)

### Existing Code Patterns
- `lua/ai/fetch_models.lua` — curl + io.popen() HTTP 请求模式、端点探测逻辑
- `lua/ai/health.lua` — API Key 格式校验模式、`vim.health` 状态报告模式
- `lua/ai/providers.lua` — Provider 注册表，`timeout` 字段定义
- `lua/ai/keys.lua` — 配置文件读写模式
- `lua/ai/provider_manager/init.lua` — 命令注册和 keymap 注册模式
- `lua/ai/provider_manager/registry.lua` — Provider 配置管理模式

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fetch_models.lua`: 已有 curl 调用 OpenAI 兼容端点的完整实现，可复用其 HTTP 请求构建逻辑
- `providers.lua`: 每个 provider 已有 `timeout` 字段（默认 30000ms），可直接用于检测超时控制
- `health.lua`: `validate_api_key()` 函数可用于检测前预检 Key 格式
- `provider_manager/registry.lua`: Phase 1 已实现的注册表，可获取 provider/model 列表
- `vim.loop`: Neovim 内置 libuv 绑定，支持异步 HTTP 请求

### Established Patterns
- **curl + io.popen() pattern**: `fetch_models.lua` 已建立通过 curl 调用 API 的模式
- **Lua config file pattern**: `read()` / `writefile()` 用于持久化配置（用于缓存）
- **Command registration pattern**: `vim.api.nvim_create_user_command()` + `vim.keymap.set()`
- **Notification pattern**: `vim.notify()` 用于用户反馈

### Integration Points
- `lua/ai/provider_manager/init.lua`: 需要注册新的检测命令和 keymap
- `lua/ai/state.lua`: 切换 provider 时需要触发自动检测（预留接口）
- `~/.local/state/nvim/ai_keys.lua`: 同目录存储检测结果缓存
- `lua/ai/providers.lua`: 读取 provider 配置（endpoint, timeout, model）

</code_context>

<specifics>
## Specific Ideas

- 检测命令应像 `healthcheck` 工具一样直观 — 一条命令即可知道哪个 Provider/Model 可用
- 浮动窗口结果应一目了然，类似 `:checkhealth` 的输出风格但更紧凑
- 并发控制在 3 个是为了避免触发 API 速率限制
- 缓存文件使用 Lua 格式（`return {...}`）与 ai_keys.lua 保持一致，方便手动编辑

</specifics>

<deferred>
## Deferred Ideas

- 自动检测并更新状态指示器 — Phase 3 (PMGR-07, PMGR-08)
- Agent-Model 配置 — v2 requirements (PMGR-09 ~ PMGR-16)
- 检测历史记录 — 未来可考虑，当前只做最新结果缓存

</deferred>

---

*Phase: 02-provider-manager-detection-commands*
*Context gathered: 2026-04-24*
