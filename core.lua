BReST = {}
BReST.name = "BrzEnhancedSwingTimer" -- Folder name, which is what ADDON_LOADED reports
-- Version of the addon, the one of the .toc
BReST.version = (GetAddOnMetadata and GetAddOnMetadata(BReST.name, "Version")) or "1.0.0"
BReST.url = "github.com/brz-admin/BrzEnhancedSwingTimer"
BReST.prefix = "BReST" -- prefix of the addon messages used to compare versions
BReST.BS = AceLibrary("Babble-Spell-2.3")

local function copy(value)
    if type(value) ~= "table" then return value end
    local t = {}
    for k, v in pairs(value) do t[k] = copy(v) end
    return t
end
BReST.copy = copy

local function color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

-- The three bars. MAIN and OFF are the melee hands, RANGED is the bow / gun / wand slot
BReST.HANDS = { "MAIN", "OFF", "RANGED" }
BReST.HAND_NAMES = { MAIN = "Main Hand", OFF = "Off Hand", RANGED = "Ranged" }

-- Settings of one bar
function BReST.BarDefaults(hand)
    local main = (hand == "MAIN")
    local barColor = color(0.62, 0.40, 0.96) -- violet
    if hand == "OFF" then
        barColor = color(0.96, 0.76, 0.26) -- gold
    elseif hand == "RANGED" then
        barColor = color(0.46, 0.56, 0.98)
    end

    return {
        enabled = true,
        width = 200,
        height = 18,

        texture = "Gradient", -- a name from BReST.Media.textures, or "Custom"
        customTexture = "",
        color = barColor,
        bgColor = color(0, 0, 0, 0.45),
        borderSize = 1,
        borderColor = color(0, 0, 0, 1),

        direction = "LTR", -- LTR, RTL, CENTER_OUT (center to the sides), EDGES_IN (sides to the center)
        mode = "DRAIN", -- DRAIN: full when the swing starts, FILL: empty when the swing starts
        holdFull = false, -- FILL only: stay full once the swing is ready
        spark = false,
        sparkColor = color(1, 1, 1, 0.8),
        sparkWidth = 14,
        sparkHeight = 47,
        queuedTint = main, -- MAIN only: another color while Heroic Strike / Cleave / ... is queued
        queuedColor = color(1.0, 0.85, 0.25),

        -- When the bar is on screen
        vis = {
            hideOutOfCombat = false,
            hideWhenIdle = false, -- hide while no swing is running
            hideDelay = 3, -- seconds the bar stays once it should be hidden
            fadeOut = 1, -- seconds it takes to disappear
            fadeIn = 0.2, -- and to come back
            fadeStyle = "SMOOTH", -- LINEAR, SMOOTH, EASE_OUT, INSTANT
        },

        icon = {
            show = true,
            source = "WEAPON", -- WEAPON: what is equipped in the slot, CUSTOM: the path below
            custom = "",
            showQueued = main, -- MAIN only: show the queued swing spell instead
            side = "LEFT", -- LEFT, RIGHT (outside the bar), INSIDE_LEFT, INSIDE_RIGHT
            matchHeight = true,
            size = 20,
            offsetX = 0,
            offsetY = 0,
            zoom = true,
        },

        timer = {
            show = true,
            font = "Open Sans",
            customFont = "",
            size = 11,
            outline = "NONE", -- NONE, OUTLINE, THICKOUTLINE
            shadow = true,
            color = color(1, 1, 1, 1),
            anchor = "LEFT", -- LEFT, CENTER, RIGHT, ABOVE, BELOW
            offsetX = 4,
            offsetY = 0,
            format = "REMAINING", -- REMAINING, REMAINING_S, REMAINING_TOTAL
            decimals = 1,
        },
    }
end

BReST.defaults = {
    version = 3,
    grouped = true, -- the bars are stacked in one frame that moves as a whole
    scale = 1,
    alpha = 1,
    updateTime = 0.03,

    group = {
        collapse = true, -- a hidden bar gives its room back to the others
        padding = 5,
        spacing = 5,
        bgColor = color(0, 0, 0, 0.5),
        borderSize = 1,
        borderColor = color(0.15, 0.15, 0.15, 1),
    },

    bars = {
        MAIN = BReST.BarDefaults("MAIN"),
        OFF = BReST.BarDefaults("OFF"),
        RANGED = BReST.BarDefaults("RANGED"),
    },
}
BReST.defaultProfile = "Default"

