---@meta transcend
-- ================================================================================================
--  transcend.d.lua - type definitions for the Transcend extension API (script API level 14)
-- ------------------------------------------------------------------------------------------------
--  For the Lua language server (LuaLS), which is what the "Lua" extension by sumneko uses in VS
--  Code. It gives autocomplete, parameter hints and warnings for everything on `transcend`, and
--  flags a misspelled function before Transcend ever runs it.
--
--  DEFINITIONS ONLY. Nothing in this file runs, and Transcend never loads it.
--
--  Setup: Settings > Packages > New Package... writes this file into the new package's
--  `.transcend/` folder together with a `.luarc.json` that points LuaLS at it. To add it to an
--  existing package by hand, put this file in `<package>/.transcend/` and create
--  `<package>/.luarc.json`:
--
--      {
--        "runtime.version": "Lua 5.4",
--        "runtime.path": ["scripts/lib/?.lua"],
--        "runtime.builtin": { "io": "disable", "debug": "disable", "package": "disable" },
--        "workspace.library": [".transcend"]
--      }
--
--  Both are dot-folders/files, so Export .tpkg leaves them out of the package it builds.
--
--  KEPT IN STEP WITH THE HOST BY A TEST. extension_defs_test loads a real package in the real
--  sandbox, walks everything a script can reach (including the drawing table, captured during a
--  real panel draw) and fails if anything exists in Transcend but not here, or here but not in
--  Transcend. The built-in action ids below are the one list it cannot check headlessly (the
--  registry is filled by the app window); call transcend.actions.list() for the live list.
-- ================================================================================================

---The Transcend extension API. Everything a script can reach is on this table.
transcend = {}

-- ── transcend.api ───────────────────────────────────────────────────────────────────────────────

transcend.api = {}

---The API level this build of Transcend implements. Every lower level is implemented too.
---@type integer
transcend.api.level = 14

---Does this build of Transcend implement `name`? Takes a surface path such as `"midi.send"`,
---`"panels.create"`, `"project.notes"`, or `"events.<hookName>"`. Unknown names return false.
---
---This asks about the HOST. To ask whether your PACKAGE was granted a permission, use
---`transcend.permissions.has`.
---@param name string
---@return boolean
function transcend.api.has(name) end

-- ── transcend.app ───────────────────────────────────────────────────────────────────────────────

transcend.app = {}

---The app version, e.g. `"0.7.3"`, or `"0.7.3.1"` with a hotfix number. Moves independently of `transcend.api.level`.
---@type string
transcend.app.version = ""

-- ── transcend.permissions ───────────────────────────────────────────────────────────────────────

transcend.permissions = {}

---@alias transcend.PermissionName
---| "midi.out"      # send MIDI to user-chosen devices
---| "files.read"    # read files in user-granted folders
---| "files.write"   # write files in user-granted folders
---| "network"       # not available yet
---| "process.spawn" # not available yet

---Was this PACKAGE granted permission `name`? Unknown names return false.
---@param name transcend.PermissionName|string
---@return boolean
function transcend.permissions.has(name) end

-- ── transcend.project (read only) ───────────────────────────────────────────────────────────────

transcend.project = {}

---@class transcend.Pattern
---@field id string
---@field name string
---@field beats number
---@field noteCount integer
---@field pluginId integer The instrument the pattern plays, 0 for none (level 11)
---@field hasSample boolean The built-in sampler plays a sample (level 11)

---@class transcend.Note
---@field uid integer Identity for THIS SESSION ONLY - renumbered when a project loads. Never persist it.
---@field note integer MIDI note number, 0-127
---@field velocity integer 1-127
---@field startStep number FRACTIONAL steps; one step is a 1/16 note
---@field lengthSteps number FRACTIONAL steps
---@field pluginId integer 0 = the pattern's own instrument

---The project tempo in BPM.
---@return number
function transcend.project.tempo() end

---@return integer
function transcend.project.trackCount() end

---@return string
function transcend.project.name() end

---@return transcend.Pattern[]
function transcend.project.patterns() end

---The id of the pattern open in the piano roll, or nil. Nothing is open in a fresh project, so
---always check before passing the result on.
---@return string|nil
function transcend.project.activePattern() end

---The plugin id of the instrument the user is playing (last opened or picked; what a new pattern
---starts on), or nil. Level 11. Give it to a pattern with pattern.setInstrument.
---@return integer|nil
function transcend.project.currentInstrument() end

---The notes of a pattern: nil if there is no such pattern, `{}` if it is empty.
---To CHANGE notes, invoke the `pattern.setNotes` action.
---@param patternId string
---@return transcend.Note[]|nil
function transcend.project.notes(patternId) end

---@alias transcend.TrackKind "track"|"folder"|"vca"|"take"

---@class transcend.Track
---@field index integer Track N is mixer channel N. Pass this to the track.* actions.
---@field name string The name on the arrangement's track header
---@field kind transcend.TrackKind A folder bus or VCA cannot hold clips
---@field muted boolean
---@field soloed boolean
---@field volume number Linear fader gain, 1.0 = 0 dB
---@field pan number -1 (left) .. +1 (right)
---@field color integer|nil The track's colour as 0xRRGGBB; nil when none is assigned (API level 8)
---@field bandColor integer|nil The tone a clip's name band and the mixer strip's name plate are painted in, 0xRRGGBB (API level 13); nil without a colour
---@field bodyColor integer|nil A clip's body tone (API level 13)
---@field nameColor integer|nil The ink written on the band (API level 13)
---@field contentColor integer|nil A clip's waveform / notes ink (API level 13)

---@class transcend.Clip
---@field uid integer Identity of this clip; pass it to the clip.* actions. Use it for a clip you just read, not as a key saved for next session.
---@field track integer Track index
---@field name string
---@field startSeconds number
---@field lengthSeconds number
---@field pattern boolean A pattern clip rather than audio
---@field patternId? string Pattern clips only; pass to transcend.project.notes
---@field path? string Audio clips only: the file it plays; pass to clip.placeAudio for another copy (API level 6)
---@field muted boolean
---@field selected boolean

---One row of the Samples bin (API level 6).
---@class transcend.Sample
---@field path string The file. This is what clip.placeAudio takes.
---@field name string The row's name in the bin (the user can rename it)
---@field lengthSeconds number 0 until the file has decoded
---@field ready boolean Decoded. clip.placeAudio declines a file that is not ready yet.

---Every track, in INDEX order (API level 5).
---@return transcend.Track[]
function transcend.project.tracks() end

---Every clip on the arrangement, in song order (by start time, then track) (API level 5).
---@return transcend.Clip[]
function transcend.project.clips() end

---Where the transport is, in seconds: the song position, or the pattern position in Pattern mode
---(API level 5). `transport.seek` sets it.
---@return number
function transcend.project.playhead() end

---Is the transport rolling? (API level 5)
---@return boolean
function transcend.project.isPlaying() end

