BReST.Frame = {}
local bf = BReST.Frame
BReST_Profiles.default = {
    profile = "Default",
    barHeight = 20,
    barWidth = 200,
    barSpacing = 5,
    barPadding = 5,
    backgroundOpacity = 0.5,
    backgroundColor = {r = 0, g = 0, b = 0},
    barColor = {r = 0.8, g = 0.5, b = 0.2},
    showTimer = true,
    showIcon = true,
    hideOutOfCombat = false,
    updateTime = 0.1,
    fadeTime = 1,
    hideTime = 3,
    barAlpha = 1
}

-- stored as local value for better performances
local currProfile = BReST_Profiles[BReST_Config.profile]
local barHeight = currProfile.barHeight
local barWidth = currProfile.barWidth
local barSpacing = currProfile.barSpacing
local barPadding = currProfile.barPadding
local backgroundOpacity = currProfile.backgroundOpacity
local backgroundColor = currProfile.backgroundColor
local barColor = currProfile.barColor
local showTimer = currProfile.showTimer
local showIcon = currProfile.showIcon
local hideOutOfCombat = currProfile.hideOutOfCombat
local mainFrameWidth = barWidth + 2 * barPadding
local updateTime = currProfile.updateTime
local fadeTime = currProfile.fadeTime
local hideTime = currProfile.hideTime
local barAlpha = currProfile.barAlpha
local mainFrameHeight = barHeight + 2 * barPadding
local iconWidth = barHeight
local iconHeight = barHeight


bf.buildFrame = function()
    bf.MainFrame.Hide()
    bf.MainFrame = nil
    bf.MainFrame = {}
    bf.MainFrame = CreateFrame("Frame", "BReST_SwingTimer_MainFrame", UIParent)
    bf.MainFrame:SetPoint("CENTER")
    bf.MainFrame:SetWidth(mainFrameWidth)
    bf.MainFrame:SetHeight(barHeight)
    bf.MainFrame:SetFrameStrata("BACKGROUND")
    bf.MainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bf.MainFrame:SetBackdropColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)
    local isDualWield = BReST.utils.isDualWield()

    bf.MainhandBar = CreateFrame("StatusBar", "BReST_SwingTimer_MainhandBar", bf.MainFrame)
    bf.MainhandBar:SetPoint("TOPLEFT", bf.MainFrame, "TOPLEFT", barPadding, -barPadding)
    bf.MainhandBar:SetWidth(0)
    local actualBarsHeight = barHeight / (isDualWield and 2 or 1) - (isDualWield and math.ceil(barSpacing / 2) or 0)
    bf.MainhandBar:SetHeight(actualBarsHeight)
    bf.MainhandBar:SetStatusBarTexture("Interface\\AddOns\\BReST\\bar")
    bf.MainhandBar:GetStatusBarTexture():SetHorizTile(false)
    bf.MainhandBar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)

    bf.MainhandIcon = bf.MainhandBar:CreateTexture("BReST_SwingTimer_MainhandIcon", "ARTWORK")
    bf.MainhandIcon:SetWidth(actualBarsHeight)
    bf.MainhandIcon:SetHeight(actualBarsHeight)
    bf.MainhandIcon:SetPoint("LEFT", bf.MainhandBar, "LEFT", -barPadding, 0)
    if (showIcon) then
        bf.MainhandIcon:Show()
    else
        bf.MainhandIcon:Hide()
    end

    bf.MainhandText = bf.MainhandBar:CreateFontString("BReST_SwingTimer_MainhandText", "ARTWORK")
    bf.MainhandText:SetPoint("LEFT", bf.MainhandBar, "LEFT", barPadding, 0)
    bf.MainhandText:SetText("0")
    if (showTimer) then
        bf.MainhandText:Show()
    else
        bf.MainhandText:Hide()
    end

    bf.OffhandBar = CreateFrame("StatusBar", "BReST_SwingTimer_OffhandBar", bf.MainFrame)
    bf.OffhandBar:SetPoint("TOPLEFT", bf.MainhandBar, "BOTTOMLEFT", 0, -barSpacing)
    bf.OffhandBar:SetWidth(0)
    bf.OffhandBar:SetHeight(actualBarsHeight)
    bf.OffhandBar:SetStatusBarTexture("Interface\\AddOns\\BReST\\bar")
    bf.OffhandBar:GetStatusBarTexture():SetHorizTile(false)
    bf.OffhandBar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)

    bf.OffhandIcon = bf.OffhandBar:CreateTexture("BReST_SwingTimer_OffhandIcon", "ARTWORK")
    bf.OffhandIcon:SetWidth(actualBarsHeight)
    bf.OffhandIcon:SetHeight(actualBarsHeight)
    bf.OffhandIcon:SetPoint("LEFT", bf.OffhandBar, "LEFT", -barPadding, 0)
  
    bf.OffhandText = bf.OffhandBar:CreateFontString("BReST_SwingTimer_OffhandText", "ARTWORK")
    bf.OffhandText:SetPoint("LEFT", bf.OffhandBar, "LEFT", barPadding, 0)
    bf.OffhandText:SetText("0")

    if BReST.utils.isDualWield() then
        bf.OffhandBar:Show()

        if (showTimer) then
            bf.OffhandText:Show()
        else
            bf.OffhandText:Hide()
        end

        if (showIcon) then
            bf.OffhandIcon:Show()
        else
            bf.OffhandIcon:Hide()
        end
    else
        bf.OffhandBar:Hide()
        bf.OffhandIcon:Hide()
        bf.OffhandText:Hide()
    end

    if (hideOutOfCombat and not InCombatLockdown() and not BReST.configMode) then
        bf.MainFrame:Hide()
    end
