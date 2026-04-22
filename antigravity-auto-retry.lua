-- antigravity-auto-retry.lua (v3 · 事件驱动)
-- 自动检测并点击 Antigravity AI 编辑器的 "Retry" 按钮
--
-- 触发机制：
--   监听 ~/Library/Application Support/Antigravity/logs/<最新会话>/ls-main.log
--   一旦检测到服务端错误关键字（agent executor error / 503 / 429），
--   立即发起一次像素扫描点击；失败则每 2s 重试，最多 60s 停。
--   平时 0 CPU，不做任何轮询。
--
-- 使用方法：将本文件内容粘贴到 ~/.hammerspoon/init.lua 末尾，然后 hs.reload()
--
-- 快捷键：
--   Cmd+Shift+\   开启 / 暂停自动 Retry
--   Cmd+Option+S  手动触发一次检测（调试）
--   Cmd+Option+L  打印当前监听状态到 Console（诊断）
--   Cmd+Option+Z  采样按钮区域颜色（调试，在 Accept all 出现时运行）

-- ─────────────────────────────────────────────────────────────────
-- 状态 & 常量
-- ─────────────────────────────────────────────────────────────────
agRetryEnabled = true
local AG_BUNDLE_ID = "com.google.antigravity"
local AG_LOGS_ROOT = os.getenv("HOME") .. "/Library/Application Support/Antigravity/logs"

-- 触发关键字（OR 关系，任意命中即唤醒）
--   agent executor error          → 对应 "Agent terminated due to error" 弹框
--   UNAVAILABLE %(code 503%)      → 服务器容量不足（旧 high traffic 弹框）
--   RESOURCE_EXHAUSTED %(code 429%) → 配额用完
local AG_TRIGGER_PATTERNS = {
  "agent executor error",
  "UNAVAILABLE %(code 503%)",
  "RESOURCE_EXHAUSTED %(code 429%)",
}

local agLogWatcher, agRootWatcher = nil, nil
local agLogPath, agLogOffset = nil, 0
local agPolling = false
local agLastClickAt = 0

-- ─────────────────────────────────────────────────────────────────
-- 工具：定位 Antigravity 主窗口（不依赖 focus，遍历选最大 standard 窗）
-- ─────────────────────────────────────────────────────────────────
local function agFindMainWindow()
  local apps = hs.application.applicationsForBundleID(AG_BUNDLE_ID)
  if not apps or #apps == 0 then return nil end
  local best, bestArea = nil, 0
  for _, app in ipairs(apps) do
    for _, w in ipairs(app:allWindows() or {}) do
      if w:isStandard() then
        local f = w:frame()
        local area = f.w * f.h
        if area > bestArea then
          best, bestArea = w, area
        end
      end
    end
  end
  return best
end

-- ─────────────────────────────────────────────────────────────────
-- 核心：像素扫描 + 点击 Retry 按钮
-- 扫 VS Code 蓝 #3376CE（R<0.25, G>0.35, B>0.7），用重心偏移区分 Retry vs Accept all
-- ─────────────────────────────────────────────────────────────────
local function agDetectAndRetry()
  local win = agFindMainWindow()
  if not win then return false end
  local wf = win:frame()
  local img = win:snapshot()
  if not img then return false end
  local sz = img:size()
  local sx = sz.w / wf.w
  local sy = sz.h / wf.h
  local btnX = wf.w - 40
  local btnY = wf.h - 136
  local bxs, bys, cnt = 0, 0, 0
  for dy = -15, 15, 2 do
    for dx = -80, 30, 2 do
      local px = math.floor((btnX + dx) * sx)
      local py = math.floor((btnY + dy) * sy)
      if px >= 0 and py >= 0 and px < sz.w and py < sz.h then
        local c = img:colorAt({ x = px, y = py })
        if c and (c.red or 1) < 0.25 and (c.green or 0) > 0.35 and (c.blue or 0) > 0.7 then
          bxs = bxs + px; bys = bys + py; cnt = cnt + 1
        end
      end
    end
  end
  if cnt < 6 then return false end
  local centroidX = (bxs / cnt) / sx
  if centroidX - btnX < -20 then return false end
  local cx = wf.x + (bxs / cnt) / sx
  local cy = wf.y + (bys / cnt) / sy
  hs.eventtap.leftClick({ x = cx, y = cy })
  agLastClickAt = hs.timer.secondsSinceEpoch()
  hs.alert.show("Antigravity 自动 Retry ✓", 2)
  return true
end

-- ─────────────────────────────────────────────────────────────────
-- 命中后的短期轮询：立即试一次，失败每 2s 重试，最多 60s
-- 15s 防抖：上次点击后 15s 内不重复唤醒
-- ─────────────────────────────────────────────────────────────────
local function agStartShortPolling()
  if agPolling then return end
  if hs.timer.secondsSinceEpoch() - agLastClickAt < 15 then return end
  agPolling = true
  local attempts = 0
  local function poll()
    if not agRetryEnabled or not agPolling or attempts >= 30 then
      agPolling = false; return
    end
    attempts = attempts + 1
    local ok, hit = pcall(agDetectAndRetry)
    if not ok then print("[agRetry] detect error: " .. tostring(hit)) end
    if hit then agPolling = false; return end
    hs.timer.doAfter(2, poll)
  end
  poll()
end

-- ─────────────────────────────────────────────────────────────────
-- 日志监听
-- ─────────────────────────────────────────────────────────────────

