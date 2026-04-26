# Bailian Coding API 测试报告

## 测试日期
2026-04-10

## 测试目的
测试 qwen3.6-plus 模型在 bailian_coding provider 中是否可用

## 测试环境

### API 配置
- **Provider**: bailian_coding
- **Base URL**: https://coding.dashscope.aliyuncs.com/v1
- **API Key**: sk-sp-5071d171dc284eca8f7ac8b1462de7e2
- **OpenCode CLI Version**: 1.3.15

## 测试方法

### 1. HTTP API 直接测试
尝试直接调用 Bailian Coding API endpoint：
- 测试 `/v1/models` 端点获取模型列表
- 测试 `/v1/chat/completions` 端点发送聊天请求

**结果**: ❌ 失败
- HTTP 状态码: 405 Method Not Allowed
- 错误信息: "Coding Plan is currently only available for Coding Agents"
- **原因**: Bailian Coding API 是专门为 Coding Agents (如 opencode CLI) 设计的，不接受标准的 HTTP API 请求

### 2. OpenCode CLI 测试
使用 opencode CLI 的 `models` 命令查询支持的模型列表：

```bash
opencode models bailian_coding
```

**结果**: ✅ 成功获取模型列表

### 3. 模型可用性测试

#### 已知支持的模型测试
使用 opencode CLI 测试已知支持的模型：

```bash
opencode run --model bailian_coding/qwen3.5-plus "你好，请回复：测试成功"
```

**结果**: ✅ qwen3.5-plus 可用，返回 "测试成功"

#### qwen3.6-plus 测试
尝试使用 qwen3.6-plus 模型：

```bash
opencode run --model bailian_coding/qwen3.6-plus "你好"
```

**结果**: ❌ 失败
- 错误类型: ProviderModelNotFoundError
- 错误信息: "Model not found: bailian_coding/qwen3.6-plus"
- 建议列表: 空 (无替代模型建议)

## 测试结果总结

### Bailian Coding Provider 支持的模型列表

截至测试时间，bailian_coding provider 支持以下模型：

| 模型名称 | 状态 | 测试结果 |
|---------|------|---------|
| glm-5 | ✅ 已注册 | 配置中存在 |
| qwen3.5-plus | ✅ 已注册且可用 | 测试通过 |
| kimi-k2.5 | ✅ 已注册 | 配置中存在 |
| MiniMax-M2.5 | ✅ 已注册 | 配置中存在 |

### qwen3.6-plus 测试结论

**❌ qwen3.6-plus 模型在 bailian_coding provider 中不可用**

**原因分析**:
1. qwen3.6-plus 模型尚未在 bailian_coding provider 中注册
2. Bailian Coding Plan 目前仅支持上述 4 个模型
3. 该模型可能还在开发中或尚未通过 Bailian Coding Plan 的审批

## 测试的其他 qwen3.6 变体

尝试了以下 qwen3.6 的可能命名变体，均失败：
- qwen3.6-plus ❌
- qwen3.6-plus-latest ❌
- qwen3-6-plus ❌
- qwen-3.6-plus ❌
- qwen3.6 ❌
- qwen3.6-coder ❌
- qwen3.6-coder-plus ❌
- qwen3-6-coder-plus ❌

## 建议

### 对于用户
- ✅ **可以使用**: qwen3.5-plus (已验证可用)
- ✅ **可以使用**: glm-5, kimi-k2.5, MiniMax-M2.5 (已注册)
- ❌ **暂不可用**: qwen3.6-plus

### 后续行动
1. 如果需要使用 qwen3.6-plus，建议：
   - 联系 Bailian Coding 官方确认模型支持计划
   - 或使用其他支持 qwen3.6-plus 的 provider

2. 更新配置文件：
   - providers.lua 中 bailian_coding 的 static_models 应仅包含已支持的模型
   - 当前配置正确：`{ "glm-5", "qwen3.5-plus", "kimi-k2.5", "MiniMax-M2.5" }`

## 测试脚本

测试脚本已保存在：
- `/root/tool/starter/test_bailian_models.js`

该脚本可用于：
- 验证 HTTP API 访问限制
- 测试多个模型名称变体
- 输出详细的错误信息

## 相关文件

- OpenCode 配置: `/root/.opencode/opencode.json`
- API Key 存储: `/root/.opencode/api_key_bailian_coding.txt`
- Provider 配置: `/root/tool/starter/lua/ai/providers.lua`

---

**测试完成时间**: 2026-04-10
**测试状态**: ✅ 完成
**结论**: qwen3.6-plus 在 bailian_coding provider 中 **不可用**