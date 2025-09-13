local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_MythicPlus")

-- Lightweight World Map side-panel for Dungeon Portals, with a small tab
-- that sits together with the default Map Legend / Quest tabs. The panel
-- lists all teleports from addon.MythicPlus.variables.portalCompendium,
-- honoring favorites and the main teleport options where reasonable.

local f = CreateFrame("Frame")
local DISPLAY_MODE = "EQOL_DungeonPortals"

-- Cache some frequently used API
local FirstOwnedItemID
do
	local GetItemCount = C_Item.GetItemCount
	function FirstOwnedItemID(itemID)
		if type(itemID) == "table" then
			for _, id in ipairs(itemID) do
				if GetItemCount(id) > 0 then return id end
			end
			return itemID[1]
		end
		return itemID
	end
end

local function IsToyUsable(id)
	if not id or not PlayerHasToy(id) then return false end
	local tips = C_TooltipInfo.GetToyByItemID(id)
	if not tips or not tips.lines then return true end
	for _, line in pairs(tips.lines) do
		if line.type == 23 then -- requirement text; white = usable
			local c = line.leftColor
			if c and c.r == 1 and c.g == 1 and c.b == 1 then return true end
			return false
		end
	end
	return true
end

local function BuildSpellEntries()
	local faction = select(2, UnitFactionGroup("player"))
	local comp = addon.MythicPlus and addon.MythicPlus.variables and addon.MythicPlus.variables.portalCompendium
	if not comp then return {} end

	local out = {}
	local favorites = addon.db.teleportFavorites or {}

	local function shouldInclude(data, spellID)
		local aMapID = C_Map.GetBestMapForUnit("player")
		local ok = true
		if data.faction and data.faction ~= faction then ok = false end
		if data.map then
			if type(data.map) == "number" then
				ok = ok and (data.map == aMapID)
			elseif type(data.map) == "table" then
				ok = ok and (data.map[aMapID] == true)
			end
		end
		if addon.db["portalHideMissing"] then
			if data.isToy then
				ok = ok and IsToyUsable(data.toyID)
			elseif data.isItem then
				local iid = FirstOwnedItemID(data.itemID)
				ok = ok and (iid and C_Item.GetItemCount(iid) > 0)
			else
				ok = ok and C_SpellBook.IsSpellInSpellBook(spellID)
			end
		end
		if not ok and addon.db.teleportFavoritesIgnoreFilters and favorites[spellID] then ok = true end
		return ok
	end

	for _, section in pairs(comp) do
		local list = {}
		for spellID, data in pairs(section.spells) do
			if shouldInclude(data, spellID) then
				local known = (C_SpellBook.IsSpellInSpellBook(spellID) and not data.isToy)
					or (data.isToy and IsToyUsable(data.toyID))
					or (data.isItem and C_Item.GetItemCount(FirstOwnedItemID(data.itemID)) > 0)

				table.insert(list, {
					spellID = spellID,
					text = data.text,
					iconID = data.iconID,
					isToy = data.isToy,
					toyID = data.toyID,
					isItem = data.isItem,
					itemID = FirstOwnedItemID(data.itemID),
					isKnown = known,
					isFavorite = favorites[spellID] or false,
				})
			end
		end
		if #list > 0 then
			table.sort(list, function(a, b)
				if a.isFavorite ~= b.isFavorite then return a.isFavorite end
				if a.text ~= b.text then return a.text < b.text end
				return (a.spellID or 0) < (b.spellID or 0)
			end)
			table.insert(out, { title = section.headline, items = list })
		end
	end

	-- Favorites block on top (if any)
	local favs = {}
	for _, sec in ipairs(out) do
		for _, it in ipairs(sec.items) do
			if it.isFavorite then table.insert(favs, it) end
		end
	end
	if #favs > 0 then
		table.sort(favs, function(a, b) return a.text < b.text end)
		table.insert(out, 1, { title = FAVORITES, items = favs })
	end
	return out
end

