# Claude Code Stop Hook — 任务完成自动回调

当 Claude Code（含 Agent Teams）完成任务后，自动：
1. 将结果写入 JSON 文件
2. 发送 聊天软件 通知到指定群组
3. 写入 pending-wake 文件供 AGI 主会话读取

## 架构

```
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

| 文件 | 位置 | 作用 |
|------|------|------|
| `hooks/notify-agi.sh` | `~/.claude/hooks/` | Stop Hook 脚本 |
| `hooks/claude-settings.json` | `~/.claude/settings.json` | Claude Code 配置（注册 hook）|
| `scripts/dispatch-claude-code.sh` | 任意位置 | 一键派发任务 |
| `scripts/claude_code_run.py` | 任意位置 | Claude Code PTY 运行器 |

## 使用方法

### 基础任务
```bash
dispatch-claude-code.sh \
  -p "实现一个 Python 爬虫" \
  -n "my-scraper" \
  -g "-5189558203" \
  --permission-mode "bypassPermissions" \
  --workdir "/home/ubuntu/projects/scraper"
```

### Agent Teams 任务
```bash
dispatch-claude-code.sh \
  -p "重构整个项目的测试" \
  -n "test-refactor" \
  -g "-5189558203" \
  --agent-teams \
  --teammate-mode auto \
  --permission-mode "bypassPermissions" \
  --workdir "/home/ubuntu/projects/myapp"
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

在 `~/.claude/settings.json` 中注册：
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 10}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 10}]}]
  }
}
```

## 防重复机制

Hook 在 Stop 和 SessionEnd 都会触发。脚本使用 `.hook-lock` 文件去重：
- 30秒内重复触发自动跳过
- 只处理第一个事件（通常是 Stop）

## 结果文件

任务完成后，结果写入 `/home/ubuntu/clawd/data/claude-code-results/latest.json`：
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