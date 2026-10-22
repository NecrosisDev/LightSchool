-- The Light school: Light Orb, Kindle, Snuff, Radiance, Beacon, Guiding Light and Searing Beacon are held powers (cast to start,
-- cast again to release); Flare and Glare are instant casts. Costs follow the game's thaumaturgy rules
-- (rules.lua). Beacon is placed once when it starts, not on every sync, so it stays where it was cast.
local config = require("config")
local rules = require("rules")
local effects = require("effects")
local feedback = require("feedback")
local settings_page = require("settings_page")

settings_page.define()

-- Character creation's first-skill wheel is not a session, so teaching cannot reach it; the runtime
-- can mark the Light school clickable there instead (0.28.0-r24).
local LIGHT_SCHOOL = 5
if powers.open_school then
    pcall(powers.open_school, LIGHT_SCHOOL)
end

local HELD = { "orb", "kindle", "snuff", "radiance", "beacon", "guide", "searing" }
local OPPOSITE = { kindle = "snuff", snuff = "kindle" }
local INSTANT = { flare = effects.flare, glare = effects.glare }

local held = { orb = false, kindle = false, snuff = false, radiance = false, beacon = false, guide = false, searing = false }
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
    effects.radiance(held.radiance)
    effects.guide(held.guide)
    effects.searing(held.searing)
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

-- Re-reads Insight (a detailed character read, the costliest call here) and re-applies the held
-- effects when it changed. Only from timers.
local function refresh_potency()
    local changed
    if profile and profile.scope then
        changed = profile.scope("light.potency", rules.refresh_potency)
    else
        changed = rules.refresh_potency()
    end
    if changed then
        sync(powers.caster())
    end
end

local event_power_of = {}
for _, name in ipairs(HELD) do
    event_power_of[name] = config[name].power
end
local instant_of = {}
for name in pairs(INSTANT) do
    event_power_of[name] = config[name].power
    instant_of[config[name].power] = name
end

local function refuse(name, why)
    log.info(name .. " not cast: " .. why)
    feedback.cast(event_power_of[name], false)
end

local function toggle(name, caster)
    if held[name] then
        held[name] = false
        if name == "beacon" then
            effects.beacon(false)
            -- Searing Beacon works through the Beacon's light, so it goes out with it.
            held.searing = false
        end
        feedback.sound("release")
        log.info(name .. " released")
        return
    end
    if OPPOSITE[name] then
        held[OPPOSITE[name]] = false
    end
    local why = rules.held_refusal(name, caster, held_count())
    if not why and name == "searing" and not effects.beacon_standing() then
        why = "it needs a standing Beacon"
    end
    if not why and name == "beacon" and not effects.beacon(true) then
        why = effects.beacon_available() and "the runtime refused the light or the player's position is unknown" or "this runtime has no fixed-position lights (needs 0.28.0)"
    end
    if why then
        refuse(name, why)
        return
    end
    held[name] = true
    -- Like the game's continuous powers (0x17aad0): the cost is held off the ceiling and also drained
    -- from current focus once.
    feedback.spend(rules.held_cost(name, caster))
    feedback.cast(event_power_of[name], true)
    log.info(name .. " started")
end

-- Iteration halves a repeated instant cast; the game's record of the last cast covers every school.
local function repeated(power, caster)
    if caster and caster.last_power ~= nil then
        return caster.last_power == power
    end
    return last_light_power == power
end

-- Flare and Glare: instant casts.
local function cast_instant(name, caster)
    local power = config[name].power
    local cost = rules.instant_cost(name, caster, repeated(power, caster))
    local why = rules.instant_refusal(cost, caster)
    if why then
        refuse(name, why)
        return
    end
    INSTANT[name]()
    feedback.flare(power)
    -- An instant cast spends current focus as the game's do. Runtimes without powers.spend_focus
    -- cannot, so there the cost is held off the ceiling for a while instead.
    if feedback.spend(cost) then
        return
    end
    flare_hold = flare_hold + cost
    timers.after(config.flare.recover, function()
        flare_hold = math.max(0, flare_hold - cost)
        sync(powers.caster())
    end)
end

events.on("power.cast", function(event)
    local caster = powers.caster()
    if instant_of[event.power] then
        cast_instant(instant_of[event.power], caster)
    elseif by_power[event.power] then
        toggle(by_power[event.power], caster)
    else
        return
    end
    last_light_power = event.power
    sync(caster)
    timers.after(0, refresh_potency)
end)

-- Companions: another mod (Endless) asks an NPC to cast through a game script line,
-- LuaEvent(LightCastGlare, <caster record id>) or LuaEvent(LightCastGuiding, <caster record id>).
-- NPC changes are staged from timer callbacks, so the cast runs from one.
local NPC_CASTS = { LightCastGlare = "glare", LightCastGuiding = "guide" }
-- Or, from another addon: addons.send("com.necrosis.light-orb", "light.cast", {caster = <a
-- characters.read row or table with its handle, or a record id>, power = "glare" | "guide"}).
if addons and addons.on then
    addons.on("light.cast", function(value, from_id)
        if type(value) ~= "table" or (value.power ~= "glare" and value.power ~= "guide") then
            log.warn("light.cast from " .. tostring(from_id) .. " needs {caster, power = \"glare\" or \"guide\"}")
            return
        end
        local caster = type(value.caster) == "table" and { handle = value.caster.handle } or value.caster
        timers.after(0, function()
            if effects.npc_cast(caster, value.power) then
                feedback.sound(value.power == "glare" and "flare" or "start", config.companions.volume)
            end
        end)
    end)
end
if api.has_capability("events.script") then
    events.on("script.event", function(event)
        local kind = NPC_CASTS[event.name]
        if not kind then
            return
        end
        local caster = math.tointeger(event.number)
        timers.after(0, function()
            if effects.npc_cast(caster, kind) then
                feedback.sound(kind == "glare" and "flare" or "start", config.companions.volume)
            end
        end)
    end)
end

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
        held.searing = false
        effects.beacon(false)
    end
    if event.phase == "menu" then
        for _, name in ipairs(HELD) do
            held[name] = false
        end
        last_light_power = nil
    end
    -- The spell book's school wheel opens only schools the character knows a power in (0x1dd440), and
    -- the game seeds only Mind's Sense Minds. Knowing the Light page's root (Flare) makes the page selectable.
    if event.phase == "session" and powers.teach then
        timers.after(0, function()
            pcall(powers.teach, config.flare.power)
        end)
    end
    -- Insight strengthens the held effects: read at the start, after each cast, and every
    -- potency_interval s while a Light power is held; nothing is read while none is.
    if event.phase == "session" then
        timers.after(0, refresh_potency)
        timers.every(config.potency_interval, function()
            if held_count() > 0 then
                refresh_potency()
            end
        end)
    end
    sync(nil)
end)
