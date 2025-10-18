local PARENT_ADDON = "EnhanceQoL"
local addonName, addon = ...

if _G[PARENT_ADDON] then
	addon = _G[PARENT_ADDON]
else
	error("LegionRemix module requires EnhanceQoL to be loaded first.")
end

addon.Events = addon.Events or {}
addon.Events.LegionRemix = addon.Events.LegionRemix or {}
local LegionRemix = addon.Events.LegionRemix

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(PARENT_ADDON)

local PHASE_LOOKUP = _G.EnhanceQoLLegionRemixPhaseData or { mount = {}, item = {}, achievement = {} }
if type(PHASE_LOOKUP.mount) ~= "table" then PHASE_LOOKUP.mount = {} end
if type(PHASE_LOOKUP.item) ~= "table" then PHASE_LOOKUP.item = {} end
if type(PHASE_LOOKUP.achievement) ~= "table" then PHASE_LOOKUP.achievement = {} end

LegionRemix.phaseLookup = PHASE_LOOKUP

LegionRemix.phaseAchievements = LegionRemix.phaseAchievements or {}
for achievementID, phase in pairs(PHASE_LOOKUP.achievement) do
	local list = LegionRemix.phaseAchievements[phase]
	if not list then
		list = {}
		LegionRemix.phaseAchievements[phase] = list
	end
	table.insert(list, achievementID)
end
for _, list in pairs(LegionRemix.phaseAchievements) do table.sort(list) end
LegionRemix.phaseTotals = LegionRemix.phaseTotals or {}

local function T(key, fallback)
	if type(L) == "table" then
		local value = rawget(L, key)
		if value then return value end
	end
	return fallback or key
end

function LegionRemix:GetAllPhases()
	if self.cachedPhases then return self.cachedPhases end
	local seen = {}
	for _, mapping in pairs(PHASE_LOOKUP) do
		for _, phase in pairs(mapping) do
			if phase then seen[phase] = true end
		end
	end
	local phases = {}
	for phase in pairs(seen) do table.insert(phases, phase) end
	table.sort(phases)
	self.cachedPhases = phases
	return phases
end

function LegionRemix:GetActivePhaseFilterSet()
	local db = self:GetDB()
	local filters = db and db.phaseFilters or {}
	local set = {}
	local selectedCount = 0
	for phase, enabled in pairs(filters) do
		if enabled and type(phase) == "number" then
			set[phase] = true
			selectedCount = selectedCount + 1
		end
	end
	if selectedCount == 0 then
		for _, phase in ipairs(self:GetAllPhases()) do set[phase] = true end
		return set, true
	end
	return set, false
end

function LegionRemix:IsPhaseActive(phase)
	local active, allActive = self:GetActivePhaseFilterSet()
	if allActive then return true end
	return active[phase] or false
end

function LegionRemix:SetPhaseFilter(phase, enabled)
	local db = self:GetDB()
	if not db then return end
	db.phaseFilters = db.phaseFilters or {}
	if enabled then
		db.phaseFilters[phase] = true
	else
		db.phaseFilters[phase] = nil
	end
	self:RefreshData()
end

function LegionRemix:TogglePhaseFilter(phase)
	local db = self:GetDB()
	if not db then return end
	db.phaseFilters = db.phaseFilters or {}
	if db.phaseFilters[phase] then
		db.phaseFilters[phase] = nil
	else
		db.phaseFilters[phase] = true
	end
	self:RefreshData()
end

function LegionRemix:ResetPhaseFilters()
	local db = self:GetDB()
	if not db then return end
	db.phaseFilters = {}
	self:RefreshData()
end

function LegionRemix:SetFilterButtonActive(button, active)
	if not button then return end
	button.active = active and true or false
	if button.active then
		button:SetBackdropColor(0.14, 0.36, 0.66, 0.9)
		button:SetBackdropBorderColor(0.18, 0.48, 0.82, 0.9)
		button.label:SetTextColor(1, 1, 1)
	else
		button:SetBackdropColor(0.06, 0.06, 0.1, 0.6)
		button:SetBackdropBorderColor(0.16, 0.28, 0.45, 0.6)
		button.label:SetTextColor(0.82, 0.84, 0.9)
	end
end

function LegionRemix:BuildFilterButtons()
	if not self.overlay or not self.overlay.filterBar then return end
	local bar = self.overlay.filterBar
	bar.hasButtons = false
	if bar.buttons then
		for _, btn in ipairs(bar.buttons) do
			btn:Hide()
			btn:SetParent(nil)
		end
	end
	bar.buttons = {}
	self.filterButtons = {}

	local phases = self:GetAllPhases()
	if #phases == 0 then
		bar:Hide()
		return
	end
	bar:Show()
	bar.hasButtons = true

	local previous
	local function createButton(key, label, onClick)
		local btn = CreateFrame("Button", nil, bar, "BackdropTemplate")
		btn:SetHeight(22)
		btn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		btn.label:SetPoint("CENTER")
		btn.label:SetText(label)
		local width = math.max(56, btn.label:GetStringWidth() + 20)
		btn:SetWidth(width)
		if previous then
			btn:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			btn:SetPoint("LEFT", bar, "LEFT", 0, 0)
		end
		btn:SetScript("OnClick", onClick)
		btn:SetScript("OnEnter", function(self)
			if not self.active then self:SetBackdropColor(0.09, 0.09, 0.14, 0.75) end
		end)
		btn:SetScript("OnLeave", function(self)
			if not self.active then LegionRemix:SetFilterButtonActive(self, false) end
		end)
		table.insert(bar.buttons, btn)
		self.filterButtons[key] = btn
		previous = btn
		return btn
	end

	createButton("all", T("All Phases", "All Phases"), function()
		LegionRemix:ResetPhaseFilters()
	end)

	for _, phase in ipairs(phases) do
		createButton("phase_" .. phase, string.format(T("Phase %d", "Phase %d"), phase), function()
			LegionRemix:TogglePhaseFilter(phase)
		end).phase = phase
	end
end

function LegionRemix:UpdateFilterButtons()
	if not self.filterButtons then return end
	local activeSet, allActive = self:GetActivePhaseFilterSet()
	local allButton = self.filterButtons.all
	if allButton then self:SetFilterButtonActive(allButton, allActive) end
	for key, btn in pairs(self.filterButtons) do
		if key ~= "all" and btn.phase then
			self:SetFilterButtonActive(btn, allActive or activeSet[btn.phase])
		end
	end
