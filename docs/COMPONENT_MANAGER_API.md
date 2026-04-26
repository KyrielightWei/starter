# AI Component Manager - API Reference

> 内部模块 API 文档（开发者参考）

---

## Manager Module

> 缓存 + 部署生命周期管理器
> 
> 提供 `install_to_cache`、`update_cache` 和 `deploy_to`、`deploy_all`、`undeploy_from`、`rollback_partial` 等统一接口。

### M.get_cache_path(component_name)

获取组件缓存目录路径。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `string` — 缓存目录完整路径（`~/.local/share/nvim/ai_components/cache/{component_name}`）

**示例:**

```lua
local Manager = require("ai.components.manager")
local path = Manager.get_cache_path("ecc")
-- ~/.local/share/nvim/ai_components/cache/ecc
```

---

### M.ensure_cache_dir()

确保缓存基础目录存在，不存在则创建。

**参数:**

无

**返回:**

- `string` — 缓存基础目录路径

**示例:**

```lua
local Manager = require("ai.components.manager")
local cache_base = Manager.ensure_cache_dir()
-- ~/.local/share/nvim/ai_components/cache
```

---

### M.is_cached(component_name)

检查组件是否已缓存。

检查顺序：
1. Registry 注册状态
2. 组件实现的 `is_cached()` 方法
3. 缓存目录是否存在
4. Deployments 状态记录

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `boolean` — 是否已缓存

**示例:**

```lua
local Manager = require("ai.components.manager")
if Manager.is_cached("ecc") then
  print("ECC 已缓存")
end
```

---

### M.get_cache_version(component_name)

获取已缓存组件的版本号。

优先级：
1. 组件实现的 `get_cache_version()` 方法
2. Deployments 状态中的 `cache_version`
3. Git 仓库的 `rev-parse HEAD`

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `string|nil` — 版本字符串，未缓存则返回 `nil`

**示例:**

```lua
local Manager = require("ai.components.manager")
local version = Manager.get_cache_version("ecc")
if version then
  print("ECC 版本: " .. version)
end
```

---

### M.install_to_cache(component_name, opts)

将组件安装到缓存目录。

调用组件的 `install()` 方法，并在 Deployments 状态中记录版本信息。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `opts` | table|nil | 可选参数 |
| `opts.force` | boolean | 强制重新安装（覆盖已有缓存） |

**返回:**

- `boolean` — 是否成功
- `string` — 成功/失败消息

**示例:**

```lua
local Manager = require("ai.components.manager")
local ok, msg = Manager.install_to_cache("ecc", { force = true })
if ok then
  print("安装成功: " .. msg)
else
  print("安装失败: " .. msg)
end
```

---

### M.deploy_to(component_name, target)

将已缓存的组件部署到指定目标工具。

使用 Syncer 模块执行 symlink/copy，并在 Deployments 状态中记录部署信息。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `target` | string | 目标工具名称（如 `"claude"`、`"opencode"`） |

**返回:**

- `boolean` — 是否成功
- `string` — 成功消息或错误信息

**示例:**

```lua
local Manager = require("ai.components.manager")
-- 先确保组件已缓存
if Manager.is_cached("ecc") then
  local ok, msg = Manager.deploy_to("ecc", "claude")
  if ok then
    print("部署成功: " .. msg)
  end
end
```

---

### M.deploy_all(component_name)

将组件部署到所有支持的 target 工具。

按照 D-16 规范，返回结构化结果 `{ success[], failed[] }`。部分失败时提示用户是否回滚。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `table` — 结构化结果：
  - `success` — `{ { target, method }[] }` 成功部署列表
  - `failed` — `{ { target, error }[] }` 失败列表

**示例:**

```lua
local Manager = require("ai.components.manager")
local result = Manager.deploy_all("ecc")
print("成功: " .. #result.success)
print("失败: " .. #result.failed)

-- 处理部分失败
if #result.failed > 0 and #result.success > 0 then
  Manager.rollback_partial("ecc", result.success)
end
```

---

