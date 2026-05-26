# Pi CLI 参考

完整 CLI 命令行选项参考。

## 基本用法

```bash
pi [options] [@files...] [messages...]
```

---

## 包管理命令

```bash
pi install <source> [-l]     # 安装包，-l 项目本地
pi remove <source> [-l]      # 移除包
pi uninstall <source> [-l]   # remove 别名
pi update                    # 更新 Pi 和包 (跳过锁定包)
pi update --extensions       # 只更新包
pi update --self             # 只更新 Pi
pi update --self --force     # 强制重装 Pi
pi update --extension <src>  # 更新单个包
pi list                      # 列出已安装包
pi config                    # 启用/禁用包资源
```

**包来源格式：**

| 格式 | 示例 |
|------|------|
| npm | `npm:@scope/pkg@1.2.3`, `npm:pkg` |
| git | `git:github.com/user/repo@v1`, `git:git@github.com:user/repo` |
| URL | `https://github.com/user/repo@v1`, `ssh://git@github.com/user/repo` |
| 本地 | `/absolute/path`, `./relative/path` |

---

## 运行模式

| 模式 | 命令 | 说明 |
|------|------|------|
| **交互式** | `pi` | 默认，TUI 交互界面 |
| **打印** | `pi -p` | 打印响应并退出 |
| **JSON** | `pi --mode json` | 输出所有事件为 JSON 行 |
| **RPC** | `pi --mode rpc` | stdin/stdout RPC 协议 |
| **导出** | `pi --export <in> [out]` | 导出会话为 HTML |

**打印模式示例：**

```bash
# 简单询问
pi -p "List all .ts files in src/"

# 管道输入
cat README.md | pi -p "Summarize this text"

# 文件引用
pi -p @screenshot.png "What's in this image?"
pi @code.ts @test.ts "Review these files"
```

---

## 模型选项

| 选项 | 说明 |
|------|------|
| `--provider <name>` | Provider (anthropic, openai, bailian 等) |
| `--model <pattern>` | 模型 ID 或模式，支持 `provider/id:thinking` |
| `--api-key <key>` | API key (覆盖环境变量) |
| `--thinking <level>` | 思考级别: off, minimal, low, medium, high, xhigh |
| `--models <patterns>` | Ctrl+P 循环模型模式 (逗号分隔) |
| `--list-models [search]` | 列出可用模型 |

**示例：**

```bash
# 不同模型
pi --provider openai --model gpt-4o "Help me refactor"

# Provider 前缀简写
pi --model openai/gpt-4o "Help me refactor"

# 思考级别简写
pi --model sonnet:high "Solve this complex problem"

# 高思考级别
pi --thinking high "Solve this complex problem"

# 限制模型循环
pi --models "claude-*,gpt-4o"
```

---

## 会话选项

| 选项 | 说明 |
|------|------|
| `-c`, `--continue` | 继续最近的会话 |
| `-r`, `--resume` | 浏览并选择会话 |
| `--session <path|id>` | 使用特定会话文件或部分 UUID |
| `--fork <path|id>` | Fork 特定会话到新会话 |
| `--session-dir <dir>` | 自定义会话存储目录 |
| `--no-session` | 临时模式 (不保存) |

**示例：**

```bash
pi -c                  # 继续最近会话
pi -r                  # 选择历史会话
pi --no-session        # 临时会话 (不保存)
pi --session abc123    # 使用特定会话 ID
pi --fork abc123       # Fork 会话 ID 到新会话
```

---

## 工具选项

| 选项 | 说明 |
|------|------|
| `--tools <list>` | 允许的工具列表 (逗号分隔) |
| `--no-builtin-tools` | 禁用内置工具 (保留扩展/自定义) |
| `--no-tools` | 禁用所有工具 |

**内置工具:** `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls`

**示例：**

```bash
# 只读模式
pi --tools read,grep,find,ls -p "Review the code"

# 禁用内置工具，只用扩展工具
pi --no-builtin-tools

# 禁用所有工具
pi --no-tools -p "Just chat"
```

---

## 资源选项

| 选项 | 说明 |
|------|------|
| `-e`, `--extension <source>` | 加载扩展 (路径/npm/git，可重复) |
| `--no-extensions` | 禁用扩展发现 |
| `--skill <path>` | 加载技能 (可重复) |
| `--no-skills` | 禁用技能发现 |
| `--prompt-template <path>` | 加载提示模板 (可重复) |
| `--no-prompt-templates` | 禁用提示模板发现 |
| `--theme <path>` | 加载主题 (可重复) |
| `--no-themes` | 禁用主题发现 |
| `--no-context-files`, `-nc` | 禁用 AGENTS.md/CLAUDE.md |

