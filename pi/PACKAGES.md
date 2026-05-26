# Pi 包管理

Pi 包通过 npm 或 git 分发扩展、技能、提示模板和主题。

---

## 安装和管理

> **安全警告:** Pi 包拥有完整系统权限。扩展执行任意代码，技能可以指示模型执行任何操作包括运行可执行文件。安装第三方包前请审查源代码。

```bash
# npm 包
pi install npm:@scope/pi-tools
pi install npm:@scope/pi-tools@1.2.3      # 锁定版本

# git 包
pi install git:github.com/user/repo
pi install git:github.com/user/repo@v1    # 锁定 tag/commit
pi install git:git@github.com:user/repo    # SSH 格式
pi install https://github.com/user/repo    # HTTPS URL
pi install ssh://git@github.com/user/repo  # SSH URL

# 本地包
pi install /absolute/path/to/package
pi install ./relative/path/to/package

# 项目本地安装 (写入 .pi/settings.json)
pi install npm:@foo/bar -l

# 移除包
pi remove npm:@foo/bar
pi uninstall npm:@foo/bar                  # 别名

# 列出已安装包
pi list

# 更新
pi update                    # 更新 Pi 和包 (跳过锁定包)
pi update --extensions       # 只更新包
pi update --self             # 只更新 Pi
pi update --self --force     # 强制重装 Pi
pi update npm:@foo/bar       # 更新单个包
```

---

## 包来源格式

### npm

```
npm:@scope/pkg@1.2.3
npm:pkg
```

- 版本锁定包被 `pi update` 跳过
- 用户安装到 `~/.pi/agent/npm/`
- 项目安装到 `.pi/npm/`
- 使用 `npmCommand` 设置包装器 (如 mise, asdf)

### git

```
git:github.com/user/repo@v1
git:git@github.com:user/repo@v1
https://github.com/user/repo@v1
ssh://git@github.com/user/repo@v1
```

- 支持 HTTPS 和 SSH
- SSH 使用配置的密钥 (遵循 `~/.ssh/config`)
- `@ref` 锁定 tag 或 commit，`pi update` 不会移动
- 克隆到 `~/.pi/agent/git/<host>/<path>` (用户) 或 `.pi/git/<host>/<path>` (项目)

**非交互式 CI：**

```bash
GIT_TERMINAL_PROMPT=0 pi install git:github.com/user/repo
GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" pi install git:git@github.com:user/repo
```

### 本地路径

```
/absolute/path/to/package
./relative/path/to/package
```

---

## 临时试用

用 `-e` (或 `--extension`) 临时加载包：

```bash
pi -e npm:@foo/bar
pi -e git:github.com/user/repo
pi -e ./local-extension.ts
```

---

## 创建 Pi 包

### package.json 配置

```json
{
  "name": "my-pi-package",
  "version": "1.0.0",
  "keywords": ["pi-package"],
  "pi": {
    "extensions": ["./extensions"],
    "skills": ["./skills"],
    "prompts": ["./prompts"],
    "themes": ["./themes"]
  }
}
```

### 自动发现结构

没有 `pi` 配置时，自动发现：

```
my-pi-package/
├── extensions/
│   ├── my-tool.ts
│   └── my-command.ts
├── skills/
│   └── my-skill/SKILL.md
├── prompts/
│   └── my-prompt.md
└── themes/
│   └── my-theme.json
```

---

## 包结构示例

```
my-pi-package/
├── package.json           # npm 包定义
├── extensions/
│   ├── index.ts           # 扩展入口 (可选)
│   ├── my-tool.ts         # 单个扩展
│   └── subdir/
│       └── index.ts       # 子目录扩展
├── skills/
│   └── my-skill/
│       ├── SKILL.md       # 技能定义
│       └── templates/
│           └── template.md
├── prompts/
│   └── review.md          # 提示模板
│   └── refactor.md
└── themes/
│   └── my-theme.json      # 主题文件
```

---

## 依赖管理

### runtime 依赖

```json
{
  "dependencies": {
    "some-lib": "^1.0.0"
  }
}
```

git 包安装使用 `npm install --omit=dev`，所以 runtime 依赖必须在 `dependencies`。

### devDependencies

仅开发时需要，运行时不可用。

### npmCommand 包装器

使用 Node 版本管理器时：

```json
// settings.json
{
  "npmCommand": ["mise", "exec", "node@20", "--", "npm"]
}
```

---

## 启用/禁用资源

```bash
pi config                  # 打开配置界面
```

在 settings.json 中：

```json
{
  "disabledExtensions": ["my-pkg/my-ext"],
  "disabledSkills": ["my-pkg/my-skill"],
  "disabledPrompts": ["my-pkg/my-prompt"],
  "disabledThemes": ["my-pkg/my-theme"]
}
```

---

## 已安装包查看

```bash
pi list
```

输出格式：

```
npm:@foo/bar@1.0.0
git:github.com/obra/superpowers@abc123
```

---

## 更新锁定包

锁定包 (`@version` 或 `@commit`) 被 `pi update` 跳过。

更新锁定包：

```bash
# 更新到新版本
pi install npm:@foo/bar@1.2.0

# 更新到新 tag/commit
pi install git:github.com/user/repo@v2
```

---

## 推荐 Pi 包

| 包 | 说明 |
|----|------|
| `git:github.com/obra/superpowers` | 高级技能集合 (TDD, debugging, code review 等) |
| `npm:@earendil-works/pi-mcp` | MCP 服务器集成 |

---

## 发布 Pi 包

1. 创建 `package.json`，添加 `keywords: ["pi-package"]`
2. 添加 `pi` 配置或使用自动发现目录
3. 发布到 npm:

```bash
npm publish
```

或推送到 git 仓库。

4. 用户安装：

```bash
pi install npm:your-package
pi install git:github.com/your/repo
```

---

## 搜索 Pi 包

- npmjs.com: [搜索 `keywords:pi-package`](https://www.npmjs.com/search?q=keywords%3Api-package)
- Discord: [#pi-packages 频道](https://discord.com/channels/1456806362351669492/1457744485428629628)