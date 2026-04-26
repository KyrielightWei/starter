---
phase: 01
reviewers: [glm-5, qwen3.6-plus]
reviewed_at: "2026-04-22T18:30:00Z"
plans_reviewed: [01-01-PLAN.md, 01-02-PLAN.md, 01-03-PLAN.md, 01-04-PLAN.md, 01-05-PLAN.md]
---

# Cross-AI Plan Review — Phase 01 (Full 5-Plan Review)

> **Note:** This is the SECOND review covering all 5 plans (01-01 through 01-05). The first review covered only plans 01-01 through 01-03. This review includes the gap closure plans 01-04 (Model Selection) and 01-05 (Static Models Editor).

---

## glm-5 Review

### Summary

整体计划设计较为完整，覆盖了从底层数据层（Registry & Validator）到 UI 层（Picker + CRUD），再到集成层（keymap/command）的完整链路。计划 01-04 和 01-05 作为 gap closure 补充了 Model Selection 和 Static Models Editor，体现了迭代思维。**但存在若干 HIGH 风险点：** 文件持久化策略（直接修改 `providers.lua`）过于激进，FZF-lua 双向交互（Ctrl-A/D/E/+/-M 等）的 API 一致性未充分验证，两步 Picker 的状态管理缺乏容错，且 TDD 策略与 Neovim 测试环境适配度存疑。

### Strengths

- **分层架构清晰**：01-01（数据层）→ 01-02（UI 层）→ 01-03（集成层）→ 01-04/01-05（功能增强）
- **Validator 先行**：regex 校验 + duplicate check 避免脏数据
- **动态 fetch + static fallback**：Plan 01-04 的双层 model 策略兼顾实时性与离线可用性
- **Human verify checkpoint**：Plan 01-03 的 11 步验证清单提供了明确的质量门禁
- **向后兼容考虑**：Keys cleanup 时保留旧 provider 的 key 文件

### Concerns (per plan)

| Plan | Severity | Concern |
|------|----------|---------|
| 01-01 | **HIGH** | 直接修改 providers.lua（AST 不感知的正则替换易出错）|
| 01-01 | MEDIUM | `add_provider()` 只是打开文件，缺少模板生成 |
| 01-02 | **HIGH** | FZF-lua `fzf_exec` action 绑定需验证兼容性 |
| 01-02 | MEDIUM | `vim.ui.input` 在 async callback 中可能 focus loss |
| 01-03 | MEDIUM | `pcall(require)` 静默失败无用户反馈 |
| 01-04 | **HIGH** | 两步 Picker 状态丢失（Esc 后如何返回第一步未定义）|
| 01-04 | MEDIUM | `get_default_model()` 存储位置未明确 |
| 01-05 | **HIGH** | 修改 providers.lua static_models 行风险高（可能跨多行）|
| 01-05 | MEDIUM | Ctrl-M 嵌套 Picker 的退出路径不明确 |
| 01-05 | LOW | `<CR>` 在不同 picker 语义冲突 |

### Suggestions

1. **独立配置文件（P0）** — 改用 `~/.local/state/nvim/ai_providers_custom.lua`，启动时 merge
2. **统一 Registry API（P1）** — 设计一致的 CRUD 接口
3. **两步 Picker 状态机（P1）** — 明确状态转换：main → model_picker → (confirm|back|cancel)
4. **嵌套 Picker 导航（P2）** — 提供明确返回键（如 `<BS>` 或 `Ctrl-B`）

### Risk Assessment

**Overall: HIGH**

主要理由：文件持久化策略是最大风险源；FZF-lua 交互复杂度被低估；模型管理状态分散。

---

## qwen3.6-plus Review

### Summary

整体设计采用分层递进的方式（数据层 → UI 层 → 集成层 → 功能补全 → 扩展编辑器），结构清晰、依赖关系合理，TDD 方法贯穿始终。但在**文件持久化安全性**、**Keymap 密度**、**两步 Picker 状态管理**、以及**多 step picker 间的数据刷新**方面存在显著风险。Plan 01-05 尤其复杂——在 providers.lua 上做 AST 不感知的行级编辑，有较高的文件损坏风险。

