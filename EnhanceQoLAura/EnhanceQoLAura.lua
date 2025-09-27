-- Store the original Blizzard SetupMenu generator for rewrapping
local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local LSM = LibStub("LibSharedMedia-3.0")
local AceGUI = addon.AceGUI

-- Expose Aura subfeatures directly under Combat (no umbrella "Aura")
addon.variables.statusTable.groups["combat"] = true
addon.functions.addToTree("combat", { value = "resourcebar",   text = DISPLAY_PERSONAL_RESOURCE }, true)
addon.functions.addToTree("combat", { value = "bufftracker",    text = L["BuffTracker"] }, true)
addon.functions.addToTree("combat", { value = "casttracker",    text = L["CastTracker"] or "Cast Tracker" }, true)
addon.functions.addToTree("combat", { value = "cooldownnotify", text = L["CooldownNotify"] or "Cooldown Notify" }, true)

-- TODO add an information dialog to the root node with informations and a discord link for "minimal Auras in M+ etc."
function addon.Aura.functions.treeCallback(container, group)
    container:ReleaseChildren()
    -- Normalize group to last segment (supports legacy "aura\001..." and new "combat\001..." paths)
    local seg = group
    local ap = group:find("aura\001", 1, true)
    local cp = group:find("combat\001", 1, true)
    if ap then seg = group:sub(ap + #("aura\001")) end
    if cp then seg = group:sub(cp + #("combat\001")) end

    if seg == "resourcebar" then
        addon.Aura.functions.addResourceFrame(container)
    elseif seg == "bufftracker" then
        addon.Aura.functions.addBuffTrackerOptions(container)
        addon.Aura.scanBuffs()
    elseif seg == "casttracker" and addon.Aura.CastTracker and addon.Aura.CastTracker.functions then
        addon.Aura.CastTracker.functions.addCastTrackerOptions(container)
        if addon.Aura.CastTracker.functions.Refresh then addon.Aura.CastTracker.functions.Refresh() end
    elseif seg == "cooldownnotify" and addon.Aura.CooldownNotify and addon.Aura.CooldownNotify.functions then
        addon.Aura.CooldownNotify.functions.addCooldownNotifyOptions(container)
    end
end
addon.Aura.functions.BuildSoundTable()
