-- Store the original Blizzard SetupMenu generator for rewrapping
local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

addon.tempScrollPos = 0 -- holds last scroll offset for Essential list

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local AceGUI = addon.AceGUI

local resourceBarsLoaded = false
local function LoadResourceBars()
        if not resourceBarsLoaded then
                addon.Aura.ResourceBars =
                        dofile("Interface/AddOns/" .. addonName .. "/ResourceBars.lua")
                resourceBarsLoaded = true
        end
end

local function addResourceFrame(container)
	local wrapper = addon.functions.createContainer("SimpleGroup", "Flow")
	container:AddChild(wrapper)

	local groupCore = addon.functions.createContainer("InlineGroup", "List")
	wrapper:AddChild(groupCore)

	local data = {
                {
                        text = "Enable Resource frame",
                        var = "enableResourceFrame",
                        func = function(self, _, value)
                                addon.db["enableResourceFrame"] = value
                                if value then
                                        LoadResourceBars()
                                        addon.Aura.ResourceBars.EnableResourceBars()
                                elseif addon.Aura.ResourceBars and addon.Aura.ResourceBars.DisableResourceBars then
                                        addon.Aura.ResourceBars.DisableResourceBars()
                                end
                        end,
                },
	}

	table.sort(data, function(a, b) return a.text < b.text end)

	for _, cbData in ipairs(data) do
		local uFunc = function(self, _, value) addon.db[cbData.var] = value end
		if cbData.func then uFunc = cbData.func end
		local cbElement = addon.functions.createCheckboxAce(cbData.text, addon.db[cbData.var], uFunc)
		groupCore:AddChild(cbElement)
	end

	if addon.db["enableResourceFrame"] then
		local data = {
			{
				text = "Healthbar Width",
				var = "personalResourceBarHealthWidth",
                                func = function(self, _, value)
                                        addon.db["personalResourceBarHealthWidth"] = value
                                        if addon.Aura.ResourceBars and addon.Aura.ResourceBars.SetHealthBarSize then
                                                addon.Aura.ResourceBars.SetHealthBarSize(addon.db["personalResourceBarHealthWidth"], addon.db["personalResourceBarHealthHeight"])
                                        end
                                end,
				min = 1,
				max = 2000,
			},
			{
				text = "Healthbar Height",
				var = "personalResourceBarHealthHeight",
                                func = function(self, _, value)
                                        addon.db["personalResourceBarHealthHeight"] = value
                                        if addon.Aura.ResourceBars and addon.Aura.ResourceBars.SetHealthBarSize then
                                                addon.Aura.ResourceBars.SetHealthBarSize(addon.db["personalResourceBarHealthWidth"], addon.db["personalResourceBarHealthHeight"])
                                        end
                                end,
				min = 1,
				max = 2000,
			},
			{
				text = "Manabar Width",
				var = "personalResourceBarManaWidth",
                                func = function(self, _, value)
                                        addon.db["personalResourceBarManaWidth"] = value
                                        if addon.Aura.ResourceBars and addon.Aura.ResourceBars.SetPowerBarSize then
                                                addon.Aura.ResourceBars.SetPowerBarSize(addon.db["personalResourceBarManaWidth"], addon.db["personalResourceBarManaHeight"])
                                        end
                                end,
				min = 1,
				max = 2000,
			},
			{
				text = "Manabar Height",
				var = "personalResourceBarManaHeight",
                                func = function(self, _, value)
                                        addon.db["personalResourceBarManaHeight"] = value
                                        if addon.Aura.ResourceBars and addon.Aura.ResourceBars.SetPowerBarSize then
                                                addon.Aura.ResourceBars.SetPowerBarSize(addon.db["personalResourceBarManaWidth"], addon.db["personalResourceBarManaHeight"])
                                        end
                                end,
				min = 1,
				max = 100,
			},
		}

		for _, cbData in ipairs(data) do
			local uFunc = function(self, _, value) addon.db[cbData.var] = value end
			if cbData.func then uFunc = cbData.func end

			local healthBarWidth = addon.functions.createSliderAce(cbData.text, addon.db[cbData.var], cbData.min, cbData.max, 1, uFunc)
			healthBarWidth:SetFullWidth(true)
			groupCore:AddChild(healthBarWidth)

			groupCore:AddChild(addon.functions.createSpacerAce())
		end
	end
end

addon.variables.statusTable.groups["aura"] = true

addon.functions.addToTree(nil, {
	value = "aura",
	text = L["Aura"],
	children = {
		{ value = "resourcebar", text = DISPLAY_PERSONAL_RESOURCE },
		{ value = "bufftracker", text = L["BuffTracker"] },
	},
})

function addon.Aura.functions.treeCallback(container, group)
        container:ReleaseChildren()
        if group == "aura\001resourcebar" then
                addResourceFrame(container)
        elseif group == "aura\001bufftracker" then
                addon.Aura.functions.addBuffTrackerOptions(container)
                addon.Aura.scanBuffs()
        end
end

if addon.db["enableResourceFrame"] then
        LoadResourceBars()
        addon.Aura.ResourceBars.EnableResourceBars()
end
