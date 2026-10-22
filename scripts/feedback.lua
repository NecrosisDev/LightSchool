-- Sound and motion when a Light power starts, ends or is refused. Each part switches on by itself
-- when the runtime offers it (ui.sound since 0.28.0, powers.gesture since 0.28.0-r8).
local config = require("config")

local feedback = {}

function feedback.sound(which)
    if ui and ui.sound and api.has_capability("ui.sound") then
        ui.sound(config.sounds[which], config.sounds.volume)
    end
end

function feedback.gesture(which)
    if powers.gesture then
        pcall(powers.gesture, config.gestures[which])
    end
end

return feedback
