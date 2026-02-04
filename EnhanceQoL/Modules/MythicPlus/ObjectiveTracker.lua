local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.MythicPlus = addon.MythicPlus or {}
addon.MythicPlus.functions = addon.MythicPlus.functions or {}
addon.MythicPlus.variables = addon.MythicPlus.variables or {}

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_MythicPlus")

local frameLoad = CreateFrame("Frame")
local hiddenElements = {}
local alreadyHooked = {}

function addon.MythicPlus.functions.setObjectiveFrames()
	if IsInInstance() and select(3, GetInstanceInfo()) == 8 and addon.db["mythicPlusEnableObjectiveTracker"] then
		for i, v in pairs(addon.MythicPlus.variables.collapseFrames) do
			if not v.frame and v.name then v.frame = _G[v.name] end
			local frame = v.frame
			if addon.db["mythicPlusObjectiveTrackerSetting"] == 1 and frame then
				if frame:IsVisible() then
					frame:Hide()
					table.insert(hiddenElements, v)
				end
				if not alreadyHooked[frame] then
					frame:HookScript("OnShow", function(self)
						if IsInInstance() and select(3, GetInstanceInfo()) == 8 and addon.db["mythicPlusEnableObjectiveTracker"] and addon.db["mythicPlusObjectiveTrackerSetting"] == 1 then
							self:Hide()
						end
					end)
					alreadyHooked[frame] = true
				end
			elseif addon.db["mythicPlusObjectiveTrackerSetting"] == 2 and frame and frame.IsCollapsed and not frame:IsCollapsed() then
				if frame.SetCollapsed then
					frame:SetCollapsed(true)
				elseif frame.Header and frame.Header.MinimizeButton then
					frame.Header.MinimizeButton:Click()
				end
			end
		end
	elseif #hiddenElements > 0 then
		for i, v in pairs(hiddenElements) do
			if not v.frame and v.name then v.frame = _G[v.name] end
			local frame = v.frame
			if frame and not frame:IsVisible() then frame:Show() end
			if frame and frame.IsCollapsed and frame:IsCollapsed() then
				if frame.SetCollapsed then
					frame:SetCollapsed(false)
				elseif frame.Header and frame.Header.MinimizeButton then
					frame.Header.MinimizeButton:Click()
				end
			end
		end
		wipe(hiddenElements)
	end
end

local firstLoad = true
local eventHandlers = {
	["CHALLENGE_MODE_RESET"] = function() addon.MythicPlus.functions.setObjectiveFrames() end,
	["CHALLENGE_MODE_START"] = function() addon.MythicPlus.functions.setObjectiveFrames() end,
	["ZONE_CHANGED_NEW_AREA"] = function() addon.MythicPlus.functions.setObjectiveFrames() end,
	["PLAYER_ENTERING_WORLD"] = function()
		if firstLoad then
			firstLoad = false
			C_Timer.After(1, function()
				addon.MythicPlus.functions.setObjectiveFrames()
				frameLoad:UnregisterEvent("PLAYER_ENTERING_WORLD")
			end)
		end
	end,
}

local function registerEvents(frame)
	for event in pairs(eventHandlers) do
		frame:RegisterEvent(event)
	end
end
local function eventHandler(self, event, ...)
	if addon.db["mythicPlusEnableObjectiveTracker"] then
		if eventHandlers[event] then eventHandlers[event](...) end
	end
end

function addon.MythicPlus.functions.InitObjectiveTracker()
	if addon.MythicPlus.variables.objectiveTrackerInitialized then return end
	if not addon.db then return end
	addon.MythicPlus.variables.objectiveTrackerInitialized = true
	registerEvents(frameLoad)
	frameLoad:SetScript("OnEvent", eventHandler)
end
