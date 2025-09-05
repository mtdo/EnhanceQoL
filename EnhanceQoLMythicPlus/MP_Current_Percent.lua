local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_MythicPlus")

-- Ultra‑lightweight tracker for current pull percent in M+.
-- Design goals:
--  - Zero cost when MDT is not loaded or when not in/entering an M+ run
--  - Conditional event registration (add/remove COMBAT_LOG only while active)
--  - Early exits in hot paths (e.g., CL events) and GUID de‑duplication

local MPlus = {}
MPlus.active = false
MPlus.weights = {} -- [npcId] = forcesCount (or weight)
MPlus.inPullGUID = {} -- map: [guid] = npcId (or true before cache fill)
MPlus.inPullByNPC = {} -- [npcId] = { guids = set, _count = int }
MPlus.pullForces = 0 -- absolute forces for current pull
MPlus.maxForces = 0 -- from MDT objective cap
MPlus.uiThrottle = 0
MPlus._weightsReady = false
MPlus._nextWeightsAttemptTime = 0
addon.MPlusData = MPlus

-- forward declarations for locals referenced earlier
local EnsureUILabel
local UpdateUILabel
local RecomputePullForces

-- Localize frequently used globals for hot paths
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local tonumber = tonumber
local strsplit = strsplit
local GetTime = GetTime
local max = math.max
local wipe, pairs, select = wipe, pairs, select
local GetScenarioStepInfo = C_ScenarioInfo.GetScenarioStepInfo
local GetCriteriaInfo = C_ScenarioInfo.GetCriteriaInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local function NPCIDFromGUID(guid)
	-- guid: Creature-0-*-*-*-<npcId>-*
	local id = guid and select(6, strsplit("-", guid))
	return id and tonumber(id)
end

-- MDT Integration (built once per run/preset)
local function BuildWeightsFromMDT()
	wipe(MPlus.weights)
	if not MDT then return end
	-- Guard against MDT not fully initialized yet (e.g., db is nil)
	local okPreset, preset = pcall(function() return MDT.GetCurrentPreset and MDT:GetCurrentPreset() end)
	if not okPreset or not preset then return end
	local okIsTeeming, isTeeming = pcall(function() return MDT.IsPresetTeeming and MDT:IsPresetTeeming(preset) end)
	isTeeming = okIsTeeming and isTeeming or false

	local sData = GetScenarioStepInfo()
	if not sData or not sData.numCriteria then return end

	for criteriaIndex = 1, sData.numCriteria do
		local criteriaInfo = GetCriteriaInfo(criteriaIndex)
		if criteriaInfo and criteriaInfo.isWeightedProgress and criteriaInfo.totalQuantity then MPlus.maxForces = criteriaInfo.totalQuantity end
	end

	if MPlus.maxForces and MPlus.maxForces > 0 then
		local mapID = GetBestMapForUnit("player")
		local mdtID = MDT.zoneIdToDungeonIdx[mapID]

		local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[mdtID]
		if type(enemies) == "table" then
			for _, entry in pairs(enemies) do
				if entry.id and entry.count then MPlus.weights[entry.id] = entry.count * 100 / MPlus.maxForces end
			end
		end
		-- mark weights as ready and recompute current pull once
		MPlus._weightsReady = next(MPlus.weights) ~= nil
		RecomputePullForces()
	end
end

local function ResetPull()
	wipe(MPlus.inPullGUID)
	wipe(MPlus.inPullByNPC)
	MPlus.pullForces = 0
	MPlus._lastActivity = GetTime()
	if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
end

-- Full recompute: used when weights change
function RecomputePullForces()
	local sum = 0
	for npcId, data in pairs(MPlus.inPullByNPC) do
		local perMob = MPlus.weights[npcId]
		if perMob and data.guids then sum = sum + perMob * (data._count or 0) end
	end
	MPlus.pullForces = sum
	if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
end

local function AddGUIDToPull(guid)
	if MPlus.inPullGUID[guid] then return end -- already accounted
	local npcId = NPCIDFromGUID(guid)
	if not npcId then return end
	local perMob = MPlus.weights[npcId]
	if not perMob then return end -- ignorieren (kein Forces-Eintrag, Minion o.ä.)

	-- cache npcId per GUID to avoid reparsing on remove
	MPlus.inPullGUID[guid] = npcId
	local b = MPlus.inPullByNPC[npcId]
	if not b then
		b = { guids = {}, _count = 0 }
		MPlus.inPullByNPC[npcId] = b
	end
	b.guids[guid] = true
	b._count = b._count + 1
	-- Incremental update
	MPlus.pullForces = MPlus.pullForces + perMob
	MPlus._lastActivity = GetTime()
	if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
end

