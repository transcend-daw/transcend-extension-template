-- Chord Helper: an example extension in the Browser sidebar.
--
--   * shows the KEY of the open pattern (detected from its notes, or set by hand);
--   * lists the seven chords of that key, as triads or sevenths;
--   * names the chord sounding at the playhead in the open pattern, and lights it in the list;
--   * click a chord to add it as the next bar of the open pattern (one undo step).

local T = transcend
local theory = require("theory")

local SIDEBAR = T.api.has("panels.placement.sidebar")
local PANEL = T.panels.create("chords", {
    title = "Chords", placement = SIDEBAR and "sidebar" or "dock", minWidth = 220, minHeight = 320 })

-- A step is a 1/16 note. A bar's length comes from the song's meter where this Transcend can say it
-- (API level 12, project.meter); an older one is taken to be in 4/4.
local HAS_METER = T.api.has("project.meter")
local function stepsPerBar(seconds)
    if not HAS_METER then return 16 end
    local num, den = T.project.meter(seconds)
    return math.max(1, math.floor(num * 16 / den + 0.5))
end
-- Notes, active pattern and tempo hooks (API level 12) mean the panel never has to poll.
local HAS_NOTE_HOOKS = T.api.has("events.notesChanged")
local ROW_H, PAD = 34, 14

-- What the user chose, kept across sessions.
local S = {
    autoKey  = T.state.get("autoKey") ~= false,
    keyRoot  = T.state.get("keyRoot") or 0,
    minor    = T.state.get("minor") == true,
    sevenths = T.state.get("sevenths") == true,
}
local function save()
    T.state.set("autoKey", S.autoKey)
    T.state.set("keyRoot", S.keyRoot)
    T.state.set("minor", S.minor)
    T.state.set("sevenths", S.sevenths)
end

-- What the panel shows, recomputed from the project.
local view = {
    patternId = nil, patternName = nil,
    notes = {}, readAt = -1,       -- the open pattern's notes, re-read at most every half second
    key = nil,                     -- detected { root, minor } or nil
    now = nil,                     -- chord name at the playhead, or nil
    message = nil,                 -- the last thing a click did, or why it could not
    hover = nil, hits = {},
}

local function effectiveKey()
    if S.autoKey and view.key then return view.key.root, view.key.minor end
    return S.keyRoot, S.minor
end

local function patternName(pid)
    for _, p in ipairs(T.project.patterns()) do
        if p.id == pid then return p.name end
    end
    return nil
end

-- Re-read the open pattern. With the API level 12 hooks (notesChanged, activePatternChanged) this
-- runs only when something changed; on an older Transcend it also runs from playheadMoved, at most
-- twice a second.
local function refresh(force)
    local now = os.clock()
    if not force and (HAS_NOTE_HOOKS or now - view.readAt < 0.5) then return end
    view.readAt = now
    local pid = T.project.activePattern()
    if pid == "" then pid = nil end
    view.patternId = pid
    view.patternName = pid and patternName(pid) or nil
    view.notes = (pid and T.project.notes(pid)) or {}
    local root, minor = theory.detectKey(view.notes)
    view.key = root and { root = root, minor = minor } or nil
end

-- The pattern-local step under the playhead, or nil. In Pattern mode the playhead IS the pattern
-- clock; in Song mode it is found through the open pattern's placement under the playhead.
local lastMode = "song"
local function stepAtPlayhead()
    local t = T.project.playhead()
    if lastMode == "pattern" then return t / (60 / T.project.tempo() / 4) end
    if not view.patternId then return nil end
    for _, c in ipairs(T.project.clips()) do
        if c.pattern and c.patternId == view.patternId and not c.muted
           and t >= c.startSeconds and t < c.startSeconds + c.lengthSeconds then
            -- Quarter notes through the song's tempo map where it can be read (level 12), so the
            -- step is right after a tempo change. Ignores a left crop: the clip table has no offset.
            if T.api.has("project.beatsAt") then
                return (T.project.beatsAt(t) - T.project.beatsAt(c.startSeconds)) * 4
            end
            return (t - c.startSeconds) / (60 / T.project.tempo() / 4)
        end
    end
    return nil
end

local function chordAtPlayhead()
    local step = stepAtPlayhead()
    if not step then return nil end
    local set, bass = {}, nil
    for _, n in ipairs(view.notes) do
        if step >= n.startStep and step < n.startStep + n.lengthSteps then
            set[n.note % 12] = true
            if not bass or n.note < bass then bass = n.note end
        end
    end
    return theory.chordName(set, bass and bass % 12)
end

