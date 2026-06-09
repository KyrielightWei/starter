# Pi × Claude Code 跨工具对接

> 本文档说明 Pi 如何加载 Claude Code 的项目级 skill / rule / command，以及哪些**不能**直接共享。

---

## 总览

| Claude Code 资源 | 路径 | Pi 能否加载 | 实现方式 |
|-----------------|------|:-----------:|----------|
| **Skill** | `.claude/skills/*/SKILL.md` | ✅ 完整支持 | `settings.json` → `skills` 数组 |
| **Rule** | `.claude/rules/**/*.md` | ⚠️ 列表级 | `claude-rules` 扩展（只列路径，模型按需 read） |
| **Command** | `.claude/commands/*.md` | ❌ 不兼容 | 需手动复制到 `.pi/prompts/` 且格式要适配 |
| **Agent** | `.claude/agents/*.md` | ❌ 格式不同 | Pi 的 `agents/` 是 subagent system prompt，不兼容 |

---

## Skill 对接（已在模板中启用）

### 当前配置

`templates/pi/default.template.jsonc` 已启用：

```jsonc
"skills": [
  "~/.claude/skills",       // 全局 skill（用户级）
  "./.claude/skills"        // 项目级 skill（cwd 下）
],
"enableSkillCommands": true  // 暴露为 /skill:name 命令
```

### 效果

- Pi 启动时扫描 `~/.claude/skills/` 和 `cwd/.claude/skills/` 下的 `SKILL.md`
- 每个 skill 的 `name` 和 `description` 注入 system prompt
- 模型按需 `read` 完整 `SKILL.md`
- 用户可用 `/skill:ob-code-review` 等命令强制加载

### Agent Skills 标准

Pi 和 Claude Code 都实现了 [agentskills.io 标准](https://agentskills.io/specification)，所以结构和 frontmatter 兼容：

```markdown
---
name: my-skill
description: 一句话描述
---
# 完整说明
...
```

### 注意事项

- Pi 允许 skill name 与目录名不一致（Claude Code 也是如此）
- 如果全局和项目 skill 同名，**先加载的胜出**（user > project > path）
- skill 过多会增大 system prompt；建议项目级 skill 控制在 10 个以内

---

## Rule 对接（已通过扩展实现）

### 当前实现

`claude-rules.template.ts` 扩展已默认安装。它会：

1. 会话开始时递归扫描 `cwd/.claude/rules/` 下所有 `.md` 文件
2. 把**文件列表**（不是文件内容）追加到 system prompt
3. 模型收到提示后按需 `read` 相关 rule

### 与 Claude Code 的区别

| | Claude Code | Pi（通过扩展） |
|---|---|---|
| 注入方式 | **全文注入** system prompt | **仅列路径**，模型按需 read |
| 条件触发 | frontmatter `globs` 匹配当前文件 | 无条件列出所有 |
| 性能影响 | 上下文占用大 | 上下文占用小（但模型可能不主动 read） |

### 如何确保 rule 被读取

如果发现 Pi 对某条 rule 没有主动读，可以：

1. 在 `AGENTS.md` 里加一行提示：
   ```
   Before modifying files, check .claude/rules/ for applicable rules.
   ```
2. 或在 prompt 里显式引用：`按照 .claude/rules/ob-build-test.md 执行`

---

## Command 对接（不兼容，需手动转换）

### 原因

| 维度 | Claude Code Command | Pi Prompt Template |
|------|--------------------|--------------------|
| 路径 | `.claude/commands/*.md` (支持子目录命名空间) | `.pi/prompts/*.md` (**不递归**) |
| 参数 | `$ARGUMENTS` | `$@`、`$1`、`$2` ... |
| 文件引用 | `@file` 语法 | 不支持 |
| 命令名 | 文件路径即名（含 `/` 命名空间） | 文件名去 `.md` 即名 |

### 手动转换步骤

如果某条 command 内容简单，可以手动搬到 Pi：

1. 复制 `.claude/commands/foo.md` → `.pi/prompts/foo.md`
2. 把 `$ARGUMENTS` 替换为 `$@`
3. 删除不支持的 `@file` 引用
4. 删除 Claude Code 特有的 frontmatter 字段
5. 在 Pi 中用 `/foo` 调用

---

## Agent 对接（格式不同，不可共享）

- Claude Code 的 `.claude/agents/`: 声明 subagent 的 `description`、`tools`、`model`，由 Claude Code 内部路由调度
- Pi 的 `~/.pi/agent/agents/`: 完整 system prompt，由 `pi-subagents` 包驱动

两者用途类似但格式不同，无法直接复用。

---

## 参考

- [Pi 官方 Skills 文档](https://github.com/earendil-works/pi-coding-agent) — `docs/skills.md`
- [Agent Skills 标准](https://agentskills.io/specification)
- [claude-rules 扩展源码](./extensions/claude-rules.template.ts)
- [Pi Prompt Templates 文档](https://github.com/earendil-works/pi-coding-agent) — `docs/prompt-templates.md`
