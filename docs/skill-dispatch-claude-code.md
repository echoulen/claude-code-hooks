# Skill: 使用 Claude Code 執行開發任務

## 概述

當你需要將一個開發任務委派給 Claude Code 執行時，使用 `dispatch-claude-code.sh` 腳本。任務完成後會自動通知到指定的 Telegram 群組，並將結果寫入 JSON 文件。

## 前置條件

- `claude` CLI 已安裝且在 PATH 中
- `jq` 已安裝
- `~/.claude/settings.json` 已配置 hook（執行 `setup.sh` 自動生成）
- 環境變數 `OPENCLAW_GATEWAY_TOKEN` 已設定（如需 Telegram 通知）

## 使用方式

### 基本指令

```bash
<REPO_DIR>/scripts/dispatch-claude-code.sh \
  -p "<任務描述 prompt>" \
  -n "<任務名稱>" \
  -g "<Telegram 群組 ID>" \
  --workdir "<工作目錄>" \
  --permission-mode "bypassPermissions"
```

### 參數說明

| 參數                | 必要 | 說明                                                         |
| ------------------- | ---- | ------------------------------------------------------------ |
| `-p, --prompt`      | ✅   | 任務描述，會直接傳給 Claude Code                             |
| `-n, --name`        | ❌   | 任務名稱，用於追蹤和通知顯示（預設: `adhoc-<timestamp>`）    |
| `-g, --group`       | ✅   | Telegram 群組 ID，任務完成後自動發送結果（見下方說明）       |
| `-w, --workdir`     | ❌   | Claude Code 的工作目錄（預設: 當前目錄）                     |
| `--permission-mode` | ❌   | 權限模式：`plan`, `acceptEdits`, `bypassPermissions` 等      |
| `--agent-teams`     | ❌   | 啟用 Agent Teams 多代理協作模式                              |
| `--teammate-mode`   | ❌   | Agent Teams 模式：`auto`, `in-process`, `tmux`               |
| `--allowed-tools`   | ❌   | 允許的工具白名單                                             |
| `--model`           | ❌   | 覆蓋預設模型（設定 `ANTHROPIC_MODEL` 環境變數）              |

> **重要：`-g` 參數規則**
>
> 你必須始終傳入 `-g` 參數，以確保任務完成後能將結果通知回來。
>
> - 如果使用者有指定目標群組 ID，使用該 ID。
> - 如果使用者沒有指定，使用**當前對話所在的群組/頻道 ID** 作為預設值。

## 範例場景

### 1. 簡單開發任務

```bash
dispatch-claude-code.sh \
  -p "在 src/utils/ 下建立一個 date formatter 工具函數，支援 ISO 8601 和相對時間格式" \
  -n "date-formatter" \
  -g "-5189558203" \
  --workdir "/path/to/project" \
  --permission-mode "bypassPermissions"
```

### 2. Bug 修復

```bash
dispatch-claude-code.sh \
  -p "修復 issue #42: 用戶登入後 session 沒有正確保存的問題。請先閱讀 issue 描述，然後定位問題並修復，最後補充測試。" \
  -n "fix-session-bug" \
  -g "-5189558203" \
  --workdir "/path/to/project" \
  --permission-mode "acceptEdits"
```

### 3. Agent Teams 大型任務

```bash
dispatch-claude-code.sh \
  -p "重構整個專案的測試框架，從 unittest 遷移到 pytest，確保所有測試通過" \
  -n "migrate-to-pytest" \
  -g "-5189558203" \
  --agent-teams \
  --teammate-mode auto \
  --workdir "/path/to/project" \
  --permission-mode "bypassPermissions"
```

## 執行流程

```text
openclaw 決定派發任務
  │
  ├─ 1. 呼叫 dispatch-claude-code.sh（帶上 prompt、名稱、群組 ID）
  │
  ├─ 2. 腳本自動：
  │     ├─ 寫入 task-meta.json（任務元數據）
  │     └─ 啟動 Claude Code 執行任務
  │
  ├─ 3. Claude Code 完成後，Stop Hook 自動觸發：
  │     ├─ 讀取任務輸出
  │     ├─ 寫入 latest.json（完整結果）
  │     ├─ 發送 Telegram 通知到指定群組
  │     └─ 寫入 pending-wake.json（供 AGI 讀取）
  │
  └─ 4. openclaw 可讀取結果：
        ├─ latest.json — 完整任務結果
        └─ pending-wake.json — 簡要摘要
```

## 結果文件

任務完成後，結果位於 `$CLAUDE_CODE_RESULT_DIR`（預設: `<REPO_DIR>/data/claude-code-results/`）：

| 文件                | 內容                                                  |
| ------------------- | ----------------------------------------------------- |
| `latest.json`       | 完整結果（session_id, output, status 等）             |
| `task-meta.json`    | 任務元數據（名稱、群組、開始/結束時間、exit code）    |
| `task-output.txt`   | Claude Code 的原始輸出                                |
| `pending-wake.json` | 簡要摘要，供 AGI heartbeat 讀取                       |

## 注意事項

- **prompt 品質**：prompt 越具體，Claude Code 的執行效果越好。建議包含：目標、約束條件、預期輸出。
- **工作目錄**：確保 `--workdir` 指向正確的專案目錄，Claude Code 會在該目錄下操作。
- **權限模式**：自動化場景建議用 `bypassPermissions`；需要人工審核時用 `plan` 或 `acceptEdits`。
- **Agent Teams**：適合大型任務（重構、遷移），會啟動多個 Claude Code 實例協作。小任務不需要。
- **防重複**：Hook 有 30 秒去重機制，同一任務不會重複通知。
