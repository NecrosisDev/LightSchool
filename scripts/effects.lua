-- What each Light power does in the world. Each effect is started and stopped by main.lua and keeps
-- only its own timer and light.
local config = require("config")

local effects = {}

-- Light Orb ------------------------------------------------------------------------------------

function effects.orb(on)
    if not on then
        lights.remove("orb")
        return
    end
    local orb = config.orb
    lights.set("orb", {
        color = orb.color,
        range = orb.range,
        intensity = orb.intensity,
        follow = { forward = orb.forward, right = orb.right, up = orb.up, smoothing = orb.smoothing, bob = orb.bob },
        -- Runtimes before 0.28.0-r10 ignore this field. The glow takes colours 0..1, the light 0..4.
        glow = {
            size = orb.glow,
            color = { math.min(orb.color[1], 1), math.min(orb.color[2], 1), math.min(orb.color[3], 1) },
        },
    })
end

-- Kindle and Snuff -----------------------------------------------------------------------------
-- The runtime stages one world write per callback and offers torch methods only on targets within
-- reach, so each tick acts on the first eligible torch it finds.

local torch_mode, torch_timer = nil, nil

local function torch_tick()
    if not (api.has_capability("world.read") and api.has_capability("world.devices")) then
        return
    end
    local scene = world.snapshot()
    if not scene then
        return
    end
    for _, object in ipairs(scene.objects) do
        if torch_mode == "kindle" and object.device_kind == "torch" and not object.lit and object.ignite then
            object:ignite()
            return
        elseif torch_mode == "snuff" and object.lit and object.extinguish then
            object:extinguish()
            return
        end
    end
end

-- mode is "kindle", "snuff" or nil.
function effects.torches(mode)
    torch_mode = mode
    if mode and not torch_timer then
        torch_timer = timers.every(config.torch_interval, torch_tick)
    elseif not mode and torch_timer then
        timers.cancel(torch_timer)
        torch_timer = nil
    end
end

-- Flare ----------------------------------------------------------------------------------------

local flare_timer, flare_started = nil, 0

-- pcall: if the runtime refuses the light (its per-addon limit, or a runtime older than 0.28.0 that
-- allows only 2), that should cost the flare, not the whole addon.
local function flare_light(strength)
    local flare = config.flare
    pcall(lights.set, "flare", {
        color = flare.color,
        range = flare.range,
        intensity = flare.intensity * strength,
        follow = { forward = flare.forward, up = flare.up, smoothing = 0 },
    })
end

local function flare_out()
    if flare_timer then
        timers.cancel(flare_timer)
        flare_timer = nil
    end
    lights.remove("flare")
end

local function flare_tick()
    local flare = config.flare
    local fading = timers.now() - flare_started - flare.burn
    if fading >= flare.fade then
        flare_out()
    elseif fading > 0 then
        flare_light(1 - fading / flare.fade)
    end
end

function effects.flare()
    flare_out()
    flare_light(1)
    flare_started = timers.now()
    flare_timer = timers.every(config.flare.fade_step, flare_tick)
end

-- Beacon ---------------------------------------------------------------------------------------
-- lights.place(name, spec) stands a light at spec.position (scene cm). The player's body centre in
-- the same space comes from a character snapshot.

local function player_position()
    local view
    if api.has_capability("characters.read") then
        view = characters.snapshot()
    elseif api.has_capability("characters.awareness") then
        view = characters.awareness()
    end
    for _, row in ipairs(view and view.characters or {}) do
        if row.is_player and row.position then
            return row.position
        end
    end
    return nil
end

function effects.beacon_available()
    return lights.place ~= nil
end

function effects.beacon(on)
    if not on then
        lights.remove("beacon")
        return true
    end
    local at = lights.place and player_position()
    if not at then
        return false
    end
    local beacon = config.beacon
    local ok, placed = pcall(lights.place, "beacon", {
        color = beacon.color,
        range = beacon.range,
        intensity = beacon.intensity,
        position = { at[1], at[2] + beacon.up, at[3] },
    })
    return ok and placed ~= false
end

-- Sanctuary ------------------------------------------------------------------------------------
-- Calms NPCs near the player a little each tick. The game's AI can raise these values again, so
-- this softens hostility while it lasts rather than making anyone friendly.

local sanctuary_timer = nil
local MAX_PER_TICK = 8              -- the runtime's per-callback limit on NPC writes
local MAX_HOSTILITY, MAX_CONCERN = 20, 15   -- set_attitude refuses values outside the native ranges

local function distance(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function sanctuary_tick()
    if not (api.has_capability("characters.awareness") and api.has_capability("characters.attitude.write")) then
        return
    end
    local view = characters.awareness()
    if not view then
        return
    end
    local here
    for _, row in ipairs(view.characters) do
        if row.is_player then
            here = row.position
        end
    end
    if not here then
        return
    end
    local s, written = config.sanctuary, 0
    for _, row in ipairs(view.characters) do
        local toward = row.toward_player
        if written < MAX_PER_TICK and not row.is_player and not row.dead and row.set_attitude and toward
            and row.position and distance(row.position, here) <= s.radius then
            local change = {}
            if toward.hostility and toward.hostility > 0 then
                change.hostility = math.min(MAX_HOSTILITY, math.max(0, toward.hostility - s.hostility_step))
            end
            if toward.concern and toward.concern > 0 then
                change.concern = math.min(MAX_CONCERN, math.max(0, toward.concern - s.concern_step))
            end
            if next(change) then
                row:set_attitude(change)
                written = written + 1
            end
        end
    end
end

function effects.sanctuary(on)
    if on and not sanctuary_timer then
        sanctuary_timer = timers.every(config.sanctuary.interval, sanctuary_tick)
    elseif not on and sanctuary_timer then
        timers.cancel(sanctuary_timer)
        sanctuary_timer = nil
    end
end

-- The runtime cancels every timer when its phase changes; forget them so they are made again.
function effects.timers_lost()
    torch_timer, flare_timer, sanctuary_timer = nil, nil, nil
    lights.remove("flare")
end

return effects