-- 找最新会话的 ls-main.log（会话目录名为 ISO 时间戳，字典序等同时间序）
local function agFindLatestLog()
  local best = nil
  local ok, err = pcall(function()
    for f in hs.fs.dir(AG_LOGS_ROOT) do
      if f and f:match("^%d+T%d+$") then
        if not best or f > best then best = f end
      end
    end
  end)
  if not ok then
    print("[agRetry] 扫描日志目录失败: " .. tostring(err))
    return nil
  end
  if not best then return nil end
  local path = AG_LOGS_ROOT .. "/" .. best .. "/ls-main.log"
  if not hs.fs.attributes(path) then return nil end
  return path
end

local function agOnLogChange()
  if not agRetryEnabled or not agLogPath then return end
  local f = io.open(agLogPath, "r")
  if not f then return end
  local curSize = f:seek("end")
  -- 文件被截断/替换：重置偏移，跳过本次
  if curSize < agLogOffset then agLogOffset = curSize; f:close(); return end
  f:seek("set", agLogOffset)
  local newContent = f:read("*a") or ""
  agLogOffset = curSize
  f:close()
  for _, pat in ipairs(AG_TRIGGER_PATTERNS) do
    if newContent:find(pat) then
      print("[agRetry] trigger matched: " .. pat)
      agStartShortPolling()
      return
    end
  end
end

local function agAttachLogWatcher()
  local path = agFindLatestLog()
  if not path then
    print("[agRetry] ls-main.log 未找到，路径: " .. AG_LOGS_ROOT)
    return
  end
  if agLogWatcher then agLogWatcher:stop(); agLogWatcher = nil end
  agLogPath = path
  local f = io.open(path, "r")
  if f then agLogOffset = f:seek("end"); f:close() else agLogOffset = 0 end
  agLogWatcher = hs.pathwatcher.new(path, agOnLogChange)
  agLogWatcher:start()
  print("[agRetry] 已监听 " .. path .. " (offset=" .. agLogOffset .. ")")
end

-- 监听 logs 根目录：AG 重启产生新会话目录时，延迟 3s 切换到新日志文件
local function agAttachRootWatcher()
  if agRootWatcher then agRootWatcher:stop() end
  agRootWatcher = hs.pathwatcher.new(AG_LOGS_ROOT .. "/", function()
    hs.timer.doAfter(3, agAttachLogWatcher)
  end)
  agRootWatcher:start()
end

agAttachRootWatcher()
agAttachLogWatcher()

-- ─────────────────────────────────────────────────────────────────
-- 快捷键
-- ─────────────────────────────────────────────────────────────────

-- Cmd+Shift+\：开启 / 暂停自动 Retry
hs.hotkey.bind({ 'cmd', 'shift' }, '\\', function()
  agRetryEnabled = not agRetryEnabled
  hs.alert.show("Antigravity 自动 Retry " .. (agRetryEnabled and "已开启" or "已暂停"), 2)
end)

-- Cmd+Option+S：手动触发一次检测
hs.hotkey.bind({ 'cmd', 'alt' }, 'S', function()
  local ok = agDetectAndRetry()
  if not ok then hs.alert.show("未检测到 Retry 按钮", 2) end
end)

-- Cmd+Option+L：打印当前监听状态到 Hammerspoon Console
hs.hotkey.bind({ 'cmd', 'alt' }, 'L', function()
  print("=== Antigravity 自动 Retry 状态 ===")
  print("启用: " .. tostring(agRetryEnabled))
  print("监听文件: " .. tostring(agLogPath))
  print("当前 offset: " .. tostring(agLogOffset))
  print("上次点击: " .. (agLastClickAt > 0 and os.date("%H:%M:%S", agLastClickAt) or "未触发过"))
  print("正在短轮询: " .. tostring(agPolling))
  local win = agFindMainWindow()
  if win then
    local f = win:frame()
    print(string.format("主窗口: %dx%d @ (%d,%d)", f.w, f.h, f.x, f.y))
  else
    print("主窗口: 未找到")
  end
  hs.alert.show("状态已打印到 Hammerspoon Console", 2)
end)

-- Cmd+Option+Z：采样按钮区域颜色（Accept all 出现时用，校准阈值）
hs.hotkey.bind({ 'cmd', 'alt' }, 'Z', function()
  hs.alert.show("采样中...", 1)
  local win = agFindMainWindow()
  if not win then print("[agRetry] 未找到 Antigravity 窗口"); return end
  local wf = win:frame()
  local img = win:snapshot()
  if not img then return end
  local sz = img:size()
  local sx = sz.w / wf.w
  local sy = sz.h / wf.h
  local btnX = wf.w - 40
  local btnY = wf.h - 136
  print(string.format("=== 诊断 winSize=%dx%d btnX=%d btnY=%d ===", wf.w, wf.h, btnX, btnY))
  for dy = -30, 30, 6 do
    for dx = -120, 60, 6 do
      local px = math.floor((btnX + dx) * sx)
      local py = math.floor((btnY + dy) * sy)
      if px >= 0 and py >= 0 and px < sz.w and py < sz.h then
        local c = img:colorAt({ x = px, y = py })
        if c then
          local r = math.floor((c.red or 0) * 255)
          local g = math.floor((c.green or 0) * 255)
          local b = math.floor((c.blue or 0) * 255)
          if r > 50 or g > 50 or b > 60 then
            print(string.format("dx=%d dy=%d RGB=(%d,%d,%d)", dx, dy, r, g, b))
          end
        end
      end
    end
  end
end)