### Strengths

- **良好的分层架构**：01 → 02 → 03 → 04 → 05 依次构建，依赖链清晰
- **TDD 贯穿始终**：每个计划都包含测试用例
- **响应已有 Review**：删除持久化、empty state guard 等已修复
- **Two-step picker 复用现有模式**：Fetch/fallback 模式正确
- **Threat model 覆盖关键边界**：每个计划都有 STRIDE 分析

### Concerns (per plan)

| Plan | Severity | Concern |
|------|----------|---------|
| 01-01 | **HIGH** | `delete_provider()` 行级匹配 `M.register(...)` 到 `})` 不可靠 |
| 01-01 | **HIGH** | 无文件备份/原子写入机制（`writefile` 覆盖写风险）|
| 01-02 | **HIGH** | **Keymap 密度过高** — 5+ 快捷键，两步 `<CR>` 语义冲突 |
| 01-02 | MEDIUM | CRUD 操作后 picker 不自动刷新 |
| 01-02 | MEDIUM | `vim.ui.input` 异步回调在 FZF-lua 上下文中可能被吞 |
| 01-03 | MEDIUM | `ai/init.lua` 修改位置描述基于行号，代码变动后会偏移 |
| 01-04 | **HIGH** | **两步 Picker 交互流断裂** — 同一 `<CR>` 键在两步有不同含义 |
| 01-04 | **HIGH** | `set_default_model()` 写入 ai_keys.lua 而非 providers.lua，设计意图不清 |
| 01-05 | **HIGH** | **文件编辑风险最大** — static_models 行可能跨多行 |
| 01-05 | **HIGH** | 无原子写入或备份机制（Threat model 提到但代码未实现）|
| 01-05 | **HIGH** | `vim.defer_fn` 竞态条件 — 多次快速操作产生交错 picker |
| 01-05 | MEDIUM | empty state placeholder 与前期 review 结论矛盾 |

### Cross-Plan Issues

| Issue | Plans Affected |
|-------|----------------|
| 文件持久化全局不可靠（无备份/原子写入）| 01-01, 01-05 |
| Picker 状态刷新缺失 | 01-02, 01-04, 01-05 |
| Keymap 膨胀（Ctrl-A/D/E/M/+/-/ 7+ 个）| 01-02, 01-05 |
| 测试框架不统一 | 01-01, 01-02, 01-04, 01-05 |
| Keys vs providers.lua 边界模糊 | 01-01, 01-04 |

### Suggestions

1. **封装安全文件写入** — 创建 `file_util.lua`，先写 `.tmp` 再 rename
2. **Picker 刷新机制** — CRUD 后调用 `vim.defer_fn(M.open, 50)` 自动刷新
3. **精简 Keymap** — 保留核心 3-4 个，二级操作放 submenu
4. **两步 Picker 重构** — 单 picker + 动态内容切换（`fzf.reload()`）
5. **明确 Keys 和 providers.lua 边界** — 文档区分注册定义 vs 用户偏好

### Risk Assessment

**Overall: MEDIUM-HIGH**

| Dimension | Risk |
|-----------|------|
| 数据完整性 | **HIGH** — providers.lua 行级编辑无备份机制 |
| UI/UX 可用性 | **MEDIUM** — Keymap 密度高但可容忍 |
| 集成复杂度 | **LOW** — Plan 01-03 简单明了 |
| 测试覆盖 | **MEDIUM** — 核心数据层有测试，UI 集成层薄弱 |

### 阻塞项（应在执行前解决）

1. 实现 `safe_write_file()` 统一模块
2. 澄清两步 Picker 的 `<CR>` 语义冲突
3. 补全 Picker 自动刷新机制

---

## Consensus Summary

### Agreed Strengths (2+ reviewers)

1. **分层架构清晰** — 数据层 → UI 层 → 集成层 → 功能增强
2. **TDD 方法** — 核心数据层有完整测试
3. **动态 fetch + static fallback** — Provider model 策略合理
4. **Human verify checkpoint 具体化** — 11 步验证清单可执行

