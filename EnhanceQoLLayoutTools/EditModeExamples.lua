local PARENT_ADDON = "EnhanceQoL"
local addonName, addon = ...

if _G[PARENT_ADDON] then
	addon = _G[PARENT_ADDON]
else
	error("LegionRemix module requires EnhanceQoL to be loaded first.")
end

local EditMode = addon.EditMode
if not (EditMode and EditMode.RegisterFrame and EditMode.lib and EditMode.lib.SettingType) then return end

local SettingType = EditMode.lib.SettingType

local function createExampleFrame(name, title, color)
	local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetSize(170, 50)
	frame:SetFrameStrata("DIALOG")

	frame:SetBackdrop({
		bgFile = "Interface/Buttons/WHITE8X8",
		edgeFile = "Interface/Buttons/WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(color[1], color[2], color[3], 0.15)
	frame:SetBackdropBorderColor(color[1], color[2], color[3], 0.8)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(title)
	frame.Label = label

	return frame
end

local function getterFor(id, field)
	return function(layout) return EditMode:GetValue(id, field, layout) end
end

local function setterFor(id, field)
	return function(layout, value)
		EditMode:SetValue(id, field, value, layout, true)
		EditMode:ApplyLayout(id, layout)
	end
end

local function registerExample(example)
	local id = "EQOL_EditModeExample_" .. example.key
	local frame = createExampleFrame(id .. "_Frame", example.title, example.color or { 0.7, 0.7, 0.7 })

	local settings = {}
	for i, setting in ipairs(example.settings or {}) do
		local copy = CopyTable(setting)
		if copy.colorField then
			copy.colorGet = getterFor(id, copy.colorField)
			copy.colorSet = setterFor(id, copy.colorField)
			copy.colorField = nil
		end
		settings[i] = copy
	end

	local defaults = CopyTable(example.defaults or {})
	defaults.point = defaults.point or "CENTER"
	defaults.relativePoint = defaults.relativePoint or defaults.point
	defaults.x = defaults.x or 0
	defaults.y = defaults.y or 0

	EditMode:RegisterFrame(id, {
		frame = frame,
		title = example.title,
		layoutDefaults = defaults,
		settings = settings,
	})
end

local examples = {
	{
		key = "Checkbox",
		title = "Checkbox",
		color = { 0.2, 0.6, 1 },
		settings = {
			{
				name = "Checkbox",
				kind = SettingType.Checkbox,
				field = "checkbox",
				default = true,
				get = function() return nil end,
				tooltip = "Always shown",
			},
			{
				name = "Checkbox2",
				kind = SettingType.Checkbox,
				field = "checkbox2",
				default = true,
				get = function() return nil end,
				isShown = function()
					local val = EditMode:GetValue("EQOL_EditModeExample_Checkbox", "checkbox", EditMode:GetActiveLayoutName())
					return val ~= false
				end,
				tooltip = "Hidden when Checkbox is off",
			},
		},
	},
	{
		key = "Dropdown",
		title = "Dropdown",
		color = { 0.3, 0.8, 0.4 },
		defaults = { point = "CENTER", x = -80, y = 120, dropdown = "Option A" },
		settings = {
			{
				name = "Dropdown",
				kind = SettingType.Dropdown,
				field = "dropdown",
				default = "Option A",
				values = {
					{ text = "Option A", isRadio = true },
					{ text = "Option B", isRadio = true },
					{ text = "Option C", isRadio = true },
				},
			},
		},
	},
	{
		key = "MultiDropdown",
		title = "Multi Dropdown",
		color = { 0.3, 0.65, 0.95 },
		defaults = {
			point = "CENTER",
			x = 260,
			y = 20,
			roles = { TANK = true, HEALER = true },
		},
		settings = {
			{
				name = "Roles",
				kind = SettingType.MultiDropdown,
				field = "roles",
				default = { TANK = true, HEALER = true },
				values = {
					{ text = "Tank", value = "TANK" },
					{ text = "Healer", value = "HEALER" },
					{ text = "DPS", value = "DPS" },
					{ text = "DPS2", value = "DPS2" },
					{ text = "DPS3", value = "DPS3" },
					{ text = "DPS4", value = "DPS4" },
					{ text = "DPS5", value = "DPS5" },
					{ text = "DPS6", value = "DPS6" },
				},
			},
		},
	},
	{
		key = "SliderInput",
		title = "Slider + Input",
		color = { 0.8, 0.6, 0.2 },
		defaults = { point = "CENTER", x = 100, y = 120, slider = 50 },
		settings = {
			{
				name = "Slider",
				kind = SettingType.Slider,
				field = "slider",
				default = 50,
				minValue = 0,
				maxValue = 100,
				valueStep = 5,
				allowInput = true,
				formatter = function(value) return string.format("%d%%", value) end,
			},
		},
	},
	{
		key = "SliderSimple",
		title = "Slider",
		color = { 0.8, 0.4, 0.2 },
		defaults = { point = "CENTER", x = 260, y = 120, slider = 10 },
		settings = {
			{
				name = "Slider",
				kind = SettingType.Slider,
				field = "slider",
				default = 10,
				minValue = 0,
				maxValue = 20,
				valueStep = 1,
				allowInput = false,
				formatter = function(value) return tostring(value) end,
			},
		},
	},
	{
		key = "Color",
		title = "Color",
		color = { 0.6, 0.3, 0.8 },
		defaults = { point = "CENTER", x = -260, y = 20, color = { 0.3, 0.7, 1, 1 } },
		settings = {
			{
				name = "Color",
				kind = SettingType.Color,
				field = "color",
				default = { 0.3, 0.7, 1, 1 },
				hasOpacity = true,
			},
		},
	},
	{
		key = "CheckboxColor",
		title = "Checkbox + Color",
		color = { 0.9, 0.5, 0.3 },
		defaults = {
			point = "CENTER",
			x = -80,
			y = 20,
			checkboxColorEnabled = true,
			checkboxColor = { 1, 0.8, 0.2, 1 },
		},
		settings = {
			{
				name = "Checkbox + Color",
				kind = SettingType.CheckboxColor,
				field = "checkboxColorEnabled",
				default = true,
				colorField = "checkboxColor",
				colorDefault = { 1, 0.8, 0.2, 1 },
				hasOpacity = true,
			},
		},
	},
	{
		key = "DropdownColor",
		title = "Dropdown + Color",
		color = { 0.2, 0.7, 0.7 },
		defaults = {
			point = "CENTER",
			x = 100,
			y = 20,
			dropdownColorChoice = "Default",
			dropdownColor = { 0.2, 0.8, 0.2, 1 },
		},
		settings = {
			{
				name = "Dropdown + Color",
				kind = SettingType.DropdownColor,
				field = "dropdownColorChoice",
				default = "Default",
				values = {
					{ text = "Default", isRadio = true },
					{ text = "Smooth", isRadio = true },
					{ text = "Flat", isRadio = true },
				},
				colorField = "dropdownColor",
				colorDefault = { 0.2, 0.8, 0.2, 1 },
				hasOpacity = true,
			},
		},
	},
}

for _, example in ipairs(examples) do
	registerExample(example)
end
