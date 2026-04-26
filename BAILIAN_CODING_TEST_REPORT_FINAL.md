# Bailian Coding Provider 第二轮完整测试报告

## 测试信息
- **测试时间**: 2026-04-10
- **测试轮次**: 第二轮（全面测试）
- **测试目的**: 确认 qwen3.6-plus 及所有变体在 bailian_coding provider 中的可用性

## 测试环境
- **Provider**: bailian_coding  
- **Base URL**: https://coding.dashscope.aliyuncs.com/v1
- **OpenCode CLI**: 1.3.15
- **API Key**: sk-sp-5071d171dc284eca8f7ac8b1462de7e2

---

## 一、支持的模型列表验证

### 使用 OpenCode CLI 获取
```bash
opencode models bailian_coding
```

### 结果
```
bailian_coding/glm-5
bailian_coding/kimi-k2.5
bailian_coding/MiniMax-M2.5
bailian_coding/qwen3.5-plus
```

✅ **确认支持 4 个模型**

---

## 二、已支持模型可用性测试

对每个已支持的模型进行实际调用测试：

### 1. glm-5 ✅
```bash
opencode run --model bailian_coding/glm-5 "你好，请回复：glm-5测试成功"
```
**结果**: ✅ 成功
**响应**: "你好！glm-5测试成功"

### 2. qwen3.5-plus ✅
```bash
opencode run --model bailian_coding/qwen3.5-plus "你好，请回复：qwen3.5测试成功"
```
**结果**: ✅ 成功
**响应**: "qwen3.5 测试成功"

### 3. kimi-k2.5 ✅
```bash
opencode run --model bailian_coding/kimi-k2.5 "你好，请回复：kimi测试成功"
```
**结果**: ✅ 成功
**响应**: "kimi测试成功"

### 4. MiniMax-M2.5 ✅
```bash
opencode run --model bailian_coding/MiniMax-M2.5 "你好，请回复：minimax测试成功"
```
**结果**: ✅ 成功
**响应**: "你好！👋 很高兴收到你的消息！系统运行正常，minimax 测试成功。😊"

### 测试总结
| 模型 | 状态 | 可用性测试 |
|------|------|-----------|
| glm-5 | ✅ 已注册 | ✅ 实测可用 |
| qwen3.5-plus | ✅ 已注册 | ✅ 实测可用 |
| kimi-k2.5 | ✅ 已注册 | ✅ 实测可用 |
| MiniMax-M2.5 | ✅ 已注册 | ✅ 实测可用 |

---

## 三、qwen3.6-plus 及所有变体测试

### 测试的变体列表（共 15 个）

测试了以下所有可能的命名变体：

1. ❌ qwen3.6-plus
2. ❌ qwen3.6
3. ❌ qwen3-6-plus
4. ❌ qwen-3.6-plus
5. ❌ qwen3.6-coder
6. ❌ qwen3.6-coder-plus
7. ❌ qwen3-6-coder
8. ❌ qwen3-6-coder-plus
9. ❌ qwen-coder-3.6
10. ❌ qwen-coder-3.6-plus
11. ❌ qwen3.6p
12. ❌ qwen3.6-plus-2025
13. ❌ qwen3.6-plus-latest
14. ❌ qwen3.6-turbo
15. ❌ qwen3.6-chat

### 测试结果
**所有 15 个变体均返回错误**:
- 错误类型: `ProviderModelNotFoundError`
- 错误信息: "Model not found: bailian_coding/qwen3.6-plus" (及相关变体)
- suggestions: [] (无替代建议)

---

## 四、最终结论

### ❌ qwen3.6-plus 在 bailian_coding provider 中不可用

**核心发现**:
1. bailian_coding provider 仅支持 4 个模型
2. qwen3.6 系列的任何命名变体都不在支持列表中
3. 所有已支持的模型实测均可正常使用
4. Bailian Coding API 拒绝直接的 HTTP API 请求，仅支持通过 Coding Agents (如 opencode CLI) 调用

### 支持状态对比

| 模型系列 | 支持版本 | 不支持版本 |
|---------|---------|-----------|
| Qwen | ✅ qwen3.5-plus | ❌ qwen3.6 系列（所有变体） |
| GLM | ✅ glm-5 | - |
| Kimi | ✅ kimi-k2.5 | - |
| MiniMax | ✅ MiniMax-M2.5 | - |

---

## 五、建议与后续行动

### 对于需要使用 qwen3.6-plus 的用户

**选项 1**: 使用已支持的替代模型
- ✅ **qwen3.5-plus** (推荐，同属 Qwen 系列)
- ✅ **glm-5** (性能优秀)
- ✅ **kimi-k2.5** 
- ✅ **MiniMax-M2.5**

**选项 2**: 使用其他 provider
- 检查其他 provider (如 `qwen`, `dashscope`) 是否支持 qwen3.6-plus
- 联系 Bailian Coding 官方确认未来的支持计划

**选项 3**: 等待官方支持
- qwen3.6-plus 可能还在开发或审批流程中
- 关注 Bailian Coding 的官方更新公告

### 配置建议

当前 `lua/ai/providers.lua` 中的配置已正确：

```lua
M.register("bailian_coding", {
  api_key_name = "BAILIAN_CODING_API_KEY",
  endpoint = "https://coding.dashscope.aliyuncs.com/v1",
  model = "glm-5",
  static_models = { "glm-5", "qwen3.5-plus", "kimi-k2.5", "MiniMax-M2.5" },
})
```

✅ **无需修改** - static_models 列表已准确反映实际支持的模型

---

## 六、测试文件

### 生成的测试文件
1. **Node.js 测试脚本**: `/root/tool/starter/test_bailian_models.js`
   - 用于 HTTP API 直接测试
   - 验证 API 访问限制
   
2. **Shell 测试脚本**: `/root/tool/starter/test_qwen36_variants.sh`
   - 测试 15 个 qwen3.6 变体命名
   - 自动化批量测试
   
3. **测试报告**: `/root/tool/starter/BAILIAN_CODING_TEST_REPORT_FINAL.md`
   - 本文档
   - 包含完整测试结果和建议

### 相关配置文件
- OpenCode 配置: `/root/.opencode/opencode.json`
- API Key: `/root/.opencode/api_key_bailian_coding.txt`
- Neovim 配置: `/root/tool/starter/lua/ai/providers.lua`

---

## 七、附录：完整测试输出

### qwen3.6-plus 测试输出示例
```
ProviderModelNotFoundError: ProviderModelNotFoundError
 data: {
  providerID: "bailian_coding",
  modelID: "qwen3.6-plus",
  suggestions: [],
}

Error: Model not found: bailian_coding/qwen3.6-plus.
```

### qwen3.5-plus 测试输出示例
```
> build · qwen3.5-plus
qwen3.5 测试成功
```

### glm-5 测试输出示例
```
> build · glm-5
你好！glm-5测试成功
```

---

**测试状态**: ✅ 完成  
**测试范围**: 全面（模型列表 + 可用性验证 + 15个变体测试）  
**最终结论**: qwen3.6-plus 及所有 qwen3.6 系列变体在 bailian_coding provider 中 **均不可用**