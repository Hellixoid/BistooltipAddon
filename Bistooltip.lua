-- Item tooltip enrichment. BiS data is shown in a separate box attached to the
-- bottom of the item tooltip (like the old LibExtraTip "extra tip"), driven by
-- the client's native tooltip system (TooltipDataProcessor on the 11.x-era
-- engine, e.g. WoW Forever 5.5.4) with a legacy OnTooltipSetItem fallback.
-- No external tooltip library.

local extraTip                      -- our attached tooltip frame (created lazily)
local anchorHost                    -- the tooltip we're currently attached to
local shownItemId                   -- item id currently displayed in the box

local CLASS_FILE = {
    ["Druid"] = "DRUID", ["Hunter"] = "HUNTER", ["Mage"] = "MAGE",
    ["Paladin"] = "PALADIN", ["Priest"] = "PRIEST", ["Rogue"] = "ROGUE",
    ["Shaman"] = "SHAMAN", ["Warlock"] = "WARLOCK", ["Warrior"] = "WARRIOR",
    ["Death knight"] = "DEATHKNIGHT", ["Monk"] = "MONK",
}

local function classColor(class_name)
    local file = CLASS_FILE[class_name]
    if file and GetClassColor then
        local r, g, b = GetClassColor(file)
        if r then return r, g, b end
    end
    return 1, 0.8, 0
end

local function isHighlighted(class_name, spec_name)
    local mode = BistooltipAddon.db.char.highlight_mode
    if mode == "class" then
        return class_name == BistooltipAddon.playerClassName
    elseif mode == "spec" then
        return class_name == BistooltipAddon.playerClassName
            and BistooltipAddon.playerSpecs and BistooltipAddon.playerSpecs[spec_name] == true
    end
    return false
end

-- Filter mode mirrors the highlight modes, but hides non-matching specs instead
-- of recoloring them. "none" shows everything.
local function passesFilter(class_name, spec_name)
    local mode = BistooltipAddon.db.char.filter_mode
    if mode == "class" then
        return class_name == BistooltipAddon.playerClassName
    elseif mode == "spec" then
        return class_name == BistooltipAddon.playerClassName
            and BistooltipAddon.playerSpecs and BistooltipAddon.playerSpecs[spec_name] == true
    end
    return true
end

-- True if at least one spec for this item survives the current filter.
local function hasBisToShow(itemId)
    local item = Bistooltip_items and Bistooltip_items[itemId]
    if not item or #item == 0 then return false end
    for _, spec in ipairs(item) do
        if passesFilter(spec.class_name, spec.spec_name) then return true end
    end
    return false
end

local function classNamesFiltered()
    return BistooltipAddon.db.char.filter_class_names == true
end

local function printSpecLine(tooltip, slot, class_name, spec_name)
    local slot_name = slot.name
    local suffix = slot.suffix
    local slot_ranks = slot.ranks
    local prefix = classNamesFiltered() and "" or "   "

    local icon = Bistooltip_spec_icons[class_name] and Bistooltip_spec_icons[class_name][spec_name]
    local left_text = prefix
    if icon then left_text = left_text .. "|T" .. icon .. ":14|t " end
    left_text = left_text .. spec_name
    if slot_name == "Off hand" or slot_name == "Weapon" or slot_name == "Weapon 1H" or slot_name == "Weapon 2H" then
        left_text = left_text .. " (" .. slot_name .. ")"
    end
    if suffix and suffix ~= "" then
        left_text = left_text .. " " .. suffix
    end

    local r, g, b
    if isHighlighted(class_name, spec_name) then
        r, g, b = 0.074, 0.964, 0.129
    else
        r, g, b = classColor(class_name)
    end

    tooltip:AddDoubleLine(left_text, slot_ranks or "", r, g, b, r, g, b)
end

local function printClassName(tooltip, class_name)
    tooltip:AddLine(class_name, 1, 0.8, 0)
end

