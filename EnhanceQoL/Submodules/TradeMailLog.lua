-- luacheck: globals GetTradePlayerItemInfo GetTradeTargetItemInfo GetTradePlayerItemLink GetTradeTargetItemLink GetPlayerTradeMoney GetTargetTradeMoney
-- luacheck: globals HasSendMailItem GetSendMailItem GetSendMailMoney GetSendMailCOD HasInboxItem GetInboxHeaderInfo GetInboxText GetInboxItem GetInboxItemLink
-- luacheck: globals SendMailNameEditBox SendMailSubjectEditBox SendMailBodyEditBox SendMailFrame_SendMail InboxFrame_OnClick
-- luacheck: globals ButtonFrameTemplate_HidePortrait SetTooltipMoney SetItemButtonQuality
-- luacheck: globals COPPER_PER_SILVER SILVER_PER_GOLD COPPER_PER_GOLD MAX_TRADE_ITEMS TRADE_ENCHANT_SLOT ATTACHMENTS_MAX_SEND ATTACHMENTS_MAX_RECEIVE ATTACHMENTS_PER_ROW_RECEIVE
-- luacheck: globals MAIL NO_SUBJECT TO EQOL_MailPreviewFrame EQOL_MailPreviewFrameInset
local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end
local L = addon.L or {}

local TradeMailLog = addon.TradeMailLog or {}
addon.TradeMailLog = TradeMailLog

TradeMailLog.frame = TradeMailLog.frame or CreateFrame("Frame")
TradeMailLog.tradeState = TradeMailLog.tradeState or nil
TradeMailLog.pendingSend = TradeMailLog.pendingSend or nil
TradeMailLog.lastOpenIndex = TradeMailLog.lastOpenIndex or nil
TradeMailLog.lastOpenSignature = TradeMailLog.lastOpenSignature or nil
TradeMailLog.seq = TradeMailLog.seq or 0
TradeMailLog.mailHooksReady = TradeMailLog.mailHooksReady or false
TradeMailLog.itemTemplatesReady = TradeMailLog.itemTemplatesReady or false

local function now() return (GetServerTime and GetServerTime()) or time() end

local function trim(value)
	if not value then return "" end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function setFrameTitle(frame, text)
	if not frame then return end
	if frame.SetTitle then
		frame:SetTitle(text)
		return
	end
	local titleText = frame.TitleText
	if not titleText and frame.TitleContainer then titleText = frame.TitleContainer.TitleText end
	if titleText and titleText.SetText then titleText:SetText(text) end
end

local function setFramePortrait(frame, texture)
	if not frame or not texture then return end
	if frame.SetPortraitToAsset then
		frame:SetPortraitToAsset(texture)
		return
	end
	if frame.SetPortraitTextureRaw then
		frame:SetPortraitTextureRaw(texture)
		return
	end
	if frame.SetPortraitToTexture then
		frame:SetPortraitToTexture(texture)
		return
	end
	local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
	if portrait and portrait.SetTexture then portrait:SetTexture(texture) end
end

local function ensureItemTemplates()
	if TradeMailLog.itemTemplatesReady then return end
	if UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_ItemButton") end
	TradeMailLog.itemTemplatesReady = true
end

local function createItemButton(parent, size)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)

	local icon = button:CreateTexture(nil, "BORDER")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.icon = icon

	local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	count:SetJustifyH("RIGHT")
	count:Hide()
	button.Count = count

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Common\\WhiteIconFrame")
	border:SetAllPoints()
	border:Hide()
	button.IconBorder = border

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetAllPoints()
	overlay:Hide()
	button.IconOverlay = overlay

	local overlay2 = button:CreateTexture(nil, "OVERLAY")
	overlay2:SetAllPoints()
	overlay2:Hide()
	button.IconOverlay2 = overlay2

	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	return button
end

local function setItemButtonTextureSafe(button, texture)
	if SetItemButtonTexture then
		SetItemButtonTexture(button, texture)
	elseif button and button.icon then
		button.icon:SetTexture(texture)
		button.icon:SetShown(texture ~= nil)
	end
end

local function setItemButtonCountSafe(button, count)
	if SetItemButtonCount then
		SetItemButtonCount(button, count)
	elseif button and button.Count then
		if count and count > 1 then
			button.Count:SetText(count)
			button.Count:Show()
		else
			button.Count:Hide()
		end
	end
end

local function setItemButtonQualitySafe(button, quality, itemIDOrLink)
	if SetItemButtonQuality then
		SetItemButtonQuality(button, quality, itemIDOrLink)
		return
	end

	if button and button.IconOverlay then button.IconOverlay:Hide() end
	if button and button.IconOverlay2 then button.IconOverlay2:Hide() end
	if not button or not button.IconBorder then return end

	local minQuality = (Enum and Enum.ItemQuality and Enum.ItemQuality.Common) or 1
	if quality and quality > minQuality and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		if r then
			button.IconBorder:SetVertexColor(r, g, b)
			button.IconBorder:Show()
			return
		end
	end
	button.IconBorder:Hide()
end

local function getChannelHistory() return addon.ChatIM and addon.ChatIM.ChannelHistory or nil end

