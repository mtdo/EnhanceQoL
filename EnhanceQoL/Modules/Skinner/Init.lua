local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Skinner = addon.Skinner or {}
addon.Skinner.functions = addon.Skinner.functions or {}
addon.Skinner.variables = addon.Skinner.variables or {}

local function isCharacterFrameSkinEnabled() return addon.db and addon.db.skinnerCharacterFrameEnabled == true end

local characterSlotNames = {
	"CharacterHeadSlot",
	"CharacterNeckSlot",
	"CharacterShoulderSlot",
	"CharacterBackSlot",
	"CharacterChestSlot",
	"CharacterShirtSlot",
	"CharacterTabardSlot",
	"CharacterWristSlot",
	"CharacterHandsSlot",
	"CharacterWaistSlot",
	"CharacterLegsSlot",
	"CharacterFeetSlot",
	"CharacterFinger0Slot",
	"CharacterFinger1Slot",
	"CharacterTrinket0Slot",
	"CharacterTrinket1Slot",
	"CharacterMainHandSlot",
	"CharacterSecondaryHandSlot",
}

local PAPERDOLL_SLOT_TEXTURE = "Interface\\CharacterFrame\\Char-Paperdoll-Parts"
local PAPERDOLL_SLOT_TEXTURE_ID = (type(GetFileIDFromPath) == "function") and GetFileIDFromPath(PAPERDOLL_SLOT_TEXTURE) or nil

local function hideSlotTexture(texture)
	if not texture then return end
	if texture.SetAtlas then texture:SetAtlas(nil) end
	if texture.SetTexture then texture:SetTexture(nil) end
	if texture.SetAlpha then texture:SetAlpha(0) end
	if texture.Hide then texture:Hide() end
end

local function lockTextureHidden(texture)
	if not texture then return end
	hideSlotTexture(texture)
	if texture.SetColorTexture then texture:SetColorTexture(0, 0, 0, 0) end
	if texture.SetShown then texture:SetShown(false) end
	if texture.eqolLockedHidden then return end
	texture.eqolLockedHidden = true
	texture.Show = function() end
	texture.SetShown = function() end
end

local function setTextureAlpha(texture, alpha)
	if not texture or not texture.SetAlpha then return end
	texture:SetAlpha(alpha)
	if texture.Show then texture:Show() end
end

local FLAT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 0.9 }
local FLAT_PANEL_BG = { r = 0.06, g = 0.06, b = 0.06, a = 0.5 }
local FLAT_SLOT_BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.6 }
local FLAT_TAB_BG = { r = FLAT_PANEL_BG.r, g = FLAT_PANEL_BG.g, b = FLAT_PANEL_BG.b, a = FLAT_PANEL_BG.a }
local FLAT_TAB_BG_SELECTED = { r = 0.10, g = 0.10, b = 0.10, a = math.min(1, FLAT_PANEL_BG.a + 0.15) }
local FLAT_HEADER_BG = { r = FLAT_PANEL_BG.r, g = FLAT_PANEL_BG.g, b = FLAT_PANEL_BG.b, a = FLAT_PANEL_BG.a }
local FLAT_CLOSE_BG = { r = FLAT_HEADER_BG.r, g = FLAT_HEADER_BG.g, b = FLAT_HEADER_BG.b, a = FLAT_HEADER_BG.a }
local FLAT_CLOSE_BG_HOVER = { r = 0.09, g = 0.09, b = 0.09, a = FLAT_HEADER_BG.a }
local FLAT_BUTTON_BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.65 }
local FLAT_BUTTON_BG_HOVER = { r = 0.12, g = 0.12, b = 0.12, a = 0.75 }
local FLAT_BUTTON_BG_DISABLED = { r = 0.05, g = 0.05, b = 0.05, a = 0.5 }
local FLAT_BUTTON_TEXT_ENABLED = { r = 1, g = 0.82, b = 0 }
local FLAT_BUTTON_TEXT_DISABLED = { r = 0.6, g = 0.6, b = 0.6 }
local FLAT_TITLE_TEXT = { r = 0.9, g = 0.75, b = 0.2 }
local FLAT_TITLE_TEXT_SELECTED = { r = 1, g = 0.82, b = 0 }
local FLAT_TITLE_TEXT_HOVER = { r = 1, g = 1, b = 1 }
local FLAT_TITLE_HOVER_BG = { r = 0.06, g = 0.06, b = 0.06, a = 0.75 }
local FLAT_TITLE_SELECTED_BG = { r = 0.32, g = 0.24, b = 0.08, a = 0.65 }
local FLAT_DROPDOWN_BG = { r = 0.07, g = 0.07, b = 0.07, a = 0.65 }
local FLAT_STATS_ROW_BG = { r = 0.35, g = 0.35, b = 0.35, a = 0.62 }
local FLAT_STATS_ROW_BG_INSET_X = 4
local FLAT_STATS_ROW_BG_INSET_Y = 2
local FLAT_HEADER_HEIGHT = 20
local FLAT_HEADER_TOP = 4
local FLAT_HEADER_PAD = 0
local FLAT_CLOSE_SIZE = 16
local DEFAULT_SIDEBAR_TAB_WIDTH = 33
local DEFAULT_SIDEBAR_TAB_HEIGHT = 35
local DEFAULT_SIDEBAR_TABS_WIDTH = 168
local DEFAULT_SIDEBAR_TABS_HEIGHT = 35

