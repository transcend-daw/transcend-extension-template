-- The extension's musical rule, kept apart from the panel so a test can call it directly
-- (tests/fade_test.lua does: require("fade") works there as it does in main.lua).

local M = {}

-- Velocities moving evenly from `from` to `to` across the notes, by where each one starts.
-- Returns NEW note tables; everything but the velocity is copied unchanged.
function M.fade(notes, from, to)
    local first, last = math.huge, -math.huge
    for _, n in ipairs(notes) do
        first = math.min(first, n.startStep)
        last = math.max(last, n.startStep)
    end
    local out = {}
    for i, n in ipairs(notes) do
        -- Notes that all start together (a chord) take the end value.
        local t = (last > first) and (n.startStep - first) / (last - first) or 1
        local v = math.floor(from + (to - from) * t + 0.5)
        out[i] = { note = n.note, velocity = math.max(1, math.min(127, v)),
                   startStep = n.startStep, lengthSteps = n.lengthSteps, pluginId = n.pluginId }
    end
    return out
end

return M
