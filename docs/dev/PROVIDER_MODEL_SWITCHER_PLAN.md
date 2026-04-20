# Provider/Model Switcher Enhancement - 详细设计文档

> 创建日期：2026-04-19
> 目标：优化 Provider 和 Model 选择/切换系统，实现任务级模型分配

---

## 一、设计目标

### 1.1 当前问题

```
当前流程（分散、不直观）:
┌─────────────────────────────────────────────────────────┐
│  <leader>ks (Model Switch)                              │
│      ↓                                                   │
│  Provider 选择 → Model 选择                              │
│      ↓                                                   │
│  全局切换（所有工具共用一个 Provider/Model）              │
│                                                          │
│  问题:                                                   │
│  ✗ ECC wave 用什么模型？不清楚                          │
│  ✗ GSD spec 用什么模型？不清楚                          │
│  ✗ 不同任务需要不同模型能力，但无法单独配置              │
│  ✗ 状态仅保存在内存，重启后丢失                         │
│  ✗ 无法看到"哪个工具/任务使用哪个模型"的整体视图         │
└─────────────────────────────────────────────────────────┘
```

### 1.2 设计目标

```
目标流程（统一、可视化、任务级）:
┌─────────────────────────────────────────────────────────┐
│  <leader>ks (统一入口)                                  │
│      ↓                                                   │
│  Header 显示:                                            │
│    ┌───────────────────────────────────────────┐        │
│    │ Tool Assignments:                          │        │
│    │   OpenCode → qwen3.6-plus                  │        │
│    │   Claude   → claude-sonnet-4-6             │        │
│    │                                             │        │
│    │ Task Assignments:                           │        │
│    │   ECC Wave    → claude-opus-4-6 (深度推理) │        │
│    │   GSD Spec    → claude-sonnet-4-6 (编码)   │        │
│    │   Quick Chat  → qwen3.6-plus (快速响应)    │        │
│    └───────────────────────────────────────────┘        │
│      ↓                                                   │
│  Provider → Model → 分配目标 (三级联动)                  │
│      ↓                                                   │
│  状态持久化到 ~/.local/state/nvim/ai_assignment.lua      │
│      ↓                                                   │
│  配置生成时自动应用任务级设置                            │
└─────────────────────────────────────────────────────────┘
```

### 1.3 核心价值

| 场景 | 当前行为 | 目标行为 |
|------|----------|----------|
| **ECC 执行 wave** | 用全局模型（可能不适合） | 自动使用 wave 专用模型（深度推理） |
| **GSD 生成 spec** | 用全局模型 | 自动使用 spec 专用模型（结构化输出） |
| **日常问答** | 用全局模型（可能太慢） | 用 quick chat 模型（快速响应） |
| **查看配置状态** | 无直观视图 | Header 显示所有分配 |
| **配置持久化** | 内存状态，重启丢失 | 文件持久化，重启保留 |

---

## 二、交互设计模式

### 2.1 UI 结构（借鉴 CC Switch）

