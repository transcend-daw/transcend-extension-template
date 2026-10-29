-- Velocity Fade: a small, complete extension to start from.
--
--   * a panel (in the Browser's sidebar) that shows the open pattern and two buttons;
--   * two commands in the command palette (Ctrl+P / Cmd+P), Fade In and Fade Out;
--   * it listens for changes instead of polling, so it costs nothing while nothing happens.
--
-- Reads go through transcend.project; changes go through transcend.actions.invoke, so the user can
-- undo them. Every function is described in .transcend/transcend.d.lua (VS Code autocompletes it).
-- Run the tests with:  pwsh tools/test.ps1

local T = transcend
local fade = require("fade")

local PANEL = T.panels.create("panel", {
    title = "Velocity Fade",
    placement = T.api.has("panels.placement.sidebar") and "sidebar" or "dock",
    minWidth = 200, minHeight = 150,
})

local view = { hits = {}, hover = nil, message = nil }

local function openPattern()
    local pid = T.project.activePattern()
    if not pid or pid == "" then return nil, {} end
    return pid, T.project.notes(pid) or {}
end

local function patternName(pid)
    for _, p in ipairs(T.project.patterns()) do
        if p.id == pid then return p.name end
    end
    return pid
end

-- Rewrites the open pattern's velocities as ONE undo step. Returns true when it changed something.
local function apply(from, to)
    local pid, notes = openPattern()
    local ok = false
    if not pid then
        view.message = "Open a pattern first."
    elseif #notes == 0 then
        view.message = "The open pattern has no notes."
    else
        ok = T.actions.invoke("pattern.setNotes", { patternId = pid, notes = fade.fade(notes, from, to) })
        view.message = ok and ("Faded %d notes."):format(#notes) or "Place the pattern on a track first."
    end
    T.panels.invalidate(PANEL)
    return ok
end

T.actions.register("fadeIn", "Velocity Fade: Fade In", function() return apply(40, 110) end)
T.actions.register("fadeOut", "Velocity Fade: Fade Out", function() return apply(110, 40) end)

-- ── Drawing ──────────────────────────────────────────────────────────────────────────────────────
T.panels.onDraw(PANEL, function(g, ctx)
    local bg     = g.themeColor("panelBg") or 0x1b2024
    local card   = g.themeColor("buttonBg") or 0x242a30
    local border = g.themeColor("borderSubtle") or 0x2c333a
    local bright = g.themeColor("textBright") or 0xf5f6f8
    local muted  = g.themeColor("textMuted") or 0x6a767f
    local pad = 14
    view.hits = {}

    g.clear(bg)
    local pid, notes = openPattern()
    if pid then
        g.text(pad, 28, patternName(pid), bright, 14, "bold")
        g.text(pad, 46, (#notes == 1) and "1 note" or (#notes .. " notes"), muted, 10)
    else
        g.text(pad, 28, "No pattern open", muted, 14, "bold")
    end

    local w = (ctx.w - 2 * pad - 8) / 2
    local function button(id, x, label)
        g.roundRect(x, 64, w, 32, 7, view.hover == id and border or card)
        g.text(x + w / 2, 84, label, bright, 12, "center")
        view.hits[#view.hits + 1] = { id = id, x = x, y = 64, w = w, h = 32 }
    end
    button("in", pad, "Fade in")
    button("out", pad + w + 8, "Fade out")

    if view.message then g.text(pad, 120, view.message, muted, 10) end
end)

-- ── Clicking ─────────────────────────────────────────────────────────────────────────────────────
T.panels.onInput(PANEL, function(e)
    local over
    for _, h in ipairs(view.hits) do
        if e.x >= h.x and e.x < h.x + h.w and e.y >= h.y and e.y < h.y + h.h then over = h.id end
    end
    if e.type == "move" or e.type == "leave" then
        if e.type == "leave" then over = nil end
        if over ~= view.hover then view.hover = over; T.panels.invalidate(PANEL) end
        return false
    end
    if e.type ~= "press" or e.button ~= 1 or not over then return false end
    if over == "in" then apply(40, 110) else apply(110, 40) end
    return true
end)

-- ── Keeping up with the project ──────────────────────────────────────────────────────────────────
local function changed() view.message = nil; T.panels.invalidate(PANEL) end
for _, hook in ipairs({ "notesChanged", "activePatternChanged", "projectLoaded" }) do
    T.events.on(hook, changed)
end
