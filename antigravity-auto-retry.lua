-- antigravity-auto-retry.lua
-- 自动检测并点击 Antigravity AI 编辑器的 "Retry" 按钮
-- 背景：Antigravity 服务器算力不足时频繁出现
--   "Our servers are experiencing high traffic right now, please try again in a minute."
--   本脚本通过屏幕截图像素扫描 + 重心偏移判别，自动点击 Retry，跳过 Accept all。
--
-- 使用方法：将本文件内容粘贴到 ~/.hammerspoon/init.lua 末尾，然后 hs.reload()
--
-- 快捷键：
--   Cmd+Shift+\   开启 / 暂停自动 Retry
--   Cmd+Option+S  手动触发一次检测（调试用）
--   Cmd+Option+Z  采样按钮区域颜色（调试用）

-- ─────────────────────────────────────────────────────────────────
-- 核心检测函数
-- ─────────────────────────────────────────────────────────────────

local function agDetectAndRetry()
  local apps = hs.application.applicationsForBundleID("com.google.antigravity")
  if not apps or #apps == 0 then return false end

  local win = apps[1]:focusedWindow() or apps[1]:mainWindow()
  if not win then return false end

  local wf = win:frame()
  -- Retry 按钮锚点：距窗口右边 40px、距底部 136px（实测校准值）
  local btnX = wf.x + wf.w - 40
  local btnY = wf.y + wf.h - 136

  -- 找到真正包含该全局坐标的屏幕（多屏场景）
  local targetScreen = nil
  for _, s in ipairs(hs.screen.allScreens()) do
    local sf = s:fullFrame()
    if btnX >= sf.x and btnX < sf.x + sf.w and btnY >= sf.y and btnY < sf.y + sf.h then
      targetScreen = s
      break
    end
  end
  if not targetScreen then return false end

  local sf  = targetScreen:fullFrame()
  local img = targetScreen:snapshot()
  if not img then return false end

  local sz = img:size()
  -- 缩放比（Retina 下为 2.0，普通屏为 1.0）
  local sx = sz.w / sf.w
  local sy = sz.h / sf.h

  -- 扫描蓝色像素（VS Code 蓝 #3376CE ≈ R<0.25, G>0.35, B>0.7）
  local bxs, bys, cnt = 0, 0, 0
  for dy = -15, 15, 2 do
    for dx = -80, 30, 2 do
      local px = math.floor((btnX + dx - sf.x) * sx)
      local py = math.floor((btnY + dy - sf.y) * sy)
      if px >= 0 and py >= 0 and px < sz.w and py < sz.h then
        local c = img:colorAt({ x = px, y = py })
        if c and (c.red or 1) < 0.25 and (c.green or 0) > 0.35 and (c.blue or 0) > 0.7 then
          bxs = bxs + px
          bys = bys + py
          cnt = cnt + 1
        end
      end
    end
  end
  if cnt < 6 then return false end

  -- 重心 X 偏移判别：
  --   Retry 按钮    → dx ≈ -3  （按钮中心贴近锚点）
  --   Accept all 按钮 → dx ≈ -36 （按钮整体偏左约 36px）
  -- 阈值 -20：偏左超过 20px 则判定为 Accept all，跳过
  local centroidX = (bxs / cnt) / sx + sf.x
  if centroidX - btnX < -20 then return false end

  local cx = centroidX
  local cy = (bys / cnt) / sy + sf.y
  hs.eventtap.leftClick({ x = cx, y = cy })
  hs.alert.show("Antigravity auto Retry OK", 2)
  return true
end

-- ─────────────────────────────────────────────────────────────────
-- 定时轮询（每 4 秒检测一次）
-- ─────────────────────────────────────────────────────────────────

local agRetryEnabled = true

local function agScheduleNext()
  hs.timer.doAfter(4, function()
    if agRetryEnabled then
      local ok, err = pcall(agDetectAndRetry)
      if not ok then print("agRetry error: " .. tostring(err)) end
    end
    agScheduleNext()
  end)
end

agScheduleNext()

-- ─────────────────────────────────────────────────────────────────
-- 快捷键
-- ─────────────────────────────────────────────────────────────────

-- Cmd+Shift+\：开启 / 暂停自动 Retry
hs.hotkey.bind({ "cmd", "shift" }, "\\", function()
  agRetryEnabled = not agRetryEnabled
  hs.alert.show("Antigravity auto Retry " .. (agRetryEnabled and "ON" or "OFF"), 2)
end)

-- Cmd+Option+S：手动触发一次（调试 / 测试用）
hs.hotkey.bind({ "cmd", "alt" }, "S", function()
  local ok = agDetectAndRetry()
  if not ok then hs.alert.show("Retry button not detected", 2) end
end)

-- Cmd+Option+Z：采样按钮区域颜色（调试用，在 Accept all 出现时运行）
hs.hotkey.bind({ "cmd", "alt" }, "Z", function()
  hs.alert.show("Sampling...", 1)
  local apps = hs.application.applicationsForBundleID("com.google.antigravity")
  if not apps or #apps == 0 then return end
  local win = apps[1]:focusedWindow() or apps[1]:mainWindow()
  if not win then return end
  local wf = win:frame()
  local btnX = wf.x + wf.w - 40
  local btnY = wf.y + wf.h - 136
  local screen = nil
  for _, s in ipairs(hs.screen.allScreens()) do
    local sf = s:fullFrame()
    if btnX >= sf.x and btnX < sf.x + sf.w and btnY >= sf.y and btnY < sf.y + sf.h then
      screen = s
      break
    end
  end
  if not screen then print("Screen not found"); return end
  local sf  = screen:fullFrame()
  local img = screen:snapshot()
  if not img then return end
  local sz = img:size()
  local sx = sz.w / sf.w
  local sy = sz.h / sf.h
  print("=== Sample btnX=" .. btnX .. " btnY=" .. btnY .. " ===")
  for dy = -30, 30, 6 do
    for dx = -120, 60, 6 do
      local px = math.floor((btnX + dx - sf.x) * sx)
      local py = math.floor((btnY + dy - sf.y) * sy)
      if px >= 0 and py >= 0 and px < sz.w and py < sz.h then
        local c = img:colorAt({ x = px, y = py })
        if c then
          local r = math.floor((c.red   or 0) * 255)
          local g = math.floor((c.green or 0) * 255)
          local b = math.floor((c.blue  or 0) * 255)
          if r > 50 or g > 50 or b > 60 then
            print("dx=" .. dx .. " dy=" .. dy .. " RGB=(" .. r .. "," .. g .. "," .. b .. ")")
          end
        end
      end
    end
  end
end)