end

local BRONZE_CURRENCY_ID = 2778
local DEFAULTS = {
	overlayEnabled = true,
	overlayHidden = false,
	locked = false,
	collapsed = false,
	onlyInRemixZones = true,
	classOnly = false,
	enhancedTracking = true,
	phaseFilters = {},
	anchor = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 },
}

local CLASS_MASKS = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 4,
	ROGUE = 8,
	PRIEST = 16,
	DEATHKNIGHT = 32,
	SHAMAN = 64,
	MAGE = 128,
	WARLOCK = 256,
	MONK = 512,
	DRUID = 1024,
	DEMONHUNTER = 2048,
	EVOKER = 4096,
}

local REMIX_ZONE_IDS = {
	[619] = true,
	[747] = true,
	[748] = true,
	[749] = true,
	[750] = true,
	[751] = true,
	[752] = true,
	[753] = true,
	[754] = true,
	[755] = true,
	[756] = true,
	[1456] = true,
	[1458] = true,
	[1466] = true,
	[1477] = true,
	[1492] = true,
	[1493] = true,
	[1501] = true,
	[1516] = true,
	[1520] = true,
	[1530] = true,
	[1544] = true,
	[1571] = true,
	[1648] = true,
	[1651] = true,
	[1676] = true,
	[1677] = true,
	[1712] = true,
	[1753] = true,
}

local CATEGORY_DATA = {
	{
		key = "mounts",
		label = MOUNTS or "Mounts",
		groups = {
			{ type = "mount", cost = 10000, items = { 2653, 2671, 2672, 2673, 2674, 2665, 2675, 2676, 2677, 2678, 2705, 2706, 2593, 2660, 2661, 2662, 2542, 2544, 2546, 2663, 2664, 2666, 2574, 2670, 2679, 2681, 2682, 2683, 2686, 2688, 2689, 2690, 2691 } },
			{ type = "mount", cost = 20000, items = { 802, 943, 941, 905, 944, 942, 983, 984, 985, 838 } },
			{ type = "mount", cost = 20000, items = { 2726, 2731, 2720, 2723, 2728, 2725, 2721, 2727, 2730, 2724, 2729 } },
			{ type = "mount", cost = 40000, items = { 656, 779, 981, 980, 979, 955, 906, 973, 975, 976, 974, 970 } },
			{ type = "mount", cost = 100000, items = { 847, 875, 791, 633, 899, 971, 954 } },
		},
	},
	{
		key = "toys",
		label = TOY_BOX or TOYS or "Toys",
		groups = {
			{ type = "toy", cost = 10000, items = { 131724, 131717, 129165, 130169, 142530, 142529, 142528, 143662, 153204, 153193 } },
			{ type = "toy", cost = 20000, items = { 140363 } },
			{ type = "toy", cost = 25000, items = { 141862, 153293, 153179, 153181, 153180, 153253, 153182, 153126, 153194 } },
			{ type = "toy", cost = 35000, items = { 142265, 147843, 147867, 153124 } },
			{ type = "toy", cost = 80000, items = { 140160, 153183, 153982 } },
			{ type = "toy", cost = 100000, items = { 136901, 119211, 153004 } },
		},
	},
	{
		key = "pets",
		label = PET_JOURNAL or BATTLE_PETS or "Pets",
		groups = {
			{ type = "pet", cost = 5000, items = {} },
			{ type = "pet", cost = 10000, items = { 1929, 1928, 1887, 2136, 2115, 1926 } },
			{ type = "pet", cost = 20000, items = { 2119, 2118, 2120 } },
			{ type = "pet", cost = 35000, items = { 1718, 2135, 2022, 2050 } },
			{ type = "pet", cost = 80000, items = { 1723, 2042, 2072, 2071 } },
			{ type = "pet", cost = 100000, items = { 1937, 1803 } },
		},
	},
	{
		key = "raidfinder",
		label = RAID_FINDER or "Raid Finder",
		groups = {
			{ type = "set_mixed", cost = 20000, items = { 186, 182, 178, 174 } },
		},
	},
	{
		key = "mythic",
		label = DIFFICULTY_MYTHIC or "Mythic",
		groups = {
			{
				type = "set_per_class",
				cost = 30000,
				itemsByClass = {
					DEATHKNIGHT = { 1004, 1338, 1474 },
					DEMONHUNTER = { 1000, 1334, 1478 },
					DRUID = { 996, 1330, 1482 },
					HUNTER = { 992, 1326, 1486 },
					MAGE = { 998, 1322, 1490 },
					MONK = { 984, 1318, 1494 },
					PALADIN = { 980, 1314, 1498 },
					PRIEST = { 311, 1310, 1502 },
					ROGUE = { 944, 1308, 1506 },
					SHAMAN = { 935, 1304, 1510 },
					WARLOCK = { 321, 1299, 1514 },
					WARRIOR = { 939, 1295, 1518 },
				},
			},
			{ type = "transmog", cost = 30000, items = { 152094, 242368, 151524 } },
			{ type = "set_mixed", cost = 30000, items = { 5276 } },
		},
	},
	{
		key = "dungeon",
		label = DUNGEONS or "Dungeon",
		groups = {
			{ type = "set_mixed", cost = 15000, items = { 4403, 4414, 4415, 4416 } },
			{ type = "set_mixed", cost = 15000, items = { 4406, 4417, 4418, 4419 } },
			{ type = "set_mixed", cost = 15000, items = { 4420, 4421, 4422 } },
			{ type = "set_mixed", cost = 15000, items = { 4412, 4411, 4423, 4424, 4425 } },
		},
	},
	{
		key = "world",
		label = WORLD or "World",
		groups = {
			{ type = "set_mixed", cost = 15000, items = { 160, 4402, 4404, 4465, 4466, 4467, 4468, 4485, 4330, 4481 } },
			{ type = "set_mixed", cost = 15000, items = { 159, 4405, 4407, 4469, 4470, 4471, 4472, 4486, 4399, 4482, 4458 } },
			{ type = "set_mixed", cost = 15000, items = { 158, 4409, 4410, 4473, 4474, 4475, 4476, 4487, 4400, 4483 } },
			{ type = "set_mixed", cost = 15000, items = { 157, 4412, 4413, 4477, 4478, 4479, 4480, 4488, 4401, 4490, 4484, 5301, 5300 } },
		},
	},
	{
		key = "unique",
		label = T("Remix Exclusives", "Remix Exclusives"),
		groups = {
			{ type = "set_mixed", cost = 7500, items = { 4427, 4428, 4429, 4430, 4431, 4432, 4489, 4491 } },
			{ type = "set_mixed", cost = 7500, items = { 4433, 4434, 4435, 4436, 4437, 4457, 2337 } },
			{ type = "set_mixed", cost = 7500, items = { 4443, 4444, 4447, 4448, 4450, 4459 } },
			{ type = "set_mixed", cost = 7500, items = { 4452, 4453, 4460, 2656, 5270 } },
			{ type = "set_mixed", cost = 2500, items = { 5294 } },
			{ type = "set_mixed", cost = 7500, items = { 4331, 4462, 4463, 4464 } },
			{ type = "set_mixed", cost = 2500, items = { 5291, 5295, 5296, 5297, 5298, 5299 } },
			{ type = "set_mixed", cost = 7500, items = { 5292, 5293 } },
		},
	},
	{
		key = "cloaks",
		label = BACKSLOT or CLOAKSLOT or "Cloaks",
		groups = {
			{ type = "set_mixed", cost = 2000, items = { 4502, 4500 } },
			{ type = "set_mixed", cost = 4000, items = { 4494, 4495, 4511, 4498 } },
			{ type = "set_mixed", cost = 6000, items = { 4496, 4505, 4504, 4506, 4510, 4508, 4507 } },
			{ type = "set_mixed", cost = 8000, items = { 4503, 4501, 4499, 4497, 4509 } },
		},
	},
	{
		key = "lostfound",
		label = T("Lost and Found", "Lost and Found"),
		groups = {
			{ type = "set_mixed", cost = 15000, items = { 4440, 4442, 4446, 4449, 4454, 4456, 4492 } },
		},
	},
}

