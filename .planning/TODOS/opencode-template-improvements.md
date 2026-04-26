# TODO: 未来优化 OpenCode 配置模版

## 背景

当前 `opencode.template.jsonc` 是一个静态基础模版，不包含 GSD 阶段生成的动态内容。未来需要在 `:OpenCodeGenerateConfig` 生成流程中集成更多动态配置能力。

---

## 待办事项

### 1. 🔲 动态 provider 检测与注入

**优先级:** Medium
**状态:** 当前模版写死了 provider，生成器未从 key 文件动态读取

**需要：** 在 `lua/ai/opencode.lua` 的生成逻辑中：
- 从 `providers.lua` 中动态读取当前 provider 的 baseURL、apiKey 路径
- 自动写入 `opencode.json` 的 `provider` 段

### 2. 🔲 模型白名单动态生成

**优先级:** Low
**状态:** 当前模版 model 字段静态写死

**需要：** 根据 provider 支持的模型列表，动态生成 `provider.xxx.models` 配置

---

## 涉及文件

| 文件 | 说明 |
|------|------|
| `opencode.template.jsonc` | OpenCode 配置模版（需更新） |
| `lua/ai/opencode.lua` | OpenCode 配置生成器（需更新生成逻辑） |
| `lua/ai/providers.lua` | Provider 注册表 |

---

## 历史记录

### 2026-04-20: 插件测试总结

**测试了两个 token 相关插件，均无法满足需求：**

#### opencode-quota (157 ⭐)

- ❌ 配额条数据不准确（provider ID `bailian_coding` 不被识别）
- ❌ 改成 `alibaba-coding-plan` 后历史数据丢失
- ❌ 无法显示实时 token 速率（用户核心需求）
- ⚠️ 费用估算依赖 models.dev，自定义模型名匹配不准
- **结论：** 卸载

#### Context Analysis Plugin (99 ⭐)

- ❌ 插件无法正确加载（工具 `context_usage` 未注册）
- ❌ 尝试了多种安装方式（`.opencode/`、`plugins/`、编译 `.ts` → `.js`）均失败
- ❌ tokenizer 依赖 `@huggingface/transformers` 安装失败（onnxruntime CUDA 问题）
- **结论：** 卸载

---

## 当前推荐方案

对于 OpenCode token 统计，推荐使用内置命令：

```bash
opencode stats
```

在终端运行，查看：
- 累计 sessions、messages 数量
- 累计 Input/Output tokens
- 工具使用频率分布

**局限性：** 没有实时 token 速率显示（如 ccstatusline 的 `11.3k t/s`）

---

## 参考

- OpenCode stats 命令: `opencode stats`（终端运行）
- 当前 provider: `bailian_coding` (自定义名)