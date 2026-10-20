BReST.Frame = {}
local bf = BReST.Frame
local M = BReST.Media

local HANDS = BReST.HANDS
local SLOT = { MAIN = 16, OFF = 17, RANGED = 18 } -- Inventory slot of the weapon of each bar
bf.SLOT = SLOT

local ICON_GAP = 3
local DEMO_FRACTION = 0.6 -- how full the bars are when they only show their look
local SIM_REST = 0.7 -- seconds a simulated bar waits before it swings again
local SIM_COMBAT = 4 -- seconds a simulated swing counts as being in combat
local SIM_SPEED = { MAIN = 2.6, OFF = 2.4, RANGED = 2.2 } -- used when no weapon gives a speed
local QUEUED_ICON = "Interface\\Icons\\Ability_MeleeDamage"

-- True while the window is open: all the enabled bars are shown, equipped or not
bf.preview = false
bf.testHide = false

-- Simulated swings, to see what the bars do without fighting
bf.sim = {
    active = false, -- swinging in a loop
    queued = false, -- pretend a swing spell is queued
    combat = 0, -- seconds left of the simulated fight, only used to test the hiding
    timer = { MAIN = 0, OFF = 0, RANGED = 0 },
    speed = { MAIN = 0, OFF = 0, RANGED = 0 },
    rest = { MAIN = 0, OFF = 0, RANGED = 0 },
}

-- mult scales the opacity of the color
local function tint(texture, c, mult)
    texture:SetVertexColor(c.r, c.g, c.b, (c.a or 1) * (mult or 1))
end

-- Four textures drawn just outside of a frame
local function makeBorder(frame, layer)
    local b = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        b[side] = frame:CreateTexture(nil, layer)
        b[side]:SetTexture(M.white)
    end
    return b
end

local function layoutBorder(b, frame, size, c, mult)
    if size <= 0 then
        b.top:Hide()
        b.bottom:Hide()
        b.left:Hide()
        b.right:Hide()
        return
    end

    b.top:ClearAllPoints()
    b.top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0)
    b.top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0)
    b.top:SetHeight(size)

    b.bottom:ClearAllPoints()
    b.bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0)
    b.bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0)
    b.bottom:SetHeight(size)

    b.left:ClearAllPoints()
    b.left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    b.left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    b.left:SetWidth(size)

    b.right:ClearAllPoints()
    b.right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    b.right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    b.right:SetWidth(size)

    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        tint(b[side], c, mult)
        b[side]:Show()
    end
end

local function createBar(hand)
    local bar = CreateFrame("Frame", "BReST_Bar_" .. hand, bf.Group)
    bar.hand = hand
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture(M.white)

    bar.border = makeBorder(bar, "BORDER")

    bar.fill1 = bar:CreateTexture(nil, "ARTWORK")
    bar.fill2 = bar:CreateTexture(nil, "ARTWORK")

    bar.spark1 = bar:CreateTexture(nil, "OVERLAY")
    bar.spark1:SetTexture(M.spark)
    bar.spark1:SetBlendMode("ADD")
    bar.spark2 = bar:CreateTexture(nil, "OVERLAY")
    bar.spark2:SetTexture(M.spark)
    bar.spark2:SetBlendMode("ADD")

    -- The icon sits next to the bar, with a one color border behind it
    bar.iconFrame = CreateFrame("Frame", nil, bar)
    bar.iconFrame:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.iconBorder = bar.iconFrame:CreateTexture(nil, "BACKGROUND")
    bar.iconBorder:SetAllPoints(bar.iconFrame)
    bar.iconBorder:SetTexture(M.white)
    bar.icon = bar.iconFrame:CreateTexture(nil, "ARTWORK")

    -- Text goes above the fill
    bar.top = CreateFrame("Frame", nil, bar)
    bar.top:SetAllPoints(bar)
    bar.top:SetFrameLevel(bar:GetFrameLevel() + 3)

    bar.moveTex = bar.top:CreateTexture(nil, "BACKGROUND")
    bar.moveTex:SetAllPoints(bar.top)
    bar.moveTex:SetTexture(M.white)
    bar.moveTex:SetVertexColor(1, 1, 1, 0.14)
    bar.moveTex:Hide()

    bar.text = bar.top:CreateFontString(nil, "OVERLAY")
    M.SetFont(bar.text, M.fontUI, 11)

    bar.label = bar.top:CreateFontString(nil, "OVERLAY")
    M.SetFont(bar.label, M.fontUIBold, 10)
    bar.label:SetPoint("BOTTOM", bar, "TOP", 0, 3)
    bar.label:SetTextColor(1, 0.85, 0.25, 1)
    bar.label:SetText(BReST.HAND_NAMES[hand])
    bar.label:Hide()

    bar:EnableMouse(false)
    bar:SetScript("OnMouseDown", function()
        if not BReST.configMode or arg1 ~= "LeftButton" then return end
        bar.moving = true
        if BReST.GetProfile().grouped then
            bf.Group:StartMoving()
        else
            bar:StartMoving()
        end
    end)
    bar:SetScript("OnMouseUp", function()
        bf.Group:StopMovingOrSizing()
        bar:StopMovingOrSizing()
        if bar.moving then
            bar.moving = false
            bf.savePosition(bar)
        end
    end)

    return bar
