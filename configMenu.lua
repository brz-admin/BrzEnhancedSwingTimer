-- The settings window: opened with /brest.
-- Nothing in here uses the stock UI art, every widget is drawn from flat colored textures
-- (Textures/white.tga) and the bundled font, so it can be styled without any template.
BReST.ConfigUI = {}
local UI = BReST.ConfigUI
local M = BReST.Media
local HANDS = BReST.HANDS

-- Theme --------------------------------------------------------------------------------------

local T = {
    bg = { 0.067, 0.071, 0.090, 0.98 },
    side = { 0.047, 0.050, 0.066, 1 },
    panel = { 0.094, 0.098, 0.125, 1 },
    control = { 0.133, 0.141, 0.176, 1 },
    hover = { 0.192, 0.204, 0.255, 1 },
    border = { 0.200, 0.212, 0.263, 1 },
    text = { 0.90, 0.91, 0.94, 1 },
    dim = { 0.55, 0.57, 0.64, 1 },
    accent = { 0.66, 0.47, 1.00, 1 }, -- violet
    accentBg = { 0.20, 0.14, 0.36, 1 },
    gold = { 1.00, 0.82, 0.32, 1 },
    danger = { 0.95, 0.35, 0.35, 1 },
}

local WIN_W, WIN_H = 724, 560
local TITLE_H, FOOT_H, SIDE_W = 34, 54, 156
local CONTENT_W = WIN_W - SIDE_W
local CONTENT_H = WIN_H - TITLE_H - FOOT_H
local TAB_H = 36
local PAGE_X = 18
local PAGE_W = CONTENT_W - 2 * PAGE_X -- scroll area, with the room of the scroll bar at the right
local SCROLL_W = 14
local COL_GAP = 16
local ROW_GAP = 8
local LEVEL_TOP = 40 -- frame level of the parts that must stay above scrolled widgets

-- Drawing helpers ----------------------------------------------------------------------------

local function setColor(t, c)
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

local function newTexture(parent, layer, c)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(M.white)
    if c then setColor(t, c) end
    return t
end

-- One pixel border inside of a frame
local function edges(frame, c)
    local e = {}
    e.top = newTexture(frame, "BORDER", c)
    e.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    e.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    e.top:SetHeight(1)
    e.bottom = newTexture(frame, "BORDER", c)
    e.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    e.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    e.bottom:SetHeight(1)
    e.left = newTexture(frame, "BORDER", c)
    e.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    e.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    e.left:SetWidth(1)
    e.right = newTexture(frame, "BORDER", c)
    e.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    e.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    e.right:SetWidth(1)
    e.SetColor = function(col)
        setColor(e.top, col)
        setColor(e.bottom, col)
        setColor(e.left, col)
        setColor(e.right, col)
    end
    return e
end

local function label(parent, str, size, c, bold, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    M.SetFont(fs, bold and M.fontUIBold or M.fontUI, size)
    c = c or T.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(str or "")
    return fs
end

local function panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = newTexture(f, "BACKGROUND", bg)
    f.bg:SetAllPoints(f)
    f.edge = edges(f, border or T.border)
    return f
end

local function round(v)
    return math.floor(v + 0.5)
end

-- Bindings: a get and a set on a value of the current profile -------------------------------

local function prof()
    return BReST.GetProfile()
end

-- "icon.size" -> the table that holds it and the key
local function field(root, path)
    local tbl, key = root, path
    while true do
        local s, e, head, rest = string.find(key, "^([^%.]+)%.(.+)$")
        if not s then break end
        tbl, key = tbl[head], rest
    end
    return tbl, key
end

local function Bind(rootFn, path)
    return {
        get = function()
            local t, k = field(rootFn(), path)
            return t[k]
        end,
        set = function(v)
            local t, k = field(rootFn(), path)
            t[k] = v
        end,
    }
end

local function barOf(hand)
    return function() return BReST.GetProfile().bars[hand] end
end

-- Widgets ------------------------------------------------------------------------------------
-- Each one is a frame with Refresh() (read the value again) and, once it sits in a page,
-- SetEnabled(). Changing a value goes through UI.Changed().

local function Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(height)
    b.bg = newTexture(b, "BACKGROUND", T.control)
    b.bg:SetAllPoints(b)
    b.edge = edges(b, T.border)
    b.text = label(b, text, 11, T.text, true, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.active = false
    b.hovered = false

    b.Style = function()
        if b.active then
            setColor(b.bg, T.accentBg)
            b.edge.SetColor(T.accent)
            b.text:SetTextColor(T.gold[1], T.gold[2], T.gold[3], 1)
        else
            if b.hovered then setColor(b.bg, T.hover) else setColor(b.bg, T.control) end
            b.edge.SetColor(T.border)
            b.text:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
        end
    end
    b.SetActive = function(on)
        b.active = on and true or false
        b.Style()
    end
    b.SetLabel = function(s)
        b.text:SetText(s)
    end

    b:SetScript("OnEnter", function()
        b.hovered = true
        b.Style()
    end)
    b:SetScript("OnLeave", function()
        b.hovered = false
        b.Style()
    end)
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)
    return b
end

local function Checkbox(parent, text, bind)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(22)
    f.box = panel(f, T.control, T.border)
    f.box:SetWidth(16)
    f.box:SetHeight(16)
    f.box:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.check = f.box:CreateTexture(nil, "OVERLAY")
    f.check:SetTexture(M.check)
    setColor(f.check, T.gold)
    f.check:SetAllPoints(f.box)
    f.text = label(f, text, 11, T.text)
    f.text:SetPoint("LEFT", f.box, "RIGHT", 8, 0)

    f.Refresh = function()
        if bind.get() then f.check:Show() else f.check:Hide() end
    end
    f:SetScript("OnEnter", function() f.box.edge.SetColor(T.accent) end)
    f:SetScript("OnLeave", function() f.box.edge.SetColor(T.border) end)
    f:SetScript("OnClick", function()
        bind.set(not bind.get())
        UI.Changed()
    end)
    return f
end

-- A line of dim text, `lines` is how many lines it takes
local function Note(parent, text, lines)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(lines * 14)
    f.text = label(f, text, 10, T.dim)
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.OnWidth = function(w) f.text:SetWidth(w) end
    return f
end

local function Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(26)
    f.text = label(f, text, 12, T.gold, true)
    f.text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 6)
    f.line = newTexture(f, "ARTWORK", T.border)
    f.line:SetHeight(1)
    f.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    return f
end

-- An EditBox with the look of the other controls
local function InputBox(parent, width, height)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetWidth(width)
    e:SetHeight(height)
    e:SetAutoFocus(false)
    e:SetFont(M.fontUI, 11)
    e:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
    if e.SetTextInsets then e:SetTextInsets(6, 6, 0, 0) end
    e.bg = newTexture(e, "BACKGROUND", T.control)
    e.bg:SetAllPoints(e)
    e.edge = edges(e, T.border)
    e.focused = false
    e:SetScript("OnEditFocusGained", function()
        e.focused = true
        e.edge.SetColor(T.accent)
    end)
    e:SetScript("OnEditFocusLost", function()
        e.focused = false
        e.edge.SetColor(T.border)
        if e.OnCommit then e.OnCommit() end
    end)
    e:SetScript("OnEscapePressed", function()
        if e.OnCancel then e.OnCancel() end
        e:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function()
        e:ClearFocus()
    end)
    return e
end