-- Setting up some globals
BReST.ready = false
BReST.debug = false
BReST.configMode = false -- the bars are unlocked and can be dragged
BReST.inCombat = false
BReST.mainhandTimer = 0
BReST.offhandTimer = 0
BReST.rangedTimer = 0
-- Duration of the swing each timer started with, so the bar stays right if the speed changes
BReST.mainhandSpeed = 0
BReST.offhandSpeed = 0
BReST.rangedSpeed = 0
BReST.lastUpdate = GetTime()

-- Localized names of the spells that count as a swing
local function nameSet(keys)
    local set = {}
    for i = 1, table.getn(keys) do
        local name = BReST.BS[keys[i]]
        if type(name) == "string" then set[name] = true end
    end
    return set
end

local function nameList(keys)
    local list = {}
    for i = 1, table.getn(keys) do
        local name = BReST.BS[keys[i]]
        if type(name) == "string" then table.insert(list, name) end
    end
    return list
end

-- Ranged weapons, these have their own timer
BReST.rangedSpells = nameSet({"Auto Shot", "Shoot", "Throw", "Shoot Bow", "Shoot Gun", "Shoot Crossbow"})
-- Replace the next main hand swing, so they restart its timer
BReST.nextSwingSpells = nameSet({"Heroic Strike", "Cleave", "Maul", "Raptor Strike", "Slam"})
-- The ones among them that are queued on the action bar until the next swing
BReST.onSwingList = nameList({"Heroic Strike", "Cleave", "Maul", "Raptor Strike"})
BReST.onSwingSpells = nameSet({"Heroic Strike", "Cleave", "Maul", "Raptor Strike"})