local function normalizePhaseKind(kind)
	if kind == "mount" then return "mount" end
	if kind == "achievement" then return "achievement" end
	if kind == "toy" or kind == "pet" or kind == "transmog" or kind == "item" then return "item" end
	return nil
end

function LegionRemix:GetPhaseFor(kind, id)
	if not id then return nil end
	local normalized = normalizePhaseKind(kind)
	if not normalized then return nil end
	local map = PHASE_LOOKUP[normalized]
	return map and map[id] or nil
end

function LegionRemix:GetPhaseLookup() return PHASE_LOOKUP end

function LegionRemix:GetPhaseAchievements() return self.phaseAchievements end

local function deepMerge(target, source)
	if type(target) ~= "table" then target = {} end
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then target[key] = {} end
			deepMerge(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

local function formatBronze(value)
	if not value or value <= 0 then return "0" end
	if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
	return BreakUpLargeNumbers(math.floor(value + 0.5))
end

local function getProfile()
	if not addon or not addon.db then return nil end
	addon.db.legionRemix = deepMerge(addon.db.legionRemix, DEFAULTS)
	return addon.db.legionRemix
end

LegionRemix.cache = LegionRemix.cache or {}
LegionRemix.rows = LegionRemix.rows or {}

local function clearTable(tbl)
	if not tbl then return end
	for k in pairs(tbl) do tbl[k] = nil end
end

function LegionRemix:InvalidateAllCaches()
	self.cache.sets = {}
	self.cache.mounts = {}
	self.cache.toys = {}
	self.cache.pets = {}
	self.cache.transmog = {}
	self.cache.slotGrid = {}
end

local function ensureTable(tbl)
	return tbl or {}
end

function LegionRemix:GetPlayerClass()
	if not self.playerClass then
		local _, class = UnitClass("player")
		self.playerClass = class
	end
	return self.playerClass
end

function LegionRemix:GetDB() return getProfile() end

function LegionRemix:PlayerHasMount(mountId)
	if not mountId then return false end
	local cache = ensureTable(self.cache.mounts)
	self.cache.mounts = cache
	if cache[mountId] ~= nil then return cache[mountId] end
	local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)
	cache[mountId] = isCollected and true or false
	return cache[mountId]
end

function LegionRemix:PlayerHasToy(itemId)
	if not itemId then return false end
	local cache = ensureTable(self.cache.toys)
	self.cache.toys = cache
	if cache[itemId] ~= nil then return cache[itemId] end
	cache[itemId] = PlayerHasToy(itemId) and true or false
	return cache[itemId]
end

function LegionRemix:PlayerHasPet(speciesId)
	if not speciesId then return false end
	local cache = ensureTable(self.cache.pets)
	self.cache.pets = cache
	if cache[speciesId] ~= nil then return cache[speciesId] end
	local collected = C_PetJournal.GetNumCollectedInfo(speciesId)
	cache[speciesId] = (collected and collected > 0) and true or false
	return cache[speciesId]
end

function LegionRemix:CollectSlotGrid(setId)
	local cache = ensureTable(self.cache.slotGrid)
	self.cache.slotGrid = cache
	if cache[setId] then return cache[setId] end
	local grid = {}
	local setSourceIds = C_TransmogSets.GetAllSourceIDs(setId)
	if setSourceIds then
		for _, sourceID in ipairs(setSourceIds) do
			local categoryID, _, _, _, isCollected = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
			if categoryID then
				if isCollected then
					grid[categoryID] = true
				elseif grid[categoryID] == nil then
					grid[categoryID] = false
				end
			end
		end
	end
	cache[setId] = grid
	return grid
end

function LegionRemix:IsSetUsable(setId)
	local _, className = UnitClass("player")
	if not className or not setId then return false end
	local info = C_TransmogSets.GetSetInfo(setId)
	if not info then return false end
	local mask = CLASS_MASKS[className]
	if not mask then return false end
	return bit.band(info.classMask or 0, mask) ~= 0
end

