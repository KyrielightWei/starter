# Pi Template Code Review Report

## 📊 Review Scope

冲突解决的文件 + 整体逻辑一致性检查。

---

## ✅ 代码质量检查

### Extensions (通过)

| 扩展 | 代码质量 | API 使用 | 设计目标 |
|------|----------|----------|----------|
| git-checkpoint.ts | ✅ 正确 | `pi.exec` (正确) | ✅ fork 时恢复代码状态 |
| permission-gate.ts | ✅ 正确 | `pi.on("tool_call")` | ✅ 拦截危险命令 |
| protected-paths.ts | ✅ 正确 | `pi.on("tool_call")` | ⚠️ 与 permission-gate 重叠 |
| dirty-repo-guard.ts | ✅ 正确 | `pi.on("session_before_*")` | ✅ 阻止脏仓库切 session |
| handoff.ts | ✅ 正确 | `pi.registerCommand` | ✅ 无损跨 session 转移 |
| notify.ts | ✅ 正确 | OSC 协议 | ✅ 终端通知 |
| statusbar.ts | ✅ 正确 | `ctx.ui.setFooter` | ✅ 三行状态栏 |
| todo.ts | ✅ 正确 | `pi.registerTool` | ✅ TODO 管理 |

### Prompts (通过)

| Prompt | 格式 | 内容 |
|--------|------|------|
| commit.template.md | ✅ 正确 | Conventional commit 格式 |
| debug.template.md | ✅ 正确 | 系统化调试流程 |
| docs.template.md | ✅ 正确 | 文档生成 |
| explain.template.md | ✅ 正确 | 代码解释 |
| perf.template.md | ✅ 正确 | 性能分析 |
| pr.template.md | ✅ 正确 | PR 创建 |
| review.template.md | ✅ 正确 | 代码审查 |
| security.template.md | ✅ 正确 | 安全检查 |
| test.template.md | ✅ 正确 | 测试生成 |

### Skills (通过)

所有 skills 都符合 Agent Skills 标准，frontmatter 正确。

---

## ⚠️ 发现的逻辑问题

### 1. 🔴 两个 Settings 模板不一致

**问题**: 存在两个不同的 settings 模板文件：

| 文件 | 内容 | 说明 |
|------|------|------|
| `pi/settings.template.jsonc` | 我们写的版本 | 缺少 `thinkingBudgets`, `skills`, `enableSkillCommands` |
| `pi.template.jsonc` | 远程版本 | 更完整，含 MCP 包配置 |

**影响**: 用户可能使用错误的模板，导致配置不完整。

**建议**: 
- 合并两个文件，保留 `pi.template.jsonc` 作为主模板
- 删除 `pi/settings.template.jsonc` 或标注为"简化版"

### 2. 🔴 permission-gate 与 protected-paths 功能重叠

**问题**: 两个扩展都处理敏感文件保护，但行为不一致：

```
permission-gate.ts:
- sensitivePaths: [.env, id_rsa, .ssh/, ...]
- 弹出确认对话框，用户可选择允许

protected-paths.ts:
- protectedPaths: [.env, .git/, node_modules/]
- 直接阻止，不给用户选择
```

**影响**: 
- 用户可能困惑为何有时能确认、有时直接被阻止
- 同时安装两个扩展会导致 `.env` 被双重拦截

**建议**: 
- 合并为一个扩展，统一逻辑
- 或明确分工：permission-gate 处理危险命令，protected-paths 处理路径保护

### 3. 🟡 Skills 目录缺少 brainstorming

**问题**: README 提到 superpowers 提供 brainstorming skill，但我们之前写了本地的 brainstorming/SKILL.md（已删除）。

**当前状态**: `pi/skills/` 只有 5 个 skill，没有 brainstorming。

**建议**: 
- superpowers 包已包含 brainstorming，无需本地副本
- 但 README 描述应准确反映实际情况

### 4. 🟡 prompts 版本合并问题

**问题**: 远程版本有 12 个 prompts，我们写了 7 个。合并后：
- 远程版本：commit, debug, docs, explain, perf, pr, review, security, test, refactor
- 我们版本：commit, debug, explain, implement, plan, refactor, review

**冲突解决**: 我们接受了远程版本（更专业）。

**潜在问题**: 缺少 `implement` 和 `plan` prompts（我们写的版本有）。

**建议**: 保留我们的 `implement.template.md` 和 `plan.template.md`（TDD 和计划功能有价值）。

---

## 📋 配置一致性检查

### mcp.template.jsonc ✅

- 结构正确，符合 pi-mcp-adapter 规范
- 环境变量引用格式正确 (`$env:VAR`)
- lazy lifecycle 配置正确

### models.template.jsonc ✅

- Provider 配置正确
- 缺少 cost 信息（不影响功能）

### keybindings.template.jsonc ✅

- 键格式正确
- 命名空间正确 (`tui.*`, `app.*`)

### theme.template.jsonc ✅

- JSONC 格式正确
- 颜色变量定义完整

---

## 🔧 需要修复的问题

### 高优先级

1. **合并 settings 模板**
```bash
# 删除我们的简化版，使用远程完整版
rm pi/settings.template.jsonc
# 或保留并标注用途差异
```

2. **统一敏感文件保护逻辑**
```typescript
// 建议在 permission-gate 中整合 protected-paths 的功能
// protected-paths.ts 可以删除或改为特定场景使用
```

### 中优先级

3. **补充缺失的 prompts**
```bash
# 保留我们写的 implement 和 plan
git show 8c75af5:pi/prompts/implement.template.md > pi/prompts/implement.template.md
git show 8c75af5:pi/prompts/plan.template.md > pi/prompts/plan.template.md
```

4. **更新 README 确保准确性**
- 说明 superpowers 包提供的 skills
- 说明 prompts 的完整列表

---

## 📊 最终评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **代码质量** | ⭐⭐⭐⭐⭐ | 扩展代码正确使用 Pi API |
| **逻辑一致性** | ⭐⭐⭐⭐ | 有重叠功能需统一 |
| **配置完整性** | ⭐⭐⭐⭐ | 远程版本更完整 |
| **文档准确性** | ⭐⭐⭐⭐ | README 需要更新 |

---

## 🎯 总结

**通过项**:
- 所有扩展代码正确，API 使用规范
- Prompts 格式和内容专业
- Skills 符合 Agent Skills 标准
- MCP 配置结构正确

**需修复项**:
1. 两个 settings 模板不一致 → 合并或删除重复
2. permission-gate 与 protected-paths 重叠 → 统一逻辑
3. 缺少 implement/plan prompts → 补充
4. README 准确性 → 更新

---

## 🔄 修复步骤

```bash
# 1. 保留远程版本 settings 模板（更完整）
rm pi/settings.template.jsonc

# 2. 补充缺失的 prompts
git show 8c75af5:pi/prompts/implement.template.md > pi/prompts/implement.template.md
git show 8c75af5:pi/prompts/plan.template.md > pi/prompts/plan.template.md

# 3. 更新 README（如有需要）

# 4. 提交修复
git add -A
git commit -m "fix(pi): resolve template inconsistencies after merge"
```