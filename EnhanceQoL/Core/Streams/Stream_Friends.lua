-- luacheck: globals EnhanceQoL C_FriendList
local GetNumFriends = C_FriendList.GetNumFriends
local GetFriendInfoByIndex = C_FriendList.GetFriendInfoByIndex

local myGuid = UnitGUID("player")

local function getFriends(stream)
	local numFriendsOnline = 0
	local tooltipData = {}
	local gMember = GetNumGuildMembers()
	if gMember then
		for i = 1, gMember do
			local name, _, _, level, _, _, _, _, isOnline, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
			if isOnline and guid ~= myGuid then
				numFriendsOnline = numFriendsOnline + 1
				local unit = name .. "(" .. level .. ")"
				table.insert(tooltipData, unit)
			end
		end
	end

	local numBNetTotal, numBNetOnline = BNGetNumFriends()
	if numBNetOnline then
		for i = 1, numBNetTotal, 1 do
			local info = C_BattleNet.GetFriendAccountInfo(i)
			if info and info.gameAccountInfo then
				if info.gameAccountInfo.isOnline and info.gameAccountInfo.characterName and info.gameAccountInfo.characterLevel then
					numFriendsOnline = numFriendsOnline + 1
					local unit = info.gameAccountInfo.characterName .. "(" .. info.gameAccountInfo.characterLevel .. ")"
					table.insert(tooltipData, unit)
				end
			end
		end
	end
	for i = 1, C_FriendList.GetNumFriends() do
		local friendInfo = C_FriendList.GetFriendInfoByIndex(i)
		if friendInfo.connected then
			numFriendsOnline = numFriendsOnline + 1
			local unit = friendInfo.name .. "(" .. friendInfo.level .. ")"
			table.insert(tooltipData, unit)
		end
	end
	EnhanceQoL.DataHub:Publish(stream, {
		text = numFriendsOnline .. " " .. FRIENDS,
		tooltip = table.concat(tooltipData, "\n"),
		-- OnClick = function() ToggleCharacter("PaperDollFrame") end,
	})
end

local provider = {
	id = "friends",
	version = 1,
	title = "Friends",
	events = {
		PLAYER_LOGIN = function(stream) getFriends(stream) end,
		BN_FRIEND_ACCOUNT_ONLINE = function(stream) getFriends(stream) end,
		BN_FRIEND_ACCOUNT_OFFLINE = function(stream) getFriends(stream) end,
		FRIENDLIST_UPDATE = function(stream) getFriends(stream) end,
	},
}

EnhanceQoL.DataHub.RegisterStream(provider)

return provider