**组合示例：**

```bash
# 只加载特定扩展，忽略其他
pi --no-extensions -e ./my-ext.ts

# 最小配置运行
pi --no-extensions --no-skills --no-prompt-templates

# 禁用上下文文件
pi -nc
```

---

## 其他选项

| 选项 | 说明 |
|------|------|
| `--system-prompt <text>` | 替换默认提示 |
| `--append-system-prompt <text>` | 追加到系统提示 |
| `--verbose` | 强制详细启动 |
| `--offline` | 禁用所有启动网络操作 |
| `-h`, `--help` | 显示帮助 |
| `-v`, `--version` | 显示版本 |

---

## 环境变量

| 变量 | 说明 |
|------|------|
| `PI_CODING_AGENT_DIR` | 覆盖配置目录 (默认 `~/.pi/agent`) |
| `PI_CODING_AGENT_SESSION_DIR` | 覆盖会话存储目录 |
| `PI_PACKAGE_DIR` | 覆盖包目录 |
| `PI_OFFLINE` | 禁用启动网络操作 (包括更新检查) |
| `PI_SKIP_VERSION_CHECK` | 跳过 Pi 版本更新检查 |
| `PI_TELEMETRY` | 覆盖遥测 (1/true/yes 或 0/false/no) |
| `PI_CACHE_RETENTION` | 设置为 `long` 扩展缓存保留 |
| `VISUAL`, `EDITOR` | Ctrl+G 外部编辑器 |

---

## 文件引用

用 `@` 前缀引用文件：

```bash
pi @prompt.md "Answer this"
pi -p @screenshot.png "What's in this image?"
pi @code.ts @test.ts "Review these files"
```

---

## 交互模式命令

在 TUI 中输入 `/` 触发：

| 命令 | 说明 |
|------|------|
| `/login`, `/logout` | OAuth 认证 |
| `/model` | 切换模型 |
| `/scoped-models` | 启用/禁用 Ctrl+P 模型循环 |
| `/settings` | 设置界面 |
| `/resume` | 选择历史会话 |
| `/new` | 新会话 |
| `/name <name>` | 设置会话名称 |
| `/session` | 显示会话信息 |
| `/tree` | 会话树导航 |
| `/fork` | Fork 到新会话 |
| `/clone` | Clone 当前分支 |
| `/compact [prompt]` | 手动压缩 |
| `/copy` | 复制最后助手消息 |
| `/export [file]` | 导出为 HTML |
| `/share` | 上传为 GitHub gist |
| `/reload` | 重载配置 |
| `/hotkeys` | 显示快捷键 |
| `/changelog` | 版本历史 |
| `/quit` | 退出 |

---

## 快捷键

| 键 | 动作 |
|-----|------|
| `Ctrl+C` | 清空编辑器 |
| `Ctrl+C` (两次) | 退出 |
| `Escape` | 取消/中止 |
| `Escape` (两次) | 打开 `/tree` |
| `Ctrl+L` | 模型选择器 |
| `Ctrl+P` | 循环模型前进 |
| `Shift+Ctrl+P` | 循环模型后退 |
| `Shift+Tab` | 循环思考级别 |
| `Ctrl+O` | 折叠/展开工具输出 |
| `Ctrl+T` | 折叠/展开思考块 |
| `Shift+Enter` | 换行 (不提交) |
| `Alt+Enter` | Follow-up 消息 |
| `Alt+Up` | 取回队列消息 |
| `Ctrl+G` | 外部编辑器 |
| `@` | 文件引用 |
| `/` | 命令 |
| `!command` | 运行 bash，输出到 LLM |
| `!!command` | 运行 bash，不发送输出 |

---

## 示例场景

### 只读代码审查

```bash
pi --tools read,grep,find,ls -p "Review the authentication module"
```

### 高思考解决复杂问题

```bash
pi --thinking high "Debug this memory leak"
```

### 临时会话

```bash
pi --no-session "Quick question"
```

### 继续上次会话

```bash
pi -c
```

### 管道输入

```bash
cat error.log | pi -p "Explain these errors"
git diff | pi -p "Review these changes"
```

### 多文件审查

```bash
pi @src/auth.ts @src/user.ts @tests/auth.spec.ts "Review these files for security issues"
```

### 扩展测试

```bash
pi -e ./my-extension.ts
pi --no-extensions -e ./test-ext.ts
```

### 离线模式

```bash
PI_OFFLINE=1 pi
```

### 特定模型

```bash
pi --model bailian/glm-5:medium "Explain this algorithm"
```

### 完全隔离

```bash
pi --no-session --no-extensions --no-skills --no-prompt-templates --no-context-files
```