-- Fill `tooltip` with the BiS lines for itemId. Returns true if anything added.
local function populate(tooltip, itemId)
    if not itemId or Bistooltip_items == nil or Bistooltip_items[itemId] == nil then return false end
    local item = Bistooltip_items[itemId]
    if #item == 0 then return false end

    -- Apply the filter mode: keep only the specs that match (all, when "none").
    local matches = {}
    for _, spec in ipairs(item) do
        if passesFilter(spec.class_name, spec.spec_name) then
            matches[#matches + 1] = spec
        end
    end
    if #matches == 0 then return false end

    tooltip:AddDoubleLine("Spec name", Bistooltip_phases_string or "", 1, 1, 0, 1, 1, 0)

    local previous_class = nil
    for _, spec in ipairs(matches) do
        local class_name = spec.class_name
        local spec_name = spec.spec_name
        for _, slot in ipairs(spec.slots) do
            if not classNamesFiltered() then
                if previous_class ~= class_name then
                    printClassName(tooltip, class_name)
                    previous_class = class_name
                end
            end
            printSpecLine(tooltip, slot, class_name, spec_name)
        end
    end

    if Bistooltip_char_equipment and Bistooltip_char_equipment[itemId] ~= nil then
        tooltip:AddLine(" ", 1, 1, 0)
        if Bistooltip_char_equipment[itemId] == 2 then
            tooltip:AddLine("You have this item equipped", 0.074, 0.964, 0.129)
        else
            tooltip:AddLine("You have this item in your inventory", 0.074, 0.964, 0.129)
        end
    end
    return true
end

local function ensureExtraTip()
    if extraTip then return extraTip end
    extraTip = CreateFrame("GameTooltip", "BistooltipExtraTip", UIParent, "GameTooltipTemplate")
    extraTip:SetClampedToScreen(true)
    return extraTip
end

local function hideExtra()
    if extraTip then extraTip:Hide() end
    anchorHost = nil
    shownItemId = nil
end

-- Show the attached BiS box under `host` (the item tooltip that fired).
local function showExtra(host, itemId)
    -- Some tooltips (e.g. merchant items) re-fire this callback several times a
    -- second while hovered. If we're already showing this item under the same
    -- host, leave the box untouched -- rebuilding it every frame makes it flicker.
    if extraTip and extraTip:IsShown() and anchorHost == host and shownItemId == itemId then
        return
    end

    hideExtra()
    if BistooltipAddon.db.char.tooltip_with_ctrl and not IsControlKeyDown() then return end

    -- Bail early if there's nothing to show (no data, or the filter hides it
    -- all), so we never flash an empty box.
    if not itemId or not hasBisToShow(itemId) then
        return
    end

    local et = ensureExtraTip()
    et:SetParent(UIParent)
    et:SetScale(host:GetScale() or 1)
    et:SetFrameStrata(host:GetFrameStrata())
    et:SetFrameLevel(host:GetFrameLevel() + 1)
    anchorHost = host
    shownItemId = itemId

    -- Lay out the box at a given minimum content width. SetMinimumWidth only
    -- takes effect through a fresh layout pass (ClearLines -> AddLine -> Show);
    -- calling Show() on an already-shown tooltip is a no-op.
    local function buildAt(minW)
        et:SetOwner(UIParent, "ANCHOR_NONE")
        et:ClearLines()
        if minW and minW > 0 then et:SetMinimumWidth(minW) end
        populate(et, itemId)
        et:ClearAllPoints()
        et:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -3)
        et:Show()
    end

    -- Match the box's final rendered width to the host's. GetWidth() includes
    -- each tooltip's own border padding, so feeding host:GetWidth() straight
    -- into SetMinimumWidth overshoots by one padding's worth. Measure the
    -- overshoot and shrink the minimum until the two widths line up (a few
    -- iterations; stops early once equal or once content sets the floor).
    local function layout()
        if not extraTip or anchorHost ~= host or not host:IsShown() then return end
        local hostW = host:GetWidth()
        if not hostW or hostW <= 0 then return end
        local minW, prevW = hostW, nil
        for _ = 1, 5 do
            buildAt(minW)
            local w = et:GetWidth() or hostW
            local over = w - hostW
            if over <= 0.5 then break end
            if prevW and math.abs(w - prevW) < 0.5 then break end
            prevW = w
            minW = minW - over
            if minW <= 0 then break end
        end
    end

    layout()
    -- Re-run on later frames in case the host tooltip changes size after our
    -- post-call (other addons appending lines, async item info loading).
    if C_Timer and C_Timer.After then
        C_Timer.After(0, layout)
        C_Timer.After(0.1, layout)
    end
end

-- Resolve the item id a tooltip is currently displaying, across API variants.
local function tooltipItemId(tooltip, data)
    if data and data.id then return data.id end
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if link then return tonumber(link:match("item:(%d+)")) end
    end
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if link then return tonumber(link:match("item:(%d+)")) end
    end
    return nil
end

local function hookHost(host)
    if not host or host.bistooltipHooked then return end
    host.bistooltipHooked = true
    -- Some hosts (notably the auction house) hide and immediately re-show the
    -- tooltip on every refresh tick. Hiding our box straight away makes it
    -- flicker, so defer a frame and only hide if the host is still gone.
    host:HookScript("OnHide", function(self)
        if anchorHost ~= self then return end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if anchorHost == self and not self:IsShown() then hideExtra() end
            end)
        else
            hideExtra()
        end
    end)
end

function BistooltipAddon:initBisTooltip()
    hookHost(GameTooltip)
    hookHost(ItemRefTooltip)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        -- Modern engine: one post-call fires for every item tooltip.
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
            showExtra(tooltip, tooltipItemId(tooltip, data))
        end)
    else
        -- Legacy fallback: hook the item tooltip script directly.
        local function hook(tt)
            showExtra(tt, tooltipItemId(tt, nil))
        end
        GameTooltip:HookScript("OnTooltipSetItem", hook)
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", hook) end
    end
end
