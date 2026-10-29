-- Tests of the extension's own rule. They run inside the extension (pwsh tools/test.ps1), so
-- require() finds package/scripts/lib exactly as main.lua does.

local fade = require("fade")

local function arpeggio()
    return {
        { note = 60, velocity = 100, startStep = 0,  lengthSteps = 4, pluginId = 0 },
        { note = 64, velocity = 100, startStep = 4,  lengthSteps = 4, pluginId = 0 },
        { note = 67, velocity = 100, startStep = 8,  lengthSteps = 4, pluginId = 0 },
        { note = 72, velocity = 100, startStep = 12, lengthSteps = 4, pluginId = 0 },
    }
end

test("a fade in rises evenly from soft to loud", function()
    local out = fade.fade(arpeggio(), 40, 100)
    testkit.equal(out[1].velocity, 40)
    testkit.equal(out[2].velocity, 60)
    testkit.equal(out[3].velocity, 80)
    testkit.equal(out[4].velocity, 100)
end)

test("notes keep their pitch, place and length", function()
    local before = arpeggio()
    local out = fade.fade(before, 110, 40)
    for i, n in ipairs(out) do
        testkit.equal(n.note, before[i].note, "note " .. i)
        testkit.equal(n.startStep, before[i].startStep, "start of note " .. i)
        testkit.equal(n.lengthSteps, before[i].lengthSteps, "length of note " .. i)
    end
end)

test("velocities stay between 1 and 127", function()
    local out = fade.fade(arpeggio(), -50, 300)
    testkit.equal(out[1].velocity, 1)
    testkit.equal(out[4].velocity, 127)
end)

test("an empty pattern stays empty", function()
    testkit.equal(fade.fade({}, 40, 110), {})
end)