---Every row of the Samples bin, in the bin's order (API level 6). These are the ONLY files
---`clip.placeAudio` will place: a script cannot bring a new file into the project. A file dragged
---in twice has two rows with the same path.
---@return transcend.Sample[]
function transcend.project.samples() end

---One loaded plugin instance and where it sits (API level 7). The id is the engine's handle for the
---instance: stable while it stays loaded, NOT across a project reload. `track` is the EXPLICIT
---routing; an instrument picked in the piano roll plays through its pattern's track but reads as
---"global".
---@class transcend.Plugin
---@field id integer Pass to transcend.project.parameters and plugin.setParameter
---@field name string
---@field format "stock"|"vst3"|"vst2"|"clap"|"au"
---@field track integer The mixer channel (== arrangement track index), or -1
---@field role "instrument"|"insert"|"master"|"global" instrument input, insert chain, master chain, or on no channel
---@field slot integer Position in the insert chain (role "insert" or "master"), otherwise -1
---@field instrument boolean true when it plays notes (API level 9)

---One automatable parameter (API level 7) -- the same list the Add Automation picker offers.
---`value` and `default` are NORMALISED 0..1 for every format. `min`/`max` are the plugin's own units
---(0 and 1 for VST3 and VST2, which report none), so the shown value is min + value * (max - min).
---@class transcend.Parameter
---@field id integer What plugin.setParameter takes. NOT a list position; can exceed 2^31 (VST3).
---@field name string
---@field value number 0..1
---@field min number
---@field max number
---@field default number 0..1. VST2 has no default to ask for: it reports the current value.

---Every loaded plugin instance (API level 7).
---@return transcend.Plugin[]
function transcend.project.plugins() end

---A plugin's automatable parameters, or nil when no such plugin is loaded (API level 7). On a large
---synth this is thousands of entries; read it once and poll single values with parameterValue.
---@param pluginId integer
---@return transcend.Parameter[]|nil
function transcend.project.parameters(pluginId) end

---One parameter's current value, 0..1, or nil for an unknown plugin or parameter (API level 7). The
---cheap read a controller script polls.
---@param pluginId integer
---@param paramId integer
---@return number|nil
function transcend.project.parameterValue(pluginId, paramId) end

-- ── Musical context (API level 12) ─────────────────────────────────────────────────────────────
-- Positions are SONG seconds; a "beat" is a quarter note from bar 1 (the unit the tempo counts),
-- whatever the meter. A position that is left out is the playhead. All of these follow the song's
-- tempo and meter changes.

---The tempo in BPM (quarter notes per minute) in force at a position (API level 12).
---@param seconds? number Defaults to the playhead.
---@return number
function transcend.project.tempoAt(seconds) end

---Quarter notes from the song's start at a position (API level 12).
---@param seconds? number Defaults to the playhead.
---@return number
function transcend.project.beatsAt(seconds) end

---Song seconds at a number of quarter notes from the start; the inverse of beatsAt (API level 12).
---@param beats number
---@return number
function transcend.project.secondsAtBeats(beats) end

---The time signature in force at a position, as two numbers: 6, 8 for 6/8 (API level 12).
---@param seconds? number Defaults to the playhead.
---@return integer num
---@return integer den
function transcend.project.meter(seconds) end

---A position as a bar count: 1.0 is bar 1's downbeat, 2.5 is halfway through bar 2 (API level 12).
---@param seconds? number Defaults to the playhead.
---@return number
function transcend.project.barAt(seconds) end

---Song seconds at a bar count; the inverse of barAt (API level 12).
---@param bar number 1.0 = bar 1's downbeat.
---@return number
function transcend.project.secondsAtBar(bar) end

---@class transcend.Key
---@field root integer Pitch class of the key note, 0 = C.
---@field rootName string "A", "F#".
---@field scale string "Major", "Minor", "Dorian" ...
---@field notes integer[] The scale's pitch classes (0 = C), starting at the root.

---The song key, or nil when the song has none (API level 12).
---@return transcend.Key|nil
function transcend.project.key() end

---@class transcend.Marker
---@field id integer Stable while the project is open.
---@field name string
---@field beats number Where it sits, in quarter notes; it keeps its beat when the tempo changes.
---@field seconds number Where that is now.
---@field color? integer 0xRRGGBB; absent = the theme's accent.
---@field tempo? number A tempo change here (BPM from this marker on).
---@field sigNum? integer A time-signature change here (with sigDen).
---@field sigDen? integer

---Every marker on the ruler, in time order (API level 12).
---@return transcend.Marker[]
function transcend.project.markers() end

---The loop region as two numbers (start and end seconds), or nil when no loop is switched on
---(API level 12).
---@return number|nil startSeconds
---@return number|nil endSeconds
function transcend.project.loop() end

---@class transcend.Selection
---@field clips integer[] Uids of the selected arrangement clips.
---@field notes integer[] Uids of the selected notes in the piano roll's open pattern.
---@field notesPattern? string The pattern those notes belong to; absent when no pattern is open.

---What is selected (API level 12).
---@return transcend.Selection
function transcend.project.selection() end

---@class transcend.ControllerPoint
---@field controller integer -1 = pitch bend, else the CC number 0..127.
---@field step integer Position on the pattern's step grid (a step is a 1/16 note).
---@field value integer 0..127, or 0..16383 for pitch bend (8192 = centre).
---@field pluginId integer 0 = the pattern's instrument.

---A pattern's controller lanes (the piano roll's event lane), in step order, or nil when no such
---pattern exists (API level 12).
---@param patternId string
---@return transcend.ControllerPoint[]|nil
function transcend.project.controllers(patternId) end

-- ── transcend.launcher (API level 8) ───────────────────────────────────────────────────────────
-- The clip launcher's READS. Starting and stopping are the launcher.* actions (launcher.setSlot,
-- launcher.launch, launcher.stop, launcher.stopTrack, launcher.stopAll, launcher.clearSlot,
-- launcher.clearAll); the timing is the engine's, sample-accurate on the bar line.

transcend.launcher = {}

---@alias transcend.LaunchState "idle"|"queued"|"playing"|"stopping"

---What a launcher slot (0..1023) is doing. "queued" = waiting for its boundary or for Play;
---"stopping" = playing with a stop waiting for its boundary.
---@param slot integer
---@return transcend.LaunchState
function transcend.launcher.state(slot) end

---0..1 through the loop while the slot plays, else nil.
---@param slot integer
---@return number|nil
function transcend.launcher.progress(slot) end

---@class transcend.LaunchActive
---@field slot integer
---@field state transcend.LaunchState
---@field progress number|nil 0..1 through the loop while playing

---Every slot that is not idle, from ONE read of the engine's table. Draw from this, not state() per cell.
---@return transcend.LaunchActive[]
function transcend.launcher.active() end

-- ── transcend.actions ───────────────────────────────────────────────────────────────────────────

transcend.actions = {}