local function RemoveGUIDFromPull(guid)
	local cachedNpc = MPlus.inPullGUID[guid]
	if not cachedNpc then return end
	local npcId = type(cachedNpc) == "number" and cachedNpc or NPCIDFromGUID(guid)
	local b = npcId and MPlus.inPullByNPC[npcId]
	if b and b.guids[guid] then
		b.guids[guid] = nil
		b._count = max(0, (b._count or 1) - 1)
		if b._count == 0 then MPlus.inPullByNPC[npcId] = nil end
		-- Decremental update
		local perMob = MPlus.weights[npcId]
		if perMob then MPlus.pullForces = max(0, MPlus.pullForces - perMob) end
		MPlus._lastActivity = GetTime()
		if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
	end
	-- remove cache entry after using it
	MPlus.inPullGUID[guid] = nil
end

-- === Removed standalone UI label; keep stubs to safely hide any leftover frame ===
function EnsureUILabel() end
function UpdateUILabel()
	if MPlus.uiFrame then
		MPlus.uiFrame:Hide()
		MPlus.uiFrame = nil
	end
	if _G["EnhanceQoL_CurrentPullLabel"] then _G["EnhanceQoL_CurrentPullLabel"]:Hide() end
end

-- === Events ===
local f = CreateFrame("Frame")

-- localize bit ops and masks for hot path
local band = bit.band
local MASK_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local MASK_NPC = COMBATLOG_OBJECT_TYPE_NPC
local function isHostileNPC(flags) return band(flags or 0, MASK_HOSTILE) ~= 0 and band(flags or 0, MASK_NPC) ~= 0 end

-- Track whether the player (or pet) is involved in a CLEU event
local MASK_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local function isMineInvolved(srcFlags, dstFlags) return band(srcFlags or 0, MASK_MINE) ~= 0 or band(dstFlags or 0, MASK_MINE) ~= 0 end

-- While out of combat, accept only clear combat actions to avoid OOC noise
local allowedSubOOC = {
	SWING_DAMAGE = true,
	RANGE_DAMAGE = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
}

local allowedSub = {
	SWING_DAMAGE = true,
	RANGE_DAMAGE = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	SPELL_CAST_START = true,
	SPELL_CAST_SUCCESS = true,
	UNIT_DIED = true,
	UNIT_DESTROYED = true,
	UNIT_DISSIPATES = true,
}

local function SetCombatLogActive(active)
	if active then
		f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:RegisterEvent("PLAYER_DEAD")
		f:RegisterEvent("PLAYER_UNGHOST")
	else
		f:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		f:UnregisterEvent("PLAYER_REGEN_ENABLED")
		f:UnregisterEvent("PLAYER_DEAD")
		f:UnregisterEvent("PLAYER_UNGHOST")
	end
end

local function IsInKeystoneRun()
	local inInstance, _ = IsInInstance()
	if not inInstance then return false end
	local difficultyID = select(3, GetInstanceInfo())
	return difficultyID == 8 -- Mythic Keystone
end

local function ActivateRun()
	if MPlus.active then return end
	MPlus.active = true
	ResetPull()
	MPlus._weightsReady = false
	MPlus._nextWeightsAttemptTime = 0
	BuildWeightsFromMDT()
	SetCombatLogActive(true)
	UpdateUILabel()
	-- Start watchdog ticker to clean up edge cases when out of combat
	if not MPlus._watchdogTicker then
		MPlus._watchdogTicker = C_Timer.NewTicker(0.5, function()
			if not MPlus.active then return end
			if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
			if (MPlus.pullForces or 0) <= 0 then return end
			local engaged = UnitAffectingCombat("player") and not UnitIsDeadOrGhost("player")
			if engaged then return end
			local last = MPlus._lastActivity or 0
			if GetTime() - last > 1.5 then ResetPull() end
		end)
	end
end

local function DeactivateRun()
	if not MPlus.active then return end
	MPlus.active = false
	ResetPull()
	SetCombatLogActive(false)
	MPlus._weightsReady = false
	UpdateUILabel()
	if MPlus._watchdogTicker then
		MPlus._watchdogTicker:Cancel()
		MPlus._watchdogTicker = nil
	end
end

local baseEventsRegistered = false
local mdtInitDone = false
local function EnsureBaseEvents()
	if baseEventsRegistered then return end
	f:RegisterEvent("CHALLENGE_MODE_START")
	f:RegisterEvent("CHALLENGE_MODE_RESET")
	f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
	f:RegisterEvent("ENCOUNTER_END")
	-- PLAYER_ENTERING_WORLD wird initial ohnehin registriert (s. unten)
	baseEventsRegistered = true
end

local function OnMDTReady()
	EnsureBaseEvents()
	-- Falls wir schon in einer aktiven Instanz sind, M+ ggf. sofort aktivieren/deaktivieren
	if IsInKeystoneRun() then
		ActivateRun()
	else
		DeactivateRun()
	end
end