function LegionRemix:PlayerHasSet(setId)
	if not setId then return false end
	local cache = ensureTable(self.cache.sets)
	self.cache.sets = cache
	if cache[setId] ~= nil then return cache[setId] end

	local setInfo = C_TransmogSets.GetSetInfo(setId)
	if setInfo and setInfo.collected then
		cache[setId] = true
		return true
	end

	local primaryAppearances = C_TransmogSets.GetSetPrimaryAppearances(setId)
	if not primaryAppearances then
		cache[setId] = false
		return false
	end

	local missingSlots = {}
	for _, appearance in ipairs(primaryAppearances) do
		local categoryID, _, _, _, isCollected = C_TransmogCollection.GetAppearanceSourceInfo(appearance.appearanceID)
		if not isCollected then table.insert(missingSlots, categoryID) end
	end

	if #missingSlots == 0 then
		cache[setId] = true
		return true
	end

	local db = self:GetDB()
	if not (db and db.enhancedTracking) then
		cache[setId] = false
		return false
	end

	local slotInfo = self:CollectSlotGrid(setId)
	for _, slot in ipairs(missingSlots) do
		if not slotInfo[slot] then
			cache[setId] = false
			return false
		end
	end

	cache[setId] = true
	return true
end

function LegionRemix:PlayerHasTransmog(itemId)
	if not itemId then return false end
	local cache = ensureTable(self.cache.transmog)
	self.cache.transmog = cache
	if cache[itemId] ~= nil then return cache[itemId] end
	cache[itemId] = C_TransmogCollection.PlayerHasTransmog(itemId) and true or false
	return cache[itemId]
end

local function accumulatePhase(target, phase, cost, owned)
	if not phase or not target then return end
	local bucket = target[phase]
	if not bucket then
		bucket = { totalCost = 0, collectedCost = 0, totalCount = 0, collectedCount = 0 }
		target[phase] = bucket
	end
	bucket.totalCost = bucket.totalCost + cost
	bucket.totalCount = bucket.totalCount + 1
	if owned then
		bucket.collectedCost = bucket.collectedCost + cost
		bucket.collectedCount = bucket.collectedCount + 1
	end
end

local function addItemResult(result, owned, cost, entry)
	result.totalCost = result.totalCost + cost
	result.totalCount = result.totalCount + 1
	local phase = LegionRemix:GetPhaseFor(entry.kind, entry.id)
	if phase then
		result.phaseTotals = result.phaseTotals or {}
		accumulatePhase(result.phaseTotals, phase, cost, owned)
		LegionRemix.phaseTotals = LegionRemix.phaseTotals or {}
		accumulatePhase(LegionRemix.phaseTotals, phase, cost, owned)
	end
	if owned then
		result.collectedCost = result.collectedCost + cost
		result.collectedCount = result.collectedCount + 1
	else
		entry.cost = cost
		entry.phase = phase
		table.insert(result.missing, entry)
	end
end

function LegionRemix:ProcessSetList(result, list, cost)
	if not list or #list == 0 then return end
	for _, setId in ipairs(list) do
		local owned = self:PlayerHasSet(setId)
		addItemResult(result, owned, cost, { kind = "set", id = setId })
	end
end

function LegionRemix:ProcessGroup(categoryResult, group)
	local cost = group.cost or 0
	if cost <= 0 then return end

	if group.type == "mount" then
		for _, mountId in ipairs(group.items) do
			local owned = self:PlayerHasMount(mountId)
			addItemResult(categoryResult, owned, cost, { kind = "mount", id = mountId })
		end
	elseif group.type == "toy" then
		for _, toyId in ipairs(group.items) do
			local owned = self:PlayerHasToy(toyId)
			addItemResult(categoryResult, owned, cost, { kind = "toy", id = toyId })
		end
	elseif group.type == "pet" then
		for _, speciesId in ipairs(group.items) do
			local owned = self:PlayerHasPet(speciesId)
			addItemResult(categoryResult, owned, cost, { kind = "pet", id = speciesId })
		end
	elseif group.type == "transmog" then
		for _, itemId in ipairs(group.items) do
			local owned = self:PlayerHasTransmog(itemId)
			addItemResult(categoryResult, owned, cost, { kind = "transmog", id = itemId })
		end
	elseif group.type == "set_per_class" then
		local db = self:GetDB()
		local itemsByClass = group.itemsByClass or group.items
		if db and db.classOnly then
			local className = self:GetPlayerClass()
			self:ProcessSetList(categoryResult, itemsByClass and itemsByClass[className], cost)
		else
			for _, list in pairs(itemsByClass) do
				self:ProcessSetList(categoryResult, list, cost)
			end
		end
	elseif group.type == "set_mixed" then
		local db = self:GetDB()
		if db and db.classOnly then
			local filtered = {}
			for _, setId in ipairs(group.items) do
				if self:IsSetUsable(setId) then table.insert(filtered, setId) end
			end
			self:ProcessSetList(categoryResult, filtered, cost)
		else
			self:ProcessSetList(categoryResult, group.items, cost)
		end
	end
end

function LegionRemix:BuildCategoryData(category)
	local result = {
		key = category.key,
		label = category.label,
		collectedCost = 0,
		totalCost = 0,
		collectedCount = 0,
		totalCount = 0,
		missing = {},
	}
	for _, group in ipairs(category.groups or {}) do
		self:ProcessGroup(result, group)
	end
	result.remainingCost = result.totalCost - result.collectedCost
	if result.remainingCost < 0 then result.remainingCost = 0 end
	table.sort(result.missing, function(a, b)
		if a.cost == b.cost then return (a.id or 0) < (b.id or 0) end
		return a.cost > b.cost
	end)
	if result.phaseTotals and not next(result.phaseTotals) then result.phaseTotals = nil end
	return result
end

function LegionRemix:BuildCategoryDisplay(categoryData)
	local filters, allActive = self:GetActivePhaseFilterSet()
	local display = {
		key = categoryData.key,
		label = categoryData.label,
		phaseTotals = categoryData.phaseTotals,
		original = categoryData,
		missing = categoryData.missing,
	}

	if allActive or not categoryData.phaseTotals then
		display.collectedCost = categoryData.collectedCost
		display.totalCost = categoryData.totalCost
		display.collectedCount = categoryData.collectedCount
		display.totalCount = categoryData.totalCount
		display.filteredMissing = categoryData.missing
		display.showAllPhases = true
		return display
	end

	local collectedCost, totalCost, collectedCount, totalCount = 0, 0, 0, 0
	for phase, totals in pairs(categoryData.phaseTotals) do
		if filters[phase] then
			collectedCost = collectedCost + (totals.collectedCost or 0)
			totalCost = totalCost + (totals.totalCost or 0)
			collectedCount = collectedCount + (totals.collectedCount or 0)
			totalCount = totalCount + (totals.totalCount or 0)
		end
	end

	local filteredMissing = {}
	for _, entry in ipairs(categoryData.missing or {}) do
		if not entry.phase or filters[entry.phase] then table.insert(filteredMissing, entry) end
	end

	display.collectedCost = collectedCost
	display.totalCost = totalCost
	display.collectedCount = collectedCount
	display.totalCount = totalCount
	display.filteredMissing = filteredMissing
	display.showAllPhases = false
	return display
