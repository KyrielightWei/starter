# AGENTS.md - Pi Agent 指令模板

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  AGENTS.md 是项目级上下文指令文件，Pi 启动时自动加载                   ║
║                                                                        ║
║  文件位置:                                                              ║
║    - ~/.pi/agent/AGENTS.md (全局)                                      ║
║    - 项目目录及其父目录 (向上查找，合并)                                ║
║                                                                        ║
║  禁用: --no-context-files 或 -nc                                       ║
╚════════════════════════════════════════════════════════════════════════╝
-->

## Style

代码风格约定:
- 使用简洁、惯用的代码
- 遵循现有代码库的模式
- 避免不必要的抽象
- 保持函数小，文件聚焦
- 中文注释在代码中 (保持仓库约定)
- 使用双引号，2 空格缩进

## Tools

工具使用约定:
- 使用 `read` 查看文件，再用 `edit` 或 `write` 修改
- 修改后运行验证命令 (build, lint, test)
- 不要用 `as any` 或 `@ts-ignore` 抑制类型错误
- 不要提交 secrets 或 credentials
- 只暂存预期的文件

## Git

Git 工作流:
- 原子提交，清晰的 conventional commit 消息
- feat: 新功能 | fix: 修复 bug | refactor: 重构
- docs: 文档 | style: 格式 | test: 测试 | chore: 杂项
- 不要提交 secrets 或 credentials
- 提交前检查 git diff

## Workflow

工作流程:
- 实现模糊请求前先询问
- 修改后用 build/lint 命令验证
- 保持函数小，文件聚焦
- 复杂任务拆解为步骤

## Commands

常用命令:

```bash
# 构建
npm run build

# 测试
npm test

# Lint
npm run lint

# 格式化
npm run format

# Neovim (Lua)
stylua lua/
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"
```