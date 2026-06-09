# Pi 认证与 Provider 配置

> 本文档说明 Pi 的认证机制（`auth.json`）、Provider 定义（`models.json`）、以及它们与 `settings.json` 的关系。
>
> 主 settings 字段说明见 [default.template.jsonc](../templates/pi/default.template.jsonc)。
> 模型 / Provider 模板见 [models.template.jsonc](./models.template.jsonc)。

---

## 配置文件位置

所有运行时配置在 `~/.pi/agent/` 下：

| 文件 | 用途 | 模板 |
|------|------|------|
| `settings.json` | 用户偏好（主题、思考级别、压缩、包列表等）| `templates/pi/default.template.jsonc` |
| `models.json` | Provider 和模型定义 | `models.template.jsonc` |
| `auth.json` | 认证信息（API Key、OAuth Token） | 不进入模板 — 含敏感凭据 |

> `auth.json` 由 Pi 维护，权限 `0600`，**严禁**写入 git 或模板。

---

## auth.json：认证存储

### 结构

支持两种认证类型：

```json
{
  "<provider 名>": {
    "type": "api_key",
    "key": "<密钥或引用>"
  },
  "<oauth provider>": {
    "type": "oauth",
    "access": "<access_token>",
    "refresh": "<refresh_token>",
    "expires": 1780913178734,
    "accountId": "<可选 account id>"
  }
}
```

### `key` 字段支持的格式

| 格式 | 示例 | 说明 |
|------|------|------|
| 直接密钥 | `"sk-xxx"` | 直接存储 |
| 环境变量 | `"$OPENAI_API_KEY"` | 引用环境变量 |
| 环境变量（括号）| `"${OPENAI_API_KEY}"` | 同上，带括号 |
| Shell 命令 | `"!cat ~/.config/api_key.txt"` | 执行后读取 stdout |

### Bailian Coding 示例

```json
{
  "bailian": {
    "type": "api_key",
    "key": "$OPENAI_API_KEY"
  }
}
```

> 不建议把明文密钥写进 `auth.json`。优先用 `$OPENAI_API_KEY` 或 `!cat ~/.config/.../key.txt` 引用。

### API Key 获取优先级

Pi 按以下顺序解析 API Key：

1. **Runtime override** — CLI 参数 `--api-key`
2. **auth.json `api_key`** — `{ type: "api_key", key: "..." }`
3. **auth.json `oauth`** — OAuth Token（自动刷新）
4. **环境变量** — `models.json` 中 `apiKey` 字段指定的变量名
5. **Fallback resolver** — `models.json` 中的 custom provider config

> 一旦 `auth.json` 里存在该 provider 配置，**不会**再回退到环境变量。

---

## models.json：Provider / 模型定义

完整模板见 [models.template.jsonc](./models.template.jsonc)。下面是关键字段速查。

### 字段说明

| 字段 | 说明 |
|------|------|
| `baseUrl` | API 端点 |
| `api` | API 协议类型（如 `openai-completions`）|
| `apiKey` | 关联的**环境变量名**（与 auth.json 配合）|
| `compat.supportsDeveloperRole` | 是否支持 `developer` role |
| `compat.supportsReasoningEffort` | 是否支持 OpenAI 风格 reasoning effort |
| `models[].id` | 模型 ID（CLI / `/model` 中使用）|
| `models[].contextWindow` | 上下文窗口 tokens |
| `models[].maxTokens` | 单次最大输出 tokens |
| `models[].cost.*` | input/output/cacheRead/cacheWrite 单价 |

### `apiKey` 字段语义

`apiKey` **不是密钥本身**，而是声明 fallback 使用的环境变量名：

```jsonc
// models.json — 声明环境变量名
"apiKey": "OPENAI_API_KEY"

// auth.json — 真正的凭据（优先级更高）
"bailian": {
  "type": "api_key",
  "key": "$OPENAI_API_KEY"
}
```

如果 `auth.json` 里有 `bailian`，Pi 用它；否则才回退去读 `$OPENAI_API_KEY`。

---

## settings.json：用户偏好

`defaultProvider` / `defaultModel` 必须能在 `models.json` 中找到：

```json
{
  "defaultProvider": "bailian",
  "defaultModel": "glm-5",
  "defaultThinkingLevel": "medium",
  "theme": "flexoki-dark"
}
```

完整字段（含注释）见 [default.template.jsonc](../templates/pi/default.template.jsonc)。

---

## 完整链路示例：Bailian Coding

**1. `models.json`**（模板里已有，见 [models.template.jsonc](./models.template.jsonc)）：

```jsonc
{
  "providers": {
    "bailian": {
      "name": "百炼编码",
      "baseUrl": "https://coding.dashscope.aliyuncs.com/v1",
      "api": "openai-completions",
      "apiKey": "OPENAI_API_KEY",
      "models": [
        { "id": "glm-5", "name": "GLM-5", "contextWindow": 200000, ... }
      ]
    }
  }
}
```

**2. `auth.json`**（**手动维护**，不在模板中）：

```json
{
  "bailian": {
    "type": "api_key",
    "key": "$OPENAI_API_KEY"
  }
}
```

**3. `settings.json`**（来自 `templates/pi/default.template.jsonc`）：

```json
{
  "defaultProvider": "bailian",
  "defaultModel": "glm-5"
}
```

**4. 环境变量**（shell）：

```bash
export OPENAI_API_KEY='sk-sp-xxxxxxxxxxxxxxxxxxxx'
```

---

## 常见问题

### `401 invalid access token`

- 检查 `auth.json` 中是否有目标 provider 配置。
- 确认 `key` 字段格式正确：`{ "type": "api_key", "key": "..." }`。
- 确认 provider 名与 `models.json` 中定义一致。
- 如果是 OAuth，运行 `pi /logout` 后 `/login` 重新授权。

### MCP config 加载失败（`.mcp.json` 为空）

```bash
echo '{}' > .mcp.json
```

### 环境变量 vs `auth.json`

推荐使用 `auth.json` + `$ENV_VAR` 引用：

- 不污染 shell 环境
- 集中管理多 provider
- 文件权限 `0600`
- 模板里依然能保留 provider 定义，密钥**不进 git**

---

## 与 OpenCode 的对比

| 配置项 | Pi | OpenCode |
|--------|----|----------|
| 认证文件 | `~/.pi/agent/auth.json` | `~/.config/opencode/api_key_<provider>.txt` |
| Provider 配置 | `models.json` | `opencode.json` |
| API Key 引用 | `{ type: "api_key", key: "$ENV" }` | `{file:/path/to/key.txt}` 或 `{env:VAR}` |
| Base URL | `baseUrl` | `baseURL` |
| 权限 | `0600` | `0600`（key 文件） |

---

## 参考

- Pi GitHub: https://github.com/earendil-works/pi-coding-agent
- Bailian Coding API: https://coding.dashscope.aliyuncs.com/v1
- 模型清单：[../../docs/BAILIAN_CODING_MODELS.md](../../docs/BAILIAN_CODING_MODELS.md)
- 主 settings 模板：[../templates/pi/default.template.jsonc](../templates/pi/default.template.jsonc)
