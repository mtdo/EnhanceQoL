local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.CooldownPanels = addon.Aura.CooldownPanels or {}
local CooldownPanels = addon.Aura.CooldownPanels

CooldownPanels.AnchorHelper = CooldownPanels.AnchorHelper or {}
local AnchorHelper = CooldownPanels.AnchorHelper

local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

AnchorHelper.providers = AnchorHelper.providers or {}
AnchorHelper.runtime = AnchorHelper.runtime or {}

local function isProviderLoaded(provider)
	if not provider then return false end
	if provider.addonName and IsAddOnLoaded and not IsAddOnLoaded(provider.addonName) then return false end
	if provider.isLoaded and provider.isLoaded() == false then return false end
	return true
end

local function providerHasAnchor(provider, value)
	if type(value) ~= "string" or value == "" then return false end
	if provider.isAnchorKey and provider.isAnchorKey(value) then return true end
	if provider.anchorLabelByKey and provider.anchorLabelByKey[value] then return true end
	if provider.anchors then
		for _, entry in ipairs(provider.anchors) do
			if entry.key == value then return true end
		end
	end
	return false
end

local function getRoot()
	if CooldownPanels and CooldownPanels.GetRoot then return CooldownPanels:GetRoot() end
	return nil
end

local function getProvidersInUse()
	local root = getRoot()
	if not root or not root.panels then return nil end
	local used = {}
	for _, panel in pairs(root.panels) do
		local anchor = panel.anchor
		local key = anchor and anchor.relativeFrame
		if key then
			for _, provider in pairs(AnchorHelper.providers) do
				if providerHasAnchor(provider, key) then
					used[provider.key] = provider
					break
				end
			end
		end
	end
	local list = {}
	for _, provider in pairs(used) do
		list[#list + 1] = provider
	end
	if #list == 0 then return nil end
	return list
end

local function providersReady(providers)
	for _, provider in ipairs(providers) do
		if not isProviderLoaded(provider) then return false end
		if provider.framesAvailable and not provider.framesAvailable() then return false end
	end
	return true
end

local function reapplyAnchors(providers)
	local root = getRoot()
	if not root or not root.panels then return end
	if not (CooldownPanels and CooldownPanels.ApplyPanelPosition) then return end
	for panelId, panel in pairs(root.panels) do
		local anchor = panel.anchor
		local key = anchor and anchor.relativeFrame
		if key then
			for _, provider in ipairs(providers) do
				if providerHasAnchor(provider, key) then
					CooldownPanels:ApplyPanelPosition(panelId)
					break
				end
			end
		end
	end
end

function AnchorHelper:RegisterProvider(key, provider)
	if type(key) ~= "string" or key == "" then return end
	if type(provider) ~= "table" then return end
	provider.key = key
	provider.anchorLabelByKey = provider.anchorLabelByKey or {}
	if provider.anchors then
		for _, entry in ipairs(provider.anchors) do
			if entry.key and provider.anchorLabelByKey[entry.key] == nil then
				provider.anchorLabelByKey[entry.key] = entry.label
			end
		end
	end
	if provider.anchorLabels then
		for anchorKey, label in pairs(provider.anchorLabels) do
			if provider.anchorLabelByKey[anchorKey] == nil then
				provider.anchorLabelByKey[anchorKey] = label
			end
		end
	end
	AnchorHelper.providers[key] = provider
end

function AnchorHelper:IsExternalAnchorKey(value)
	for _, provider in pairs(self.providers) do
		if providerHasAnchor(provider, value) then return true end
	end
	return false
end

function AnchorHelper:GetAnchorLabel(value)
	for _, provider in pairs(self.providers) do
		if provider.anchorLabelByKey and provider.anchorLabelByKey[value] then return provider.anchorLabelByKey[value] end
	end
	return nil
end

function AnchorHelper:CollectAnchorEntries(entries, seen)
	if type(entries) ~= "table" then return end
	if type(seen) ~= "table" then seen = {} end
	for _, provider in pairs(self.providers) do
		if isProviderLoaded(provider) and provider.anchors then
			for _, entry in ipairs(provider.anchors) do
				local key = entry.key
				if key and not seen[key] then
					entries[#entries + 1] = { key = key, label = entry.label or (provider.anchorLabelByKey and provider.anchorLabelByKey[key]) or key }
					seen[key] = true
				end
			end
		end
	end
end

function AnchorHelper:ResolveExternalFrame(relativeName)
	if type(relativeName) ~= "string" or relativeName == "" then return nil end
	for _, provider in pairs(self.providers) do
		if isProviderLoaded(provider) and providerHasAnchor(provider, relativeName) then
			if provider.resolveFrame then
				local frame = provider.resolveFrame(relativeName)
				if frame then return frame end
			end
			if provider.anchorFrames and provider.anchorFrames[relativeName] then
				local frame = _G[provider.anchorFrames[relativeName]]
				if frame then return frame end
			end
			local frame = _G[relativeName]
			if frame then return frame end
		end
	end
	return nil
end

function AnchorHelper:MaybeScheduleRefresh(anchorKey)
	if self:IsExternalAnchorKey(anchorKey) then self:ScheduleRefresh() end
end

function AnchorHelper:ScheduleRefresh()
	local providers = getProvidersInUse()
	if not providers then return end
	local active = {}
	for _, provider in ipairs(providers) do
		if isProviderLoaded(provider) then active[#active + 1] = provider end
	end
	if #active == 0 then return end
	if providersReady(active) then
		reapplyAnchors(active)
		if CooldownPanels and CooldownPanels.RefreshAllPanels then CooldownPanels:RefreshAllPanels() end
		return
	end
	if not (C_Timer and C_Timer.NewTicker) then return end
	if self.runtime.refreshTicker then return end
	local tries = 0
	self.runtime.refreshTicker = C_Timer.NewTicker(0.2, function()
		tries = tries + 1
		if providersReady(active) then
			self.runtime.refreshTicker:Cancel()
			self.runtime.refreshTicker = nil
			reapplyAnchors(active)
			if CooldownPanels and CooldownPanels.RefreshAllPanels then CooldownPanels:RefreshAllPanels() end
		elseif tries >= 25 then
			self.runtime.refreshTicker:Cancel()
			self.runtime.refreshTicker = nil
		end
	end)
end

function AnchorHelper:HandleAddonLoaded(addonName)
	if type(addonName) ~= "string" or addonName == "" then return end
	for _, provider in pairs(self.providers) do
		if provider.addonName == addonName then
			self:ScheduleRefresh()
			return
		end
	end
end

function AnchorHelper:HandlePlayerLogin()
	self:ScheduleRefresh()
end

AnchorHelper:RegisterProvider("msuf", {
	addonName = "MidnightSimpleUnitFrames",
	anchors = {
		{ key = "MSUF_player", label = "MSUF: Player Frame" },
		{ key = "MSUF_target", label = "MSUF: Target Frame" },
	},
	framesAvailable = function()
		local frames = _G and _G.MSUF_UnitFrames
		if frames and (frames.player or frames.target) then return true end
		return _G and (_G.MSUF_player or _G.MSUF_target) and true or false
	end,
	resolveFrame = function(relativeName)
		return _G[relativeName]
	end,
})