local function Slider(parent, text, min, max, step, bind)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(40)
    f.trackW = 200

    local decimals = 0
    if step < 1 then decimals = 1 end
    if step < 0.1 then decimals = 2 end
    local fmt = "%." .. decimals .. "f"

    f.text = label(f, text, 11, T.dim)
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    f.input = InputBox(f, 58, 18)
    f.input:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 2)
    f.input:SetJustifyH("CENTER")
    f.input:SetMaxLetters(8)

    local s = CreateFrame("Slider", nil, f)
    f.slider = s
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(14)
    s:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
    s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 2)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)

    s.track = newTexture(s, "BACKGROUND", T.control)
    s.track:SetHeight(4)
    s.track:SetPoint("LEFT", s, "LEFT", 0, 0)
    s.track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    s.fill = newTexture(s, "ARTWORK", T.accent)
    s.fill:SetHeight(4)
    s.fill:SetPoint("LEFT", s, "LEFT", 0, 0)
    s.fill:SetWidth(1)
    s:SetThumbTexture(M.white)
    local thumb = s:GetThumbTexture()
    thumb:SetWidth(8)
    thumb:SetHeight(14)
    setColor(thumb, T.gold)

    local function snap(v)
        v = math.floor(v / step + 0.5) * step
        if v < min then v = min elseif v > max then v = max end
        return tonumber(string.format(fmt, v))
    end

    local function updateFill(v)
        local ratio = (v - min) / (max - min)
        if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
        s.fill:SetWidth(math.max(1, ratio * (f.trackW - 8) + 4))
    end

    f.OnWidth = function(w)
        f.trackW = w
        updateFill(s:GetValue())
    end

    f.Refresh = function()
        local v = bind.get()
        if v == nil then return end
        f.updating = true
        s:SetMinMaxValues(min, max)
        s:SetValue(v)
        f.updating = false
        if not f.input.focused then f.input:SetText(string.format(fmt, v)) end
        updateFill(v)
    end

    s:SetScript("OnValueChanged", function()
        if f.updating then return end
        local v = snap(s:GetValue())
        bind.set(v)
        f.input:SetText(string.format(fmt, v))
        updateFill(v)
        UI.Changed()
    end)

    f.input.OnCommit = function()
        local v = tonumber(f.input:GetText())
        if v ~= nil then
            v = snap(v)
            bind.set(v)
            UI.Changed()
        end
        f.input:SetText(string.format(fmt, bind.get()))
    end
    f.input.OnCancel = function()
        f.input:SetText(string.format(fmt, bind.get()))
    end

    return f
end

local function TextField(parent, text, bind, maxLetters)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(44)
    f.text = label(f, text, 11, T.dim)
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    f.input = InputBox(f, 100, 22)
    f.input:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.input:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.input:SetMaxLetters(maxLetters or 200)

    f.Refresh = function()
        if not f.input.focused then f.input:SetText(tostring(bind.get() or "")) end
    end
    f.input.OnCommit = function()
        bind.set(f.input:GetText())
        UI.Changed()
    end
    f.input.OnCancel = function()
        f.input:SetText(tostring(bind.get() or ""))
    end
    return f
end

local function Dropdown(parent, text, optionsFn, bind, decorate)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(44)
    f.text = label(f, text, 11, T.dim)
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local b = CreateFrame("Button", nil, f)
    f.button = b
    b:SetHeight(22)
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    b.bg = newTexture(b, "BACKGROUND", T.control)
    b.bg:SetAllPoints(b)
    b.edge = edges(b, T.border)
    b.value = label(b, "", 11, T.text)
    b.value:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetTexture(M.arrow)
    setColor(b.arrow, T.dim)
    b.arrow:SetWidth(16)
    b.arrow:SetHeight(16)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)

    b:SetScript("OnEnter", function()
        setColor(b.bg, T.hover)
    end)
    b:SetScript("OnLeave", function()
        setColor(b.bg, T.control)
    end)
    b:SetScript("OnClick", function()
        UI.OpenDropdown(b, optionsFn(), bind.get(), function(v)
            bind.set(v)
            UI.Changed()
        end, decorate)
    end)
    f.OnWidth = function(w)
        b.fullWidth = w
    end

    f.Refresh = function()
        local current = bind.get()
        local shown = tostring(current)
        local options = optionsFn()
        for i = 1, table.getn(options) do
            if options[i].value == current then shown = options[i].text end
        end
        b.value:SetText(shown)
    end
    return f
end

local function ColorField(parent, text, bind, hasAlpha)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(26)
    f.text = label(f, text, 11, T.dim)
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)

    local b = CreateFrame("Button", nil, f)
    b:SetWidth(52)
    b:SetHeight(20)
    b:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    b.bg = newTexture(b, "BACKGROUND", T.control)
    b.bg:SetAllPoints(b)
    b.edge = edges(b, T.border)
    -- Left half is the color alone, right half shows it with its opacity
    b.solid = newTexture(b, "ARTWORK", T.text)
    b.solid:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.solid:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
    b.solid:SetWidth(24)
    b.alpha = newTexture(b, "ARTWORK", T.text)
    b.alpha:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    b.alpha:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.alpha:SetWidth(24)

    b:SetScript("OnEnter", function() b.edge.SetColor(T.accent) end)
    b:SetScript("OnLeave", function() b.edge.SetColor(T.border) end)
    b:SetScript("OnClick", function()
        UI.OpenColorPicker(bind.get(), hasAlpha)
    end)

    f.Refresh = function()
        local c = bind.get()
        b.solid:SetVertexColor(c.r, c.g, c.b, 1)
        if hasAlpha then
            b.alpha:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        else
            b.alpha:SetVertexColor(c.r, c.g, c.b, 1)
        end
    end
    return f
end

-- Dims a widget and makes it ignore the mouse
local function attachEnable(w)
    w.SetEnabled = function(on)
        if w.enabledState == on then return end
        w.enabledState = on
        if on then w:SetAlpha(1) else w:SetAlpha(0.35) end
        if not w.blocker then
            local bl = CreateFrame("Frame", nil, w)
            bl:SetAllPoints(w)
            bl:SetFrameLevel(w:GetFrameLevel() + 20)
            bl:EnableMouse(true)
            w.blocker = bl
        end
        if on then w.blocker:Hide() else w.blocker:Show() end
    end
end

local function When(w, condition)
    w.cond = condition
    return w
end

-- Popups -------------------------------------------------------------------------------------

local ROW_H = 22
local DROP_ROWS = 12

local function renderDropList()
    local list = UI.dropList
    local options = list.options
    local n = table.getn(options)
    local visible = n
    if visible > DROP_ROWS then visible = DROP_ROWS end

    for i = 1, DROP_ROWS do
        local row = list.rows[i]
        local opt = options[list.offset + i]
        if i <= visible and opt then
            row.opt = opt
            row.text:SetText(opt.text)
            M.SetFont(row.text, M.fontUI, 11)
            if opt.value == list.current then
                row.text:SetTextColor(T.gold[1], T.gold[2], T.gold[3], 1)
            else
                row.text:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
            end
            row.prev:Hide()
            if list.decorate then list.decorate(row, opt) end
            row:Show()
        else
            row.opt = nil
            row:Hide()
        end
    end
end

local function ensureDropList()
    if UI.dropList then return UI.dropList end

    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetAllPoints(UIParent)
    catcher:EnableMouse(true)
    catcher:Hide()

    local list = panel(UIParent, T.panel, T.border)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(catcher:GetFrameLevel() + 50)
    list:EnableMouse(true)
    list:Hide()
    list.catcher = catcher
    list.rows = {}
    list.offset = 0
    list.options = {}

    for i = 1, DROP_ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -(1 + (i - 1) * ROW_H))
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, -(1 + (i - 1) * ROW_H))
        row.hl = newTexture(row, "BACKGROUND", T.hover)
        row.hl:SetAllPoints(row)
        row.hl:Hide()
        row.text = label(row, "", 11, T.text)
        row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.prev = row:CreateTexture(nil, "ARTWORK")
        row.prev:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.prev:SetWidth(72)
        row.prev:SetHeight(10)
        setColor(row.prev, T.accent)
        row:SetScript("OnEnter", function() row.hl:Show() end)
        row:SetScript("OnLeave", function() row.hl:Hide() end)
        row:SetScript("OnClick", function()
            local opt, pick = row.opt, list.onPick
            UI.CloseDropdown()
            if opt and pick then pick(opt.value) end
        end)
        list.rows[i] = row
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function()
        local maxOffset = table.getn(list.options) - DROP_ROWS
        if maxOffset <= 0 then return end
        list.offset = list.offset - arg1
        if list.offset < 0 then list.offset = 0 elseif list.offset > maxOffset then list.offset = maxOffset end
        renderDropList()
    end)
    catcher:SetScript("OnMouseDown", function() UI.CloseDropdown() end)

    UI.dropList = list
    return list
end

function UI.CloseDropdown()
    if UI.dropList then
        UI.dropList:Hide()
        UI.dropList.catcher:Hide()
    end
end

-- options is a list of { value, text }, onPick receives the value,
-- decorate(row, option) can restyle a row (row.text, row.prev)
function UI.OpenDropdown(anchor, options, current, onPick, decorate)
    local list = ensureDropList()
    list.options, list.current, list.onPick, list.decorate = options, current, onPick, decorate
    list.offset = 0

    local visible = table.getn(options)
    if visible > DROP_ROWS then visible = DROP_ROWS end
    list:SetWidth(anchor.fullWidth or anchor:GetWidth())
    list:SetHeight(visible * ROW_H + 2)
    list:ClearAllPoints()
    local bottom = anchor:GetBottom()
    if bottom and bottom - visible * ROW_H - 4 < 0 then
        list:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
        list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end

    renderDropList()
    list.catcher:Show()
    list:Show()