f:SetScript("OnEvent", function(_, ev, arg1)
	-- Feature must be enabled explicitly in settings
	if not (addon and addon.db and addon.db["mythicPlusCurrentPull"]) then return end
	if ev == "ADDON_LOADED" then
		-- Lazy detect MDT when it loads after us
		if not MDT and _G.MDT then MDT = _G.MDT end
		if MDT and not mdtInitDone then
			mdtInitDone = true
			OnMDTReady()
		end
		return
	end

	if ev == "CHALLENGE_MODE_START" then
		if not MDT and _G.MDT then MDT = _G.MDT end
		if MDT then ActivateRun() end
		return
	end

	if ev == "CHALLENGE_MODE_RESET" or ev == "CHALLENGE_MODE_COMPLETED" then
		if not MDT and _G.MDT then MDT = _G.MDT end
		if MDT then DeactivateRun() end
		return
	end

	if ev == "ENCOUNTER_END" then
		if MDT and MPlus.active then ResetPull() end
		return
	end

	if ev == "PLAYER_ENTERING_WORLD" then
		-- Only a single initial pass per session. PEW fires on every loading screen.
		if mdtInitDone then return end
		-- Last-chance init: check for MDT once here at startup
		if not MDT and _G.MDT then MDT = _G.MDT end
		if MDT then
			mdtInitDone = true
			OnMDTReady()
		end
		return
	end

	if ev == "COMBAT_LOG_EVENT_UNFILTERED" then
		if not MDT or not MPlus.active then return end
		-- Late MDT init guard: try again with backoff if weights not ready
		if not MPlus._weightsReady then
			local now = GetTime()
			if now >= (MPlus._nextWeightsAttemptTime or 0) then
				BuildWeightsFromMDT()
				MPlus._nextWeightsAttemptTime = now + 0.75
			end
			if not MPlus._weightsReady then return end
		end
		local _, sub, _, srcGUID, _, srcFlags, _, dstGUID, _, dstFlags = CombatLogGetCurrentEventInfo()
		if not allowedSub[sub] then return end

		-- Prevent updates while dead or OOC due to party combat.
		-- Consider the player "engaged" only when alive and in combat.
		local engaged = UnitAffectingCombat("player") and not UnitIsDeadOrGhost("player")
		if not engaged then
			-- Only accept clear, personal damage events out of combat.
			if not isMineInvolved(srcFlags, dstFlags) then return end
			if not allowedSubOOC[sub] then return end
		end

		-- Source
		if srcGUID and not MPlus.inPullGUID[srcGUID] and isHostileNPC(srcFlags) then
			if addon and addon.debug then print("Added", "source") end
			AddGUIDToPull(srcGUID)
		end
		-- Destination
		if dstGUID and isHostileNPC(dstFlags) then
			if not MPlus.inPullGUID[dstGUID] then AddGUIDToPull(dstGUID) end
			if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" or sub == "UNIT_DISSIPATES" then RemoveGUIDFromPull(dstGUID) end
		end
		return
	end

	if ev == "PLAYER_REGEN_ENABLED" then
		if not MDT or not MPlus.active then return end
		-- Reset current pull when leaving combat (player side)
		ResetPull()
		return
	end

	if ev == "PLAYER_DEAD" then
		if not MDT or not MPlus.active then return end
		-- Hard reset on death to avoid stuck/continuing updates while dead
		ResetPull()
		return
	end

	if ev == "PLAYER_UNGHOST" then
		if not MDT or not MPlus.active then return end
		-- Keep UI consistent at 0 after releasing
		if addon and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.RefreshProgressLabel then addon.MythicPlus.functions.RefreshProgressLabel() end
		return
	end
end)

-- Toggle registration from the MythicPlus UI
addon.MythicPlus = addon.MythicPlus or {}
addon.MythicPlus.functions = addon.MythicPlus.functions or {}
function addon.MythicPlus.functions.ToggleCurrentPull(enabled)
	if enabled then
		f:RegisterEvent("ADDON_LOADED")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		-- If MDT is around already, initialize immediately
		if _G.MDT and not MDT then MDT = _G.MDT end
		if MDT and not mdtInitDone then
			mdtInitDone = true
			OnMDTReady()
		end
	else
		f:UnregisterEvent("ADDON_LOADED")
		f:UnregisterEvent("PLAYER_ENTERING_WORLD")
		f:UnregisterEvent("CHALLENGE_MODE_START")
		f:UnregisterEvent("CHALLENGE_MODE_RESET")
		f:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
		f:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		DeactivateRun()
		baseEventsRegistered = false
	end
end

-- Apply initial state based on saved setting
-- live‑update helper exposed for UI sliders
addon.MythicPlus.functions.UpdateCurrentPullAppearance = function() UpdateUILabel() end

if addon and addon.db and addon.db["mythicPlusCurrentPull"] then addon.MythicPlus.functions.ToggleCurrentPull(true) end
