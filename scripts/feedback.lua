-- What the player sees, hears and pays when a Light power starts, ends or is refused, done the way the
-- game does it for its own powers where the runtime offers the means: ui.sound (0.28.0),
-- powers.gesture (0.28.0-r8), and the requested powers.wheel and powers.spend_focus.
local config = require("config")

local feedback = {}

function feedback.sound(which, volume)
    if ui and ui.sound and api.has_capability("ui.sound") then
        ui.sound(config.sounds[which], volume or config.sounds.volume)
    end
end

function feedback.gesture(which)
    if powers.gesture then
        pcall(powers.gesture, config.gestures[which])
    end
end

-- The power wheel's own reaction to a cast: it shows and flashes the slot on success; on a refusal the
-- runtime plays the game's fail sound itself. Without powers.wheel, our sounds stand in.
local function wheel(power, accepted)
    if powers.wheel then
        return (pcall(powers.wheel, power, accepted and "cast" or "fail"))
    end
    return false
end

-- A held power started (accepted) or any cast refused.
function feedback.cast(power, accepted)
    local shown = wheel(power, accepted)
    if accepted then
        feedback.sound("start")
        feedback.gesture("start")
    elseif not shown then
        feedback.sound("fail")
    end
end

function feedback.flare(power)
    wheel(power, true)
    feedback.sound("flare")
    feedback.gesture("flare")
end

-- Drains `amount` from current focus the way the game's casts do; false when the runtime cannot.
function feedback.spend(amount)
    if powers.spend_focus and amount > 0 then
        return (pcall(powers.spend_focus, amount))
    end
    return false
end

return feedback