local function getCharacterFrameSkinAlpha()
	local alpha = addon.db and addon.db.skinnerCharacterFrameAlpha
	if alpha == nil then return FLAT_PANEL_BG.a end
	alpha = tonumber(alpha) or FLAT_PANEL_BG.a
	if alpha < 0 then alpha = 0 end
	if alpha > 1 then alpha = 1 end
	return alpha
end

local function getCharacterFrameBorderSettings()
	local enabled = addon.db and addon.db.skinnerCharacterFrameBorderEnabled == true
	local size = tonumber(addon.db and addon.db.skinnerCharacterFrameBorderSize) or 1
	if size < 1 then size = 1 end
	local col = addon.db and addon.db.skinnerCharacterFrameBorderColor
	if type(col) ~= "table" then col = FLAT_BORDER_COLOR end
	local r = col.r or FLAT_BORDER_COLOR.r
	local g = col.g or FLAT_BORDER_COLOR.g
	local b = col.b or FLAT_BORDER_COLOR.b
	local a = col.a
	if a == nil then a = FLAT_BORDER_COLOR.a end
	return enabled, size, { r = r, g = g, b = b, a = a }
end

local function createFlatBorder(frame, key)
	if not frame then return nil end
	local enabled, size, color = getCharacterFrameBorderSettings()
	if not enabled then
		if frame[key] then frame[key]:Hide() end
		return nil
	end
	local border = frame[key]
	if not border then
		border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		frame[key] = border
	end
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size - 3)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = size })
	border:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	border:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
	border:Show()
	return border
end

local updateTitleButtonState

local function applyTitleButtonFlatSkin(button)
	if not button then return end

	lockTextureHidden(button.BgTop)
	lockTextureHidden(button.BgBottom)
	lockTextureHidden(button.BgMiddle)
	lockTextureHidden(button.Stripe)
	lockTextureHidden(button.SelectedBar)

	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then lockTextureHidden(highlight) end

	if not button.eqolFlatTitle then
		button.eqolFlatTitle = true

		button.eqolTitleBg = button:CreateTexture(nil, "BACKGROUND")
		button.eqolTitleBg:SetAllPoints(button)
		button.eqolTitleBg:SetColorTexture(0, 0, 0, 0)

		button.eqolTitleSelected = button:CreateTexture(nil, "BACKGROUND")
		button.eqolTitleSelected:SetAllPoints(button)
		button.eqolTitleSelected:SetColorTexture(FLAT_TITLE_SELECTED_BG.r, FLAT_TITLE_SELECTED_BG.g, FLAT_TITLE_SELECTED_BG.b, FLAT_TITLE_SELECTED_BG.a)
		button.eqolTitleSelected:Hide()

		button.eqolTitleHover = button:CreateTexture(nil, "BACKGROUND")
		button.eqolTitleHover:SetAllPoints(button)
		button.eqolTitleHover:SetColorTexture(FLAT_TITLE_HOVER_BG.r, FLAT_TITLE_HOVER_BG.g, FLAT_TITLE_HOVER_BG.b, FLAT_TITLE_HOVER_BG.a)
		button.eqolTitleHover:Hide()

		button:HookScript("OnEnter", function(self)
			if self.eqolTitleHover and not self.eqolTitleSelected:IsShown() then
				self.eqolTitleHover:Show()
				if self.text and self.text.SetTextColor then self.text:SetTextColor(FLAT_TITLE_TEXT_HOVER.r, FLAT_TITLE_TEXT_HOVER.g, FLAT_TITLE_TEXT_HOVER.b) end
			end
		end)
		button:HookScript("OnLeave", function(self)
			if self.eqolTitleHover then self.eqolTitleHover:Hide() end
			if self.text and self.text.SetTextColor and not (self.eqolTitleSelected and self.eqolTitleSelected:IsShown()) then
				self.text:SetTextColor(FLAT_TITLE_TEXT.r, FLAT_TITLE_TEXT.g, FLAT_TITLE_TEXT.b)
			end
		end)
	end

	if button.text and button.text.SetTextColor then button.text:SetTextColor(FLAT_TITLE_TEXT.r, FLAT_TITLE_TEXT.g, FLAT_TITLE_TEXT.b) end
	if button.eqolTitleBg and button.eqolTitleBg.SetDrawLayer then button.eqolTitleBg:SetDrawLayer("BACKGROUND", 0) end
	if button.eqolTitleSelected and button.eqolTitleSelected.SetDrawLayer then button.eqolTitleSelected:SetDrawLayer("BACKGROUND", 1) end
	if button.eqolTitleHover and button.eqolTitleHover.SetDrawLayer then button.eqolTitleHover:SetDrawLayer("BACKGROUND", 2) end

	local selected = false
	if button.titleId and _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane then
		selected = _G.PaperDollFrame.TitleManagerPane.selected == button.titleId
	elseif button.Check and button.Check.IsShown then
		selected = button.Check:IsShown()
	end
	updateTitleButtonState(button, selected)
end

updateTitleButtonState = function(button, selected)
	if not button or not button.eqolFlatTitle then return end
	if button.eqolTitleSelected then
		if selected then
			button.eqolTitleSelected:Show()
		else
			button.eqolTitleSelected:Hide()
		end
	end
	if button.eqolTitleHover then
		if selected then button.eqolTitleHover:Hide() end
	end
	if button.text and button.text.SetTextColor then
		local col = selected and FLAT_TITLE_TEXT_SELECTED or FLAT_TITLE_TEXT
		button.text:SetTextColor(col.r, col.g, col.b)
	end
end

