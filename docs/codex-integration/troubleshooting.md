# 故障排除指南

本文档介绍 Codex 集成的常见问题和解决方案。

## 快速诊断

### 检查清单

在深入排查前，先确认以下几点：

- [ ] Codex CLI 已安装：`codex --version`
- [ ] MCP 配置正确：`~/.config/mcp/mcp.json` 存在
- [ ] 代理配置正确（如需要）：`echo $HTTPS_PROXY`
- [ ] OMP 已重启：配置更改后需要重启 OMP
- [ ] 网络连接正常：`curl https://api.openai.com`

## 常见问题

### 问题 1: MCP 服务器连接失败

**症状：**
```
Error: Cannot connect to codex mcp-server
Error: MCP server not found
```

**可能原因：**
1. Codex CLI 未安装
2. MCP 配置文件错误
3. Codex 版本过旧

**解决方案：**

```bash
# 1. 检查 Codex 是否安装
codex --version

# 如果未安装，参考 Codex 官方文档安装

# 2. 检查 MCP 配置文件
cat ~/.config/mcp/mcp.json

# 确保格式正确：
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "codex",
      "args": ["mcp-server"]
    }
  }
}

# 3. 测试 MCP 服务器
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | codex mcp-server

# 应该返回 JSON 响应

# 4. 更新 Codex（如果版本过旧）
npm update -g @openai/codex
```

### 问题 2: Codex 响应超时

**症状：**
```
Error: Request timeout
Error: Codex did not respond
```

**可能原因：**
1. 网络问题（代理配置错误）
2. API 密钥无效
3. 上下文过大
4. Codex 服务器负载高

**解决方案：**

```bash
# 1. 检查网络连接
curl -x $HTTPS_PROXY https://api.openai.com

# 2. 检查 API 密钥
echo $OPENAI_API_KEY

# 3. 减小上下文
# 使用手动模式指定少量文件
用 codex 优化这个文件：src/auth.ts

# 4. 稍后重试
# Codex 服务器可能暂时负载高
```

### 问题 3: threadId 失效

**症状：**
```
Error: Invalid threadId
Error: Session not found
```

**可能原因：**
1. Codex 会话已过期
2. Codex 服务重启
3. threadId 格式错误

**解决方案：**

```
# 1. 开始新会话
# 不要继续追问，而是重新开始
用 codex 分析这个问题

# 2. 检查 OMP 日志
# 查看 threadId 是否正确保存

# 3. 重启 OMP
# 清除会话状态
omp --restart
```

### 问题 4: 代理认证失败

**症状：**
```
Error: Proxy authentication required
Error: 407 Proxy Authentication Required
```

**可能原因：**
1. 用户名或密码错误
2. 密码包含特殊字符未编码
3. 代理服务器要求特殊认证方式

**解决方案：**

```bash
# 1. 检查凭据
echo $HTTPS_PROXY

# 2. 编码特殊字符
# 如果密码是 p@ssw0rd，需要编码为 p%40ssw0rd
export HTTPS_PROXY="http://user:p%40ssw0rd@proxy.example.com:8080"

# 3. 测试代理
curl -x $HTTPS_PROXY https://api.openai.com

# 4. 联系 IT 部门
# 确认代理服务器配置和认证方式
```

### 问题 5: 上下文提取不正确

**症状：**
- Codex 没有理解任务
- 返回的结果不相关
- 缺少关键文件

**可能原因：**
1. 智能模式提取错误
2. 文件路径不正确
3. 文件权限问题

**解决方案：**

```bash
# 1. 使用手动模式
# 明确指定需要的文件
用 codex 优化这些文件：src/auth.ts, src/user.ts

# 2. 检查文件路径
ls -la src/auth.ts

# 3. 检查文件权限
chmod 644 src/auth.ts

# 4. 使用完整模式
用 codex（完整上下文）分析这个问题
```

### 问题 6: Codex 返回错误代码

**症状：**
```
Error: Codex returned error code 401
Error: Unauthorized
```

**可能原因：**
1. API 密钥无效或过期
2. API 配额用尽
3. API 密钥权限不足

**解决方案：**

```bash
# 1. 检查 API 密钥
echo $OPENAI_API_KEY

# 2. 验证 API 密钥
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# 3. 检查配额
# 登录 OpenAI 平台查看使用情况

# 4. 更新 API 密钥
export OPENAI_API_KEY="sk-new-key-here"
```

## 调试技巧

### 1. 启用详细日志

```bash
# 设置调试环境变量
export DEBUG=omp:*
export MCP_DEBUG=1

# 重启 OMP
omp
```

### 2. 检查 MCP 通信

```bash
# 手动测试 MCP 服务器
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | codex mcp-server
```

### 3. 查看 OMP 日志

```bash
# 日志位置
~/.omp/logs/

# 查看最新日志
tail -f ~/.omp/logs/omp.log
```

### 4. 网络抓包

```bash
# 使用 tcpdump 抓包（需要 root）
sudo tcpdump -i any port 8080

# 或使用 mitmproxy
mitmproxy --mode regular
```

## 性能优化

### 1. 减少上下文

```bash
# 使用手动模式
用 codex 优化：src/auth.ts:10-50

# 避免使用完整模式（除非必要）
```

### 2. 缓存常用文件

```bash
# 将常用文件放在快速访问位置
# 使用 SSD 存储项目
```

### 3. 优化代理

```bash
# 使用就近的代理服务器
# 配置 NO_PROXY 避免内网走代理
export NO_PROXY="localhost,127.0.0.1,.example.com"
```

## 获取帮助

### 1. 查看文档

- [MCP 配置](./mcp-setup.md)
- [Skill 使用](./skill-usage.md)
- [上下文提取](./context-extraction.md)
- [代理配置](./proxy-config.md)

### 2. 检查示例

- [简单委托示例](../../skill/codex-delegate/examples/simple-delegation.md)
- [多轮对话示例](../../skill/codex-delegate/examples/multiturn-conversation.md)
- [手动上下文示例](../../skill/codex-delegate/examples/manual-context.md)

### 3. 提交问题

如果问题无法解决，提交 issue 时请包含：

1. 错误信息（完整）
2. 操作步骤
3. 环境信息（OS、OMP 版本、Codex 版本）
4. 配置文件（脱敏）
5. 日志文件（脱敏）

## 常见问题解答

### Q: 如何知道 Codex 是否在工作？

A: 在 OMP 中输入 `用 codex 测试`，如果能正常响应，说明工作正常。

### Q: 为什么有时快有时慢？

A: 响应时间受多个因素影响：
- 网络延迟
- 上下文大小
- Codex 服务器负载
- 代理性能

### Q: 可以同时使用多个 Codex 会话吗？

A: 可以，每个 Codex 会话有独立的 threadId。当前 skill 只指导助手保存和复用 threadId；是否自动管理取决于宿主是否提供会话状态 API。

### Q: 如何清除 Codex 会话历史？

A: 重启 OMP 或开始新会话会自动清除旧的 threadId。

### Q: Codex 的费用如何计算？

A: Codex 使用 OpenAI API，费用取决于：
- 使用的模型
- token 消耗量
- API 定价

可以通过 Codex 的审计日志查看详细使用情况。