end

-- Color picker -------------------------------------------------------------------------------

local PALETTE = {
    { 1.00, 1.00, 1.00 }, { 0.70, 0.70, 0.72 }, { 0.30, 0.30, 0.34 }, { 0.00, 0.00, 0.00 },
    { 0.66, 0.47, 1.00 }, { 0.50, 0.30, 0.90 }, { 0.32, 0.18, 0.62 }, { 0.85, 0.50, 0.95 },
    { 1.00, 0.82, 0.32 }, { 0.96, 0.62, 0.15 }, { 0.90, 0.25, 0.25 }, { 0.95, 0.45, 0.65 },
    { 0.50, 0.85, 0.30 }, { 0.30, 0.85, 0.85 }, { 0.35, 0.65, 0.95 }, { 0.55, 0.30, 0.15 },
}

local function toHex(c, withAlpha)
    local hex = string.format("%02X%02X%02X", round(c.r * 255), round(c.g * 255), round(c.b * 255))
    if withAlpha then hex = hex .. string.format("%02X", round((c.a or 1) * 255)) end
    return hex
end

-- "RRGGBB" or "RRGGBBAA", with or without #
local function parseHex(text)
    text = string.gsub(text, "[#%s]", "")
    local len = string.len(text)
    if len ~= 6 and len ~= 8 then return nil end
    local r = tonumber(string.sub(text, 1, 2), 16)
    local g = tonumber(string.sub(text, 3, 4), 16)
    local b = tonumber(string.sub(text, 5, 6), 16)
    if r == nil or g == nil or b == nil then return nil end
    local a = nil
    if len == 8 then a = tonumber(string.sub(text, 7, 8), 16) end
    return r / 255, g / 255, b / 255, a and a / 255
end

-- All of them 0..1
local function rgb2hsv(r, g, b)
    local max = math.max(r, math.max(g, b))
    local min = math.min(r, math.min(g, b))
    local d = max - min
    local h = 0
    if d > 0 then
        if max == r then
            h = (g - b) / d
            if h < 0 then h = h + 6 end
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    local s = 0
    if max > 0 then s = d / max end
    return h, s, max
end

local function hsv2rgb(h, s, v)
    if s <= 0 then return v, v, v end
    h = h * 6
    if h >= 6 then h = 0 end
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if i == 0 then return v, t, p end
    if i == 1 then return q, v, p end
    if i == 2 then return p, v, t end
    if i == 3 then return p, q, v end
    if i == 4 then return t, p, v end
    return v, p, q
end

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- Where the cursor is on a frame, 0..1 from its bottom left corner
local function cursorFraction(frame)
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return 0, 0 end
    return clamp01((cx / scale - left) / frame:GetWidth()), clamp01((cy / scale - bottom) / frame:GetHeight())
end

-- Calls onMove(x, y) while the mouse button is held after a click on the frame
local function makeDraggable(frame, onMove)
    frame:EnableMouse(true)
    frame.dragging = false
    frame:SetScript("OnMouseDown", function()
        if arg1 ~= "LeftButton" then return end
        frame.dragging = true
        local fx, fy = cursorFraction(frame)
        onMove(fx, fy)
    end)
    frame:SetScript("OnMouseUp", function()
        frame.dragging = false
    end)
    frame:SetScript("OnUpdate", function()
        if not frame.dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            frame.dragging = false
            return
        end
        local fx, fy = cursorFraction(frame)
        onMove(fx, fy)
    end)
end

local CP_INNER = 234 -- width of the picker areas
local SV_H = 140
local STRIP_H = 14

-- A hue-like strip: texture, outline and a marker. Returns the strip frame.
local function buildStrip(cp, y)
    local strip = CreateFrame("Frame", nil, cp)
    strip:SetWidth(CP_INNER)
    strip:SetHeight(STRIP_H)
    strip:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, y)
    strip.back = newTexture(strip, "BACKGROUND", T.control)
    strip.back:SetAllPoints(strip)
    strip.tex = strip:CreateTexture(nil, "ARTWORK")
    strip.tex:SetAllPoints(strip)

    local outline = CreateFrame("Frame", nil, strip)
    outline:SetAllPoints(strip)
    outline:SetFrameLevel(strip:GetFrameLevel() + 2)
    edges(outline, T.border)

    strip.marker = panel(strip, { 1, 1, 1, 1 }, { 0, 0, 0, 1 })
    strip.marker:SetFrameLevel(strip:GetFrameLevel() + 3)
    strip.marker:SetWidth(6)
    strip.marker:SetHeight(STRIP_H + 6)
    return strip
end