-- Fills what is missing in target from defaults, going down into the tables
local function fill(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = copy(v)
        elseif type(v) == "table" and type(target[k]) == "table" then
            fill(target[k], v)
        end
    end
end

local function put(t, k, v)
    if v ~= nil then t[k] = v end
end

-- Version 1 profiles had one set of flat settings for all the bars
local OLD_KEYS = {
    "barHeight", "barWidth", "barSpacing", "barPadding", "backgroundOpacity", "backgroundColor",
    "barColor", "showTimer", "showIcon", "barAlpha", "posX", "posY",
}

local function migrate(p)
    if p.version == nil then
        BReST.MigrateV1(p)
        p.version = 2
    end

    -- Version 2 hid all the bars the same way, version 3 does it per bar
    if p.version == 2 then
        if type(p.bars) ~= "table" then p.bars = {} end
        for i = 1, table.getn(BReST.HANDS) do
            local hand = BReST.HANDS[i]
            if type(p.bars[hand]) ~= "table" then p.bars[hand] = {} end
            local bar = p.bars[hand]
            if type(bar.vis) ~= "table" then bar.vis = {} end
            put(bar.vis, "hideOutOfCombat", p.hideOutOfCombat)
            put(bar.vis, "hideDelay", p.hideTime)
            put(bar.vis, "fadeOut", p.fadeTime)
        end
        p.hideOutOfCombat, p.hideTime, p.fadeTime = nil, nil, nil
        p.version = 3
    end
end

function BReST.MigrateV1(p)
    local hasOld = p.barHeight ~= nil or p.barWidth ~= nil or p.barColor ~= nil or p.posX ~= nil
    if hasOld then
        p.bars = {}
        for i = 1, table.getn(BReST.HANDS) do
            local bar = {}
            put(bar, "width", p.barWidth)
            put(bar, "height", p.barHeight)
            if type(p.barColor) == "table" then
                bar.color = color(p.barColor.r or 0.8, p.barColor.g or 0.5, p.barColor.b or 0.2)
            end
            if p.showIcon ~= nil then bar.icon = { show = p.showIcon } end
            if p.showTimer ~= nil then bar.timer = { show = p.showTimer } end
            p.bars[BReST.HANDS[i]] = bar
        end

        p.group = {}
        put(p.group, "padding", p.barPadding)
        put(p.group, "spacing", p.barSpacing)
        if type(p.backgroundColor) == "table" then
            p.group.bgColor = color(p.backgroundColor.r or 0, p.backgroundColor.g or 0, p.backgroundColor.b or 0, p.backgroundOpacity or 0.5)
        end

        put(p, "alpha", p.barAlpha)
        -- It used to be the bottom left corner of the frame, now it is the top left one
        if p.posX ~= nil and p.posY ~= nil then
            p.groupX = p.posX
            p.groupY = p.posY + (p.barHeight or 20) + 2 * (p.barPadding or 5)
        end
        -- The old default made the bars jerky
        if p.updateTime == 0.1 then p.updateTime = nil end
    end

    for i = 1, table.getn(OLD_KEYS) do p[OLD_KEYS[i]] = nil end
end

-- Current profile, or the defaults while the saved variables are not there yet
function BReST.GetProfile()
    local profile = BReST_Profiles and BReST_Config and BReST_Profiles[BReST_Config.profile]
    return profile or BReST.defaults
end

function BReST.GetBar(hand)
    return BReST.GetProfile().bars[hand]
end

function BReST.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffa879ffBReST|r: " .. text)
end

function BReST.Debug(text)
    if BReST.debug then BReST.Print(text) end
end

-- Makes sure a profile has every setting
local function prepare(profile)
    migrate(profile)
    fill(profile, BReST.defaults)
end

-- Sets up the saved variables. Safe to call more than once, whichever of ADDON_LOADED and
-- VARIABLES_LOADED comes last is the one that sees the saved data.
function BReST.Init()
    if type(BReST_Config) ~= "table" then BReST_Config = {} end
    if type(BReST_Profiles) ~= "table" then BReST_Profiles = {} end
    if BReST_Config.profile == nil then BReST_Config.profile = BReST.defaultProfile end
    if BReST_Config.checkUpdates == nil then BReST_Config.checkUpdates = true end
    if type(BReST_Profiles[BReST_Config.profile]) ~= "table" then BReST_Profiles[BReST_Config.profile] = {} end

    for _, profile in pairs(BReST_Profiles) do
        if type(profile) == "table" then prepare(profile) end
    end

    BReST.Profiles = BReST_Profiles
    BReST.Config = BReST_Config
    BReST.ready = true
end

-- Profiles ---------------------------------------------------------------------------------

function BReST.ProfileNames()
    local names = {}
    for name, profile in pairs(BReST_Profiles or {}) do
        if type(profile) == "table" then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

-- Redraws everything after the profile changed
function BReST.Apply()
    if BReST.Frame and BReST.Frame.Group then
        BReST.Frame.restorePosition()
        BReST.Frame.layout()
    end
    if BReST.ConfigUI then BReST.ConfigUI.Refresh() end
end

function BReST.SetProfile(name)
    if type(BReST_Profiles[name]) ~= "table" then return false end
    BReST_Config.profile = name
    BReST.Apply()
    return true
end

-- Creates a profile, as a copy of the current one. Returns true, or false and why not
function BReST.CreateProfile(name)
    if type(name) ~= "string" then return false, "no name" end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then return false, "the name is empty" end
    if BReST_Profiles[name] ~= nil then return false, "a profile with that name exists" end

    BReST_Profiles[name] = copy(BReST.GetProfile())
    BReST.SetProfile(name)
    return true
end

function BReST.DeleteProfile(name)
    if BReST_Profiles[name] == nil then return false, "no such profile" end
    if table.getn(BReST.ProfileNames()) <= 1 then return false, "it is the only profile" end

    BReST_Profiles[name] = nil
    if BReST_Config.profile == name then
        BReST_Config.profile = BReST.ProfileNames()[1]
    end
    BReST.Apply()
    return true
end

-- Back to the defaults, the position is kept
function BReST.ResetProfile()
    local profile = BReST.GetProfile()
    if profile == BReST.defaults then return end
    local gx, gy = profile.groupX, profile.groupY
    for k in pairs(profile) do profile[k] = nil end
    prepare(profile)
    profile.groupX, profile.groupY = gx, gy
    BReST.Apply()
end

-- Swing timers -----------------------------------------------------------------------------

-- Starts the timer of a hand ("MAIN", "OFF" or "RANGED"): it just swung
function BReST.Start(hand)
    local speed
    if hand == "RANGED" then
        speed = BReST.utils.GetRangedSpeed()
    else
        speed = BReST.utils.GetWeaponSpeed(hand == "OFF")
    end
    if speed == nil or speed <= 0 then return end

    if hand == "RANGED" then
        BReST.rangedTimer, BReST.rangedSpeed = speed, speed
    elseif hand == "OFF" then
        BReST.offhandTimer, BReST.offhandSpeed = speed, speed
    else
        BReST.mainhandTimer, BReST.mainhandSpeed = speed, speed
    end

end

-- An auto attack happened, damage is nil when it did not hit
function BReST.OnMeleeSwing(damage, damageType)
    local hand = BReST.utils.PickHand(damage, damageType)
    BReST.Debug("melee " .. tostring(damageType) .. " " .. tostring(damage) .. " -> " .. hand)
    BReST.Start(hand)
end

-- A new weapon restarts its swing, and the bars depend on what is equipped
function BReST.CheckWeapons()
    local mainhand = GetInventoryItemLink("player", 16)
    local offhand = GetInventoryItemLink("player", 17)
    local ranged = GetInventoryItemLink("player", 18)

    if mainhand ~= BReST.mainhandLink then BReST.mainhandTimer = 0 end
    if offhand ~= BReST.offhandLink then BReST.offhandTimer = 0 end
    if ranged ~= BReST.rangedLink then BReST.rangedTimer = 0 end
    BReST.mainhandLink, BReST.offhandLink, BReST.rangedLink = mainhand, offhand, ranged

    BReST.Frame.layout()
end

-- Queued swing spells ------------------------------------------------------------------------
-- Heroic Strike and friends are not cast, they are queued until the next swing and the client
-- shows their action button as checked. So we look for the buttons that hold one of them.

BReST.spellTextures = {} -- name of a queued spell -> its icon
BReST.queueSlots = {} -- action slots holding one of them
BReST.queuedName = nil -- the one that is queued right now, and its icon
BReST.queuedTexture = nil

function BReST.ScanSpellBook()
    BReST.spellTextures = {}
    BReST.rangedTextures = {}
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if BReST.rangedSpells[name] then
            local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
            if texture then BReST.rangedTextures[texture] = true end
        end
        if BReST.onSwingSpells[name] then
            BReST.spellTextures[name] = GetSpellTexture(i, BOOKTYPE_SPELL)
        end
        i = i + 1
    end
end

function BReST.ScanActions()
    BReST.queueSlots = {}
    for slot = 1, 120 do
        if HasAction(slot) then
            local texture = GetActionTexture(slot)
            if texture then
                for name, spellTexture in pairs(BReST.spellTextures) do
                    if spellTexture == texture then
                        table.insert(BReST.queueSlots, { slot = slot, name = name, texture = texture })
                    end
                end
            end
        end
    end
end

function BReST.UpdateQueued()
    BReST.queuedName, BReST.queuedTexture = nil, nil
    for i = 1, table.getn(BReST.queueSlots) do
        local q = BReST.queueSlots[i]
        if IsCurrentAction(q.slot) then
            BReST.queuedName, BReST.queuedTexture = q.name, q.texture
            return
        end
    end
end

-- Versions ---------------------------------------------------------------------------------
-- An addon can't ask a server for the latest version, so the players that have the addon tell
-- each other which one they run (guild, party and raid) and the older one gets a notice.

local function parseVersion(v)
    local s, e, major, minor, patch = string.find(v or "", "^(%d+)%.?(%d*)%.?(%d*)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

-- -1, 0 or 1 when a is older than, the same as or newer than b
function BReST.CompareVersions(a, b)
    local a1, a2, a3 = parseVersion(a)
    local b1, b2, b3 = parseVersion(b)
    if a1 ~= b1 then return a1 < b1 and -1 or 1 end
    if a2 ~= b2 then return a2 < b2 and -1 or 1 end
    if a3 ~= b3 then return a3 < b3 and -1 or 1 end
    return 0
end

function BReST.CheckEnabled()
    return BReST_Config == nil or BReST_Config.checkUpdates ~= false
end

BReST.newerVersion = nil -- the newest version somebody else runs, once it is newer than ours
BReST.versionDelay = nil -- seconds before the first broadcast, the guild is not known right at login

local lastSent = {}

function BReST.BroadcastVersion()
    if not BReST.ready or not BReST.CheckEnabled() then return end

    local channels = {}
    if GetGuildInfo("player") then table.insert(channels, "GUILD") end
    if GetNumRaidMembers() > 0 then
        table.insert(channels, "RAID")
    elseif GetNumPartyMembers() > 0 then
        table.insert(channels, "PARTY")
    end

    -- The group events fire a lot, one message per channel every 30 seconds is plenty
    local now = GetTime()
    for i = 1, table.getn(channels) do
        local channel = channels[i]
        if lastSent[channel] == nil or now - lastSent[channel] > 30 then
            lastSent[channel] = now
            SendAddonMessage(BReST.prefix, "V:" .. BReST.version, channel)
        end
    end
end

function BReST.OnVersion(message)
    local s, e, version = string.find(message or "", "^V:([%d%.]+)$")
    if not version or not BReST.CheckEnabled() then return end

    if BReST.CompareVersions(version, BReST.version) > 0
        and (BReST.newerVersion == nil or BReST.CompareVersions(version, BReST.newerVersion) > 0) then
        BReST.newerVersion = version
        BReST.Print("version " .. version .. " is out (you have " .. BReST.version .. "): " .. BReST.url)
        if BReST.ConfigUI then BReST.ConfigUI.RefreshTitle() end
    end
end

-- Events -----------------------------------------------------------------------------------

BReST.frame = CreateFrame("Frame")
BReST.frame:RegisterEvent("ADDON_LOADED")
BReST.frame:RegisterEvent("VARIABLES_LOADED")
BReST.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
BReST.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
BReST.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
BReST.frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
BReST.frame:RegisterEvent("CHAT_MSG_ADDON")
BReST.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
BReST.frame:RegisterEvent("RAID_ROSTER_UPDATE")
BReST.frame:RegisterEvent("SPELLS_CHANGED")
BReST.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BReST.frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
BReST.frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
BReST.frame:RegisterEvent("SPELLCAST_START")
BReST.frame:RegisterEvent("SPELLCAST_STOP")
BReST.frame:RegisterEvent("SPELLCAST_FAILED")
BReST.frame:RegisterEvent("SPELLCAST_INTERRUPTED")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
BReST.frame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
BReST.frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")

-- Each event is handled by the method of the same name
BReST.frame:SetScript("OnEvent", function()
    local handler = BReST.frame[event]
    if handler then handler(BReST.frame, arg1) end
end)

function BReST.frame:ADDON_LOADED(arg1)
    if arg1 == BReST.name then
        BReST.Init()
    end
end

function BReST.frame:VARIABLES_LOADED()
    BReST.Init()
end

function BReST.frame:PLAYER_ENTERING_WORLD()
    BReST.Init()
    BReST.lastUpdate = GetTime()
    BReST.Frame.build()
    BReST.Frame.restorePosition()
    BReST.ScanSpellBook()
    BReST.ScanActions()
    BReST.ammo = {}
    BReST.CheckAmmo()
    BReST.CheckWeapons()
    BReST.versionDelay = 8
end

-- The other players' versions (the handler only gets arg1, the rest are globals)
function BReST.frame:CHAT_MSG_ADDON(prefix)
    if prefix ~= BReST.prefix or arg4 == UnitName("player") then return end
    BReST.OnVersion(arg2)
end

function BReST.frame:PARTY_MEMBERS_CHANGED()
    BReST.BroadcastVersion()
end

function BReST.frame:RAID_ROSTER_UPDATE()
    BReST.BroadcastVersion()
end

function BReST.frame:SPELLS_CHANGED()
    BReST.ScanSpellBook()
    BReST.ScanActions()
end

function BReST.frame:ACTIONBAR_SLOT_CHANGED()
    BReST.ScanActions()
end

function BReST.frame:ACTIONBAR_PAGE_CHANGED()
    BReST.ScanActions()
end

function BReST.frame:UPDATE_BONUS_ACTIONBAR()
    BReST.ScanActions()
end

function BReST.frame:PLAYER_REGEN_DISABLED()
    BReST.inCombat = true
end

function BReST.frame:PLAYER_REGEN_ENABLED()
    BReST.inCombat = false
end

function BReST.frame:UNIT_INVENTORY_CHANGED(arg1)
    if arg1 == "player" and BReST.ready then
        BReST.CheckAmmo()
        BReST.CheckWeapons()
    end
end

-- White hits
function BReST.frame:CHAT_MSG_COMBAT_SELF_HITS(arg1)
    local target, damage, source, damageType = BReST.parser.selfMeleeDamage(arg1)
    if target == nil then return end
    BReST.OnMeleeSwing(damage, damageType)
end

-- Swings that missed, were dodged, parried...
function BReST.frame:CHAT_MSG_COMBAT_SELF_MISSES(arg1)
    local target, outcome = BReST.parser.selfMeleeAvoid(arg1)
    if target == nil then return end
    BReST.OnMeleeSwing(nil, outcome)
end

-- Shots, and the abilities that replace a swing
function BReST.frame:CHAT_MSG_SPELL_SELF_DAMAGE(arg1)
    local spellName, target, outcome = BReST.parser.selfSpell(arg1)
    if spellName == nil then return end

    if BReST.rangedSpells[spellName] then
        -- This line is the projectile landing. When the timer already started at the shot
        -- (SPELLCAST_START/STOP below) it must not restart it. It is the only signal for
        -- shots that never send those events.
        local sinceFired = GetTime() - (BReST.rangedFiredAt or -100)
        if sinceFired < BReST.RANGED_IMPACT_WINDOW then
            BReST.Debug("ranged " .. spellName .. " " .. outcome .. " landed, timer already started")
            return
        end
        BReST.Debug("ranged " .. spellName .. " " .. outcome .. " -> RANGED")
        BReST.Start("RANGED")
    elseif BReST.nextSwingSpells[spellName] then
        BReST.Debug("swing replaced by " .. spellName .. " " .. outcome .. " -> MAIN")
        BReST.Start("MAIN")
    end
end

-- The shot leaves the weapon when the cast ends, the damage line only comes once the projectile
-- has travelled to the target, so the ranged timer starts on the cast.
-- Auto Shot sends no cast event in 1.12, so the shot is detected by the ammo (or the thrown
-- weapon) being spent: that happens when the shot leaves, not when it lands. The other shots
-- (Arcane Shot, Multi-Shot, Aimed Shot...) spend ammo too and don't touch the swing timer, so
-- they are filtered out by watching what the player cast.
BReST.RANGED_IMPACT_WINDOW = 1.0 -- seconds after a shot during which its damage line is ignored
BReST.MANUAL_SHOT_WINDOW = 0.7 -- seconds an ability keeps claiming the ammo it spends
BReST.rangedFiredAt = nil
BReST.manualAt = nil -- last time the player used an ability that is not a ranged auto attack
BReST.manualCasting = false -- a cast time ability (Aimed Shot) is being cast
BReST.rangedTextures = {} -- icons of the ranged auto attacks, to tell their buttons apart
BReST.ammo = {} -- slot -> { link, count } as last seen

-- A ranged auto attack left the weapon, from any of the signals. Several can report the same
-- shot, the later ones are dropped.
function BReST.OnRangedFired(source)
    local now = GetTime()
    if BReST.rangedFiredAt and now - BReST.rangedFiredAt < 0.3 then return end
    BReST.rangedFiredAt = now
    BReST.Debug("ranged fired (" .. source .. ") -> RANGED")
    BReST.Start("RANGED")
end

local function claimedByAbility()
    if BReST.manualCasting then return true end
    return BReST.manualAt ~= nil and GetTime() - BReST.manualAt < BReST.MANUAL_SHOT_WINDOW
end

-- Compares the ammo (slot 0) and the thrown weapon stack (slot 18) with the last time
function BReST.CheckAmmo()
    local spent = false
    local slots = { 0, 18 }
    for i = 1, 2 do
        local slot = slots[i]
        local link = GetInventoryItemLink("player", slot)
        local count = link and GetInventoryItemCount("player", slot) or 0
        local last = BReST.ammo[slot]
        if last and link and last.link == link and count < last.count then
            spent = true
        end
        BReST.ammo[slot] = { link = link, count = count }
    end

    if not spent or not BReST.utils.hasRanged() then return end
    if claimedByAbility() then
        BReST.Debug("ammo spent by an ability, ignored")
        return
    end
    BReST.OnRangedFired("ammo")
end

local function isRangedAttack(name)
    if name == nil then return true end
    local bare = string.gsub(name, "%s*%b()", "")
    return BReST.rangedSpells[name] or BReST.rangedSpells[bare]
end

local function markAbility(name)
    if not isRangedAttack(name) then BReST.manualAt = GetTime() end
end

-- Abilities started from a button or a macro. Their ammo must not start the timer.
local useAction, castSpell, castSpellByName = UseAction, CastSpell, CastSpellByName

UseAction = function(slot, a, b)
    if slot and HasAction(slot) and not BReST.rangedTextures[GetActionTexture(slot) or ""] then
        BReST.manualAt = GetTime()
    end
    return useAction(slot, a, b)
end

CastSpell = function(index, book)
    markAbility(GetSpellName(index, book))
    return castSpell(index, book)
end

CastSpellByName = function(name, onSelf)
    markAbility(name)
    return castSpellByName(name, onSelf)
end

function BReST.frame:SPELLCAST_START(arg1)
    if BReST.rangedSpells[arg1] then
        BReST.rangedCasting = arg1
    else
        BReST.manualCasting = true
    end
end

function BReST.frame:SPELLCAST_STOP()
    if BReST.manualCasting then
        BReST.manualCasting = false
        BReST.manualAt = GetTime()
    end
    if BReST.rangedCasting then
        BReST.rangedCasting = nil
        BReST.OnRangedFired("cast")
    end
end

function BReST.frame:SPELLCAST_FAILED()
    BReST.rangedCasting = nil
    BReST.manualCasting = false
end

function BReST.frame:SPELLCAST_INTERRUPTED()
    BReST.rangedCasting = nil
    BReST.manualCasting = false
end

BReST.frame:SetScript("OnUpdate", function()
    if not BReST.ready then return end

    local currTime = GetTime()
    local lastUpdate = BReST.lastUpdate

    if (lastUpdate < (currTime - BReST.GetProfile().updateTime)) then
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

        BReST.UpdateQueued()

        if BReST.versionDelay then
            BReST.versionDelay = BReST.versionDelay - elapsed
            if BReST.versionDelay <= 0 then
                BReST.versionDelay = nil
                BReST.BroadcastVersion()
            end
        end

        -- Update bar frame
        BReST.Frame.update(elapsed)

        BReST.lastUpdate = currTime
    end
end)

-- Slash command ----------------------------------------------------------------------------

SLASH_BREST1 = "/brest"
SlashCmdList["BREST"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "" or msg == "config" or msg == "options" or msg == "menu" then
        BReST.ConfigUI.Toggle()
    elseif msg == "unlock" then
        BReST.Frame.setConfigMode(true)
        BReST.Print("bars unlocked, drag them to move")
    elseif msg == "lock" then
        BReST.Frame.setConfigMode(false)
        BReST.Print("bars locked")
    elseif msg == "sim" or msg == "simulate" then
        BReST.Frame.setSimulating(not BReST.Frame.sim.active)
        BReST.Print("simulation " .. (BReST.Frame.sim.active and "on" or "off"))
    elseif msg == "reset" then
        BReST.Frame.resetPosition()
        BReST.Print("position reset")
    elseif msg == "debug" then
        BReST.debug = not BReST.debug
        BReST.Print("debug " .. (BReST.debug and "on" or "off"))
    else
        BReST.Print("/brest: settings, /brest unlock | lock: move the bars, /brest sim: simulate swings, /brest reset: center the bars, /brest debug: print every swing")
    end
end
