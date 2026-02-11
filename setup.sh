#!/bin/bash
# setup.sh — Generate claude-settings.json with correct paths for this repo
#
# Usage:
#   ./setup.sh
#
# This will:
#   1. Detect the repo directory
#   2. Generate a ready-to-use claude-settings.json with absolute hook paths
#   3. Optionally install it to ~/.claude/settings.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
HOOK_PATH="${REPO_DIR}/hooks/notify-agi.sh"
RESULT_DIR="${CLAUDE_CODE_RESULT_DIR:-${REPO_DIR}/data/claude-code-results}"

echo "📁 Repo directory: ${REPO_DIR}"
echo "🔗 Hook path:      ${HOOK_PATH}"
echo "📂 Result dir:     ${RESULT_DIR}"

# Ensure hooks are executable
chmod +x "${REPO_DIR}/hooks/"*.sh 2>/dev/null || true
chmod +x "${REPO_DIR}/scripts/"*.sh 2>/dev/null || true

# Create data directory
mkdir -p "$RESULT_DIR"

# Generate settings JSON
GENERATED="${REPO_DIR}/claude-settings.local.json"
cat > "$GENERATED" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_PATH}",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_PATH}",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF

echo ""
echo "✅ Generated: ${GENERATED}"
echo ""
echo "To install, merge into your Claude Code settings:"
echo "  cp ${GENERATED} ~/.claude/settings.json"
echo ""
echo "Or manually copy the hooks section into your existing ~/.claude/settings.json"