local function applyFlatBackground(frame, key, color, inset)
	if not frame then return nil end
	if frame[key] then return frame[key] end
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", inset or 0, -(inset or 0))
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset or 0), inset or 0)
	bg:SetColorTexture(color.r, color.g, color.b, color.a)
	frame[key] = bg
	return bg
end

local function applyCharacterSlotFlatSkin(slot)
	if not slot then return end
	if not slot.eqolFlatSlot then
		slot.eqolFlatSlot = true

		if slot.icon and slot.icon.SetTexCoord then slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

		applyFlatBackground(slot, "eqolFlatBg", FLAT_SLOT_BG, 0)

		local highlight = slot.GetHighlightTexture and slot:GetHighlightTexture()
		if highlight then
			highlight:SetColorTexture(1, 1, 1, 0.08)
			highlight:SetAllPoints(slot)
		end
	end
	if slot.eqolFlatBorder then slot.eqolFlatBorder:Hide() end
end

local function applyFlatButtonSkin(button)
	if not button then return end
	if not button.eqolFlatButton then
		button.eqolFlatButton = true

		hideSlotTexture(button:GetNormalTexture())
		hideSlotTexture(button:GetPushedTexture())
		hideSlotTexture(button:GetHighlightTexture())
		hideSlotTexture(button:GetDisabledTexture())
		hideSlotTexture(button.Left)
		hideSlotTexture(button.Middle)
		hideSlotTexture(button.Right)
		hideSlotTexture(button.LeftDisabled)
		hideSlotTexture(button.MiddleDisabled)
		hideSlotTexture(button.RightDisabled)
		hideSlotTexture(button.LeftHighlight)
		hideSlotTexture(button.MiddleHighlight)
		hideSlotTexture(button.RightHighlight)

		button.eqolFlatBg = button:CreateTexture(nil, "BACKGROUND")
		button.eqolFlatBg:SetAllPoints(button)
		button.eqolFlatBg:SetColorTexture(FLAT_BUTTON_BG.r, FLAT_BUTTON_BG.g, FLAT_BUTTON_BG.b, FLAT_BUTTON_BG.a)

		if button.SetNormalFontObject then button:SetNormalFontObject("GameFontHighlight") end
		if button.SetHighlightFontObject then button:SetHighlightFontObject("GameFontHighlight") end
		if button.SetDisabledFontObject then button:SetDisabledFontObject("GameFontDisable") end
		local label = button.GetFontString and button:GetFontString()

		local function setState(isEnabled)
			if button.eqolFlatBg then
				local col = isEnabled and FLAT_BUTTON_BG or FLAT_BUTTON_BG_DISABLED
				button.eqolFlatBg:SetColorTexture(col.r, col.g, col.b, col.a)
			end
			if label and label.SetTextColor then
				local col = isEnabled and FLAT_BUTTON_TEXT_ENABLED or FLAT_BUTTON_TEXT_DISABLED
				label:SetTextColor(col.r, col.g, col.b)
			end
		end

		setState(button.IsEnabled and button:IsEnabled())

		button:HookScript("OnEnter", function(self)
			if self.IsEnabled and self:IsEnabled() and self.eqolFlatBg then
				self.eqolFlatBg:SetColorTexture(FLAT_BUTTON_BG_HOVER.r, FLAT_BUTTON_BG_HOVER.g, FLAT_BUTTON_BG_HOVER.b, FLAT_BUTTON_BG_HOVER.a)
			end
		end)
		button:HookScript("OnLeave", function(self) setState(self.IsEnabled and self:IsEnabled()) end)
		button:HookScript("OnEnable", function() setState(true) end)
		button:HookScript("OnDisable", function() setState(false) end)
	end
	if button.eqolFlatBorder then button.eqolFlatBorder:Hide() end
end

local function applyFlatDropdownSkin(dropdown)
	if not dropdown then return end
	if not dropdown.eqolFlatDropdown then
		dropdown.eqolFlatDropdown = true

		if dropdown.Background then hideSlotTexture(dropdown.Background) end
		if dropdown.Left then hideSlotTexture(dropdown.Left) end
		if dropdown.Middle then hideSlotTexture(dropdown.Middle) end
		if dropdown.Right then hideSlotTexture(dropdown.Right) end

		dropdown.eqolFlatBg = dropdown:CreateTexture(nil, "BACKGROUND")
		dropdown.eqolFlatBg:SetPoint("TOPLEFT", dropdown, "TOPLEFT", -2, 2)
		dropdown.eqolFlatBg:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 2, -2)
		dropdown.eqolFlatBg:SetColorTexture(FLAT_DROPDOWN_BG.r, FLAT_DROPDOWN_BG.g, FLAT_DROPDOWN_BG.b, FLAT_DROPDOWN_BG.a)

		if dropdown.Arrow and dropdown.Arrow.SetDesaturation then
			dropdown.Arrow:SetDesaturation(1)
			dropdown.Arrow:SetVertexColor(1, 1, 1, 0.85)
		end
	end
	if dropdown.eqolFlatBorder then dropdown.eqolFlatBorder:Hide() end
end

local function updateFlatTabState(tab, selected)
	if not tab or not tab.eqolFlatBg then return end
	local alpha = getCharacterFrameSkinAlpha()
	local col = selected and { r = FLAT_TAB_BG_SELECTED.r, g = FLAT_TAB_BG_SELECTED.g, b = FLAT_TAB_BG_SELECTED.b, a = math.min(1, alpha + 0.15) }
		or { r = FLAT_TAB_BG.r, g = FLAT_TAB_BG.g, b = FLAT_TAB_BG.b, a = alpha }
	tab.eqolFlatBg:SetColorTexture(col.r, col.g, col.b, col.a)