```
╔══════════════════════════════════════════════════════════════════╗
║  AI Model & Provider Manager                        [?] Help     ║
╠══════════════════════════════════════════════════════════════════╣
║  Current Assignments:                                             ║
║    Tools:                                                         ║
║      OpenCode  → bailian_coding / qwen3.6-plus                    ║
║      Claude    → anthropic / claude-sonnet-4-6                    ║
║    Tasks:                                                         ║
║      ECC Wave   → anthropic / claude-opus-4-6 (deep reasoning)   ║
║      GSD Spec   → anthropic / claude-sonnet-4-6 (structured)     ║
║      Quick Chat → bailian_coding / qwen3.6-turbo (fast)          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > ○ anthropic                                                    ║
║    ○ bailian_coding                                               ║
║    ○ deepseek                                                     ║
║    ○ openai                                                       ║
║                                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  Preview (右侧):                                                  ║
║    Provider: Anthropic                                            ║
║    Endpoint: https://api.anthropic.com                            ║
║    Models:                                                        ║
║      • claude-opus-4-6 (deepest reasoning)                       ║
║      • claude-sonnet-4-6 (best coding)                           ║
║      • claude-haiku-4-5 (fastest)                                ║
║                                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  Keys: [Enter] Select → [s] Quick Switch │ [v] View Details      ║
╚══════════════════════════════════════════════════════════════════╝

选择 Provider 后进入 Model 选择:

╔══════════════════════════════════════════════════════════════════╗
║  Select Model for: anthropic                                     ║
╠══════════════════════════════════════════════════════════════════╣
║  Current Assignments:                                             ║
║    Tools: OpenCode → qwen3.6-plus, Claude → claude-sonnet-4-6    ║
║    Tasks: ECC Wave → claude-opus-4-6                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > ✓ claude-sonnet-4-6  ← 当前 Claude Code 使用                  ║
║    ○ claude-opus-4-6   ← 推荐 ECC Wave 任务                      ║
║    ○ claude-haiku-4-5  ← 推荐 Quick Chat 任务                    ║
║                                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  Keys: [Enter] Assign │ [t] To Task │ [g] To Tool │ [a] All     ║
╚══════════════════════════════════════════════════════════════════╝

选择 Model 后进入分配目标:

╔════════════════════════════════════════════════════════════════╗
║  Assign claude-opus-4-6 to:                                    ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Tools:                                                        ║
║    ○ OpenCode  (current: qwen3.6-plus)                         ║
║    ○ Claude    (current: claude-sonnet-4-6)                    ║
║                                                                ║
║  Tasks:                                                        ║
║    ✓ ECC Wave  ← 推荐！深度推理适合 wave 执行                  ║
║    ○ GSD Spec  (current: claude-sonnet-4-6)                    ║
║    ○ Quick Chat (current: qwen3.6-turbo)                       ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

### 2.2 快捷键设计

| 按键 | 作用 | 说明 |
|------|------|------|
| `Enter` | 选择/进入下一级 | Provider → Model → 分配目标 |
| `s` | 快速切换全局 | 直接切换全局 Provider/Model（跳过分配） |
| `t` | 分配到任务 | 快速分配到任务（ECC Wave、GSD Spec） |
| `g` | 分配到工具 | 快速分配到工具（OpenCode、Claude） |
| `a` | 应用到所有 | 全局替换所有工具和任务的模型 |
| `v` | 查看详情 | 右侧预览显示完整配置 |
| `r` | 刷新模型列表 | 从 API 动态拉取最新模型 |
| `q/Esc` | 退出/返回上一级 | 关闭或返回 Provider 选择 |

### 2.3 任务类型定义

```lua
-- lua/ai/switcher/task_registry.lua

local TASKS = {
  {
    name = "ecc_wave",
    display_name = "ECC Wave",
    description = "Everything Claude Code - Wave 执行（深度推理任务）",
    category = "framework",
    recommended_capability = "reasoning",  -- 推荐能力类型
    supported_tools = { "claude", "opencode" },
  },
  {
    name = "gsd_spec",
    display_name = "GSD Spec",
    description = "Get Shit Done - Spec 生成（结构化输出）",
    category = "framework",
    recommended_capability = "structured_output",
    supported_tools = { "claude", "opencode" },
  },
  {
    name = "quick_chat",
    display_name = "Quick Chat",
    description = "日常快速问答（速度优先）",
    category = "general",
    recommended_capability = "speed",
    supported_tools = { "claude", "opencode" },
  },
  {
    name = "deep_analysis",
    display_name = "Deep Analysis",
    description = "复杂代码分析、架构决策",
    category = "general",
    recommended_capability = "reasoning",
    supported_tools = { "claude", "opencode" },
  },
}
```

---

## 三、数据结构设计

### 3.1 状态文件结构

```lua
-- ~/.local/state/nvim/ai_assignment.lua

