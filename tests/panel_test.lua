-- Tests of the extension as the DAW drives it: its panel, its commands, what it changes.
--
-- The project these run against is a pretend one: tests/project.json (beside this file) says what is
-- in it, and anything it leaves out comes from the test runner's default project. Every change the
-- extension asks for is recorded (testkit.calls) and applied to the pretend project, so reading the
-- project afterwards shows the change.

test("the panel shows the open pattern", function()
    local frame = testkit.draw("panel", 260, 160)
    testkit.truthy(not frame.failed, "the panel drew")
    testkit.truthy(testkit.findText(frame, "Arpeggio"), "the pattern's name is on the panel")
    testkit.truthy(testkit.findText(frame, "4 notes"), "the note count is on the panel")
end)

test("Fade In from the command palette rewrites the open pattern", function()
    local ok = testkit.run("fadeIn")
    testkit.truthy(ok, "the command ran")

    local calls = testkit.calls("pattern.setNotes")
    testkit.equal(#calls, 1, "one change, so one undo step")
    testkit.equal(calls[1].params.patternId, "p1")

    local notes = transcend.project.notes("p1")
    testkit.equal(notes[1].velocity, 40)
    testkit.equal(notes[4].velocity, 110)
end)

test("clicking Fade out on the panel fades the notes down", function()
    local frame = testkit.draw("panel", 260, 160)
    local button = testkit.findText(frame, "Fade out")
    testkit.truthy(button, "the panel has a Fade out button")
    testkit.truthy(testkit.click("panel", button.x, button.y - 4), "the panel took the click")

    local notes = transcend.project.notes("p1")
    testkit.equal(notes[1].velocity, 110)
    testkit.equal(notes[4].velocity, 40)
end)

test("with no pattern open it says so and changes nothing", function()
    testkit.set({ activePattern = "" })
    testkit.equal(testkit.run("fadeIn"), false)
    testkit.equal(#testkit.calls("pattern.setNotes"), 0)
    testkit.truthy(testkit.findText(testkit.draw("panel", 260, 160), "Open a pattern first."))
end)
