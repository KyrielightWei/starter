# 代理配置指南

本文档介绍如何配置代理以通过企业网络访问 Codex API。

## 概述

Codex CLI 通过 HTTPS 访问 OpenAI API。在企业网络环境中，通常需要配置代理才能访问外部服务。

## 配置方法

### 方法 1: 环境变量（推荐）

在启动 OMP 前设置环境变量：

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1"

# 启动 OMP
omp
```

### 方法 2: MCP 配置文件

在 `~/.config/mcp/mcp.json` 中配置：

```json
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "codex",
      "args": ["mcp-server"],
      "env": {
        "HTTPS_PROXY": "http://proxy.example.com:8080",
        "HTTP_PROXY": "http://proxy.example.com:8080",
        "NO_PROXY": "localhost,127.0.0.1"
      }
    }
  }
}
```

### 方法 3: Shell 配置文件

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
# Codex 代理配置
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.example.com"
```

## 代理 URL 格式

### 基本格式

```
http://proxy.example.com:8080
```

### 带认证的格式

```
http://username:password@proxy.example.com:8080
```

### SOCKS5 代理

```
socks5://proxy.example.com:1080
```

## NO_PROXY 配置

`NO_PROXY` 用于指定不需要代理的地址：

```bash
# 多个地址用逗号分隔
export NO_PROXY="localhost,127.0.0.1,.example.com,10.0.0.0/8"
```

### 常见配置

| 场景 | NO_PROXY 值 |
|------|------------|
| 本地服务 | `localhost,127.0.0.1` |
| 内网域名 | `.example.com,.internal` |
| 内网 IP 段 | `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` |
| 组合配置 | `localhost,127.0.0.1,.example.com,10.0.0.0/8` |

## 常见代理服务器

### Squid 代理

```bash
export HTTPS_PROXY="http://squid.example.com:3128"
```

### Nginx 反向代理

```bash
export HTTPS_PROXY="http://nginx.example.com:8888"
```

### corporate proxy

```bash
export HTTPS_PROXY="http://corporate-proxy.example.com:8080"
```

## 验证代理配置

### 1. 测试代理连接

```bash
curl -x $HTTPS_PROXY https://api.openai.com
```

如果返回响应（即使是 401），说明代理工作正常。

### 2. 测试 Codex 连接

```bash
codex --help
```

如果命令正常执行，说明 Codex 可以访问。

### 3. 在 OMP 中测试

```
用户：用 codex 测试连接

OMP 会尝试调用 Codex，如果代理配置正确，应该能正常响应。
```

## 故障排除

### 问题 1: 连接超时

**症状：**
```
Error: Connection timeout
```

**解决方案：**
1. 检查代理地址是否正确
2. 检查代理服务器是否运行
3. 检查防火墙规则

```bash
# 测试代理可达性
ping proxy.example.com
telnet proxy.example.com 8080
```

### 问题 2: 认证失败

**症状：**
```
Error: Proxy authentication required
```

**解决方案：**
1. 检查用户名和密码是否正确
2. 检查 URL 编码（特殊字符需要编码）

```bash
# 正确编码密码
export HTTPS_PROXY="http://user:p%40ssw0rd@proxy.example.com:8080"
```

### 问题 3: 证书错误

**症状：**
```
Error: SSL certificate problem
```

**解决方案：**
1. 更新 CA 证书
2. 或临时禁用证书验证（不推荐）

```bash
# 更新证书（Ubuntu/Debian）
sudo update-ca-certificates

# 临时禁用（仅用于测试）
export NODE_TLS_REJECT_UNAUTHORIZED=0
```

### 问题 4: 内网地址被代理

**症状：**
访问内网服务时走代理，导致连接失败。

**解决方案：**
正确配置 `NO_PROXY`：

```bash
export NO_PROXY="localhost,127.0.0.1,.example.com,10.0.0.0/8"
```

## 高级配置

### PAC 文件

如果公司使用 PAC 文件：

```bash
# 下载 PAC 文件
curl -O http://proxy.example.com/proxy.pac

# 使用 pacproxy
npm install -g pacproxy
pacproxy http://proxy.example.com/proxy.pac &

export HTTPS_PROXY="http://localhost:8010"
```

### 多个代理

如果需要为不同目标使用不同代理：

```bash
# 使用 proxychains
sudo apt-get install proxychains

# 编辑 /etc/proxychains.conf
# 配置多个代理

# 通过 proxychains 运行
proxychains codex
```

## 最佳实践

1. **使用环境变量**：灵活且易于切换
2. **配置 NO_PROXY**：避免内网地址走代理
3. **测试连接**：配置后先测试
4. **文档化配置**：记录代理地址和认证信息
5. **定期更新**：代理服务器可能变更

## 下一步

- 查看 [故障排除](./troubleshooting.md) 解决常见问题
- 参考 [MCP 配置](./mcp-setup.md) 完成基础配置