### Agreed Concerns (HIGH — both reviewers raised)

| Concern | Severity | Plans | Fix Required |
|---------|----------|-------|--------------|
| 文件持久化不可靠（无备份/原子写入）| HIGH | 01-01, 01-05 | 封装 `safe_write_file()`，先写 `.tmp` 再 rename |
| 两步 Picker `<CR>` 语义冲突 | HIGH | 01-02, 01-04 | 明确状态机或重构为单 picker + reload |
| Keymap 密度过高（5+ 快捷键）| MEDIUM | 01-02, 01-05 | 精简到 3-4 个，二级操作放 submenu |
| Picker 操作后不自动刷新 | MEDIUM | 01-02, 01-04, 01-05 | CRUD 后调用 `M.open()` 或 `fzf.reload()` |
| 文件编辑的 AST 不感知风险 | HIGH | 01-01, 01-05 | 考虑独立配置文件格式 |

### Divergent Views

| Issue | glm-5 View | qwen3.6-plus View | Resolution |
|-------|------------|-------------------|------------|
| 文件持久化方案 | 建议独立配置文件 | 建议安全写入封装 + 备份 | **折中：先实现安全写入封装，独立配置作为后续优化** |
| 两步 Picker 重构 | 定义状态机 | 单 picker + reload | **采纳状态机方案（更简单，改动小）** |
| 测试覆盖 | 关注 TDD 环境适配 | 关注 UI 行为测试 | **两者都需要：补充 UI 行为测试** |

### Requirement Coverage Assessment (All 5 Plans)

| Requirement | Status | Plans | Notes |
|-------------|--------|-------|-------|
| PMGR-01 查看所有 Provider/Model | PARTIAL | 01-02, 01-04 | Step 2 实现，但两步 picker 交互流断裂 |
| PMGR-02 添加 Provider | PARTIAL | 01-02 | Ctrl-A 打开文件编辑，缺少模板生成 |
| PMGR-03 删除 Provider | PARTIAL | 01-02 | 文件持久化有实现但无备份机制 |
| PMGR-04 编辑 Provider 配置 | PARTIAL | 01-05 | static_models 编辑器有风险 |

### Overall Risk Assessment

**MEDIUM-HIGH**

---

## Recommended Fixes Before Executing Plans 01-04 and 01-05

### Priority 1 (Blocking)

| # | Fix | Plan | Description |
|---|-----|------|-------------|
| 1 | 安全文件写入封装 | 01-05 | 创建 `file_util.lua`，实现 `safe_write()`（先写 `.tmp` 再 rename） |
| 2 | 两步 Picker 状态机 | 01-04 | 明确定义状态转换，Provider → Model → (select|back|cancel) |
| 3 | Picker 自动刷新 | 01-02 | CRUD 操作后调用 `vim.defer_fn(M.open, 50)` 自动刷新 |

### Priority 2 (Important)

| # | Fix | Plan | Description |
|---|-----|------|-------------|
| 4 | 精简 Keymap | 01-02, 01-05 | 保留 Ctrl-A/D/E/+/ 核心 5 个，Ctrl-M 改为 submenu 或 `Ctrl-E → Static Models` |
| 5 | 补充 UI 行为测试 | 01-02, 01-04, 01-05 | 测试空状态、name_map 失败、两步 picker 状态流转 |
| 6 | 静态模型跨行处理 | 01-05 | 处理 `static_models = { ... }` 跨多行格式 |

### Priority 3 (Enhancement)

| # | Fix | Plan | Description |
|---|-----|------|-------------|
| 7 | 独立配置文件 | Future | 改用 `ai_providers_custom.lua` 而非直接修改 providers.lua |
| 8 | Loading 指示器 | 01-04 | 动态 fetch 时显示 loading 状态 |
| 9 | 错误处理统一 | All | 统一网络/文件/用户取消的错误处理流程 |

---

*Reviews completed: 2026-04-22T18:30:00Z*
*Plans reviewed: 01-01 through 01-05*
*To incorporate feedback: `/gsd-plan-phase 1 --reviews`*
