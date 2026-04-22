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

**事件驱动**，平时零 CPU 开销：

1. **日志监听**：用 `hs.pathwatcher` 监听 Antigravity 自身的 Language Server 日志
   `~/Library/Application Support/Antigravity/logs/<最新会话>/ls-main.log`
2. **关键字命中**即唤醒：
   - `agent executor error` → "Agent terminated due to error" 弹框
   - `UNAVAILABLE (code 503)` → 服务器容量不足
   - `RESOURCE_EXHAUSTED (code 429)` → 配额用完
3. **短期像素扫描**：命中后立即截取 Antigravity 窗口截图，扫 VS Code 蓝色像素（`#3376CE`，`R<0.25, G>0.35, B>0.7`），失败则每 2 秒重试，最多 60 秒
4. **按钮区分**：用蓝色像素重心 X 偏移区分 **Retry**（dx ≈ -3）与 **Accept all**（dx ≈ -36），只点 Retry
5. **防抖**：成功点击后 15 秒内不再重复触发
6. **AG 重启自愈**：同时监听 `logs/` 根目录，AG 重启生成新会话目录时自动切换监听目标
7. 支持多显示器 + Retina 显示屏

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
| `Cmd+Option+L` | 打印当前监听状态到 Hammerspoon Console（诊断用） |
| `Cmd+Option+Z` | 采样按钮区域颜色（调试用） |

### 注意事项

- 按钮位置使用像素坐标硬编码（窗口右边 40px、底部 136px），适用于 Antigravity 1.22.x。如按钮位置变化，修改 `btnX` / `btnY` 的偏移值即可。
- 按 `Cmd+Shift+\` 暂停自动 Retry，或将 `agRetryEnabled` 初始值改为 `false`。
- 如果下次 AG 出现弹框时脚本没反应，先按 `Cmd+Option+L` 看 Console 中的监听文件是否正确；再 `tail` 一下对应 `ls-main.log`，确认错误日志是否带了 `agent executor error` / `code 503` / `code 429` 之一。若出现了新的错误签名，在脚本中 `AG_TRIGGER_PATTERNS` 里补上即可。

---

## English

### Background

[Antigravity](https://antigravity.dev) is Google's AI-powered code editor (VS Code / Electron-based). Due to server capacity limits, users frequently encounter:

> **Agent terminated due to error**
> Our servers are experiencing high traffic right now, please try again in a minute.

You have to manually click **Retry** every time, constantly breaking your flow.

This script uses [Hammerspoon](https://www.hammerspoon.org/) to automatically detect and click the Retry button so you can keep coding uninterrupted.

### How It Works

**Event-driven**, zero CPU when idle:

1. **Log watcher**: uses `hs.pathwatcher` to tail Antigravity's language server log
   `~/Library/Application Support/Antigravity/logs/<latest session>/ls-main.log`
2. **Trigger keywords** (any match wakes the retry routine):
   - `agent executor error` → "Agent terminated due to error" modal
   - `UNAVAILABLE (code 503)` → server capacity exhausted
   - `RESOURCE_EXHAUSTED (code 429)` → quota exhausted
3. **Short-burst pixel scan**: on trigger, immediately snapshot the Antigravity window, scan for VS Code blue pixels (`#3376CE`, `R<0.25, G>0.35, B>0.7`); retry every 2s for up to 60s if not found
4. **Button disambiguation**: uses the blue pixel centroid X offset to distinguish **Retry** (dx ≈ -3) from **Accept all** (dx ≈ -36), only clicking Retry
5. **Debounce**: ignore re-triggers within 15s of a successful click
6. **AG restart self-heal**: also watches `logs/` root; when AG starts a new session directory, the log watcher automatically switches targets
7. Supports multiple monitors and Retina displays

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
| `Cmd+Option+L` | Print watcher status to Hammerspoon Console (diagnostic) |
| `Cmd+Option+Z` | Sample button area colors (debug) |

### Notes

- The button position uses hardcoded pixel offsets relative to the window edge (40px from right, 136px from bottom), calibrated for Antigravity 1.22.x. Adjust `btnX` / `btnY` if the button moves in future versions.
- To disable the watcher, press `Cmd+Shift+\` or set `agRetryEnabled = false` in the script.
- If the script fails to react next time a modal appears, press `Cmd+Option+L` to verify the watched log path, then `tail` the corresponding `ls-main.log` to check whether the error line contains one of `agent executor error` / `code 503` / `code 429`. If Google introduces a new error signature, add it to `AG_TRIGGER_PATTERNS` in the script.

---

## License

MIT
