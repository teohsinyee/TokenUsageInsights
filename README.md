# TokenUsageInsights

本機優先的 Token 使用量與 Session 看板，專注支援：

- GitHub Copilot Chat（VS Code）
- GitHub Copilot CLI
- Codex Desktop
- Codex CLI

它只讀取電腦上的本機記錄，不會呼叫 AI 供應商 API 查詢帳戶資料。Token 統計、模型分布、估算費用與 Session 時間軸都在本機處理。

## 直接請 Codex 幫你設定

你可以把這段話貼給 Codex：

> 請幫我安裝並啟動 TokenUsageInsights，讀取我本機的 GitHub Copilot 和 Codex 使用記錄，確認 Dashboard 可以開啟，並告訴我哪些資料成功同步。

## 安裝

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/doggy8088/TokenUsageInsights/main/scripts/get.ps1 | iex
& "$HOME\bin\token-usage-insights.cmd"
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/doggy8088/TokenUsageInsights/main/scripts/get.sh | bash
token-usage-insights
```

開啟 [http://localhost:3003](http://localhost:3003)，等待同步完成後，在左側選擇 `Copilot` 或 `Codex`。

<details>
<summary>詳細說明：資料來源、Codex Desktop、設定與排錯</summary>

## 資料來源

| 來源 | 額外設定 | 本機資料來源 |
| --- | --- | --- |
| GitHub Copilot Chat（VS Code） | 不需要 | VS Code `workspaceStorage/chatSessions` |
| GitHub Copilot CLI | 需要 Status Line | `~/.copilot/usage/usage-YYYY-MM-DD.jsonl` |
| Codex Desktop | 不需要 | `~/.codex/sessions` |
| Codex CLI | 不需要 | `~/.codex/sessions` |

## Codex Desktop 支援

Dashboard 目前的來源標籤仍叫 `Codex CLI`，但 Codex Desktop 產生的本機 Session 若寫入同一個 `~/.codex/sessions` 目錄，也可以被讀取。這是本機記錄相容，不是透過 Codex Desktop API 整合。

因此：

1. 正常使用 Codex Desktop 產生至少一個 Session。
2. 啟動 Dashboard。
3. 選擇 `Codex CLI`。
4. 按右上角同步，或等待背景同步。

這個 Dashboard 統計本機 Session Token，不等同於 ChatGPT/Codex 帳戶的即時 quota。若 Session 中有 quota 資訊，顯示的也是最後一次本機記錄，不是即時線上查詢。

## GitHub Copilot

VS Code Copilot Chat 不需要安裝 Hook 或收集腳本；Dashboard 會直接掃描本機聊天 Session。

Copilot CLI 需要把 Status Line 腳本接到 Copilot CLI 的設定，讓每次對話後寫入 Token 記錄。安裝後請在 Dashboard 內開啟設定指南，複製目前平台對應的命令。

## Windows 預設路徑

| 用途 | 路徑 |
| --- | --- |
| Dashboard 啟動檔 | `%USERPROFILE%\bin\token-usage-insights.cmd` |
| Codex 記錄 | `%USERPROFILE%\.codex\sessions` |
| Copilot 記錄 | `%USERPROFILE%\.copilot` |
| SQLite 資料庫 | `%LOCALAPPDATA%\TokenUsageInsights\token_usage_insights.db` |

Windows 安裝版不需要 Rust、Cargo、WSL、Git Bash 或 `jq`。

## 沒有資料時

- 確認你已經在對應工具產生至少一個 Session。
- 按 Dashboard 右上角的同步按鈕。
- 確認記錄路徑存在，並且沒有使用自訂的 Codex、Copilot 或 VS Code 資料目錄。
- 如果你不確定，直接請 Codex 執行上面的設定提示，並要求它檢查同步結果。

</details>

## License

MIT