end

-- The group and its bars are created once, layout() styles them
bf.build = function()
    if bf.Group then return end

    bf.Group = CreateFrame("Frame", "BReST_SwingTimer_MainFrame", UIParent)
    bf.MainFrame = bf.Group
    bf.Group:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bf.Group:SetWidth(1)
    bf.Group:SetHeight(1)
    bf.Group:SetFrameStrata("MEDIUM")
    bf.Group:SetMovable(true)
    bf.Group:SetClampedToScreen(true)

    bf.Group.bg = bf.Group:CreateTexture(nil, "BACKGROUND")
    bf.Group.bg:SetAllPoints(bf.Group)
    bf.Group.bg:SetTexture(M.white)
    bf.Group.border = makeBorder(bf.Group, "BORDER")

    bf.byHand = {}
    for i = 1, table.getn(HANDS) do
        bf.byHand[HANDS[i]] = createBar(HANDS[i])
    end
    bf.bars = {}
end

-- Geometry -----------------------------------------------------------------------------------

local function iconSize(cfg)
    if cfg.icon.matchHeight then return cfg.height end
    return cfg.icon.size
end

-- How far the icon sticks out on each side of the bar
local function iconExtent(cfg)
    local ic = cfg.icon
    if not ic.show then return 0, 0 end
    if ic.side == "LEFT" then return iconSize(cfg) + ICON_GAP, 0 end
    if ic.side == "RIGHT" then return 0, iconSize(cfg) + ICON_GAP end
    return 0, 0
end

