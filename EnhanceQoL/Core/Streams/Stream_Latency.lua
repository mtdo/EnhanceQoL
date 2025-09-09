-- luacheck: globals EnhanceQoL GetFramerate GetNetStats GAMEMENU_OPTIONS MAINMENUBAR_FPS_LABEL MAINMENUBAR_LATENCY_LABEL
local addonName, addon = ...
local L = addon.L

local AceGUI = addon.AceGUI
local db
local stream

-- Runtime state for smoothing and cadence
local fpsSamples = {} -- queue of { t = now, v = fps }
local lastPingUpdate = 0
local pingHome, pingWorld = nil, nil

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

    local fontSize = AceGUI:Create("Slider")
    fontSize:SetLabel("Font size")
    fontSize:SetSliderValues(8, 32, 1)
    fontSize:SetValue(db.fontSize)
    fontSize:SetCallback("OnValueChanged", function(_, _, val)
        db.fontSize = val
        addon.DataHub:RequestUpdate(stream)
    end)
    frame:AddChild(fontSize)

    local fpsRate = AceGUI:Create("Slider")
    fpsRate:SetLabel(L["FPS update interval (s)"] or "FPS update interval (s)")
    fpsRate:SetSliderValues(0.10, 1.00, 0.05)
    fpsRate:SetValue(db.fpsInterval)
    fpsRate:SetCallback("OnValueChanged", function(_, _, val)
        db.fpsInterval = val
        if stream then stream.interval = val end -- driver picks up new cadence
        addon.DataHub:RequestUpdate(stream)
    end)
    frame:AddChild(fpsRate)

    local smooth = AceGUI:Create("Slider")
    smooth:SetLabel(L["FPS smoothing window (s)"] or "FPS smoothing window (s)")
    smooth:SetSliderValues(0.00, 1.50, 0.05)
    smooth:SetValue(db.fpsSmoothWindow)
    smooth:SetCallback("OnValueChanged", function(_, _, val)
        db.fpsSmoothWindow = val
        addon.DataHub:RequestUpdate(stream)
    end)
    frame:AddChild(smooth)

    local pingRate = AceGUI:Create("Slider")
    pingRate:SetLabel(L["Ping update interval (s)"] or "Ping update interval (s)")
    pingRate:SetSliderValues(0.50, 3.00, 0.25)
    pingRate:SetValue(db.pingInterval)
    pingRate:SetCallback("OnValueChanged", function(_, _, val)
        db.pingInterval = val
        addon.DataHub:RequestUpdate(stream)
    end)
    frame:AddChild(pingRate)

    local mode = AceGUI:Create("Dropdown")
    mode:SetLabel(L["Ping display"] or "Ping display")
    mode:SetList({ max = L["Max(home, world)"] or "Max(home, world)", split = L["home|world"] or "home|world" })
    mode:SetValue(db.pingMode)
    mode:SetCallback("OnValueChanged", function(_, _, key)
        db.pingMode = key or "max"
        addon.DataHub:RequestUpdate(stream)
    end)
    frame:AddChild(mode)

    frame.frame:Show()
end

local function trimOldSamples(now, window)
    if window <= 0 then
        -- drop all previous samples when smoothing is disabled
        wipe(fpsSamples)
        return
    end
    local cutoff = now - window
    local i = 1
    while i <= #fpsSamples do
        if fpsSamples[i].t < cutoff then
            table.remove(fpsSamples, i)
        else
            break -- samples are appended in time order
        end
    end
end

local function averageFPS(now, window, current)
    if window <= 0 then return current end
    trimOldSamples(now, window)
    -- Include current sample too for a tighter feel
    local sum, n = current, 1
    for i = 1, #fpsSamples do
        sum = sum + fpsSamples[i].v
        n = n + 1
    end
    return sum / n
end

local lastText -- for cheap change detection in this provider before UI

local function updateLatency(s)
    s = s or stream
    ensureDB()

    -- Keep the hub driver cadence in sync with the setting
    if s and s.interval ~= db.fpsInterval then s.interval = db.fpsInterval end

    local size = db.fontSize or 14
    s.snapshot.fontSize = size
    if not s.snapshot.tooltip then s.snapshot.tooltip = L and L["Right-Click for options"] or "Right-Click for options" end

    local now = GetTime()

    -- FPS sampling + smoothing
    local fpsNow = GetFramerate() or 0
    fpsSamples[#fpsSamples + 1] = { t = now, v = fpsNow }
    local fpsAvg = averageFPS(now, db.fpsSmoothWindow or 0, fpsNow)
    local fpsValue = math.floor(fpsAvg + 0.5)

    -- Ping sampling (gated)
    if (now - (lastPingUpdate or 0)) >= (db.pingInterval or 1.0) or not pingHome or not pingWorld then
        local _, _, home, world = GetNetStats()
        pingHome, pingWorld = home or 0, world or 0
        lastPingUpdate = now
    end

    local pingText
    if db.pingMode == "split" then
        local ph = pingHome or 0
        local pw = pingWorld or 0
        pingText = string.format("|cff%s%d|r| |cff%s%d|r ms", pingColorHex(ph), ph, pingColorHex(pw), pw)
    else
        local p = pingHome or 0
        if pingWorld and pingWorld > p then p = pingWorld end
        pingText = string.format("|cff%s%d|r ms", pingColorHex(p), p)
    end

    local text = string.format("FPS |cff%s%d|r | %s", fpsColorHex(fpsValue), fpsValue, pingText)
    if text ~= lastText then
        s.snapshot.text = text
        lastText = text
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

        local fps = math.floor((GetFramerate() or 0) + 0.5)
        local _, _, home, world = GetNetStats()
        home = home or 0
        world = world or 0

        -- Build FPS line using the global format, coloring only the value
        local fpsFmt = (MAINMENUBAR_FPS_LABEL or "Framerate: %.0f fps"):gsub("%%%.0f", "%%s")
        local fpsLine = fpsFmt:format(string.format("|cff%s%.0f|r", fpsColorHex(fps), fps))

        -- Build Latency block using the global format, coloring each value
        local latFmt = (MAINMENUBAR_LATENCY_LABEL or "Latency:\n%.0f ms (home)\n%.0f ms (world)")
        latFmt = latFmt:gsub("%%%.0f", "%%s")
        local latencyBlock = latFmt:format(
            string.format("|cff%s%.0f|r", pingColorHex(home), home),
            string.format("|cff%s%.0f|r", pingColorHex(world), world)
        )

        tip:SetText(fpsLine .. "\n" .. latencyBlock)
        tip:AddLine(" ")
        tip:AddLine(L and L["Right-Click for options"] or "Right-Click for options")
        tip:Show()
    end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