local function buildColorPicker()
    local cp = panel(UIParent, T.panel, T.border)
    cp:SetWidth(262)
    cp:SetHeight(378)
    cp:SetFrameStrata("FULLSCREEN_DIALOG")
    cp:EnableMouse(true)
    cp:SetMovable(true)
    cp:SetClampedToScreen(true)
    cp:Hide()
    cp.color = { r = 1, g = 1, b = 1, a = 1 }
    cp.hasAlpha = false
    cp.h, cp.s, cp.v = 0, 0, 1

    local title = label(cp, "Color", 12, T.gold, true)
    title:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -12)

    local close = CreateFrame("Button", nil, cp)
    close:SetWidth(24)
    close:SetHeight(24)
    close:SetPoint("TOPRIGHT", cp, "TOPRIGHT", -6, -6)
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetTexture(M.close)
    close.icon:SetAllPoints(close)
    setColor(close.icon, T.dim)
    close:SetScript("OnEnter", function() setColor(close.icon, T.text) end)
    close:SetScript("OnLeave", function() setColor(close.icon, T.dim) end)
    close:SetScript("OnClick", function() cp:Hide() end)

    -- Saturation (left to right) and value (bottom to top) of the hue
    local sv = CreateFrame("Frame", nil, cp)
    cp.sv = sv
    sv:SetWidth(CP_INNER)
    sv:SetHeight(SV_H)
    sv:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -38)
    cp.svBase = newTexture(sv, "BACKGROUND", { 1, 0, 0, 1 })
    cp.svBase:SetAllPoints(sv)
    local white = sv:CreateTexture(nil, "BORDER")
    white:SetTexture(M.gradH)
    white:SetAllPoints(sv)
    local black = sv:CreateTexture(nil, "ARTWORK")
    black:SetTexture(M.gradV)
    black:SetVertexColor(0, 0, 0, 1)
    black:SetAllPoints(sv)
    local outline = CreateFrame("Frame", nil, sv)
    outline:SetAllPoints(sv)
    outline:SetFrameLevel(sv:GetFrameLevel() + 2)
    edges(outline, T.border)
    cp.svMarker = CreateFrame("Frame", nil, sv)
    cp.svMarker:SetFrameLevel(sv:GetFrameLevel() + 3)
    cp.svMarker:SetWidth(14)
    cp.svMarker:SetHeight(14)
    cp.svMarker.tex = cp.svMarker:CreateTexture(nil, "OVERLAY")
    cp.svMarker.tex:SetTexture(M.ring)
    cp.svMarker.tex:SetAllPoints(cp.svMarker)

    local function applyHsv()
        local r, g, b = hsv2rgb(cp.h, cp.s, cp.v)
        cp.color.r, cp.color.g, cp.color.b = r, g, b
        UI.Changed()
    end
    makeDraggable(sv, function(fx, fy)
        cp.s, cp.v = fx, fy
        applyHsv()
    end)

    cp.hueStrip = buildStrip(cp, -190)
    cp.hueStrip.tex:SetTexture(M.hue)
    makeDraggable(cp.hueStrip, function(fx)
        cp.h = fx
        applyHsv()
    end)

    -- Opacity: the color from transparent to solid over the dark background
    cp.alphaStrip = buildStrip(cp, -212)
    cp.alphaStrip.tex:SetTexture(M.gradH)
    cp.alphaStrip.tex:SetTexCoord(1, 0, 0, 1)
    makeDraggable(cp.alphaStrip, function(fx)
        cp.color.a = fx
        UI.Changed()
    end)

    cp.preview = panel(cp, T.control, T.border)
    cp.preview:SetWidth(54)
    cp.preview:SetHeight(26)
    cp.preview:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -240)
    cp.previewSolid = newTexture(cp.preview, "ARTWORK", T.text)
    cp.previewSolid:SetPoint("TOPLEFT", cp.preview, "TOPLEFT", 2, -2)
    cp.previewSolid:SetPoint("BOTTOMLEFT", cp.preview, "BOTTOMLEFT", 2, 2)
    cp.previewSolid:SetWidth(24)
    cp.previewAlpha = newTexture(cp.preview, "ARTWORK", T.text)
    cp.previewAlpha:SetPoint("TOPRIGHT", cp.preview, "TOPRIGHT", -2, -2)
    cp.previewAlpha:SetPoint("BOTTOMRIGHT", cp.preview, "BOTTOMRIGHT", -2, 2)
    cp.previewAlpha:SetWidth(24)

    cp.hex = InputBox(cp, 120, 24)
    cp.hex:SetPoint("TOPRIGHT", cp, "TOPRIGHT", -14, -239)
    cp.hex:SetMaxLetters(9)
    cp.hex:SetJustifyH("CENTER")
    cp.hex.OnCommit = function()
        local r, g, b, a = parseHex(cp.hex:GetText())
        if r ~= nil then
            cp.color.r, cp.color.g, cp.color.b = r, g, b
            if a ~= nil and cp.hasAlpha then cp.color.a = a end
            UI.Changed()
        end
        cp.Refresh()
    end
    cp.hex.OnCancel = function() cp.Refresh() end

    -- R G B A as numbers
    cp.boxes = {}
    local keys = { "r", "g", "b", "a" }
    for i = 1, 4 do
        local key = keys[i]
        local name = label(cp, string.upper(key), 10, T.dim, true, "CENTER")
        name:SetPoint("TOPLEFT", cp, "TOPLEFT", 14 + (i - 1) * 61, -274)
        name:SetWidth(52)
        local box = InputBox(cp, 52, 22)
        box:SetPoint("TOPLEFT", cp, "TOPLEFT", 14 + (i - 1) * 61, -288)
        box:SetJustifyH("CENTER")
        box:SetMaxLetters(3)
        box.OnCommit = function()
            local v = tonumber(box:GetText())
            if v ~= nil then
                cp.color[key] = clamp01(v / 255)
                UI.Changed()
            end
            cp.Refresh()
        end
        box.OnCancel = function() cp.Refresh() end
        cp.boxes[i] = box
    end
    attachEnable(cp.boxes[4])

    local presets = label(cp, "Presets", 10, T.dim, true)
    presets:SetPoint("TOPLEFT", cp, "TOPLEFT", 14, -322)
    for i = 1, table.getn(PALETTE) do
        local c = PALETTE[i]
        local sw = CreateFrame("Button", nil, cp)
        sw:SetWidth(22)
        sw:SetHeight(16)
        local col = math.mod(i - 1, 8)
        local row = math.floor((i - 1) / 8)
        sw:SetPoint("TOPLEFT", cp, "TOPLEFT", 14 + col * 30, -338 - row * 20)
        sw.bg = newTexture(sw, "ARTWORK", { c[1], c[2], c[3], 1 })
        sw.bg:SetAllPoints(sw)
        sw.edge = edges(sw, T.border)
        sw:SetScript("OnEnter", function() sw.edge.SetColor(T.accent) end)
        sw:SetScript("OnLeave", function() sw.edge.SetColor(T.border) end)
        sw:SetScript("OnClick", function()
            cp.color.r, cp.color.g, cp.color.b = c[1], c[2], c[3]
            UI.Changed()
        end)
    end

    -- Redraws everything from the color table
    cp.Refresh = function()
        local c = cp.color
        local h, s, v = rgb2hsv(c.r, c.g, c.b)
        -- A grey has no hue and black has no saturation: keep what the user had picked
        if s > 0 and v > 0 then cp.h = h end
        if v > 0 then cp.s = s end
        cp.v = v

        local hr, hg, hb = hsv2rgb(cp.h, 1, 1)
        cp.svBase:SetVertexColor(hr, hg, hb, 1)
        cp.svMarker:ClearAllPoints()
        cp.svMarker:SetPoint("CENTER", cp.sv, "TOPLEFT", cp.s * CP_INNER, -(1 - cp.v) * SV_H)

        cp.hueStrip.marker:ClearAllPoints()
        cp.hueStrip.marker:SetPoint("CENTER", cp.hueStrip, "LEFT", cp.h * CP_INNER, 0)

        local alpha = c.a or 1
        cp.alphaStrip.tex:SetVertexColor(c.r, c.g, c.b, 1)
        cp.alphaStrip.marker:ClearAllPoints()
        cp.alphaStrip.marker:SetPoint("CENTER", cp.alphaStrip, "LEFT", alpha * CP_INNER, 0)
        if cp.hasAlpha then cp.alphaStrip:Show() else cp.alphaStrip:Hide() end

        cp.previewSolid:SetVertexColor(c.r, c.g, c.b, 1)
        cp.previewAlpha:SetVertexColor(c.r, c.g, c.b, cp.hasAlpha and alpha or 1)
        if not cp.hex.focused then cp.hex:SetText(toHex(c, cp.hasAlpha)) end

        local keys = { "r", "g", "b", "a" }
        for i = 1, 4 do
            local box = cp.boxes[i]
            if not box.focused then box:SetText(tostring(round((c[keys[i]] or 1) * 255))) end
        end
        cp.boxes[4].SetEnabled(cp.hasAlpha)
    end

    cp:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then cp:StartMoving() end
    end)
    cp:SetScript("OnMouseUp", function() cp:StopMovingOrSizing() end)
    return cp
end

-- Edits the color table in place, so it needs no callback: UI.Changed() redraws everything
function UI.OpenColorPicker(color, hasAlpha)
    UI.CloseDropdown()
    if not UI.colorPicker then UI.colorPicker = buildColorPicker() end
    local cp = UI.colorPicker
    cp.color = color
    cp.hasAlpha = hasAlpha and true or false

    if not cp:IsShown() then
        cp:ClearAllPoints()
        local w = UI.frame
        if w:GetRight() and w:GetRight() + 272 < UIParent:GetWidth() then
            cp:SetPoint("TOPLEFT", w, "TOPRIGHT", 8, 0)
        else
            cp:SetPoint("TOPRIGHT", w, "TOPLEFT", -8, 0)
        end
    end
    cp:Show()
    cp.Refresh()
end

-- Icon picker --------------------------------------------------------------------------------

local ICON_COLS = 8
local ICON_SIZE = 32
local ICON_STEP = 36

local function collectIcons()
    local seen, list = {}, {}
    local function add(texture)
        if type(texture) == "string" and texture ~= "" and not seen[texture] then
            seen[texture] = true
            table.insert(list, texture)
        end
    end
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        add(GetSpellTexture(i, BOOKTYPE_SPELL))
        i = i + 1
    end
    for slot = 1, 19 do
        add(GetInventoryItemTexture("player", slot))
    end
    return list
end

-- Forward declaration, NewPage is defined below
local NewPage

local function buildIconPicker()
    local ip = panel(UIParent, T.panel, T.border)
    ip:SetWidth(360)
    ip:SetHeight(380)
    ip:SetFrameStrata("FULLSCREEN_DIALOG")
    ip:EnableMouse(true)
    ip:SetMovable(true)
    ip:SetClampedToScreen(true)
    ip:Hide()

    local title = label(ip, "Pick an icon from your spellbook and equipment", 12, T.gold, true)
    title:SetPoint("TOPLEFT", ip, "TOPLEFT", 14, -12)

    local close = CreateFrame("Button", nil, ip)
    close:SetWidth(24)
    close:SetHeight(24)
    close:SetPoint("TOPRIGHT", ip, "TOPRIGHT", -6, -6)
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetTexture(M.close)
    close.icon:SetAllPoints(close)
    setColor(close.icon, T.dim)
    close:SetScript("OnEnter", function() setColor(close.icon, T.text) end)
    close:SetScript("OnLeave", function() setColor(close.icon, T.dim) end)
    close:SetScript("OnClick", function() ip:Hide() end)

    ip.page = NewPage(ip, 14, 40, 332, 326)
    ip.buttons = {}

    ip:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then ip:StartMoving() end
    end)
    ip:SetScript("OnMouseUp", function() ip:StopMovingOrSizing() end)
    return ip
end