local function placeIcon(bar, cfg)
    local ic = cfg.icon
    local size = iconSize(cfg)
    local f = bar.iconFrame
    f:SetWidth(size)
    f:SetHeight(size)
    f:ClearAllPoints()

    local bs = cfg.borderSize
    if ic.side == "RIGHT" then
        f:SetPoint("LEFT", bar, "RIGHT", ICON_GAP + bs + ic.offsetX, ic.offsetY)
    elseif ic.side == "INSIDE_LEFT" then
        f:SetPoint("LEFT", bar, "LEFT", ic.offsetX, ic.offsetY)
    elseif ic.side == "INSIDE_RIGHT" then
        f:SetPoint("RIGHT", bar, "RIGHT", ic.offsetX, ic.offsetY)
    else
        f:SetPoint("RIGHT", bar, "LEFT", -(ICON_GAP + bs) + ic.offsetX, ic.offsetY)
    end

    tint(bar.iconBorder, cfg.borderSize > 0 and cfg.borderColor or { r = 0, g = 0, b = 0, a = 0 })
    bar.icon:ClearAllPoints()
    local inset = cfg.borderSize
    if inset * 2 >= size then inset = 0 end
    bar.icon:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    bar.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    if ic.zoom then
        bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        bar.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function styleText(bar, cfg)
    local t = cfg.timer
    local fs = bar.text
    local fontPath, flags = M.FontPath(t.font, t.customFont), OUTLINES[t.outline] or ""
    local fontKey = fontPath .. "|" .. t.size .. "|" .. flags
    if fontKey ~= bar.fontKey then
        M.SetFont(fs, fontPath, t.size, flags)
        bar.fontKey = fontKey
    end
    fs:SetTextColor(t.color.r, t.color.g, t.color.b, t.color.a or 1)
    if t.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowColor(0, 0, 0, 0)
        fs:SetShadowOffset(0, 0)
    end

    fs:ClearAllPoints()
    if t.anchor == "RIGHT" then
        fs:SetPoint("RIGHT", bar, "RIGHT", -t.offsetX, t.offsetY)
        fs:SetJustifyH("RIGHT")
    elseif t.anchor == "CENTER" then
        fs:SetPoint("CENTER", bar, "CENTER", t.offsetX, t.offsetY)
        fs:SetJustifyH("CENTER")
    elseif t.anchor == "ABOVE" then
        fs:SetPoint("BOTTOM", bar, "TOP", t.offsetX, t.offsetY + 2)
        fs:SetJustifyH("CENTER")
    elseif t.anchor == "BELOW" then
        fs:SetPoint("TOP", bar, "BOTTOM", t.offsetX, t.offsetY - 2)
        fs:SetJustifyH("CENTER")
    else
        fs:SetPoint("LEFT", bar, "LEFT", t.offsetX, t.offsetY)
        fs:SetJustifyH("LEFT")
    end

    if t.show then fs:Show() else fs:Hide() end
    bar.lastText = nil
end

-- Everything that does not change while the bar runs
local function styleBar(bar, cfg)
    bar:SetWidth(cfg.width)
    bar:SetHeight(cfg.height)
    tint(bar.bg, cfg.bgColor)
    layoutBorder(bar.border, bar, cfg.borderSize, cfg.borderColor)

    local path = M.TexturePath(cfg.texture, cfg.customTexture)
    local f1, f2 = bar.fill1, bar.fill2
    f1:SetTexture(path)
    f2:SetTexture(path)
    tint(f1, cfg.color)
    tint(f2, cfg.color)
    f1:ClearAllPoints()
    f2:ClearAllPoints()
    bar.spark1:ClearAllPoints()
    bar.spark2:ClearAllPoints()

    local dir = cfg.direction
    if dir == "RTL" then
        f1:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        f1:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        bar.spark1:SetPoint("CENTER", f1, "LEFT", 0, 0)
    elseif dir == "CENTER_OUT" then
        f1:SetPoint("TOP", bar, "TOP", 0, 0)
        f1:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
        bar.spark1:SetPoint("CENTER", f1, "LEFT", 0, 0)
        bar.spark2:SetPoint("CENTER", f1, "RIGHT", 0, 0)
    elseif dir == "EDGES_IN" then
        f1:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        f1:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        f2:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        f2:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        bar.spark1:SetPoint("CENTER", f1, "RIGHT", 0, 0)
        bar.spark2:SetPoint("CENTER", f2, "LEFT", 0, 0)
    else
        f1:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        f1:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        bar.spark1:SetPoint("CENTER", f1, "RIGHT", 0, 0)
    end

    for _, spark in ipairs({ bar.spark1, bar.spark2 }) do
        spark:SetWidth(cfg.sparkWidth)
        spark:SetHeight(cfg.sparkHeight)
        tint(spark, cfg.sparkColor)
    end
    bar.twoSided = (dir == "CENTER_OUT" or dir == "EDGES_IN")

    placeIcon(bar, cfg)
    bar.iconPath = nil
    styleText(bar, cfg)

    if BReST.configMode then
        bar.moveTex:Show()
        bar.label:Show()
    else
        bar.moveTex:Hide()
        bar.label:Hide()
    end
    bar:EnableMouse(BReST.configMode)
    bar.queuedShown = nil
end