---Built-in actions in this build. Scoped ones (roll.selectAll, track.group, view.zoomIn/Out) decline
---when their area does not have focus; edit.* act on whichever area has focus.
---@alias transcend.BuiltinActionId
---| "pattern.setNotes"      # replace a pattern's notes; undoable; see transcend.SetNotesParams
---| "pattern.create"        # undoable; { name? } -> ok, patternId (API level 6)
---| "clip.placePattern"     # undoable; { patternId, track, startSeconds } -> ok, uid (API level 6)
---| "clip.placeAudio"       # undoable; { path, track, startSeconds } -> ok, uid (API level 6)
---| "plugin.setParameter"   # NOT undoable; { pluginId, paramId, value } value 0..1 (API level 7)
---| "pattern.setInstrument" # NOT undoable; { patternId?, pluginId } (API level 11)
---| "launcher.setSlot"      # { slot, uid } that clip is what the slot plays (API level 8)
---| "launcher.clearSlot"    # { slot } (API level 8)
---| "launcher.clearAll"     # (API level 8)
---| "launcher.launch"       # { slot, bars? } bars default 1, 0 = at once; starts the transport (API level 8)
---| "launcher.stop"         # { slot, bars? } (API level 8)
---| "launcher.stopTrack"    # { track, bars? } (API level 8)
---| "launcher.stopAll"      # { bars? } (API level 8)
---| "note.preview"          # { notes, velocity?, seconds?, pluginId?, delay?, stagger? } (API level 9)
---| "note.stopPreview"      # (API level 9)
---| "clip.move"             # undoable; transcend.ClipMoveParams (API level 5)
---| "clip.delete"           # undoable; { uid } (API level 5)
---| "clip.setMuted"         # undoable; { uid, muted } (API level 5)
---| "clip.select"           # { uids, add? } (API level 5)
---| "track.rename"          # { index, name } (API level 5)
---| "track.setMute"         # { index, muted } (API level 5)
---| "track.setSolo"         # { index, soloed } (API level 5)
---| "track.setVolume"       # { index, volume } (API level 5)
---| "track.setPan"          # { index, pan } (API level 5)
---| "transport.seek"        # { seconds } (API level 5)
---| "transport.play"        # Play / Pause
---| "transport.stop"
---| "transport.restart"
---| "transport.record"
---| "transport.recordKeep"
---| "transport.recordDiscard"
---| "transport.toggleLoop"
---| "transport.metronome"
---| "edit.undo"
---| "edit.redo"
---| "edit.redoAlt"
---| "edit.cut"
---| "edit.copy"
---| "edit.paste"
---| "edit.duplicate"
---| "edit.delete"
---| "roll.selectAll"
---| "track.add"             # { name? } -> ok, index; name is API level 6
---| "track.addVca"
---| "track.group"
---| "view.zoomIn"
---| "view.zoomOut"
---| "view.mixer"
---| "view.pianoRoll"
---| "view.stepSequencer"
---| "view.padSampler"
---| "view.browser"
---| "view.plugins"
---| "view.extensionPanels"
---| "view.changes"
---| "view.versions"
---| "file.new"
---| "file.open"
---| "file.save"
---| "file.saveAs"
---| "file.importMidi"
---| "file.importAudio"
---| "file.export"
---| "help.shortcuts"
---| "help.reportBug"
---| "palette.open"

---One note for `pattern.setNotes`. Omitted fields default to note 60, velocity 100, startStep 0,
---lengthSteps 1, pluginId 0. Do not pass `uid`.
---@class transcend.NoteInput
---@field note? integer
---@field velocity? integer
---@field startStep? number
---@field lengthSteps? number
---@field pluginId? integer

---@class transcend.SetNotesParams
---@field patternId? string Defaults to the open pattern.
---@field notes transcend.NoteInput[] At most 20,000.

---@class transcend.ClipMoveParams
---@field uid integer
---@field startSeconds? number At least one of startSeconds and track
---@field track? integer Must be a track that can hold clips (not a folder or VCA)

---@class transcend.ClipParams
---@field uid integer

---@class transcend.ClipMuteParams
---@field uid integer
---@field muted boolean

---@class transcend.ClipSelectParams
---@field uids integer[] `{}` selects nothing
---@field add? boolean Add to the current selection instead of replacing it

---@class transcend.TrackRenameParams
---@field index integer
---@field name string Renames the arrangement header; the mixer strip keeps its own name

---@class transcend.TrackMuteParams
---@field index integer
---@field muted boolean

---@class transcend.TrackSoloParams
---@field index integer
---@field soloed boolean

---@class transcend.TrackVolumeParams
---@field index integer
---@field volume number Linear gain, 0..4 (1.0 = 0 dB)

---@class transcend.TrackPanParams
---@field index integer
---@field pan number -1 (left) .. +1 (right)

---@class transcend.SeekParams
---@field seconds number Exact, not snapped to the grid

---@class transcend.PatternCreateParams
---@field name? string Default "Pattern N"

---@class transcend.PlacePatternParams
---@field patternId string From transcend.project.patterns() or pattern.create
---@field track integer A track that can hold clips (not a folder or VCA)
---@field startSeconds number Exact, not snapped to the grid

---@class transcend.PlaceAudioParams
---@field path string A READY row of transcend.project.samples(); any other path declines
---@field track integer A track that can hold clips (not a folder or VCA)
---@field startSeconds number Exact, not snapped to the grid

---@class transcend.TrackAddParams
---@field name? string Names the arrangement header, like track.rename

---A performance control, like a fader: NOT undoable, and a lane automating the same parameter
---overrides it while the song plays (API level 7).
---@class transcend.SetParameterParams
---@field pluginId integer From transcend.project.plugins()
---@field paramId integer From transcend.project.parameters() -- the id, not the list position
---@field value number Normalised 0..1

---Run an action by id. Returns false when it DECLINED (for example the wrong area has focus, a
---parameter is missing or out of range, or `pattern.setNotes` was given a pattern that is not
---placed on the arrangement). Clip edits, placements, new patterns and pattern.setNotes are
---undoable, like the same edit by hand; renames, mute/solo, faders, selection, seeking and adding a
---track are not.
---
---An action that CREATES something returns it as a SECOND value (API level 6): the pattern id from
---`pattern.create`, the clip uid from `clip.placePattern` / `clip.placeAudio`, the track index from
---`track.add`. Every other call, and every decline, returns exactly one value.
---@param id transcend.BuiltinActionId|string
---@param params? table
---@return boolean ok
---@return any created
---@overload fun(id: "pattern.create", params?: transcend.PatternCreateParams): boolean, string?
---@overload fun(id: "clip.placePattern", params: transcend.PlacePatternParams): boolean, integer?
---@overload fun(id: "clip.placeAudio", params: transcend.PlaceAudioParams): boolean, integer?
---@overload fun(id: "track.add", params?: transcend.TrackAddParams): boolean, integer?
---@overload fun(id: "plugin.setParameter", params: transcend.SetParameterParams): boolean
---@overload fun(id: "pattern.setNotes", params: transcend.SetNotesParams): boolean
---@overload fun(id: "clip.move", params: transcend.ClipMoveParams): boolean
---@overload fun(id: "clip.delete", params: transcend.ClipParams): boolean
---@overload fun(id: "clip.setMuted", params: transcend.ClipMuteParams): boolean
---@overload fun(id: "clip.select", params: transcend.ClipSelectParams): boolean
---@overload fun(id: "track.rename", params: transcend.TrackRenameParams): boolean
---@overload fun(id: "track.setMute", params: transcend.TrackMuteParams): boolean
---@overload fun(id: "track.setSolo", params: transcend.TrackSoloParams): boolean
---@overload fun(id: "track.setVolume", params: transcend.TrackVolumeParams): boolean
---@overload fun(id: "track.setPan", params: transcend.TrackPanParams): boolean
---@overload fun(id: "transport.seek", params: transcend.SeekParams): boolean
function transcend.actions.invoke(id, params) end