end

function LegionRemix:GetFilteredOverallTotals()
	local filters, allActive = self:GetActivePhaseFilterSet()
	if allActive or not self.phaseTotals then
		return self.totalCollected or 0, self.totalCost or 0
	end
	local collected, total = 0, 0
	for phase, totals in pairs(self.phaseTotals) do
		if filters[phase] then
			collected = collected + (totals.collectedCost or 0)
			total = total + (totals.totalCost or 0)
		end
	end
	return collected, total
end

function LegionRemix:RefreshData()
	if not addon.db then return end
	self:GetDB()
	self.phaseTotals = {}
	LegionRemix.phaseTotals = self.phaseTotals
	local categories = {}
	local totalCost, totalCollected = 0, 0
	for _, category in ipairs(CATEGORY_DATA) do
		local data = self:BuildCategoryData(category)
		table.insert(categories, data)
		totalCost = totalCost + data.totalCost
		totalCollected = totalCollected + data.collectedCost
	end
	self.latestCategories = categories
	self.totalCost = totalCost
	self.totalCollected = totalCollected
	self:UpdateOverlay()
end

function LegionRemix:GetBronzeCurrency()
	local info = C_CurrencyInfo.GetCurrencyInfo(BRONZE_CURRENCY_ID)
	return info and info.quantity or 0
end

function LegionRemix:IsInLegionRemixZone()
	local db = self:GetDB()
	if not db or not db.onlyInRemixZones then return true end
	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then return false end
	return REMIX_ZONE_IDS[mapID] or false
end

function LegionRemix:ShouldOverlayBeVisible()
	local db = self:GetDB()
	if not db or not db.overlayEnabled then return false end
	if db.overlayHidden then return false end
	return self:IsInLegionRemixZone()
end

function LegionRemix:ApplyAnchor(frame)
	local db = self:GetDB()
	if not (frame and db and db.anchor) then return end
	frame:ClearAllPoints()
	frame:SetPoint(db.anchor.point or "CENTER", UIParent, db.anchor.relativePoint or "CENTER", db.anchor.x or 0, db.anchor.y or 0)
end

function LegionRemix:SaveAnchor(frame)
	if not frame then return end
	local db = self:GetDB()
	if not db then return end
	local point, _, relativePoint, x, y = frame:GetPoint()
	db.anchor.point = point
	db.anchor.relativePoint = relativePoint
	db.anchor.x = x
	db.anchor.y = y
end

local function setButtonTexture(button, collapsed)
	if not button then return end
	if collapsed then
		button:SetNormalAtlas("ui-hud-minimap-button-plus")
		button:SetPushedAtlas("ui-hud-minimap-button-plus-down")
	else
		button:SetNormalAtlas("ui-hud-minimap-button-minus")
		button:SetPushedAtlas("ui-hud-minimap-button-minus-down")
	end
end

function LegionRemix:CreateCategoryRow(parent)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetHeight(42)
	row:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false,
		edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	row:SetBackdropColor(0.04, 0.06, 0.1, 0.65)
	row:SetBackdropBorderColor(0.18, 0.48, 0.82, 0.35)

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOPLEFT", 6, -6)
	label:SetPoint("RIGHT", -6, 0)
	label:SetJustifyH("LEFT")

	local count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	count:SetPoint("TOPRIGHT", -6, -6)
	count:SetJustifyH("RIGHT")

	local status = CreateFrame("StatusBar", nil, row)
	status:SetPoint("BOTTOMLEFT", 6, 6)
	status:SetPoint("BOTTOMRIGHT", -6, 6)
	status:SetHeight(16)
	status:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
	status:GetStatusBarTexture():SetHorizTile(false)
	status:SetMinMaxValues(0, 1)
	status:SetValue(0)
	status:SetStatusBarColor(0.18, 0.52, 0.9, 0.9)

	local statusBg = status:CreateTexture(nil, "BACKGROUND")
	statusBg:SetAllPoints()
	statusBg:SetColorTexture(0.02, 0.03, 0.06, 0.85)

	local metric = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	metric:SetPoint("CENTER", 0, 0)

	row.label = label
	row.count = count
	row.status = status
	row.metric = metric

	row:SetScript("OnEnter", function(btn)
		btn:SetBackdropColor(0.08, 0.12, 0.17, 0.75)
		LegionRemix:ShowCategoryTooltip(btn)
	end)
	row:SetScript("OnLeave", function(btn)
		btn:SetBackdropColor(0.04, 0.06, 0.1, 0.65)
		GameTooltip_Hide()
	end)
	return row
end

function LegionRemix:GetRow(index, parent)
	self.rows = self.rows or {}
	local row = self.rows[index]
	if not row then
		row = self:CreateCategoryRow(parent)
		if index == 1 then
			row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
			row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
		else
			row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -6)
			row:SetPoint("TOPRIGHT", self.rows[index - 1], "BOTTOMRIGHT", 0, -6)
		end
		self.rows[index] = row
	end
	row:Show()
	return row
end

local function round(value)
	return math.floor((value or 0) + 0.5)
end

function LegionRemix:UpdateRow(row, data)
	row.displayData = data
	row.label:SetText(data.label or "")
	row.count:SetText(string.format("%s / %s", data.collectedCount or 0, data.totalCount or 0))

	local total = data.totalCost > 0 and data.totalCost or 1
	row.status:SetMinMaxValues(0, total)
	row.status:SetValue(data.collectedCost or 0)
	row.metric:SetText(string.format("%s / %s", formatBronze(data.collectedCost), formatBronze(data.totalCost)))
end

function LegionRemix:HideUnusedRows(fromIndex)
	if not self.rows then return end
	for i = fromIndex, #self.rows do
		if self.rows[i] then self.rows[i]:Hide() end
	end
end