-- True when the bars are shown for what they look like, whatever is equipped or going on:
-- while unlocked, while the settings window is open and while the simulation runs
bf.showAll = function()
    return BReST.configMode or bf.preview or bf.sim.active
end

-- True when the bars ignore the hiding rules. The settings window can turn them on to test them.
bf.forceVisible = function()
    return BReST.configMode or (bf.showAll() and not bf.testHide)
end

local function inCombat()
    return BReST.inCombat or (bf.testHide and bf.sim.combat > 0)
end

local function wantBar(hand, cfg)
    if not cfg.enabled then return false end
    if bf.showAll() then return true end
    if hand == "OFF" then return BReST.utils.isDualWield() end
    if hand == "RANGED" then return BReST.utils.hasRanged() end
    return true
end

-- A bar that is not completely faded out
local function occupies(bar)
    return bar.vAlpha == nil or bar.vAlpha > 0.003
end

local function occupancy(bars)
    local sig = ""
    for i = 1, table.getn(bars) do
        sig = sig .. bars[i].hand .. (occupies(bars[i]) and "1" or "0")
    end
    return sig
end

-- The group background and border follow the most visible bar
local function tintGroup(p, fade)
    local G, g = bf.Group, p.group
    bf.groupFade = fade
    tint(G.bg, g.bgColor, fade)
    layoutBorder(G.border, G, g.borderSize, g.borderColor, fade)
end

-- Sizes the frame and shows the bars that make sense for what is equipped
bf.layout = function()
    if not bf.Group then return end
    local p = BReST.GetProfile()
    local G = bf.Group

    G:SetScale(p.scale)

    local visible = {}
    for i = 1, table.getn(HANDS) do
        local hand = HANDS[i]
        local cfg = p.bars[hand]
        local bar = bf.byHand[hand]
        styleBar(bar, cfg)
        if wantBar(hand, cfg) then
            bar.cfg = cfg
            table.insert(visible, bar)
        else
            bar:Hide()
        end
    end
    bf.bars = visible
    bf.occSig = occupancy(visible)
    local count = table.getn(visible)

    if p.grouped then
        local g = p.group
        -- The bars that take room in the group
        local stack = {}
        for i = 1, count do
            if not g.collapse or occupies(visible[i]) then table.insert(stack, visible[i]) end
        end
        local n = table.getn(stack)

        if n > 0 then
            local left, right, widest, height = 0, 0, 0, 0
            for i = 1, n do
                local cfg = stack[i].cfg
                local l, r = iconExtent(cfg)
                if l > left then left = l end
                if r > right then right = r end
                if cfg.width > widest then widest = cfg.width end
                height = height + cfg.height
            end
            height = height + (n - 1) * g.spacing

            G:SetWidth(left + widest + right + 2 * g.padding)
            G:SetHeight(height + 2 * g.padding)
            G.bg:Show()
            tintGroup(p, bf.groupFade or 1)

            local y = g.padding
            for i = 1, n do
                local bar = stack[i]
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", G, "TOPLEFT", g.padding + left, -y)
                y = y + bar.cfg.height + g.spacing
            end
        else
            G:SetWidth(1)
            G:SetHeight(1)
            G.bg:Hide()
            layoutBorder(G.border, G, 0, g.borderColor)
        end

        -- The ones left out wait where the first one is
        for i = 1, count do
            local bar = visible[i]
            local inStack = false
            for j = 1, n do
                if stack[j] == bar then inStack = true end
            end
            if not inStack then
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", G, "TOPLEFT", g.padding, -g.padding)
            end
        end
    else
        G:SetWidth(1)
        G:SetHeight(1)
        G.bg:Hide()
        layoutBorder(G.border, G, 0, p.group.borderColor)

        for i = 1, table.getn(HANDS) do
            local bar = bf.byHand[HANDS[i]]
            local cfg = p.bars[HANDS[i]]
            bar:ClearAllPoints()
            if cfg.x ~= nil and cfg.y ~= nil then
                bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.x, cfg.y)
            else
                bar:SetPoint("CENTER", UIParent, "CENTER", 0, -(i - 1) * (cfg.height + 12))
            end
        end
    end

    for i = 1, count do visible[i]:Show() end
    bf.update(0)