---@alias transcend.ActionScope "global"|"timeline"|"pianoroll"|"mixer"

---@class transcend.ActionOptions
---@field undoable? boolean Default false. When true, everything the handler does is ONE undo step.
---@field scope? transcend.ActionScope Default "global". A scoped action declines when that area lacks focus.

---Add a command to the command palette and Settings > Shortcuts (API level 3). The id is prefixed
---with your package id automatically. Re-registering an id replaces its handler. At most 64 per
---package. The handler gets 10,000,000 instructions, or 200,000 when a hook handler invoked it.
---
---A handler that creates something can hand it back with `return true, created` (a string or a
---number, API level 6); whatever invoked the command gets it as `actions.invoke`'s second value.
---@param id string Matches ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$
---@param name string What the user sees in the command palette.
---@param handler fun(params: table): boolean?, (string|number)? Return false to decline; a second value is what the command created.
---@param opts? transcend.ActionOptions
---@return string fullId
function transcend.actions.register(id, name, handler, opts) end

---@class transcend.ActionInfo
---@field id string
---@field name string
---@field scope transcend.ActionScope
---@field undoable boolean
---@field provider string "" for a built-in action, otherwise the owning package id

---Every registered action, built-in and scripted (API level 3).
---@return transcend.ActionInfo[]
function transcend.actions.list() end

-- ── transcend.state ─────────────────────────────────────────────────────────────────────────────

transcend.state = {}

---@param key string 1-256 characters
---@return string|number|boolean|nil
function transcend.state.get(key) end

---Store a value that survives reloads, restarts and updates. nil erases the key. Values up to 64 KB;
---at most 512 keys.
---@param key string
---@param value string|number|boolean|nil
function transcend.state.set(key, value) end

---@return string[]
function transcend.state.keys() end

-- ── transcend.files ─────────────────────────────────────────────────────────────────────────────

transcend.files = {}

---Read a file inside a user-granted folder. Needs the `files.read` permission AND a granted folder;
---this beta has no way to grant one, so it always raises. Raises on refusal.
---@param absolutePath string
---@return string
function transcend.files.read(absolutePath) end

---Write a file inside a user-granted folder (at most 1 MB). Needs `files.write` AND a granted
---folder; this beta has no way to grant one, so it always raises. Refused inside a panel draw.
---@param absolutePath string
---@param contents string
function transcend.files.write(absolutePath, contents) end

---Read a file from your own package folder. No permission needed; no absolute paths or `..`.
---@param relativePath string
---@return string
function transcend.files.readPackageFile(relativePath) end

-- ── transcend.events (API level 2) ──────────────────────────────────────────────────────────────

transcend.events = {}

---@alias transcend.HookName
---| "transportStarted"
---| "transportStopped"
---| "playheadMoved"
---| "selectionChanged"
---| "notePlayed"
---| "clipAdded"
---| "clipRemoved"
---| "projectLoaded"
---| "projectSaved"
---| "parameterChanged"
---| "trackAdded"
---| "trackRemoved"
---| "notesChanged"
---| "activePatternChanged"
---| "tempoChanged"
---| "meterChanged"
---| "keyChanged"
---| "markersChanged"

---@class transcend.TransportEvent
---@field mode "song"|"pattern"
---@field seconds number
---@field tempo number

---Fires at most once per UI frame, only when the position changed. Not a sample clock.
---@class transcend.PlayheadEvent
---@field seconds number
---@field beats number
---@field mode "song"|"pattern"
---@field playing boolean

---@class transcend.SelectionEvent
---@field view "timeline"
---@field count integer

---Note-ons from MIDI input only.
---@class transcend.NotePlayedEvent
---@field note integer
---@field velocity integer
---@field channel integer
---@field source "midi"

---@class transcend.ClipAddedEvent
---@field uid integer
---@field track integer
---@field startSeconds number
---@field lengthSeconds number
---@field name string
---@field pattern boolean

---@class transcend.ClipRemovedEvent
---@field uid integer
---@field track integer
---@field name string

---@class transcend.ProjectEvent
---@field path string
---@field name string

---@class transcend.ParameterEvent
---@field target "mixer"
---@field channel integer -1 is the master fader
---@field parameter string
---@field value number

---@class transcend.TrackEvent
---@field index integer
---@field count integer

---API level 12. Fires at most once per UI frame for a pattern whose notes, steps, controller lanes
---or length really changed (not for a project load).
---@class transcend.NotesChangedEvent
---@field patternId string

---API level 12. The pattern the piano roll edits changed; patternId is absent when none is open.
---@class transcend.ActivePatternEvent
---@field patternId? string

---API level 12. The tempo map changed (the base tempo or a tempo marker); read the map with
---project.tempoAt / beatsAt.
---@class transcend.TempoChangedEvent
---@field bpm number The base tempo (the tempo before the first tempo change).

---API level 12. The meter map changed (the base time signature or a signature marker).
---@class transcend.MeterChangedEvent
---@field num integer The base time signature.
---@field den integer

---API level 12. The song key changed; both fields are absent when the song now has no key.
---@class transcend.KeyChangedEvent
---@field root? integer
---@field scale? string

---Register a handler for an event. Returns false if this build does not fire that hook. At most 32
---handlers per hook per package. Handlers run synchronously on the UI thread with a
---200,000-instruction budget; one that raises is switched off until you call `on` again.
---@param hook transcend.HookName
---@param fn fun(e: table)
---@return boolean
---@overload fun(hook: "transportStarted", fn: fun(e: transcend.TransportEvent)): boolean
---@overload fun(hook: "transportStopped", fn: fun(e: transcend.TransportEvent)): boolean
---@overload fun(hook: "playheadMoved", fn: fun(e: transcend.PlayheadEvent)): boolean
---@overload fun(hook: "selectionChanged", fn: fun(e: transcend.SelectionEvent)): boolean
---@overload fun(hook: "notePlayed", fn: fun(e: transcend.NotePlayedEvent)): boolean
---@overload fun(hook: "clipAdded", fn: fun(e: transcend.ClipAddedEvent)): boolean
---@overload fun(hook: "clipRemoved", fn: fun(e: transcend.ClipRemovedEvent)): boolean
---@overload fun(hook: "projectLoaded", fn: fun(e: transcend.ProjectEvent)): boolean
---@overload fun(hook: "projectSaved", fn: fun(e: transcend.ProjectEvent)): boolean
---@overload fun(hook: "parameterChanged", fn: fun(e: transcend.ParameterEvent)): boolean
---@overload fun(hook: "trackAdded", fn: fun(e: transcend.TrackEvent)): boolean
---@overload fun(hook: "trackRemoved", fn: fun(e: transcend.TrackEvent)): boolean
function transcend.events.on(hook, fn) end

