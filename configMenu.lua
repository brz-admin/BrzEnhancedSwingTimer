BReST.ConfigFrame = CreateFrame("Frame", "BReST.ConfigFrame", UIParent)
BReST.ConfigFrame:SetWidth(300)
BReST.ConfigFrame:SetHeight(200)
BReST.ConfigFrame:SetPoint("CENTER")
BReST.ConfigFrame:Hide()
BReST.ConfigFrame:SetFrameStrata("DIALOG")
BReST.ConfigFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

BReST.ConfigFrame:SetBackdropColor(0,0,0,0.5)

BReST.ConfigFrame.Title = BReST.ConfigFrame:CreateFontString("BReST.ConfigFrame_Title", "ARTWORK")
BReST.ConfigFrame.Title:SetPoint("TOP", BReST.ConfigFrame, "TOP", 0, -20)
BReST.ConfigFrame.Title:SetText("BReST Config")

BReST.ConfigFrame.ProfileSelect = CreateFrame("Dropdown", "BReST.ConfigFrame_ProfileSelect", BReST.ConfigFrame)
BReST.ConfigFrame.ProfileSelect:SetPoint("TOPLEFT", BReST.ConfigFrame, "TOPLEFT", 10, -50)
BReST.ConfigFrame.ProfileSelect.initialize = function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.func = self.SetValue
    info.owner = self
    info.checked = false
    info.menuList = {}
    if level == 1 then
        for k, _ in pairs(BReST_Profiles) do
            info.text = k
            info.value = k
            info.arg1 = self
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

BReST.ConfigFrame.ProfileSelect.SetValue = function(self, value)
    BReST_Config.profile = value
    BReST_Profiles[value] = BReST_Profiles[value] or {}
    for k, v in pairs(BReST_Profiles[value]) do
        BReST_Config[k] = v
    end
    UIDropDownMenu_SetText(self, value)
end

BReST.ConfigFrame.ProfileSelect.initialize(BReST.ConfigFrame.ProfileSelect, 1)

BReST.ConfigFrame.SaveButton = CreateFrame("Button", "BReST.ConfigFrame_SaveButton", BReST.ConfigFrame)
BReST.ConfigFrame.SaveButton:SetPoint("BOTTOMLEFT", BReST.ConfigFrame, "BOTTOMLEFT", 10, 10)
BReST.ConfigFrame.SaveButton:SetText("Save")
BReST.ConfigFrame.SaveButton:SetWidth(100)
BReST.ConfigFrame.SaveButton:SetHeight(25)
BReST.ConfigFrame.SaveButton:SetScript("OnClick", function(self)
    for k, v in pairs(BReST_Config) do
        if k ~= "profile" then
            BReST_Profiles[BReST_Config.profile][k] = v
        end
    end
    BReST.ConfigFrame:Hide()
end)

BReST.ConfigFrame.LoadButton = CreateFrame("Button", "BReST.ConfigFrame_LoadButton", BReST.ConfigFrame)
BReST.ConfigFrame.LoadButton:SetPoint("BOTTOMLEFT", BReST.ConfigFrame.SaveButton, "BOTTOMRIGHT", 10, 0)
BReST.ConfigFrame.LoadButton:SetText("Load")
BReST.ConfigFrame.LoadButton:SetWidth(100)
BReST.ConfigFrame.LoadButton:SetHeight(25)
BReST.ConfigFrame.LoadButton:SetScript("OnClick", function(self)
    BReST.ConfigFrame.ProfileSelect:SetValue(BReST_Config.profile)
end)

BReST.ConfigFrame:Show()

BReST.ConfigFrame.BarHeightSlider = CreateFrame("Slider", "BReST.ConfigFrame_BarHeightSlider", BReST.ConfigFrame)
BReST.ConfigFrame.BarHeightSlider:SetWidth(200)
BReST.ConfigFrame.BarHeightSlider:SetHeight(20)
BReST.ConfigFrame.BarHeightSlider:SetPoint("TOPLEFT", BReST.ConfigFrame, "TOPLEFT", 10, -10)
BReST.ConfigFrame.BarHeightSlider:SetMinMaxValues(5, 50)
BReST.ConfigFrame.BarHeightSlider:SetValue(BReST_Config.barHeight)
BReST.ConfigFrame.BarHeightSlider:SetObeyStepOnDrag(true)
BReST.ConfigFrame.BarHeightSlider:SetValueStep(1)
BReST.ConfigFrame.BarHeightSlider:SetScript("OnValueChanged", function(self, value)
    BReST_Config.barHeight = value
end)

