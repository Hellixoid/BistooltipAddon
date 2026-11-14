BistooltipAddon = BistooltipAddon or {}

local sources = { wh = "wh", wowtbc = "wowtbc" }

Bistooltip_source_to_url = {
    ["wh"] = "wowhead.com/forever",
    ["wowtbc"] = "wowtbc.gg/warcraftforever",
}
Bistooltip_source_to_name = {
    ["wh"] = "Wowhead",
    ["wowtbc"] = "wowtbc.gg",
}

local icon_name = "BisTooltipIcon"
local icon_registered = false

local function enableDataSource(data_source)
    if data_source == sources.wowtbc then
        Bistooltip_bislists = Bistooltip_wowtbc_bislists
        Bistooltip_items = Bistooltip_wowtbc_items
        Bistooltip_classes = Bistooltip_wowtbc_classes
        Bistooltip_phases = Bistooltip_wowtbc_phases
    else
        Bistooltip_bislists = Bistooltip_wh_bislists
        Bistooltip_items = Bistooltip_wh_items
        Bistooltip_classes = Bistooltip_wh_classes
        Bistooltip_phases = Bistooltip_wh_phases
    end
    Bistooltip_phases_string = ""
    if Bistooltip_phases then
        for i, phase in ipairs(Bistooltip_phases) do
            if i ~= 1 then Bistooltip_phases_string = Bistooltip_phases_string .. "/" end
            Bistooltip_phases_string = Bistooltip_phases_string .. phase
        end
    end
end

function BistooltipAddon:changeDataSource(data_source)
    BistooltipAddon.db.char.data_source = data_source
    enableDataSource(data_source)
    if BistooltipAddon.refreshPlayerSpecs then BistooltipAddon:refreshPlayerSpecs() end
    BistooltipAddon:initBislists()
    BistooltipAddon:reloadData()
end

function BistooltipAddon:addMapIcon()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
    if not LDB then return end
    if not icon_registered then
        local obj = LDB:NewDataObject(icon_name, {
            type = "launcher",
            text = icon_name,
            icon = "interface/icons/inv_weapon_glave_01.blp",
            OnClick = function(_, button)
                if button == "RightButton" then
                    BistooltipAddon:createMainFrame()
                    if BistooltipAddon.openSettings then BistooltipAddon:openSettings() end
                else
                    BistooltipAddon:createMainFrame()
                end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine(BistooltipAddon.AddonNameAndVersion)
                tt:AddLine("|cffffff00Left click|r to open the BiS lists window")
                tt:AddLine("|cffffff00Right click|r to open settings")
            end,
        })
        if LDBIcon then
            LDBIcon:Register(icon_name, obj, BistooltipAddon.db.char.minimap)
            icon_registered = true
        end
    end
    if LDBIcon then
        if BistooltipAddon.db.char.minimap_icon then LDBIcon:Show(icon_name) else LDBIcon:Hide(icon_name) end
    end
end

function BistooltipAddon:setMinimapIcon(show)
    BistooltipAddon.db.char.minimap_icon = show
    BistooltipAddon.db.char.minimap.hide = not show
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
    if LDBIcon then
        if show then LDBIcon:Show(icon_name) else LDBIcon:Hide(icon_name) end
    end
end

function BistooltipAddon:initConfig()
    local ds = BistooltipAddon.db.char.data_source
    if ds == nil then
        ds = sources.wowtbc
        BistooltipAddon.db.char.data_source = ds
        print("|cffC79C6EBis-Tooltip|r: data source set to wowtbc.gg. Open with |cffffff00/bistooltip|r and use the gear to change it.")
    end
    Bistooltip_bislists = {}
    Bistooltip_items = {}
    enableDataSource(ds)
end