---Remove EVERY handler this package registered for `hook`.
---@param hook transcend.HookName
---@return boolean
function transcend.events.off(hook) end

---Every hook name this build fires.
---@return transcend.HookName[]
function transcend.events.names() end

-- ── transcend.midi (API level 2) ────────────────────────────────────────────────────────────────

transcend.midi = {}

---@type integer
transcend.midi.NOTE_OFF = 0x80
---@type integer
transcend.midi.NOTE_ON = 0x90
---@type integer
transcend.midi.AFTERTOUCH = 0xA0
---@type integer
transcend.midi.CC = 0xB0
---@type integer
transcend.midi.PROGRAM = 0xC0
---@type integer
transcend.midi.CHANNEL_PRESSURE = 0xD0
---@type integer
transcend.midi.PITCH_BEND = 0xE0

---@class transcend.MidiDevice
---@field device integer 1-based index into YOUR granted list - pass this to send/noteOn/noteOff/cc
---@field name string
---@field connected boolean

---The devices the user granted this package (Settings > Packages > MIDI Devices). Needs `midi.out`.
---@return transcend.MidiDevice[]
function transcend.midi.devices() end

---Send a channel-voice message (status 0x80-0xEF). Anything from 0xF0 up, including sysex, raises.
---Needs `midi.out` and a granted device.
---@param device integer
---@param status integer
---@param data1? integer
---@param data2? integer
---@return boolean
function transcend.midi.send(device, status, data1, data2) end

---@param device integer
---@param channel integer 0-15
---@param note integer
---@param velocity? integer Default 100
---@return boolean
function transcend.midi.noteOn(device, channel, note, velocity) end

---@param device integer
---@param channel integer 0-15
---@param note integer
---@return boolean
function transcend.midi.noteOff(device, channel, note) end

---@param device integer
---@param channel integer 0-15
---@param controller integer
---@param value? integer Default 0
---@return boolean
function transcend.midi.cc(device, channel, controller, value) end

---Omit a field to match anything.
---@class transcend.MidiMatch
---@field status? integer
---@field channel? integer
---@field data1? integer

---Run an action when incoming MIDI matches. No permission needed. The action receives `params` plus
---the message's own `status`, `channel`, `data1`, `data2` and `value`. The message still reaches
---instruments and pads. At most 256 mappings per package.
---@param match transcend.MidiMatch
---@param actionId transcend.BuiltinActionId|string
---@param params? table
---@return integer mappingId
function transcend.midi.map(match, actionId, params) end

---@param mappingId integer
---@return boolean
function transcend.midi.unmap(mappingId) end

-- ── transcend.panels (API level 4) ──────────────────────────────────────────────────────────────

transcend.panels = {}

---@alias transcend.RedrawMode "onDemand"|"continuous"

---@class transcend.PanelOptions
---@field title? string
---@field minWidth? number 40-4000
---@field minHeight? number 40-4000
---@field redraw? transcend.RedrawMode Default "onDemand"
---@field icon? string A page's button icon in the main bar (API level 7): the path of an .svg in your package, at most 256 KB, e.g. "images/page.svg" (not in icons/, which replaces Transcend's own icons). It is drawn as a one-colour shape in Transcend's icon colours. Without it the button shows the title's first letter
---@field placement? "dock"|"sidebar"|"page"|"window" Default "dock". "sidebar": a card on the Browser's home screen; "page": a whole workspace page beside the arrangement, piano roll and mixer, opened from View > Extension Pages or the command palette (API level 7; probe api.has("panels.placement.sidebar") / api.has("panels.placement.page")); "window": a floating DAW window of its own, opened by the user or by panels.show (API level 10; probe api.has("panels.placement.window"))
---@field width? number A window's size the first time it opens (API level 10); never below minWidth
---@field height? number As width
---@field mixer? boolean A page only (API level 13; probe api.has("panels.option.mixer")): while the page is on screen, the DAW's own docked mixer sits under it, and goes away with the page if the page opened it. panels.mixerLayout says where its strips are

---@class transcend.PanelInfo
---@field id string
---@field title string
---@field visible boolean
---@field width integer
---@field height integer
---@field placement "dock"|"sidebar"|"page"|"window" (API level 7; "window": level 10)

---@class transcend.DrawContext
---@field w integer Panel width in logical pixels
---@field h integer Panel height in logical pixels
---@field dpr number Device pixel ratio
---@field time number Monotonic seconds

---@alias transcend.InputType "press"|"release"|"move"|"wheel"|"enter"|"leave"|"key"

---@class transcend.InputEvent
---@field type transcend.InputType
---@field x number Panel-local logical pixels, the same space you draw in
---@field y number
---@field button integer 1 left, 2 right, 4 middle; 0 for move/wheel/key
---@field mods integer Bitmask: 1 Shift, 2 Ctrl, 4 Alt
---@field delta number Wheel notches, +1 per notch away from the user
---@field key integer Qt key code for "key", otherwise 0
---@field text string The typed character, or ""

---Colours are 0xRRGGBB integers; alpha is a separate optional number from 0 to 1. Every call works
---only while your draw handler is running.
---@class transcend.Graphics
local Graphics = {}

---Fill the whole panel.
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.clear(color, alpha) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.rect(x, y, w, h, color, alpha) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param color integer 0xRRGGBB
---@param penWidth? number Default 1
---@param alpha? number 0-1
function Graphics.rectOutline(x, y, w, h, color, penWidth, alpha) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param radius number
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.roundRect(x, y, w, h, radius, color, alpha) end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color integer 0xRRGGBB
---@param penWidth? number
---@param alpha? number 0-1
function Graphics.line(x1, y1, x2, y2, color, penWidth, alpha) end

---CENTRE and radii, not a bounding box.
---@param cx number
---@param cy number
---@param rx number
---@param ry number
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.ellipse(cx, cy, rx, ry, color, alpha) end

---@param cx number
---@param cy number
---@param rx number
---@param ry number
---@param color integer 0xRRGGBB
---@param penWidth? number
---@param alpha? number 0-1
function Graphics.ellipseOutline(cx, cy, rx, ry, color, penWidth, alpha) end

---`y` is the text BASELINE. `align` contains "left", "center" or "right", optionally with "bold".
---@param x number
---@param y number
---@param str string
---@param color integer 0xRRGGBB
---@param size? number Default 12
---@param align? string e.g. "center bold"
---@param alpha? number 0-1
function Graphics.text(x, y, str, color, size, align, alpha) end

