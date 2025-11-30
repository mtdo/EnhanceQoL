local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_LayoutTools")

local AceGUI = addon.AceGUI
local db = addon.db["eqolLayoutTools"]

local IsAddonLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local function resolveFramePath(path)
	if not path or type(path) ~= "string" then return nil end
	local first, rest = path:match("([^.]+)%.?(.*)")
	local obj = _G[first]
	if not obj then return nil end
	if rest and rest ~= "" then
		for seg in rest:gmatch("([^.]+)") do
			obj = obj and obj[seg]
			if not obj then return nil end
		end
	end
	return obj
end

addon.variables.statusTable.groups["move"] = true

-- Place layout tools under UI & Input, dynamic list of known frames
local function addLayoutToolsToTree() addon.functions.addToTree("ui", { value = "move", text = L["Move"] }) end

addLayoutToolsToTree()

local function addGeneralSettings(container)
	local scroll = addon.functions.createContainer("ScrollFrame", "Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	container:AddChild(scroll)

	local wrapper = addon.functions.createContainer("SimpleGroup", "Flow")
	scroll:AddChild(wrapper)

	-- Global toggles
	local groupGlobal = addon.functions.createContainer("InlineGroup", "List")
	groupGlobal:SetTitle(L["Global Settings"] or "Global Settings")
	wrapper:AddChild(groupGlobal)

	local cbMove = addon.functions.createCheckboxAce(L["Global Move Enabled"] or "Global Move Enabled", db["uiScalerGlobalMoveEnabled"], function(_, _, val) db["uiScalerGlobalMoveEnabled"] = val end)
	groupGlobal:AddChild(cbMove)

	local cbScale = addon.functions.createCheckboxAce(
		L["Global Scale Enabled"] or "Global Scale Enabled",
		db["uiScalerGlobalScaleEnabled"],
		function(_, _, val) db["uiScalerGlobalScaleEnabled"] = val end
	)
	groupGlobal:AddChild(cbScale)

	local cbMoveMod = addon.functions.createCheckboxAce(
		L["Require Modifier For Move"] or "Require modifier to move",
		db["uiScalerMoveRequireModifier"],
		function(_, _, val) db["uiScalerMoveRequireModifier"] = val end
	)
	groupGlobal:AddChild(cbMoveMod)

	local groupCore = addon.functions.createContainer("InlineGroup", "List")
	groupCore:SetTitle(L["Wheel Scaling"] or "Wheel Scaling")
	wrapper:AddChild(groupCore)

	-- Modifier dropdown
	local list = { SHIFT = "SHIFT", CTRL = "CTRL", ALT = "ALT" }
	local order = { "SHIFT", "CTRL", "ALT" }
	local instr -- forward-declared for callback update
	local drop = addon.functions.createDropdownAce(L["Scale Modifier"] or "Scale Modifier", list, order, function(self, _, key)
		db["uiScalerWheelModifier"] = key
		if instr then
			local m = db["uiScalerWheelModifier"] or "SHIFT"
			instr:SetText(string.format(L["ScaleInstructions"] or "Use %s + Mouse Wheel to scale. Use %s + Right-Click to reset.", m, m))
		end
	end)
	drop:SetValue(db["uiScalerWheelModifier"] or "SHIFT")
	groupCore:AddChild(drop)

	-- Instruction label
	local m = db["uiScalerWheelModifier"] or "SHIFT"
	instr = addon.functions.createLabelAce(string.format(L["ScaleInstructions"] or "Use %s + Mouse Wheel to scale. Use %s + Right-Click to reset.", m, m))
	groupCore:AddChild(instr)

	-- Frames selection
	local groupFrames = addon.functions.createContainer("InlineGroup", "Flow")
	groupFrames:SetTitle(L["Frames"] or "Frames")
	wrapper:AddChild(groupFrames)

	local framesActive = db["uiScalerFramesActive"] or {}
	for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
		local id = entry.id
		local label = entry.label or id
		local val = framesActive[id]
		if val == nil then val = true end
		local cb = addon.functions.createCheckboxAce(label, val, function(_, _, v)
			framesActive[id] = v
			db["uiScalerFramesActive"] = framesActive
			-- hook any frames for this entry
			local function hookName(name)
				local f = resolveFramePath and resolveFramePath(name) or _G[name]
				if v and f then
					addon.LayoutTools.functions.createHooks(f)
					addon.LayoutTools.functions.applyFrameSettings(f)
				end
			end
			if entry.names then
				for _, n in ipairs(entry.names) do
					hookName(n)
				end
			end
		end)
		-- two columns
		cb:SetFullWidth(false)
		cb:SetRelativeWidth(0.5)
		groupFrames:AddChild(cb)
	end
end

local function addGenericFrameOptions(container, frameName, displayText)
	local frame = _G[frameName]
	local keys = {
		enable = "uiScaler" .. frameName .. "Enabled",
		move = "uiScaler" .. frameName .. "Move",
		scale = "uiScaler" .. frameName .. "Frame",
	}

	local scroll = addon.functions.createContainer("ScrollFrame", "Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	container:AddChild(scroll)

	local wrapper = addon.functions.createContainer("SimpleGroup", "Flow")
	scroll:AddChild(wrapper)

	local groupCore = addon.functions.createContainer("InlineGroup", "List")
	groupCore:SetTitle(displayText or frameName)
	wrapper:AddChild(groupCore)

	-- Enable scaling
	local cbScale = addon.functions.createCheckboxAce(
		L["Enable scaling for"] and (L["Enable scaling for"] .. ": " .. (displayText or frameName)) or ("Enable scaling: " .. (displayText or frameName)),
		db[keys.enable],
		function(_, _, val)
			db[keys.enable] = val
			if frame and frame:IsShown() then addon.LayoutTools.functions.applyFrameSettings(frame) end
		end
	)
	groupCore:AddChild(cbScale)

	-- Enable moving
	local cbMove = addon.functions.createCheckboxAce(
		L["Enable moving for"] and (L["Enable moving for"] .. ": " .. (displayText or frameName)) or ("Enable moving: " .. (displayText or frameName)),
		db[keys.move],
		function(_, _, val)
			db[keys.move] = val
			if frame and frame:IsShown() then
				-- ensure hooks exist
				addon.LayoutTools.functions.createHooks(frame)
				addon.LayoutTools.functions.applyFrameSettings(frame)
			end
		end
	)
	groupCore:AddChild(cbMove)

	if db[keys.enable] then
		local groupScale = addon.functions.createContainer("InlineGroup", "List")
		groupScale:SetTitle(UI_SCALE)
		wrapper:AddChild(groupScale)

		local slider = addon.functions.createSliderAce(L["talentFrameUIScale"] or (displayText .. " scale"), db[keys.scale] or 1, 0.3, 1, 0.05, function(_, _, value2)
			db[keys.scale] = value2
			if frame and frame:IsShown() then frame:SetScale(value2) end
		end)
		groupScale:AddChild(slider)
	end
end

function addon.LayoutTools.functions.treeCallback(container, group)
	container:ReleaseChildren()
	addGeneralSettings(container)
end

local function tryHookKnownFrames()
	for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
		local function hookName(name)
			local f = resolveFramePath and resolveFramePath(name) or _G[name]
			if f then addon.LayoutTools.functions.createHooks(f) end
		end
		local shouldHook = true
		if entry.addon and not (IsAddonLoaded and IsAddonLoaded(entry.addon)) then shouldHook = false end
		if shouldHook then
			if entry.names then
				for _, n in ipairs(entry.names) do
					hookName(n)
				end
			end
		end
	end
end

local eventHandlers = {
	["ADDON_LOADED"] = function(arg1)
		if arg1 == addonName then
			-- Hook frames already available
			tryHookKnownFrames()
			if addon.LayoutTools and addon.LayoutTools.functions and addon.LayoutTools.functions.ensureWheelCaptureOverlay then addon.LayoutTools.functions.ensureWheelCaptureOverlay() end
		end

		-- Hook frames that load with specific Blizzard addons
		for _, entry in ipairs(addon.LayoutTools.variables.knownFrames or {}) do
			local function hookName(name)
				local f = resolveFramePath and resolveFramePath(name) or _G[name]
				if f then addon.LayoutTools.functions.createHooks(f) end
			end
			if entry.addon and arg1 == entry.addon then
				if entry.names then
					for _, n in ipairs(entry.names) do
						hookName(n)
					end
				end
			end
		end
	end,
	["PLAYER_REGEN_ENABLED"] = function()
		-- Process deferred hooks for protected frames
		local combatQueue = addon.LayoutTools.variables.combatQueue or {}
		for frame, stored in pairs(combatQueue) do
			addon.LayoutTools.variables.combatQueue[frame] = nil
			if frame then addon.LayoutTools.functions.createHooks(frame, stored.dbVar) end
		end
		-- Apply deferred operations for protected frames
		local pending = addon.LayoutTools.variables.pendingApply or {}
		for f in pairs(pending) do
			if f and f:IsShown() then addon.LayoutTools.functions.applyFrameSettings(f) end
			pending[f] = nil
		end
	end,
}

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
