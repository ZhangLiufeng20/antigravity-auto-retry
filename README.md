# antigravity-auto-retry

[中文](#中文) | [English](#english)

---

## 中文

### 背景

[Antigravity](https://antigravity.dev) 是 Google 推出的 AI 编码编辑器（基于 VS Code / Electron）。由于服务器算力限制，使用过程中频繁出现以下错误：

> **Agent terminated due to error**
> Our servers are experiencing high traffic right now, please try again in a minute.

每次都需要手动点击 **Retry** 按钮才能继续，严重打断编码流。

本脚本通过 [Hammerspoon](https://www.hammerspoon.org/) 自动检测并点击 Retry 按钮，让你无需中断工作。

### 技术原理

- 每 4 秒对 Antigravity 窗口底部区域截图
- 扫描 VS Code 蓝色像素（`#3376CE`，`R<0.25, G>0.35, B>0.7`）
- 通过蓝色像素重心 X 偏移区分 **Retry**（dx ≈ -3）与 **Accept all**（dx ≈ -36），只点 Retry
- 支持多显示器 + Retina 显示屏

### 环境要求

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) 已安装并开启辅助功能权限

### 安装

1. 安装 Hammerspoon：https://www.hammerspoon.org/
2. 在系统设置 → 隐私与安全性 → 辅助功能 中，授权 Hammerspoon
3. 将 `antigravity-auto-retry.lua` 内容粘贴到 `~/.hammerspoon/init.lua` 末尾
4. 在 Hammerspoon 菜单栏图标中点击 **Reload Config**，或运行：
   ```
   open -g hammerspoon://hs.reload
   ```

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+\` | 开启 / 暂停自动 Retry |
| `Cmd+Option+S` | 手动触发一次检测（调试用） |
| `Cmd+Option+Z` | 采样按钮区域颜色（调试用） |

### 注意事项

- 脚本使用像素坐标硬编码了按钮相对位置（窗口右边 40px、底部 136px），适用于 Antigravity 1.22.x。如按钮位置变化，修改 `btnX` / `btnY` 的偏移值即可。
- 若想关闭后台轮询，按 `Cmd+Shift+\` 暂停，或将 `agRetryEnabled` 初始值改为 `false`。

---

## English

### Background

[Antigravity](https://antigravity.dev) is Google's AI-powered code editor (VS Code / Electron-based). Due to server capacity limits, users frequently encounter:

> **Agent terminated due to error**
> Our servers are experiencing high traffic right now, please try again in a minute.

You have to manually click **Retry** every time, constantly breaking your flow.

This script uses [Hammerspoon](https://www.hammerspoon.org/) to automatically detect and click the Retry button so you can keep coding uninterrupted.

### How It Works

- Takes a screenshot of the Antigravity window's bottom area every 4 seconds
- Scans for VS Code blue pixels (`#3376CE`, `R<0.25, G>0.35, B>0.7`)
- Uses the blue pixel centroid X offset to distinguish **Retry** (dx ≈ -3) from **Accept all** (dx ≈ -36) — only clicks Retry
- Supports multiple monitors and Retina displays

### Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) installed with Accessibility permission granted

### Installation

1. Install Hammerspoon: https://www.hammerspoon.org/
2. Go to **System Settings → Privacy & Security → Accessibility** and allow Hammerspoon
3. Append the contents of `antigravity-auto-retry.lua` to `~/.hammerspoon/init.lua`
4. Click **Reload Config** in the Hammerspoon menu bar icon, or run:
   ```
   open -g hammerspoon://hs.reload
   ```

### Hotkeys

| Hotkey | Action |
|--------|--------|
| `Cmd+Shift+\` | Toggle auto Retry on / off |
| `Cmd+Option+S` | Manually trigger detection once (debug) |
| `Cmd+Option+Z` | Sample button area colors (debug) |

### Notes

- The script uses hardcoded pixel offsets relative to the window edge (40px from right, 136px from bottom), calibrated for Antigravity 1.22.x. If the button position changes in a future version, adjust `btnX` / `btnY`.
- To disable background polling, press `Cmd+Shift+\` or set `agRetryEnabled = false` in the script.

---

## License

MIT
