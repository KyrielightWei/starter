---
status: complete
phase: 03-provider-manager-auto-detection-status
source:
  - 03-01-SUMMARY.md
  - 03-02-SUMMARY.md
started: 2026-04-25T09:00:00Z
updated: 2026-04-25T09:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Auto-Detect on Model Switch
expected: 当用户选择新的 provider/model 时，异步检测在后台运行。如果状态不是 available，会显示 vim.notify 警告包含 provider + model + status 信息。切换操作本身不会因检测结果而被阻塞。快速切换到其他 model 时，过时的回调警告会被丢弃。
result: pass
verification: |
  代码验证：
  - status.lua:vim.schedule_wrap() 包裹所有回调 → 无 E5560 错误
  - status.lua: stale guard 通过 State.get() 检查 provider+model → 过时回调被丢弃
  - model_switch.lua: Status.trigger_async_check 在 callback 之前调用，不阻塞选择

### 2. Status Icons in Provider Manager Picker
expected: 打开 Provider Manager picker 时，每个 provider 显示缓存的状态图标前缀：✓(available)、✗(unavailable)、⏱(timeout)、⚠(error)。未检测过的 provider 不显示图标，显示与 phase 前相同。
result: pass
verification: |
  代码验证：
  - picker.lua 第40行: Status.get_cached_status(p.name, default_model)
  - picker.lua 第43行: UIUtil.format_provider_display(p.name, def_info, status)
  - ui_util.lua: ICONS 表包含所有5种状态图标

### 3. Status Icons in Model Picker
expected: 选择 provider 后，model picker 显示每个 model 的缓存状态图标。未检测的 model 不显示图标。默认 model 标记为 ★。
result: pass
verification: |
  代码验证：
  - picker.lua: _select_model 中 Status.get_cached_status(provider_name, model_id)
  - picker.lua: UIUtil.format_model_display(model_id, is_default, nil, status)
  - ui_util.lua: format_model_display 正确处理 status 参数

### 4. Backward Compatibility — No Status, No Icon
expected: 从未检测过的 provider/model，picker 输出与 phase 前完全相同。format_provider_display(name, def) 无 status 参数时行为不变。
result: pass
verification: |
  代码验证：
  - ui_util.lua: format_provider_display 中 status 为 nil 或 "unchecked" 时返回 base（无图标）
  - ui_util.lua: format_model_display 同理
  - picker.lua: Status.get_cached_status 返回 "unchecked" 时不添加图标

### 5. Status Module Exports via provider_manager Subsystem
expected: require("ai.provider_manager").get_cached_status、.trigger_async_check、.check_all_batch 均可访问
result: pass
verification: |
  代码验证：
  - init.lua 第13行: local Status = require("ai.provider_manager.status")
  - init.lua 第178-180行: M.get_cached_status = ... M.trigger_async_check = ... M.check_all_batch = ...

### 6. Vim.schedule Thread Safety in Callbacks
expected: 所有与 UI 交互的异步回调都使用 vim.schedule_wrap 包裹，不会出现 E5560 错误
result: pass
verification: |
  代码验证：
  - status.lua 第50行: vim.schedule_wrap 包裹 detector callback
  - status.lua 第67行: vim.schedule_wrap 包裹 check_all_providers callback
  - model_switch.lua: vim.schedule 包裹 vim.notify 调用

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none]