return {
  -- Profile 支持（类似 keys.lua）
  profile = "default",

  -- 工具级分配（每个 CLI 工具的默认模型）
  tools = {
    opencode = {
      provider = "bailian_coding",
      model = "qwen3.6-plus",
    },
    claude = {
      provider = "anthropic",
      model = "claude-sonnet-4-6",
    },
  },

  -- 任务级分配（特定任务使用的模型）
  tasks = {
    ecc_wave = {
      provider = "anthropic",
      model = "claude-opus-4-6",
      reason = "deep reasoning for wave execution",
    },
    gsd_spec = {
      provider = "anthropic",
      model = "claude-sonnet-4-6",
      reason = "structured output for spec generation",
    },
    quick_chat = {
      provider = "bailian_coding",
      model = "qwen3.6-turbo",
      reason = "fast response for daily queries",
    },
  },

  -- 最后更新时间
  last_updated = "2026-04-19T12:00:00",

  -- 版本（用于兼容性检查）
  version = "1.0",
}
```

### 3.2 API 接口设计

```lua
-- lua/ai/switcher/assignment_store.lua

local M = {}

-- 加载状态
function M.load()
  -- 从 ~/.local/state/nvim/ai_assignment.lua 加载
  -- 使用 vim.tbl_deep_extend("keep", ...) 保持向后兼容
end

-- 保存状态
function M.save(state)
  -- 写入状态文件
end

-- 获取工具的当前模型
function M.get_for_tool(tool_name)
  -- 返回 { provider, model }
end

-- 获取任务的当前模型
function M.get_for_task(task_name)
  -- 返回 { provider, model, reason }
end

-- 设置工具模型
function M.set_tool(tool_name, provider, model)
  -- 更新 tools[tool_name]
end

-- 设置任务模型
function M.set_task(task_name, provider, model, reason)
  -- 更新 tasks[task_name]
end

-- 获取所有分配（用于 Header 显示）
function M.get_all()
  -- 返回 { tools = {...}, tasks = {...} }
end

-- 重置所有分配
function M.reset()
  -- 清空状态文件
end

return M
```

---

## 四、实现步骤

### Phase 1: 基础数据层（2-3 小时）

**目标**：建立任务注册表和状态存储，不涉及 UI。

#### Step 1.1: 创建任务注册表

**文件**: `lua/ai/switcher/task_registry.lua`

```lua
local M = {}

-- 预定义任务
local BUILTIN_TASKS = {
  ecc_wave = {
    name = "ecc_wave",
    display_name = "ECC Wave",
    description = "Wave 执行 - 深度推理",
    recommended_capability = "reasoning",
    supported_tools = { "claude", "opencode" },
  },
  gsd_spec = {
    name = "gsd_spec",
    display_name = "GSD Spec",
    description = "Spec 生成 - 结构化输出",
    recommended_capability = "structured_output",
    supported_tools = { "claude", "opencode" },
  },
  quick_chat = {
    name = "quick_chat",
    display_name = "Quick Chat",
    description = "日常问答 - 速度优先",
    recommended_capability = "speed",
    supported_tools = { "claude", "opencode" },
  },
}

-- 用户自定义任务（从配置加载）
local CUSTOM_TASKS = {}

function M.register(task_def)
  -- 注册新任务
end

function M.get(task_name)
  -- 获取任务定义
end

function M.list()
  -- 返回所有任务
end

function M.get_recommended_model(task_name)
  -- 根据 recommended_capability 推荐模型
end

return M
```

#### Step 1.2: 创建状态存储模块

**文件**: `lua/ai/switcher/assignment_store.lua`

```lua
local M = {}

local STATE_PATH = vim.fn.expand("~/.local/state/nvim/ai_assignment.lua")

local DEFAULT_STATE = {
  profile = "default",
  tools = {
    opencode = { provider = "bailian_coding", model = "qwen3.6-plus" },
    claude = { provider = "anthropic", model = "claude-sonnet-4-6" },
  },
  tasks = {},
  version = "1.0",
}

function M.load()
  -- 实现...
end

function M.save(state)
  -- 实现...
end

function M.get_for_tool(tool_name)
  -- 实现...
end

function M.get_for_task(task_name)
  -- 实现...
end

function M.set_tool(tool_name, provider, model)
  -- 实现...
end

function M.set_task(task_name, provider, model, reason)
  -- 实现...
end

function M.get_all()
  -- 实现...
end