BReST.ConfigFrame.BarHeightSliderLabel = BReST.ConfigFrame.BarHeightSlider:CreateFontString("BReST.ConfigFrame_BarHeightSliderLabel", "ARTWORK")
BReST.ConfigFrame.BarHeightSliderLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BarHeightSlider, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BarHeightSliderLabel:SetText("Bar Height")

BReST.ConfigFrame.BarWidthSlider = CreateFrame("Slider", "BReST.ConfigFrame_BarWidthSlider", BReST.ConfigFrame)
BReST.ConfigFrame.BarWidthSlider:SetWidth(200)
BReST.ConfigFrame.BarWidthSlider:SetHeight(20)
BReST.ConfigFrame.BarWidthSlider:SetPoint("TOPLEFT", BReST.ConfigFrame.BarHeightSlider, "BOTTOMLEFT", 0, -10)
BReST.ConfigFrame.BarWidthSlider:SetMinMaxValues(50, 500)
BReST.ConfigFrame.BarWidthSlider:SetValue(BReST_Config.barWidth)
BReST.ConfigFrame.BarWidthSlider:SetObeyStepOnDrag(true)
BReST.ConfigFrame.BarWidthSlider:SetValueStep(1)
BReST.ConfigFrame.BarWidthSlider:SetScript("OnValueChanged", function(self, value)
    BReST_Config.barWidth = value
end)

BReST.ConfigFrame.BarWidthSliderLabel = BReST.ConfigFrame.BarWidthSlider:CreateFontString("BReST.ConfigFrame_BarWidthSliderLabel", "ARTWORK")
BReST.ConfigFrame.BarWidthSliderLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BarWidthSlider, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BarWidthSliderLabel:SetText("Bar Width")

BReST.ConfigFrame.BarSpacingSlider = CreateFrame("Slider", "BReST.ConfigFrame_BarSpacingSlider", BReST.ConfigFrame)
BReST.ConfigFrame.BarSpacingSlider:SetWidth(200)
BReST.ConfigFrame.BarSpacingSlider:SetHeight(20)
BReST.ConfigFrame.BarSpacingSlider:SetPoint("TOPLEFT", BReST.ConfigFrame.BarWidthSlider, "BOTTOMLEFT", 0, -10)
BReST.ConfigFrame.BarSpacingSlider:SetMinMaxValues(0, 20)
BReST.ConfigFrame.BarSpacingSlider:SetValue(BReST_Config.barSpacing)
BReST.ConfigFrame.BarSpacingSlider:SetObeyStepOnDrag(true)
BReST.ConfigFrame.BarSpacingSlider:SetValueStep(1)
BReST.ConfigFrame.BarSpacingSlider:SetScript("OnValueChanged", function(self, value)
    BReST_Config.barSpacing = value
end)

BReST.ConfigFrame.BarSpacingSliderLabel = BReST.ConfigFrame.BarSpacingSlider:CreateFontString("BReST.ConfigFrame_BarSpacingSliderLabel", "ARTWORK")
BReST.ConfigFrame.BarSpacingSliderLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BarSpacingSlider, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BarSpacingSliderLabel:SetText("Bar Spacing")

BReST.ConfigFrame.BarPaddingSlider = CreateFrame("Slider", "BReST.ConfigFrame_BarPaddingSlider", BReST.ConfigFrame)
BReST.ConfigFrame.BarPaddingSlider:SetWidth(200)
BReST.ConfigFrame.BarPaddingSlider:SetHeight(20)
BReST.ConfigFrame.BarPaddingSlider:SetPoint("TOPLEFT", BReST.ConfigFrame.BarSpacingSlider, "BOTTOMLEFT", 0, -10)
BReST.ConfigFrame.BarPaddingSlider:SetMinMaxValues(0, 20)
BReST.ConfigFrame.BarPaddingSlider:SetValue(BReST_Config.barPadding)
BReST.ConfigFrame.BarPaddingSlider:SetObeyStepOnDrag(true)
BReST.ConfigFrame.BarPaddingSlider:SetValueStep(1)
BReST.ConfigFrame.BarPaddingSlider:SetScript("OnValueChanged", function(self, value)
    BReST_Config.barPadding = value
end)