end

-- Position -----------------------------------------------------------------------------------

bf.restorePosition = function()
    if not bf.Group then return end
    local p = BReST.GetProfile()
    bf.Group:ClearAllPoints()
    if p.groupX ~= nil and p.groupY ~= nil then
        bf.Group:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.groupX, p.groupY)
    else
        bf.Group:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Remembers where a bar (or the group) was dropped
bf.savePosition = function(bar)
    local p = BReST.GetProfile()
    if p.grouped then
        local x, y = bf.Group:GetLeft(), bf.Group:GetTop()
        if x and y then
            p.groupX, p.groupY = x, y
            bf.restorePosition()
        end
    else
        local cfg = p.bars[bar.hand]
        local x, y = bar:GetLeft(), bar:GetTop()
        if x and y then
            cfg.x, cfg.y = x, y
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        end
    end
    if BReST.ConfigUI then BReST.ConfigUI.RefreshPage() end
end

-- Positions are in the units of the scale, so they have to follow it to stay where they are
bf.rescale = function(oldScale, newScale)
    local p = BReST.GetProfile()
    local k = oldScale / newScale
    if p.groupX ~= nil and p.groupY ~= nil then
        p.groupX, p.groupY = p.groupX * k, p.groupY * k
    end
    for i = 1, table.getn(HANDS) do
        local cfg = p.bars[HANDS[i]]
        if cfg.x ~= nil and cfg.y ~= nil then
            cfg.x, cfg.y = cfg.x * k, cfg.y * k
        end
    end
    bf.restorePosition()
end

bf.resetPosition = function()
    local p = BReST.GetProfile()
    p.groupX, p.groupY = nil, nil
    for i = 1, table.getn(HANDS) do
        local cfg = p.bars[HANDS[i]]
        cfg.x, cfg.y = nil, nil
    end
    bf.restorePosition()
    bf.layout()
end

-- Unlocking, preview, simulation -------------------------------------------------------------

bf.setConfigMode = function(on)
    BReST.configMode = on and true or false
    bf.layout()
    if BReST.ConfigUI then BReST.ConfigUI.RefreshFooter() end
end

bf.setPreview = function(on)
    bf.preview = on and true or false
    bf.layout()
end

-- While on, the preview follows the hiding rules of the bars instead of showing them all
bf.setTestHide = function(on)
    bf.testHide = on and true or false
    bf.layout()
    if BReST.ConfigUI then BReST.ConfigUI.RefreshFooter() end
end

local function simSpeed(hand)
    local speed
    if hand == "RANGED" then
        speed = BReST.utils.GetRangedSpeed()
    else
        speed = BReST.utils.GetWeaponSpeed(hand == "OFF")
    end
    if speed == nil or speed <= 0 then speed = SIM_SPEED[hand] end
    return speed
end

-- One simulated swing
bf.simSwing = function(hand)
    local sim = bf.sim
    local speed = simSpeed(hand)
    sim.timer[hand], sim.speed[hand], sim.rest[hand] = speed, speed, SIM_REST
    sim.combat = SIM_COMBAT
end

bf.setSimulating = function(on)
    local sim = bf.sim
    sim.active = on and true or false
    if sim.active then
        bf.simSwing("MAIN")
        bf.simSwing("OFF")
        bf.simSwing("RANGED")
        -- The off hand does not swing at the same time as the main hand
        sim.timer.OFF = sim.timer.OFF * 0.45
    else
        for i = 1, table.getn(HANDS) do sim.timer[HANDS[i]] = 0 end
    end
    bf.layout()
    if BReST.ConfigUI then BReST.ConfigUI.RefreshFooter() end
end

bf.setSimQueued = function(on)
    bf.sim.queued = on and true or false
    if BReST.ConfigUI then BReST.ConfigUI.RefreshFooter() end
end