function LegionRemix:GetItemName(entry)
	if entry.kind == "mount" then
		local name = C_MountJournal.GetMountInfoByID(entry.id or 0)
		return name or ("Mount #" .. tostring(entry.id or "?"))
	elseif entry.kind == "toy" then
		local name = C_ToyBox.GetToyInfo(entry.id or 0)
		return name or ("Toy #" .. tostring(entry.id or "?"))
	elseif entry.kind == "pet" then
		local name = select(1, C_PetJournal.GetPetInfoBySpeciesID(entry.id or 0))
		return name or ("Pet #" .. tostring(entry.id or "?"))
	elseif entry.kind == "set" then
		local info = C_TransmogSets.GetSetInfo(entry.id or 0)
		return info and info.name or ("Set #" .. tostring(entry.id or "?"))
	elseif entry.kind == "transmog" then
		local name = GetItemInfo(entry.id or 0)
		if name then return name end
		local itemName = C_Item.GetItemNameByID(entry.id or 0)
		if itemName then return itemName end
		C_Item.RequestLoadItemDataByID(entry.id or 0)
		return ("Item #" .. tostring(entry.id or "?"))
	end
	return T("Unknown", "Unknown")
end

function LegionRemix:ShowCategoryTooltip(row)
	if not row or not row:IsVisible() then return end
	local data = row.displayData or row.data
	if not data then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(data.label or "")
	GameTooltip:AddDoubleLine(T("Items", "Items"), string.format("%d / %d", data.collectedCount or 0, data.totalCount or 0), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
	GameTooltip:AddDoubleLine(T("Bronze", "Bronze"), string.format("%s / %s", formatBronze(data.collectedCost), formatBronze(data.totalCost)), 0.8, 0.8, 0.8, 0.9, 0.9, 0.9)
	GameTooltip:AddLine(" ")
	local missing = data.filteredMissing or data.missing or {}
	if #missing == 0 then
		GameTooltip:AddLine(T("All items collected.", "All items collected."), 0.4, 1, 0.4)
	else
		GameTooltip:AddLine(T("Missing items:", "Missing items:"), 1, 0.82, 0)
		local maxEntries = 12
		for i = 1, math.min(maxEntries, #missing) do
			local entry = missing[i]
			local label = self:GetItemName(entry)
			if entry.phase then label = string.format("%s (%s)", label, string.format(T("Phase %d", "Phase %d"), entry.phase)) end
			GameTooltip:AddDoubleLine(label, formatBronze(entry.cost), 0.9, 0.9, 0.9, 0.7, 0.9, 0.7)
		end
		if #missing > maxEntries then
			GameTooltip:AddLine(string.format(T("+ %d more...", "+ %d more..."), #missing - maxEntries), 0.5, 0.5, 0.5)
		end
	end
	GameTooltip:Show()
end

function LegionRemix:CreateOverlay()
	if self.overlay then return self.overlay end

	local frame = CreateFrame("Frame", "EnhanceQoLLegionRemixOverlay", UIParent, "BackdropTemplate")
	frame:SetSize(360, 520)
	frame.expandedHeight = 520
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.015, 0.015, 0.03, 0.92)
	frame:SetBackdropBorderColor(0.12, 0.32, 0.62, 0.85)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(f)
		local db = LegionRemix:GetDB()
		if db and db.locked then return end
		f:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		LegionRemix:SaveAnchor(f)
	end)

	local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	header:SetPoint("TOPLEFT", 10, -10)
	header:SetPoint("TOPRIGHT", -10, -10)
	header:SetHeight(48)
	header:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
	})
	header:SetBackdropColor(0.05, 0.05, 0.08, 0.95)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 12, -8)
	title:SetJustifyH("LEFT")
	title:SetText(T("Legion Remix Collection", "Legion Remix Collection"))

	local bronzeText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bronzeText:SetPoint("BOTTOMLEFT", 12, 10)
	bronzeText:SetJustifyH("LEFT")

	local remainingText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	remainingText:SetPoint("BOTTOMRIGHT", -12, 10)
	remainingText:SetJustifyH("RIGHT")

	local collapse = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	collapse:SetSize(26, 24)
	collapse:SetPoint("TOPRIGHT", -6, -8)
	collapse:SetScript("OnClick", function()
		local db = LegionRemix:GetDB()
		if not db then return end
		db.collapsed = not db.collapsed
		setButtonTexture(collapse, db.collapsed)
		LegionRemix:UpdateOverlay()
	end)

	local closeButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	closeButton:SetSize(26, 24)
	closeButton:SetPoint("RIGHT", collapse, "LEFT", -4, 0)
	closeButton:SetText("X")
	closeButton:SetScript("OnClick", function()
		local db = LegionRemix:GetDB()
		if db then db.overlayHidden = true end
		LegionRemix:UpdateOverlay()
	end)

	local lockButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	lockButton:SetSize(58, 24)
	lockButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)
	lockButton:SetText(T("Lock", "Lock"))
	lockButton:SetScript("OnClick", function()
		local db = LegionRemix:GetDB()
		if not db then return end
		db.locked = not db.locked
		lockButton:SetText(db.locked and T("Unlock", "Unlock") or T("Lock", "Lock"))
	end)

	local filterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	filterBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	filterBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)
	filterBar:SetHeight(24)
	filterBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
	filterBar:SetBackdropColor(0.03, 0.03, 0.06, 0.8)

	local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	content:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -10)
	content:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -10)
	content:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 16)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 16)

	frame.collapsedHeight = header:GetHeight() + 28
	frame.filterBar = filterBar
	frame.header = header
	frame.title = title
	frame.bronzeText = bronzeText
	frame.remainingText = remainingText
	frame.collapseButton = collapse
	frame.lockButton = lockButton
	frame.content = content
	self.overlay = frame
	self:ApplyAnchor(frame)
	self:BuildFilterButtons()
	self:UpdateFilterButtons()
	return frame
end