BReST.ConfigFrame.BarPaddingSliderLabel = BReST.ConfigFrame.BarPaddingSlider:CreateFontString("BReST.ConfigFrame_BarPaddingSliderLabel", "ARTWORK")
BReST.ConfigFrame.BarPaddingSliderLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BarPaddingSlider, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BarPaddingSliderLabel:SetText("Bar Padding")

BReST.ConfigFrame.BackgroundOpacitySlider = CreateFrame("Slider", "BReST.ConfigFrame_BackgroundOpacitySlider", BReST.ConfigFrame)
BReST.ConfigFrame.BackgroundOpacitySlider:SetWidth(200)
BReST.ConfigFrame.BackgroundOpacitySlider:SetHeight(20)
BReST.ConfigFrame.BackgroundOpacitySlider:SetPoint("TOPLEFT", BReST.ConfigFrame.BarPaddingSlider, "BOTTOMLEFT", 0, -10)
BReST.ConfigFrame.BackgroundOpacitySlider:SetMinMaxValues(0, 1)
BReST.ConfigFrame.BackgroundOpacitySlider:SetValue(BReST_Config.backgroundOpacity)
BReST.ConfigFrame.BackgroundOpacitySlider:SetObeyStepOnDrag(true)
BReST.ConfigFrame.BackgroundOpacitySlider:SetValueStep(0.01)
BReST.ConfigFrame.BackgroundOpacitySlider:SetScript("OnValueChanged", function(self, value)
    BReST_Config.backgroundOpacity = value
end)

BReST.ConfigFrame.BackgroundOpacitySliderLabel = BReST.ConfigFrame.BackgroundOpacitySlider:CreateFontString("BReST.ConfigFrame_BackgroundOpacitySliderLabel", "ARTWORK")
BReST.ConfigFrame.BackgroundOpacitySliderLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BackgroundOpacitySlider, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BackgroundOpacitySliderLabel:SetText("Background Opacity")

BReST.ConfigFrame.BackgroundColorEditBox = CreateFrame("EditBox", "BReST.ConfigFrame_BackgroundColorEditBox", BReST.ConfigFrame)
BReST.ConfigFrame.BackgroundColorEditBox:SetWidth(200)
BReST.ConfigFrame.BackgroundColorEditBox:SetHeight(20)
BReST.ConfigFrame.BackgroundColorEditBox:SetPoint("TOPLEFT", BReST.ConfigFrame.BackgroundOpacitySlider, "BOTTOMLEFT", 0, -10)
BReST.ConfigFrame.BackgroundColorEditBox:SetText(string.format("%f %f %f", BReST_Config.backgroundColor.r, BReST_Config.backgroundColor.g, BReST_Config.backgroundColor.b))
BReST.ConfigFrame.BackgroundColorEditBox:SetAutoFocus(false)
BReST.ConfigFrame.BackgroundColorEditBox:SetScript("OnEditFocusLost", function(self)
    local r, g, b = strsplit(" ", self:GetText())
    BReST_Config.backgroundColor = {
        r = tonumber(r) or 0,
        g = tonumber(g) or 0,
        b = tonumber(b) or 0,
    }
end)

BReST.ConfigFrame.BackgroundColorEditBoxLabel = BReST.ConfigFrame.BackgroundColorEditBox:CreateFontString("BReST.ConfigFrame_BackgroundColorEditBoxLabel", "ARTWORK")
BReST.ConfigFrame.BackgroundColorEditBoxLabel:SetPoint("TOPLEFT", BReST.ConfigFrame.BackgroundColorEditBox, "TOPLEFT", 0, 15)
BReST.ConfigFrame.BackgroundColorEditBoxLabel:SetText("Background Color")