function UI.OpenIconPicker(onPick)
    UI.CloseDropdown()
    if not UI.iconPicker then UI.iconPicker = buildIconPicker() end
    local ip = UI.iconPicker
    local icons = collectIcons()
    local child = ip.page.child

    for i = 1, table.getn(icons) do
        local b = ip.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, child)
            b:SetWidth(ICON_SIZE)
            b:SetHeight(ICON_SIZE)
            b.bg = newTexture(b, "BACKGROUND", T.control)
            b.bg:SetAllPoints(b)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
            b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.edge = edges(b, T.border)
            b:SetScript("OnEnter", function() b.edge.SetColor(T.accent) end)
            b:SetScript("OnLeave", function() b.edge.SetColor(T.border) end)
            b:SetScript("OnClick", function()
                local pick = ip.onPick
                ip:Hide()
                if pick and b.path then pick(b.path) end
            end)
            ip.buttons[i] = b
        end
        local col = math.mod(i - 1, ICON_COLS)
        local row = math.floor((i - 1) / ICON_COLS)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", col * ICON_STEP, -row * ICON_STEP)
        b.path = icons[i]
        b.tex:SetTexture(icons[i])
        b:Show()
    end
    for i = table.getn(icons) + 1, table.getn(ip.buttons) do
        ip.buttons[i]:Hide()
    end

    local rows = math.ceil(table.getn(icons) / ICON_COLS)
    ip.page.Finish(rows * ICON_STEP)
    ip.onPick = onPick

    if not ip:IsShown() then
        ip:ClearAllPoints()
        local w = UI.frame
        if w:GetRight() and w:GetRight() + 370 < UIParent:GetWidth() then
            ip:SetPoint("TOPLEFT", w, "TOPRIGHT", 8, 0)
        else
            ip:SetPoint("TOPRIGHT", w, "TOPLEFT", -8, 0)
        end
    end
    ip:Show()
end

-- Pages --------------------------------------------------------------------------------------

-- A scrolled column of widgets. Row(a) fills the width, Row(a, b) makes two columns,
-- Row(a, false) leaves the right column empty.
NewPage = function(parent, x, y, width, height)
    local P = {}
    P.height = height
    P.width = width - SCROLL_W
    P.colW = math.floor((P.width - COL_GAP) / 2)
    P.y = 0
    P.pos = 0
    P.range = 0
    P.widgets = {}

    local sf = CreateFrame("ScrollFrame", nil, parent)
    P.frame = sf
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    sf:SetWidth(width)
    sf:SetHeight(height)

    local child = CreateFrame("Frame", nil, sf)
    P.child = child
    child:SetWidth(P.width)
    child:SetHeight(height)
    sf:SetScrollChild(child)

    -- Scroll bar
    local bar = CreateFrame("Frame", nil, parent)
    P.bar = bar
    bar:SetWidth(4)
    bar:SetHeight(height)
    bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -2, 0)
    bar:SetFrameLevel(sf:GetFrameLevel() + 2)
    bar.track = newTexture(bar, "BACKGROUND", T.control)
    bar.track:SetAllPoints(bar)
    local thumb = CreateFrame("Frame", nil, bar)
    bar.thumb = thumb
    thumb:SetWidth(4)
    thumb:SetHeight(30)
    thumb:EnableMouse(true)
    thumb.tex = newTexture(thumb, "ARTWORK", T.hover)
    thumb.tex:SetAllPoints(thumb)

    local function updateBar()
        if not P.shown or P.range <= 0 then
            bar:Hide()
            return
        end
        bar:Show()
        local contentH = P.range + height
        local thumbH = math.max(24, height * height / contentH)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", bar, "TOP", 0, -(P.pos / P.range) * (height - thumbH))
    end

    P.SetScroll = function(v)
        if v > P.range then v = P.range end
        if v < 0 then v = 0 end
        P.pos = v
        sf:SetVerticalScroll(v)
        updateBar()
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function()
        P.SetScroll(P.pos - arg1 * 40)
    end)

    thumb:SetScript("OnMouseDown", function()
        local _, cy = GetCursorPosition()
        P.dragY, P.dragPos = cy, P.pos
    end)
    thumb:SetScript("OnMouseUp", function()
        P.dragY = nil
    end)
    thumb:SetScript("OnUpdate", function()
        if not P.dragY then return end
        local _, cy = GetCursorPosition()
        local scale = thumb:GetEffectiveScale()
        local thumbH = thumb:GetHeight()
        local travel = height - thumbH
        if travel <= 0 then return end
        local dy = (P.dragY - cy) / scale
        P.SetScroll(P.dragPos + dy * P.range / travel)
    end)

    P.SetShown = function(on)
        P.shown = on
        if on then sf:Show() else sf:Hide() end
        updateBar()
    end

    local function place(w, px, pw)
        w:SetPoint("TOPLEFT", child, "TOPLEFT", px, -P.y)
        w:SetWidth(pw)
        if w.OnWidth then w.OnWidth(pw) end
        attachEnable(w)
        table.insert(P.widgets, w)
    end

    function P.Section(text)
        if P.y > 0 then P.y = P.y + 10 end
        local h = Header(child, text)
        h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -P.y)
        h:SetWidth(P.width)
        P.y = P.y + 26 + 8
    end

    function P.Row(a, b)
        local rowH = a:GetHeight()
        if b ~= nil and b ~= false then
            if b:GetHeight() > rowH then rowH = b:GetHeight() end
            place(a, 0, P.colW)
            place(b, P.colW + COL_GAP, P.colW)
        elseif b == false then
            place(a, 0, P.colW)
        else
            place(a, 0, P.width)
        end
        P.y = P.y + rowH + ROW_GAP
    end

    function P.Note(text, lines)
        P.Row(Note(child, text, lines))
    end

    -- Sets the height of the content once everything is in
    function P.Finish(contentH)
        contentH = contentH or P.y
        child:SetHeight(math.max(contentH, height))
        P.range = math.max(0, contentH - height)
        P.SetScroll(math.min(P.pos, P.range))
    end

    function P.Refresh()
        for i = 1, table.getn(P.widgets) do
            local w = P.widgets[i]
            if w.Refresh then w.Refresh() end
            if w.cond then w.SetEnabled(w.cond()) end
        end
    end

    P.shown = true
    return P
end

-- pairs is { value, text, value, text, ... }
local function optionList(pairs_)
    local list = {}
    for i = 1, table.getn(pairs_), 2 do
        table.insert(list, { value = pairs_[i], text = pairs_[i + 1] })
    end
    return list
end

