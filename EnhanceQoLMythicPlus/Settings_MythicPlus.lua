local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_MythicPlus")
local LSM = LibStub("LibSharedMedia-3.0")

local cTeleports = addon.functions.SettingsCreateCategory(nil, L["Teleports"], nil, "Teleports")
addon.SettingsLayout.teleportsCategory = cTeleports

local data = {
	{
		var = "teleportFrame",
		text = L["teleportEnabled"],
		desc = L["teleportEnabledDesc"],
		func = function(v)
			addon.db["teleportFrame"] = v
			addon.MythicPlus.functions.toggleFrame()
		end,
	},
	{
		var = "teleportsWorldMapEnabled",
		text = L["teleportsWorldMapEnabled"],
		desc = L["teleportsWorldMapEnabledDesc"],
		func = function(v) addon.db["teleportsWorldMapEnabled"] = v end,
		children = {
			{
				text = "|cffffd700" .. L["teleportsWorldMapHelp"] .. "|r",
				sType = "hint",
			},
		},
	},
	{
		var = "teleportsWorldMapShowSeason",
		text = L["teleportsWorldMapShowSeason"],
		desc = L["teleportsWorldMapShowSeasonDesc"],
		func = function(v) addon.db["teleportsWorldMapShowSeason"] = v end,
	},
	{
		var = "portalHideMissing",
		text = L["portalHideMissing"],
		func = function(v) addon.db["portalHideMissing"] = v end,
	},
}
-- TODO bug in tooltip in midnight beta - remove for now
if not addon.variables.isMidnight then table.insert(data, {
	text = L["portalShowTooltip"],
	var = "portalShowTooltip",
	func = function(value) addon.db["portalShowTooltip"] = value end,
}) end
table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cTeleports, data)

-- Potion Tracker (Combat & Dungeon)
local cPotion = addon.SettingsLayout.characterInspectCategory
if cPotion then
	addon.functions.SettingsCreateHeadline(cPotion, L["Potion Tracker"])
	if L["potionTrackerMidnightWarning"] then addon.functions.SettingsCreateText(cPotion, L["potionTrackerMidnightWarning"]) end

	local potionEnable = addon.functions.SettingsCreateCheckbox(cPotion, {
		var = "potionTracker",
		text = L["potionTracker"],
		desc = L["potionTrackerHeadline"],
		func = function(v)
			addon.db["potionTracker"] = v
			if v then
				if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.updateBars then addon.MythicPlus.functions.updateBars() end
			else
				if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.resetCooldownBars then addon.MythicPlus.functions.resetCooldownBars() end
				if addon.MythicPlus and addon.MythicPlus.anchorFrame and addon.MythicPlus.anchorFrame.Hide then addon.MythicPlus.anchorFrame:Hide() end
			end
		end,
	})

	local function isPotionEnabled()
		return potionEnable and potionEnable.setting and potionEnable.setting:GetValue() == true
	end

	local potionOptions = {
		{
			var = "potionTrackerUpwardsBar",
			text = L["potionTrackerUpwardsBar"],
			func = function(v)
				addon.db["potionTrackerUpwardsBar"] = v
				if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.updateBars then addon.MythicPlus.functions.updateBars() end
			end,
		},
		{
			var = "potionTrackerClassColor",
			text = L["potionTrackerClassColor"],
			func = function(v) addon.db["potionTrackerClassColor"] = v end,
		},
		{
			var = "potionTrackerDisableRaid",
			text = L["potionTrackerDisableRaid"],
			func = function(v)
				addon.db["potionTrackerDisableRaid"] = v
				if v == true and UnitInRaid("player") and addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.resetCooldownBars then
					addon.MythicPlus.functions.resetCooldownBars()
				end
			end,
		},
		{
			var = "potionTrackerShowTooltip",
			text = L["potionTrackerShowTooltip"],
			func = function(v) addon.db["potionTrackerShowTooltip"] = v end,
		},
		{
			var = "potionTrackerHealingPotions",
			text = L["potionTrackerHealingPotions"],
			func = function(v) addon.db["potionTrackerHealingPotions"] = v end,
		},
		{
			var = "potionTrackerOffhealing",
			text = L["potionTrackerOffhealing"],
			func = function(v) addon.db["potionTrackerOffhealing"] = v end,
		},
	}

	for _, entry in ipairs(potionOptions) do
		entry.parent = true
		entry.element = potionEnable.element
		entry.parentCheck = isPotionEnabled
		addon.functions.SettingsCreateCheckbox(cPotion, entry)
	end

	local function buildPotionTextureOptions()
		local map = {
			["DEFAULT"] = DEFAULT,
			["Interface\\TargetingFrame\\UI-StatusBar"] = "Blizzard: UI-StatusBar",
			["Interface\\Buttons\\WHITE8x8"] = "Flat (white, tintable)",
			["Interface\\Tooltips\\UI-Tooltip-Background"] = "Dark Flat (Tooltip bg)",
		}
		for name, path in pairs(LSM and LSM:HashTable("statusbar") or {}) do
			if type(path) == "string" and path ~= "" then map[path] = tostring(name) end
		end
		local noDefault = {}
		for k, v in pairs(map) do
			if k ~= "DEFAULT" then noDefault[k] = v end
		end
		local sorted, order = addon.functions.prepareListForDropdown(noDefault)
		sorted["DEFAULT"] = DEFAULT
		table.insert(order, 1, "DEFAULT")
		sorted._order = order
		return sorted
	end

	addon.functions.SettingsCreateDropdown(cPotion, {
		var = "potionTrackerBarTexture",
		text = L["Bar Texture"],
		default = "DEFAULT",
		listFunc = buildPotionTextureOptions,
		get = function()
			local cur = addon.db["potionTrackerBarTexture"] or "DEFAULT"
			local list = buildPotionTextureOptions()
			if not list[cur] then cur = "DEFAULT" end
			return cur
		end,
		set = function(key)
			addon.db["potionTrackerBarTexture"] = key
			if addon.MythicPlus and addon.MythicPlus.functions and addon.MythicPlus.functions.applyPotionBarTexture then addon.MythicPlus.functions.applyPotionBarTexture() end
		end,
		parent = true,
		element = potionEnable.element,
		parentCheck = isPotionEnabled,
	})

	addon.functions.SettingsCreateButton(cPotion, {
		var = "potionTrackerAnchor",
		text = L["Toggle Anchor"],
		func = function()
			local anchor = addon.MythicPlus and addon.MythicPlus.anchorFrame
			if not anchor then return end
			if anchor:IsShown() then
				anchor:Hide()
			else
				anchor:Show()
			end
		end,
		parent = true,
		element = potionEnable.element,
		parentCheck = isPotionEnabled,
	})
end

----- REGION END

function addon.functions.initTeleports() end

local eventHandlers = {}

local function registerEvents(frame)
	for event in pairs(eventHandlers) do
		frame:RegisterEvent(event)
	end
end

local function eventHandler(self, event, ...)
	if eventHandlers[event] then eventHandlers[event](...) end
end

local frameLoad = CreateFrame("Frame")

registerEvents(frameLoad)
frameLoad:SetScript("OnEvent", eventHandler)