local function isHistoryEnabled()
	local history = getChannelHistory()
	if not history then return false end
	if not addon.db or not addon.db.enableChatHistory then return false end
	if history.enabled == false then return false end
	return true
end

local function canLog(filterKey)
	if not isHistoryEnabled() then return false end
	local history = getChannelHistory()
	if history and history.IsLoggingEnabled and not history:IsLoggingEnabled(filterKey) then return false end
	return true
end

local function nextId(prefix)
	TradeMailLog.seq = (TradeMailLog.seq or 0) + 1
	return string.format("%s-%d-%d", prefix or "eqol", now(), TradeMailLog.seq)
end

local function formatMoney(amount)
	if not amount or amount <= 0 then return nil end
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(amount) end
	if GetCoinTextureString then return GetCoinTextureString(amount) end
	if GetMoneyString then return GetMoneyString(amount) end
	return tostring(amount)
end

local function formatMoneyText(amount)
	if not amount or amount <= 0 then return nil end
	local copperPerSilver = COPPER_PER_SILVER or 100
	local silverPerGold = SILVER_PER_GOLD or 100
	local copperPerGold = COPPER_PER_GOLD or (copperPerSilver * silverPerGold)

	local gold = floor(amount / copperPerGold)
	local silver = floor((amount - (gold * copperPerGold)) / copperPerSilver)
	local copper = mod(amount, copperPerSilver)

	local goldSymbol = GOLD_AMOUNT_SYMBOL or "g"
	local silverSymbol = SILVER_AMOUNT_SYMBOL or "s"
	local copperSymbol = COPPER_AMOUNT_SYMBOL or "c"

	local function formatUnit(value, symbol, allowBreak)
		local display = value
		if allowBreak and BreakUpLargeNumbers then display = BreakUpLargeNumbers(value) end
		return string.format("%s%s", display, symbol)
	end

	local parts = {}
	if gold > 0 then parts[#parts + 1] = formatUnit(gold, goldSymbol, true) end
	if silver > 0 then parts[#parts + 1] = formatUnit(silver, silverSymbol, false) end
	if copper > 0 then parts[#parts + 1] = formatUnit(copper, copperSymbol, false) end
	return table.concat(parts, " ")
end

local function extractLinkName(link)
	if not link then return nil end
	return link:match("%[(.-)%]")
end

local function addSearchPart(parts, value)
	if not value or value == "" then return end
	parts[#parts + 1] = value
end

local function addItemSearch(parts, items)
	for _, item in ipairs(items or {}) do
		addSearchPart(parts, item.name)
		local linkName = extractLinkName(item.link)
		if linkName then addSearchPart(parts, linkName) end
	end
end

local function getTradeItemSlots()
	local maxSlots = MAX_TRADE_ITEMS or 6
	if TRADE_ENCHANT_SLOT and maxSlots == TRADE_ENCHANT_SLOT then maxSlots = maxSlots - 1 end
	if maxSlots < 1 then maxSlots = 1 end
	return maxSlots
end

local function getTradeItems(isTarget)
	local items = {}
	local maxSlots = getTradeItemSlots()
	for i = 1, maxSlots do
		local name, texture, count, quality
		if isTarget then
			name, texture, count, quality = GetTradeTargetItemInfo(i)
		else
			name, texture, count, quality = GetTradePlayerItemInfo(i)
		end
		if name then
			local link = isTarget and GetTradeTargetItemLink(i) or GetTradePlayerItemLink(i)
			local itemID = link and tonumber(link:match("item:(%d+)")) or nil
			items[#items + 1] = {
				name = name,
				link = link,
				itemID = itemID,
				texture = texture,
				count = count or 1,
				quality = quality,
				slot = i,
			}
		end
	end
	return items
end

local function makeLink(linkType, id, text)
	if not id then return text or "" end
	return string.format("|H%s:%s|h%s|h", linkType, id, text or "")
end

local function buildSideSummary(label, itemCount, moneyText)
	local itemLabel = (_G and _G.ITEMS) or "Items"
	local count = itemCount or 0
	local summary = string.format("%s x%d %s", label or "", count, itemLabel)
	if moneyText and moneyText ~= "" then summary = summary .. " - " .. moneyText end
	return summary
end

local function tradeStatusIcon(status)
	if status == "completed" then return "|A:ReadyCheck-Ready:14:14:0:0|a" end
	if status == "cancelled" then return "|A:ReadyCheck-NotReady:14:14:0:0|a" end
	return ""
end

local function buildTradeSummary(state, id)
	local tradeLabel = TRADE or "Trade"
	local youLabel = YOU or "You"
	local otherLabel = OTHER or "Other"
	local partner = state.partner or UNKNOWN or "Unknown"
	local youSummary = buildSideSummary(youLabel, #(state.playerItems or {}), formatMoneyText(state.playerMoney))
	local otherSummary = buildSideSummary(otherLabel, #(state.targetItems or {}), formatMoneyText(state.targetMoney))
	local base = string.format("%s - %s - %s - %s", tradeLabel, partner, youSummary, otherSummary)
	local icon = tradeStatusIcon(state.status)
	if icon ~= "" then base = icon .. " " .. base end
	return makeLink("eqoltrade", id, base)
end

local function buildTradeSearchText(state)
	local parts = {}
	addSearchPart(parts, "trade")
	addSearchPart(parts, state.status)
	if state.status == "cancelled" then addSearchPart(parts, "canceled") end
	if state.status == "completed" then addSearchPart(parts, "complete") end
	addSearchPart(parts, state.partner)
	addSearchPart(parts, state.zone)
	addSearchPart(parts, date("%Y-%m-%d %H:%M:%S", state.time or now()))
	addItemSearch(parts, state.playerItems)
	addItemSearch(parts, state.targetItems)
	return table.concat(parts, " "):lower()
end

local function buildMailSummary(data, id)
	local mailLabel = MAIL_LABEL or MAIL or INBOX or "Mail"
	local subject = data.subject or ""
	if subject == "" then subject = NO_SUBJECT or "" end
	local itemCount = #(data.items or {})
	local moneyText = formatMoneyText(data.money)
	if not moneyText then
		local goldSymbol = GOLD_AMOUNT_SYMBOL or "g"
		moneyText = string.format("0%s", goldSymbol)
	end

	local sentLabel = L["TL_FILTER_SENT_ONLY"] or "Sent"
	local receivedLabel = L["TL_FILTER_RECEIVED_ONLY"] or "Received"
	local toLabel = TO or "To"
	local fromLabel = FROM or "From"

	local whoText
	if data.direction == "sent" then
		local receiver = data.receiver or ""
		if receiver ~= "" then
			whoText = string.format("%s %s %s %s", sentLabel, mailLabel, toLabel, receiver)
		else
			whoText = string.format("%s %s", sentLabel, mailLabel)
		end
	else
		local sender = data.sender or ""
		if sender ~= "" then
			whoText = string.format("%s %s %s %s", receivedLabel, mailLabel, fromLabel, sender)
		else
			whoText = string.format("%s %s", receivedLabel, mailLabel)
		end
	end

	local itemLabel = (_G and _G.ITEMS) or "Items"
	local parts = { whoText }
	parts[#parts + 1] = subject
	parts[#parts + 1] = string.format("x%d %s", itemCount, itemLabel)
	parts[#parts + 1] = moneyText
	return makeLink("eqolmail", id, table.concat(parts, " - "))
end

local function buildMailSearchText(data)
	local parts = {}
	addSearchPart(parts, "mail")
	addSearchPart(parts, data.direction)
	addSearchPart(parts, data.sender)
	addSearchPart(parts, data.receiver)
	addSearchPart(parts, data.subject)
	addSearchPart(parts, data.body)
	addSearchPart(parts, data.zone)
	addSearchPart(parts, date("%Y-%m-%d %H:%M:%S", data.time or now()))
	if data.money and data.money > 0 then addSearchPart(parts, tostring(data.money)) end
	if data.cod and data.cod > 0 then
		addSearchPart(parts, "cod")
		addSearchPart(parts, tostring(data.cod))
	end
	addItemSearch(parts, data.items)
	return table.concat(parts, " "):lower()
end

local function setItemButtonData(button, item)
	if not button then return end
	if not item then
		button.money = nil
		button.itemLink = nil
		button.itemID = nil
		button.itemName = nil
		setItemButtonTextureSafe(button, nil)
		setItemButtonCountSafe(button, 0)
		setItemButtonQualitySafe(button, nil)
		button:Hide()
		return
	end
	button:Show()
	if item.money then
		button.money = item.money
		button.itemLink = nil
		button.itemID = nil
		button.itemName = item.name or (MONEY or "Money")
		setItemButtonTextureSafe(button, item.texture)
		setItemButtonCountSafe(button, 0)
		setItemButtonQualitySafe(button, nil)
		return
	end
	button.money = nil
	local texture = item.texture
	if not texture and item.itemID then texture = select(10, GetItemInfo(item.itemID)) end
	setItemButtonTextureSafe(button, texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	setItemButtonCountSafe(button, item.count or 1)
	local link = item.link
	if not link and item.itemID then link = select(2, GetItemInfo(item.itemID)) end
	if link or item.itemID then
		setItemButtonQualitySafe(button, item.quality, link or item.itemID)
	else
		setItemButtonQualitySafe(button, item.quality)
	end
	button.itemLink = link
	button.itemID = item.itemID
	button.itemName = item.name or extractLinkName(link) or item.itemID
end

local function setItemButtonTooltip(button)
	if not button or not GameTooltip then return end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	if button.money and SetTooltipMoney then
		SetTooltipMoney(GameTooltip, button.money)
		GameTooltip:Show()
		return
	end
	if button.money then
		GameTooltip:SetText(formatMoney(button.money) or tostring(button.money))
		GameTooltip:Show()
		return
	end
	if button.itemLink then
		GameTooltip:SetHyperlink(button.itemLink)
	elseif button.itemID then
		GameTooltip:SetItemByID(button.itemID)
	elseif button.itemName then
		GameTooltip:SetText(button.itemName)
	end
	GameTooltip:Show()
end

function TradeMailLog:UpdateTradeSnapshot()
	local state = self.tradeState
	if not state then return end
	state.playerItems = getTradeItems(false)
	state.targetItems = getTradeItems(true)
	state.playerMoney = GetPlayerTradeMoney and GetPlayerTradeMoney() or 0
	state.targetMoney = GetTargetTradeMoney and GetTargetTradeMoney() or 0
end

function TradeMailLog:StartTrade()
	local partner = GetUnitName and GetUnitName("NPC", true) or nil
	if not partner or partner == "" then
		local name, realm
		if UnitName then name, realm = UnitName("npc") end
		if name and realm then
			partner = name .. "-" .. realm
		else
			partner = name
		end
	end
	if not partner or partner == "" then partner = UNKNOWN or "Unknown" end

	self.tradeState = {
		kind = "trade",
		partner = partner,
		playerName = UnitName and UnitName("player") or "",
		zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or "",
		time = now(),
		playerAccepted = 0,
		targetAccepted = 0,
	}
	self:UpdateTradeSnapshot()
end

local function hasTradeContent(state)
	if not state then return false end
	if state.playerMoney and state.playerMoney > 0 then return true end
	if state.targetMoney and state.targetMoney > 0 then return true end
	if state.playerItems and #state.playerItems > 0 then return true end
	if state.targetItems and #state.targetItems > 0 then return true end
	return false
end

function TradeMailLog:FinishTrade()
	local state = self.tradeState
	if not state then return end

	local completed = state.playerAccepted == 1 and state.targetAccepted == 1
	state.completed = completed
	state.status = completed and "completed" or "cancelled"

	if canLog("TRADE") and (hasTradeContent(state) or completed or state.playerAccepted == 1 or state.targetAccepted == 1) then self:LogTrade(state) end
	self.tradeState = nil
end

function TradeMailLog:LogTrade(state)
	local history = getChannelHistory()
	if not history or not history.StoreCustom then return end
	local id = nextId("trade")
	state.id = id
	state.time = state.time or now()

	history:StoreCustom("TRADE", "TRADE", TRADE or "Trade", {
		message = buildTradeSummary(state, id),
		sender = "",
		searchText = buildTradeSearchText(state),
		eqolId = id,
		eqolType = "trade",
		eqolPayload = state,
	})
end

function TradeMailLog:CaptureSendMail()
	if not canLog("MAIL") then
		self.pendingSend = nil
		return
	end
	if not SendMailNameEditBox or not SendMailSubjectEditBox or not SendMailBodyEditBox then return end
	local recipient = trim(SendMailNameEditBox:GetText())
	if recipient == "" then return end
	local subject = SendMailSubjectEditBox:GetText() or ""
	local body = SendMailBodyEditBox:GetText() or ""
	local money = GetSendMailMoney and GetSendMailMoney() or 0
	local cod = GetSendMailCOD and GetSendMailCOD() or 0

	local items = {}
	local maxAttach = ATTACHMENTS_MAX_SEND or 12
	for i = 1, maxAttach do
		if HasSendMailItem and HasSendMailItem(i) then
			local name, itemID, texture, count, quality = GetSendMailItem(i)
			local link = itemID and select(2, GetItemInfo(itemID)) or nil
			items[#items + 1] = {
				name = name,
				link = link,
				itemID = itemID,
				texture = texture,
				count = count or 1,
				quality = quality,
				slot = i,
			}
		end
	end

	self.pendingSend = {
		kind = "mail",
		direction = "sent",
		sender = UnitName and UnitName("player") or "",
		receiver = recipient,
		subject = subject,
		body = body,
		money = money,
		cod = cod,
		items = items,
		zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or "",
		time = now(),
	}
end

function TradeMailLog:LogMail(data)
	local history = getChannelHistory()
	if not history or not history.StoreCustom then return end
	local id = nextId("mail")
	data.id = id
	data.time = data.time or now()

	history:StoreCustom("MAIL", "MAIL", MAIL_LABEL or MAIL or INBOX or "Mail", {
		message = buildMailSummary(data, id),
		sender = "",
		searchText = buildMailSearchText(data),
		eqolId = id,
		eqolType = "mail",
		eqolPayload = data,
	})
end

function TradeMailLog:LogInboxMail(index)
	if not canLog("MAIL") then return end
	if not index or not GetInboxHeaderInfo then return end

	local _, _, sender, subject, money, cod, daysLeft, itemCount, wasRead = GetInboxHeaderInfo(index)
	if not sender or sender == "" then sender = UNKNOWN or "Unknown" end
	subject = subject or ""
	local bodyText = ""
	if GetInboxText then bodyText = (GetInboxText(index) or "") or "" end

	local signature = table.concat({
		sender,
		subject,
		tostring(money or 0),
		tostring(cod or 0),
		tostring(daysLeft or 0),
		tostring(itemCount or 0),
		bodyText:sub(1, 24),
	}, "|")
	if self.lastOpenIndex == index and self.lastOpenSignature == signature then return end
	self.lastOpenIndex = index
	self.lastOpenSignature = signature

	local items = {}
	local maxAttach = ATTACHMENTS_MAX_RECEIVE or 16
	for i = 1, maxAttach do
		if HasInboxItem and HasInboxItem(index, i) then
			local name, itemID, texture, count, quality = GetInboxItem(index, i)
			local link = GetInboxItemLink and GetInboxItemLink(index, i) or nil
			items[#items + 1] = {
				name = name,
				link = link,
				itemID = itemID,
				texture = texture,
				count = count or 1,
				quality = quality,
				slot = i,
			}
		end
	end

	self:LogMail({
		kind = "mail",
		direction = "received",
		sender = sender,
		receiver = UnitName and UnitName("player") or "",
		subject = subject,
		body = bodyText,
		money = money or 0,
		cod = cod or 0,
		items = items,
		zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or "",
		time = now(),
	})
end

function TradeMailLog:EnsureMailHooks()
	if self.mailHooksReady then return end
	local sendHooked = self.sendHooked
	local inboxHooked = self.inboxHooked

	if not sendHooked and type(SendMailFrame_SendMail) == "function" then
		hooksecurefunc("SendMailFrame_SendMail", function() TradeMailLog:CaptureSendMail() end)
		self.sendHooked = true
		sendHooked = true
	end
	if not inboxHooked and type(InboxFrame_OnClick) == "function" then
		hooksecurefunc("InboxFrame_OnClick", function(_, index) TradeMailLog:LogInboxMail(index) end)
		self.inboxHooked = true
		inboxHooked = true
	end

	self.mailHooksReady = sendHooked and inboxHooked
end

function TradeMailLog:EnsureTradePreview()
	if self.tradePreview then return self.tradePreview end
	ensureItemTemplates()

	local frame = _G.EQOL_TradePreviewFrame
	if not frame then return nil end

	frame:ClearAllPoints()
	frame:SetParent(UIParent)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	local function hidePreview() frame:Hide() end
	if frame.CloseButton then frame.CloseButton:SetScript("OnClick", hidePreview) end

	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
	if frame.PortraitContainer then frame.PortraitContainer:Hide() end
	if frame.RecipientOverlay then frame.RecipientOverlay:Hide() end
	setFrameTitle(frame, TRADE or "Trade")

	frame.playerNameText = frame.NameHeader and frame.NameHeader.PlayerNameText or frame.PlayerNameText
	frame.recipientNameText = frame.NameHeader and frame.NameHeader.RecipientNameText or frame.RecipientNameText
	frame.playerMoneyText = frame.PlayerMoneyFrame and frame.PlayerMoneyFrame.Text or nil
	frame.recipientMoneyText = frame.RecipientMoneyFrame and frame.RecipientMoneyFrame.Text or nil

	local itemSize = 37
	frame.playerButtons = {}
	frame.targetButtons = {}
	frame.playerItemFrames = {}
	frame.targetItemFrames = {}
	for i = 1, getTradeItemSlots() do
		local playerFrame = frame["PlayerItem" .. i]
		if playerFrame then
			frame.playerItemFrames[i] = playerFrame
			local pBtn = createItemButton(playerFrame, itemSize)
			pBtn:SetPoint("TOPLEFT", playerFrame, "TOPLEFT", 0, 0)
			pBtn:SetScript("OnEnter", function(selfBtn) setItemButtonTooltip(selfBtn) end)
			pBtn:SetScript("OnLeave", GameTooltip_Hide)
			frame.playerButtons[i] = pBtn
		end

		local targetFrame = frame["RecipientItem" .. i]
		if targetFrame then
			frame.targetItemFrames[i] = targetFrame
			local tBtn = createItemButton(targetFrame, itemSize)
			tBtn:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", 0, 0)
			tBtn:SetScript("OnEnter", function(selfBtn) setItemButtonTooltip(selfBtn) end)
			tBtn:SetScript("OnLeave", GameTooltip_Hide)
			frame.targetButtons[i] = tBtn
		end
	end

	self.tradePreview = frame
	return frame
end

function TradeMailLog:EnsureMailPreview()
	if self.mailPreview then return self.mailPreview end
	local frame = _G.EQOL_MailPreviewFrame
	if not frame then return nil end

	frame:ClearAllPoints()
	frame:SetParent(UIParent) -- safety net, falls irgendwo doch nil/anders
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	local function hidePreview() frame:Hide() end
	if frame.CloseButton then frame.CloseButton:SetScript("OnClick", hidePreview) end
	if frame.CloseButtonBottom then frame.CloseButtonBottom:SetScript("OnClick", hidePreview) end

	frame.senderLabel = frame.SenderLabel
	frame.senderText = frame.Sender and frame.Sender.Name

	frame.Sender:ClearAllPoints()
	frame.Sender:SetPoint("TOPLEFT", frame.senderLabel, "TOPRIGHT", 5, 0)
	frame.Sender:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -12, -54)

	frame.subjectLabel = frame.SubjectLabel
	frame.subjectText = frame.SubjectText
	frame.subjectText:SetPoint("TOPLEFT", frame.subjectLabel, "TOPRIGHT", 5, -4)
	frame.scrollFrame = frame.ScrollFrame
	frame.scrollChild = frame.scrollFrame and frame.scrollFrame.ScrollChildFrame or nil
	frame.body = frame.scrollChild and frame.scrollChild.BodyText or frame.BodyText
	frame.stationeryLeft = frame.scrollFrame and frame.scrollFrame.StationeryBackgroundLeft or nil
	frame.stationeryRight = frame.scrollFrame and frame.scrollFrame.StationeryBackgroundRight or nil
	frame.stationeryRight:ClearAllPoints()
	frame.stationeryRight:SetPoint("TOPLEFT", frame.stationeryLeft, "TOPRIGHT", 0, 0)

	frame.attachmentsArea = frame.AttachmentsArea
	frame.attachmentsLabel = frame.AttachmentsArea and frame.AttachmentsArea.AttachmentsLabel or nil
	frame.attachmentsLabel:ClearAllPoints()
	frame.attachmentsLabel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 55)
	if frame.HorizontalBarLeft and frame.attachmentsArea then frame.HorizontalBarLeft:ClearAllPoints() end
	if frame.HorizontalBarRight and frame.HorizontalBarLeft then
		frame.HorizontalBarRight:ClearAllPoints()
		frame.HorizontalBarRight:SetPoint("LEFT", frame.HorizontalBarLeft, "RIGHT", 0, 0)
	end

	local itemSize = 34
	local spacing = 4
	local itemsPerRow = 7
	local startY = -18
	frame.attachmentItemSize = itemSize
	frame.attachmentSpacing = spacing
	frame.attachmentItemsPerRow = itemsPerRow
	frame.attachmentStartY = startY
	local areaWidth = frame.attachmentsArea and frame.attachmentsArea:GetWidth() or 0
	local rowWidth = (itemsPerRow * itemSize) + ((itemsPerRow - 1) * spacing)
	local startX = 0
	if areaWidth > rowWidth then startX = math.floor((areaWidth - rowWidth) / 2) end

	frame.attachmentButtons = frame.attachmentButtons or {}
	for i = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
		local btn = frame.attachmentButtons[i]
		if not btn then
			btn = createItemButton(frame.attachmentsArea or frame, itemSize)
			btn:SetScript("OnEnter", function(selfBtn) setItemButtonTooltip(selfBtn) end)
			btn:SetScript("OnLeave", GameTooltip_Hide)
			frame.attachmentButtons[i] = btn
		end
		btn:SetSize(itemSize, itemSize)
		if frame.attachmentsArea then
			local row = math.floor((i - 1) / itemsPerRow)
			local col = (i - 1) % itemsPerRow
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", frame.attachmentsArea, "TOPLEFT", startX + (col * (itemSize + spacing)), startY - (row * (itemSize + spacing)))
		end
	end

	self.mailPreview = frame
	return frame
end

function TradeMailLog:ShowTradePreview(payload)
	if not payload then return end
	local frame = self:EnsureTradePreview()
	if not frame then return end

	setFrameTitle(frame, TRADE or "Trade")

	local playerName = (payload.playerName and payload.playerName ~= "" and payload.playerName) or (UnitName and UnitName("player")) or (YOU or "You")
	if frame.playerNameText and frame.playerNameText.SetText then frame.playerNameText:SetText(playerName or "") end
	if frame.recipientNameText and frame.recipientNameText.SetText then frame.recipientNameText:SetText(payload.partner or "") end

	for i, button in ipairs(frame.playerButtons or {}) do
		local item = payload.playerItems and payload.playerItems[i]
		setItemButtonData(button, item)
		local itemFrame = frame.playerItemFrames and frame.playerItemFrames[i]
		if itemFrame and itemFrame.Name then
			local itemName = item and (item.name or extractLinkName(item.link)) or nil
			if item and itemName then
				itemFrame.Name:SetText(itemName)
				if item.quality and GetItemQualityColor then
					local r, g, b = GetItemQualityColor(item.quality)
					itemFrame.Name:SetTextColor(r, g, b)
				else
					itemFrame.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				end
			else
				itemFrame.Name:SetText("")
				itemFrame.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			end
		end
	end
	for i, button in ipairs(frame.targetButtons or {}) do
		local item = payload.targetItems and payload.targetItems[i]
		setItemButtonData(button, item)
		local itemFrame = frame.targetItemFrames and frame.targetItemFrames[i]
		if itemFrame and itemFrame.Name then
			local itemName = item and (item.name or extractLinkName(item.link)) or nil
			if item and itemName then
				itemFrame.Name:SetText(itemName)
				if item.quality and GetItemQualityColor then
					local r, g, b = GetItemQualityColor(item.quality)
					itemFrame.Name:SetTextColor(r, g, b)
				else
					itemFrame.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				end
			else
				itemFrame.Name:SetText("")
				itemFrame.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			end
		end
	end

	if frame.playerMoneyText and frame.playerMoneyText.SetText then frame.playerMoneyText:SetText(formatMoney(payload.playerMoney) or "") end
	if frame.recipientMoneyText and frame.recipientMoneyText.SetText then frame.recipientMoneyText:SetText(formatMoney(payload.targetMoney) or "") end

	frame:Show()
	frame:Raise()
end

function TradeMailLog:ShowMailPreview(payload)
	if not payload then return end
	local frame = self:EnsureMailPreview()
	if not frame then return end
	local mailLabel = MAIL_LABEL or MAIL or INBOX or "Mail"
	local sentLabel = L["TL_FILTER_SENT_ONLY"] or "Sent"
	local receivedLabel = L["TL_FILTER_RECEIVED_ONLY"] or "Received"
	local statusLabel = payload.direction == "sent" and sentLabel or receivedLabel
	local timeText = date("%Y-%m-%d %H:%M:%S", payload.time or now())
	setFrameTitle(frame, string.format("%s %s - %s", mailLabel, statusLabel, timeText))

	if frame.Icon then frame.Icon:SetTexture("Interface\\MailFrame\\Mail-Icon") end

	local senderLabel = payload.direction == "sent" and (TO or "To") or (FROM or "From")
	local senderText = payload.direction == "sent" and (payload.receiver or "") or (payload.sender or "")
	if frame.senderLabel and frame.senderLabel.SetText then frame.senderLabel:SetText(senderLabel) end
	if frame.senderText and frame.senderText.SetText then frame.senderText:SetText(senderText) end

	local subject = payload.subject or ""
	if subject == "" then subject = NO_SUBJECT or "" end
	if frame.subjectText and frame.subjectText.SetText then frame.subjectText:SetText(subject) end

	if frame.body and frame.body.SetText then frame.body:SetText(payload.body or "", true) end
	if frame.scrollFrame and frame.scrollFrame.SetVerticalScroll then frame.scrollFrame:SetVerticalScroll(0) end

	local displayItems = {}
	if payload.money and payload.money > 0 then
		local coinIcon = C_CurrencyInfo and C_CurrencyInfo.GetCoinIcon and C_CurrencyInfo.GetCoinIcon(payload.money) or nil
		if not coinIcon then coinIcon = "Interface\\Icons\\INV_Misc_Coin_01" end
		displayItems[#displayItems + 1] = {
			money = payload.money,
			texture = coinIcon,
			name = MONEY or "Money",
		}
	end
	for _, item in ipairs(payload.items or {}) do
		displayItems[#displayItems + 1] = item
	end

	local itemButtonCount = #displayItems
	local itemRowCount = (itemButtonCount > 0) and math.ceil(itemButtonCount / ATTACHMENTS_PER_ROW_RECEIVE) or 0

	local marginxl = 10 + 4
	local marginxr = 43 + 4
	local areax = EQOL_MailPreviewFrame:GetWidth() - marginxl - marginxr
	local iconx = 39
	local icony = 39
	local gapx1 = floor((areax - (iconx * ATTACHMENTS_PER_ROW_RECEIVE)) / (ATTACHMENTS_PER_ROW_RECEIVE - 1))
	local gapx2 = floor((areax - (iconx * ATTACHMENTS_PER_ROW_RECEIVE) - (gapx1 * (ATTACHMENTS_PER_ROW_RECEIVE - 1))) / 2)
	local gapy1 = 3
	local gapy2 = 3
	local areay = gapy2 + frame.attachmentsLabel:GetHeight() + gapy2 + (icony * itemRowCount) + (gapy1 * (itemRowCount - 1)) + gapy2
	local indentx = marginxl + gapx2
	local indenty = 28 + gapy2
	local tabx = (iconx + gapx1) + 6 --this magic number changes the button spacing
	local taby = (icony + gapy1)
	local scrollHeight = 305 - areay
	if scrollHeight > 256 then
		scrollHeight = 256
		areay = 305 - scrollHeight
	end
	-- Resize the scroll frame
	frame.ScrollFrame:SetHeight(scrollHeight)
	frame.scrollChild:SetHeight(scrollHeight)
	frame.HorizontalBarLeft:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 2, 39 + areay)
	frame.stationeryLeft:SetHeight(scrollHeight)
	frame.stationeryLeft:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256)
	frame.stationeryRight:SetHeight(scrollHeight)
	frame.stationeryRight:SetTexCoord(0, 1.0, 0, min(scrollHeight, 256) / 256)
	EQOL_MailPreviewFrameInset:SetPoint("TOPLEFT", 4, -80)

	local hasItems = #displayItems > 0
	if frame.attachmentsLabel and frame.attachmentsLabel.SetText then
		frame.attachmentsLabel:ClearAllPoints()
		if hasItems then
			local label = TAKE_ATTACHMENTS or "Attachments"
			local codText = formatMoney(payload.cod)
			if codText then label = label .. " - " .. (COD_AMOUNT or "COD") .. ": " .. codText end
			frame.attachmentsLabel:SetText(label)
			frame.attachmentsLabel:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			frame.attachmentsLabel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", indentx, indenty + (icony * itemRowCount) + (gapy1 * (itemRowCount - 1)) + gapy2 + frame.attachmentsLabel:GetHeight())
		else
			frame.attachmentsLabel:SetText(NO_ATTACHMENTS or "No Attachments")
			frame.attachmentsLabel:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
			frame.attachmentsLabel:SetPoint(
				"TOPLEFT",
				frame,
				"BOTTOMLEFT",
				marginxl + (areax - frame.attachmentsLabel:GetWidth()) / 2,
				indenty + (areay - frame.attachmentsLabel:GetHeight()) / 2 + frame.attachmentsLabel:GetHeight()
			)
		end
	end

	local itemsPerRow = frame.attachmentItemsPerRow or 7
	local itemSize = frame.attachmentItemSize or 37
	local spacing = frame.attachmentSpacing or 4
	local rows = hasItems and math.ceil(#displayItems / itemsPerRow) or 0
	local labelHeight = frame.attachmentsLabel and frame.attachmentsLabel:GetHeight() or 0
	local itemBlockHeight = rows > 0 and ((rows * itemSize) + ((rows - 1) * spacing)) or 0
	local padding = 6
	local attachmentsHeight = labelHeight + itemBlockHeight + padding
	if frame.attachmentsArea then frame.attachmentsArea:SetHeight(attachmentsHeight) end

	if frame.stationeryLeft and frame.stationeryRight then
		local textureHeight = scrollHeight or (frame.scrollFrame and frame.scrollFrame:GetHeight()) or 256
		frame.stationeryLeft:SetTexture("Interface/Stationery/stationerytest1")
		frame.stationeryRight:SetTexture("Interface/Stationery/stationerytest2")
		frame.stationeryLeft:SetHeight(textureHeight)
		frame.stationeryRight:SetHeight(textureHeight)
		local texCoordBottom = math.min(textureHeight, 256) / 256
		frame.stationeryLeft:SetTexCoord(0, 1.0, 0, texCoordBottom)
		frame.stationeryRight:SetTexCoord(0, 1.0, 0, texCoordBottom)
	end

	if frame.attachmentsArea then
		local areaWidth = frame.attachmentsArea:GetWidth() or 0
		local rowWidth = (itemsPerRow * itemSize) + ((itemsPerRow - 1) * spacing)
		local startX = 0
		if areaWidth > rowWidth then startX = math.floor((areaWidth - rowWidth) / 2) end
		local startY = -(labelHeight + 4)
		for i, button in ipairs(frame.attachmentButtons or {}) do
			local row = math.floor((i - 1) / itemsPerRow)
			local col = (i - 1) % itemsPerRow
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame.attachmentsArea, "TOPLEFT", startX + (col * (itemSize + spacing)), startY - (row * (itemSize + spacing)) + 20)
		end
	end

	for i, button in ipairs(frame.attachmentButtons or {}) do
		setItemButtonData(button, displayItems[i])
	end

	frame:Show()
	frame:Raise()
end

function TradeMailLog:HandleLink(linkType, payload)
	if not payload or payload == "" then return end
	local history = getChannelHistory()
	if not history or not history.FindEQOLLine then return end
	local line = history:FindEQOLLine(payload)
	if not line or not line.eqolPayload then return end

	local data = line.eqolPayload
	if linkType == "eqoltrade" or data.kind == "trade" then
		self:ShowTradePreview(data)
	elseif linkType == "eqolmail" or data.kind == "mail" then
		self:ShowMailPreview(data)
	end
end

function TradeMailLog:OnEvent(event, ...)
	if event == "PLAYER_LOGIN" then
		self:EnsureMailHooks()
		return
	end
	if event == "ADDON_LOADED" then
		local name = ...
		if name == "Blizzard_MailFrame" then self:EnsureMailHooks() end
		return
	end
	if event == "MAIL_SHOW" then
		self:EnsureMailHooks()
		return
	end
	if event == "MAIL_SEND_SUCCESS" then
		if self.pendingSend and canLog("MAIL") then self:LogMail(self.pendingSend) end
		self.pendingSend = nil
		return
	end
	if event == "MAIL_FAILED" or event == "MAIL_CLOSED" then
		self.pendingSend = nil
		return
	end

	if event == "TRADE_SHOW" then
		if not canLog("TRADE") then
			self.tradeState = nil
			return
		end
		self:StartTrade()
		return
	end
	if event == "TRADE_UPDATE" or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" or event == "PLAYER_TRADE_MONEY" then
		if not self.tradeState then return end
		if not canLog("TRADE") then
			self.tradeState = nil
			return
		end
		self:UpdateTradeSnapshot()
		return
	end
	if event == "TRADE_ACCEPT_UPDATE" then
		if not self.tradeState then return end
		local playerAccepted, targetAccepted = ...
		self.tradeState.playerAccepted = playerAccepted or 0
		self.tradeState.targetAccepted = targetAccepted or 0
		return
	end
	if event == "TRADE_CLOSED" then
		if self.tradeState then self:FinishTrade() end
		return
	end
end

TradeMailLog.frame:SetScript("OnEvent", function(_, event, ...) TradeMailLog:OnEvent(event, ...) end)
TradeMailLog.frame:RegisterEvent("PLAYER_LOGIN")
TradeMailLog.frame:RegisterEvent("ADDON_LOADED")
TradeMailLog.frame:RegisterEvent("MAIL_SHOW")
TradeMailLog.frame:RegisterEvent("MAIL_SEND_SUCCESS")
TradeMailLog.frame:RegisterEvent("MAIL_FAILED")
TradeMailLog.frame:RegisterEvent("MAIL_CLOSED")
TradeMailLog.frame:RegisterEvent("TRADE_SHOW")
TradeMailLog.frame:RegisterEvent("TRADE_UPDATE")
TradeMailLog.frame:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
TradeMailLog.frame:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
TradeMailLog.frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
TradeMailLog.frame:RegisterEvent("TRADE_MONEY_CHANGED")
TradeMailLog.frame:RegisterEvent("PLAYER_TRADE_MONEY")
TradeMailLog.frame:RegisterEvent("TRADE_CLOSED")
