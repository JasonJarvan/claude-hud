# Claude Code 状态栏定制设计文档

## 概述

基于 [claude-hud](https://github.com/jarrodwatts/claude-hud) 安装的 `statusline-command.sh`，针对个人使用习惯进行了定制。状态栏通过 Claude Code 的 `statusLine.command` 配置项挂载，每次刷新时 Claude Code 将上下文 JSON 通过 stdin 传入脚本，脚本输出文本显示在状态栏。

## 配置入口

`~/.claude/settings.json`：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /home/zhaosheng/.claude/statusline-command.sh",
    "padding": 0
  }
}
```

## 布局设计

所有字段合并为**单行**，以 `|` 分隔，保持紧凑：

```
📁 ~/当前目录 | 🌿 分支 +增/-删 | 模型名(紫) | ████░░ 23% | $4.93(金) | 76m reset(绿)/76m remain(红)
```

## 字段说明

| 字段 | 数据来源 | 颜色 | 说明 |
|------|----------|------|------|
| `📁 ~/dir` | Claude Code JSON `.workspace.current_dir` | 默认 | 当前工作目录，home 路径缩写为 `~` |
| `🌿 branch +N/-N` | git（从 current_dir 读取） | 绿/红 | 分支名 + 相对 HEAD 的增删行数 |
| 模型名 | Claude Code JSON `.model.display_name` | 紫 `\033[38;5;135m` | 当前使用的 Claude 模型 |
| `████░░ N%` | Claude Code JSON `.context_window.used_percentage` | 绿/黄/红（按占用率） | 上下文窗口使用率，<50% 绿，<80% 黄，≥80% 红 |
| `$N.NN` | ccusage（5分钟缓存） | 金 `\033[38;5;220m` | 当前 billing block 累计费用（USD） |
| `Nm reset` | ccusage `.endTime` 计算 | 绿 `\033[32m` | 当前 block 到期倒计时（分钟） |
| `Nm remain` | ccusage `.projection.remainingMinutes` | 红 `\033[31m` | 按当前消耗速率预计配额耗尽时间（分钟） |

## 关键概念

**Billing Block（计费块）**：Claude Code 按使用块计费，每块持续约 5 小时，从首次使用时刻起算。`reset` 是 block 到期的剩余时间，`remain` 是按当前 token 消耗速率估算的配额剩余时间。两者差距越大说明使用节奏越轻松。

**ccusage 缓存**：费用和时间数据每 5 分钟刷新一次，缓存于 `~/.claude/ccusage-cache.json`，避免频繁调用影响响应速度。

## 未启用的可用字段

| 字段 | 含义 |
|------|------|
| `burnRate.costPerHour` | 当前每小时消耗速率 |
| `burnRate.tokensPerMinute` | 每分钟 token 消耗速率 |
| `projection.totalCost` | 预计本 block 总花费 |
| `totalTokens` | 本 block 已用总 token 数 |
| `tokenCounts.cacheReadInputTokens` | 缓存命中 token 数（体现省钱效果） |
| `entries` | 本 block 会话数量 |
