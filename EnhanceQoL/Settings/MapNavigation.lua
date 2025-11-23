local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local cMapNav = addon.functions.SettingsCreateCategory(nil, L["MapNavigation"], nil, "MapNavigation")
addon.SettingsLayout.mapNavigationCategory = cMapNav

addon.functions.SettingsCreateHeadline(cMapNav, MINIMAP_LABEL)

local data = {
	{
		var = "enableWayCommand",
		text = L["enableWayCommand"],
		desc = L["enableWayCommandDesc"],
		func = function(key) addon.db["enableWayCommand"] = key end,
		default = false,
	},
	{
		var = "enableSquareMinimap",
		text = L["SquareMinimap"],
		desc = L["enableSquareMinimapDesc"],
		func = function(key) addon.db["enableSquareMinimap"] = key end,
		default = false,
		children = {
			{
				var = "enableSquareMinimapBorder",
				text = L["enableSquareMinimapBorder"],
				desc = L["enableSquareMinimapBorderDesc"],
				func = function(key) addon.db["enableSquareMinimapBorder"] = key end,
				default = false,
				sType = "checkbox",
				parentCheck = function()
					return addon.SettingsLayout.elements["enableSquareMinimap"]
						and addon.SettingsLayout.elements["enableSquareMinimap"].setting
						and addon.SettingsLayout.elements["enableSquareMinimap"].setting:GetValue() == true
				end,
				parent = true,
			},
			{
				var = "squareMinimapBorderSize",
				text = L["squareMinimapBorderSize"],
				parentCheck = function()
					return addon.SettingsLayout.elements["enableSquareMinimapBorder"]
						and addon.SettingsLayout.elements["enableSquareMinimapBorder"].setting
						and addon.SettingsLayout.elements["enableSquareMinimapBorder"].setting:GetValue() == true
						and addon.SettingsLayout.elements["enableSquareMinimap"]
						and addon.SettingsLayout.elements["enableSquareMinimap"].setting
						and addon.SettingsLayout.elements["enableSquareMinimap"].setting:GetValue() == true
				end,
				get = function() return addon.db and addon.db.squareMinimapBorderSize or 1 end,
				set = function(value)
					addon.db["squareMinimapBorderSize"] = value
					if addon.functions.applySquareMinimapBorder then addon.functions.applySquareMinimapBorder() end
				end,
				min = 1,
				max = 8,
				step = 1,
				parent = true,
				default = 1,
				sType = "slider",
			},
		},
	},
}

-- TODO add notifier to bordersize/border/square

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cMapNav, data)

addon.functions.SettingsCreateMultiDropdown(cMapNav, {
	var = "hiddenMinimapElements",
	text = L["minimapHideElements"],
	options = {
		{ value = "Tracking", text = L["minimapHideElements_Tracking"] },
		{ value = "ZoneInfo", text = L["minimapHideElements_ZoneInfo"] },
		{ value = "Clock", text = L["minimapHideElements_Clock"] },
		{ value = "Calendar", text = L["minimapHideElements_Calendar"] },
		{ value = "Mail", text = L["minimapHideElements_Mail"] },
		{ value = "AddonCompartment", text = L["minimapHideElements_AddonCompartment"] },
	},
})

addon.functions.SettingsCreateHeadline(cMapNav, SPECIALIZATION)

data = {
	{
		var = "enableLootspecQuickswitch",
		text = L["enableLootspecQuickswitch"],
		desc = L["enableLootspecQuickswitchDesc"],
		func = function(key) addon.db["enableLootspecQuickswitch"] = key end,
		default = false,
	},
}

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cMapNav, data)

----- REGION END

function addon.functions.initMapNav() end

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
