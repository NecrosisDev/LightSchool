-- The Light School section of Settings > Mod Settings. Each row writes one field of config, so the
-- rest of the mod keeps reading config; config.lua's values are the rows' defaults.
local config = require("config")

local COLORS = {
    ["Cool white"] = { 0.85, 0.92, 1.0 },
    ["Warm white"] = { 1.0, 0.86, 0.66 },
    ["Pale blue"] = { 0.6, 0.78, 1.0 },
    ["Gold"] = { 1.0, 0.78, 0.4 },
}
local COLOR_NAMES = { "Cool white", "Warm white", "Pale blue", "Gold" }

local function number_row(key, label, target, field, min, max, step)
    return {
        row = { key = key, label = label, type = "number", default = target[field], min = min, max = max, step = step },
        store = function(value) target[field] = value end,
    }
end

local ROWS = {
    {
        row = { key = "needs_binding", label = "Held powers need a binding", type = "toggle", default = config.needs_binding },
        store = function(value) config.needs_binding = value end,
    },
    {
        row = { key = "orb_color", label = "Light Orb colour", type = "choice", default = "Cool white", choices = COLOR_NAMES },
        store = function(value) config.orb.color = COLORS[value] or config.orb.color end,
    },
    number_row("orb_focus", "Light Orb focus held", config.orb, "focus", 0, 0.5, 0.01),
    number_row("orb_range", "Light Orb range (cm)", config.orb, "range", 500, 5000, 100),
    number_row("orb_intensity", "Light Orb brightness", config.orb, "intensity", 0.5, 8, 0.5),
    number_row("orb_up", "Light Orb height (cm)", config.orb, "up", -50, 200, 10),
    number_row("orb_forward", "Light Orb ahead/behind (cm)", config.orb, "forward", -150, 150, 10),
    number_row("orb_right", "Light Orb to the side (cm)", config.orb, "right", -150, 150, 10),
    number_row("orb_smoothing", "Light Orb drift (seconds)", config.orb, "smoothing", 0, 2, 0.05),
    number_row("orb_bob", "Light Orb sway (cm)", config.orb, "bob", 0, 30, 1),
    number_row("orb_glow", "Light Orb glow size (cm)", config.orb, "glow", 2, 20, 1),
    number_row("kindle_focus", "Kindle focus held", config.kindle, "focus", 0, 0.5, 0.01),
    number_row("snuff_focus", "Snuff focus held", config.snuff, "focus", 0, 0.5, 0.01),
    number_row("flare_focus", "Flare focus cost", config.flare, "focus", 0, 0.5, 0.01),
    number_row("flare_intensity", "Flare brightness", config.flare, "intensity", 1, 8, 0.5),
    number_row("flare_recover", "Flare focus returns after (s)", config.flare, "recover", 1, 30, 1),
    number_row("sanctuary_focus", "Sanctuary focus held", config.sanctuary, "focus", 0, 0.5, 0.01),
    number_row("sanctuary_radius", "Sanctuary reach (cm)", config.sanctuary, "radius", 200, 2000, 50),
    number_row("beacon_focus", "Beacon focus held", config.beacon, "focus", 0, 0.5, 0.01),
    number_row("beacon_range", "Beacon range (cm)", config.beacon, "range", 500, 5000, 100),
}

local page = {}

-- Declares the section and loads the active profile's values; call once while loading.
function page.define()
    if not (settings and api.has_capability("ui.settings")) then
        return
    end
    local rows = {}
    for _, entry in ipairs(ROWS) do
        rows[#rows + 1] = entry.row
    end
    settings.define("Light School", rows)
    for _, entry in ipairs(ROWS) do
        local value = settings.get(entry.row.key)
        if value ~= nil then
            entry.store(value)
        end
    end
end

-- Stores one changed value; true when the key is one of ours.
function page.changed(key, value)
    for _, entry in ipairs(ROWS) do
        if entry.row.key == key then
            entry.store(value)
            return true
        end
    end
    return false
end

return page