local DIRECTIONS = optionList({ "LTR", "Left to right", "RTL", "Right to left", "CENTER_OUT", "Center to the sides", "EDGES_IN", "Sides to the center" })
local MODES = optionList({ "DRAIN", "Drain: starts full, empties", "FILL", "Fill: starts empty, fills up" })
local ICON_SOURCES = optionList({ "WEAPON", "Equipped weapon", "CUSTOM", "Custom icon" })
local ICON_SIDES = optionList({ "LEFT", "Left of the bar", "RIGHT", "Right of the bar", "INSIDE_LEFT", "Inside, left", "INSIDE_RIGHT", "Inside, right" })
local TIMER_ANCHORS = optionList({ "LEFT", "Left", "CENTER", "Center", "RIGHT", "Right", "ABOVE", "Above the bar", "BELOW", "Below the bar" })
local OUTLINES = optionList({ "NONE", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick outline" })
local TIMER_FORMATS = optionList({ "REMAINING", "1.5", "REMAINING_S", "1.5s", "REMAINING_TOTAL", "1.5 / 2.6" })

local function fixedOptions(list)
    return function() return list end
end

local function decorateTexture(row, opt)
    row.prev:SetTexture(M.TexturePath(opt.value, ""))
    row.prev:Show()
end

local function decorateFont(row, opt)
    M.SetFont(row.text, M.FontPath(opt.value, ""), 11)
end

-- Position of the group or of a bar, in screen units of the UI (the saved ones follow the scale)
local function groupPos(which)
    return {
        get = function()
            local G = BReST.Frame.Group
            if not G then return 0 end
            local v
            if which == "x" then v = G:GetLeft() else v = G:GetTop() end
            return round((v or 0) * prof().scale)
        end,
        set = function(v)
            local p, G = prof(), BReST.Frame.Group
            if p.groupX == nil then p.groupX, p.groupY = G:GetLeft(), G:GetTop() end
            if which == "x" then p.groupX = v / p.scale else p.groupY = v / p.scale end
            BReST.Frame.restorePosition()
        end,
    }
end

local function barPos(hand, which)
    local function frame() return BReST.Frame.byHand and BReST.Frame.byHand[hand] end
    return {
        get = function()
            local bar = frame()
            if not bar then return 0 end
            local v
            if which == "x" then v = bar:GetLeft() else v = bar:GetTop() end
            return round((v or 0) * prof().scale)
        end,
        set = function(v)
            local p = prof()
            local cfg, bar = p.bars[hand], frame()
            if cfg.x == nil then cfg.x, cfg.y = bar:GetLeft(), bar:GetTop() end
            if which == "x" then cfg.x = v / p.scale else cfg.y = v / p.scale end
        end,
    }
end

local scaleBind = {
    get = function() return prof().scale end,
    set = function(v)
        local p = prof()
        local old = p.scale
        p.scale = v
        BReST.Frame.rescale(old, v)
    end,
}

local function isGrouped() return prof().grouped end
local function isFree() return not prof().grouped end

local function buildGeneral(content)
    local P = NewPage(content, PAGE_X, 14, PAGE_W, CONTENT_H - 28)
    local screenW, screenH = math.floor(UIParent:GetWidth()), math.floor(UIParent:GetHeight())

    P.Section("Layout")
    P.Row(Checkbox(P.child, "Group the bars in one frame", Bind(prof, "grouped")))
    P.Row(Slider(P.child, "Scale", 0.5, 2, 0.05, scaleBind), Slider(P.child, "Opacity", 0.1, 1, 0.05, Bind(prof, "alpha")))
    P.Note("The bars on screen are a simulation while this window is open. Use Unlock bars below to drag them.", 2)

    P.Section("Group frame")
    P.Row(When(Slider(P.child, "Padding", 0, 30, 1, Bind(prof, "group.padding")), isGrouped),
        When(Slider(P.child, "Space between the bars", 0, 30, 1, Bind(prof, "group.spacing")), isGrouped))
    P.Row(When(ColorField(P.child, "Background", Bind(prof, "group.bgColor"), true), isGrouped),
        When(ColorField(P.child, "Border color", Bind(prof, "group.borderColor"), true), isGrouped))
    P.Row(When(Slider(P.child, "Border size", 0, 4, 1, Bind(prof, "group.borderSize")), isGrouped),
        When(Checkbox(P.child, "Free the room of hidden bars", Bind(prof, "group.collapse")), isGrouped))

    P.Section("Position")
    P.Row(When(Slider(P.child, "Horizontal position", 0, screenW, 1, groupPos("x")), isGrouped),
        When(Slider(P.child, "Vertical position (top edge)", 0, screenH, 1, groupPos("y")), isGrouped))
    P.Row(Button(P.child, "Center the bars", 100, 26, function()
        BReST.Frame.resetPosition()
        UI.Changed()
    end), false)

    P.Section("Visibility")
    P.Note("When a bar hides, and how it fades, is set on the Visibility tab of each bar.", 1)

    P.Section("Performance")
    P.Row(Slider(P.child, "Update interval (s)", 0.01, 0.2, 0.01, Bind(prof, "updateTime")), false)
    P.Note("Lower is smoother. The bars are redrawn at most once per interval.", 1)

    P.Finish()
    return P
end

local function copyBar(from, to)
    local p = prof()
    local keep = p.bars[to]
    local c = BReST.copy(p.bars[from])
    c.enabled, c.x, c.y = keep.enabled, keep.x, keep.y
    p.bars[to] = c
    UI.Changed()
end

local function buildBarTab(content, hand)
    local bar = barOf(hand)
    local function B(path) return Bind(bar, path) end
    local P = NewPage(content, PAGE_X, TAB_H + 10, PAGE_W, CONTENT_H - TAB_H - 20)

    P.Row(Checkbox(P.child, "Show this bar", B("enabled")))

    P.Section("Size")
    P.Row(Slider(P.child, "Width", 20, 600, 1, B("width")), Slider(P.child, "Height", 4, 80, 1, B("height")))

    P.Section("Look")
    P.Row(Dropdown(P.child, "Texture", M.TextureOptions, B("texture"), decorateTexture),
        When(TextField(P.child, "Custom texture path", B("customTexture")), function() return bar().texture == "Custom" end))
    P.Row(ColorField(P.child, "Bar color", B("color"), true), ColorField(P.child, "Background", B("bgColor"), true))
    P.Row(Slider(P.child, "Border size", 0, 4, 1, B("borderSize")), ColorField(P.child, "Border color", B("borderColor"), true))

    P.Section("Animation")
    P.Row(Dropdown(P.child, "Direction", fixedOptions(DIRECTIONS), B("direction")),
        Dropdown(P.child, "Style", fixedOptions(MODES), B("mode")))
    P.Row(When(Checkbox(P.child, "Stay full when the swing is ready", B("holdFull")), function() return bar().mode == "FILL" end), false)
    local function sparkOn() return bar().spark end
    P.Row(Checkbox(P.child, "Spark on the edge of the fill", B("spark")),
        When(ColorField(P.child, "Spark color", B("sparkColor"), true), sparkOn))
    P.Row(When(Slider(P.child, "Spark width", 2, 100, 1, B("sparkWidth")), sparkOn),
        When(Slider(P.child, "Spark height", 4, 200, 1, B("sparkHeight")), sparkOn))
    if hand == "MAIN" then
        P.Row(Checkbox(P.child, "Tint while a swing spell is queued", B("queuedTint")), ColorField(P.child, "Queued color", B("queuedColor"), true))
        P.Note("Heroic Strike, Cleave, Maul and Raptor Strike are queued until your next swing.", 1)
    end

    P.Section("Position")
    P.Row(When(Slider(P.child, "Horizontal position", 0, math.floor(UIParent:GetWidth()), 1, barPos(hand, "x")), isFree),
        When(Slider(P.child, "Vertical position (top edge)", 0, math.floor(UIParent:GetHeight()), 1, barPos(hand, "y")), isFree))
    P.Note("Only used when the bars are not grouped, see the General page.", 1)

    P.Section("Copy this look")
    local others = {}
    for i = 1, table.getn(HANDS) do
        if HANDS[i] ~= hand then table.insert(others, HANDS[i]) end
    end
    local function copyButton(to)
        return Button(P.child, "Copy to " .. BReST.HAND_NAMES[to], 100, 26, function() copyBar(hand, to) end)
    end
    P.Row(copyButton(others[1]), copyButton(others[2]))

    P.Finish()
    return P
end

local function buildIconTab(content, hand)
    local bar = barOf(hand)
    local function B(path) return Bind(bar, path) end
    local P = NewPage(content, PAGE_X, TAB_H + 10, PAGE_W, CONTENT_H - TAB_H - 20)
    local function custom() return bar().icon.source == "CUSTOM" end

    P.Row(Checkbox(P.child, "Show the icon", B("icon.show")))

    P.Section("Icon")
    P.Row(Dropdown(P.child, "Icon", fixedOptions(ICON_SOURCES), B("icon.source")),
        When(TextField(P.child, "Custom icon path", B("icon.custom")), custom))
    P.Row(When(Button(P.child, "Pick from the spellbook...", 100, 26, function()
        UI.OpenIconPicker(function(path)
            local ic = bar().icon
            ic.custom, ic.source = path, "CUSTOM"
            UI.Changed()
        end)
    end), custom), false)
    if hand == "MAIN" then
        P.Row(Checkbox(P.child, "Show the queued swing spell instead", B("icon.showQueued")))
        P.Note("While Heroic Strike, Cleave, Maul or Raptor Strike is queued, its icon replaces this one.", 1)
    end

    P.Section("Position and size")
    P.Row(Dropdown(P.child, "Position", fixedOptions(ICON_SIDES), B("icon.side")),
        Checkbox(P.child, "Same size as the bar height", B("icon.matchHeight")))
    P.Row(When(Slider(P.child, "Size", 8, 80, 1, B("icon.size")), function() return not bar().icon.matchHeight end), false)
    P.Row(Slider(P.child, "Horizontal offset", -60, 60, 1, B("icon.offsetX")), Slider(P.child, "Vertical offset", -60, 60, 1, B("icon.offsetY")))
    P.Row(Checkbox(P.child, "Trim the edges of the icon", B("icon.zoom")), false)

    P.Finish()
    return P
end

local function buildTimerTab(content, hand)
    local bar = barOf(hand)
    local function B(path) return Bind(bar, path) end
    local P = NewPage(content, PAGE_X, TAB_H + 10, PAGE_W, CONTENT_H - TAB_H - 20)

    P.Row(Checkbox(P.child, "Show the timer", B("timer.show")))

    P.Section("Font")
    P.Row(Dropdown(P.child, "Font", M.FontOptions, B("timer.font"), decorateFont),
        When(TextField(P.child, "Custom font path", B("timer.customFont")), function() return bar().timer.font == "Custom" end))
    P.Row(Slider(P.child, "Size", 6, 40, 1, B("timer.size")), Dropdown(P.child, "Outline", fixedOptions(OUTLINES), B("timer.outline")))
    P.Row(ColorField(P.child, "Color", B("timer.color"), true), Checkbox(P.child, "Shadow", B("timer.shadow")))

    P.Section("Position")
    P.Row(Dropdown(P.child, "Place the timer", fixedOptions(TIMER_ANCHORS), B("timer.anchor")), false)
    P.Row(Slider(P.child, "Horizontal offset", -100, 100, 1, B("timer.offsetX")), Slider(P.child, "Vertical offset", -40, 40, 1, B("timer.offsetY")))

    P.Section("Text")
    P.Row(Dropdown(P.child, "Format", fixedOptions(TIMER_FORMATS), B("timer.format")), Slider(P.child, "Decimals", 0, 2, 1, B("timer.decimals")))

    P.Finish()
    return P
end

local FADE_STYLES = optionList({ "LINEAR", "Linear", "SMOOTH", "Smooth", "EASE_OUT", "Fast, then slow", "INSTANT", "No fade" })

local function buildVisibilityTab(content, hand)
    local bar = barOf(hand)
    local function B(path) return Bind(bar, path) end
    local P = NewPage(content, PAGE_X, TAB_H + 10, PAGE_W, CONTENT_H - TAB_H - 20)
    local function hides()
        local v = bar().vis
        return v.hideOutOfCombat or v.hideWhenIdle
    end

    P.Section("Hide the bar")
    P.Row(Checkbox(P.child, "Hide out of combat", B("vis.hideOutOfCombat")),
        Checkbox(P.child, "Hide when no swing is running", B("vis.hideWhenIdle")))
    P.Note("With both on, the bar only shows while you are swinging in combat.", 1)

    P.Section("Fading")
    P.Row(When(Slider(P.child, "Stay visible for (s)", 0, 30, 0.5, B("vis.hideDelay")), hides),
        When(Dropdown(P.child, "Fade curve", fixedOptions(FADE_STYLES), B("vis.fadeStyle")), hides))
    P.Row(When(Slider(P.child, "Fade out time (s)", 0, 5, 0.05, B("vis.fadeOut")),
            function() return hides() and bar().vis.fadeStyle ~= "INSTANT" end),
        When(Slider(P.child, "Fade in time (s)", 0, 3, 0.05, B("vis.fadeIn")), hides))
    P.Note("Stay visible for: how long the bar waits after it should hide before it starts to fade.", 2)

    P.Section("Preview")
    P.Note("While this window is open every bar is shown. Turn on Test hiding below, then use the test buttons to see how the bar hides.", 2)
    P.Row(Button(P.child, "Apply to all bars", 100, 26, function()
        local p = prof()
        for i = 1, table.getn(HANDS) do
            if HANDS[i] ~= hand then p.bars[HANDS[i]].vis = BReST.copy(p.bars[hand].vis) end
        end
        UI.Changed()
    end), false)

    P.Finish()
    return P
end

-- A bar has four tabs: the bar itself, its icon, its timer and when it shows
local function buildBarPage(content, hand)
    local page = { tabs = {}, buttons = {}, active = "bar" }

    local strip = CreateFrame("Frame", nil, content)
    strip:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    strip:SetWidth(CONTENT_W)
    strip:SetHeight(TAB_H + 4)
    strip:SetFrameLevel(content:GetFrameLevel() + LEVEL_TOP)
    strip.bg = newTexture(strip, "BACKGROUND", T.panel)
    strip.bg:SetAllPoints(strip)
    strip.line = newTexture(strip, "BORDER", T.border)
    strip.line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    strip.line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    strip.line:SetHeight(1)
    page.strip = strip

    local ids = { "bar", "icon", "timer", "vis" }
    local names = { bar = "Bar", icon = "Icon", timer = "Timer", vis = "Visibility" }
    page.tabs.bar = buildBarTab(content, hand)
    page.tabs.icon = buildIconTab(content, hand)
    page.tabs.timer = buildTimerTab(content, hand)
    page.tabs.vis = buildVisibilityTab(content, hand)

    local function show(id)
        page.active = id
        for i = 1, table.getn(ids) do
            local on = (ids[i] == id)
            page.tabs[ids[i]].SetShown(on and page.visible)
            page.buttons[ids[i]].SetActive(on)
        end
        if page.visible then page.tabs[id].Refresh() end
    end

    for i = 1, table.getn(ids) do
        local id = ids[i]
        local b = Button(strip, names[id], 90, 26, function() show(id) end)
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", PAGE_X + (i - 1) * 96, -6)
        page.buttons[id] = b
    end

    page.SetShown = function(on)
        page.visible = on
        if on then strip:Show() else strip:Hide() end
        show(page.active)
    end
    page.Refresh = function()
        page.tabs[page.active].Refresh()
    end
    return page
end

local function profileOptions()
    local options = {}
    local names = BReST.ProfileNames()
    for i = 1, table.getn(names) do
        table.insert(options, { value = names[i], text = names[i] })
    end
    return options
end

-- A button that must be clicked twice within a few seconds
local function ConfirmButton(parent, text, confirmText, onConfirm)
    local b
    b = Button(parent, text, 100, 26, function()
        if b.armedAt and GetTime() - b.armedAt < 4 then
            b.armedAt = nil
            b.SetLabel(text)
            onConfirm()
        else
            b.armedAt = GetTime()
            b.SetLabel(confirmText)
        end
    end)
    b:SetScript("OnUpdate", function()
        if b.armedAt and GetTime() - b.armedAt >= 4 then
            b.armedAt = nil
            b.SetLabel(text)
        end
    end)
    return b
end

local function buildProfiles(content)
    local P = NewPage(content, PAGE_X, 14, PAGE_W, CONTENT_H - 28)
    local newName = ""

    P.Section("Profile")
    P.Row(Dropdown(P.child, "Active profile", profileOptions, {
        get = function() return BReST_Config.profile end,
        set = function(v) BReST.SetProfile(v) end,
    }), false)
    P.Note("Profiles are saved per character. Every setting of this window belongs to the active profile.", 2)

    P.Section("Create")
    P.Row(TextField(P.child, "Name of the new profile", {
        get = function() return newName end,
        set = function(v) newName = v end,
    }, 40))
    P.Row(Button(P.child, "Create a copy of the current profile", 100, 26, function()
        local ok, err = BReST.CreateProfile(newName)
        if ok then
            BReST.Print("profile " .. newName .. " created")
            newName = ""
            UI.Changed()
        else
            BReST.Print("can't create the profile: " .. err)
        end
    end), false)

    P.Section("Current profile")
    P.Row(ConfirmButton(P.child, "Reset to defaults", "Click again to reset", function()
        BReST.ResetProfile()
        BReST.Print("profile reset")
    end), ConfirmButton(P.child, "Delete this profile", "Click again to delete", function()
        local ok, err = BReST.DeleteProfile(BReST_Config.profile)
        if not ok then BReST.Print("can't delete the profile: " .. err) end
    end))

    P.Finish()
    return P
end

-- The window ---------------------------------------------------------------------------------

local NAV = {
    { id = "general", text = "General" },
    { id = "MAIN", text = "Main Hand" },
    { id = "OFF", text = "Off Hand" },
    { id = "RANGED", text = "Ranged" },
    { id = "profiles", text = "Profiles" },
}

UI.pages = {}
UI.nav = {}
UI.current = "general"

local function pageShown(id, on)
    local page = UI.pages[id]
    if page.SetShown then page.SetShown(on) end
end

function UI.Select(id)
    UI.CloseDropdown()
    for i = 1, table.getn(NAV) do
        local nid = NAV[i].id
        pageShown(nid, nid == id)
        UI.nav[nid].SetActive(nid == id)
    end
    UI.current = id
    UI.pages[id].Refresh()
end

-- A value changed: redraw the bars and the widgets that depend on it
function UI.Changed()
    BReST.Frame.layout()
    UI.RefreshPage()
    if UI.colorPicker and UI.colorPicker:IsShown() then UI.colorPicker.Refresh() end
end

function UI.RefreshPage()
    if not UI.built then return end
    UI.pages[UI.current].Refresh()
end

function UI.RefreshFooter()
    if not UI.built then return end
    local f = BReST.Frame
    UI.unlockButton.SetActive(BReST.configMode)
    UI.unlockButton.SetLabel(BReST.configMode and "Lock bars" or "Unlock bars")
    UI.simButton.SetActive(f.sim.active)
    UI.hideButton.SetActive(f.testHide)
    UI.queuedButton.SetActive(f.sim.queued)
end

-- Everything, after the profile changed
function UI.Refresh()
    UI.RefreshPage()
    UI.RefreshFooter()
end

local function buildFooter(W)
    local footer = CreateFrame("Frame", nil, W)
    footer:SetPoint("BOTTOMLEFT", W, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(FOOT_H)
    footer:SetFrameLevel(W:GetFrameLevel() + LEVEL_TOP)
    footer.bg = newTexture(footer, "BACKGROUND", T.side)
    footer.bg:SetAllPoints(footer)
    footer.line = newTexture(footer, "BORDER", T.border)
    footer.line:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footer.line:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footer.line:SetHeight(1)

    local f = BReST.Frame
    local y = -13
    UI.unlockButton = Button(footer, "Unlock bars", 104, 28, function() f.setConfigMode(not BReST.configMode) end)
    UI.unlockButton:SetPoint("TOPLEFT", footer, "TOPLEFT", 16, y)

    UI.simButton = Button(footer, "Simulation", 92, 28, function() f.setSimulating(not f.sim.active) end)
    UI.simButton:SetPoint("TOPLEFT", footer, "TOPLEFT", 126, y)

    -- With it on, the bars hide and fade like they do in the game instead of all showing
    UI.hideButton = Button(footer, "Test hiding", 100, 28, function() f.setTestHide(not f.testHide) end)
    UI.hideButton:SetPoint("TOPLEFT", footer, "TOPLEFT", 224, y)

    local x = 340
    local swings = { { "MAIN", "Main hand", 70 }, { "OFF", "Off hand", 64 }, { "RANGED", "Ranged", 58 } }
    for i = 1, table.getn(swings) do
        local s = swings[i]
        local b = Button(footer, s[2], s[3], 28, function() f.simSwing(s[1]) end)
        b:SetPoint("TOPLEFT", footer, "TOPLEFT", x, y)
        x = x + s[3] + 6
    end

    UI.queuedButton = Button(footer, "Queued spell", 90, 28, function() f.setSimQueued(not f.sim.queued) end)
    UI.queuedButton:SetPoint("TOPLEFT", footer, "TOPLEFT", x + 4, y)
end

local function buildTitle(W)
    local title = CreateFrame("Frame", nil, W)
    title:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    title:SetHeight(TITLE_H)
    title:SetFrameLevel(W:GetFrameLevel() + LEVEL_TOP)
    title:EnableMouse(true)
    title.bg = newTexture(title, "BACKGROUND", T.side)
    title.bg:SetAllPoints(title)
    title.line = newTexture(title, "BORDER", T.border)
    title.line:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0)
    title.line:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 0)
    title.line:SetHeight(1)

    title.text = label(title, "|cffa879ffBrz|r|cffffffffenhanced|r|cfff5c542SwingTimer|r", 13, T.text, true)
    title.text:SetPoint("LEFT", title, "LEFT", 16, 0)
    title.version = label(title, "v" .. BReST.version, 10, T.dim)
    title.version:SetPoint("LEFT", title.text, "RIGHT", 8, -1)

    local close = CreateFrame("Button", nil, title)
    close:SetWidth(34)
    close:SetHeight(TITLE_H)
    close:SetPoint("TOPRIGHT", title, "TOPRIGHT", 0, 0)
    close.bg = newTexture(close, "BACKGROUND", T.danger)
    close.bg:SetAllPoints(close)
    close.bg:Hide()
    close.icon = close:CreateTexture(nil, "ARTWORK")
    close.icon:SetTexture(M.close)
    close.icon:SetWidth(18)
    close.icon:SetHeight(18)
    close.icon:SetPoint("CENTER", close, "CENTER", 0, 0)
    setColor(close.icon, T.dim)
    close:SetScript("OnEnter", function()
        close.bg:Show()
        setColor(close.icon, { 1, 1, 1, 1 })
    end)
    close:SetScript("OnLeave", function()
        close.bg:Hide()
        setColor(close.icon, T.dim)
    end)
    close:SetScript("OnClick", function() W:Hide() end)

    title:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then W:StartMoving() end
    end)
    title:SetScript("OnMouseUp", function() W:StopMovingOrSizing() end)
