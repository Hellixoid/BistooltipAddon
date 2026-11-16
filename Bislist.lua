BistooltipAddon = BistooltipAddon or {}
local W = BistooltipAddon.Widgets
local C

local main_frame
local classDD, specDD, phaseDD
local scroll, content
local statusText

local class_index, spec_index, phase_index

local WIDTH = 450
local PAD = 12
local ENH_X = 102
local ITEMS_X = 148
local ITEM_CELL = 48
local ICON = 40
local ROW_H = 46
local isHorde = UnitFactionGroup("player") == "Horde"

-- pools (all children of `content`, positioned absolutely) ------------------
local itemPool, labelPool, zebraPool, enhPool = {}, {}, {}, {}
local itemN, labelN, zebraN, enhN

local function resetPools()
    itemN, labelN, zebraN, enhN = 0, 0, 0, 0
    for _, w in ipairs(itemPool) do w:Hide() end
    for _, w in ipairs(labelPool) do w:Hide() end
    for _, w in ipairs(zebraPool) do w:Hide() end
    for _, w in ipairs(enhPool) do w:Hide() end
end

local function getLabel()
    labelN = labelN + 1
    local fs = labelPool[labelN]
    if not fs then
        fs = content:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\FRIZQT__.TTF", 13)
        labelPool[labelN] = fs
    end
    fs:Show()
    return fs
end

local function getZebra()
    zebraN = zebraN + 1
    local t = zebraPool[zebraN]
    if not t then
        t = content:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(C.rowAlt[1], C.rowAlt[2], C.rowAlt[3], C.rowAlt[4])
        zebraPool[zebraN] = t
    end
    t:Show()
    return t
end

local function cellX(i)
    return ITEMS_X + (i - 1) * ITEM_CELL + (ITEM_CELL - ICON) / 2
end

local function newItemButton()
    local btn = CreateFrame("Button", nil, content)
    btn:SetSize(ICON, ICON)
    W.bg(btn, { 0.149, 0.153, 0.176, 1 })
    W.border(btn, C.border)
    btn.tex = btn:CreateTexture(nil, "ARTWORK")
    btn.tex:SetPoint("TOPLEFT", 2, -2)
    btn.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.check = btn:CreateTexture(nil, "OVERLAY")
    btn.check:SetSize(18, 18)
    btn.check:SetPoint("BOTTOMRIGHT", 3, -3)
    btn.check:SetTexture("Interface\\AddOns\\Bistooltip\\checkmark-16.tga")
    btn.check:Hide()
    btn.boe = btn:CreateTexture(nil, "OVERLAY")
    btn.boe:SetSize(14, 14)
    btn.boe:SetPoint("TOPLEFT", -3, 3)
    btn.boe:SetTexture("Interface\\AddOns\\Bistooltip\\icons\\coin.tga")
    btn.boe:Hide()
    return btn
end

local function getItemButton()
    itemN = itemN + 1
    local btn = itemPool[itemN]
    if not btn then btn = newItemButton(); itemPool[itemN] = btn end
    btn.tex:SetTexture(nil)
    btn.check:Hide()
    btn.boe:Hide()
    for _, t in ipairs(btn.borderTex) do t:SetColorTexture(C.border[1], C.border[2], C.border[3], 1) end
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("OnClick", nil)
    btn:Show()
    return btn
end

local function fillItemButton(btn, item_id, withCheck)
    local it = Item:CreateFromItemID(item_id)
    if not it:GetItemID() then return end
    it:ContinueOnItemLoad(function()
        if not btn:IsShown() then return end
        local link = it:GetItemLink()
        btn.tex:SetTexture(it:GetItemIcon())
        local quality = select(3, GetItemInfo(item_id))
        local bindType = select(14, GetItemInfo(item_id))
        local qc = quality and ITEM_QUALITY_COLORS[quality]
        if qc then
            for _, t in ipairs(btn.borderTex) do t:SetColorTexture(qc.r, qc.g, qc.b, 1) end
        end
        if bindType == 2 then btn.boe:Show() end
        if withCheck then btn.check:Show() end
        btn:SetScript("OnClick", function() if link then SetItemRef(link, link, "LeftButton") end end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if not ok then pcall(GameTooltip.SetItemByID, GameTooltip, item_id) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end)
end

local function getEnhIcon()
    enhN = enhN + 1
    local b = enhPool[enhN]
    if not b then
        b = CreateFrame("Button", nil, content)
        b:SetSize(16, 16)
        W.bg(b, { 0.149, 0.153, 0.176, 1 })
        W.border(b, C.border)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetPoint("TOPLEFT", 1, -1)
        b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        enhPool[enhN] = b
    end
    b.tex:SetTexture(nil)
    b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil); b:SetScript("OnClick", nil)
    b:Show()
    return b