### M.rollback_partial(component_name, deployed_targets)

回滚部分部署成功的目标。

用于 `deploy_all` 部分失败时，撤销已成功部署的目标。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `deployed_targets` | table[] | 成功部署列表（来自 `deploy_all` 返回的 `result.success`） |

**返回:**

- `boolean` — 是否成功
- `string` — 成功/失败消息

**示例:**

```lua
local Manager = require("ai.components.manager")
local result = Manager.deploy_all("ecc")

if #result.failed > 0 then
  -- 回滚已成功部署的部分
  local ok, msg = Manager.rollback_partial("ecc", result.success)
  print("回滚结果: " .. msg)
end
```

---

### M.undeploy_from(component_name, target)

从指定目标工具卸载组件。

使用 Syncer 模块移除 symlink/copy，并清除 Deployments 状态记录。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `target` | string | 目标工具名称 |

**返回:**

- `boolean` — 是否成功
- `string` — 成功/失败消息

**示例:**

```lua
local Manager = require("ai.components.manager")
local ok, msg = Manager.undeploy_from("ecc", "opencode")
if ok then
  print("卸载成功: " .. msg)
end
```

---

### M.update_cache(component_name, opts)

更新组件缓存（不影响已部署的目标）。

按照 D-07 规范，只更新缓存，不自动重新部署。更新完成后提示用户是否需要重新部署。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `opts` | table|nil | 可选参数 |

**返回:**

- `boolean` — 是否成功
- `string` — 成功消息（包含新版本号）

**示例:**

```lua
local Manager = require("ai.components.manager")
local ok, msg = Manager.update_cache("ecc")
if ok then
  print("缓存已更新: " .. msg)
  -- 用户可选择重新部署
end
```

---

## Deployments Module

> 部署状态文件管理
> 
> 状态文件路径：`~/.local/share/nvim/ai_components/deployments.json`

### M.state_path()

获取部署状态文件路径。

**参数:**

无

**返回:**

- `string` — 状态文件完整路径

**示例:**

```lua
local Deployments = require("ai.components.deployments")
local path = Deployments.state_path()
-- ~/.local/share/nvim/ai_components/deployments.json
```

---

### M.load_state()

加载部署状态。

使用内存缓存加速重复读取，处理损坏文件备份和恢复。

**参数:**

无

**返回:**

- `table` — 状态对象：
  - `version` — 状态文件版本号
  - `deployments` — `{ component_name -> deployment_info }` 部署记录表

**示例:**

```lua
local Deployments = require("ai.components.deployments")
local state = Deployments.load_state()
print("状态版本: " .. state.version)
-- 查看所有部署记录
for name, info in pairs(state.deployments) do
  print(name .. ": " .. vim.inspect(info))
end
```

---

### M.save_state(state)

保存部署状态到文件。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `state` | table|nil | 状态对象（nil 时保存内存缓存） |

**返回:**

无（直接写入文件）

**示例:**

```lua
local Deployments = require("ai.components.deployments")
local state = Deployments.load_state()
-- 修改状态
state.deployments["custom"] = { cached_at = os.date("%Y-%m-%dT%H:%M:%SZ") }
Deployments.save_state(state)
```

---

### M.record_deployment(component_name, target, method)

记录组件部署到指定目标。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `target` | string | 目标工具名称 |
| `method` | string | 部署方式（`"symlink"` 或 `"copy"`） |

**返回:**

- `boolean` — 是否成功记录

**示例:**

```lua
local Deployments = require("ai.components.deployments")
Deployments.record_deployment("ecc", "claude", "symlink")
```

---

### M.record_cache(component_name, cache_version)

记录组件缓存状态和版本。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `cache_version` | string | 缓存版本号（如 git commit hash） |

**返回:**

- `boolean` — 是否成功记录

**示例:**

```lua
local Deployments = require("ai.components.deployments")
Deployments.record_cache("ecc", "abc123def456")
```

---

### M.clear_deployment(component_name, target)

清除指定目标的部署记录。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `target` | string | 目标工具名称 |

