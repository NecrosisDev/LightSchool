-- What each Light power does in the world. Each effect is started and stopped by main.lua and keeps
-- only its own timer and light.
--
-- Light works on the body and the eye, not the mind: it blinds (Flare, Glare, Radiance), guides
-- (Guiding Light) and burns (Searing Beacon). Nothing here changes what an NPC feels toward anyone;
-- the Mind school's Calm, Embolden, Fear and Banish Dead do that.
local config = require("config")
local rules = require("rules")

local effects = {}

-- Shared by the powers that act on NPCs.
local MAX_PER_TICK = 8              -- the runtime's per-callback limit on NPC writes

-- Runs a timer's work as a named scope in the runtime's profiler, where it has one.
local function scoped(name, fn)
    return function(...)
        if profile and profile.scope then
            return profile.scope(name, fn, ...)
        end
        return fn(...)
    end
end

local function distance(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The awareness rows and the player's position, or nil. NPC states are in each row's `awareness`.
local function awareness_around_player()
    local view = characters.awareness()
    if not view then
        return nil
    end
    for _, row in ipairs(view.characters) do
        if row.is_player and row.position then
            return view, row.position
        end
    end
    return nil
end

-- Light Orb ------------------------------------------------------------------------------------

function effects.orb(on)
    if not on then
        lights.remove("orb")
        return
    end
    local orb = config.orb
    lights.set("orb", {
        color = orb.color,
        range = orb.range * rules.potency(),
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
        torch_timer = timers.every(config.torch_interval, scoped("light.torches", torch_tick))
    elseif not mode and torch_timer then
        timers.cancel(torch_timer)
        torch_timer = nil
    end
end

-- Showing who a power touched --------------------------------------------------------------------
-- A short light with a glow placed at the head of the character a power just touched. One light
-- ("touch") serves every power, so the newest touch moves it. pcall: the runtime keeps at most 3
-- lights per addon (RUNTIME-REQUESTS.md asks for more), and a refused light costs only the cue.

local touch_serial = 0

function effects.touch(position, cue)
    if not (lights.place and position) then
        return
    end
    local placed = pcall(lights.place, "touch", {
        color = cue.color,
        range = cue.range,
        intensity = cue.intensity,
        glow = { size = cue.glow, color = { math.min(cue.color[1], 1), math.min(cue.color[2], 1), math.min(cue.color[3], 1) } },
        position = { position[1], position[2] + config.touch_up, position[3] },
    })
    if not placed then
        return
    end
    touch_serial = touch_serial + 1
    local mine = touch_serial
    timers.after(cue.seconds, function()
        if touch_serial == mine then
            lights.remove("touch")
        end
    end)
end

-- AI changes -------------------------------------------------------------------------------------
-- A temporary change through the runtime's row:boost_ai, which takes absolute set_ai values and
-- restores the NPC's own when it lapses. The NPC's own AI skill is awareness.skill, which the game
-- stores as set_ai's 0..100 times 0.01. Only skill is changed: attribute 2 (courage) is the Mind
-- school's business, so it is left out (RUNTIME-REQUESTS.md asks for it to be optional).
local function sharpen(row, mind, skill_change, seconds)
    if not (row.boost_ai and api.has_capability("characters.ai.write") and mind and mind.skill) then
        return false
    end
    local skill = math.max(0, math.min(100, math.floor(mind.skill * 100 + skill_change + 0.5)))
    return (pcall(row.boost_ai, row, { skill = skill, seconds = seconds }))
end

-- The game's own damage applier on an NPC (characters.damage); `row` must come from
-- characters.snapshot in this callback.
local function hurt(row, spec)
    if not (row.damage and api.has_capability("characters.damage")) then
        return false
    end
    return (pcall(row.damage, row, spec))
end

-- Foes within `radius` of `here` who are fighting you; `winding_up` keeps only those about to strike.
local function foes_near(view, here, radius, winding_up)
    local found = {}
    for _, row in ipairs(view.characters) do
        local mind = row.awareness
        if #found < MAX_PER_TICK and not row.is_player and not row.dead and mind and mind.fights_player
            and (not winding_up or mind.wants_attack or mind.attack ~= nil)
            and row.position and distance(row.position, here) <= radius then
            found[#found + 1] = row
        end
    end
    return found
end

-- Character-snapshot rows (which carry `damage`) keyed by record id and position, which match the
-- awareness rows of the same pulse.
local function row_key(row)
    local at = row.position
    return string.format("%d:%.1f:%.1f:%.1f", row.record_id or 0, at[1], at[2], at[3])
end

local function snapshot_rows(details)
    if not api.has_capability("characters.read") then
        return nil
    end
    local ok, view = pcall(characters.snapshot, details and { details = true } or nil)
    if not ok or not view then
        return nil
    end
    local rows = {}
    for _, row in ipairs(view.characters) do
        if row.position then
            rows[row_key(row)] = row
        end
    end
    return rows
end

-- Flare and Glare --------------------------------------------------------------------------------
-- Both throw a burst from the player's light ("flare"): a new burst replaces the last.

local burst_timer, burst_started, burst = nil, 0, nil

-- pcall: if the runtime refuses the light (its per-addon limit, or a runtime older than 0.28.0 that
-- allows only 2), that should cost the burst, not the whole addon.
local function burst_light(strength)
    pcall(lights.set, "flare", {
        color = burst.color,
        range = burst.range,
        intensity = burst.intensity * strength,
        follow = { forward = burst.forward, up = burst.up, smoothing = 0 },
    })
end

local function burst_out()
    if burst_timer then
        timers.cancel(burst_timer)
        burst_timer = nil
    end
    lights.remove("flare")
end

local function burst_tick()
    local fading = timers.now() - burst_started - burst.burn
    if fading >= burst.fade then
        burst_out()
    elseif fading > 0 then
        burst_light(1 - fading / burst.fade)
    end
end

local function start_burst(spec)
    burst_out()
    burst = spec
    burst_light(1)
    burst_started = timers.now()
    burst_timer = timers.every(spec.fade_step, burst_tick)
end

-- Flare: foes close by who are fighting you are dazzled and fight worse for a moment. NPC writes are
-- staged from timer callbacks, so this runs from one.
local function dazzle_tick()
    if not api.has_capability("characters.awareness") then
        return
    end
    local view, here = awareness_around_player()
    if not view then
        return
    end
    local flare, p = config.flare, rules.potency()
    for _, row in ipairs(foes_near(view, here, flare.dazzle_radius * p, false)) do
        sharpen(row, row.awareness, -flare.dazzle_skill * p, flare.dazzle_seconds)
    end
end

-- The awareness rows and the position of the NPC casting for another mod (a companion), given as a
-- record id or a table with its `handle` (a characters.read row), or nil.
local function awareness_around(caster)
    if caster == nil then
        return awareness_around_player()
    end
    local view = characters.awareness()
    local bodies = type(caster) == "table" and snapshot_rows(false) or nil
    for _, row in ipairs(view and view.characters or {}) do
        if not row.is_player and not row.dead and row.position then
            local body = bodies and bodies[row_key(row)]
            if (type(caster) == "table" and body and body.handle == caster.handle) or row.record_id == caster then
                return view, row.position, row.record_id
            end
        end
    end
    return nil
end

-- Glare: the nearest foe winding up to strike takes the light full in the eyes, is thrown off balance
-- and fights blind for a few seconds; a light flares at their face. `caster` is nil for the player, or
-- a companion's record id.
local function glare_tick(caster)
    if not api.has_capability("characters.awareness") then
        return false
    end
    local view, here, self_id = awareness_around(caster)
    if not view then
        return false
    end
    local glare, p = config.glare, rules.potency()
    local target, nearest = nil, math.huge
    for _, row in ipairs(foes_near(view, here, glare.radius * p, true)) do
        local d = distance(row.position, here)
        if d < nearest and (self_id == nil or row.record_id ~= self_id) then
            target, nearest = row, d
        end
    end
    if not target then
        return false
    end
    sharpen(target, target.awareness, -glare.skill * p, glare.blind_seconds)
    local bodies = snapshot_rows(false)
    local body = bodies and bodies[row_key(target)]
    if body then
        hurt(body, { balance = glare.balance, can_fall = false })
    end
    effects.touch(target.position, glare.touch)
    return true
end

function effects.flare()
    start_burst(config.flare)
    timers.after(0, scoped("light.flare", dazzle_tick))
end

function effects.glare()
    start_burst(config.glare)
    timers.after(0, scoped("light.glare", function() glare_tick(nil) end))
end

-- Beacon -----------------------------------------------------------------------------------------
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

local beacon_at = nil   -- where the standing Beacon is, for Searing Beacon

local function place_beacon(intensity)
    local beacon = config.beacon
    local ok, placed = pcall(lights.place, "beacon", {
        color = beacon.color,
        range = beacon.range * rules.potency(),
        intensity = intensity,
        position = { beacon_at[1], beacon_at[2] + beacon.up, beacon_at[3] },
    })
    return ok and placed ~= false
end

function effects.beacon(on)
    if not on then
        lights.remove("beacon")
        beacon_at = nil
        return true
    end
    local at = lights.place and player_position()
    if not at then
        return false
    end
    beacon_at = at
    if place_beacon(config.beacon.intensity) then
        return true
    end
    beacon_at = nil
    return false
end

function effects.beacon_standing()
    return beacon_at ~= nil
end

-- Searing Beacon ---------------------------------------------------------------------------------
-- The Beacon burns: foes fighting you who stand close to it take a little burning damage each second
-- (the game's own damage applier), the dead twice as much, and the Beacon flares and a light marks
-- whoever it sears. Undead are told by the game's own `Undead` and `Corpse` roles, which only a
-- detailed snapshot carries.

local searing_timer = nil
-- Record ids whose roles mark them undead, from a detailed snapshot (the costly read) taken at most
-- every `roles_every` seconds; roles come with the character's record, so the id stands for them.
local undead_ids, undead_read = {}, -math.huge

local function refresh_undead(s)
    if timers.now() - undead_read < s.roles_every then
        return
    end
    undead_read = timers.now()
    local ok, view = pcall(characters.snapshot, { details = true })
    if not ok or not view then
        return
    end
    local wanted = {}
    for _, name in ipairs(s.undead_roles) do
        wanted[name] = true
    end
    undead_ids = {}
    for _, row in ipairs(view.characters) do
        for _, role in ipairs(row.roles or {}) do
            if wanted[role.name] and row.record_id then
                undead_ids[row.record_id] = true
                break
            end
        end
    end
end

local function searing_tick()
    if not (beacon_at and api.has_capability("characters.awareness") and api.has_capability("characters.damage")) then
        return
    end
    local s, p = config.searing, rules.potency()
    local view = characters.awareness()
    local foes = view and foes_near(view, beacon_at, s.radius * p, false) or {}
    if #foes == 0 then
        return   -- nobody near the Beacon: no character reads at all
    end
    local bodies = snapshot_rows(false)
    if not bodies then
        return
    end
    refresh_undead(s)
    local seared
    for _, row in ipairs(foes) do
        local body = bodies[row_key(row)]
        if body then
            local burn = s.health * p * (undead_ids[row.record_id] and s.undead_factor or 1)
            if hurt(body, { health = burn, can_fall = false }) then
                seared = seared or row.position
            end
        end
    end
    if seared then
        place_beacon(config.beacon.intensity * s.flare)
        timers.after(s.touch.seconds, function()
            if beacon_at then
                place_beacon(config.beacon.intensity)
            end
        end)
        effects.touch(seared, s.touch)
    end
end

function effects.searing(on)
    if on and not searing_timer then
        searing_timer = timers.every(config.searing.interval, scoped("light.searing", searing_tick))
    elseif not on and searing_timer then
        timers.cancel(searing_timer)
        searing_timer = nil
    end
end

-- Radiance ---------------------------------------------------------------------------------------
-- While held you blaze: a bright light wraps you, and foes fighting you at close quarters cannot look
-- straight at you, so they fight worse while they stay there.

local radiance_timer = nil

local function radiance_tick()
    if not api.has_capability("characters.awareness") then
        return
    end
    local view, here = awareness_around_player()
    if not view then
        return
    end
    local r, p = config.radiance, rules.potency()
    for _, row in ipairs(foes_near(view, here, r.radius * p, false)) do
        sharpen(row, row.awareness, -r.skill * p, r.linger)
    end
end

function effects.radiance(on)
    if on and not radiance_timer then
        local r = config.radiance
        pcall(lights.set, "radiance", {
            color = r.color,
            range = r.range * rules.potency(),
            intensity = r.intensity,
            follow = { up = r.up, smoothing = 0 },
            glow = { size = r.glow, color = { math.min(r.color[1], 1), math.min(r.color[2], 1), math.min(r.color[3], 1) } },
        })
        radiance_timer = timers.every(r.interval, scoped("light.radiance", radiance_tick))
    elseif not on and radiance_timer then
        timers.cancel(radiance_timer)
        radiance_timer = nil
        lights.remove("radiance")
    end
end

-- Guiding Light ----------------------------------------------------------------------------------
-- Allies are NPCs that follow you, or trust you, and do not fight you. Your light shows them the
-- openings: they fight sharper (skill only; their courage is the Mind school's) while near you, and
-- a small light hangs over the nearest of them. The boost lapses on its own `linger` seconds after
-- the last renewal and the ally's own values come back exactly, so there is nothing to undo here.

local guide_timer = nil

local function is_ally(row, mind, trust_needed)
    if row.is_player or row.dead or not mind or mind.fights_player then
        return false
    end
    if mind.mode == "follow" or mind.handler == "follow" then
        return true
    end
    local toward = mind.toward_player
    return toward ~= nil and toward.trust ~= nil and toward.trust >= trust_needed
end

-- `caster` is nil for the player, or a companion's record id: then the allies around that companion
-- (the player's followers and friends, not the companion itself) are sharpened.
local function guide_tick(caster)
    if not api.has_capability("characters.awareness") then
        return
    end
    local view, here, self_id = awareness_around(caster)
    if not view then
        return
    end
    local g, boosted, p = config.guide, 0, rules.potency()
    local nearest, best = nil, math.huge
    for _, row in ipairs(view.characters) do
        if boosted < MAX_PER_TICK and row.position and (self_id == nil or row.record_id ~= self_id) and is_ally(row, row.awareness, g.ally_trust) then
            local d = distance(row.position, here)
            if d <= g.radius * p then
                if sharpen(row, row.awareness, g.skill * p, g.linger) then
                    boosted = boosted + 1
                end
                if d < best then
                    nearest, best = row.position, d
                end
            end
        end
    end
    if nearest then
        effects.touch(nearest, g.touch)
    end
end

function effects.guide(on)
    if on and not guide_timer then
        guide_timer = timers.every(config.guide.interval, scoped("light.guide", function() guide_tick(nil) end))
    elseif not on and guide_timer then
        timers.cancel(guide_timer)
        guide_timer = nil
    end
end

-- Companions -------------------------------------------------------------------------------------
-- Glare and Guiding Light cast by an NPC on another mod's request (Endless wires its companions):
-- an addons.send "light.cast" message, or a game script line LuaEvent(LightCastGlare, <caster record
-- id>) or LuaEvent(LightCastGuiding, <id>) (main.lua). The game cannot cast mod schools for an NPC
-- (0x1d8340 fails school 5), so this applies the effect from the caster's position. A companion's
-- Guiding Light lasts `companions.guide_seconds`. A caster given by its handle is that one
-- character; given by record id, it is the first live character with the id.

local npc_guides, npc_guide_timer = {}, nil   -- handle or record id -> {caster, left}

local function npc_guide_tick()
    local any = false
    for key, guide in pairs(npc_guides) do
        guide_tick(guide.caster)
        guide.left = guide.left - config.guide.interval
        if guide.left <= 0 then
            npc_guides[key] = nil
        end
        any = true
    end
    if not any and npc_guide_timer then
        timers.cancel(npc_guide_timer)
        npc_guide_timer = nil
    end
end

-- From a timer: `caster` (a record id, or a table with its `handle`) casts "glare" or "guide". True
-- when it took effect (Glare: when a foe was caught).
function effects.npc_cast(caster, kind)
    local key = type(caster) == "table" and caster.handle or caster
    if key == nil or (type(caster) ~= "table" and (math.type(caster) ~= "integer" or caster == 0)) then
        return false
    end
    if kind == "glare" then
        return glare_tick(caster)
    elseif kind == "guide" then
        npc_guides[key] = { caster = caster, left = config.companions.guide_seconds }
        if not npc_guide_timer then
            npc_guide_timer = timers.every(config.guide.interval, scoped("light.npc_guide", npc_guide_tick))
        end
        guide_tick(caster)
        return true
    end
    return false
end

-- The runtime cancels every timer when its phase changes; forget them so they are made again.
function effects.timers_lost()
    npc_guides, npc_guide_timer = {}, nil
    torch_timer, burst_timer, searing_timer, radiance_timer, guide_timer = nil, nil, nil, nil, nil
    lights.remove("flare")
    lights.remove("touch")
    lights.remove("radiance")
end

return effects
