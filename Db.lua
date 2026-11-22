-- Saved-variables layer (replaces AceDB-3.0). Per-character settings in BisTooltipDB.
BistooltipAddon = BistooltipAddon or {}

local defaults = {
    class_index = 1,
    spec_index = 1,
    phase_index = 1,
    data_source = nil,
    minimap = { hide = false },
    minimap_icon = true,
    filter_class_names = false,
    tooltip_with_ctrl = false,
    highlight_mode = "class", -- "none" | "class" | "spec"
    filter_mode = "none",     -- "none" | "class" | "spec" (hide non-matching specs)
    bis_list_window = nil,
    version = 10.0,
}

local function deepcopy(t)
    local r = {}
    for k, v in pairs(t) do
        r[k] = (type(v) == "table") and deepcopy(v) or v
    end
    return r
end

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = deepcopy(v) else applyDefaults(dst[k], v) end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function BistooltipAddon:initDb()
    BisTooltipDB = BisTooltipDB or {}
    local key = (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
    BisTooltipDB[key] = BisTooltipDB[key] or {}
    local char = BisTooltipDB[key]

    -- drop removed settings from older versions
    char.filter_specs = nil
    char.highlight_spec = nil

    applyDefaults(char, defaults)
    self.db = { char = char }
end