end

bf.update = function(elapsed)

    if (bf.MainFrame == nil) then return end

    -- Early return check, we must Hide and stop when :
    -- - We hide out of combat and are not id combat
    -- - have fade timer ended 
    if (hideOutOfCombat and notInCombatLockDown() and not BReST.configMode and BReST.fadeTimer == 0 and BReST.hideTimer == 0) then
        bf.MainFrame:Hide()
        return
    end

    if (hideOutOfCombat and notInCombatLockDown() and not BReST.configMode and BReST.fadeTimer > 0) then
        BReST.fadeTimer = BReST.fadeTimer - elapsed
        if (BReST.fadeTimer < 0) then BReST.fadeTimer = 0 end
        -- Set opacity value
        local opacity = BReST.fadeTimer / fadeTime
        bf.MainFrame:SetAlpha(opacity * barAlpha)
        if (opacity == 0) then return end;
    end

    if (hideOutOfCombat and notInCombatLockDown() and not BReST.configMode and BReST.hideTimer > 0) then
        BReST.hideTimer = BReST.hideTimer - elapsed
        if (BReST.hideTimer < 0) then BReST.hideTimer = 0 end
        if (BReST.hideTimer == 0) then BReST.fadeTimer = fadeTime end
    end

    -- if it's not fading and it's shown then we should use correct alpha
    if (BReST.fadeTimer == 0) then
        bf.MainFrame:SetAlpha(barAlpha);
    end

    -- if we are here bar should probably be shown so make sure of it
    bf.MainFrame:Show()

    if (BReST.rangedTimer > 0) then
        bf.MainhandBar:Show()
        bf.MainhandBar:SetHeight(barHeight)

        local actualBarWidth = (BReST.rangedTimer / BReST.utils.GetRangedSpeed()) * barWidth
        bf.MainhandBar:SetWidth(actualBarWidth)
        bf.MainhandIcon:SetTexture() -- @TODO
    end

    if (BReST.mainhandTimer > 0) then
        bf.MainhandBar:Show()
        bf.MainhandBar:SetHeight(barHeight)

        local actualBarWidth = (BReST.mainhandTimer / BReST.utils.GetWeaponSpeed()) * barWidth
        bf.MainhandBar:SetWidth(actualBarWidth)
        bf.MainhandIcon:SetTexture() -- @TODO
    end

    if (BReST.offhandTimer > 0) then
        bf.OffhandBar:Show()
        bf.OffhandBar:SetHeight(barHeight)

        local actualBarWidth = (BReST.offhandTimer / BReST.utils.GetWeaponSpeed(true)) * barWidth
        bf.OffhandBar:SetWidth(actualBarWidth)
        bf.OffhandIcon:SetTexture() -- @TODO
    end
end
