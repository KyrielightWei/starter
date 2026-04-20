# AI 组件管理系统 - 工作日志

> 用于记录每次变更，便于中断后快速恢复上下文。
> 格式: 时间 | 类型 | 问题 | 操作 | 状态

---

## 2026-04-19

### 10:30 | BUG修复 | fzf-lua previewer 崩溃

- **报错**: `previewer.lua:133: attempt to index field 'previewer' (a nil value)`
- **原因**: `fzf.previewer.builtin` 在新版 fzf-lua 中不存在
- **操作**:
  - `previewer.lua`: `create_fzf_previewer()` 改为返回 `{ title, fn }` 配置
  - `picker.lua`: 移除无效顶层 `previewer` 字段，预览函数写入 `winopts.preview.fn`
- **结果**: ✅ 语法通过，修复生效
- **注意**: 修复后被 Claude+GLM-5 agent 覆盖，第二次修复时直接将 `fn` 内联到 `winopts.preview` 中

---

### 11:00 | 性能优化 | 选择器打开慢

- **问题**: 打开 AI 组件选择器时卡顿数秒
- **根因**: `Registry.list()` 遍历组件时对每个调用 `get_version_info()`，该方法执行 `vim.fn.system("npm view ...")` 同步网络请求
- **调用链**: `Picker.open() → build_entries() → Registry.list() → comp.get_version_info() → vim.fn.system("npm view ...")` (阻塞 2-5 秒/组件)
- **修复**:
  - `registry.lua:74`: `list()` 移除 `version_info` 字段填充
  - `picker.lua:14`: `build_entries()` 简化显示，不触发网络
  - `picker.lua:89`: 添加 `vim.defer_fn(500ms)` 延迟触发异步刷新
- **结果**: ✅ 秒开

---

### 11:15 | 架构调整 | 异步远程版本查询

- **设计变更**: 打开 UI 时使用缓存数据（无网络），后台异步查远程版本后更新缓存
- **新增文件/方法**:
  - `version.lua:138-175`: `get_latest_npm_version_async(package, callback)` — jobstart 异步
  - `version.lua:177-214`: `get_latest_git_version_async(repo, callback)` — jobstart 异步
  - `switcher.lua:211+`: `refresh_versions_async()` — 遍历所有组件触发异步查询
- **保留同步方法**: `get_latest_npm_version()`, `get_latest_git_version()` — installer/updater 仍需同步调用

---

### 11:20 | BUG | 同步方法被误删

- **报错**: `gsd/updater.lua:61: attempt to call field 'get_latest_npm_version' (a nil value)`
- **原因**: 加异步方法时把同步方法也删了
- **修复**: `version.lua` 恢复 `get_latest_npm_version()`, `get_latest_git_version()`, `get_local_git_version()`
- **结果**: ✅

---

### 11:30 | BUG | GSD 重启后不可用

- **现象**: GSD 已安装，OpenCode 分配为 GSD，但重启后 GSD 命令不可用
- **排查结果**:
  - `npx -y get-shit-done-cc --help` ✅ 可用 (npm 包 v1.37.1)
  - `npm list -g get-shit-done-cc` ❌ 未全局安装
  - `~/.claude/gsd/` ❌ 目录不存在
  - `~/.claude/commands/gsd/` ❌ 不存在
  - `~/.config/opencode/commands/gsd/` ❌ 不存在
  - 状态文件: `opencode = "gsd"`, `claude = "ecc"` ✅ 正确
- **根因 1**: `gsd/status.lua:is_installed()` 检测逻辑错误 — GSD 用 npx 按需运行，但检测只查 npm 全局安装和 `~/.claude/gsd/`
  - **修复**: `is_installed()` 优先检查 `vim.fn.executable("npx") == 1`
- **根本根因**: `opencode.lua:write_config()` 第 520 行硬编码调用 `Ecc.ensure_installed(...)`，完全忽略组件切换状态
  - 无论选择器切换到什么，配置生成永远只安装 ECC
  - **状态**: ⚠️ 待修复

---

### 11:45 | BUG | GSD installer 未显式指定 opencode 目标

