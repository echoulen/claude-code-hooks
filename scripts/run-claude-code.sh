#!/bin/bash
# 启动 Claude Code 并确保 hook 环境变量可用
# 用法: ./run-claude-code.sh -p "你的任务" [其他 claude 参数]
#
# 示例:
#   ./run-claude-code.sh -p "Write hello.py that prints hello world" --allowedTools "Bash,Read,Edit,Write"
#   ./run-claude-code.sh -p "Analyze this repo" --permission-mode plan

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULT_DIR="${CLAUDE_CODE_RESULT_DIR:-${REPO_DIR}/data/claude-code-results}"
OUTPUT_FILE="${RESULT_DIR}/claude-code-output.txt"

export OPENCLAW_GATEWAY_TOKEN=""

mkdir -p "$RESULT_DIR"

# 清理上次的输出文件
> "$OUTPUT_FILE"

# 运行 Claude Code，输出同时写入文件和 stdout
claude "$@" 2>&1 | tee "$OUTPUT_FILE"
