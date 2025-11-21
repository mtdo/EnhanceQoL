local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local cVendorEconomy = addon.functions.SettingsCreateCategory(nil, L["VendorsEconomy"], nil, "VendorsEconomy")
addon.SettingsLayout.vendorEconomyCategory = cVendorEconomy

addon.functions.SettingsCreateHeadline(cVendorEconomy, BUTTON_LAG_AUCTIONHOUSE)

local data = {
	{
		text = L["persistAuctionHouseFilter"],
		var = "persistAuctionHouseFilter",
		func = function(value) addon.db["persistAuctionHouseFilter"] = value end,
	},
	{
		text = (function()
			local label = _G["AUCTION_HOUSE_FILTER_CURRENTEXPANSION_ONLY"]
			return L["alwaysUserCurExpAuctionHouse"]:format(label)
		end)(),
		var = "alwaysUserCurExpAuctionHouse",
		func = function(value) addon.db["alwaysUserCurExpAuctionHouse"] = value end,
	},
}

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cVendorEconomy, data)

addon.functions.SettingsCreateHeadline(cVendorEconomy, L["Convenience"])

data = {
	{
		var = "autoRepair",
		text = L["autoRepair"],
		func = function(v) addon.db["autoRepair"] = v end,
		desc = L["autoRepairDesc"],
		children = {
			{

				var = "autoRepairGuildBank",
				text = L["autoRepairGuildBank"],
				func = function(v) addon.db["autoRepairGuildBank"] = v end,
				desc = L["autoRepairGuildBankDesc"],
				parentCheck = function()
					return addon.SettingsLayout.elements["autoRepair"]
						and addon.SettingsLayout.elements["autoRepair"].setting
						and addon.SettingsLayout.elements["autoRepair"].setting:GetValue() == true
				end,
				parent = true,
				default = false,
				type = Settings.VarType.Boolean,
				sType = "checkbox",
			},
		},
	},
	{
		var = "sellAllJunk",
		text = L["sellAllJunk"],
		func = function(v)
			addon.db["sellAllJunk"] = v
			if v then addon.functions.checkBagIgnoreJunk() end
		end,
		desc = L["sellAllJunkDesc"],
	},
}

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cVendorEconomy, data)

addon.functions.SettingsCreateHeadline(cVendorEconomy, MERCHANT)

data = {
	{
		var = "enableExtendedMerchant",
		text = L["enableExtendedMerchant"],
		func = function(v)
			addon.db["enableExtendedMerchant"] = v
			if addon.Merchant then
				if v and addon.Merchant.Enable then
					addon.Merchant:Enable()
				elseif not v and addon.Merchant.Disable then
					addon.Merchant:Disable()
					addon.variables.requireReload = true
					addon.functions.checkReloadFrame()
				end
			end
		end,
		desc = L["enableExtendedMerchantDesc"],
	},
	{
		var = "markKnownOnMerchant",
		text = L["markKnownOnMerchant"],
		func = function(v)
			addon.db["markKnownOnMerchant"] = v
			if MerchantFrame and MerchantFrame:IsShown() then
				if MerchantFrame.selectedTab == 2 then
					if MerchantFrame_UpdateBuybackInfo then MerchantFrame_UpdateBuybackInfo() end
				else
					if MerchantFrame_UpdateMerchantInfo then MerchantFrame_UpdateMerchantInfo() end
				end
			end
		end,
		desc = L["markKnownOnMerchantDesc"],
	},
	{
		var = "markCollectedPetsOnMerchant",
		text = L["markCollectedPetsOnMerchant"],
		func = function(v)
			addon.db["markCollectedPetsOnMerchant"] = v
			if MerchantFrame and MerchantFrame:IsShown() then
				if MerchantFrame.selectedTab == 2 then
					if MerchantFrame_UpdateBuybackInfo then MerchantFrame_UpdateBuybackInfo() end
				else
					if MerchantFrame_UpdateMerchantInfo then MerchantFrame_UpdateMerchantInfo() end
				end
			end
		end,
		desc = L["markCollectedPetsOnMerchantDesc"],
	},
}

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cVendorEconomy, data)

addon.functions.SettingsCreateHeadline(cVendorEconomy, MINIMAP_TRACKING_MAILBOX)

data = {
	{
		var = "enableMailboxAddressBook",
		text = L["enableMailboxAddressBook"],
		func = function(v)
			addon.db["enableMailboxAddressBook"] = v
			if addon.Mailbox then
				if addon.Mailbox.SetEnabled then addon.Mailbox:SetEnabled(v) end
				if v and addon.Mailbox.AddSelfToContacts then addon.Mailbox:AddSelfToContacts() end
				if v and addon.Mailbox.RefreshList then addon.Mailbox:RefreshList() end
			end
		end,
		desc = L["enableMailboxAddressBookDesc"],
		children = {
			{
				listFunc = function()
					local tList = {}
					tList[""] = ""
					for key, rec in pairs(addon.db["mailboxContacts"]) do
						local class = rec and rec.class
						local col = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or ""] or { r = 1, g = 1, b = 1 }
						tList[key] = string.format("|cff%02x%02x%02x%s|r", col.r * 255, col.g * 255, col.b * 255, key)
					end
					return tList
				end,
				text = L["mailboxRemoveHeader"],
				get = function() return "" end,
				set = function(key)
					
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["enableMailboxAddressBook"]
						and addon.SettingsLayout.elements["enableMailboxAddressBook"].setting
						and addon.SettingsLayout.elements["enableMailboxAddressBook"].setting:GetValue() == true
				end,
				parent = true,
				default = "",
				var = "mailboxContacts",
				type = Settings.VarType.String,
				sType = "dropdown",
			},
		},
	},
}

table.sort(data, function(a, b) return a.text < b.text end)
addon.functions.SettingsCreateCheckboxes(cVendorEconomy, data)
----- REGION END

function addon.functions.initVendorEconomy() end

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
