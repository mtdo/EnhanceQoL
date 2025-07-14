local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")

addon.Aura.unitFrame = {}

local ICON_SIZE = 20
local ICON_SPACING = 2

local function ensureIcon(frame, index)
	frame.EQOLTrackedAura = frame.EQOLTrackedAura or {}
	local pool = frame.EQOLTrackedAura
	if not pool[index] then
		local iconFrame = CreateFrame("Frame", nil, frame)
		iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
		iconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
		local tex = iconFrame:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints(iconFrame)
		iconFrame.icon = tex
		pool[index] = iconFrame
	end
	return pool[index]
end

local function hideUnusedIcons(frame, used)
	if not frame.EQOLTrackedAura then return end
	for i = used + 1, #frame.EQOLTrackedAura do
		frame.EQOLTrackedAura[i]:Hide()
	end
end

local function layoutIcons(frame, count)
	if not frame.EQOLTrackedAura then return end
	for i = 1, count do
		local icon = frame.EQOLTrackedAura[i]
		icon:ClearAllPoints()
		local offset = (i - (count + 1) / 2) * (ICON_SIZE + ICON_SPACING)
		icon:SetPoint("CENTER", frame, "CENTER", offset, 0)
	end
end

local function UpdateTrackedBuffs(frame, unit)
	if not frame or not unit or not addon.db.unitFrameAuraIDs then return end

	local index = 0
	AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(_, icon, _, _, _, _, _, _, _, spellId)
		if addon.db.unitFrameAuraIDs[spellId] or addon.Aura.defaults.defensiveSpellIDs[spellId] then
			index = index + 1
			local iconFrame = ensureIcon(frame, index)
			iconFrame.icon:SetTexture(icon)
			iconFrame:Show()
		end
	end)

	hideUnusedIcons(frame, index)
	if index > 0 then layoutIcons(frame, index) end
end

addon.Aura.unitFrame.Update = UpdateTrackedBuffs

local function RefreshAll()
	if CompactRaidFrameContainer and CompactRaidFrameContainer.GetFrames then
		for frame in CompactRaidFrameContainer:GetFrames() do
			UpdateTrackedBuffs(frame, frame.unit)
		end
	end
	for i = 1, 5 do
		local f = _G["CompactPartyFrameMember" .. i]
		if f then UpdateTrackedBuffs(f, f.unit) end
	end
end

addon.Aura.unitFrame.RefreshAll = RefreshAll

local function getMergedAuraIDs()
	local merged = {}
	for id, name in pairs(addon.Aura.defaults.defensiveSpellIDs or {}) do
		local info = C_Spell.GetSpellInfo(id)
		merged[id] = string.format("%s (%d)", info or name or "Spell", id)
	end
	for id, val in pairs(addon.db.unitFrameAuraIDs or {}) do
		merged[id] = val
	end
	return merged
end

-- Hook the global update function once; Blizzard calls this for every CompactUnitFrame
hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
	-- 'displayedUnit' is the unit token Blizzard uses; fall back to frame.unit
	local unit = frame and frame.displayedUnit or frame.unit
	if unit then UpdateTrackedBuffs(frame, unit) end
end)

function addon.Aura.functions.addUnitFrameAuraOptions(container)
	local wrapper = addon.functions.createContainer("SimpleGroup", "Flow")
	wrapper:SetFullWidth(true)
	container:AddChild(wrapper)

	local drop
	local function refresh()
		local list, order = addon.functions.prepareListForDropdown(getMergedAuraIDs())
		drop:SetList(list, order)
		drop:SetValue(nil)
		RefreshAll()
	end

	local edit = addon.functions.createEditboxAce(L["AddSpellID"], nil, function(self, _, text)
		local id = tonumber(text)
		if id then
			local info = C_Spell.GetSpellInfo(id)
			if info then
				addon.db.unitFrameAuraIDs[id] = string.format("%s (%d)", info.name, id)
				refresh()
			end
		end
		self:SetText("")
	end)
	wrapper:AddChild(edit)

	local list, order = addon.functions.prepareListForDropdown(getMergedAuraIDs())
	drop = addon.functions.createDropdownAce(L["TrackedAuras"], list, order, nil)
	wrapper:AddChild(drop)

	local btn = addon.functions.createButtonAce(REMOVE, 100, function()
		local sel = drop:GetValue()
		if sel then
			addon.db.unitFrameAuraIDs[sel] = nil
			refresh()
		end
	end)
	wrapper:AddChild(btn)
end