-- ── Drawing ──────────────────────────────────────────────────────────────────────────────────────
local function hit(id, x, y, w, h) view.hits[#view.hits + 1] = { id = id, x = x, y = y, w = w, h = h } end

T.panels.onDraw(PANEL, function(g, ctx)
    local bg      = g.themeColor("panelBg") or 0x1b2024
    local card    = g.themeColor("buttonBg") or 0x242a30
    local border  = g.themeColor("borderSubtle") or 0x2c333a
    local text    = g.themeColor("textPrimary") or 0xd8dee4
    local muted   = g.themeColor("textMuted") or 0x6a767f
    local bright  = g.themeColor("textBright") or 0xf5f6f8
    local accent  = g.themeColor("accent") or 0x2ad4ff
    local w = ctx.w
    view.hits = {}

    g.clear(bg)
    g.text(PAD, 28, "Chords", bright, 14, "bold")
    g.text(PAD, 46, view.patternName and ("In " .. view.patternName) or "No pattern open", muted, 10)

    -- Key: < A minor >   (click the name to switch major / minor)
    local root, minor = effectiveKey()
    local y = 60
    local function arrow(id, x, dir)
        local hover = view.hover == id
        g.roundRect(x, y, 26, 26, 6, hover and border or card)
        local cx, cy = x + 13, y + 13
        g.polygon(dir < 0 and { cx + 4, cy - 6, cx + 4, cy + 6, cx - 5, cy }
                           or { cx - 4, cy - 6, cx - 4, cy + 6, cx + 5, cy }, text)
        hit(id, x, y, 26, 26)
    end
    arrow("keyDown", PAD, -1)
    arrow("keyUp", w - PAD - 26, 1)
    local nameW = w - 2 * PAD - 64
    g.roundRect(PAD + 32, y, nameW, 26, 6, view.hover == "mode" and border or card)
    g.text(PAD + 32 + nameW / 2, y + 18, theory.keyName(root, minor), bright, 12, "center bold")
    hit("mode", PAD + 32, y, nameW, 26)

    -- Toggles: Auto key, Sevenths.
    y = 94
    local function toggle(id, x, tw, label, on)
        g.roundRect(x, y, tw, 22, 11, on and accent or card, on and 0.22 or 1)
        if on then g.rectOutline(x + 0.5, y + 0.5, tw - 1, 21, accent, 1, 0.6) end
        g.text(x + tw / 2, y + 15, label, on and bright or muted, 10, "center")
        hit(id, x, y, tw, 22)
    end
    local half = (w - 2 * PAD - 8) / 2
    toggle("auto", PAD, half, view.key and "Key from notes" or "Key from notes (-)", S.autoKey)
    toggle("sevenths", PAD + half + 8, half, "Sevenths", S.sevenths)

    -- Now.
    y = 136
    g.text(PAD, y, "AT THE PLAYHEAD", muted, 9, "bold")
    g.text(PAD, y + 28, view.now or "-", view.now and bright or muted, 20, "bold")

    -- The key's chords. Rows shrink to fit: in the sidebar the panel gets whatever height the
    -- Browser has left under its other sections, which on a laptop is not much.
    y = 182
    local rowH = math.max(22, math.min(ROW_H, math.floor((ctx.h - y - 26) / 7) - 4))
    local base = math.floor(rowH * 0.64)   -- text baseline within a row
    local chords = theory.diatonic(root, minor, S.sevenths)
    for i, ch in ipairs(chords) do
        local ry = y + (i - 1) * (rowH + 4)
        local id = "chord" .. i
        local isNow = view.now ~= nil and view.now:match("^[^/]+") == ch.name
        local hover = view.hover == id
        g.roundRect(PAD, ry, w - 2 * PAD, rowH, 7, isNow and accent or card, isNow and 0.25 or 1)
        if hover then g.rectOutline(PAD + 0.5, ry + 0.5, w - 2 * PAD - 1, rowH - 1, accent, 1, 0.8) end
        g.text(PAD + 12, ry + base, ch.roman, isNow and bright or muted, 11)
        g.text(PAD + 58, ry + base, ch.name, bright, 13, "bold")
        if hover then g.text(w - PAD - 10, ry + base, "+ add bar", accent, 10, "right") end
        hit(id, PAD, ry, w - 2 * PAD, rowH)
    end

    -- What the last click did.
    local fy = y + 7 * (rowH + 4) + 14
    if view.message then g.text(PAD, fy, view.message, muted, 10) end
end)

-- ── Clicking ─────────────────────────────────────────────────────────────────────────────────────

-- A pattern with no instrument of its own plays the chords on nothing. Give it the one you are
-- playing (last opened or picked) so they sound on your synth right away, instead of waiting for an
-- instrument to be chosen in the piano roll. Only from a click here, and never over an instrument
-- the pattern already has. API level 11; an older Transcend simply skips this.
local function giveInstrumentIfNone(pid)
    if not (T.api.has("project.currentInstrument") and T.api.has("patterns.instrument")) then return end
    for _, p in ipairs(T.project.patterns()) do
        if p.id == pid then
            if (p.pluginId or 0) > 0 or p.hasSample then return end
            local inst = T.project.currentInstrument()
            if inst then T.actions.invoke("pattern.setInstrument", { patternId = pid, pluginId = inst }) end
            return
        end
    end
end

local function addChord(i)
    refresh(true)
    if not view.patternId then
        view.message = "Open a pattern first."
        return
    end
    local root, minor = effectiveKey()
    local ch = theory.diatonic(root, minor, S.sevenths)[i]

    -- Next bar after everything already in the pattern.
    local finish = 0
    local out = {}
    for _, n in ipairs(view.notes) do
        finish = math.max(finish, n.startStep + n.lengthSteps)
        out[#out + 1] = { note = n.note, velocity = n.velocity, startStep = n.startStep,
                          lengthSteps = n.lengthSteps, pluginId = n.pluginId }
    end
    -- A pattern's bars are the meter its first placement starts in (the playhead's without one).
    local where = T.project.playhead()
    for _, c in ipairs(T.project.clips()) do
        if c.pattern and c.patternId == view.patternId then where = c.startSeconds; break end
    end
    local bar = stepsPerBar(where)
    local start = math.ceil(finish / bar - 1e-6) * bar
    for _, note in ipairs(theory.voice(ch.pcs)) do
        out[#out + 1] = { note = note, velocity = 92, startStep = start, lengthSteps = bar }
    end

    if T.actions.invoke("pattern.setNotes", { patternId = view.patternId, notes = out }) then
        giveInstrumentIfNone(view.patternId)
        view.message = ("Added %s at bar %d."):format(ch.name, start // bar + 1)
    else
        -- pattern.setNotes needs a pattern that is on the arrangement.
        view.message = "Place the pattern on a track first."
    end
    refresh(true)
end

T.panels.onInput(PANEL, function(e)
    if e.type == "enter" then refresh(true); T.panels.invalidate(PANEL); return false end
    if e.type == "leave" then
        if view.hover then view.hover = nil; T.panels.invalidate(PANEL) end
        return false
    end
    local over
    for _, h in ipairs(view.hits) do
        if e.x >= h.x and e.x < h.x + h.w and e.y >= h.y and e.y < h.y + h.h then over = h.id end
    end
    if e.type == "move" then
        if over ~= view.hover then view.hover = over; T.panels.invalidate(PANEL) end
        return false
    end
    if e.type ~= "press" or e.button ~= 1 or not over then return false end

    local root, minor = effectiveKey()
    if over == "keyDown" or over == "keyUp" then
        S.autoKey = false
        S.keyRoot = (root + (over == "keyUp" and 1 or -1)) % 12
        S.minor = minor
    elseif over == "mode" then
        S.autoKey = false
        S.keyRoot, S.minor = root, not minor
    elseif over == "auto" then
        S.autoKey = not S.autoKey
    elseif over == "sevenths" then
        S.sevenths = not S.sevenths
    else
        addChord(tonumber(over:match("%d+")))
    end
    save()
    T.panels.invalidate(PANEL)
    return true
end)

-- ── Keeping up with the project ──────────────────────────────────────────────────────────────────
-- The chord at the playhead is recomputed on every playhead move, but the panel only redraws when
-- its NAME changes -- a sustained chord costs nothing.
T.events.on("playheadMoved", function(e)
    lastMode = e.mode or lastMode
    if not T.panels.isVisible(PANEL) then return end
    refresh(false)
    local name = chordAtPlayhead()
    if name ~= view.now then view.now = name; T.panels.invalidate(PANEL) end
end)

local function projectChanged()
    refresh(true)
    view.now = chordAtPlayhead()
    T.panels.invalidate(PANEL)
end
for _, hook in ipairs({ "clipAdded", "clipRemoved", "projectLoaded", "selectionChanged",
                        "transportStarted", "transportStopped" }) do
    T.events.on(hook, projectChanged)
end
-- API level 12: told when the notes, the open pattern or the tempo change, instead of polling.
if HAS_NOTE_HOOKS then
    T.events.on("notesChanged", function(e)
        if e.patternId == view.patternId then projectChanged() end
    end)
    for _, hook in ipairs({ "activePatternChanged", "tempoChanged", "meterChanged" }) do
        T.events.on(hook, projectChanged)
    end
end

refresh(true)