end

local function fillEnhItem(b, item_id)
    local it = Item:CreateFromItemID(item_id)
    if not it:GetItemID() then return end
    it:ContinueOnItemLoad(function()
        if not b:IsShown() then return end
        local link = it:GetItemLink()
        b.tex:SetTexture(it:GetItemIcon())
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            local ok = link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if not ok then pcall(GameTooltip.SetItemByID, GameTooltip, item_id) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function() if link then SetItemRef(link, link, "LeftButton") end end)
    end)
end

-- GetSpellInfo / GetSpellLink were removed from the global namespace on the
-- modern engine (WoW Forever 5.5.4); the data now lives under C_Spell. Fall
-- back to the old globals for older clients.
local function spellIcon(spell_id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell_id) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell_id)
        return info and (info.iconID or info.iconFileID)
    end
    if GetSpellInfo then return select(3, GetSpellInfo(spell_id)) end
    return nil
end

local function spellLink(spell_id)
    if C_Spell and C_Spell.GetSpellLink then return C_Spell.GetSpellLink(spell_id) end
    if GetSpellLink then return GetSpellLink(spell_id) end
    return nil
end

local function fillEnhSpell(b, spell_id)
    local sp = Spell:CreateFromSpellID(spell_id)
    if not sp:GetSpellID() then return end
    sp:ContinueOnSpellLoad(function()
        if not b:IsShown() then return end
        b.tex:SetTexture(spellIcon(spell_id))
        local link = spellLink(spell_id)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            local ok = link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if not ok then pcall(GameTooltip.SetSpellByID, GameTooltip, spell_id) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function() if link then SetItemRef(link, link, "LeftButton") end end)
    end)
end

-- drawing -------------------------------------------------------------------

local function currentNames()
    local cl = Bistooltip_classes and Bistooltip_classes[class_index]
    if not cl then return nil end
    local sp = cl.specs and cl.specs[spec_index]
    local ph = Bistooltip_phases and Bistooltip_phases[phase_index]
    return cl.name, sp, ph
end

local function drawSpecData()
    if not content then return end
    resetPools()
    local class_name, spec_name, phase_name = currentNames()
    if not class_name or not spec_name or not phase_name then
        content:SetHeight(1); if scroll then scroll.updateThumb() end; return
    end
    local slots = Bistooltip_bislists[class_name]
        and Bistooltip_bislists[class_name][spec_name]
        and Bistooltip_bislists[class_name][spec_name][phase_name]
    if not slots then content:SetHeight(1); if scroll then scroll.updateThumb() end; return end

    local row = 0
    for _, slot in ipairs(slots) do
        if slot[1] and slot[1] ~= -1 then
            local top = -row * ROW_H
            if row % 2 == 1 then
                local z = getZebra()
                z:ClearAllPoints()
                z:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
                z:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
                z:SetHeight(ROW_H)
            end
            local lbl = getLabel()
            lbl:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3], 1)
            lbl:SetText(slot.slot_name or "")
            lbl:ClearAllPoints()
            lbl:SetPoint("LEFT", content, "TOPLEFT", PAD, top - ROW_H / 2)
            lbl:SetJustifyH("LEFT")

            local ex = ENH_X
            for _, enh in ipairs(slot.enhs or {}) do
                if (enh.type == "item" or enh.type == "spell") and enh.id and enh.id > 0 and ex < ITEMS_X - 14 then
                    local eb = getEnhIcon()
                    eb:ClearAllPoints()
                    eb:SetPoint("TOPLEFT", content, "TOPLEFT", ex, top - (ROW_H - 16) / 2)
                    if enh.type == "item" then fillEnhItem(eb, enh.id) else fillEnhSpell(eb, enh.id) end
                    ex = ex + 20
                end
            end

            for i = 1, 6 do
                local item_id = slot[i]
                if item_id and item_id ~= -1 then
                    if isHorde and Bistooltip_horde_to_ali and Bistooltip_horde_to_ali[item_id] then
                        item_id = Bistooltip_horde_to_ali[item_id]
                    end
                    local owned = Bistooltip_char_equipment[item_id] ~= nil
                    local btn = getItemButton()
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", content, "TOPLEFT", cellX(i), top - (ROW_H - ICON) / 2)
                    fillItemButton(btn, item_id, owned)
                end
            end
            row = row + 1
        end
    end
    content:SetHeight(math.max(row * ROW_H, 1))
    if scroll then scroll.updateThumb() end
