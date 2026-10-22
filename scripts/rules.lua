-- The game's cost rules for thaumaturgy, applied to the Light school.
local config = require("config")

local rules = {}

function rules.held_cost(name, caster)
    local cost = config[name].focus
    if caster and caster.techniques.abstraction then
        cost = cost * config.abstraction
    end
    return cost
end

function rules.instant_cost(name, caster, repeated)
    local cost = config[name].focus
    if repeated and caster and caster.techniques.iteration then
        cost = cost * config.iteration
    end
    return cost
end

-- Why a held power cannot start, or nil. `held_now` counts our own held powers, which
-- caster.bindings_used leaves out (it counts the game's own powers only). Unknown caster state never
-- blocks a cast.
function rules.held_refusal(name, caster, held_now)
    if not caster then
        return nil
    end
    if config.needs_binding and caster.bindings_used + held_now >= caster.bindings then
        return caster.bindings == 0 and "it needs a Continuity technique" or "every Continuity binding is in use"
    end
    if caster.focus < rules.held_cost(name, caster) then
        return "not enough focus"
    end
    return nil
end

function rules.instant_refusal(cost, caster)
    if caster and caster.focus < cost then
        return "not enough focus"
    end
    return nil
end

return rules
