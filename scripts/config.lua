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
    torch_interval = 0.3,

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

    sanctuary = {
        power = 0x20505,
        focus = 0.20,
        radius = 700,
        interval = 1.0,
        hostility_step = 2,          -- native hostility is 0..20
        concern_step = 1,            -- native concern is 0..15
    },
}