**返回:**

- `boolean` — 是否成功清除

**示例:**

```lua
local Deployments = require("ai.components.deployments")
Deployments.clear_deployment("ecc", "opencode")
```

---

### M.get_deployment_status(component_name)

获取组件的完整部署状态信息。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `table|nil` — 部署信息对象，不存在则返回 `nil`：
  - `cached_at` — 缓存时间
  - `cache_version` — 缓存版本
  - `last_cache_update` — 最后缓存更新时间
  - `deployed_to` — `{ target -> { deployed_at, method } }` 部署目标表

**示例:**

```lua
local Deployments = require("ai.components.deployments")
local status = Deployments.get_deployment_status("ecc")
if status then
  print("缓存版本: " .. (status.cache_version or "unknown"))
  for target, info in pairs(status.deployed_to or {}) do
    print("部署到 " .. target .. " 于 " .. info.deployed_at)
  end
end
```

---

### M.is_deployed_to(component_name, target)

检查组件是否已部署到指定目标。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `target` | string | 目标工具名称 |

**返回:**

- `boolean` — 是否已部署

**示例:**

```lua
local Deployments = require("ai.components.deployments")
if Deployments.is_deployed_to("ecc", "claude") then
  print("ECC 已部署到 Claude")
end
```

---

### M.is_cache_stale(component_name)

检查缓存是否过期。

比较 `last_cache_update` 与各目标的 `deployed_at`，判断缓存是否在部署后更新过。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `boolean` — 缓存是否过期（需要重新部署）

**示例:**

```lua
local Deployments = require("ai.components.deployments")
if Deployments.is_cache_stale("ecc") then
  print("缓存已过期，需要重新部署")
end
```

---

### M.clear_cache()

清除内存缓存，强制下次读取时重新加载状态文件。

**参数:**

无

**返回:**

无

**示例:**

```lua
local Deployments = require("ai.components.deployments")
Deployments.clear_cache()
local fresh_state = Deployments.load_state() -- 从文件重新读取
```

---

## Switcher Module

> 工具-组件切换状态管理
> 
> 状态文件路径：`~/.local/state/nvim/ai_component_state.lua`

### M.state_path()

获取 Switcher 状态文件路径。

**参数:**

无

**返回:**

- `string` — 状态文件完整路径

**示例:**

```lua
local Switcher = require("ai.components.switcher")
print(Switcher.state_path())
-- ~/.local/state/nvim/ai_component_state.lua
```

---

### M.load_state()

加载切换状态。

使用内存缓存加速重复读取。

**参数:**

无

**返回:**

- `table` — 状态对象：
  - `active` — `{ tool -> component_name }` 当前工具-组件分配表
  - `last_check` — 最后检查时间
  - `versions` — `{ component_name -> version_info }` 版本缓存表

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local state = Switcher.load_state()
print("OpenCode 使用: " .. (state.active.opencode or "未设置"))
```

---

### M.save_state(state)

保存切换状态到文件。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `state` | table|nil | 状态对象（nil 时保存内存缓存） |

**返回:**

无

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local state = Switcher.load_state()
state.active.opencode = "gsd"
Switcher.save_state(state)
```

---

### M.switch(tool, component_name)

切换工具使用的组件。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `tool` | string | 工具名称（如 `"opencode"`、`"claude"`） |
| `component_name` | string | 组件名称（如 `"ecc"`、`"gsd"`） |

**返回:**

- `boolean` — 是否成功切换

**示例:**

```lua
local Switcher = require("ai.components.switcher")
Switcher.switch("opencode", "gsd")
-- OpenCode 现在使用 GSD
```

---

### M.get_active(tool)

获取工具当前使用的组件。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `tool` | string | 工具名称 |

**返回:**