---@param points number[] FLAT: {x1, y1, x2, y2, ...}
---@param color integer 0xRRGGBB
---@param penWidth? number
---@param alpha? number 0-1
function Graphics.polyline(points, color, penWidth, alpha) end

---Closed and filled.
---@param points number[] FLAT: {x1, y1, x2, y2, ...}
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.polygon(points, color, alpha) end

---@param x number
---@param y number
---@param w number
---@param h number
function Graphics.clip(x, y, w, h) end

function Graphics.clipReset() end

---The picture of one arrangement clip, drawn by Transcend (API level 13; probe
---api.has("panels.draw.clipPreview")): an audio clip's waveform or a pattern's notes, filling the
---rectangle in `color`. The same picture the clip strips in the bins show. An unknown uid draws nothing.
---@param uid integer A clip's uid, from transcend.project.clips()
---@param x number
---@param y number
---@param w number
---@param h number
---@param color integer 0xRRGGBB
---@param alpha? number 0-1
function Graphics.clipPreview(uid, x, y, w, h, color, alpha) end

---The active theme's colour for `role` (e.g. "panelBg", "accent", "textBright"), or nil for a role
---this build lacks. Always give a fallback: `g.themeColor("accent") or 0x2ad4ff`.
---@param role string
---@return integer|nil
function Graphics.themeColor(role) end

---A theme colour role as TWO values, rgb and alpha (API level 14; probe api.has("panels.draw.role")),
---so `g.rect(x, y, w, h, g.role("meterLow"))` passes both. nil for a role this build lacks, so give
---a fallback: `local c, a = g.role("accent"); if not c then c, a = 0x2ad4ff, 1 end`.
---@param name string
---@return integer|nil rgb 0xRRGGBB
---@return number|nil alpha 0-1
function Graphics.role(name) end

---A shape token of the active theme in logical pixels: "radius.chip", "radius.control",
---"radius.field", "radius.panel", "radius.popup", "radius.clip" or "border.width". `fallback` when the
---theme leaves the token unset or this build has no such token (API level 14; probe
---api.has("panels.draw.radius")).
---@param token string
---@param fallback? number Default 0
---@return number
function Graphics.radius(token, fallback) end

---A rounded outline; the pen is centred on the edge, as rectOutline's is (API level 14; probe
---api.has("panels.draw.roundRectOutline")).
---@param x number
---@param y number
---@param w number
---@param h number
---@param radius number
---@param color integer 0xRRGGBB
---@param penWidth? number Default 1
---@param alpha? number 0-1
function Graphics.roundRectOutline(x, y, w, h, radius, color, penWidth, alpha) end

---@class transcend.GradientOptions
---@field radius? number Corner radius, default 0
---@field alpha1? number The first colour's alpha, 0-1, default 1
---@field alpha2? number The second colour's alpha, 0-1, default 1
---@field direction? "down"|"right" Default "down": color1 at the top; "right": color1 at the left

---A rectangle filled with a two-stop linear gradient, `color1` at the start (API level 14; probe
---api.has("panels.draw.gradient")).
---@param x number
---@param y number
---@param w number
---@param h number
---@param color1 integer 0xRRGGBB
---@param color2 integer 0xRRGGBB
---@param opts? transcend.GradientOptions
function Graphics.gradient(x, y, w, h, color1, color2, opts) end

---Smoothing (antialiasing) for the drawing calls after this one (API level 14; probe
---api.has("panels.draw.antialias")). A skin part starts with it on; turn it off for whole-pixel
---rows that must stay crisp.
---@param on boolean
function Graphics.antialias(on) end

---Create a panel: a tab under View > Extension Panels, a card on the Browser's home screen
---(`placement = "sidebar"`), or a whole workspace page (`placement = "page"`) (API level 7). Re-creating an id replaces it. At most 8 per package. The id
---is prefixed with your package id.
---@param id string
---@param opts? transcend.PanelOptions
---@return string fullId
function transcend.panels.create(id, opts) end

---@param id string
---@return boolean
function transcend.panels.destroy(id) end

---@param id string
---@param fn fun(g: transcend.Graphics, ctx: transcend.DrawContext)
---@return boolean
function transcend.panels.onDraw(id, fn) end

---The panel's STATIC layer (API level 7; probe api.has("panels.onDrawStatic")): drawn only when
---invalidated with no layer or "static", resized or re-themed, then cached as a picture that onDraw
---paints over. Put what changes with the project here (lanes, clips, a grid) and what moves every
---frame (a playhead, a meter) in onDraw -- which must then NOT call g.clear(). Pass nil to remove.
---@param id string
---@param fn (fun(g: transcend.Graphics, ctx: transcend.DrawContext))|nil
---@return boolean
function transcend.panels.onDrawStatic(id, fn) end

---Return true ONLY for events you used; anything else falls through to the app.
---@param id string
---@param fn fun(e: transcend.InputEvent): boolean?
---@return boolean
function transcend.panels.onInput(id, fn) end

---Ask for a redraw at the next allowed moment. `layer` (API level 7): "dynamic" redraws onDraw only
---and reuses the cached static layer; "static" redraws onDrawStatic only; omitted redraws both.
---@param id string
---@param layer? "dynamic"|"static"
---@return boolean
function transcend.panels.invalidate(id, layer) end

---@param id string
---@param title string
---@return boolean
function transcend.panels.setTitle(id, title) end

---@param id string
---@param mode transcend.RedrawMode
---@return boolean
function transcend.panels.setRedraw(id, mode) end

---This package's panels.
---@return transcend.PanelInfo[]
function transcend.panels.list() end

---@param id string
---@return boolean
function transcend.panels.isVisible(id) end

---Bring one of your panels into view (API level 10): the dock opens on its tab, a page becomes the
---workspace, a window opens or comes to the front. A sidebar card answers false. Call it from an
---action (a menu entry, a key), never when the package loads.
---@param id string
---@return boolean
function transcend.panels.show(id) end

---@class transcend.StripRect
---@field track? integer The track (= mixer channel) the strip shows; absent for the master
---@field x number In the panel's own coordinates
---@field y number
---@field w number
---@field h number

---@class transcend.MixerLayout
---@field strips transcend.StripRect[] Empty while the mixer is not docked on screen
---@field master? transcend.StripRect

---Where the docked mixer's strips are, in this panel's coordinates (API level 13; probe
---api.has("panels.mixerLayout")), so a page made with `mixer = true` can line its columns up over
---them. Read it in a draw: the strips move when the mixer scrolls or the window resizes.
---@param id string
---@return transcend.MixerLayout
function transcend.panels.mixerLayout(id) end

-- ── transcend.menus (API level 10) ─────────────────────────────────────────────────────────────────────────────

transcend.menus = {}

---@alias transcend.MenuName "clip"|"track"|"mixer"|"pianoRoll"

