local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local cUIInput = addon.functions.SettingsCreateCategory(nil, L["UIInput"], nil, "UIInput")
addon.SettingsLayout.uiInputCategory = cUIInput
local class, classname = UnitClass("player")
addon.functions.SettingsCreateHeadline(cUIInput, L["headerClassInfo"]:format(class))

local data = {}

local function addTotemCheckbox(dbKey)
	table.insert(data, {
		var = dbKey,
		text = L["shaman_HideTotem"],
		func = function(value) addon.db[dbKey] = value end,
		get = function() return addon.db[dbKey] end,
	})
end
if classname == "DEATHKNIGHT" then
	table.insert(data, {
		var = "deathknight_HideRuneFrame",
		text = L["deathknight_HideRuneFrame"],
		func = function(value)
			addon.db["deathknight_HideRuneFrame"] = value
			if value then
				if RuneFrame then RuneFrame:Hide() end
			else
				if RuneFrame then RuneFrame:Show() end
			end
		end,
	})
	addTotemCheckbox("deathknight_HideTotemBar")
elseif classname == "DRUID" then
	addTotemCheckbox("druid_HideTotemBar")
	table.insert(data, {
		var = "druid_HideComboPoint",
		text = L["druid_HideComboPoint"],
		func = function(value)
			addon.db["druid_HideComboPoint"] = value
			if value then
				if DruidComboPointBarFrame then DruidComboPointBarFrame:Hide() end
			else
				if DruidComboPointBarFrame then DruidComboPointBarFrame:Show() end
			end
		end,
	})
elseif classname == "EVOKER" then
	table.insert(data, {
		var = "evoker_HideEssence",
		text = L["evoker_HideEssence"],
		func = function(value)
			addon.db["evoker_HideEssence"] = value
			if value then
				if EssencePlayerFrame then EssencePlayerFrame:Hide() end
			else
				if EssencePlayerFrame then EssencePlayerFrame:Show() end
			end
		end,
	})
elseif classname == "MAGE" then
	addTotemCheckbox("mage_HideTotemBar")
elseif classname == "MONK" then
	table.insert(data, {
		var = "monk_HideHarmonyBar",
		text = L["monk_HideHarmonyBar"],
		func = function(value)
			addon.db["monk_HideHarmonyBar"] = value
			if value then
				if MonkHarmonyBarFrame then MonkHarmonyBarFrame:Hide() end
			else
				if MonkHarmonyBarFrame then MonkHarmonyBarFrame:Show() end
			end
		end,
	})
	addTotemCheckbox("monk_HideTotemBar")
elseif classname == "PRIEST" then
	addTotemCheckbox("priest_HideTotemBar")
elseif classname == "SHAMAN" then
	addTotemCheckbox("shaman_HideTotem")
elseif classname == "ROGUE" then
	table.insert(data, {
		var = "rogue_HideComboPoint",
		text = L["rogue_HideComboPoint"],
		func = function(value)
			addon.db["rogue_HideComboPoint"] = value
			if value then
				if RogueComboPointBarFrame then RogueComboPointBarFrame:Hide() end
			else
				if RogueComboPointBarFrame then RogueComboPointBarFrame:Show() end
			end
		end,
	})
elseif classname == "PALADIN" then
	addTotemCheckbox("paladin_HideTotemBar")
	table.insert(data, {
		var = "paladin_HideHolyPower",
		text = L["paladin_HideHolyPower"],
		func = function(value)
			addon.db["paladin_HideHolyPower"] = value
			if value then
				if PaladinPowerBarFrame then PaladinPowerBarFrame:Hide() end
			else
				if PaladinPowerBarFrame then PaladinPowerBarFrame:Show() end
			end
		end,
	})
elseif classname == "WARLOCK" then
	table.insert(data, {
		var = "warlock_HideSoulShardBar",
		text = L["warlock_HideSoulShardBar"],
		func = function(value)
			addon.db["warlock_HideSoulShardBar"] = value
			if value then
				if WarlockPowerFrame then WarlockPowerFrame:Hide() end
			else
				if WarlockPowerFrame then WarlockPowerFrame:Show() end
			end
		end,
	})
	addTotemCheckbox("warlock_HideTotemBar")
end
table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cUIInput, data)

----- REGION END

function addon.functions.initUIInput() end

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