-- Panel creation -----------------------------------------------------------
local panel -- content frame
local scrollBox
local function EnsurePanel(parent)
    local targetParent = QuestMapFrame or parent
    if panel and panel:GetParent() ~= targetParent then panel:SetParent(targetParent) end
    if panel then return panel end

    panel = CreateFrame("Frame", "EQOLWorldMapDungeonPortalsPanel", targetParent, "BackdropTemplate")
    panel:ClearAllPoints()

	local function anchorPanel()
        local host = panel:GetParent() or targetParent
        local ca = QuestMapFrame and QuestMapFrame.ContentsAnchor
        panel:ClearAllPoints()
        if ca and ca.GetWidth and ca:GetWidth() > 0 and ca:GetHeight() > 0 then
            panel:SetPoint("TOPLEFT", ca, "TOPLEFT", 0, 0)
            panel:SetPoint("BOTTOMRIGHT", ca, "BOTTOMRIGHT", 0, 0)
        else
            panel:SetAllPoints(host)
        end
    end

    anchorPanel()
	-- In case layout isn't ready on first tick, re-anchor shortly after
	C_Timer.After(0, anchorPanel)
	C_Timer.After(0.1, anchorPanel)
	-- Ensure our panel is on top of Blizzard content frames
    if QuestMapFrame then
        panel:SetFrameStrata("HIGH")
        panel:SetFrameLevel((QuestMapFrame:GetFrameLevel() or 0) + 200)
    else
        panel:SetFrameStrata("HIGH")
    end
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:Hide()

    -- QuestLog-like border frame
    if not panel.BorderFrame then
        local bf = CreateFrame("Frame", nil, panel, "QuestLogBorderFrameTemplate")
        bf:SetAllPoints(panel)
        panel.BorderFrame = bf
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "Game15Font_Shadow")
    -- Keep title inside the frame, slightly below top edge
    title:SetPoint("TOP", panel, "TOP", 0, -6)
    title:SetText(L["DungeonCompendium"] or "Dungeon Portals")
    panel.Title = title

	-- Scroll area
    local s = CreateFrame("ScrollFrame", "EQOLWorldMapDungeonPortalsScrollFrame", panel, "ScrollFrameTemplate")
    -- Inset to keep background and scrollbar inside border
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -28)
    s:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    -- Background inside the scrollframe similar to MapLegend
    if not s.Background then
        local bg = s:CreateTexture(nil, "BACKGROUND")
        if bg.SetAtlas then bg:SetAtlas("QuestLog-main-background", true) end
        bg:SetPoint("TOPLEFT")
        bg:SetPoint("BOTTOMRIGHT")
        s.Background = bg
    end

    -- Align scrollbar like MapLegend: x=+8, topY=+2, bottomY=-4
    if s.ScrollBar and not s._eqolBarAnchored then
        s.ScrollBar:ClearAllPoints()
        s.ScrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -24)
        s.ScrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 6)
        s._eqolBarAnchored = true
    end

    local content = CreateFrame("Frame", "EQOLWorldMapDungeonPortalsScrollChild", s)
    content:SetSize(1, 1)
    s:SetScrollChild(content)

    panel.Content = content
    panel.Scroll = s

    -- Ensure our interactive content renders above any sibling art
    local baseLevel = panel:GetFrameLevel() or 1
    s:SetFrameLevel(baseLevel + 1)
    content:SetFrameLevel(baseLevel + 2)

	scrollBox = content
	-- Integrate with QuestLog display system

	-- Keep content up-to-date if the scroll area changes size after layout
	if not s._eqolSizeHook then
		s:HookScript("OnSizeChanged", function()
			if panel and panel:IsShown() then f:RefreshPanel() end
		end)
		s._eqolSizeHook = true
	end
    panel.displayMode = DISPLAY_MODE
    return panel
end