function LegionRemix:UpdateOverlay()
	if not self:ShouldOverlayBeVisible() then
		if self.overlay then self.overlay:Hide() end
		return
	end

	local frame = self:CreateOverlay()
	if not frame then return end

	local db = self:GetDB()
	frame:Show()
	setButtonTexture(frame.collapseButton, db and db.collapsed)
	if frame.lockButton then
		frame.lockButton:SetText(db and db.locked and T("Unlock", "Unlock") or T("Lock", "Lock"))
	end

	local activeSet, allActive = self:GetActivePhaseFilterSet()
	self:UpdateFilterButtons()

	local bronze = self:GetBronzeCurrency()
	local collected, total = self:GetFilteredOverallTotals()
	local remaining = math.max(total - collected, 0)

	frame.bronzeText:SetFormattedText("%s: %s", CURRENCY, formatBronze(bronze))
	if not allActive then
		local activeList = {}
		for phase in pairs(activeSet) do table.insert(activeList, phase) end
		table.sort(activeList)
		local labels = {}
		for _, phase in ipairs(activeList) do table.insert(labels, string.format(T("Phase %d", "Phase %d"), phase)) end
		frame.remainingText:SetFormattedText("%s (%s): %s", T("Total Remaining", "Total Remaining"), table.concat(labels, ", "), formatBronze(remaining))
	else
		frame.remainingText:SetFormattedText("%s: %s", T("Total Remaining", "Total Remaining"), formatBronze(remaining))
	end

	if db and db.collapsed then
		if frame.filterBar and frame.filterBar.hasButtons then frame.filterBar:Hide() end
		frame.content:Hide()
		frame:SetHeight(frame.collapsedHeight or 80)
		return
	end

	frame:SetHeight(frame.expandedHeight or 520)
	if frame.filterBar then
		if frame.filterBar.hasButtons then
			frame.filterBar:Show()
		else
			frame.filterBar:Hide()
		end
	end
	frame.content:Show()

	local categories = self.latestCategories or {}
	local visibleIndex = 0
	for _, data in ipairs(categories) do
		local display = self:BuildCategoryDisplay(data)
		if (display.totalCost or 0) > 0 then
			visibleIndex = visibleIndex + 1
			local row = self:GetRow(visibleIndex, frame.content)
			self:UpdateRow(row, display)
		end
	end
	self:HideUnusedRows(visibleIndex + 1)
end

function LegionRemix:SetOverlayEnabled(value)
	local db = self:GetDB()
	if not db then return end
	db.overlayEnabled = value and true or false
	if value then db.overlayHidden = false end
	self:UpdateOverlay()
end

function LegionRemix:SetCollapsed(value)
	local db = self:GetDB()
	if not db then return end
	db.collapsed = value and true or false
	self:UpdateOverlay()
end

function LegionRemix:SetOnlyInRemix(value)
	local db = self:GetDB()
	if not db then return end
	db.onlyInRemixZones = value and true or false
	self:UpdateOverlay()
end

function LegionRemix:SetClassOnly(value)
	local db = self:GetDB()
	if not db then return end
	db.classOnly = value and true or false
	self:InvalidateAllCaches()
	self:RefreshData()
end

function LegionRemix:SetEnhancedTracking(value)
	local db = self:GetDB()
	if not db then return end
	db.enhancedTracking = value and true or false
	self:InvalidateAllCaches()
	self:RefreshData()
end

function LegionRemix:ResetPosition()
	local db = self:GetDB()
	if not db then return end
	db.anchor = CopyTable(DEFAULTS.anchor)
	self:ApplyAnchor(self.overlay)
end

function LegionRemix:SetHidden(value)
	local db = self:GetDB()
	if not db then return end
	db.overlayHidden = value and true or false
	self:UpdateOverlay()
end

LegionRemix.refreshPending = false

function LegionRemix:RequestRefresh()
	if self.refreshPending then return end
	self.refreshPending = true
	C_Timer.After(0.25, function()
		self.refreshPending = false
		self:RefreshData()
	end)
end

local EVENT_TO_CACHE = {
	NEW_MOUNT_ADDED = "mounts",
	MOUNT_JOURNAL_USABILITY_CHANGED = "mounts",
	TOYS_UPDATED = "toys",
	PET_JOURNAL_LIST_UPDATE = "pets",
	TRANSMOG_COLLECTION_SOURCE_ADDED = "sets",
	TRANSMOG_COLLECTION_SOURCE_REMOVED = "sets",
	TRANSMOG_COLLECTION_UPDATED = "sets",
	TRANSMOG_SETS_UPDATE_FAVORITE = "sets",
	PLAYER_SPECIALIZATION_CHANGED = "sets",
}

function LegionRemix:OnEvent(event, arg1)
	if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
		self.playerClass = nil
		self:InvalidateAllCaches()
		self:RequestRefresh()
	elseif event == "CURRENCY_DISPLAY_UPDATE" then
		if not arg1 or arg1 == BRONZE_CURRENCY_ID then self:UpdateOverlay() end
	else
		local cacheKey = EVENT_TO_CACHE[event]
		if cacheKey then
			self.cache[cacheKey] = {}
		else
			self:InvalidateAllCaches()
		end
		self:RequestRefresh()
	end

	if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
		self:UpdateOverlay()
	end
end

function LegionRemix:RegisterEvents()
	if self.eventFrame then return end
	local frame = CreateFrame("Frame")
	self.eventFrame = frame
	frame:SetScript("OnEvent", function(_, event, ...)
		LegionRemix:OnEvent(event, ...)
	end)
	local events = {
		"PLAYER_LOGIN",
		"PLAYER_ENTERING_WORLD",
		"NEW_MOUNT_ADDED",
		"MOUNT_JOURNAL_USABILITY_CHANGED",
		"TOYS_UPDATED",
		"PET_JOURNAL_LIST_UPDATE",
		"TRANSMOG_COLLECTION_UPDATED",
		"TRANSMOG_COLLECTION_SOURCE_ADDED",
		"TRANSMOG_COLLECTION_SOURCE_REMOVED",
		"TRANSMOG_SETS_UPDATE_FAVORITE",
		"PLAYER_SPECIALIZATION_CHANGED",
		"CURRENCY_DISPLAY_UPDATE",
		"ZONE_CHANGED_NEW_AREA",
		"ZONE_CHANGED",
		"ZONE_CHANGED_INDOORS",
	}
	for _, event in ipairs(events) do
		frame:RegisterEvent(event)
	end
end

function LegionRemix:Init()
	if self.initialized then return end
	if not addon.db then return end
	self:GetDB()
	self:InvalidateAllCaches()
	self:RegisterEvents()
	self.initialized = true
	self:RefreshData()
end

local function addSpacer(container)
	local spacer = AceGUI:Create("Label")
	spacer:SetFullWidth(true)
	spacer:SetText(" ")
	container:AddChild(spacer)
end