- `string|nil` — 组件名称，未设置则返回 `nil`

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local comp = Switcher.get_active("opencode")
print("OpenCode 当前使用: " .. (comp or "默认"))
```

---

### M.get_all()

获取所有工具的当前组件分配。

**参数:**

无

**返回:**

- `table<string, string>` — `{ tool = component_name }` 分配表

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local assignments = Switcher.get_all()
for tool, comp in pairs(assignments) do
  print(tool .. " → " .. comp)
end
```

---

### M.get_tools_using(component_name)

获取所有使用指定组件的工具。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `string[]` — 使用该组件的工具列表

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local tools = Switcher.get_tools_using("ecc")
print("使用 ECC 的工具: " .. table.concat(tools, ", "))
```

---

### M.update_version_cache(component_name, version_info)

更新组件版本缓存。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |
| `version_info` | table | 版本信息对象 |
| `version_info.current` | string | 当前版本 |
| `version_info.latest` | string | 最新版本 |
| `version_info.status` | string | 状态（`"current"`、`"outdated"` 等） |

**返回:**

无

**示例:**

```lua
local Switcher = require("ai.components.switcher")
Switcher.update_version_cache("ecc", {
  current = "abc123",
  latest = "def456",
  status = "outdated"
})
```

---

### M.get_version_cache(component_name)

获取缓存的组件版本信息。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `component_name` | string | 组件名称 |

**返回:**

- `table|nil` — 版本信息对象，不存在则返回 `nil`

**示例:**

```lua
local Switcher = require("ai.components.switcher")
local info = Switcher.get_version_cache("ecc")
if info then
  print("状态: " .. info.status)
end
```

---

### M.clear_cache()

清除内存缓存，强制下次重新读取状态文件。

**参数:**

无

**返回:**

无

**示例:**

```lua
local Switcher = require("ai.components.switcher")
Switcher.clear_cache()
```

---

### M.reset()

重置状态到默认值，删除状态文件后重建。

**参数:**

无

**返回:**

无

**示例:**

```lua
local Switcher = require("ai.components.switcher")
Switcher.reset() -- 清除所有工具-组件分配
```

---

### M.refresh_versions_async()

异步刷新所有已注册组件的远程版本信息。

在后台查询 npm 或 git 远程版本，完成后更新 Switcher 版本缓存。

**参数:**

无

**返回:**

无（异步执行，完成后触发 `User RemoteVersionRefreshed` 自动命令）

**示例:**

```lua
local Switcher = require("ai.components.switcher")
Switcher.refresh_versions_async()
-- 后台执行，完成后触发:
vim.api.nvim_create_autocmd("User", {
  pattern = "RemoteVersionRefreshed",
  callback = function()
    print("版本信息已刷新")
  end
})
```

---

## Registry Module

> 组件注册表
> 
> 类似 `providers.lua` 的注册模式，管理已注册组件的发现和查询。

### M.register(name, component)

注册组件到注册表。

验证组件名称和接口规范，检查是否已注册。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称（仅允许字母、数字、下划线、连字符） |
| `component` | AIComponent | 组件实例（需满足 Interface 规范） |

**返回:**

- `boolean` — 是否成功注册
- `string|nil` — 失败时的错误消息

**示例:**

```lua
local Registry = require("ai.components.registry")
local MyComponent = require("ai.components.my_component")
local ok, err = Registry.register("my_component", MyComponent)
if not ok then
  print("注册失败: " .. err)
end
```

---

### M.register_batch(components)

批量注册多个组件。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `components` | table | `{ name -> AIComponent }` 组件列表 |

**返回:**

- `number` — 成功注册数量
- `string[]` — 失败错误消息列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local count, errors = Registry.register_batch({
  ecc = require("ai.components.ecc"),
  gsd = require("ai.components.gsd"),
})
print("注册成功: " .. count .. " 个")
if #errors > 0 then
  print("错误: " .. table.concat(errors, "\n"))
end
```

---

### M.get(name)

获取已注册的组件实例。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |

**返回:**

- `AIComponent|nil` — 组件实例，未注册则返回 `nil`

**示例:**

```lua
local Registry = require("ai.components.registry")
local ecc = Registry.get("ecc")
if ecc then
  print("ECC 显示名: " .. ecc.display_name)
end
```

