---@meta
-- Definitions for the test runner's helpers (Transcend --test-extension), for the Lua extension in
-- VS Code. Tests live in tests/*.lua and run INSIDE the extension, against a pretend project; see
-- the template's README. This file describes; it is never run.

---Declares one test. The runner calls `fn` after every test before it in the file has run; the
---extension and the pretend project carry over from one test to the next within a file.
---@param name string
---@param fn fun()
function test(name, fn) end

---@class TestkitText
---@field text string
---@field x number
---@field y number
---@field size number

---@class TestkitFrame
---@field texts TestkitText[]  every piece of text the panel drew, static layer first
---@field commands integer     how many drawing commands it made
---@field failed boolean       its draw handler raised an error
---@field title string

---@class TestkitCall
---@field id string            the host action the extension invoked, e.g. "pattern.setNotes"
---@field params table         what it passed

testkit = {}

---Fails the test unless `got` equals `want` (tables are compared field by field, numbers to 1e-9).
---@param got any
---@param want any
---@param what? string  says what was compared, in the failure message
function testkit.equal(got, want, what) end

---Fails the test unless `got` is within `tolerance` of `want` (default 1e-6).
---@param got number
---@param want number
---@param tolerance? number
---@param what? string
function testkit.near(got, want, tolerance, what) end

---Fails the test unless `value` is truthy.
---@param value any
---@param what? string
function testkit.truthy(value, what) end

---Fails the test unless the list holds `value`.
---@param list any[]
---@param value any
---@param what? string
function testkit.contains(list, value, what) end

---A readable one-line form of any value, for your own messages.
---@param value any
---@return string
function testkit.describe(value) end

---The whole pretend project, in the names tests/project.json uses.
---@return table
function testkit.project() end

---Replaces fields of the pretend project, e.g. testkit.set({ tempo = 90, activePattern = "" }).
---@param fields table
function testkit.set(fields) end

---Fires one of Transcend's events at the extension, e.g. testkit.fire("notesChanged", { patternId = "p1" }).
---@param event string
---@param payload? table
function testkit.fire(event, payload) end

---Runs an action, by its full id or by the id the extension registered it under ("fadeIn").
---@param actionId string
---@param params? table
---@return boolean ran
---@return any result
function testkit.run(actionId, params) end

---Every host action the extension invoked during this test, optionally only one kind.
---@param actionId? string
---@return TestkitCall[]
function testkit.calls(actionId) end

---Every line the extension printed during this test (load-time prints show in the file's first test).
---@return string[]
function testkit.console() end

---Draws one of the extension's panels at this size and returns what it drew.
---@param panel string  the id given to transcend.panels.create
---@param w? integer    default 400
---@param h? integer    default 300
---@param t? number     the panel's clock, in seconds
---@return TestkitFrame
function testkit.draw(panel, w, h, t) end

---Presses and releases a mouse button at (x, y) on a panel. Returns true when the panel used the click.
---@param panel string
---@param x number
---@param y number
---@param button? integer  1 left (default), 2 right, 4 middle
---@return boolean
function testkit.click(panel, x, y, button) end

---Moves the mouse to (x, y) over a panel.
---@param panel string
---@param x number
---@param y number
---@return boolean
function testkit.move(panel, x, y) end

---Turns the mouse wheel over a panel (+1 = one notch away from you).
---@param panel string
---@param x number
---@param y number
---@param delta? number
---@return boolean
function testkit.wheel(panel, x, y, delta) end

---The first drawn text equal to, or containing, `text`.
---@param frame TestkitFrame
---@param text string
---@return TestkitText|nil
function testkit.findText(frame, text) end