---@class transcend.MenuEntryOptions
---@field title? string What the menu reads (at most 60 characters); default the action's name
---@field only? "audio"|"pattern" Clip menu only: show the entry on audio clips or pattern clips alone

---@class transcend.MenuEntry
---@field id integer
---@field menu transcend.MenuName
---@field action string The full action id
---@field title string
---@field only string

---Put one of your registered actions in a right-click menu, under "Extensions". Picking it runs the
---action with what was right-clicked as its params -- clip: {clip, track, pattern, patternId|path};
---track and mixer: {track}; pianoRoll (its Tools menu): {patternId, clip, selected = {note uid...}}.
---At most 12 entries per package; adding the same action to the same menu again replaces it.
---@param menu transcend.MenuName
---@param actionId string Your own action, local or full id, registered first
---@param opts? transcend.MenuEntryOptions
---@return integer entryId
function transcend.menus.add(menu, actionId, opts) end

---@param entryId integer
---@return boolean
function transcend.menus.remove(entryId) end

---Your entries.
---@return transcend.MenuEntry[]
function transcend.menus.list() end

-- -- transcend.skin (API level 14) -----------------------------------------------------------------
-- A Look's skin (docs/SKINS_PLAN.md 1.9): skin/skin.lua in a package that provides "theme" and
-- "skin" draws named PARTS of the interface, which Transcend caches as pictures. The whole list of
-- slots, their requests and their pictures is the slot reference in the README of
-- extension-sdk/examples/com.transcend.example-skin.
--
-- INSIDE skin/skin.lua ONLY transcend.api, transcend.app AND transcend.skin EXIST: a skin cannot
-- read the project, register an action, open a panel or see the mouse. Everywhere else the table is
-- present (so api.has("skin.part") is true) but transcend.skin.part raises. Inside a skin,
-- api.has(name) answers true only for what that table holds (api.*, app.version, skin.part) and for
-- the drawing calls (panels.draw.*), false for everything else.
--
-- Browser > Extensions > Themes > New Look Package... starts a Look from the theme being worn: its
-- skin/skin.lua holds one commented-out transcend.skin.part per slot; uncomment one and save, and the
-- worn Look redraws.

transcend.skin = {}

---@alias transcend.SkinSlot
---| "cap"          # the mute, solo, arm and FX caps
---| "meter.column" # one column of the segmented meter, lit or ghost
---| "control.action"     # (step 2) the ordinary button: a nine-slice, 24 x 24, insets 8
---| "control.primary"    # the one button a dialog wants pressed
---| "control.quiet"      # a button that is text until the pointer is on it
---| "control.toggle"     # a toggle; q.size "chip" is 12 x 12, insets 4
---| "control.field"      # where text or a number is typed
---| "control.menuButton" # a button that opens a list, and every combo box
---| "control.tab"        # one tab of a tab bar
---| "tray"               # the plate behind a group of toolbar buttons: 36 x 36, insets 12
---| "popup"              # a menu, a combo's drop list, a tooltip, the status message
---| "popup.item"         # the menu row under the pointer: 12 x 12, insets 4
---| "scrollBar.handle"   # the thumb: vertical 6 x 12, insets 3 / 4 (horizontal transposed)
---| "scrollBar.groove"   # the track: vertical 10 x 24, insets 0 / 8 (horizontal transposed)
---| "fader.track"        # (step 3) a fader's track: a nine-slice, vertical 30 x 24 (insets 8 top/bottom), horizontal 24 x 14 (insets 8 left/right)
---| "fader.cap"          # a fader's cap: 30 x 30 classic strip, 22 x 12 detailed strip, 3 x 12 a header's handle
---| "knob.body"          # a knob's square without its pointer; "lit" is the ring fully lit
---| "knob.indicator"     # the pointer alone, straight up, at twice the ratio; Transcend turns it
---| "clip.body"          # a clip: a three-slice, 24 x the clip's height, ends 6 px each
---| "clip.band"          # the name band over the body: 24 x bandHeight, ends 6 px each
---| "clip.barLine"       # one bar line inside a banded clip: 1 x the clip's height minus bandHeight
---| "card"               # (step 4) a Browser card, a list entry's hover card, a store or Library tile: a nine-slice, 36 x 36, insets 12
---| "row"                # a list, bin-folder or Active Plug-ins row's background: a nine-slice, 24 x 24, insets 8
---| "stepCell"           # one step sequencer cell: a nine-slice, 16 x 16, insets 4
---| "scrollThumb"        # a scroll-and-extend bar's thumb, the song map's plate: a three-slice, 24 x 14, ends 8 px each
---| "pianoKey"           # the piano roll's keys: a nine-slice, white 32 x 24, black 24 x 12, insets 4
---| "lcd.well"           # the transport LCD's well (the well look): a nine-slice, 36 x 36, insets 12
---| "lcd.digits"         # one glyph cell of the LCD's readouts (0-9 . :), copied 1:1; Lua only, no data part
---| "status.well"        # the status badges' well: a nine-slice, 36 x 36, insets 12
---| "panel.frame"        # a tool or plug-in window's body frame: a stylesheet nine-slice, 24 x 24, insets 8
---| "playhead"           # the playhead's handle in a ruler: 16 x 16, copied 1:1 (the line stays Transcend's)