local function simQueuedTexture()
    for i = 1, table.getn(BReST.onSwingList) do
        local texture = BReST.spellTextures[BReST.onSwingList[i]]
        if texture then return texture end
    end
    return QUEUED_ICON
end

local function simTick(elapsed)
    local sim = bf.sim
    if sim.active then
        sim.combat = SIM_COMBAT
    elseif sim.combat > 0 then
        sim.combat = sim.combat - elapsed
        if sim.combat < 0 then sim.combat = 0 end
    end
    for i = 1, table.getn(HANDS) do
        local hand = HANDS[i]
        if sim.timer[hand] > 0 then
            sim.timer[hand] = sim.timer[hand] - elapsed
            if sim.timer[hand] < 0 then sim.timer[hand] = 0 end
        elseif sim.active then
            sim.rest[hand] = sim.rest[hand] - elapsed
            if sim.rest[hand] <= 0 then bf.simSwing(hand) end
        end
    end
end

-- Drawing ------------------------------------------------------------------------------------

local function timerOf(hand)
    if hand == "RANGED" then
        return BReST.rangedTimer, BReST.rangedSpeed
    elseif hand == "OFF" then
        return BReST.offhandTimer, BReST.offhandSpeed
    end
    return BReST.mainhandTimer, BReST.mainhandSpeed
end

-- frac of the bar is filled, in the direction of the bar
local function setFill(bar, cfg, frac)
    if frac > 1 then frac = 1 end
    local width = cfg.width
    local f1, f2 = bar.fill1, bar.fill2
    local dir = cfg.direction

    if frac <= 0 or frac * width < 0.5 then
        f1:Hide()
        f2:Hide()
        bar.spark1:Hide()
        bar.spark2:Hide()
        return
    end

    if dir == "RTL" then
        f1:SetWidth(width * frac)
        f1:SetTexCoord(1 - frac, 1, 0, 1)
    elseif dir == "CENTER_OUT" then
        f1:SetWidth(width * frac)
        f1:SetTexCoord((1 - frac) / 2, (1 + frac) / 2, 0, 1)
    elseif dir == "EDGES_IN" then
        local half = frac / 2
        f1:SetWidth(width * half)
        f1:SetTexCoord(0, half, 0, 1)
        f2:SetWidth(width * half)
        f2:SetTexCoord(1 - half, 1, 0, 1)
        f2:Show()
    else
        f1:SetWidth(width * frac)
        f1:SetTexCoord(0, frac, 0, 1)
    end
    f1:Show()
    if dir ~= "EDGES_IN" then f2:Hide() end

    if cfg.spark then
        bar.spark1:Show()
        if bar.twoSided then bar.spark2:Show() else bar.spark2:Hide() end
    else
        bar.spark1:Hide()
        bar.spark2:Hide()
    end
end

local function iconTexture(bar, cfg, queuedTexture)
    local ic = cfg.icon
    if queuedTexture and ic.showQueued then return queuedTexture end
    if ic.source == "CUSTOM" then
        if type(ic.custom) == "string" and ic.custom ~= "" then return ic.custom end
        return M.fallbackIcon
    end
    local texture = GetInventoryItemTexture("player", SLOT[bar.hand])
    if texture == nil and bf.showAll() then texture = M.fallbackIcon end
    return texture
end

local function formatTimer(t, timer, speed)
    local decimals = t.decimals
    local fmt = "%." .. decimals .. "f"
    local text = string.format(fmt, timer)
    if t.format == "REMAINING_S" then
        return text .. "s"
    elseif t.format == "REMAINING_TOTAL" then
        return text .. " / " .. string.format(fmt, speed)
    end
    return text
end

local function ease(a, style)
    if style == "SMOOTH" then
        return a * a * (3 - 2 * a)
    elseif style == "EASE_OUT" then
        return 1 - (1 - a) * (1 - a)
    elseif style == "INSTANT" then
        if a > 0 then return 1 end
        return 0
    end
    return a
end

