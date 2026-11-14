-- Lightweight custom UI widgets (replaces AceGUI). Pure WoW API, no libraries.
BistooltipAddon = BistooltipAddon or {}
local W = {}
BistooltipAddon.Widgets = W

local FONT = "Fonts\\FRIZQT__.TTF"

-- Modern dark palette (r, g, b, a)
local C = {
    window      = { 0.106, 0.110, 0.125, 0.98 },
    header      = { 0.078, 0.082, 0.098, 1 },
    panel       = { 0.129, 0.133, 0.157, 1 },
    panelHover  = { 0.169, 0.173, 0.200, 1 },
    border      = { 0.204, 0.208, 0.231, 1 },
    rowAlt      = { 0.125, 0.129, 0.153, 0.6 },
    textPrimary = { 0.909, 0.902, 0.890 },
    textSecond  = { 0.603, 0.603, 0.627 },
    textMuted   = { 0.420, 0.423, 0.439 },
    accent      = { 0.780, 0.612, 0.431 }, -- fallback (overridden by class color)
    green       = { 0.180, 0.800, 0.439 },
    boe         = { 0.878, 0.627, 0.188 },
}
W.Colors = C
BistooltipAddon.Colors = C

function W.font(fs, size, flags)
    fs:SetFont(FONT, size or 13, flags)
    return fs
end

local function text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 13)
    color = color or C.textPrimary
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    if justify then fs:SetJustifyH(justify) end
    return fs
end
W.text = text

-- Solid background on a frame.
function W.bg(frame, color)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    frame.bgTex = t
    return t
end

-- 1px flat border drawn with four edge textures.
function W.border(frame, color, size)
    color = color or C.border
    size = size or 1
    local function edge()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        return t
    end
    local top, bottom, left, right = edge(), edge(), edge(), edge()
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(size)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(size)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(size)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(size)
    frame.borderTex = { top, bottom, left, right }
    return frame
end

function W.panel(parent, color)
    local f = CreateFrame("Frame", nil, parent)
    W.bg(f, color or C.panel)
    return f
end

-- A text/icon button with hover.
function W.button(parent, label, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 90, height or 28)
    W.bg(b, C.panel)
    W.border(b, C.border)
    b.label = text(b, 13, C.textPrimary)
    b.label:SetPoint("CENTER")
    if label then b.label:SetText(label) end
    b:SetScript("OnEnter", function(self) self.bgTex:SetColorTexture(C.panelHover[1], C.panelHover[2], C.panelHover[3], 1) end)
    b:SetScript("OnLeave", function(self) self.bgTex:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], 1) end)
    return b
end

-- A borderless, transparent icon button with a subtle hover fill (header controls).
function W.iconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 24, size or 24)
    local hover = b:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints(b)
    hover:SetColorTexture(C.panelHover[1], C.panelHover[2], C.panelHover[3], 1)
    hover:Hide()
    b.hover = hover
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    return b
end

-- ----------------------------------------------------------------------- --
-- Dropdown
-- ----------------------------------------------------------------------- --

local openList = nil

local function ensureList()
    if W._list then return W._list end
    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:Hide()
    closer:SetScript("OnClick", function() W.closeDropdown() end)
    W._closer = closer

    local list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(closer:GetFrameLevel() + 10)
    W.bg(list, C.header)
    W.border(list, C.border)
    list:Hide()
    list.buttons = {}
    W._list = list
    return list
end

function W.closeDropdown()
    if W._list then W._list:Hide() end
    if W._closer then W._closer:Hide() end
    openList = nil
end

local function listButton(list, i)
    local b = list.buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, list)
    b:SetHeight(26)
    -- Highlight sits in BACKGROUND (below the OVERLAY label) so text stays readable.
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetPoint("TOPLEFT", 1, 0)
    b.hl:SetPoint("BOTTOMRIGHT", -1, 0)
    b.hl:SetColorTexture(C.panelHover[1], C.panelHover[2], C.panelHover[3], 1)
    b.hl:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 8, 0)
    b.label = text(b, 13, C.textPrimary)
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
    b.label:SetPoint("RIGHT", -8, 0)
    b.label:SetJustifyH("LEFT")
    b:SetScript("OnEnter", function(self) self.hl:Show() end)
    b:SetScript("OnLeave", function(self) if not self.selected then self.hl:Hide() end end)
    list.buttons[i] = b
    return b
end

local function openDropdownList(dd)
    local list = ensureList()
    local opts = dd.options or {}
    local width = math.max(dd:GetWidth(), 120)
    for _, b in ipairs(list.buttons) do b:Hide() end
    local y = -4
    for i, opt in ipairs(opts) do
        local b = listButton(list, i)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, y)
        b:SetWidth(width)
        if opt.icon then b.icon:SetTexture(opt.icon); b.icon:Show() else b.icon:Hide() end
        b.label:SetText(opt.text or "")
        local col = opt.color or C.textPrimary
        b.label:SetTextColor(col[1], col[2], col[3], 1)
        b.selected = (opt.value == dd.value)
        if b.selected then b.hl:Show() else b.hl:Hide() end
        b:SetScript("OnClick", function()
            dd:SetValue(opt.value)
            W.closeDropdown()
            if dd.onChange then dd.onChange(opt.value) end
        end)
        b:Show()
        y = y - 26
    end
    list:SetWidth(width)
    list:SetHeight(math.max((-y) + 4, 30))
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -3)
    W._closer:Show()
    list:Show()
    openList = dd
end

