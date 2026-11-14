-- Talent-based spec detection. WoW Forever allows two talent groups (dual spec);
-- a group's spec is the talent tab with the most points spent. Druid's single
-- "Feral Combat" tree maps to both Feral DPS and Feral Tank.
BistooltipAddon = BistooltipAddon or {}

local CLASS_MAP = {
    WARRIOR = "Warrior", DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", DEATHKNIGHT = "Death knight", MONK = "Monk",
}

local function classSpecNames(className)
    if not Bistooltip_classes then return {} end
    for _, cl in ipairs(Bistooltip_classes) do
        if cl.name == className then return cl.specs or {} end
    end
    return {}
end

-- Read a talent tab's (name, pointsSpent) defensively across API signatures.
local function readTab(tab, group)
    local ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab, false, false, group)
    if not ok then
        ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab)
        if not ok then return nil, nil end
    end
    if type(a) == "string" then
        return a, tonumber(c) -- classic: name, icon, pointsSpent
    elseif type(b) == "string" then
        return b, tonumber(e) -- alt: id, name, desc, icon, pointsSpent
    end
    return nil, nil
end

local function specsForTab(className, tabName)
    local tl = (tabName or ""):lower()
    local out = {}
    for _, sp in ipairs(classSpecNames(className)) do
        local sl = sp:lower()
        if sl == tl then
            table.insert(out, sp)
        elseif tl:find("feral", 1, true) and sl:find("feral", 1, true) then
            table.insert(out, sp)
        end
    end
    return out
end

function BistooltipAddon:refreshPlayerSpecs()
    local _, classFile = UnitClass("player")
    local className = CLASS_MAP[classFile or ""]
    BistooltipAddon.playerClassName = className

    local specs = {}
    if className then
        local groups = 1
        if GetNumTalentGroups then
            local ok, n = pcall(GetNumTalentGroups)
            if ok and tonumber(n) then groups = n end
        end
        local numTabs = (GetNumTalentTabs and GetNumTalentTabs()) or 3
        for g = 1, groups do
            local bestName, bestPts = nil, 0
            for tab = 1, numTabs do
                local name, pts = readTab(tab, g)
                if name and pts and pts > bestPts then
                    bestPts = pts
                    bestName = name
                end
            end
            if bestName then
                for _, sp in ipairs(specsForTab(className, bestName)) do
                    specs[sp] = true
                end
            end
        end
    end
    BistooltipAddon.playerSpecs = specs
end

function BistooltipAddon:initSpec()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    if pcall(f.RegisterEvent, f, "PLAYER_TALENT_UPDATE") then end
    if pcall(f.RegisterEvent, f, "CHARACTER_POINTS_CHANGED") then end
    if pcall(f.RegisterEvent, f, "ACTIVE_TALENT_GROUP_CHANGED") then end
    f:SetScript("OnEvent", function() BistooltipAddon:refreshPlayerSpecs() end)
    BistooltipAddon:refreshPlayerSpecs()
end
