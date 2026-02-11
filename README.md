# Claude Code Stop Hook — 任务完成自动回调

当 Claude Code（含 Agent Teams）完成任务后，自动：

1. 将结果写入 JSON 文件
2. 发送 聊天软件 通知到指定群组
3. 写入 pending-wake 文件供 AGI 主会话读取

## 架构

```text
dispatch-claude-code.sh
  │
  ├─ 写入 task-meta.json（任务名、目标群组）
  ├─ 启动 Claude Code（via claude_code_run.py）
  │   └─ Agent Teams lead + sub-agents 运行
  │
  └─ Claude Code 完成 → Stop Hook 自动触发
      │
      ├─ notify-agi.sh 执行：
      │   ├─ 读取 task-meta.json + task-output.txt
      │   ├─ 写入 latest.json（完整结果）
      │   ├─ openclaw message send → 聊天软件 群
      │   └─ 写入 pending-wake.json
      │
      └─ AGI heartbeat 读取 pending-wake.json（备选）
```

## 文件说明

| 文件 | 作用 |
|------|------|

| `hooks/notify-agi.sh` | Stop Hook 脚本（路径自动从脚本位置推导）|
| `hooks/claude-settings.json` | Claude Code 配置模板（`<REPO_DIR>` 占位符）|
| `scripts/dispatch-claude-code.sh` | 一键派发任务 |
| `scripts/claude_code_run.py` | Claude Code PTY 运行器 |
| `scripts/run-claude-code.sh` | 简易 Claude Code 启动脚本 |
| `setup.sh` | 自动生成含正确路径的 `claude-settings.local.json` |

## 安装

```bash
git clone <repo-url> && cd claude-code-hooks
./setup.sh
```

`setup.sh` 会自动检测 repo 路径，生成 `claude-settings.local.json`，将其内容合并到 `~/.claude/settings.json` 即可。

## 使用方法

### 基础任务

```bash
./scripts/dispatch-claude-code.sh \
  -p "实现一个 Python 爬虫" \
  -n "my-scraper" \
  -g "-5189558203" \
  --permission-mode "bypassPermissions" \
  --workdir "$HOME/projects/scraper"
```

### Agent Teams 任务

```bash
./scripts/dispatch-claude-code.sh \
  -p "重构整个项目的测试" \
  -n "test-refactor" \
  -g "-5189558203" \
  --agent-teams \
  --teammate-mode auto \
  --permission-mode "bypassPermissions" \
  --workdir "$HOME/projects/myapp"
```

### 参数

| 参数 | 说明 |
|------|------|

| `-p, --prompt` | 任务提示（必需）|
| `-n, --name` | 任务名称（用于跟踪）|
| `-g, --group` | 聊天软件 群组 ID（结果自动发送）|
| `-w, --workdir` | 工作目录 |
| `--agent-teams` | 启用 Agent Teams |
| `--teammate-mode` | Agent Teams 模式 (auto/in-process/tmux) |
| `--permission-mode` | 权限模式 |
| `--allowed-tools` | 允许的工具列表 |

## Hook 配置

运行 `./setup.sh` 自动生成配置，或手动在 `~/.claude/settings.json` 中注册（将 `<REPO_DIR>` 替换为实际路径）：

```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "<REPO_DIR>/hooks/notify-agi.sh", "timeout": 10}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "<REPO_DIR>/hooks/notify-agi.sh", "timeout": 10}]}]
  }
}
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|

| `CLAUDE_CODE_BIN` | claude 二进制路径 | 自动从 PATH 查找 |
| `CLAUDE_CODE_RESULT_DIR` | 结果输出目录 | `<REPO_DIR>/data/claude-code-results` |
| `OPENCLAW_BIN` | openclaw 二进制路径 | 自动从 PATH 查找 |
| `OPENCLAW_GATEWAY_TOKEN` | OpenClaw 网关 token | （需手动设置）|
| `OPENCLAW_GATEWAY` | OpenClaw 网关地址 | `http://127.0.0.1:18789` |

## 防重复机制

Hook 在 Stop 和 SessionEnd 都会触发。脚本使用 `.hook-lock` 文件去重：

- 30秒内重复触发自动跳过
- 只处理第一个事件（通常是 Stop）

## 结果文件

任务完成后，结果写入 `<REPO_DIR>/data/claude-code-results/latest.json`（或 `$CLAUDE_CODE_RESULT_DIR/latest.json`）：

```json
{
  "session_id": "...",
  "timestamp": "2026-02-10T01:02:33+00:00",
  "task_name": "fibonacci-demo",
  "telegram_group": "-5189558203",
  "output": "...",
  "status": "done"
}
```
