-- luacheck: globals EnhanceQoL GetFramerate GetNetStats GAMEMENU_OPTIONS MAINMENUBAR_FPS_LABEL MAINMENUBAR_LATENCY_LABEL
local addonName, addon = ...
local L = addon.L

local AceGUI = addon.AceGUI
local db
local stream

local function getOptionsHint()
	if addon.DataPanel and addon.DataPanel.GetOptionsHintText then
		local text = addon.DataPanel.GetOptionsHintText()
		if text ~= nil then return text end
		return nil
	end
	return L["Right-Click for options"]
end

-- Micro-optimizations: localize frequently used globals
local floor = math.floor
local min = math.min
local format = string.format
local GetTime = GetTime
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats

-- Runtime state for smoothing and cadence
local lastPingUpdate = 0
local pingHome, pingWorld = nil, nil
local emaFPS -- exponential moving average for FPS
-- Change detection cache (declare early so callbacks see locals, not globals)
local lastFps, lastHome, lastWorld, lastMode

-- Color helpers (hex without leading #)
local function fpsColorHex(v)
    if v >= 60 then return "00ff00" -- green
    elseif v >= 30 then return "ffff00" -- yellow
    else return "ff0000" end -- red
end

local function pingColorHex(v)
    if v <= 50 then return "00ff00" -- green
    elseif v <= 100 then return "ffff00" -- yellow
    else return "ff0000" end -- red
end

local function ensureDB()
    addon.db.datapanel = addon.db.datapanel or {}
    addon.db.datapanel.latency = addon.db.datapanel.latency or {}
    db = addon.db.datapanel.latency

    db.fontSize = db.fontSize or 14
    -- Cadence (seconds)
    db.fpsInterval = db.fpsInterval or 0.25 -- 4x/s
    db.pingInterval = db.pingInterval or 1.0 -- 1x/s
    -- Smoothing window (seconds); 0 disables smoothing
    if db.fpsSmoothWindow == nil then db.fpsSmoothWindow = 0.75 end
    -- Ping display mode: "max" or "split"
    db.pingMode = db.pingMode or "max"
end

local function RestorePosition(frame)
    if not db then return end
    if db.point and db.x and db.y then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end
end

local aceWindow
local function createAceWindow()
    if aceWindow then
        aceWindow:Show()
        return
    end
    ensureDB()
    local frame = AceGUI:Create("Window")
    aceWindow = frame.frame
    frame:SetTitle(GAMEMENU_OPTIONS)
    frame:SetWidth(320)
    frame:SetHeight(300)
    frame:SetLayout("List")

    frame.frame:SetScript("OnShow", function(self) RestorePosition(self) end)
    frame.frame:SetScript("OnHide", function(self)
        local point, _, _, xOfs, yOfs = self:GetPoint()
        db.point = point
        db.x = xOfs
        db.y = yOfs
    end)

    -- Debounce RequestUpdate calls while dragging sliders
    local sliderTimer
    local function scheduleUpdate()
        if sliderTimer then sliderTimer:Cancel() end
        sliderTimer = C_Timer.NewTimer(0.05, function()
            sliderTimer = nil
            if stream then addon.DataHub:RequestUpdate(stream) end
        end)
    end

    local fontSize = AceGUI:Create("Slider")
    fontSize:SetLabel(FONT_SIZE)
    fontSize:SetSliderValues(8, 32, 1)
    fontSize:SetValue(db.fontSize)
    fontSize:SetCallback("OnValueChanged", function(_, _, val)
        db.fontSize = val
        scheduleUpdate()
    end)
    frame:AddChild(fontSize)

    local fpsRate = AceGUI:Create("Slider")
    fpsRate:SetLabel(L["FPS update interval (s)"] or "FPS update interval (s)")
    fpsRate:SetSliderValues(0.10, 1.00, 0.05)
    fpsRate:SetValue(db.fpsInterval)
    fpsRate:SetCallback("OnValueChanged", function(_, _, val)
        db.fpsInterval = val
        if stream then stream.interval = val end -- driver picks up new cadence
        -- Reset EMA so the new cadence takes immediate effect visually
        emaFPS = nil
        lastFps = nil
        scheduleUpdate()
    end)
    frame:AddChild(fpsRate)

    local smooth = AceGUI:Create("Slider")
    smooth:SetLabel(L["FPS smoothing window (s)"] or "FPS smoothing window (s)")
    smooth:SetSliderValues(0.00, 1.50, 0.05)
    smooth:SetValue(db.fpsSmoothWindow)
    smooth:SetCallback("OnValueChanged", function(_, _, val)
        db.fpsSmoothWindow = val
        -- Reset EMA for a fresh smoothing window
        emaFPS = nil
        lastFps = nil
        scheduleUpdate()
    end)
    frame:AddChild(smooth)

    local pingRate = AceGUI:Create("Slider")
    pingRate:SetLabel(L["Ping update interval (s)"] or "Ping update interval (s)")
    pingRate:SetSliderValues(0.50, 3.00, 0.25)
    pingRate:SetValue(db.pingInterval)
    pingRate:SetCallback("OnValueChanged", function(_, _, val)
        db.pingInterval = val
        scheduleUpdate()
    end)
    frame:AddChild(pingRate)

    local mode = AceGUI:Create("Dropdown")
    mode:SetLabel(L["Ping display"] or "Ping display")
    mode:SetList({ max = L["Max(home, world)"] or "Max(home, world)", split = L["home|world"] or "home|world" })
    mode:SetValue(db.pingMode)
    mode:SetCallback("OnValueChanged", function(_, _, key)
        db.pingMode = key or "max"
        -- Invalidate cache to force re-render even if values are equal
        lastMode = nil
        lastHome, lastWorld = nil, nil
        scheduleUpdate()
    end)
    frame:AddChild(mode)

    frame.frame:Show()
end

-- EMA-based smoothing (no tables, constant work per tick)
local function smoothFPS(current, interval, window)
    if (window or 0) <= 0 then
        emaFPS = current
        return current
    end
    local alpha = min(1, (interval or 0.25) / window)
    emaFPS = emaFPS and (emaFPS + alpha * (current - emaFPS)) or current
    return emaFPS
end

-- (declared above)

local function updateLatency(s)
    s = s or stream
    ensureDB()

    -- Keep the hub driver cadence in sync with the setting
    if s and s.interval ~= db.fpsInterval then s.interval = db.fpsInterval end

    local size = db.fontSize or 14
    s.snapshot.tooltip = getOptionsHint()

    local now = GetTime()

    -- FPS sampling + smoothing
    local fpsNow = GetFramerate() or 0
    local fpsAvg = smoothFPS(fpsNow, db.fpsInterval or 0.25, db.fpsSmoothWindow or 0)
    local fpsValue = floor(fpsAvg + 0.5)

    -- Ping sampling (gated)
    if (now - (lastPingUpdate or 0)) >= (db.pingInterval or 1.0) or not pingHome or not pingWorld then
        local _, _, home, world = GetNetStats()
        pingHome, pingWorld = home or 0, world or 0
        lastPingUpdate = now
    end

    if fpsValue ~= lastFps or (pingHome or 0) ~= (lastHome or -1) or (pingWorld or 0) ~= (lastWorld or -1) or db.pingMode ~= lastMode then
        local pingText
        if db.pingMode == "split" then
            local ph = pingHome or 0
            local pw = pingWorld or 0
            pingText = format("|cff%s%d|r| |cff%s%d|r ms", pingColorHex(ph), ph, pingColorHex(pw), pw)
        else
            local p = pingHome or 0
            if pingWorld and pingWorld > p then p = pingWorld end
            pingText = format("|cff%s%d|r ms", pingColorHex(p), p)
        end
        local text = format("FPS |cff%s%d|r | %s", fpsColorHex(fpsValue), fpsValue, pingText)
        s.snapshot.text = text
        lastFps, lastHome, lastWorld, lastMode = fpsValue, pingHome or 0, pingWorld or 0, db.pingMode
    end

    -- Only touch fontSize if actually changed
    if s.snapshot._fs ~= size then
        s.snapshot.fontSize = size
        s.snapshot._fs = size
    end
end

local provider = {
    id = "latency",
    version = 1,
    title = L["Latency"] or "Latency",
    poll = 0.25, -- default FPS cadence; kept in sync with db.fpsInterval at runtime
    update = updateLatency,
    OnClick = function(_, btn)
        if btn == "RightButton" then createAceWindow() end
    end,
    OnMouseEnter = function(btn)
        local tip = GameTooltip
        tip:ClearLines()
        tip:SetOwner(btn, "ANCHOR_TOPLEFT")

        local fps = floor((GetFramerate() or 0) + 0.5)
        local _, _, home, world = GetNetStats()
        home = home or 0
        world = world or 0

        -- Build FPS line using the global format, coloring only the value
        local fpsFmt = (MAINMENUBAR_FPS_LABEL or "Framerate: %.0f fps"):gsub("%%%.0f", "%%s")
        local fpsLine = fpsFmt:format(format("|cff%s%.0f|r", fpsColorHex(fps), fps))

        -- Build Latency block using the global format, coloring each value
        local latFmt = (MAINMENUBAR_LATENCY_LABEL or "Latency:\n%.0f ms (home)\n%.0f ms (world)")
        latFmt = latFmt:gsub("%%%.0f", "%%s")
        local latencyBlock = latFmt:format(
            format("|cff%s%.0f|r", pingColorHex(home), home),
            format("|cff%s%.0f|r", pingColorHex(world), world)
        )

        tip:SetText(fpsLine .. "\n" .. latencyBlock)
        local hint = getOptionsHint()
        if hint then
            tip:AddLine(" ")
            tip:AddLine(hint)
        end
        tip:Show()
    end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