local function addCheckbox(container, text, getter, setter)
	local checkbox = AceGUI:Create("CheckBox")
	checkbox:SetLabel(text)
	checkbox:SetValue(getter())
	checkbox:SetFullWidth(true)
	checkbox:SetCallback("OnValueChanged", function(_, _, val) setter(val and true or false) end)
	container:AddChild(checkbox)
	return checkbox
end

function LegionRemix:BuildOptionsUI(container)
	container:ReleaseChildren()
	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("List")
	container:AddChild(scroll)

	local intro = AceGUI:Create("Label")
	intro:SetFullWidth(true)
	intro:SetText(T("Track your Legion Remix Bronze collection, inspired by the community WeakAura.", "Track your Legion Remix Bronze collection, inspired by the community WeakAura."))
	scroll:AddChild(intro)

	addSpacer(scroll)

	addCheckbox(scroll, T("Enable overlay", "Enable overlay"), function()
		local db = LegionRemix:GetDB()
		return db and db.overlayEnabled
	end, function(value) LegionRemix:SetOverlayEnabled(value) end)

	addCheckbox(scroll, T("Show only in Legion Remix zones", "Show only in Legion Remix zones"), function()
		local db = LegionRemix:GetDB()
		return db and db.onlyInRemixZones
	end, function(value) LegionRemix:SetOnlyInRemix(value) end)

	addCheckbox(scroll, T("Collapse progress list by default", "Collapse progress list by default"), function()
		local db = LegionRemix:GetDB()
		return db and db.collapsed
	end, function(value) LegionRemix:SetCollapsed(value) end)

	addCheckbox(scroll, T("Lock overlay position", "Lock overlay position"), function()
		local db = LegionRemix:GetDB()
		return db and db.locked
	end, function(value)
		local db = LegionRemix:GetDB()
		if db then
			db.locked = value
			if LegionRemix.overlay and LegionRemix.overlay.lockButton then
				LegionRemix.overlay.lockButton:SetText(value and T("Unlock", "Unlock") or T("Lock", "Lock"))
			end
		end
	end)

	addSpacer(scroll)

	addCheckbox(scroll, T("Only consider sets wearable by the current character", "Only consider sets wearable by the current character"), function()
		local db = LegionRemix:GetDB()
		return db and db.classOnly
	end, function(value) LegionRemix:SetClassOnly(value) end)

	addCheckbox(scroll, T("Enhanced transmog tracking (slower on login)", "Enhanced transmog tracking (slower on login)"), function()
		local db = LegionRemix:GetDB()
		return db and db.enhancedTracking
	end, function(value) LegionRemix:SetEnhancedTracking(value) end)

	local phases = LegionRemix:GetAllPhases()
	if #phases > 0 then
		addSpacer(scroll)
		local phaseLabel = AceGUI:Create("Label")
		phaseLabel:SetFullWidth(true)
		phaseLabel:SetText(T("Filter by release phase to focus on current drops.", "Filter by release phase to focus on current drops."))
		scroll:AddChild(phaseLabel)

		local phaseCheckboxes = {}
		local function refreshPhaseCheckboxes()
			for _, phase in ipairs(phases) do
				local checkbox = phaseCheckboxes[phase]
				if checkbox then checkbox:SetValue(LegionRemix:IsPhaseActive(phase)) end
			end
		end

		for _, phase in ipairs(phases) do
			local checkbox = AceGUI:Create("CheckBox")
			checkbox:SetLabel(string.format(T("Phase %d", "Phase %d"), phase))
			checkbox:SetFullWidth(true)
			checkbox:SetValue(LegionRemix:IsPhaseActive(phase))
			checkbox:SetCallback("OnValueChanged", function(_, _, val)
				LegionRemix:SetPhaseFilter(phase, val)
				refreshPhaseCheckboxes()
			end)
			scroll:AddChild(checkbox)
			phaseCheckboxes[phase] = checkbox
		end

		local clearBtn = AceGUI:Create("Button")
		clearBtn:SetText(T("Show all phases", "Show all phases"))
		clearBtn:SetWidth(160)
		clearBtn:SetCallback("OnClick", function()
			LegionRemix:ResetPhaseFilters()
			refreshPhaseCheckboxes()
		end)
		scroll:AddChild(clearBtn)
	end

	addSpacer(scroll)

	local buttonsGroup = AceGUI:Create("SimpleGroup")
	buttonsGroup:SetLayout("Flow")
	buttonsGroup:SetFullWidth(true)
	scroll:AddChild(buttonsGroup)

	local showBtn = AceGUI:Create("Button")
	showBtn:SetText(T("Show overlay", "Show overlay"))
	showBtn:SetWidth(160)
	showBtn:SetCallback("OnClick", function()
		LegionRemix:SetHidden(false)
		LegionRemix:SetOverlayEnabled(true)
	end)
	buttonsGroup:AddChild(showBtn)

	local hideBtn = AceGUI:Create("Button")
	hideBtn:SetText(T("Hide overlay", "Hide overlay"))
	hideBtn:SetWidth(160)
	hideBtn:SetCallback("OnClick", function()
		LegionRemix:SetHidden(true)
	end)
	buttonsGroup:AddChild(hideBtn)

	local resetBtn = AceGUI:Create("Button")
	resetBtn:SetText(T("Reset position", "Reset position"))
	resetBtn:SetWidth(160)
	resetBtn:SetCallback("OnClick", function() LegionRemix:ResetPosition() end)
	buttonsGroup:AddChild(resetBtn)

	local refreshBtn = AceGUI:Create("Button")
	refreshBtn:SetText(T("Refresh now", "Refresh now"))
	refreshBtn:SetWidth(160)
	refreshBtn:SetCallback("OnClick", function() LegionRemix:RefreshData() end)
	buttonsGroup:AddChild(refreshBtn)

	addSpacer(scroll)

	local status = AceGUI:Create("Label")
	status:SetFullWidth(true)
	local remaining = math.max((LegionRemix.totalCost or 0) - (LegionRemix.totalCollected or 0), 0)
	status:SetText(string.format(T("Remaining Bronze: %s", "Remaining Bronze: %s"), formatBronze(remaining)))
	scroll:AddChild(status)
end

LegionRemix.functions = LegionRemix.functions or {}

function LegionRemix.functions.treeCallback(container, group)
	LegionRemix:Init()
	LegionRemix:BuildOptionsUI(container)
end