end

-- options -------------------------------------------------------------------

local function classColorTbl(class_name)
    local file = ({ Druid = "DRUID", Hunter = "HUNTER", Mage = "MAGE", Paladin = "PALADIN",
        Priest = "PRIEST", Rogue = "ROGUE", Shaman = "SHAMAN", Warlock = "WARLOCK",
        Warrior = "WARRIOR" })[class_name]
    if file and GetClassColor then
        local r, g, b = GetClassColor(file)
        if r then return { r, g, b } end
    end
    return C.textPrimary
end

local function classOptions()
    local opts = {}
    for ci, cl in ipairs(Bistooltip_classes) do
        opts[#opts + 1] = {
            text = cl.name, value = ci,
            icon = Bistooltip_spec_icons[cl.name] and Bistooltip_spec_icons[cl.name].classIcon,
            color = classColorTbl(cl.name),
        }
    end
    return opts
end

local function specOptions(ci)
    local opts = {}
    local cl = Bistooltip_classes[ci]
    if not cl then return opts end
    for si, sp in ipairs(cl.specs) do
        opts[#opts + 1] = {
            text = sp, value = si,
            icon = Bistooltip_spec_icons[cl.name] and Bistooltip_spec_icons[cl.name][sp],
        }
    end
    return opts
end