function W.dropdown(parent, width, height)
    local dd = CreateFrame("Button", nil, parent)
    dd:SetSize(width or 150, height or 30)
    W.bg(dd, C.panel)
    W.border(dd, C.border)
    dd.icon = dd:CreateTexture(nil, "ARTWORK")
    dd.icon:SetSize(16, 16)
    dd.icon:SetPoint("LEFT", 9, 0)
    dd.label = text(dd, 13, C.textPrimary)
    dd.label:SetPoint("LEFT", dd.icon, "RIGHT", 7, 0)
    dd.label:SetJustifyH("LEFT")
    dd.chev = dd:CreateTexture(nil, "ARTWORK")
    dd.chev:SetSize(11, 11)
    dd.chev:SetTexture("Interface\\AddOns\\Bistooltip\\icons\\chevron.tga")
    dd.chev:SetVertexColor(0.62, 0.62, 0.67, 1)
    dd.chev:SetPoint("RIGHT", -8, 0)
    dd.label:SetPoint("RIGHT", dd.chev, "LEFT", -6, 0)
    dd.options = {}

    function dd:SetOptions(opts) self.options = opts or {} end

    function dd:SetValue(value)
        self.value = value
        for _, opt in ipairs(self.options) do
            if opt.value == value then
                if opt.icon then self.icon:SetTexture(opt.icon); self.icon:Show() else self.icon:Hide() end
                self.label:SetText(opt.text or "")
                local col = opt.color or C.textPrimary
                self.label:SetTextColor(col[1], col[2], col[3], 1)
                return
            end
        end
    end

    function dd:SetOnChange(fn) self.onChange = fn end
    function dd:SetDisabled(flag)
        self.disabled = flag
        self:SetAlpha(flag and 0.5 or 1)
        if flag then self:Disable() else self:Enable() end
    end

    dd:SetScript("OnEnter", function(self) if not self.disabled then self.bgTex:SetColorTexture(C.panelHover[1], C.panelHover[2], C.panelHover[3], 1) end end)
    dd:SetScript("OnLeave", function(self) self.bgTex:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], 1) end)
    dd:SetScript("OnClick", function(self)
        if self.disabled then return end
        if openList == self then W.closeDropdown() else openDropdownList(self) end
    end)
    return dd
end

-- ----------------------------------------------------------------------- --
-- Checkbox + radio (for settings)
-- ----------------------------------------------------------------------- --

function W.checkbox(parent, label)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetHeight(20)
    local box = CreateFrame("Frame", nil, cb)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    W.bg(box, C.panel)
    W.border(box, C.border)
    cb.check = box:CreateTexture(nil, "OVERLAY")
    cb.check:SetAllPoints(box)
    cb.check:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    cb.check:Hide()
    cb.box = box
    cb.label = text(cb, 13, C.textPrimary)
    cb.label:SetPoint("LEFT", box, "RIGHT", 9, 0)
    cb.label:SetJustifyH("LEFT")
    if label then cb.label:SetText(label) end
    cb:SetWidth(240)
    function cb:SetChecked(v) self.checked = v; if v then self.check:Show() else self.check:Hide() end end
    function cb:SetOnClick(fn) self.onClick = fn end
    cb:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if self.onClick then self.onClick(self.checked) end
    end)
    return cb
end

function W.radio(parent, label)
    local rb = CreateFrame("Button", nil, parent)
    rb:SetHeight(22)
    local dot = CreateFrame("Frame", nil, rb)
    dot:SetSize(15, 15)
    dot:SetPoint("LEFT")
    W.bg(dot, C.panel)
    W.border(dot, C.border)
    rb.fill = dot:CreateTexture(nil, "OVERLAY")
    rb.fill:SetPoint("CENTER")
    rb.fill:SetSize(7, 7)
    rb.fill:SetColorTexture(C.green[1], C.green[2], C.green[3], 1)
    rb.fill:Hide()
    rb.label = text(rb, 13, C.textPrimary)
    rb.label:SetPoint("LEFT", dot, "RIGHT", 9, 0)
    if label then rb.label:SetText(label) end
    rb:SetWidth(240)
    function rb:SetSelected(v) self.selected = v; if v then self.fill:Show() else self.fill:Hide() end end
    function rb:SetOnClick(fn) self.onClick = fn end
    rb:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return rb
end

-- ----------------------------------------------------------------------- --
-- Scroll area: returns scrollframe with .content child; auto mouse wheel.
-- ----------------------------------------------------------------------- --

function W.scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf.content = content

    local thumb = CreateFrame("Frame", nil, sf)
    thumb:SetWidth(4)
    W.bg(thumb, C.border)
    thumb:Hide()
    sf.thumb = thumb

    local function update()
        local h = sf:GetHeight()
        local ch = content:GetHeight()
        -- Clamp any leftover scroll offset (e.g. after the window is enlarged).
        local maxScrollNow = math.max(ch - h, 0)
        if sf:GetVerticalScroll() > maxScrollNow then sf:SetVerticalScroll(maxScrollNow) end
        if ch <= h or h <= 0 then thumb:Hide(); return end
        local cur = sf:GetVerticalScroll()
        local ratio = h / ch
        thumb:SetHeight(math.max(h * ratio, 20))
        thumb:ClearAllPoints()
        local track = h - thumb:GetHeight()
        local maxScroll = ch - h
        local y = (maxScroll > 0) and (cur / maxScroll) * track or 0
        thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -y)
        thumb:Show()
    end
    sf.updateThumb = update

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local h = self:GetHeight()
        local ch = content:GetHeight()
        local maxScroll = math.max(ch - h, 0)
        local new = self:GetVerticalScroll() - delta * 40
        if new < 0 then new = 0 elseif new > maxScroll then new = maxScroll end
        self:SetVerticalScroll(new)
        update()
    end)
    content:SetScript("OnSizeChanged", update)
    sf:SetScript("OnSizeChanged", function(self)
        content:SetWidth(self:GetWidth())
        update()
    end)
    return sf
end
