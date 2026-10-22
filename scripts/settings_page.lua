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

local function number_row(key, label, help, target, field, min, max, step)
    return {
        row = { key = key, label = label, help = help, type = "number", default = target[field], min = min, max = max, step = step },
        store = function(value) target[field] = value end,
    }
end

local ROWS = {
    {
        row = { key = "needs_binding", label = "Binding rule", type = "toggle", default = config.needs_binding,
                help = "Held Light powers each need a free Continuity binding, like the game's own continuous powers" },
        store = function(value) config.needs_binding = value end,
    },
    {
        row = { key = "orb_color", label = "Orb colour", type = "choice", default = "Cool white", choices = COLOR_NAMES,
                help = "Colour of the Light Orb's light and glow" },
        store = function(value) config.orb.color = COLORS[value] or config.orb.color end,
    },
    number_row("orb_focus", "Orb focus", "Share of the focus ceiling held back while the Light Orb is lit", config.orb, "focus", 0, 0.5, 0.01),
    number_row("orb_range", "Orb range", "How far the Light Orb's light reaches, in cm (a torch reaches about 1500)", config.orb, "range", 500, 5000, 100),
    number_row("orb_intensity", "Orb brightness", "Light Orb brightness (the game's own player light uses 2)", config.orb, "intensity", 0.5, 8, 0.5),
    number_row("orb_up", "Orb height", "How far above your head the Light Orb floats, in cm", config.orb, "up", -50, 200, 10),
    number_row("orb_forward", "Orb forward", "How far ahead of you the Light Orb floats, in cm; negative is behind", config.orb, "forward", -150, 150, 10),
    number_row("orb_right", "Orb sideways", "How far to your side the Light Orb floats, in cm", config.orb, "right", -150, 150, 10),
    number_row("orb_smoothing", "Orb drift", "Seconds the Light Orb takes to catch up when you move; 0 keeps it fixed to you", config.orb, "smoothing", 0, 2, 0.05),
    number_row("orb_bob", "Orb sway", "How far the Light Orb slowly bobs up and down, in cm", config.orb, "bob", 0, 30, 1),
    number_row("orb_glow", "Orb glow", "Size of the visible glowing ball, in cm", config.orb, "glow", 2, 20, 1),
    number_row("kindle_focus", "Kindle focus", "Share of the focus ceiling held back while Kindle is held", config.kindle, "focus", 0, 0.5, 0.01),
    number_row("snuff_focus", "Snuff focus", "Share of the focus ceiling held back while Snuff is held", config.snuff, "focus", 0, 0.5, 0.01),
    number_row("flare_focus", "Flare focus", "Focus a Flare costs; Iteration halves it when Flare was your last cast", config.flare, "focus", 0, 0.5, 0.01),
    number_row("flare_intensity", "Flare brightness", "Brightness of the Flare burst at its peak", config.flare, "intensity", 1, 8, 0.5),
    number_row("flare_recover", "Flare recovery", "Seconds before a Flare's focus cost is returned", config.flare, "recover", 1, 30, 1),
    number_row("radiance_focus", "Radiance focus", "Share of the focus ceiling held back while Radiance is held", config.radiance, "focus", 0, 0.5, 0.01),
    number_row("radiance_radius", "Radiance reach", "How close foes must be for Radiance to blind them, in cm", config.radiance, "radius", 100, 1000, 25),
    number_row("beacon_focus", "Beacon focus", "Share of the focus ceiling held back while a Beacon stands", config.beacon, "focus", 0, 0.5, 0.01),
    number_row("beacon_range", "Beacon range", "How far a Beacon's light reaches, in cm", config.beacon, "range", 500, 5000, 100),
    number_row("guide_focus", "Guiding Light focus", "Share of the focus ceiling held back while Guiding Light is held",
        config.guide, "focus", 0, 0.5, 0.01),
    number_row("guide_radius", "Guiding Light reach", "How close allies must be for Guiding Light to sharpen them, in cm",
        config.guide, "radius", 200, 2000, 50),
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