return M
```

#### Step 1.3: 扩展 state.lua

**文件**: `lua/ai/state.lua`（修改）

```lua
-- 新增方法
function M.get_for_task(task_name)
  local AssignmentStore = require("ai.switcher.assignment_store")
  return AssignmentStore.get_for_task(task_name)
end

function M.get_for_tool(tool_name)
  local AssignmentStore = require("ai.switcher.assignment_store")
  return AssignmentStore.get_for_tool(tool_name)
end
```

---

### Phase 2: UI 交互层（4-5 小时）

**目标**：实现 fzf-lua 多级选择器。

#### Step 2.1: 创建统一入口模块

**文件**: `lua/ai/switcher/init.lua`

```lua
local M = {}

-- 主入口函数
function M.open()
  -- 打开 Provider 选择器
  M.open_provider_selector()
end

-- 快速切换（跳过分配）
function M.quick_switch()
  -- 直接切换全局模型
end

-- 查看当前分配
function M.show_assignments()
  -- 显示完整分配状态
end

return M
```

#### Step 2.2: 创建 Provider 选择器

**文件**: `lua/ai/switcher/ui/provider_picker.lua`

```lua
local M = {}

local fzf = require("fzf-lua")
local Providers = require("ai.providers")
local AssignmentStore = require("ai.switcher.assignment_store")

function M.open()
  local entries = M.build_entries()
  local header = M.build_header()

  fzf.fzf(entries, {
    prompt = " Provider > ",
    winopts = {
      title = " AI Model Manager ",
      height = 0.6,
      width = 0.8,
    },
    fzf_opts = {
      ["--header"] = header,
    },
    previewer = M.create_previewer(),
    actions = {
      ["default"] = function(selected)
        -- 进入 Model 选择
        local provider_name = entries[selected[1]]
        require("ai.switcher.ui.model_picker").open(provider_name)
      end,
      ["ctrl-s"] = function(selected)
        -- 快速切换全局
        local provider_name = entries[selected[1]]
        M.quick_switch_provider(provider_name)
      end,
      ["ctrl-v"] = function(selected)
        -- 查看详情
        M.show_details(entries[selected[1]])
      end,
    },
  })
end

