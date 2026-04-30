# Bailian Coding Provider 模型参考文档

> 本文档记录阿里云百炼官方文档中的模型 context_length 信息，用于配置 OpenCode。
> 数据来源：[阿里云百炼模型列表](https://help.aliyun.com/zh/model-studio/getting-started/models)

## 官方模型 Context Length 数据

### 千问系列（Qwen）

| 模型 | 上下文长度 (Tokens) | 简化表示 | 最大输入 | 最大输出 | 说明 |
|------|---------------------|---------|---------|---------|------|
| **qwen3.6-max-preview** | 262,144 | 256k | 229,376 | 65,536 | 旗舰模型，复杂任务 |
| **qwen3.6-plus** | 1,000,000 | 1M | 983,616 | 65,536 | 效果、速度、成本均衡 |
| **qwen3.6-flash** | 1,000,000 | 1M | 983,616 | 65,536 | 快速模型，成本低 |
| **qwen3.5-plus** | 983,616 ~ 1M | 1M | 983,616 | 65,536 | 支持多模态 |
| **qwen3.5-flash** | 1,000,000 | 1M | 983,616 | 65,536 | 快速响应 |
| **qwen3-max** | 262,144 | 256k | 258,048 | 65,536 | Qwen3 系列 |

### GLM 系列（智谱 AI）

| 模型 | 上下文长度 (Tokens) | 简化表示 | 最大输入 | 最大思维链 | 最大回复 |
|------|---------------------|---------|---------|-----------|---------|
| **glm-5.1** | 202,745 | 200k | 202,745 | 131,072 | 131,072 |
| **glm-5** | 202,752 | 200k | 202,752 | 32,768 | 16,384 |
| **glm-4.7** | 169,984 | 160k | - | - | - |
| **glm-4.6** | 131,072 | 128k | - | - | - |

### Kimi 系列（月之暗面）

| 模型 | 上下文长度 (Tokens) | 简化表示 | 最大输入 | 最大思维链 | 最大回复 |
|------|---------------------|---------|---------|-----------|---------|
| **kimi-k2.6** | 262,144 | 256k | 258,048 | 81,920 | 98,304 |
| **kimi-k2.5** | 262,144 | 256k | 258,048 | 81,920 | 98,304 |

### MiniMax 系列（稀宇科技）

| 模型 | 上下文长度 (Tokens) | 简化表示 | 最大输入 | 最大输出 |
|------|---------------------|---------|---------|---------|
| **MiniMax-M2.5** | 196,608 | 192k | 196,601 | 32,768 |
| **MiniMax-M2.1** | 204,800 | 200k | 172,032 | - |

---

## Bailian Coding Provider 支持的模型

根据实际测试（2026-04-10），bailian_coding provider 支持：

| 模型 | Context Length | 状态 | 推荐用途 |
|------|---------------|------|---------|
| **glm-5** | 200k | ✅ 可用 | 默认模型，复杂推理和代码审查 |
| **qwen3.5-plus** | 1M | ✅ 可用 | 快速模型，简单任务和文档生成 |
| **qwen3.6-plus** | 1M | ✅ 可用 | 备选模型，效果均衡 |
| **kimi-k2.5** | 256k | ✅ 可用 | 长文本专家，超长上下文处理 |
| **MiniMax-M2.5** | 192k | ✅ 可用 | 备选方案，多场景支持 |

---

## 配置建议

### OpenCode 配置示例

```json
{
  "provider": {
    "bailian_coding": {
      "models": {
        "glm-5": {
          "name": "glm-5",
          "description": "默认模型 - 智谱GLM-5，复杂推理和代码审查",
          "limit": {
            "context": 202752,
            "output": 16384
          }
        },
        "qwen3.5-plus": {
          "name": "qwen3.5-plus",
          "description": "快速模型 - 阿里Qwen3.5-Plus，适合简单任务和文档生成",
          "limit": {
            "context": 1000000,
            "output": 65536
          }
        },
        "qwen3.6-plus": {
          "name": "qwen3.6-plus",
          "description": "备选模型 - 阿里Qwen3.6-Plus，效果均衡",
          "limit": {
            "context": 1000000,
            "output": 65536
          }
        },
        "kimi-k2.5": {
          "name": "kimi-k2.5",
          "description": "长文本专家 - Moonshot Kimi，超长上下文处理",
          "limit": {
            "context": 262144,
            "output": 98304
          }
        },
        "MiniMax-M2.5": {
          "name": "MiniMax-M2.5",
          "description": "备选方案 - MiniMax模型，多场景支持",
          "limit": {
            "context": 196608,
            "output": 32768
          }
        }
      }
    }
  }
}
```

**注意**: OpenCode 使用 `limit.context` 和 `limit.output` 字段，而不是 `context_length`。

### 模型选择策略

1. **默认模型**: `glm-5` - 200k 上下文，复杂推理能力强
2. **快速模型**: `qwen3.5-plus` - 1M 上下文，响应速度快
3. **备选模型**: `qwen3.6-plus` - 1M 上下文，效果均衡
4. **长文本**: `kimi-k2.5` - 256k 上下文，超长文本处理
5. **多场景**: `MiniMax-M2.5` - 192k 上下文，Agent 任务处理

---

## 价格参考（中国内地）

### Qwen 系列

| 模型 | 输入价格 (每百万 Token) | 输出价格 (每百万 Token) |
|------|------------------------|------------------------|
| qwen3.6-max-preview | 9-15 元（阶梯） | 54-90 元 |
| qwen3.6-plus | 2-8 元（阶梯） | 12-48 元 |
| qwen3.6-flash | 1.2 元 | 7.2 元 |
| qwen3.5-plus | 0.8-4 元（阶梯） | 4.8-24 元 |

### GLM 系列

| 模型 | 输入价格 | 输出价格 |
|------|---------|---------|
| glm-5.1 | 阶梯计价 | 阶梯计价 |
| glm-5 | 阶梯计价 | 阶梯计价 |

### Kimi 系列

| 模型 | 输入价格 | 输出价格 |
|------|---------|---------|
| kimi-k2.6 | 6.5 元 | 27 元 |
| kimi-k2.5 | 4 元 | 21 元 |

### MiniMax 系列

| 模型 | 输入价格 | 输出价格 |
|------|---------|---------|
| MiniMax-M2.5 | 2.1 元 | 8.4 元 |

---

## 更新记录

- **2026-04-29**: 添加 qwen3.6-plus，更新官方 context_length 数据
- **2026-04-10**: 初始测试报告，确认 bailian_coding 支持的模型列表

## 参考链接

- [阿里云百炼模型列表](https://help.aliyun.com/zh/model-studio/getting-started/models)
- [千问 API 参考](https://help.aliyun.com/zh/model-studio/developer-reference/use-qwen-by-calling-api)
- [GLM 模型文档](https://help.aliyun.com/zh/model-studio/glm)
- [Kimi 模型文档](https://help.aliyun.com/zh/model-studio/kimi-api)
- [MiniMax 模型文档](https://help.aliyun.com/zh/model-studio/minimax-api)