- **问题**: GSD 安装器只运行 `npx -y get-shit-done-cc@latest`，可能默认为 Claude Code 写入，忽略 OpenCode
- **修复**: `gsd/installer.lua:60` 改为 `npx -y get-shit-done-cc@latest --opencode --claude`
- **结果**: ✅

---

### 12:00 | 全面审计

对全部 19 个组件文件 + 设计文档进行完整审计，结论:

#### 已存在 (19 文件)
- `components/init.lua` (268 行) — 入口，命令注册
- `components/registry.lua` (148 行) — 注册表
- `components/discovery.lua` (154 行) — 自动发现
- `components/interface.lua` (153 行) — 接口验证
- `components/version.lua` (361 行) — 版本检测 (同步+异步)
- `components/switcher.lua` (259 行) — 切换状态管理
- `components/picker.lua` (334 行) — fzf-lua 选择器
- `components/previewer.lua` (143 行) — 预览器
- `components/actions.lua` (290 行) — 安装/卸载/更新操作
- `ecc/init.lua` (235 行) / `gsd/init.lua` (243 行) — 组件入口
- `ecc/installer.lua` (198 行) / `gsd/installer.lua` (107 行) — 安装
- `ecc/status.lua` (128 行) / `gsd/status.lua` (134 行) — 状态
- `ecc/updater.lua` (113 行) / `gsd/updater.lua` (112 行) — 更新
- `ecc/uninstaller.lua` (119 行) / `gsd/uninstaller.lua` (103 行) — 卸载

#### 缺失 (9 文件)
- `components/types.lua` — 类型定义
- `components/ecc/commands.lua` — 命令注册
- `components/gsd/commands.lua` — 命令注册
- `components/status_panel.lua` — 状态面板 UI
- `components/manager.lua` — 缓存+分发管理器 (新架构)
- `components/syncer.lua` — 文件系统同步器 (新架构)
- `components/fetchers/` — 缓存获取策略 (新架构)
- `components/ccstatusline/` — ccstatusline 组件 (Phase 4)
- `components/_template.lua` — 组件开发模板

#### Critical Bugs
1. **C1**: `opencode.lua:520` — `Ecc.ensure_installed()` 不存在 → `:OpenCodeWriteConfig` 崩溃
2. **C2**: `opencode.lua:453-516` — 大量死代码，引用未定义变量 `warnings`, `errors`, `Providers`
3. **C3**: `registry.lua` — `list_outdated()` 始终返回空 (version_info 未填充)
4. **C4**: 配置生成器不读取 switcher 状态，切换无效
5. **C5**: `ecc/uninstaller.lua` — 删除整个 `~/.claude/commands/` 等目录 (高风险)

---

### 12:30 | 文档整理

- **创建**: `docs/dev/COMPONENT_MANAGER.md` — 完整设计与实现文档
- **创建**: `docs/dev/COMPONENT_MANAGER_LOG.md` — 本文件 (工作日志)

---

## 待办 (按优先级)

### P0 — 阻塞性问题
- [ ] **C4**: 让 `opencode.lua:write_config()` 读取 switcher 状态，动态加载对应组件
- [ ] **C1**: 修复或移除 `Ecc.ensure_installed()` 调用
- [ ] **C2**: 清理 `opencode.lua` 死代码 (453-516 行)
- [ ] **C5**: 修复 ECC uninstaller，只删除 ECC 特定内容

### P1 — 重要改进
- [ ] **C3**: 修复 `list_outdated()`
- [ ] **M6**: 安装过程添加进度显示
- [ ] 架构: 实现缓存 + 分发模式 (manager.lua + syncer.lua)

### P2 — 完善项
- [ ] 创建 `types.lua`
- [ ] 创建 `status_panel.lua`
- [ ] 创建 `ecommands.lua`
- [ ] 创建 `gsd/commands.lua`
- [ ] 创建 `_template.lua`
- [ ] Phase 4: ccstatusline 迁移
- [ ] 替换所有 `vim.api.nvim_buf_set_option` 为新 API
