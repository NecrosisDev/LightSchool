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

local function number_row(key, label, help, target, field, min, max, step, percent)
    return {
        row = { key = key, label = label, help = help, type = "number", default = target[field], min = min, max = max, step = step,
                format = percent and "percent" or nil },
        store = function(value) target[field] = value end,
    }
end

local function header(label)
    return { header = label }
end

local FOCUS_HELP = "Share of your focus ceiling held back while %s is held"

local ROWS = {
    header("General"),
    {
        row = { key = "needs_binding", label = "Continuity", type = "toggle", default = config.needs_binding,
                help = "Each held Light power uses a free Continuity binding, like the game's own continuous powers" },
        store = function(value) config.needs_binding = value end,
    },
    header("Light Orb"),
    {
        row = { key = "orb_color", label = "Colour", type = "choice", default = "Cool white", choices = COLOR_NAMES,
                help = "Colour of the Light Orb's light and glow" },
        store = function(value) config.orb.color = COLORS[value] or config.orb.color end,
    },
    number_row("orb_focus", "Focus", FOCUS_HELP:format("the Light Orb"), config.orb, "focus", 0, 0.5, 0.01, true),
    number_row("orb_intensity", "Brightness", "Light Orb brightness (the game's own player light uses 2)", config.orb, "intensity", 0.5, 8, 0.5),
    number_row("orb_range", "Reach", "How far the Light Orb's light reaches, in cm (a torch reaches about 1500)", config.orb, "range", 500, 5000, 100),
    number_row("orb_up", "Height", "How far above your head the Light Orb floats, in cm", config.orb, "up", -50, 200, 10),
    number_row("orb_forward", "Ahead", "How far ahead of you the Light Orb floats, in cm; negative is behind", config.orb, "forward", -150, 150, 10),
    number_row("orb_right", "Side", "How far to your side the Light Orb floats, in cm; negative is left", config.orb, "right", -150, 150, 10),
    number_row("orb_smoothing", "Drift", "Seconds the Light Orb takes to catch up when you move; 0 keeps it fixed to you", config.orb, "smoothing", 0, 2, 0.05),
    number_row("orb_bob", "Bob", "How far the Light Orb slowly bobs up and down, in cm", config.orb, "bob", 0, 30, 1),
    number_row("orb_glow", "Glow", "Size of the visible glowing ball, in cm", config.orb, "glow", 2, 20, 1),
    header("Kindle"),
    number_row("kindle_focus", "Focus", FOCUS_HELP:format("Kindle"), config.kindle, "focus", 0, 0.5, 0.01, true),
    header("Snuff"),
    number_row("snuff_focus", "Focus", FOCUS_HELP:format("Snuff"), config.snuff, "focus", 0, 0.5, 0.01, true),
    header("Flare"),
    number_row("flare_focus", "Focus", "Share of your focus ceiling a Flare costs; Iteration halves it when Flare was your last cast", config.flare, "focus", 0, 0.5, 0.01, true),
    number_row("flare_intensity", "Brightness", "Brightness of the Flare burst at its peak (the game's own player light uses 2)", config.flare, "intensity", 1, 8, 0.5),
    number_row("flare_recover", "Refund", "Seconds before Flare's focus comes back", config.flare, "recover", 1, 30, 1),
    header("Radiance"),
    number_row("radiance_focus", "Focus", FOCUS_HELP:format("Radiance"), config.radiance, "focus", 0, 0.5, 0.01, true),
    number_row("radiance_radius", "Reach", "How close foes must be for Radiance to blind them, in cm", config.radiance, "radius", 100, 1000, 25),
    header("Beacon"),
    number_row("beacon_focus", "Focus", "Share of your focus ceiling held back while a Beacon stands", config.beacon, "focus", 0, 0.5, 0.01, true),
    number_row("beacon_range", "Reach", "How far a Beacon's light reaches, in cm (a torch reaches about 1500)", config.beacon, "range", 500, 5000, 100),
    header("Guiding Light"),
    number_row("guide_focus", "Focus", FOCUS_HELP:format("Guiding Light"), config.guide, "focus", 0, 0.5, 0.01, true),
    number_row("guide_radius", "Reach", "How close allies must be for Guiding Light to sharpen them, in cm", config.guide, "radius", 200, 2000, 50),
}

local page = {}

-- Declares the section and loads the active profile's values; call once while loading.
function page.define()
    if not (settings and api.has_capability("ui.settings")) then
        return
    end
    local rows, plain = {}, {}   -- plain: without sub-headers or % display, for a runtime before 0.28.0-r42
    for _, entry in ipairs(ROWS) do
        if entry.header then
            rows[#rows + 1] = { type = "header", label = entry.header }
        else
            rows[#rows + 1] = entry.row
            local copy = {}
            for k, v in pairs(entry.row) do
                if k ~= "format" then copy[k] = v end
            end
            plain[#plain + 1] = copy
        end
    end
    if not pcall(settings.define, "Light School", rows) then
        settings.define("Light School", plain)
    end
    for _, entry in ipairs(ROWS) do
        if entry.row then
            local value = settings.get(entry.row.key)
            if value ~= nil then
                entry.store(value)
            end
        end
    end
end

-- Stores one changed value; true when the key is one of ours.
function page.changed(key, value)
    for _, entry in ipairs(ROWS) do
        if entry.row and entry.row.key == key then
            entry.store(value)
            return true
        end
    end
    return false
end

return page