end

local function updateSidebarTabState(tab, selected)
	if not tab or not tab.eqolFlatBg then return end
	local alpha = getCharacterFrameSkinAlpha()
	local base = { r = FLAT_HEADER_BG.r, g = FLAT_HEADER_BG.g, b = FLAT_HEADER_BG.b, a = alpha }
	local col = selected and { r = FLAT_TAB_BG_SELECTED.r, g = FLAT_TAB_BG_SELECTED.g, b = FLAT_TAB_BG_SELECTED.b, a = math.min(1, alpha + 0.15) } or base
	tab.eqolFlatBg:SetColorTexture(col.r, col.g, col.b, col.a)
	if tab.Icon and tab.Icon.SetDesaturation then tab.Icon:SetDesaturation(selected and 0 or 1) end
	if tab.Icon and tab.Icon.SetAlpha then tab.Icon:SetAlpha(selected and 1 or 0.75) end
end

local function applySidebarTabFlatSkin(tab, index)
	if not tab or tab.eqolFlatTab then return end
	tab.eqolFlatTab = true

	hideSlotTexture(tab.TabBg)
	hideSlotTexture(tab.Hider)
	hideSlotTexture(tab.Highlight)

	tab.eqolFlatBg = tab:CreateTexture(nil, "BACKGROUND")
	tab.eqolFlatBg:SetAllPoints(tab)
	updateSidebarTabState(tab, false)

	tab:SetSize(DEFAULT_SIDEBAR_TAB_WIDTH, DEFAULT_SIDEBAR_TAB_HEIGHT)
	if tab.Icon and tab.Icon.ClearAllPoints then
		tab.Icon:ClearAllPoints()
		tab.Icon:SetSize(DEFAULT_SIDEBAR_TAB_WIDTH, DEFAULT_SIDEBAR_TAB_HEIGHT)
		tab.Icon:SetPoint("BOTTOM", tab, "BOTTOM", 1, -2)
	end
	if tab.Icon and tab.Icon.SetTexCoord and _G.PAPERDOLL_SIDEBARS and _G.PAPERDOLL_SIDEBARS[index or tab:GetID()] then
		local tcoords = _G.PAPERDOLL_SIDEBARS[index or tab:GetID()].texCoords
		if tcoords then tab.Icon:SetTexCoord(tcoords[1], tcoords[2], tcoords[3], tcoords[4]) end
	end
end

local function applyCharacterTabFlatSkin(tab)
	if not tab then return end
	if not tab.eqolFlatTab then
		tab.eqolFlatTab = true

		local keys = {
			"Left",
			"Middle",
			"Right",
			"LeftDisabled",
			"MiddleDisabled",
			"RightDisabled",
			"LeftHighlight",
			"MiddleHighlight",
			"RightHighlight",
			"HighlightTexture",
		}
		for _, key in ipairs(keys) do
			hideSlotTexture(tab[key])
		end

		tab.eqolFlatBg = tab:CreateTexture(nil, "BACKGROUND")
		tab.eqolFlatBg:SetAllPoints(tab)
		updateFlatTabState(tab, false)

		tab.selectedTextY = 0
		tab.deselectedTextY = 0
		tab.selectedTextX = 0
		tab.deselectedTextX = 0
		if tab.Text then
			tab.Text:ClearAllPoints()
			tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 0)
		end
	end
	if tab.eqolFlatBorder then tab.eqolFlatBorder:Hide() end
end

local function applyCharacterTabsFlatSkin()
	local tabs = {
		_G.CharacterFrameTab1,
		_G.CharacterFrameTab2,
		_G.CharacterFrameTab3,
	}
	for _, tab in ipairs(tabs) do
		if tab then
			applyCharacterTabFlatSkin(tab)
			if _G.PanelTemplates_GetSelectedTab and _G.CharacterFrame and tab.GetID then updateFlatTabState(tab, tab:GetID() == PanelTemplates_GetSelectedTab(CharacterFrame)) end
		end
	end
	if _G.CharacterFrameTab1 and _G.CharacterFrameTab2 then
		_G.CharacterFrameTab2:ClearAllPoints()
		_G.CharacterFrameTab2:SetPoint("TOPLEFT", _G.CharacterFrameTab1, "TOPRIGHT", 0, 0)
	end
	if _G.CharacterFrameTab2 and _G.CharacterFrameTab3 then
		_G.CharacterFrameTab3:ClearAllPoints()
		_G.CharacterFrameTab3:SetPoint("TOPLEFT", _G.CharacterFrameTab2, "TOPRIGHT", 0, 0)
	end

	if addon.variables and addon.variables.eqolTabHooks then return end
	addon.variables = addon.variables or {}
	addon.variables.eqolTabHooks = true
	hooksecurefunc("PanelTemplates_SelectTab", function(tab)
		if tab and tab.eqolFlatTab then updateFlatTabState(tab, true) end
	end)
	hooksecurefunc("PanelTemplates_DeselectTab", function(tab)
		if tab and tab.eqolFlatTab then updateFlatTabState(tab, false) end
	end)
end