local function phaseOptions()
    local opts = {}
    for pi, ph in ipairs(Bistooltip_phases or {}) do
        opts[#opts + 1] = { text = ph, value = pi }
    end
    return opts
end

local function refreshHighlightBtn()
    -- Highlight mode is configured in the settings panel; nothing to update here.
end

local function saveSelection()
    BistooltipAddon.db.char.class_index = class_index
    BistooltipAddon.db.char.spec_index = spec_index
    BistooltipAddon.db.char.phase_index = phase_index
end

local function clampSelection()
    if not Bistooltip_classes[class_index] then class_index = 1 end
    local cl = Bistooltip_classes[class_index]
    if not cl.specs[spec_index] then spec_index = 1 end
    if not (Bistooltip_phases and Bistooltip_phases[phase_index]) then phase_index = 1 end
end

-- window --------------------------------------------------------------------

local function saveWindow()
    if not main_frame then return end
    local point, _, rel, x, y = main_frame:GetPoint()
    BistooltipAddon.db.char.bis_list_window = {
        point = point, relativePoint = rel, x = x, y = y, height = main_frame:GetHeight(),
    }
end

local function buildWindow()
    local f = CreateFrame("Frame", "BistooltipMainFrame", UIParent)
    main_frame = f
    f:SetSize(WIDTH, (BistooltipAddon.db.char.bis_list_window and BistooltipAddon.db.char.bis_list_window.height) or 560)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(WIDTH, 320, WIDTH, 1400) end
    W.bg(f, C.window)
    W.border(f, C.border)

    tinsert(UISpecialFrames, "BistooltipMainFrame")

    local pos = BistooltipAddon.db.char.bis_list_window
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end

    -- header
    local header = W.panel(f, C.header)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(40)
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function() f:StartMoving() end)
    header:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); saveWindow() end)
    local hbot = header:CreateTexture(nil, "BORDER")
    hbot:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    hbot:SetPoint("BOTTOMLEFT"); hbot:SetPoint("BOTTOMRIGHT"); hbot:SetHeight(1)

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22); icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture("interface/icons/inv_weapon_glave_01.blp")
    local title = W.text(header, 14, C.textPrimary)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("BiS-Tooltip")
    local ver = W.text(header, 12, C.textMuted)
    ver:SetPoint("LEFT", title, "RIGHT", 6, 0)
    ver:SetText("v9.17")

    local close = W.iconButton(header, 26)
    close:SetPoint("RIGHT", -8, 0)
    close.tex = close:CreateTexture(nil, "ARTWORK")
    close.tex:SetSize(13, 13); close.tex:SetPoint("CENTER")
    close.tex:SetTexture("Interface\\AddOns\\Bistooltip\\icons\\close.tga")
    close.tex:SetVertexColor(0.62, 0.62, 0.67, 1)
    close:HookScript("OnEnter", function() close.tex:SetVertexColor(0.88, 0.34, 0.34, 1) end)
    close:HookScript("OnLeave", function() close.tex:SetVertexColor(0.62, 0.62, 0.67, 1) end)
    close:SetScript("OnClick", function() BistooltipAddon:closeMainFrame() end)

    local gear = W.iconButton(header, 26)
    gear:SetPoint("RIGHT", close, "LEFT", -2, 0)
    gear.tex = gear:CreateTexture(nil, "ARTWORK")
    gear.tex:SetSize(16, 16); gear.tex:SetPoint("CENTER")
    gear.tex:SetTexture("Interface\\AddOns\\Bistooltip\\icons\\gear.tga")
    gear.tex:SetVertexColor(0.70, 0.70, 0.74, 1)
    gear:HookScript("OnEnter", function() gear.tex:SetVertexColor(0.92, 0.92, 0.95, 1) end)
    gear:HookScript("OnLeave", function() gear.tex:SetVertexColor(0.70, 0.70, 0.74, 1) end)
    gear:SetScript("OnClick", function() BistooltipAddon:openSettings() end)

    -- source toggle
    local srcWrap = CreateFrame("Frame", nil, header)
    srcWrap:SetSize(150, 24)
    srcWrap:SetPoint("RIGHT", gear, "LEFT", -8, 0)
    local function srcButton(key, anchorRight)
        local b = CreateFrame("Button", nil, srcWrap)
        b:SetSize(74, 24)
        W.bg(b, C.panel); W.border(b, C.border)
        b.label = W.text(b, 12, C.textSecond); b.label:SetPoint("CENTER")
        b.label:SetText(Bistooltip_source_to_name[key] or key)
        b.key = key
        b:SetScript("OnClick", function()
            if BistooltipAddon.db.char.data_source ~= key then
                BistooltipAddon:changeDataSource(key)
            end
        end)
        return b
    end
    local srcWh = srcButton("wh"); srcWh:SetPoint("LEFT")
    local srcTbc = srcButton("wowtbc"); srcTbc:SetPoint("LEFT", srcWh, "RIGHT", 2, 0)
    f.srcButtons = { srcWh, srcTbc }
    f.refreshSource = function()
        for _, b in ipairs(f.srcButtons) do
            local active = BistooltipAddon.db.char.data_source == b.key
            if active then
                b.bgTex:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
                b.label:SetTextColor(0.14, 0.11, 0.05, 1)
            else
                b.bgTex:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], 1)
                b.label:SetTextColor(C.textSecond[1], C.textSecond[2], C.textSecond[3], 1)
            end
        end
    end

    -- toolbar
    local toolbar = CreateFrame("Frame", nil, f)
    toolbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    toolbar:SetHeight(46)

    classDD = W.dropdown(toolbar, 120); classDD:SetPoint("LEFT", 12, 0)
    specDD = W.dropdown(toolbar, 150); specDD:SetPoint("LEFT", classDD, "RIGHT", 8, 0)
    phaseDD = W.dropdown(toolbar, 130); phaseDD:SetPoint("LEFT", specDD, "RIGHT", 8, 0)

    classDD:SetOnChange(function(ci)
        class_index = ci; spec_index = 1
        specDD:SetOptions(specOptions(ci)); specDD:SetValue(1); specDD:SetDisabled(false)
        saveSelection(); drawSpecData()
    end)
    specDD:SetOnChange(function(si) spec_index = si; saveSelection(); drawSpecData() end)
    phaseDD:SetOnChange(function(pi) phase_index = pi; saveSelection(); drawSpecData() end)

    -- grid header
    local gh = CreateFrame("Frame", nil, f)
    gh:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, 0)
    gh:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, 0)
    gh:SetHeight(22)
    local function ghLabel(txt, x, justify)
        local fs = W.text(gh, 11, C.textMuted); fs:SetText(txt)
        fs:SetPoint("LEFT", gh, "LEFT", x, 0)
        if justify then fs:SetJustifyH(justify) end
        return fs
    end
    ghLabel("Slot", PAD)
    ghLabel("Enh", ENH_X)
    for i = 1, 6 do ghLabel(i == 1 and "Top 1" or tostring(i), cellX(i)) end
    local ghbot = gh:CreateTexture(nil, "BORDER")
    ghbot:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
    ghbot:SetPoint("BOTTOMLEFT"); ghbot:SetPoint("BOTTOMRIGHT"); ghbot:SetHeight(1)

    -- footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(26)
    local ftop = footer:CreateTexture(nil, "BORDER")
    ftop:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    ftop:SetPoint("TOPLEFT"); ftop:SetPoint("TOPRIGHT"); ftop:SetHeight(1)
    statusText = W.text(footer, 11, C.textMuted)
    statusText:SetPoint("LEFT", 12, 0)

    -- Pin the frame to its current top-left corner so vertical sizing keeps the
    -- top edge fixed (a CENTER-anchored frame would resize from the middle).
    local function anchorTopLeft()
        local l, t = f:GetLeft(), f:GetTop()
        if not l or not t then return end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    end

    local grip = CreateFrame("Button", nil, footer)
    grip:SetSize(16, 16); grip:SetPoint("RIGHT", -6, 0)
    local gripTex = grip:CreateTexture(nil, "ARTWORK")
    gripTex:SetSize(12, 12); gripTex:SetPoint("CENTER")
    gripTex:SetTexture("Interface\\AddOns\\Bistooltip\\icons\\grip.tga")
    gripTex:SetVertexColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    grip:SetScript("OnEnter", function() gripTex:SetVertexColor(0.70, 0.70, 0.74, 1) end)
    grip:SetScript("OnLeave", function() gripTex:SetVertexColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1) end)
    grip:SetScript("OnMouseDown", function() anchorTopLeft(); f:StartSizing("BOTTOM") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); saveWindow(); if scroll then scroll.updateThumb() end end)

    -- scroll
    scroll = W.scroll(f)
    scroll:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -4, 2)
    content = scroll.content
    content:SetWidth(WIDTH - 6)

    f:SetScript("OnSizeChanged", function() if scroll then scroll.updateThumb() end end)
