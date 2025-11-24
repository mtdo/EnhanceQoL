local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local cUIInput = addon.functions.SettingsCreateCategory(nil, L["UIInput"], nil, "UIInput")
addon.SettingsLayout.uiInputCategory = cUIInput
local class, classname = UnitClass("player")
addon.functions.SettingsCreateHeadline(cUIInput, L["headerClassInfo"]:format(class))

local verticalScale = 11 / 17
local horizontalScale = 565 / 571

local function EQOL_UpdateStatusBars(container, height, width, scale)
	if not container then return end

	container:SetHeight(height)
	container:SetWidth(width)

	for _, child in pairs({ container:GetChildren() }) do
		if child and child.StatusBar then
			local point, relTo, relPoint, x, y = child:GetPoint()

			child:SetHeight(height)
			child:SetWidth(width)

			child.StatusBar:SetHeight(height * verticalScale)
			child.StatusBar:SetWidth(width * horizontalScale)

			child:ClearAllPoints()
			child:SetPoint(point, relTo, relPoint, -1 * scale * (width / 500) * 2, (3 / 20) * height)
		end
	end
	container:SetScale(scale)
end

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

addon.functions.SettingsCreateHeadline(cUIInput, L["XP_Rep"])

data = {
	{
		var = "modifyXPRepBar",
		text = L["modifyXPRepBar"],
		func = function(v)
			addon.db["modifyXPRepBar"] = v
			local height, width, scale = 17, 571, 1
			if v == true then
				if addon.db and addon.db.modifyXPRepBarHeight then height = addon.db and addon.db.modifyXPRepBarHeight end
				if addon.db and addon.db.modifyXPRepBarWidth then width = addon.db and addon.db.modifyXPRepBarWidth end
				if addon.db and addon.db.modifyXPRepBarScale then scale = addon.db and addon.db.modifyXPRepBarScale end
			end
			EQOL_UpdateStatusBars(MainStatusTrackingBarContainer, height, width, scale)
			EQOL_UpdateStatusBars(SecondaryStatusTrackingBarContainer, height, width, scale)
		end,
		children = {
			{
				var = "modifyXPRepBarWidth",
				text = HUD_EDIT_MODE_SETTING_CHAT_FRAME_WIDTH,
				get = function()
					local w = MainStatusTrackingBarContainer:GetSize()
					return addon.db and addon.db.modifyXPRepBarWidth or w
				end,
				set = function(v)
					addon.db["modifyXPRepBarWidth"] = v
					local _, height = MainStatusTrackingBarContainer:GetSize()
					local scale = MainStatusTrackingBarContainer:GetScale()
					EQOL_UpdateStatusBars(MainStatusTrackingBarContainer, height, v, scale)
					EQOL_UpdateStatusBars(SecondaryStatusTrackingBarContainer, height, v, scale)
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["modifyXPRepBar"]
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting:GetValue() == true
				end,
				min = 200,
				max = 800,
				step = 1,
				parent = true,
				default = 571,
				sType = "slider",
			},
			{
				var = "modifyXPRepBarHeight",
				text = HUD_EDIT_MODE_SETTING_CHAT_FRAME_HEIGHT,
				get = function()
					local _, h = MainStatusTrackingBarContainer:GetSize()
					return addon.db and addon.db.modifyXPRepBarHeight or h
				end,
				set = function(v)
					addon.db["modifyXPRepBarHeight"] = v
					local width = MainStatusTrackingBarContainer:GetSize()
					local scale = MainStatusTrackingBarContainer:GetScale()
					EQOL_UpdateStatusBars(MainStatusTrackingBarContainer, v, width, scale)
					EQOL_UpdateStatusBars(SecondaryStatusTrackingBarContainer, v, width, scale)
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["modifyXPRepBar"]
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting:GetValue() == true
				end,
				min = 10,
				max = 75,
				step = 1,
				parent = true,
				default = 17,
				sType = "slider",
			},
			{
				var = "modifyXPRepBarScale",
				text = RENDER_SCALE,
				get = function() return addon.db and addon.db.modifyXPRepBarScale or 1 end,
				set = function(v)
					addon.db["modifyXPRepBarScale"] = v
					local width, height = MainStatusTrackingBarContainer:GetSize()
					EQOL_UpdateStatusBars(MainStatusTrackingBarContainer, height, width, v)
					EQOL_UpdateStatusBars(SecondaryStatusTrackingBarContainer, height, width, v)
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["modifyXPRepBar"]
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting
						and addon.SettingsLayout.elements["modifyXPRepBar"].setting:GetValue() == true
				end,
				min = 0.5,
				max = 3,
				step = 0.05,
				parent = true,
				default = 1,
				sType = "slider",
			},
		},
	},
}
addon.functions.SettingsCreateCheckboxes(cUIInput, data)

----- REGION END

function addon.functions.initUIInput()
	if addon.db and addon.db.modifyXPRepBar then
		local height, width, scale = 571, 17, 1
		if addon.db and addon.db.modifyXPRepBarHeight then height = addon.db and addon.db.modifyXPRepBarHeight end
		if addon.db and addon.db.modifyXPRepBarWidth then width = addon.db and addon.db.modifyXPRepBarWidth end
		if addon.db and addon.db.modifyXPRepBarScale then scale = addon.db and addon.db.modifyXPRepBarScale end
		EQOL_UpdateStatusBars(MainStatusTrackingBarContainer, height, width, scale)
		EQOL_UpdateStatusBars(SecondaryStatusTrackingBarContainer, height, width, scale)
	end
end

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