local function applyCharacterSidebarTabsFlatSkin()
	local tabsFrame = _G.PaperDollSidebarTabs
	if not tabsFrame then return end

	local insetRight = _G.CharacterFrameInsetRight
	tabsFrame:SetParent(insetRight or _G.CharacterFrame or tabsFrame:GetParent())
	tabsFrame:ClearAllPoints()
	if insetRight then
		tabsFrame:SetPoint("BOTTOMRIGHT", insetRight, "TOPRIGHT", -6, -1)
	else
		tabsFrame:SetPoint("TOPRIGHT", _G.CharacterFrame, "TOPRIGHT", -36, -(FLAT_HEADER_TOP + FLAT_HEADER_HEIGHT + 8))
	end
	tabsFrame:SetFrameStrata(((_G.CharacterFrame and _G.CharacterFrame:GetFrameStrata()) or tabsFrame:GetFrameStrata()))
	tabsFrame:SetFrameLevel(((_G.CharacterFrame and _G.CharacterFrame:GetFrameLevel()) or 1) + 12)
	tabsFrame.eqolReparent = true

	hideSlotTexture(tabsFrame.DecorLeft)
	hideSlotTexture(tabsFrame.DecorRight)

	local count = (type(_G.PAPERDOLL_SIDEBARS) == "table") and #_G.PAPERDOLL_SIDEBARS or 3
	tabsFrame:SetSize(DEFAULT_SIDEBAR_TABS_WIDTH, DEFAULT_SIDEBAR_TABS_HEIGHT)
	local tab3 = _G.PaperDollSidebarTab3
	local tab2 = _G.PaperDollSidebarTab2
	local tab1 = _G.PaperDollSidebarTab1
	if tab3 then
		tab3:ClearAllPoints()
		tab3:SetPoint("BOTTOMRIGHT", tabsFrame, "BOTTOMRIGHT", -30, 0)
	end
	if tab2 then
		tab2:ClearAllPoints()
		if tab3 then
			tab2:SetPoint("RIGHT", tab3, "LEFT", -4, 0)
		else
			tab2:SetPoint("BOTTOMRIGHT", tabsFrame, "BOTTOMRIGHT", -30, 0)
		end
	end
	if tab1 then
		tab1:ClearAllPoints()
		if tab2 then
			tab1:SetPoint("RIGHT", tab2, "LEFT", -4, 0)
		else
			tab1:SetPoint("BOTTOMRIGHT", tabsFrame, "BOTTOMRIGHT", -30, 0)
		end
	end
	for i = 1, count do
		local tab = _G["PaperDollSidebarTab" .. i]
		if tab then
			applySidebarTabFlatSkin(tab, i)
			local sideFrame = _G.GetPaperDollSideBarFrame and _G.GetPaperDollSideBarFrame(i)
			updateSidebarTabState(tab, sideFrame and sideFrame:IsShown())
		end
	end

	tabsFrame:Show()

	if addon.variables and addon.variables.eqolSidebarTabHooks then return end
	addon.variables = addon.variables or {}
	addon.variables.eqolSidebarTabHooks = true
	hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
		local count2 = (type(_G.PAPERDOLL_SIDEBARS) == "table") and #_G.PAPERDOLL_SIDEBARS or 3
		for i = 1, count2 do
			local tab = _G["PaperDollSidebarTab" .. i]
			if tab then
				hideSlotTexture(tab.TabBg)
				hideSlotTexture(tab.Hider)
				hideSlotTexture(tab.Highlight)
				local sideFrame = _G.GetPaperDollSideBarFrame and _G.GetPaperDollSideBarFrame(i)
				updateSidebarTabState(tab, sideFrame and sideFrame:IsShown())
			end
		end
	end)
end

local function applyCharacterStatsPaneFlatSkin()
	local pane = _G.CharacterStatsPane
	if not pane then return end

	if pane.eqolFlatPanel then pane.eqolFlatPanel:Hide() end

	if pane.ClassBackground then hideSlotTexture(pane.ClassBackground) end
	if pane.EnhancementsCategory and pane.EnhancementsCategory.Background then hideSlotTexture(pane.EnhancementsCategory.Background) end
	if pane.AttributesCategory and pane.AttributesCategory.Background then hideSlotTexture(pane.AttributesCategory.Background) end
	if pane.ItemLevelCategory and pane.ItemLevelCategory.Background then hideSlotTexture(pane.ItemLevelCategory.Background) end
	if pane.ItemLevelFrame and pane.ItemLevelFrame.Background then hideSlotTexture(pane.ItemLevelFrame.Background) end

	local function applyStatsRowBackgrounds()
		local function setFlatRowBackground(tex, owner)
			if not tex or not tex.SetColorTexture then return end
			if tex.SetAtlas then tex:SetAtlas(nil) end
			if tex.ClearAllPoints and owner then
				tex:ClearAllPoints()
				tex:SetPoint("TOPLEFT", owner, "TOPLEFT", FLAT_STATS_ROW_BG_INSET_X, -FLAT_STATS_ROW_BG_INSET_Y)
				tex:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -FLAT_STATS_ROW_BG_INSET_X, FLAT_STATS_ROW_BG_INSET_Y)
			end
			tex:SetColorTexture(FLAT_STATS_ROW_BG.r, FLAT_STATS_ROW_BG.g, FLAT_STATS_ROW_BG.b, FLAT_STATS_ROW_BG.a)
		end

		if pane.statsFramePool and pane.statsFramePool.EnumerateActive then
			for frame in pane.statsFramePool:EnumerateActive() do
				if frame.Background then setFlatRowBackground(frame.Background, frame) end
			end
		end
	end

	applyStatsRowBackgrounds()
	if addon.variables and addon.variables.eqolStatsRowHook then return end
	addon.variables = addon.variables or {}
	addon.variables.eqolStatsRowHook = true
	hooksecurefunc("PaperDollFrame_UpdateStats", function() applyStatsRowBackgrounds() end)