end

function BistooltipAddon:reloadData()
    if not Bistooltip_classes then return end
    class_index = BistooltipAddon.db.char.class_index or 1
    spec_index = BistooltipAddon.db.char.spec_index or 1
    phase_index = BistooltipAddon.db.char.phase_index or 1
    clampSelection()
    if main_frame then
        classDD:SetOptions(classOptions()); classDD:SetValue(class_index)
        specDD:SetOptions(specOptions(class_index)); specDD:SetValue(spec_index); specDD:SetDisabled(false)
        phaseDD:SetOptions(phaseOptions()); phaseDD:SetValue(phase_index)
        refreshHighlightBtn()
        if main_frame.refreshSource then main_frame.refreshSource() end
        if statusText then statusText:SetText(Bistooltip_source_to_url[BistooltipAddon.db.char.data_source] or "") end
        drawSpecData()
    end
end

function BistooltipAddon:createMainFrame()
    if not main_frame then
        buildWindow()
        BistooltipAddon:reloadData()
        main_frame:Show()
        return
    end
    if main_frame:IsShown() then
        BistooltipAddon:closeMainFrame()
    else
        BistooltipAddon:reloadData()
        main_frame:Show()
    end
end

function BistooltipAddon:closeMainFrame()
    W.closeDropdown()
    if BistooltipAddon.closeSettings then BistooltipAddon:closeSettings() end
    if main_frame then
        saveWindow()
        main_frame:Hide()
    end
end

function BistooltipAddon:getMainFrame() return main_frame end

function BistooltipAddon:setHighlightMode(mode)
    BistooltipAddon.db.char.highlight_mode = mode
    refreshHighlightBtn()
end

function BistooltipAddon:initBislists()
    C = BistooltipAddon.Colors
    class_index = BistooltipAddon.db.char.class_index or 1
    spec_index = BistooltipAddon.db.char.spec_index or 1
    phase_index = BistooltipAddon.db.char.phase_index or 1
    if not SlashCmdList["BISTOOLTIP"] then
        SLASH_BISTOOLTIP1 = "/bistooltip"
        SlashCmdList["BISTOOLTIP"] = function() BistooltipAddon:createMainFrame() end
    end
end