---

### M.is_registered(name)

检查组件是否已注册。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |

**返回:**

- `boolean` — 是否已注册

**示例:**

```lua
local Registry = require("ai.components.registry")
if Registry.is_registered("ecc") then
  print("ECC 已注册")
end
```

---

### M.list()

获取所有已注册组件的列表（快速查询，无网络请求）。

**参数:**

无

**返回:**

- `table[]` — 组件列表，每项包含：
  - `name` — 组件名称
  - `display_name` — 显示名称
  - `category` — 分类（`framework`、`tool`、`integration`）
  - `description` — 描述
  - `installed` — 是否已安装
  - `icon` — 图标

**示例:**

```lua
local Registry = require("ai.components.registry")
local components = Registry.list()
for _, comp in ipairs(components) do
  print(comp.icon .. " " .. comp.display_name .. " (" .. comp.category .. ")")
end
```

---

### M.list_installed()

获取已安装的组件列表。

**参数:**

无

**返回:**

- `table[]` — 已安装组件列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local installed = Registry.list_installed()
print("已安装: " .. #installed .. " 个")
```

---

### M.list_uninstalled()

获取未安装的组件列表。

**参数:**

无

**返回:**

- `table[]` — 未安装组件列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local uninstalled = Registry.list_uninstalled()
for _, comp in ipairs(uninstalled) do
  print("可安装: " .. comp.name)
end
```

---

### M.list_outdated()

获取需要更新的组件列表。

检查版本缓存中状态为 `"outdated"` 的已安装组件。

**参数:**

无

**返回:**

- `table[]` — 需要更新的组件列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local outdated = Registry.list_outdated()
if #outdated > 0 then
  print("需要更新: " .. table.concat(
    vim.tbl_map(function(c) return c.name end, outdated), ", "
  ))
end
```

---

### M.list_cached()

获取已缓存的组件列表。

**参数:**

无

**返回:**

- `table[]` — 已缓存组件列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local cached = Registry.list_cached()
print("已缓存: " .. #cached .. " 个")
```

---

### M.count()

获取已注册组件总数。

**参数:**

无

**返回:**

- `number` — 组件数量

**示例:**

```lua
local Registry = require("ai.components.registry")
print("已注册: " .. Registry.count() .. " 个组件")
```

---

### M.clear()

清空注册表（主要用于测试）。

**参数:**

无

**返回:**

无

**示例:**

```lua
local Registry = require("ai.components.registry")
Registry.clear() -- 清空所有注册
```

---

### M.is_cached(name)

检查组件是否已缓存。

检查顺序：
1. 组件实现的 `is_cached()` 方法
2. Deployments 状态记录
3. 缓存目录是否存在

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |

**返回:**

- `boolean` — 是否已缓存

**示例:**

```lua
local Registry = require("ai.components.registry")
if Registry.is_cached("ecc") then
  print("ECC 已缓存")
end
```

---

### M.get_cache_version(name)

获取已缓存组件的版本号。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |

**返回:**

- `string|nil` — 版本字符串，未缓存则返回 `nil`

**示例:**

```lua
local Registry = require("ai.components.registry")
local version = Registry.get_cache_version("ecc")
```

---

### M.is_deployed_to(name, target)

检查组件是否已部署到指定目标工具。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |
| `target` | string | 目标工具名称 |

**返回:**

- `boolean` — 是否已部署

**示例:**

```lua
local Registry = require("ai.components.registry")
if Registry.is_deployed_to("ecc", "claude") then
  print("ECC 已部署到 Claude")
end
```

---

### M.get_registered_at(name)

获取组件注册时间戳。

**参数:**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `name` | string | 组件名称 |

**返回:**

- `number|nil` — 注册时间戳（Unix 时间），未注册则返回 `nil`

**示例:**

```lua
local Registry = require("ai.components.registry")
local ts = Registry.get_registered_at("ecc")
if ts then
  print("ECC 注册于: " .. os.date("%Y-%m-%d", ts))
end
```

---

### M.validate_state_consistency()

验证 Switcher 和 Deployments 状态的一致性。

交叉检查：
- 如果 Switcher 说某工具使用某组件，该组件必须已部署到该工具
- 如果某组件已部署到某工具，Switcher 应分配该组件到该工具

**参数:**

无

**返回:**

- `table` — 验证结果：
  - `consistent` — `boolean` 是否一致
  - `issues` — `string[]` 发现的问题列表

**示例:**

```lua
local Registry = require("ai.components.registry")
local result = Registry.validate_state_consistency()
if not result.consistent then
  print("发现不一致:")
  for _, issue in ipairs(result.issues) do
    print("  - " .. issue)
  end
end
```

---

## Integration Examples

### 完整安装和部署流程

```lua
local Manager = require("ai.components.manager")

-- 1. 安装组件到缓存
local ok, msg = Manager.install_to_cache("ecc", { force = true })
if not ok then
  print("安装失败: " .. msg)
  return
end

-- 2. 部署到所有支持的 target
local result = Manager.deploy_all("ecc")
print("成功: " .. #result.success .. " 个")
print("失败: " .. #result.failed .. " 个")

-- 3. 处理部分失败
if #result.failed > 0 and #result.success > 0 then
  -- 可选：回滚成功部分
  Manager.rollback_partial("ecc", result.success)
end
```

### 检查并更新组件

```lua
local Manager = require("ai.components.manager")
local Deployments = require("ai.components.deployments")

-- 检查缓存是否过期
if Manager.is_cached("ecc") and Deployments.is_cache_stale("ecc") then
  -- 更新缓存
  local ok, msg = Manager.update_cache("ecc")
  if ok then
    print("缓存已更新: " .. msg)
    
    -- 查看之前部署的目标
    local status = Deployments.get_deployment_status("ecc")
    if status and status.deployed_to then
      local targets = vim.tbl_keys(status.deployed_to)
      print("之前部署到: " .. table.concat(targets, ", "))
      -- 用户可选择重新部署
    end
  end
end
```

### 验证状态一致性

```lua
local Registry = require("ai.components.registry")

-- 检查状态一致性
local result = Registry.validate_state_consistency()
if not result.consistent then
  print("状态不一致:")
  for _, issue in ipairs(result.issues) do
    print("  - " .. issue)
  end
  
  -- 建议修复方案
  print("建议: 重新部署或切换工具-组件分配")
end
```

### 切换工具组件分配

```lua
local Switcher = require("ai.components.switcher")
local Manager = require("ai.components.manager")

-- 切换 OpenCode 使用 GSD
Switcher.switch("opencode", "gsd")

-- 确保 GSD 已部署到 OpenCode
if not Manager.is_cached("gsd") then
  Manager.install_to_cache("gsd")
end

Manager.deploy_to("gsd", "opencode")

-- 验证
local comp = Switcher.get_active("opencode")
print("OpenCode 现在使用: " .. comp)
```

### 查询组件状态

```lua
local Registry = require("ai.components.registry")
local Switcher = require("ai.components.switcher")
local Deployments = require("ai.components.deployments")

-- 获取组件详情
local comp = Registry.get("ecc")
if comp then
  print("组件: " .. comp.display_name)
  print("分类: " .. comp.category)
  print("支持工具: " .. table.concat(comp.supported_targets or {}, ", "))
end

-- 获取版本信息
local version_info = Switcher.get_version_cache("ecc")
if version_info then
  print("当前版本: " .. (version_info.current or "unknown"))
  print("最新版本: " .. (version_info.latest or "unknown"))
  print("状态: " .. version_info.status)
end

-- 获取部署状态
local status = Deployments.get_deployment_status("ecc")
if status then
  for target, info in pairs(status.deployed_to or {}) do
    print("部署到 " .. target .. " 于 " .. info.deployed_at .. " (方法: " .. info.method .. ")")
  end
end
```

---

**文档版本**: 1.0  
**最后更新**: 2026-04-25