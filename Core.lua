BistooltipAddon = BistooltipAddon or {}
BistooltipAddon.AddonNameAndVersion = "Bis-Tooltip v10.007"

Bistooltip_char_equipment = {}

local function createEquipmentWatcher()
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnEvent", frame.Show)
    frame:RegisterEvent("BAG_UPDATE")

    local flag = false
    frame:SetScript("OnUpdate", function(self)
        self:Hide()
        if flag == false then
            flag = true
            local collection = {}
            for bag = 0, NUM_BAG_SLOTS do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    local itemID = C_Container.GetContainerItemID(bag, slot)
                    if itemID ~= nil then
                        collection[itemID] = 1
                    end
                end
            end
            for i = 0, 18 do
                local itemID = GetInventoryItemID("player", i)
                if itemID ~= nil then
                    collection[itemID] = 2
                end
            end
            Bistooltip_char_equipment = collection
            flag = false
        end
    end)
end

local initialized = false
local function init()
    if initialized then return end
    initialized = true
    BistooltipAddon:initDb()
    createEquipmentWatcher()
    BistooltipAddon:initConfig()
    BistooltipAddon:addMapIcon()
    BistooltipAddon:initSpec()
    BistooltipAddon:initBislists()
    BistooltipAddon:initBisTooltip()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", init)
