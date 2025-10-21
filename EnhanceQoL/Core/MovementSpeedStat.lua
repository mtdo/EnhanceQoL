local addonName, addon = ...

local GetTime = GetTime
local C_Timer = C_Timer

addon.MovementSpeedStat = addon.MovementSpeedStat or {}
local mod = addon.MovementSpeedStat

local MOVEMENT_STAT_KEY = "EQOL_MOVEMENT_SPEED"
local CATEGORY_ID = "ENHANCEMENTS"
local BASE_MS = _G.BASE_MOVEMENT_SPEED or 7
local MOVEMENT_STAT_ENTRY = {
	stat = MOVEMENT_STAT_KEY,
	hideAt = 0,
}
local MOVING_TICK = 0.5
local IDLE_TICK = 1.5
local FLYING_TICK = 1.5
local MOVEMENT_THRESHOLD_YPS = 1
local FLYING_SPEED_GATE = BASE_MS * 2.5
local CACHE_EPSILON_PCT = 1
local CACHE_EPSILON_YPS = 0.2
local FLYING_EPSILON_PCT_MULT = 5.0
local FLYING_EPSILON_YPS_MULT = 5.0

local cache = { yps = BASE_MS, pct = 100, pctText = nil, tooltipYPS = nil, tooltipStamp = 0 }
local tickInterval = MOVING_TICK
local active = false
local installed = false
local statFrameRef
local TOOLTIP_MIN_INTERVAL = 2
local tickerActive = false
local tickerSequence = 0

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

local function CharacterUIReady() return type(PAPERDOLL_STATINFO) == "table" and type(PAPERDOLL_STATCATEGORIES) == "table" end

local function GetStatCategory()
	if not CharacterUIReady() then return nil end

	for _, category in ipairs(PAPERDOLL_STATCATEGORIES) do
		if category.categoryFrame == "EnhancementsCategory" or category.id == CATEGORY_ID then return category end
	end
end

local function StatEntryMatches(entry)
	if type(entry) == "table" then return entry.stat == MOVEMENT_STAT_KEY end
	return entry == MOVEMENT_STAT_KEY
end

local function EnsureCategoryReady()
	local category = GetStatCategory()
	if category and category.stats then return category end

	if PaperDoll_InitStatCategories then PaperDoll_InitStatCategories(PAPERDOLL_STATCATEGORY_DEFAULTORDER, "statCategoryOrder", "statCategoriesCollapsed", "player") end

	return GetStatCategory()
end

local function AddStatToCategory()
	local category = EnsureCategoryReady()
	if not category or not category.stats then return false end

	for _, entry in ipairs(category.stats) do
		if StatEntryMatches(entry) then
			installed = true
			return false
		end
	end

	table.insert(category.stats, MOVEMENT_STAT_ENTRY)
	installed = true
	return true
end

local function RemoveStatFromCategory()
	local category = GetStatCategory()
	if not category or not category.stats then return end

	for index = #category.stats, 1, -1 do
		if StatEntryMatches(category.stats[index]) then table.remove(category.stats, index) end
	end

	installed = false
	statFrameRef = nil
end

local function RebuildPaperDoll()
	if not CharacterUIReady() then return end

	if PaperDoll_InitStatCategories then PaperDoll_InitStatCategories(PAPERDOLL_STATCATEGORY_DEFAULTORDER, "statCategoryOrder", "statCategoriesCollapsed", "player") end

	if PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
end

local function Compute(unit)
	unit = unit or "player"

	if unit == "player" and UnitInVehicle("player") then unit = "vehicle" end
	local isVehicle = unit == "vehicle"

	local rawSpeed, runSpeed = GetUnitSpeed(unit)
	rawSpeed = rawSpeed or 0
	runSpeed = runSpeed or 0
	local speed = rawSpeed

	if speed < runSpeed then speed = runSpeed end

	if not isVehicle and C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local advanced, _, glideSpeed = C_PlayerInfo.GetGlidingInfo()
		if advanced and glideSpeed then
			if glideSpeed > speed then speed = glideSpeed end
			if glideSpeed > rawSpeed then rawSpeed = glideSpeed end
		end
	end

	if speed <= 0 then
		if runSpeed > 0 then
			speed = runSpeed
		else
			speed = BASE_MS
		end
	end

	local pct = (speed / BASE_MS) * 100
	return speed, pct, rawSpeed, isVehicle
end

local function PercentText(p) return string.format("%.0f", p) end

