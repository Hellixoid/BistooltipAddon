-- Talent-based spec detection. WoW Forever allows two talent groups (dual spec);
-- a group's spec is the talent tab with the most points spent. Druid's single
-- "Feral Combat" tree maps to both Feral DPS and Feral Tank.
BistooltipAddon = BistooltipAddon or {}

local CLASS_MAP = {
    WARRIOR = "Warrior", DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", DEATHKNIGHT = "Death knight", MONK = "Monk",
}

-- WoW Forever exposes talents through the modern C_Traits system as a single
-- trait tree whose nodes are laid out in the classic three panes (left -> right
-- in canonical talent-tree order). These are the pane names per class, in that
-- left-to-right order; they are matched to the data's spec names via
-- specsForTab (so Druid's single "Feral" pane maps to Feral DPS + Feral Tank).
local PANE_NAMES = {
    Warrior = { "Arms", "Fury", "Protection" },
    Paladin = { "Holy", "Protection", "Retribution" },
    Hunter = { "Beast Mastery", "Marksmanship", "Survival" },
    Rogue = { "Assassination", "Combat", "Subtlety" },
    Priest = { "Discipline", "Holy", "Shadow" },
    ["Death knight"] = { "Blood", "Frost", "Unholy" },
    Shaman = { "Elemental", "Enhancement", "Restoration" },
    Mage = { "Arcane", "Fire", "Frost" },
    Warlock = { "Affliction", "Demonology", "Destruction" },
    Druid = { "Balance", "Feral", "Restoration" },
    Monk = { "Brewmaster", "Mistweaver", "Windwalker" },
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

-- WoW Forever (C_Traits): find which talent pane the given config has the most
-- points in, and return its canonical pane name (nil if none/ambiguous tie).
local function dominantPane(configID, panes)
    local T = C_Traits
    local oki, info = pcall(T.GetConfigInfo, configID)
    local treeIDs = oki and info and info.treeIDs
    if not treeIDs then return nil end

    local nodes = {}
    for _, treeID in ipairs(treeIDs) do
        local okn, nodeIDs = pcall(T.GetTreeNodes, treeID)
        if okn and nodeIDs then
            for _, nid in ipairs(nodeIDs) do
                local okni, ni = pcall(T.GetNodeInfo, configID, nid)
                if okni and ni and ni.posX then
                    nodes[#nodes + 1] = { x = ni.posX, r = ni.activeRank or ni.ranksPurchased or 0 }
                end
            end
        end
    end
    if #nodes == 0 then return nil end
    table.sort(nodes, function(a, b) return a.x < b.x end)

    -- distinct x positions (over all nodes, so empty panes still bound correctly)
    local xs = {}
    for _, n in ipairs(nodes) do
        if xs[#xs] ~= n.x then xs[#xs + 1] = n.x end
    end

    -- the (#panes - 1) largest horizontal gaps are the boundaries between panes
    local N = #panes
    local gaps = {}
    for i = 2, #xs do gaps[#gaps + 1] = { gap = xs[i] - xs[i - 1], at = xs[i] } end
    table.sort(gaps, function(a, b) return a.gap > b.gap end)
    local bounds = {}
    for i = 1, math.min(N - 1, #gaps) do bounds[#bounds + 1] = gaps[i].at end
    table.sort(bounds)

    local pts = {}
    for i = 1, N do pts[i] = 0 end
    for _, n in ipairs(nodes) do
        if n.r > 0 then
            local idx = 1
            for _, b in ipairs(bounds) do
                if n.x >= b then idx = idx + 1 end
            end
            pts[idx] = (pts[idx] or 0) + n.r
        end
    end

    local best, bestI, second = 0, nil, 0
    for i = 1, N do
        if pts[i] > best then
            second = best; best = pts[i]; bestI = i
        elseif pts[i] > second then
            second = pts[i]
        end
    end
    if not bestI or best == 0 or best == second then return nil end  -- none or tie
    return panes[bestI]
end

-- WoW Forever / modern Mainline engine: talents live in C_Traits. Reads the
-- dominant pane of each talent group. Returns true if it detected anything.
local function detectViaTraits(className, specs)
    local SI, T = C_SpecializationInfo, C_Traits
    if not (SI and T and SI.GetCombatConfigIDForSpecGroup and T.GetConfigInfo) then return false end
    local panes = PANE_NAMES[className]
    if not panes then return false end
    local found = false
    for g = 1, 2 do
        local okc, configID = pcall(SI.GetCombatConfigIDForSpecGroup, g)
        if okc and configID then
            local paneName = dominantPane(configID, panes)
            if paneName then
                if BistooltipDebugSpec then print("|cff33ff99BisSpec|r group", g, "pane=", paneName) end
                for _, sp in ipairs(specsForTab(className, paneName)) do
                    specs[sp] = true
                    found = true
                end
            end
        end
    end
    return found
end

-- Modern engine (MoP-era) specialization API, for servers that expose it.
-- Returns true if it detected anything.
local function detectViaSpecialization(className, specs)
    if not (GetSpecialization and GetSpecializationInfo) then return false end
    local groups = 1
    if GetNumSpecGroups then
        local ok, n = pcall(GetNumSpecGroups)
        if ok and tonumber(n) then groups = n end
    end
    local found = false
    for g = 1, groups do
        local ok, idx = pcall(GetSpecialization, false, false, g)
        if ok and idx then
            local oki, _, specName = pcall(GetSpecializationInfo, idx)
            if oki and type(specName) == "string" then
                if BistooltipDebugSpec then print("|cff33ff99BisSpec|r group", g, "name=", specName) end
                for _, sp in ipairs(specsForTab(className, specName)) do
                    specs[sp] = true
                    found = true
                end
            end
        end
    end
    return found
end

-- Legacy talent-tree detection (pre-MoP clients): a group's spec is the tab
-- with the most points spent.
local function detectViaTalents(className, specs)
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

function BistooltipAddon:refreshPlayerSpecs()
    local _, classFile = UnitClass("player")
    local className = CLASS_MAP[classFile or ""]
    BistooltipAddon.playerClassName = className

    local specs = {}
    if className then
        if not detectViaTraits(className, specs)
            and not detectViaSpecialization(className, specs) then
            detectViaTalents(className, specs)
        end
    end
    if BistooltipDebugSpec then
        local list = {}
        for sp in pairs(specs) do list[#list + 1] = sp end
        print("|cff33ff99BisSpec|r class=", tostring(className), "specs=", table.concat(list, ", "))
    end
    BistooltipAddon.playerSpecs = specs
end

-- One-shot diagnostic: run `/run BistooltipDumpTraits()` in-game and paste the
-- output. Dumps the WoW Forever C_Traits structure (config/tree ids, points per
-- tree, and the posX layout of spent nodes) so the real spec detection and the
-- pane->spec-name mapping can be built from actual data.
function BistooltipDumpTraits()
    local SI, T = C_SpecializationInfo, C_Traits
    print("|cff33ff99BisTraits|r C_SpecializationInfo=" .. tostring(SI ~= nil)
        .. " C_Traits=" .. tostring(T ~= nil))
    if not (SI and T) then return end
    local _, active = pcall(SI.GetActiveSpecGroup)
    print("  activeSpecGroup=" .. tostring(active))
    for g = 1, 2 do
        local okc, configID = pcall(SI.GetCombatConfigIDForSpecGroup, g)
        if not okc then configID = nil end
        print(string.format("  group %d configID=%s", g, tostring(configID)))
        if configID then
            local oki, info = pcall(T.GetConfigInfo, configID)
            local treeIDs = oki and info and info.treeIDs
            if not treeIDs then
                print("    no treeIDs (" .. tostring(oki and "info ok" or "GetConfigInfo failed") .. ")")
            else
                for _, treeID in ipairs(treeIDs) do
                    local okn, nodeIDs = pcall(T.GetTreeNodes, treeID)
                    nodeIDs = (okn and nodeIDs) or {}
                    local total, ranked = 0, {}
                    for _, nid in ipairs(nodeIDs) do
                        local okni, ni = pcall(T.GetNodeInfo, configID, nid)
                        if okni and ni then
                            local r = ni.activeRank or ni.ranksPurchased or 0
                            if r > 0 then
                                total = total + r
                                ranked[#ranked + 1] = { x = ni.posX or 0, r = r }
                            end
                        end
                    end
                    table.sort(ranked, function(a, b) return a.x < b.x end)
                    print(string.format("    tree %s: %d nodes, %d points spent",
                        tostring(treeID), #nodeIDs, total))
                    local line = ""
                    for _, n in ipairs(ranked) do
                        line = line .. n.x .. ":" .. n.r .. "  "
                        if #line > 90 then print("      " .. line); line = "" end
                    end
                    if line ~= "" then print("      " .. line) end
                end
            end
        end
    end
end

function BistooltipAddon:initSpec()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    if pcall(f.RegisterEvent, f, "PLAYER_TALENT_UPDATE") then end
    if pcall(f.RegisterEvent, f, "CHARACTER_POINTS_CHANGED") then end
    if pcall(f.RegisterEvent, f, "ACTIVE_TALENT_GROUP_CHANGED") then end
    if pcall(f.RegisterEvent, f, "TRAIT_CONFIG_UPDATED") then end
    if pcall(f.RegisterEvent, f, "ACTIVE_COMBAT_CONFIG_CHANGED") then end
    f:SetScript("OnEvent", function() BistooltipAddon:refreshPlayerSpecs() end)
    BistooltipAddon:refreshPlayerSpecs()
end