end

local function applyCharacterFrameHeaderSkin()
	local frame = _G.CharacterFrame
	if not frame then return end
	local headerAlpha = getCharacterFrameSkinAlpha()

	if not frame.eqolHeader then
		local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", FLAT_HEADER_PAD, -FLAT_HEADER_TOP)
		header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FLAT_HEADER_PAD, -FLAT_HEADER_TOP)
		header:SetHeight(FLAT_HEADER_HEIGHT)
		header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		header:SetBackdropColor(FLAT_HEADER_BG.r, FLAT_HEADER_BG.g, FLAT_HEADER_BG.b, headerAlpha)
		header:SetFrameStrata(frame:GetFrameStrata())
		header:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
		frame.eqolHeader = header
	else
		frame.eqolHeader:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		frame.eqolHeader:SetBackdropColor(FLAT_HEADER_BG.r, FLAT_HEADER_BG.g, FLAT_HEADER_BG.b, headerAlpha)
	end

	if frame.TitleContainer and frame.eqolHeader then
		frame.TitleContainer:ClearAllPoints()
		frame.TitleContainer:SetPoint("TOPLEFT", frame.eqolHeader, "TOPLEFT", 6, -1)
		frame.TitleContainer:SetPoint("BOTTOMRIGHT", frame.eqolHeader, "BOTTOMRIGHT", -6, 1)
		frame.TitleContainer:SetFrameStrata(frame.eqolHeader:GetFrameStrata())
		frame.TitleContainer:SetFrameLevel(frame.eqolHeader:GetFrameLevel() + 1)
	end

	local close = frame.CloseButton
	if close and not close.eqolFlatClose then
		close.eqolFlatClose = true
		close:ClearAllPoints()
		close:SetPoint("RIGHT", frame.eqolHeader or frame, "RIGHT", -FLAT_HEADER_PAD, 0)
		close:SetSize(FLAT_CLOSE_SIZE, FLAT_CLOSE_SIZE)

		hideSlotTexture(close:GetNormalTexture())
		hideSlotTexture(close:GetPushedTexture())
		hideSlotTexture(close:GetHighlightTexture())
		hideSlotTexture(close:GetDisabledTexture())

		close.eqolBg = close:CreateTexture(nil, "BACKGROUND")
		close.eqolBg:SetAllPoints(close)
		close.eqolBg:SetColorTexture(FLAT_CLOSE_BG.r, FLAT_CLOSE_BG.g, FLAT_CLOSE_BG.b, headerAlpha)

		if close.eqolFlatBorder then close.eqolFlatBorder:Hide() end

		close.eqolX1 = close:CreateTexture(nil, "OVERLAY")
		close.eqolX1:SetSize(10, 2)
		close.eqolX1:SetPoint("CENTER")
		close.eqolX1:SetColorTexture(1, 0.9, 0.9, 0.9)
		close.eqolX1:SetRotation(math.rad(45))

		close.eqolX2 = close:CreateTexture(nil, "OVERLAY")
		close.eqolX2:SetSize(10, 2)
		close.eqolX2:SetPoint("CENTER")
		close.eqolX2:SetColorTexture(1, 0.9, 0.9, 0.9)
		close.eqolX2:SetRotation(math.rad(-45))

		close:HookScript("OnEnter", function()
			local col = close.eqolBgHoverColor or FLAT_CLOSE_BG_HOVER
			if close.eqolBg then close.eqolBg:SetColorTexture(col.r, col.g, col.b, col.a) end
			if close.eqolX1 then close.eqolX1:SetColorTexture(1, 0.8, 0.8, 1) end
			if close.eqolX2 then close.eqolX2:SetColorTexture(1, 0.8, 0.8, 1) end
		end)
		close:HookScript("OnLeave", function()
			local col = close.eqolBgColor or FLAT_CLOSE_BG
			if close.eqolBg then close.eqolBg:SetColorTexture(col.r, col.g, col.b, col.a) end
			if close.eqolX1 then close.eqolX1:SetColorTexture(1, 0.9, 0.9, 0.9) end
			if close.eqolX2 then close.eqolX2:SetColorTexture(1, 0.9, 0.9, 0.9) end
		end)
	end

	if close and close.eqolBg then
		close.eqolBgColor = close.eqolBgColor or {}
		close.eqolBgColor.r = FLAT_CLOSE_BG.r
		close.eqolBgColor.g = FLAT_CLOSE_BG.g
		close.eqolBgColor.b = FLAT_CLOSE_BG.b
		close.eqolBgColor.a = headerAlpha
		close.eqolBgHoverColor = close.eqolBgHoverColor or {}
		close.eqolBgHoverColor.r = FLAT_CLOSE_BG_HOVER.r
		close.eqolBgHoverColor.g = FLAT_CLOSE_BG_HOVER.g
		close.eqolBgHoverColor.b = FLAT_CLOSE_BG_HOVER.b
		close.eqolBgHoverColor.a = headerAlpha
		close.eqolBg:SetColorTexture(close.eqolBgColor.r, close.eqolBgColor.g, close.eqolBgColor.b, close.eqolBgColor.a)
	end
end

