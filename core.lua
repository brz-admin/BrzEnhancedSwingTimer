BReST = {}
BReST.version = "1.0.0" -- Version of the addon
BReST.BS = AceLibrary("Babble-Spell-2.3")

BReST.frame = CreateFrame("Frame")
BReST.frame:RegisterEvent("ADDON_LOADED")
function BReST.frame:ADDON_LOADED(arg1)
    if arg1 == "BReST" then
        -- Setting up some globals
        BReST.configMode = false
        BReST.mainhandTimer = 0
        BReST.offhandTimer = 0
        BReST.rangedTimer = 0
        BReST.lastUpdate = GetTime()
        BReST.fadeTimer = 0
        BReST.hideTimer = 0
        if BReST_Config == nil then
            BReST_Config = {}
            BReST_Config.profile = "Default"    -- Profile name
        end

        if BReST_Profiles == nil then
            BReST_Profiles = {}
        end

        BReST.Profiles = BReST_Profiles
        BReST.Config = BReST_Config
    end
end

BReST.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
BReST.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
BReST.frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")

BReST.frame:SetScript("OnUpdate", function()
    local currTime = GetTime()
    local lastUpdate = BReST.lastUpdate
    
    if (BReST.profiles[BReST.Config.profile] == nil) then return end;

    if (lastUpdate < (currTime - BReST.profiles[BReST.Config.profile].updateTime)) then
        -- Update timers
        local elapsed = currTime - lastUpdate;

        if (BReST.rangedTimer > 0) then
            BReST.rangedTimer = BReST.rangedTimer - elapsed
            if (BReST.rangedTimer < 0) then BReST.rangedTimer = 0 end
        end

        if (BReST.mainhandTimer > 0) then
            BReST.mainhandTimer = BReST.mainhandTimer - elapsed
            if (BReST.mainhandTimer < 0) then BReST.mainhandTimer = 0 end
        end

        if (BReST.offhandTimer > 0) then
            BReST.offhandTimer = BReST.offhandTimer - elapsed
            if (BReST.offhandTimer < 0) then BReST.offhandTimer = 0 end
        end

        -- Update bar frame
        BReST.Frame.update(elapsed)

        -- Update config Frame
        BReST.configFrame.update(elapsed)

        BReST.lastUpdate = GetTime()
    end
end)
