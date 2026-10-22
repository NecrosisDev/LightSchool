-- Tuning for the Light school. Distances are centimetres, times seconds, colours 0..4 per channel.
-- Power ids must match the nodes build.py writes into pwr_light.pwr.
return {
    -- Held powers follow the game's continuous-power rules: each needs a free Continuity binding.
    needs_binding = true,
    -- What Abstraction leaves of a held power's cost, and Iteration of a repeated instant cast.
    abstraction = 0.75,
    iteration = 0.5,
    -- The runtime refuses a larger total hold.
    max_hold = 0.5,
    -- Insight strengthens Light effects: reaches, light ranges and Guiding Light's boost grow by up to this
    -- share with all five Insight techniques (the mod's own rule). Re-read after each cast and every
    -- potency_interval s while a Light power is held (a detailed character read is costly).
    insight_bonus = 0.5,
    potency_interval = 30,

    -- The game's own thaumaturgy sounds (Sound.rpk member names), played with ui.sound.
    sounds = {
        start = "thaumchnl01",       -- a held power starts
        release = "thaumchnl02",     -- a held power is released
        flare = "thaumshow02",
        fail = "thaumfail01",        -- what the game plays for a refused cast
        volume = 0.5,
    },
    -- The native cast motion each power plays where the runtime offers powers.gesture.
    gestures = { start = "channel", flare = "thrust" },

    orb = {
        power = 0x20501,
        focus = 0.15,                -- Mind Sense holds 0.27
        color = { 0.85, 0.92, 1.0 },
        range = 2000,                -- a carried torch reaches about 1500
        intensity = 2.5,             -- the game's own player light uses 2
        forward = -40,
        right = 30,
        up = 50,
        smoothing = 0.35,
        bob = 6,
        glow = 12,                   -- size of the visible orb (cm, the runtime takes 2..20)
    },

    -- Kindle and Snuff light or put out the wall torches the runtime offers (within about 2 m).
    kindle = { power = 0x20502, focus = 0.10 },
    snuff = { power = 0x20503, focus = 0.10 },
    torch_interval = 0.5,

    flare = {
        power = 0x00504,
        focus = 0.12,
        recover = 8,                 -- a mod cannot spend focus, so the cost is held this long instead
        color = { 1.0, 0.97, 0.9 },
        range = 4000,
        intensity = 8,
        forward = 60,
        up = 120,
        burn = 0.4,
        fade = 1.6,
        fade_step = 0.1,
        -- Dazzle: foes within dazzle_radius who are fighting you fight worse (AI skill, 0..100) for a
        -- moment; needs the runtime's boost_ai.
        dazzle_radius = 600,
        dazzle_skill = 15,
        dazzle_seconds = 2,
    },

    -- Beacon leaves a light where it was cast (runtime 0.28.0's lights.place, plus a character snapshot
    -- for the player's position).
    beacon = {
        power = 0x20506,
        focus = 0.10,
        color = { 0.7, 0.85, 1.0 },
        range = 1500,
        intensity = 2,
        up = 100,                    -- above the body centre (about head height plus a little)
    },

    -- The short light that shows who a power touched, placed this far above the body centre.
    touch_up = 90,

    -- Glare and Guiding Light cast by an NPC on another mod's request (effects.npc_cast): how long a
    -- companion's Guiding Light lasts, and the cast sound's volume (ui.sound plays at the player).
    companions = { guide_seconds = 15, volume = 0.3 },

    -- Radiance: while held you blaze, and foes fighting you within `radius` fight worse (AI skill)
    -- while they stay that close. The boost lapses `linger` seconds after they step away.
    radiance = {
        power = 0x20505,
        focus = 0.20,
        radius = 250,
        interval = 1.0,
        skill = 20,
        linger = 1.5,
        color = { 1.0, 0.95, 0.8 },
        range = 900,
        intensity = 3,
        up = 0,
        glow = 18,
    },

    -- Guiding Light: allies near you fight sharper (their AI skill only), and a small light hangs over
    -- the nearest. The runtime undoes the boost by itself when it lapses.
    guide = {
        power = 0x20507,
        focus = 0.20,
        radius = 800,
        interval = 1.0,
        linger = 2.5,                -- seconds a boost outlasts the last tick that renewed it
        skill = 15,                  -- added to the ally's own AI skill (actor units 0..100)
        ally_trust = 50,             -- NPCs who trust you this much count as allies even if not following
        touch = { color = { 1.0, 0.9, 0.6 }, range = 400, intensity = 1.5, glow = 6, seconds = 1.1 },
    },

    -- Glare: an instant, close-range flash into the eyes of the nearest foe winding up to strike: it
    -- costs them balance at once and they fight blind (less AI skill) for `blind_seconds`.
    glare = {
        power = 0x00508,
        focus = 0.10,
        radius = 350,
        balance = 0.35,              -- of a full balance pool (about 1); never knocks them down by itself
        skill = 30,
        blind_seconds = 3,
        color = { 1.0, 1.0, 0.95 },
        range = 1200,
        intensity = 6,
        forward = 80,
        up = 140,
        burn = 0.15,
        fade = 0.5,
        fade_step = 0.05,
        touch = { color = { 1.0, 1.0, 0.95 }, range = 300, intensity = 4, glow = 10, seconds = 0.4 },
    },

    -- Searing Beacon: while held with a Beacon standing, foes fighting you within `radius` of it take
    -- `health` burning damage each second (a full pool is about 1), the dead `undead_factor` times as
    -- much. Undead are told by their character roles.
    searing = {
        power = 0x20509,
        focus = 0.12,
        radius = 250,
        interval = 1.0,
        health = 0.03,
        undead_factor = 2,
        flare = 2.5,                 -- the Beacon's brightness while it bites, times its own
        undead_roles = { "Undead", "Corpse" },
        roles_every = 5,             -- seconds between the detailed reads that find the undead
        touch = { color = { 1.0, 0.6, 0.25 }, range = 350, intensity = 3, glow = 8, seconds = 0.35 },
    },
}