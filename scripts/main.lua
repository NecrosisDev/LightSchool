-- The Light school: Light Orb, Kindle, Snuff, Sanctuary and Beacon are held powers (cast to start,
-- cast again to release); Flare is an instant cast. Costs follow the game's thaumaturgy rules
-- (rules.lua). Beacon is placed once when it starts, not on every sync, so it stays where it was cast.
local config = require("config")
local rules = require("rules")
local effects = require("effects")
local feedback = require("feedback")
local settings_page = require("settings_page")

settings_page.define()

local HELD = { "orb", "kindle", "snuff", "sanctuary", "beacon" }
local OPPOSITE = { kindle = "snuff", snuff = "kindle" }

local held = { orb = false, kindle = false, snuff = false, sanctuary = false, beacon = false }
local by_power = {}
for _, name in ipairs(HELD) do
    by_power[config[name].power] = name
end
local flare_hold = 0
-- Used for Iteration only when the runtime does not report the game's own last cast.
local last_light_power = nil

local function held_count()
    local count = 0
    for _, name in ipairs(HELD) do
        if held[name] then
            count = count + 1
        end
    end
    return count
end

local function sync(caster)
    effects.orb(held.orb)
    effects.torches((held.kindle and "kindle") or (held.snuff and "snuff") or nil)
    effects.sanctuary(held.sanctuary)
    local total = flare_hold
    for _, name in ipairs(HELD) do
        if held[name] then
            total = total + rules.held_cost(name, caster)
        end
    end
    powers.hold_focus(math.min(total, config.max_hold))
    -- Where the runtime can, our held powers also occupy the game's own Continuity bindings.
    if powers.hold_bindings then
        pcall(powers.hold_bindings, held_count())
    end
end

local function refuse(name, why)
    log.info(name .. " not cast: " .. why)
    feedback.sound("fail")
end

local function toggle(name, caster)
    if held[name] then
        held[name] = false
        if name == "beacon" then
            effects.beacon(false)
        end
        feedback.sound("release")
        log.info(name .. " released")
        return
    end
    if OPPOSITE[name] then
        held[OPPOSITE[name]] = false
    end
    local why = rules.held_refusal(name, caster, held_count())
    if not why and name == "beacon" and not effects.beacon(true) then
        why = effects.beacon_available() and "the runtime refused the light or the player's position is unknown" or "this runtime has no fixed-position lights (needs 0.28.0)"
    end
    if why then
        refuse(name, why)
        return
    end
    held[name] = true
    feedback.sound("start")
    feedback.gesture("start")
    log.info(name .. " started")
end

-- Iteration halves a repeated instant cast; the game's record of the last cast covers every school.
local function repeated_flare(caster)
    if caster and caster.last_power ~= nil then
        return caster.last_power == config.flare.power
    end
    return last_light_power == config.flare.power
end

local function cast_flare(caster)
    local cost = rules.instant_cost("flare", caster, repeated_flare(caster))
    local why = rules.instant_refusal(cost, caster)
    if why then
        refuse("flare", why)
        return
    end
    flare_hold = flare_hold + cost
    effects.flare()
    feedback.sound("flare")
    feedback.gesture("flare")
    timers.after(config.flare.recover, function()
        flare_hold = math.max(0, flare_hold - cost)
        sync(nil)
    end)
end

events.on("power.cast", function(event)
    local caster = powers.caster()
    if event.power == config.flare.power then
        cast_flare(caster)
    elseif by_power[event.power] then
        toggle(by_power[event.power], caster)
    else
        return
    end
    last_light_power = event.power
    sync(caster)
end)

if api.has_capability("ui.settings") then
    events.on("settings.changed", function(event)
        if settings_page.changed(event.key, event.value) then
            sync(powers.caster())
        end
    end)
end

-- Pending flare returns are timers too, so their cost is given back here. A beacon belongs to the
-- level it was placed in, so any phase change releases it.
events.on("runtime.phase", function(event)
    effects.timers_lost()
    flare_hold = 0
    if held.beacon then
        held.beacon = false
        effects.beacon(false)
    end
    if event.phase == "menu" then
        for _, name in ipairs(HELD) do
            held[name] = false
        end
        last_light_power = nil
    end
    sync(nil)
end)