-- Moves the opacity of the bar towards where its hiding rules want it
local function advanceVisibility(bar, cfg, running, elapsed)
    local v = cfg.vis

    local want = true
    if not bf.forceVisible() then
        if v.hideOutOfCombat and not inCombat() then want = false end
        if v.hideWhenIdle and not running then want = false end
    end

    local target = 1
    if want then
        bar.hold = v.hideDelay
    else
        target = 0
        -- The bar stays for hideDelay seconds before it starts to fade
        if bar.hold ~= nil and bar.hold > 0 then
            bar.hold = bar.hold - elapsed
            target = 1
        end
    end

    local a = bar.rawAlpha
    if a == nil then a = target end
    if target > a then
        if v.fadeIn > 0 then
            a = a + elapsed / v.fadeIn
            if a > target then a = target end
        else
            a = target
        end
    elseif target < a then
        if v.fadeOut > 0 and v.fadeStyle ~= "INSTANT" then
            a = a - elapsed / v.fadeOut
            if a < target then a = target end
        else
            a = target
        end
    end
    bar.rawAlpha = a
    bar.vAlpha = ease(a, v.fadeStyle)
    return bar.vAlpha
end

local function renderBar(bar, elapsed)
    local cfg = bar.cfg
    local hand = bar.hand
    local sim = bf.sim

    local timer, speed
    local queued, queuedTexture = false, nil

    if sim.active or sim.timer[hand] > 0 then
        timer, speed = sim.timer[hand], sim.speed[hand]
    else
        timer, speed = timerOf(hand)
        if timer <= 0 and bf.forceVisible() then
            -- Nothing is swinging, show something to look at
            speed = simSpeed(hand)
            timer = speed * DEMO_FRACTION
        end
    end
    local running = (timer > 0 and speed > 0)

    local alpha = advanceVisibility(bar, cfg, running, elapsed)
    bar:SetAlpha(alpha)
    if alpha <= 0.003 then return end

    if hand == "MAIN" then
        if BReST.queuedName then
            queued, queuedTexture = true, BReST.queuedTexture
        elseif sim.queued and bf.showAll() then
            queued, queuedTexture = true, simQueuedTexture()
        end
    end

    local frac = 0
    if running then
        local remaining = timer / speed
        if remaining > 1 then remaining = 1 end
        if cfg.mode == "FILL" then frac = 1 - remaining else frac = remaining end
    elseif cfg.mode == "FILL" and cfg.holdFull and (inCombat() or bf.showAll()) then
        frac = 1
    end
    setFill(bar, cfg, frac)

    -- Another color while a swing spell is queued
    local useQueued = queued and cfg.queuedTint
    if useQueued ~= bar.queuedShown then
        bar.queuedShown = useQueued
        local c = useQueued and cfg.queuedColor or cfg.color
        tint(bar.fill1, c)
        tint(bar.fill2, c)
    end

    local text = ""
    if running and cfg.timer.show then text = formatTimer(cfg.timer, timer, speed) end
    if text ~= bar.lastText then
        bar.text:SetText(text)
        bar.lastText = text
    end

    local texture = iconTexture(bar, cfg, queuedTexture)
    if texture ~= bar.iconPath then
        bar.iconPath = texture
        if texture then bar.icon:SetTexture(texture) end
        if texture and cfg.icon.zoom then bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
    if cfg.icon.show and texture then bar.iconFrame:Show() else bar.iconFrame:Hide() end
end

bf.update = function(elapsed)
    if not bf.Group or not bf.bars then return end
    local p = BReST.GetProfile()

    simTick(elapsed)

    bf.Group:SetAlpha(p.alpha)
    bf.Group:Show()

    local bars = bf.bars
    local top = 0
    for i = 1, table.getn(bars) do
        renderBar(bars[i], elapsed)
        if bars[i].vAlpha > top then top = bars[i].vAlpha end
    end

    -- A bar showed up or finished fading: the room it takes in the group changes
    if p.grouped and p.group.collapse and occupancy(bars) ~= bf.occSig then
        bf.layout()
        return
    end

    if p.grouped and math.abs(top - (bf.groupFade or 1)) > 0.004 then
        tintGroup(p, top)
    end
end