end

local function buildSidebar(W)
    local side = CreateFrame("Frame", nil, W)
    side:SetPoint("TOPLEFT", W, "TOPLEFT", 0, -TITLE_H)
    side:SetWidth(SIDE_W)
    side:SetHeight(WIN_H - TITLE_H - FOOT_H)
    side:SetFrameLevel(W:GetFrameLevel() + LEVEL_TOP)
    side.bg = newTexture(side, "BACKGROUND", T.side)
    side.bg:SetAllPoints(side)
    side.line = newTexture(side, "BORDER", T.border)
    side.line:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
    side.line:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
    side.line:SetWidth(1)

    for i = 1, table.getn(NAV) do
        local n = NAV[i]
        local b = CreateFrame("Button", nil, side)
        b:SetWidth(SIDE_W - 1)
        b:SetHeight(36)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -10 - (i - 1) * 38)
        b.bg = newTexture(b, "BACKGROUND", T.hover)
        b.bg:SetAllPoints(b)
        b.bg:Hide()
        b.mark = newTexture(b, "ARTWORK", T.gold)
        b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.mark:SetWidth(3)
        b.mark:Hide()
        b.text = label(b, n.text, 12, T.dim, true)
        b.text:SetPoint("LEFT", b, "LEFT", 20, 0)
        b.active, b.hovered = false, false

        b.Style = function()
            if b.active then
                b.bg:Show()
                setColor(b.bg, T.panel)
                b.mark:Show()
                b.text:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
            else
                b.mark:Hide()
                if b.hovered then
                    b.bg:Show()
                    setColor(b.bg, T.control)
                    b.text:SetTextColor(T.text[1], T.text[2], T.text[3], 1)
                else
                    b.bg:Hide()
                    b.text:SetTextColor(T.dim[1], T.dim[2], T.dim[3], 1)
                end
            end
        end
        b.SetActive = function(on)
            b.active = on and true or false
            b.Style()
        end
        b:SetScript("OnEnter", function()
            b.hovered = true
            b.Style()
        end)
        b:SetScript("OnLeave", function()
            b.hovered = false
            b.Style()
        end)
        b:SetScript("OnClick", function() UI.Select(n.id) end)
        UI.nav[n.id] = b
    end