local function ApplyDisplay(yps, pct, tooltipEps)
	cache.yps = yps
	cache.pct = pct
	tooltipEps = tooltipEps or CACHE_EPSILON_YPS

	if not statFrameRef then return end

	local pctText = PercentText(pct)
	local needsLabel = cache.pctText ~= pctText
	local needsTooltip = not cache.tooltipYPS or math.abs(yps - cache.tooltipYPS) > tooltipEps
	if statFrameRef.numericValue ~= pct then statFrameRef.numericValue = pct end

	if not needsLabel and not needsTooltip then
		if not statFrameRef:IsShown() then statFrameRef:Show() end
		return
	end

	if needsLabel then
		PaperDollFrame_SetLabelAndText(statFrameRef, STAT_MOVEMENT_SPEED, pctText, true, pct)
		cache.pctText = pctText
	end

	if needsTooltip then
		local now = GetTime()
		local tooltipOwner = GameTooltip and statFrameRef and GameTooltip:IsOwned(statFrameRef)
		local canUpdateTooltip = (now - cache.tooltipStamp >= TOOLTIP_MIN_INTERVAL) or tooltipOwner or cache.tooltipYPS == nil
		if canUpdateTooltip then
			statFrameRef.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. STAT_MOVEMENT_SPEED .. FONT_COLOR_CODE_CLOSE
			statFrameRef.tooltip2 = string.format("~%.2f yards/sec", yps)
			cache.tooltipYPS = yps
			cache.tooltipStamp = now
		end
	end

	if not statFrameRef:IsShown() then statFrameRef:Show() end
end

local function StatUpdate(statFrame, unit)
	statFrameRef = statFrame

	if not addon.db or not addon.db.movementSpeedStatEnabled then
		statFrame:Hide()
		return
	end

	unit = unit or "player"

	local yps, pct = Compute(unit)
	ApplyDisplay(yps, pct, CACHE_EPSILON_YPS)
end

local function EnsureStatInfo()
	if not CharacterUIReady() then return end
	if PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] then return end

	PAPERDOLL_STATINFO[MOVEMENT_STAT_KEY] = {
		category = CATEGORY_ID,
		updateFunc = StatUpdate,
	}
end

local function ScheduleTick(delay, seq)
	C_Timer.After(delay, function()
		if not tickerActive or seq ~= tickerSequence then return end

		local yps, pct, raw, inVehicle = Compute("player")
		local flyingLike = inVehicle or raw > FLYING_SPEED_GATE
		local moving = raw > MOVEMENT_THRESHOLD_YPS
		local desiredInterval = flyingLike and FLYING_TICK or (moving and MOVING_TICK or IDLE_TICK)
		tickInterval = desiredInterval

		local epsPct = flyingLike and (CACHE_EPSILON_PCT * FLYING_EPSILON_PCT_MULT) or CACHE_EPSILON_PCT
		local epsYps = flyingLike and (CACHE_EPSILON_YPS * FLYING_EPSILON_YPS_MULT) or CACHE_EPSILON_YPS

		if math.abs(pct - cache.pct) > epsPct or math.abs(yps - cache.yps) > epsYps then
			ApplyDisplay(yps, pct, epsYps)
		else
			cache.yps = yps
			cache.pct = pct
		end

		ScheduleTick(math.max(tickInterval, 0.25), seq)
	end)
end

local function StartTicker()
	if tickerActive or not active then return end
	tickerActive = true
	tickInterval = MOVING_TICK
	tickerSequence = tickerSequence + 1
	local seq = tickerSequence
	ScheduleTick(tickInterval, seq)
end

local function StopTicker()
	if not tickerActive then return end
	tickerActive = false
	tickerSequence = tickerSequence + 1
	tickInterval = MOVING_TICK
end

local function HookCharacterFrame()
	if mod._hookedCharacterFrame or not CharacterFrame then return end

	CharacterFrame:HookScript("OnShow", function()
		if active then
			if not statFrameRef and PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
			StartTicker()
			if statFrameRef then
				local yps, pct = Compute("player")
				ApplyDisplay(yps, pct, CACHE_EPSILON_YPS)
			end
		end
	end)

	CharacterFrame:HookScript("OnHide", function() StopTicker() end)

	mod._hookedCharacterFrame = true

	if CharacterFrame:IsShown() then StartTicker() end
end

local function TryInstall()
	if not active then return end

	if not CharacterUIReady() then return end

	EnsureStatInfo()
	local added = AddStatToCategory()
	HookCharacterFrame()

	if added then RebuildPaperDoll() end

	if CharacterFrame and CharacterFrame:IsShown() then
		if not statFrameRef and PaperDollFrame_UpdateStats then PaperDollFrame_UpdateStats() end
		StartTicker()
		if statFrameRef then
			local yps, pct = Compute("player")
			ApplyDisplay(yps, pct, CACHE_EPSILON_YPS)
		end
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == "Blizzard_CharacterUI" or name == "Blizzard_UIPanels_Game" then TryInstall() end
	elseif event == "PLAYER_LOGIN" then
		TryInstall()
	end
end)

function mod.Enable()
	if active then return end
	active = true
	tickInterval = MOVING_TICK
	cache.yps, cache.pct = Compute("player")
	TryInstall()
end

function mod.Disable()
	if not active then return end
	active = false
	StopTicker()

	if installed then
		RemoveStatFromCategory()
		RebuildPaperDoll()
	end

	statFrameRef = nil
	cache.pctText = nil
	cache.tooltipYPS = nil
	cache.tooltipStamp = 0
end

function mod.Refresh()
	if not addon.db then return end
	if addon.db.movementSpeedStatEnabled then
		mod.Enable()
	else
		mod.Disable()
	end
end
