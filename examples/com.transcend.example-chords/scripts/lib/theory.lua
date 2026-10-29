-- theory.lua -- keys, scales and chord names. Pure Lua: no transcend.* calls, so it can be read
-- (and tested) on its own. Loaded with require("theory") from scripts/lib/.

local M = {}

M.NAMES = { "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B" }
M.MAJOR = { 0, 2, 4, 5, 7, 9, 11 }
M.MINOR = { 0, 2, 3, 5, 7, 8, 10 }   -- natural minor
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII" }

-- Krumhansl-Kessler key profiles: how strongly each scale degree belongs to a major / minor key.
local KK_MAJOR = { 6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88 }
local KK_MINOR = { 6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17 }

local function pc(n) return n % 12 end

-- Chord shapes, as intervals above the root. Order matters only for ties.
local SHAPES = {
    { "",     { 0, 4, 7 } },
    { "m",    { 0, 3, 7 } },
    { "dim",  { 0, 3, 6 } },
    { "aug",  { 0, 4, 8 } },
    { "sus4", { 0, 5, 7 } },
    { "sus2", { 0, 2, 7 } },
    { "7",    { 0, 4, 7, 10 } },
    { "maj7", { 0, 4, 7, 11 } },
    { "m7",   { 0, 3, 7, 10 } },
    { "m7b5", { 0, 3, 6, 10 } },
    { "dim7", { 0, 3, 6, 9 } },
    { "6",    { 0, 4, 7, 9 } },
    { "m6",   { 0, 3, 7, 9 } },
    { "9",    { 0, 2, 4, 7, 10 } },
    { "maj9", { 0, 2, 4, 7, 11 } },
    { "m9",   { 0, 2, 3, 7, 10 } },
    { "add9", { 0, 2, 4, 7 } },
}

-- The name of the chord made by a set of pitch classes ({ [pc] = true }), with `bass` the lowest
-- sounding pitch class. nil for nothing; a single note is its own name; two notes a fifth apart are
-- a power chord. Scored rather than matched exactly so a voicing that leaves the fifth out still
-- reads as the chord everyone would call it.
function M.chordName(set, bass)
    local count, only = 0, nil
    for p in pairs(set) do count = count + 1; only = p end
    if count == 0 then return nil end
    if count == 1 then return M.NAMES[only + 1] end

    local best, bestScore = nil, -1e9
    for root = 0, 11 do
        if set[root] then
            for _, shape in ipairs(SHAPES) do
                local inShape, missing, matched = {}, 0, 0
                for _, iv in ipairs(shape[2]) do
                    local p = (root + iv) % 12
                    inShape[p] = true
                    if set[p] then matched = matched + 1
                    elseif iv == 7 then missing = missing + 0.5   -- an omitted fifth is ordinary
                    else missing = missing + 1 end
                end
                local extra = 0
                for p in pairs(set) do if not inShape[p] then extra = extra + 1 end end
                local score = matched * 2 - missing * 3 - extra * 2.5
                if root == bass then score = score + 1.5 end
                if score > bestScore then
                    bestScore = score
                    best = { root = root, suffix = shape[1] }
                end
            end
        end
    end
    if count == 2 and best then
        -- Two notes: a fifth is a power chord; anything else names its interval's likely triad.
        local other
        for p in pairs(set) do if p ~= best.root then other = p end end
        if other and (other - best.root) % 12 == 7 then return M.NAMES[best.root + 1] .. "5" end
    end
    local name = M.NAMES[best.root + 1] .. best.suffix
    if bass and bass ~= best.root then name = name .. "/" .. M.NAMES[bass + 1] end
    return name
end

-- The most likely key of a list of notes ({ note, lengthSteps }), weighted by how long each sounds.
-- Returns root (0-11), minor (boolean), or nil when there is too little to go on.
function M.detectKey(notes)
    local hist, total, distinct = {}, 0, 0
    for i = 0, 11 do hist[i] = 0 end
    for _, n in ipairs(notes) do
        local w = math.max(n.lengthSteps or 1, 0.25)
        if hist[pc(n.note)] == 0 then distinct = distinct + 1 end
        hist[pc(n.note)] = hist[pc(n.note)] + w
        total = total + w
    end
    if distinct < 3 then return nil end

    local function correlate(profile, root)
        local mx, my = 0, 0
        for i = 0, 11 do mx = mx + hist[i]; my = my + profile[i + 1] end
        mx, my = mx / 12, my / 12
        local sxy, sxx, syy = 0, 0, 0
        for i = 0, 11 do
            local x = hist[(i + root) % 12] - mx
            local y = profile[i + 1] - my
            sxy, sxx, syy = sxy + x * y, sxx + x * x, syy + y * y
        end
        if sxx == 0 or syy == 0 then return -1 end
        return sxy / math.sqrt(sxx * syy)
    end

    local bestRoot, bestMinor, bestR = 0, false, -2
    for root = 0, 11 do
        local rMaj = correlate(KK_MAJOR, root)
        if rMaj > bestR then bestRoot, bestMinor, bestR = root, false, rMaj end
        local rMin = correlate(KK_MINOR, root)
        if rMin > bestR then bestRoot, bestMinor, bestR = root, true, rMin end
    end
    return bestRoot, bestMinor
end

-- The seven chords of a key: { roman, name, pcs = {root-relative-ordered pitch classes} }.
function M.diatonic(root, minor, sevenths)
    local scale = minor and M.MINOR or M.MAJOR
    local out = {}
    for d = 1, 7 do
        local function degree(k) return (root + scale[(d + k - 1) % 7 + 1]) % 12 end
        local pcs = { degree(0), degree(2), degree(4) }
        if sevenths then pcs[#pcs + 1] = degree(6) end
        local set = {}
        for _, p in ipairs(pcs) do set[p] = true end
        local name = M.chordName(set, pcs[1])
        local third = (pcs[2] - pcs[1]) % 12
        local fifth = (pcs[3] - pcs[1]) % 12
        local roman = ROMAN[d]
        if third == 3 then roman = roman:lower() end
        if fifth == 6 then roman = roman .. "\u{00B0}" elseif fifth == 8 then roman = roman .. "+" end
        out[d] = { roman = roman, name = name, pcs = pcs }
    end
    return out
end

-- MIDI notes for a chord's pitch classes in close position, root between C3 and B3.
function M.voice(pcs)
    local rootNote = 48 + pcs[1]
    local out = { rootNote }
    for i = 2, #pcs do
        out[#out + 1] = rootNote + (pcs[i] - pcs[1]) % 12
    end
    return out
end

function M.keyName(root, minor)
    return M.NAMES[root + 1] .. (minor and " minor" or " major")
end

return M