function M.build_header()
  local all = AssignmentStore.get_all()
  local lines = {
    "Current Assignments:",
    "  Tools:",
  }

  for tool, assignment in pairs(all.tools) do
    lines[#lines + 1] = string.format("    %s → %s/%s",
      tool, assignment.provider, assignment.model)
  end

  lines[#lines + 1] = "  Tasks:"
  for task, assignment in pairs(all.tasks) do
    lines[#lines + 1] = string.format("    %s → %s/%s",
      task, assignment.provider, assignment.model)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Keys: [Enter] Select │ [s] Quick Switch │ [v] View"

  return table.concat(lines, "\n")
end

return M
```

#### Step 2.3: 创建 Model 选择器

**文件**: `lua/ai/switcher/ui/model_picker.lua`

```lua
local M = {}

local fzf = require("fzf-lua")

function M.open(provider_name)
  -- 动态获取模型列表
  local models = M.fetch_models(provider_name)

  fzf.fzf(models, {
    prompt = string.format(" Model (%s) > ", provider_name),
    actions = {
      ["default"] = function(selected)
        -- 进入分配目标选择
        local model = models[selected[1]]
        require("ai.switcher.ui.target_picker").open(provider_name, model)
      end,
      ["ctrl-t"] = function(selected)
        -- 快速分配到任务
        local model = models[selected[1]]
        M.assign_to_task(provider_name, model)
      end,
      ["ctrl-g"] = function(selected)
        -- 快速分配到工具
        local model = models[selected[1]]
        M.assign_to_tool(provider_name, model)
      end,
      ["ctrl-a"] = function(selected)
        -- 应用到所有
        local model = models[selected[1]]
        M.assign_to_all(provider_name, model)
      end,
    },
  })
end

return M
```

#### Step 2.4: 创建分配目标选择器

**文件**: `lua/ai/switcher/ui/target_picker.lua`

```lua
local M = {}

function M.open(provider_name, model_name)
  local AssignmentStore = require("ai.switcher.assignment_store")
  local TaskRegistry = require("ai.switcher.task_registry")

  local entries = {}

  -- 工具列表
  entries[#entries + 1] = "── Tools ──"
  for tool, assignment in pairs(AssignmentStore.get_all().tools) do
    local current = string.format("%s/%s", assignment.provider, assignment.model)
    entries[#entries + 1] = string.format("  ○ %s (current: %s)", tool, current)
  end

  -- 任务列表
  entries[#entries + 1] = "── Tasks ──"
  for _, task in ipairs(TaskRegistry.list()) do
    local assignment = AssignmentStore.get_for_task(task.name)
    local current = assignment and string.format("%s/%s", assignment.provider, assignment.model) or "none"
    local recommended = M.is_recommended(task, model_name)
    local rec_icon = recommended and " ✓ RECOMMENDED" or ""
    entries[#entries + 1] = string.format("  ○ %s (current: %s)%s",
      task.display_name, current, rec_icon)
  end

  -- fzf 选择器...
end

return M
```

---

### Phase 3: 配置生成集成（2-3 小时）

**目标**：将任务级模型应用到配置生成。

#### Step 3.1: 扩展 opencode.lua

**文件**: `lua/ai/opencode.lua`（修改）

```lua
-- 在 generate_config() 中新增任务级模型应用

function M.generate_config()
  local AssignmentStore = require("ai.switcher.assignment_store")
  local all = AssignmentStore.get_all()

  -- 工具级模型应用到 opencode.json
  local opencode_assignment = all.tools.opencode

  -- 任务级模型应用到 agent 配置
  -- ecc_wave → sisyphus agent
  -- gsd_spec → prometheus agent
  local task_models = {}
  for task_name, assignment in pairs(all.tasks) do
    task_models[task_name] = {
      provider = assignment.provider,
      model = assignment.model,
    }
  end

  -- 合并到模板生成...
end
```

#### Step 3.2: 扩展 claude_code.lua

**文件**: `lua/ai/claude_code.lua`（修改）

```lua
-- 在 generate_settings() 中新增任务级模型应用

function M.generate_settings()
  local AssignmentStore = require("ai.switcher.assignment_store")
  local all = AssignmentStore.get_all()

  -- Claude Code 使用 env 配置
  -- 任务级模型通过环境变量传递
  -- ECC_WAVE_MODEL=claude-opus-4-6
  -- GSD_SPEC_MODEL=claude-sonnet-4-6

  -- 合并到 settings.json...
end
```

---

### Phase 4: 入口整合（1 小时）

**目标**：更新 `<leader>ks` 调用新模块。

#### Step 4.1: 更新 init.lua

**文件**: `lua/ai/init.lua`（修改）

```lua
-- 更新 keymap
vim.keymap.set("n", "<leader>ks", function()
  require("ai.switcher").open()
end, { desc = "AI Model & Provider Manager" })

-- 新增命令
vim.api.nvim_create_user_command("AIAssignShow", function()
  require("ai.switcher").show_assignments()
end, { desc = "Show current model assignments" })

vim.api.nvim_create_user_command("AIAssignReset", function()
  require("ai.switcher.assignment_store").reset()
end, { desc = "Reset all model assignments" })
```

---

## 五、验证方式

### 5.1 单元测试

```lua
-- tests/ai/switcher_spec.lua

describe("Switcher Module", function()

  describe("assignment_store", function()
    it("should load default state when file not exists", function()
      local Store = require("ai.switcher.assignment_store")
      local state = Store.load()
      assert.is_not_nil(state.tools)
      assert.is_not_nil(state.tools.opencode)
    end)

    it("should save and load state correctly", function()
      local Store = require("ai.switcher.assignment_store")
      Store.set_task("ecc_wave", "anthropic", "claude-opus-4-6", "test")
      local state = Store.load()
      assert.are.same("claude-opus-4-6", state.tasks.ecc_wave.model)
    end)

    it("should get model for specific task", function()
      local Store = require("ai.switcher.assignment_store")
      Store.set_task("gsd_spec", "anthropic", "claude-sonnet-4-6")
      local assignment = Store.get_for_task("gsd_spec")
      assert.are.same("claude-sonnet-4-6", assignment.model)
    end)
  end)

  describe("task_registry", function()
    it("should list builtin tasks", function()
      local Registry = require("ai.switcher.task_registry")
      local tasks = Registry.list()
      assert.is_true(#tasks >= 3)  -- ecc_wave, gsd_spec, quick_chat
    end)

    it("should register custom task", function()
      local Registry = require("ai.switcher.task_registry")
      Registry.register({
        name = "custom_analysis",
        display_name = "Custom Analysis",
        description = "自定义分析任务",
      })
      local task = Registry.get("custom_analysis")
      assert.is_not_nil(task)
    end)
  end)
end)
```

### 5.2 手动验证清单

```
验证步骤:

[ ] 基础功能
    [ ] <leader>ks 打开 Provider 选择器
    [ ] Header 显示当前工具/任务分配
    [ ] 右侧预览显示 Provider 详情
    [ ] Provider → Model → 目标 三级联动

[ ] 快捷键操作
    [ ] Enter 进入下一级
    [ ] s 快速切换全局 Provider
    [ ] t 分配到任务
    [ ] g 分配到工具
    [ ] a 应用到所有
    [ ] v 查看详情

[ ] 任务级分配
    [ ] 为 ECC Wave 分配 claude-opus-4-6
    [ ] 为 GSD Spec 分配 claude-sonnet-4-6
    [ ] 为 Quick Chat 分配 qwen3.6-turbo
    [ ] Header 正确显示所有分配

[ ] 状态持久化
    [ ] 分配后状态保存到 ai_assignment.lua
    [ ] 重启 Neovim 后状态保留
    [ ] :AIAssignShow 显示完整状态
    [ ] :AIAssignReset 清空状态

[ ] 配置生成
    [ ] :OpenCodeGenerateConfig 应用任务级模型
    [ ] opencode.json 包含正确的 agent 模型
    [ ] :ClaudeCodeGenerateConfig 应用任务级模型
    [ ] settings.json 包含任务环境变量

[ ] 推荐系统
    [ ] 选择 Model 时显示任务推荐标签
    [ ] claude-opus-4-6 推荐 ECC Wave
    [ ] claude-sonnet-4-6 推荐 GSD Spec
    [ ] qwen3.6-turbo 推荐 Quick Chat
```

---

## 六、文件清单

| 文件路径 | 类型 | 内容 |
|----------|------|------|
| `lua/ai/switcher/init.lua` | 新建 | 统一入口模块 |
| `lua/ai/switcher/task_registry.lua` | 新建 | 任务注册表 |
| `lua/ai/switcher/assignment_store.lua` | 新建 | 状态存储 |
| `lua/ai/switcher/ui/provider_picker.lua` | 新建 | Provider 选择器 |
| `lua/ai/switcher/ui/model_picker.lua` | 新建 | Model 选择器 |
| `lua/ai/switcher/ui/target_picker.lua` | 新建 | 分配目标选择器 |
| `lua/ai/state.lua` | 修改 | 扩展任务级查询 |
| `lua/ai/opencode.lua` | 修改 | 集成任务级模型 |
| `lua/ai/claude_code.lua` | 修改 | 集成任务级模型 |
| `lua/ai/init.lua` | 修改 | 更新入口和命令 |
| `tests/ai/switcher_spec.lua` | 新建 | 单元测试 |

---

## 七、复杂度评估

| 维度 | 评估 |
|------|------|
| **文件数量** | 新建 6 文件 + 修改 4 文件 |
| **代码量** | ~800 行 |
| **预计时间** | 8-10 小时 |
| **复杂度** | Medium |
| **风险** | Low-Medium（复用现有 pattern） |

---

## 八、参考文档

- CC Switch 对比分析：`docs/CC_SWITCH_COMPARISON.md`
- 组件管理器设计：`docs/COMPONENT_MANAGER_PLAN.md`
- 组件管理器指南：`docs/COMPONENT_MANAGER_GUIDE.md`
- ECC 使用指南：`ECC_GUIDE.md`
- GSD 使用指南：`GSD_GUIDE.md`

---

**文档版本**: 1.0
**创建日期**: 2026-04-19
**作者**: Claude Code 规划生成