---One part request. Every request has slot, w, h and dpr; the other fields belong to one slot each.
---Slots "control.action" to "scrollBar.groove" are NINE-SLICES: their corners (inset by inset) are
---copied as drawn, their edges stretched along their length and their middle both ways, and the
---control keeps its size, text and icon. Every state of such a slot must draw.
---
---Slots "fader.track" to "clip.barLine" (step 3) are pictures the widget asks for when it paints.
---"fader.track" is a nine-slice too; "clip.body" and "clip.band" are THREE-SLICES (the left and right
---6 columns are the clip's ends, the 12 between them its middle, repeated): keep the middle flat, at
---most 8 runs of one colour per column, and Transcend fills it as cheaply as its own drawing.
---"knob.indicator" is made at twice the screen's ratio (q.dpr is already doubled) with the pointer
---drawn straight up; Transcend turns it by (value - 0.5) x 2 x q.sweep degrees, clockwise for a
---higher value. A knob is drawn from the skin only when every picture it needs is ready (the body,
---"lit" when the ring shows, the indicator), else Transcend draws its whole knob.
---
---Slots "card" to "playhead" (step 4): "panel.frame" is a stylesheet nine-slice like step 2's, the
---others are pictures the widget asks for when it paints. Every sliced one carries the four insets,
---all multiples of 4. Only backgrounds are yours: text, values, the playhead's line and everything
---that changes per frame stay Transcend's. "stepCell" and "pianoKey" are used only when all four of
---their pictures are ready, "lcd.digits" only when all 24 are (12 glyphs at two sizes); until then
---Transcend draws its own. "lcd.digits" takes no data part.
---@class transcend.SkinRequest
---@field slot transcend.SkinSlot|string
---@field w integer The picture's width in logical pixels
---@field h integer The picture's height in logical pixels
---@field dpr number The device pixel ratio the picture is made at; draw in logical pixels
---@field kind? string cap: "mute"|"solo"|"arm"|"fx"; popup: "menu"|"list"|"tooltip"|"toast"; clip.body, clip.band, clip.barLine: "audio"|"pattern"; card: "nav"|"leaf"|"tile" (a Browser navigation or home-shelf card, a list entry's hover card, a Get Extensions or Library tile); row: "list"|"group"|"plugin" (a plain list row, a bin folder's header, an Active Plug-ins row); scrollThumb: "extend"|"songMap" (a scroll-and-extend bar's thumb, the plate under the song map); pianoKey: "white"|"black" (white = a run of white keys between the separators above C and F); panel.frame: "toolWindow"
---@field state? string cap: "rest"|"hover"|"pressed"|"on"|"onHover"; meter.column: "lit"|"ghost"; control.action, .primary, .quiet, .menuButton: "rest"|"hover"|"pressed"|"disabled"; control.toggle: "rest"|"hover"|"on"|"onHover"|"disabled"; control.field: "rest"|"focus"|"disabled"; control.tab: "rest"|"hover"|"selected"|"selectedHover"; tray, popup, scrollBar.groove: "rest"; popup.item: "hover"; scrollBar.handle: "rest"|"hover"; fader.track: "rest"|"lit" (lit = the whole track as the travelled part looks); fader.cap: "rest"|"hover"|"pressed" (pressed while dragged); knob.body: "rest"|"hover"|"lit" (lit = the ring fully lit, only the part that lights); knob.indicator: "rest"|"hover"; card: "rest"|"hover" (a "leaf" card: "hover" only); row: "list": "rest"|"hover"|"selected" ("rest" only in the piano roll's pattern column), "group": "rest"|"hover"|"selected", "plugin": "rest"|"hover"|"pressed"; stepCell: "off"|"offAlt"|"on"|"onActive" (offAlt = every other bar, onActive = the step being played); scrollThumb: "rest"|"hot" (dragged or edge-hovered); pianoKey: "rest"|"lit"; lcd.well, panel.frame, playhead: "rest". The clip slots, lcd.digits and status.well have no state.
---@field size? "control"|"chip"|"big"|"small" control.toggle: a chip is a small toggle in a row; lcd.digits: "big" is the readout size, "small" the decimals' size
---@field style? "capsule"|"recessed"|"classic"|"detailed"|"header"|"well"|"inline" tray: the theme's tray.style ("capsule"|"recessed"); fader.track, fader.cap: the mixer strip's "classic" or "detailed" look, or "header" (the detailed track header's volume slider); knob.body, knob.indicator: "classic"|"detailed" (a value knob is "classic"); status.well: "well"|"inline"
---@field orientation? "vertical"|"horizontal" scrollBar.handle, scrollBar.groove; fader.track, fader.cap: vertical in the mixer, horizontal in a track header
---@field insetLeft? integer the nine-slice slots, fader.track, clip.body, clip.band, and every step-4 slot but lcd.digits and playhead: the left inset (corner columns copied as drawn)
---@field insetTop? integer as insetLeft: the top inset
---@field insetRight? integer as insetLeft: the right inset
---@field insetBottom? integer as insetLeft: the bottom inset
---@field selected? boolean fader.track, fader.cap: the strip or track is selected; clip.body, clip.band, clip.barLine: the clip is selected
---@field muted? boolean fader.track, fader.cap: the track is muted (known only in a track header; the mixer says false); clip.body, clip.band, clip.barLine: the clip is muted; stepCell: the lane is muted
---@field compact? boolean stepCell: the step sequencer is in its compact view
---@field role? "pan"|"width"|"value" knob.body, knob.indicator: a mixer strip's pan or width knob, or a value knob (the clip editor's, a plug-in window's Pitch)
---@field dial? number knob.body, knob.indicator: how wide Transcend's own dial is inside the square, in logical pixels
---@field sweep? number knob.body, knob.indicator: degrees either side of 12 o'clock the knob turns through (135)
---@field look? "solid"|"banded" clip.body, clip.band: the theme's clip drawing (the classic one never asks)
---@field color? integer clip.body, clip.band, clip.barLine: the track's own colour as the user picked it, 0xRRGGBB; stepCell: the lane's colour, 0xRRGGBB
---@field body? integer clip.body, clip.band: Transcend's body tone for this clip in this state, 0xRRGGBB
---@field band? integer clip.body, clip.band: Transcend's band tone (the body tone in the solid look), 0xRRGGBB
---@field edge? integer clip.body, clip.band: the selection colour on a selected banded clip, the outline in the solid look, else the body tone; 0xRRGGBB
---@field line? integer clip.barLine: Transcend's bar-line tone for this clip in this state, 0xRRGGBB
---@field bandHeight? integer clip.body, clip.band: the rows the name band covers at the top (0 = no band)
---@field radius? number clip.body, clip.band: Transcend's corner radius (radius.clip in the banded look, 2.5 in the solid); round your ends with it so the selection ring meets them
---@field wear? "normal"|"onPlate"|"quiet" cap: on a panel, on a selected header or strip, on an unused track
---@field fxHas? boolean cap: an FX cap whose track has inserts
---@field segments? integer meter.column: how many segments
---@field segment? integer meter.column: a segment's height (2)
---@field pitch? integer meter.column: a segment and the gap above it (3)
---@field latch? integer meter.column: the latch cell's height (3)
---@field midFrom? integer meter.column: the first segment in the -6 dB zone
---@field overFrom? integer meter.column: the first segment above 0 dB
---@field char? string lcd.digits: the glyph, "0" to "9", "." or ":". A digit's cell is the widest digit's advance (every digit the same width); "." and ":" have their own
---@field ascent? number lcd.digits: the baseline, in logical pixels from the picture's top
---@field fontPx? number lcd.digits: the size of Transcend's readout font in pixels, for a part that draws text
---@field where? "arrangement"|"roll" playhead: which ruler's handle (the arrangement's or the piano roll's)

---Register the drawing for one slot (API level 14). Only a Look's skin/skin.lua may call it; anywhere
---else it raises. Registering a slot again replaces its part. Returns false, with a warning in the
---console, for a slot this build does not have, so a skin written for a newer build still loads.
---
---`fn(g, q)` gets the same drawing object a panel's draw handler gets and the request `q`. It must be
---a pure function of `q` and the theme (Transcend keeps the picture and asks again only when either
---changes), must draw something, and runs under 500,000 instructions and 25 ms a call. A part that
---fails is switched off until the skin is reloaded, Transcend draws its own picture instead, and the
---console says so once. skin/skin.lua's top level runs under 10,000,000 instructions and 250 ms.
---@param slot transcend.SkinSlot|string
---@param fn fun(g: transcend.Graphics, q: transcend.SkinRequest)
---@return boolean
function transcend.skin.part(slot, fn) end
