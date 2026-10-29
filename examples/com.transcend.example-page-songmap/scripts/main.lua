-- Song Map: an example extension PAGE (API level 7).
--
-- A page is a panel with placement = "page": it gets the whole workspace, beside the arrangement,
-- the piano roll and the mixer, and is opened from View > Extension Pages or the command palette
-- ("Open Page: Song Map"). Drawing works exactly like any panel's.
--
-- What keeps a full-screen page cheap is splitting it into two layers:
--   * the STATIC layer (onDrawStatic) draws the song -- lanes and clips. It runs only when the song
--     changes, and Transcend keeps what it drew as a picture;
--   * the DYNAMIC layer (onDraw) draws only the playhead, over that picture. Moving the playhead
--     re-runs this one small function and repaints a thin strip, not the whole page.

local T = transcend
if not T.api.has("panels.placement.page") then
    print("Song Map needs a Transcend with extension pages (API level 7).")
    return
end

-- The icon is the page's button in Transcend's main bar, beside the arrangement and mixer buttons.
-- Any SVG works: Transcend draws its shape in the bar's own icon colours. It lives in images/, not
-- icons/ -- a package's icons/ folder replaces Transcend's OWN icons.
local PAGE = T.panels.create("songmap", { title = "Song Map", placement = "page",
                                          icon = "images/songmap.svg" })

local LEFT, TOP, LANE_GAP = 140, 48, 4

-- What the static layer laid out, kept for the playhead and for clicks.
local layout = nil   -- { length = seconds, width = px, bottom = px }

local function songLength(clips)
    local len = 0
    for _, c in ipairs(clips) do len = math.max(len, c.startSeconds + c.lengthSeconds) end
    return math.max(len, 8)
end

-- The song: runs when it changes (and on resize or a theme switch), not when the playhead moves.
T.panels.onDrawStatic(PAGE, function(g, ctx)
    local bg     = g.themeColor("workspaceBg") or 0x14181c
    local lane   = g.themeColor("panelBg") or 0x1b2024
    local text   = g.themeColor("textSecondary") or 0x94a2ad
    local muted  = g.themeColor("textMuted") or 0x6a767f
    local bright = g.themeColor("textBright") or 0xf5f6f8
    local accent = g.themeColor("accent") or 0x2ad4ff

    g.clear(bg)
    g.text(16, 30, "Song Map", bright, 16, "bold")

    local tracks = T.project.tracks()
    local clips  = T.project.clips()
    local length = songLength(clips)
    local width  = ctx.w - LEFT - 16
    local rows   = 0
    for _, t in ipairs(tracks) do if t.kind == "track" then rows = rows + 1 end end
    if rows == 0 then layout = nil; return end
    local laneH = math.max(8, math.min(40, (ctx.h - TOP - 16) / rows - LANE_GAP))

    -- One lane per track that can hold clips, in index order.
    local laneOf, y = {}, TOP
    for _, t in ipairs(tracks) do
        if t.kind == "track" then
            laneOf[t.index] = y
            g.rect(LEFT, y, width, laneH, lane)
            g.text(16, y + laneH / 2 + 4, t.name, t.muted and muted or text, 11)
            y = y + laneH + LANE_GAP
        end
    end

    -- Every clip as a bar: patterns in the accent, audio in the text colour, muted ones faint.
    for _, c in ipairs(clips) do
        local ly = laneOf[c.track]
        if ly then
            local x = LEFT + c.startSeconds / length * width
            local w = math.max(2, c.lengthSeconds / length * width)
            g.roundRect(x, ly + 2, w, laneH - 4, 3, c.pattern and accent or text, c.muted and 0.25 or 0.8)
        end
    end

    layout = { length = length, width = width, bottom = y }
end)

-- The playhead: the only thing drawn every time it moves. No g.clear() here -- it would paint over
-- the cached song.
T.panels.onDraw(PAGE, function(g)
    if not layout then return end
    local bright = g.themeColor("textBright") or 0xf5f6f8
    local px = LEFT + T.project.playhead() / layout.length * layout.width
    g.line(px, TOP - 8, px, layout.bottom, bright, 1.5)
end)

-- Click anywhere on the lanes to move the playhead there.
T.panels.onInput(PAGE, function(e)
    if e.type ~= "press" or e.button ~= 1 or e.x < LEFT or not layout then return false end
    local seconds = (e.x - LEFT) / layout.width * layout.length
    T.actions.invoke("transport.seek", { seconds = math.max(0, seconds) })
    T.panels.invalidate(PAGE, "dynamic")
    return true
end)

-- Invalidate only the layer that changed. Invalidating is free while the page is hidden (a hidden
-- page never draws), and doing it anyway means the page is up to date the moment it is opened.
local function songChanged() T.panels.invalidate(PAGE) end
for _, hook in ipairs({ "clipAdded", "clipRemoved", "trackAdded", "trackRemoved", "projectLoaded" }) do
    T.events.on(hook, songChanged)
end
T.events.on("playheadMoved", function() T.panels.invalidate(PAGE, "dynamic") end)