local function applyCharacterFrameFlatSkin()
	local frame = _G.CharacterFrame
	if not frame then return end

	if frame.Background then hideSlotTexture(frame.Background) end
	hideSlotTexture(_G.CharacterFrameBg)
	if frame.TopTileStreaks then hideSlotTexture(frame.TopTileStreaks) end
	if frame.Inset then
		if frame.Inset.Bg then hideSlotTexture(frame.Inset.Bg) end
		if frame.Inset.NineSlice and _G.NineSliceUtil then NineSliceUtil.SetLayoutShown(frame.Inset.NineSlice, false) end
	end

	applyCharacterFrameHeaderSkin()
	createFlatBorder(frame, "eqolOuterBorder")
	local panelAlpha = getCharacterFrameSkinAlpha()
	if not frame.eqolBodyBg then
		local bodyBg = frame:CreateTexture(nil, "BACKGROUND")
		bodyBg:SetPoint("TOPLEFT", frame, "TOPLEFT", FLAT_HEADER_PAD, -(FLAT_HEADER_TOP + FLAT_HEADER_HEIGHT))
		bodyBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FLAT_HEADER_PAD, FLAT_HEADER_PAD)
		bodyBg:SetColorTexture(FLAT_PANEL_BG.r, FLAT_PANEL_BG.g, FLAT_PANEL_BG.b, panelAlpha)
		frame.eqolBodyBg = bodyBg
	else
		frame.eqolBodyBg:SetColorTexture(FLAT_PANEL_BG.r, FLAT_PANEL_BG.g, FLAT_PANEL_BG.b, panelAlpha)
	end
	applyCharacterTabsFlatSkin()
	applyCharacterSidebarTabsFlatSkin()
	applyCharacterStatsPaneFlatSkin()

	applyFlatButtonSkin(_G.PaperDollFrameEquipSet)
	applyFlatButtonSkin(_G.PaperDollFrameSaveSet)
	applyFlatDropdownSkin(_G.ReputationFrame and _G.ReputationFrame.filterDropdown)
	applyFlatDropdownSkin(_G.TokenFrame and _G.TokenFrame.filterDropdown)

	local titlePane = _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane
	if titlePane then
		hideSlotTexture(titlePane.Background)
		hideSlotTexture(titlePane.Bg)
		hideSlotTexture(titlePane.Border)
	end
	if _G.PaperDollTitlesPane_InitButton and not (addon.variables and addon.variables.eqolTitleButtonHook) then
		addon.variables = addon.variables or {}
		addon.variables.eqolTitleButtonHook = true
		hooksecurefunc("PaperDollTitlesPane_InitButton", function(button) applyTitleButtonFlatSkin(button) end)
		hooksecurefunc("PaperDollTitlesPane_SetButtonSelected", function(button, selected) updateTitleButtonState(button, selected) end)
	end
end

local function stripCharacterSlotNormalTexture(slot)
	if not slot then return end
	local normalTexture = slot.GetNormalTexture and slot:GetNormalTexture()
	if not normalTexture and slot.NormalTexture then normalTexture = slot.NormalTexture end
	hideSlotTexture(normalTexture)
end

local function isPaperDollSlotTexture(region)
	if not region or (region.IsObjectType and not region:IsObjectType("Texture")) then return false end
	if not region.GetTexture then return false end
	local tex = region:GetTexture()
	if not tex then return false end
	if type(tex) == "number" then return PAPERDOLL_SLOT_TEXTURE_ID ~= nil and tex == PAPERDOLL_SLOT_TEXTURE_ID end
	if type(tex) == "string" then return tex:find("CharacterFrame\\Char%-Paperdoll%-Parts") ~= nil end
	return false
end

local function stripCharacterSlotArtwork(slot)
	if not slot then return end
	stripCharacterSlotNormalTexture(slot)

	local frameTexture = slot.GetName and _G[slot:GetName() .. "Frame"]
	hideSlotTexture(frameTexture)

	local regions = { slot:GetRegions() }
	for i = 1, #regions do
		local region = regions[i]
		if isPaperDollSlotTexture(region) then hideSlotTexture(region) end
	end

	applyCharacterSlotFlatSkin(slot)
end

local function stripCharacterSlotNormalTextures()
	for _, name in ipairs(characterSlotNames) do
		stripCharacterSlotArtwork(_G[name])
	end

	hideSlotTexture(_G.PaperDollInnerBorderBottom2)
	hideSlotTexture(_G.PaperDollInnerBorderBottom)
	hideSlotTexture(_G.PaperDollInnerBorderBottomRight)
	hideSlotTexture(_G.PaperDollInnerBorderBottomLeft)
	hideSlotTexture(_G.PaperDollInnerBorderRight)
	hideSlotTexture(_G.PaperDollInnerBorderLeft)
	hideSlotTexture(_G.PaperDollInnerBorderTop)
	hideSlotTexture(_G.PaperDollInnerBorderTopRight)
	hideSlotTexture(_G.PaperDollInnerBorderTopLeft)
	hideSlotTexture(_G.CharacterModelFrameBackgroundOverlay)

	if _G.CharacterFrame and _G.CharacterFrame.NineSlice then
		hideSlotTexture(_G.CharacterFrame.NineSlice.TopLeftCorner)
		hideSlotTexture(_G.CharacterFrame.NineSlice.TopEdge)
		hideSlotTexture(_G.CharacterFrame.NineSlice.LeftEdge)
		hideSlotTexture(_G.CharacterFrame.NineSlice.BottomLeftCorner)
		hideSlotTexture(_G.CharacterFrame.NineSlice.BottomEdge)
		hideSlotTexture(_G.CharacterFrame.NineSlice.BottomRightCorner)
		hideSlotTexture(_G.CharacterFrame.NineSlice.RightEdge)
		hideSlotTexture(_G.CharacterFrame.NineSlice.TopRightCorner)
	end
	hideSlotTexture(_G.CharacterFramePortrait)
	if _G.CharacterFrame and _G.CharacterFrame.PortraitContainer then _G.CharacterFrame.PortraitContainer:Hide() end

	hideSlotTexture(_G.CharacterFrameBg)
	if _G.CharacterFrameInsetRight then
		_G.CharacterFrameInsetRight:Show()
		if _G.CharacterFrameInsetRight.Bg then hideSlotTexture(_G.CharacterFrameInsetRight.Bg) end
		if _G.CharacterFrameInsetRight.NineSlice and _G.NineSliceUtil then NineSliceUtil.SetLayoutShown(_G.CharacterFrameInsetRight.NineSlice, false) end
	end

	applyCharacterFrameFlatSkin()