end

function UI.Build()
    if UI.built then return end

    local W = CreateFrame("Frame", "BReST_ConfigFrame", UIParent)
    UI.frame = W
    W:SetWidth(WIN_W)
    W:SetHeight(WIN_H)
    W:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    W:SetFrameStrata("DIALOG")
    W:SetMovable(true)
    W:SetClampedToScreen(true)
    W:EnableMouse(true)
    W.bg = newTexture(W, "BACKGROUND", T.bg)
    W.bg:SetAllPoints(W)
    W.edge = edges(W, T.border)
    W:Hide()
    table.insert(UISpecialFrames, "BReST_ConfigFrame")

    buildTitle(W)
    buildSidebar(W)
    buildFooter(W)

    local content = CreateFrame("Frame", nil, W)
    content:SetPoint("TOPLEFT", W, "TOPLEFT", SIDE_W, -TITLE_H)
    content:SetWidth(CONTENT_W)
    content:SetHeight(CONTENT_H)
    content.bg = newTexture(content, "BACKGROUND", T.panel)
    content.bg:SetAllPoints(content)

    UI.pages.general = buildGeneral(content)
    for i = 1, table.getn(HANDS) do
        UI.pages[HANDS[i]] = buildBarPage(content, HANDS[i])
    end
    UI.pages.profiles = buildProfiles(content)

    UI.built = true

    W:SetScript("OnShow", function()
        local f = BReST.Frame
        f.setPreview(true)
        f.setSimulating(true)
        UI.Select(UI.current)
        UI.RefreshFooter()
    end)
    W:SetScript("OnHide", function()
        local f = BReST.Frame
        UI.CloseDropdown()
        if UI.colorPicker then UI.colorPicker:Hide() end
        if UI.iconPicker then UI.iconPicker:Hide() end
        f.setSimulating(false)
        f.setConfigMode(false)
        f.setTestHide(false)
        f.setPreview(false)
    end)
end

function UI.Open()
    if not BReST.ready or not BReST.Frame.Group then
        BReST.Print("the addon is not loaded yet, try again in a moment")
        return
    end
    UI.Build()
    UI.frame:Show()
end

function UI.Toggle()
    if UI.built and UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.Open()
    end
end
