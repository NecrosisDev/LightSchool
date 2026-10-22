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

-- Potency: how much the player's Insight strengthens Light effects (reach, light range, Rally's
-- boost). This is the mod's own rule, not one read from the game: 1 with no Insight techniques, up
-- to 1 + insight_bonus with all five. It is refreshed from a timer (character snapshots are read only
-- there) and stays 1 where the runtime offers no skill details.
local potency = 1

function rules.potency()
    return potency
end

-- Re-reads the player's Insight; true when the potency changed.
function rules.refresh_potency()
    if not api.has_capability("characters.read") then
        return false
    end
    local ok, view = pcall(characters.snapshot, { details = true })
    if not ok or not view then
        return false
    end
    for _, row in ipairs(view.characters) do
        local insight = row.is_player and row.skills and row.skills.insight
        if insight and insight.active_techniques then
            local level = math.max(0, math.min(5, insight.active_techniques))
            local new = 1 + config.insight_bonus * level / 5
            if new ~= potency then
                potency = new
                return true
            end
            return false
        end
    end
    return false
end

function rules.instant_refusal(cost, caster)
    if caster and caster.focus < cost then
        return "not enough focus"
    end
    return nil
end

return rules