end

local function applyCharacterFrameSkin()
	if not isCharacterFrameSkinEnabled() then return end
	stripCharacterSlotNormalTextures()
end

addon.Skinner.functions.ApplyCharacterFrameSkin = applyCharacterFrameSkin

function addon.Skinner.functions.InitDB()
	if addon.functions and addon.functions.InitDBValue then
		addon.functions.InitDBValue("skinnerCharacterFrameEnabled", false)
		addon.functions.InitDBValue("skinnerCharacterFrameAlpha", FLAT_PANEL_BG.a)
		addon.functions.InitDBValue("skinnerCharacterFrameBorderEnabled", true)
		addon.functions.InitDBValue("skinnerCharacterFrameBorderSize", 1)
		addon.functions.InitDBValue("skinnerCharacterFrameBorderColor", {
			r = FLAT_BORDER_COLOR.r,
			g = FLAT_BORDER_COLOR.g,
			b = FLAT_BORDER_COLOR.b,
			a = FLAT_BORDER_COLOR.a,
		})
	end
end

function addon.Skinner.functions.InitSettings()
	if addon.Skinner.variables.settingsBuilt then return end
	if not addon.SettingsLayout or not addon.SettingsLayout.rootUI then return end
	if not addon.functions or not addon.functions.SettingsCreateExpandableSection then return end

	addon.Skinner.variables.settingsBuilt = true

	local category = addon.SettingsLayout.rootUI
	local expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = "Skinner",
		expanded = false,
		colorizeTitle = false,
	})

	addon.Skinner.variables.settingsExpandable = expandable

	addon.functions.SettingsCreateSlider(category, {
		var = "skinnerCharacterFrameAlpha",
		text = "Character Frame Alpha",
		default = FLAT_PANEL_BG.a,
		min = 0,
		max = 1,
		step = 0.05,
		set = function(value)
			addon.db["skinnerCharacterFrameAlpha"] = value
			if addon.Skinner and addon.Skinner.functions and addon.Skinner.functions.ApplyCharacterFrameSkin and isCharacterFrameSkinEnabled() then
				addon.Skinner.functions.ApplyCharacterFrameSkin()
			end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "skinnerCharacterFrameEnabled",
		text = "Character Frame",
		default = false,
		func = function(value)
			addon.db["skinnerCharacterFrameEnabled"] = value
			if value then
				if addon.Skinner and addon.Skinner.functions and addon.Skinner.functions.ApplyCharacterFrameSkin then addon.Skinner.functions.ApplyCharacterFrameSkin() end
			else
				addon.variables = addon.variables or {}
				addon.variables.requireReload = true
				if addon.functions and addon.functions.checkReloadFrame then addon.functions.checkReloadFrame() end
			end
		end,
		parentSection = expandable,
	})

	local borderToggle = addon.functions.SettingsCreateCheckbox(category, {
		var = "skinnerCharacterFrameBorderEnabled",
		text = "Outer Frame Border",
		default = true,
		func = function(value)
			addon.db["skinnerCharacterFrameBorderEnabled"] = value and true or false
			if addon.Skinner and addon.Skinner.functions and addon.Skinner.functions.ApplyCharacterFrameSkin and isCharacterFrameSkinEnabled() then
				addon.Skinner.functions.ApplyCharacterFrameSkin()
			end
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateSlider(category, {
		var = "skinnerCharacterFrameBorderSize",
		text = "Outer Border Size",
		default = 1,
		min = 1,
		max = 6,
		step = 1,
		set = function(value)
			addon.db["skinnerCharacterFrameBorderSize"] = value
			if addon.Skinner and addon.Skinner.functions and addon.Skinner.functions.ApplyCharacterFrameSkin and isCharacterFrameSkinEnabled() then
				addon.Skinner.functions.ApplyCharacterFrameSkin()
			end
		end,
		element = borderToggle and borderToggle.element,
		parentCheck = function() return addon.db and addon.db.skinnerCharacterFrameBorderEnabled == true end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateColorPicker(category, {
		var = "skinnerCharacterFrameBorderColor",
		text = "Outer Border Color",
		hasOpacity = true,
		callback = function()
			if addon.Skinner and addon.Skinner.functions and addon.Skinner.functions.ApplyCharacterFrameSkin and isCharacterFrameSkinEnabled() then
				addon.Skinner.functions.ApplyCharacterFrameSkin()
			end
		end,
		element = borderToggle and borderToggle.element,
		parentCheck = function() return addon.db and addon.db.skinnerCharacterFrameBorderEnabled == true end,
		parentSection = expandable,
	})
end
