# Codex MCP 配置指南

本文档介绍如何配置 OMP 通过 MCP 协议调用 Codex CLI。

## 前置条件

1. **安装 Codex CLI**
   ```bash
   # 确保 codex 已安装
   codex --version
   ```

2. **验证 MCP 服务器可用**
   ```bash
   # 从仓库根目录运行离线验证，不会发起 OpenAI API 请求
   bash skill/codex-delegate/tests/test-mcp-config.sh
   ```

## 配置步骤

### 1. 创建 MCP 配置文件

编辑 `~/.config/mcp/mcp.json`：

```json
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "codex",
      "args": ["mcp-server"],
      "env": {
        "HTTPS_PROXY": "",
        "HTTP_PROXY": ""
      }
    }
  }
}
```

### 2. 配置代理（如需要）

如果需要通过代理访问 OpenAI API，设置环境变量：

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1"
```

或在 `mcp.json` 中配置：

```json
{
  "mcpServers": {
    "codex": {
      "env": {
        "HTTPS_PROXY": "http://proxy.example.com:8080",
        "HTTP_PROXY": "http://proxy.example.com:8080"
      }
    }
  }
}
```

### 3. 验证配置

从仓库根目录运行验证脚本：

```bash
bash skill/codex-delegate/tests/test-mcp-config.sh
```

脚本会检查 MCP JSON 配置、启动 `codex mcp-server`，并确认服务端暴露 `codex` 与 `codex-reply` 两个工具。

## 配置说明

| 字段 | 说明 | 示例 |
|------|------|------|
| `type` | 服务器类型 | `"stdio"` |
| `command` | 启动命令 | `"codex"` |
| `args` | 命令参数 | `["mcp-server"]` |
| `env` | 环境变量 | `{"HTTPS_PROXY": "..."}` |

## 常见问题

### Q: 如何知道配置是否成功？

A: 运行 `bash skill/codex-delegate/tests/test-mcp-config.sh`。如果脚本输出 `OK`，说明本机 MCP 配置和 Codex MCP tool schema 可用。

### Q: 代理配置不生效？

A: 检查以下几点：
1. 代理地址格式正确：`http://host:port`
2. 环境变量已设置：`echo $HTTPS_PROXY`
3. 代理服务器可访问：`curl -x $HTTPS_PROXY https://api.openai.com`

### Q: Codex 响应很慢？

A: 可能原因：
1. 网络延迟（检查代理）
2. 上下文过大（尝试手动模式指定文件）
3. Codex 服务器负载（稍后重试）

## 下一步

配置完成后，参考 [Skill 使用指南](./skill-usage.md) 了解如何使用 codex-delegate skill。
