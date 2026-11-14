BistooltipAddon = BistooltipAddon or {}

local function build(mf)
    local W = BistooltipAddon.Widgets
    local C = BistooltipAddon.Colors
    local db = BistooltipAddon.db.char

    local overlay = CreateFrame("Frame", nil, mf)
    overlay:SetAllPoints(mf)
    overlay:EnableMouse(true)
    overlay:SetFrameStrata("DIALOG")
    W.bg(overlay, { 0, 0, 0, 0.55 })

    local card = W.panel(overlay, C.header)
    W.border(card, C.border)
    card:SetSize(320, 320)
    card:SetPoint("CENTER")

    local titleBar = W.panel(card, C.window)
    titleBar:SetPoint("TOPLEFT"); titleBar:SetPoint("TOPRIGHT"); titleBar:SetHeight(34)
    local tbot = titleBar:CreateTexture(nil, "BORDER")
    tbot:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    tbot:SetPoint("BOTTOMLEFT"); tbot:SetPoint("BOTTOMRIGHT"); tbot:SetHeight(1)
    local title = W.text(titleBar, 14, C.textPrimary); title:SetPoint("LEFT", 12, 0); title:SetText("Settings")
    local close = W.button(titleBar, "x", 24, 24); close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() BistooltipAddon:closeSettings() end)

    local y = -46
    local function sectionLabel(txt)
        local fs = W.text(card, 11, C.textMuted); fs:SetText(txt)
        fs:SetPoint("TOPLEFT", 14, y); y = y - 20
    end

    sectionLabel("Highlight in tooltips")

    local radios = {}
    local function makeRadio(mode, label)
        local rb = W.radio(card, label)
        rb:SetPoint("TOPLEFT", 16, y); y = y - 24
        rb:SetOnClick(function()
            BistooltipAddon:setHighlightMode(mode)
            for m, r in pairs(radios) do r:SetSelected(m == mode) end
        end)
        radios[mode] = rb
    end
    makeRadio("none", "None")
    makeRadio("class", "Your class")
    makeRadio("spec", "Current spec(s)")

    y = y - 6
    local div = card:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    div:SetPoint("TOPLEFT", 14, y); div:SetPoint("TOPRIGHT", -14, y); div:SetHeight(1)
    y = y - 12

    local function makeCheck(label, getFn, setFn)
        local cb = W.checkbox(card, label)
        cb:SetPoint("TOPLEFT", 16, y); y = y - 26
        cb:SetChecked(getFn())
        cb:SetOnClick(setFn)
        return cb
    end

    local cbMinimap = makeCheck("Show minimap icon",
        function() return db.minimap_icon end,
        function(v) BistooltipAddon:setMinimapIcon(v) end)
    local cbClassNames = makeCheck("Hide class names",
        function() return db.filter_class_names end,
        function(v) db.filter_class_names = v end)
    local cbCtrl = makeCheck("Show item tooltips with Ctrl",
        function() return db.tooltip_with_ctrl end,
        function(v) db.tooltip_with_ctrl = v end)

    card:SetHeight(-y + 16)

    overlay.refresh = function()
        for m, r in pairs(radios) do r:SetSelected(m == db.highlight_mode) end
        cbMinimap:SetChecked(db.minimap_icon)
        cbClassNames:SetChecked(db.filter_class_names)
        cbCtrl:SetChecked(db.tooltip_with_ctrl)
    end

    mf.settingsPanel = overlay
    return overlay
end

function BistooltipAddon:openSettings()
    local mf = BistooltipAddon:getMainFrame()
    if not mf then
        BistooltipAddon:createMainFrame()
        mf = BistooltipAddon:getMainFrame()
    end
    if not mf then return end
    local panel = mf.settingsPanel
    if not panel then panel = build(mf) end
    panel.refresh()
    panel:Show()
end

function BistooltipAddon:closeSettings()
    local mf = BistooltipAddon:getMainFrame()
    if mf and mf.settingsPanel then mf.settingsPanel:Hide() end
end