local function ClearContent()
	if not scrollBox then return end
	for _, child in ipairs({ scrollBox:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
end

local function CreateSecureSpellButton(parent, entry)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    b:SetSize(28, 28)
    b.entry = entry

    -- Keep buttons above any background art
    if panel then
        b:SetFrameStrata(panel:GetFrameStrata())
        b:SetFrameLevel((panel:GetFrameLevel() or 1) + 10)
    end

	local tex = b:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(b)
	if entry.iconID then
		tex:SetTexture(entry.iconID)
	else
		tex:SetTexture(136121) -- generic portal swirl icon fallback
	end
	b.Icon = tex

	b.cooldownFrame = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cooldownFrame:SetAllPoints(b)
	b.cooldownFrame:SetSwipeColor(0, 0, 0, 0.35)

	-- Casting setup (Left click)
	if entry.isToy then
		b:SetAttribute("type1", "toy")
		b:SetAttribute("toy", entry.toyID)
	elseif entry.isItem then
		b:SetAttribute("type1", "item")
		b:SetAttribute("item", entry.itemID)
	else
		b:SetAttribute("type1", "spell")
		b:SetAttribute("spell", entry.spellID)
	end

	-- Favorite toggle (Right click)
	b:RegisterForClicks("AnyUp")
	b:SetScript("OnClick", function(self, btn)
		if btn == "RightButton" then
			local favs = addon.db.teleportFavorites or {}
			if favs[self.entry.spellID] then
				favs[self.entry.spellID] = nil
			else
				favs[self.entry.spellID] = true
			end
			addon.db.teleportFavorites = favs
			f:RefreshPanel() -- rebuild list to reflect favorite
		end
	end)

	b:SetScript("OnEnter", function(self)
		if not addon.db["portalShowTooltip"] then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if entry.isToy then
			GameTooltip:SetToyByItemID(entry.toyID)
		elseif entry.isItem then
			GameTooltip:SetItemByID(entry.itemID)
		else
			GameTooltip:SetSpellByID(entry.spellID)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- favorite star overlay
	local fav = b:CreateTexture(nil, "OVERLAY")
	fav:SetPoint("TOPRIGHT", 5, 5)
	fav:SetSize(14, 14)
	fav:SetAtlas("auctionhouse-icon-favorite")
	fav:SetShown(entry.isFavorite)
	b.FavOverlay = fav

	return b
end

local function PopulatePanel()
	if not panel then return end
	ClearContent()

	local sections = BuildSpellEntries()
	if not sections or #sections == 0 then
		local msg = (L["teleportCompendiumHeadline"] or "Teleports") .. ": None available"
		local label = scrollBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
		label:SetPoint("TOPLEFT", 10, -10)
		label:SetText(msg)
		scrollBox:SetHeight(40)
		return
	end

    local y = -25 -- topPadding like MapLegend
    local xStart = 12 -- leftPadding like MapLegend
	local x = xStart
    local scrollW = panel.Scroll:GetWidth()
	if not scrollW or scrollW <= 1 then
		local pw = panel:GetWidth() or 0
		if pw <= 1 then pw = (panel:GetParent() and panel:GetParent():GetWidth()) or 0 end
		scrollW = (pw > 1 and pw or 330) - 30
	end
    local maxWidth = math.max(100, scrollW - 12)
    local perRow = math.max(1, math.floor(maxWidth / 44))
	local countInRow = 0

	local function nextRow()
		y = y - 44
		x = xStart
		countInRow = 0
	end

	for _, section in ipairs(sections) do
        local header = scrollBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header:SetPoint("TOPLEFT", xStart - 2, y)
        header:SetText(section.title)
        y = y - 18

		for _, entry in ipairs(section.items) do
			if countInRow >= perRow then nextRow() end
			local b = CreateSecureSpellButton(scrollBox, entry)
			b:SetPoint("TOPLEFT", x, y)

			local label = scrollBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			label:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
			label:SetText(entry.text)

			-- cooldown display
			local cd
			if entry.isToy and entry.toyID then
				local st, dur, en = C_Item.GetItemCooldown(entry.toyID)
				cd = { startTime = st, duration = dur, modRate = 1, isEnabled = en }
			elseif entry.isItem and entry.itemID then
				local st, dur, en = C_Item.GetItemCooldown(entry.itemID)
				cd = { startTime = st, duration = dur, modRate = 1, isEnabled = en }
			else
				cd = C_Spell.GetSpellCooldown(entry.spellID)
			end
			if cd and cd.isEnabled and b.cooldownFrame then b.cooldownFrame:SetCooldown(cd.startTime, cd.duration, cd.modRate) end

			x = x + 44
			countInRow = countInRow + 1
		end
		nextRow()
	end

    scrollBox:SetHeight(math.abs(y) + 44)
    if panel.Scroll and panel.Scroll.UpdateScrollChildRect then panel.Scroll:UpdateScrollChildRect() end
end

-- Tab creation -------------------------------------------------------------
local tabButton
local function EnsureTab(parent, anchorTo)
	if tabButton and tabButton:GetParent() ~= parent then tabButton:SetParent(parent) end
	if tabButton then return tabButton end

    -- Use Blizzard QuestLog tab template for a perfect visual match
    tabButton = CreateFrame("Button", "EQOLWorldMapDungeonPortalsTab", parent, "QuestLogTabButtonTemplate")
	tabButton:SetSize(32, 32)
	if anchorTo then
		tabButton:SetPoint("TOP", anchorTo, "BOTTOM", 0, -15)
	else
		tabButton:SetPoint("TOPRIGHT", -6, -100)
	end

	-- Mirror hover/selected visuals via the template, but we'll supply our own icon
	tabButton.activeAtlas = "questlog-tab-icon-maplegend"
	tabButton.inactiveAtlas = "questlog-tab-icon-maplegend-inactive"
    tabButton.tooltipText = (L["DungeonCompendium"] or "Dungeon Portals")
    tabButton.displayMode = DISPLAY_MODE

	-- Hide template's atlas-driven icon and add our persistent custom icon
	if tabButton.Icon then tabButton.Icon:Hide() end
	local customIcon = tabButton:CreateTexture(nil, "ARTWORK")
	customIcon:SetPoint("CENTER", -2, 0)
	customIcon:SetSize(20, 20)
	customIcon:SetTexture("Interface\\AddOns\\EnhanceQoL\\Icons\\Dungeon.tga")
	customIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	tabButton.CustomIcon = customIcon

	-- Guard against Blizzard re-showing the template icon
	if tabButton.Icon and not tabButton.Icon._eqolHook then
		hooksecurefunc(tabButton.Icon, "Show", function(icon) icon:Hide() end)
		hooksecurefunc(tabButton.Icon, "SetAtlas", function(icon) icon:Hide() end)
		tabButton.Icon._eqolHook = true
	end

	-- make sure we're not selected by default
	if tabButton.SetChecked then tabButton:SetChecked(false) end
	if tabButton.SelectedTexture then tabButton.SelectedTexture:Hide() end

	-- Keep custom icon clear on state changes
	if not tabButton._eqolStateHooks then
		hooksecurefunc(tabButton, "SetChecked", function(self)
			if self.CustomIcon then self.CustomIcon:SetDesaturated(false) end
		end)
		hooksecurefunc(tabButton, "Disable", function(self)
			if self.CustomIcon then self.CustomIcon:SetDesaturated(true) end
		end)
		hooksecurefunc(tabButton, "Enable", function(self)
			if self.CustomIcon then self.CustomIcon:SetDesaturated(false) end
		end)
		tabButton._eqolStateHooks = true
	end

	tabButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText)
		GameTooltip:Show()
	end)
	tabButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	tabButton:SetScript("OnMouseUp", function(self, button, upInside)
		if button ~= "LeftButton" or not upInside then return end
		if not panel then return end
		if QuestMapFrame and QuestMapFrame.SetDisplayMode then
			QuestMapFrame:SetDisplayMode(DISPLAY_MODE)
		else
			-- Fallback: show our panel if SetDisplayMode not available
			panel:Show()
			f:RefreshPanel()
			if tabButton.SetChecked then tabButton:SetChecked(true) end
		end
	end)

    return tabButton
end

-- Glue into World Map ------------------------------------------------------
local initialized = false
function f:TryInit()
	if initialized then return end
	if not QuestMapFrame then return end

    local parent = QuestMapFrame
    EnsurePanel(parent)

	-- Re-anchor our panel whenever the map resizes or the content anchor becomes valid
	if not parent._eqolSizeHook then
		parent:HookScript("OnSizeChanged", function()
			if panel and panel:GetParent() then
				panel:ClearAllPoints()
				local ca = QuestMapFrame and QuestMapFrame.ContentsAnchor
                if ca and ca.GetWidth and ca:GetWidth() > 0 and ca:GetHeight() > 0 then
                    panel:SetPoint("TOPLEFT", ca, "TOPLEFT", 0, 0)
                    panel:SetPoint("BOTTOMRIGHT", ca, "BOTTOMRIGHT", 0, 0)
                else
                    panel:SetAllPoints(panel:GetParent())
                end
                f:RefreshPanel()
            end
        end)
		parent._eqolSizeHook = true
	end
	if QuestMapFrame.ContentsAnchor and not QuestMapFrame.ContentsAnchor._eqolSizeHook then
		QuestMapFrame.ContentsAnchor:HookScript("OnSizeChanged", function()
			if panel and panel:GetParent() then
				panel:ClearAllPoints()
				local ca = QuestMapFrame and QuestMapFrame.ContentsAnchor
                if ca and ca.GetWidth and ca:GetWidth() > 0 and ca:GetHeight() > 0 then
                    panel:SetPoint("TOPLEFT", ca, "TOPLEFT", 0, 0)
                    panel:SetPoint("BOTTOMRIGHT", ca, "BOTTOMRIGHT", 0, 0)
                else
                    panel:SetAllPoints(panel:GetParent())
                end
                f:RefreshPanel()
            end
        end)
		QuestMapFrame.ContentsAnchor._eqolSizeHook = true
	end

	-- Anchor the tab under the Map Legend tab if we can find it
	local anchor = QuestMapFrame.MapLegendTab or QuestMapFrame.QuestsTab or (QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame.BackFrame)
	EnsureTab(parent, anchor)

    -- Inject our panel into ContentFrames so SetDisplayMode can manage visibility
    if QuestMapFrame.ContentFrames then
        local exists = false
        for _, frame in ipairs(QuestMapFrame.ContentFrames) do
            if frame == panel then
                exists = true
                break
            end
        end
        if not exists then table.insert(QuestMapFrame.ContentFrames, panel) end
    end

    -- Also register our tab as a managed tab for consistent checked state
    if QuestMapFrame.TabButtons then
        local present = false
        for _, b in ipairs(QuestMapFrame.TabButtons) do
            if b == tabButton then present = true break end
        end
        if not present then table.insert(QuestMapFrame.TabButtons, tabButton) end
    end

	-- Track display mode changes to update our tab state and refresh content
	if EventRegistry and not f._eqolDisplayEvent then
		EventRegistry:RegisterCallback("QuestLog.SetDisplayMode", function(_, mode)
			if mode == DISPLAY_MODE then
				if tabButton and tabButton.SetChecked then tabButton:SetChecked(true) end
				if panel then panel:Show() end
				f:RefreshPanel()
			else
				if tabButton and tabButton.SetChecked then tabButton:SetChecked(false) end
				if panel then panel:Hide() end
			end
		end, f)
		f._eqolDisplayEvent = true
	end

	initialized = panel and tabButton
end

function f:RefreshPanel()
	if not panel or not panel:IsShown() then return end
	PopulatePanel()
end

-- Events to build/refresh --------------------------------------------------
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and (arg1 == "Blizzard_WorldMap" or arg1 == addonName or arg1 == parentAddonName)) then
		C_Timer.After(0.3, function()
			f:TryInit()
			f:RefreshPanel()
		end)
	elseif event == "SPELLS_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "TOYS_UPDATED" then
		f:RefreshPanel()
	end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("TOYS_UPDATED")

-- make sure we also initialize when the WorldMap opens
if WorldMapFrame and not WorldMapFrame._eqolTeleportHook then
	WorldMapFrame:HookScript("OnShow", function()
		f:TryInit()
		C_Timer.After(0, function() f:RefreshPanel() end)
	end)
	WorldMapFrame._eqolTeleportHook = true
end
