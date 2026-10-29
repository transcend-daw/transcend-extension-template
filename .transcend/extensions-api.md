# Transcend Extensions: Complete API Reference

Transcend 0.7 (beta) - Script API level 13 - Lua 5.4

This is the complete list of what a Transcend extension can call. **If a function is not in this
file, it does not exist.** It is written to be read by people and to be given to an AI assistant as
context when writing an extension.

**The API may still change before Transcend 1.0.** Any change is listed in the release notes with
before-and-after code, and this file and `transcend.d.lua` are updated in the same release. From 1.0
on, nothing is renamed or removed.

- Installing and managing packages: `extensions.html`
- Step-by-step walkthrough: `extensions-first-package.html`
- Machine-readable definitions of this whole API: `transcend.d.lua` (section 1.5)

Contents: 0 AI instructions - 1 package format - 2 `api`, `app`, `permissions` - 3 `project` -
4 `actions` - 5 `events` - 6 `midi` - 7 `panels` - 8 `state` and `files` - 9 built-in actions
(including the clip launcher and note preview) - 10 the sandbox - 11 API levels - 12 complete
example - 13 `menus` (right-click menu entries) - 14 testing an extension.

---

## 0. Instructions for AI assistants

If you are generating a Transcend extension from this file:

1. **Use only the functions listed here.** Do not invent functions by analogy with other DAWs or
   other Lua hosts. There is no `transcend.project.setNotes`, no `transcend.transport.play`, no
   `transcend.ui`, no `transcend.timer`, and no `reaper.*`. To change the project or drive the
   transport, call `transcend.actions.invoke` with an action id from section 9.
2. **The sandbox has no `io`, no `os` (except `os.time`, `os.clock`, `os.date`), no `load`,
   `loadstring`, `dofile`, `loadfile`, `debug`, `package`, `collectgarbage`, `rawget`/`rawset`/
   `rawequal`/`rawlen` or `string.dump`.** `require` exists but only loads modules from the
   package's own `scripts/lib/` folder. Code using any of these will fail.
3. **Reads go through `transcend.project` (and `transcend.launcher`); writes go through actions.**
   Nothing else modifies the project.
4. **`transcend.project.activePattern()` returns `nil` when no pattern is open**, which is the
   normal state of a new project. Always check before passing it on.
5. **Colours are `0xRRGGBB` integers with an optional separate alpha (0 to 1).** They are not
   `0xRRGGBBAA`.
6. **A panel input handler must return `true` only for events it used.** Returning `true` for
   everything swallows the app's keyboard shortcuts.
7. **Never store a note `uid`** in `transcend.state`. It is renumbered every time a project loads.
   The same goes for a plugin `id`.
8. **Hook handlers and panel input handlers get only 200,000 Lua instructions per call**, and
   going over unloads the whole package. Keep them short. Registered commands and the entry
   script's top level get 10,000,000, except that a command invoked from inside a hook handler gets
   the hook's 200,000. String pattern functions (`find`, `match`, `gmatch`, `gsub`) count toward
   the same budget, so avoid patterns that backtrack heavily, such as several `.-` in a row.
9. Produce a complete package: a `manifest.json` (section 1.2) whose `provides` matches the files,
   plus `scripts/main.lua`. Declare the lowest `apiLevel` the script needs, and probe newer features
   with `transcend.api.has`.
10. **Scripted extensions are on by default** (since 2026-10-24). They are off only when the user
   has set the environment variable `TRANSCEND_EXTENSIONS=0`, or held Shift while Transcend started
   (safe mode, which loads no packages). If a package does not seem to load, check those two first.
11. **Track indexes start at 0; Lua arrays start at 1.** `transcend.project.tracks()[1]` is the
   track whose `index` is `0`. Always pass a track's `index` field to the `track.*` actions, never
   its position in the array.
12. **Re-read clips after changing them.** `transcend.project.clips()` returns a copy. Its
   `startSeconds`, `track` and `selected` fields do not update when an action moves a clip.
13. **Actions that create something return it as a second value** (API level 6):
   `local ok, uid = transcend.actions.invoke("clip.placePattern", {...})`. Use it; do not search
   `clips()` for the new clip. `clip.placeAudio` only accepts a `path` from
   `transcend.project.samples()` whose `ready` is `true`.
14. **For musical positions use the level-12 functions** (`beatsAt`, `secondsAtBeats`, `barAt`,
   `secondsAtBar`, `meter`; section 3.1). `60 / transcend.project.tempo()` is wrong as soon as the
   song has a tempo or time-signature change.
15. **A pattern can have no instrument and play nothing.** Check a pattern's `pluginId` and
   `hasSample` (API level 11). To give it the instrument the user is playing, invoke
   `pattern.setInstrument` with `transcend.project.currentInstrument()`, and only from something the
   user did (a command, a click in your panel), never behind their back.
16. **Never open a window or page when the package loads.** Call `transcend.panels.show` only from
   an action, a menu entry or a click. A window the user did not ask for is the one thing an
   extension must not do.
17. **Scripts have no timer.** To play notes a moment later, use `note.preview`'s `delay` and
   `stagger` (section 9.5). To react to changes, use the events in section 5.
18. **A menu entry points at one of your own registered actions.** Register the action first, then
   call `transcend.menus.add` (section 13).
19. Offer tests with the package when it has logic worth checking (section 14).

---

## 1. Package format

### 1.1 Layout

A package is a folder. Distributed, it is that folder's **contents** zipped (with `manifest.json`
at the root of the archive, forward-slash paths) and renamed to `.tpkg`.

```
com.author.package-name/
|-- manifest.json          required
|-- scripts/
|   |-- main.lua           the entry script (name set by "entry")
|   `-- lib/*.lua          optional modules for require()
|-- tests/*.lua            optional tests (section 14); may also sit beside the package folder
|-- images/                optional pictures, e.g. a page's button icon
|-- theme.json             optional theme payload
|-- layout.json            optional layout payload
|-- icons/                 optional overrides of Transcend's OWN icons (a page's icon goes elsewhere, e.g. images/)
|-- README.md              optional, shown in Settings > Packages
|-- LICENSE                optional, shown in Settings > Packages
`-- icon.png               optional 128x128 icon for the package list
```

### 1.2 manifest.json

```json
{
  "format": "transcend.package",
  "formatVersion": 1,
  "id": "com.author.package-name",
  "name": "Package Name",
  "version": "1.0.0",
  "author": "Author Name",
  "description": "One line shown in the package list.",
  "apiLevel": 3,
  "provides": ["scripts"],
  "permissions": [],
  "entry": "scripts/main.lua"
}
```

| Field | Required | Rules |
|---|---|---|
| `format` | yes | Exactly `"transcend.package"`. |
| `formatVersion` | yes | `1`. |
| `id` | yes | Reverse-DNS. Letters, digits, `.`, `-`, `_` only. Permanent: it identifies updates and the package's saved data. |
| `name` | yes | Display name. |
| `version` | yes | Semver, e.g. `"1.2.0"`. |
| `author` | yes | Display only. |
| `description` | no | One line. |
| `homepage` | no | Shown, never opened automatically. |
| `requiresApp` | no | Version range, e.g. `">=0.7.0"`. |
| `apiLevel` | if scripts | The lowest API level the script needs. The host refuses a package above its own level (13 here). |
| `provides` | yes | Any of `"scripts"`, `"theme"`, `"layout"`, `"icons"`, `"presets"`. **Must match the contents exactly in both directions**, or the install is refused. |
| `permissions` | no | Any of `"midi.out"`, `"files.read"`, `"files.write"`, `"network"`, `"process.spawn"`. Omit if none. |
| `entry` | if scripts | Path to the entry script, inside the package. |

Unknown manifest keys are ignored.

### 1.3 Install limits

The archive is at most 64 MB and 256 MB unpacked, with at most 4096 entries. A single entry is at
most 32 MB, a path at most 200 characters and 12 levels deep. Images and SVGs are at most 4 MB and
4096 px per side. Entry names must not contain backslashes, `:`, `.` or `..` components, or be
absolute.

### 1.4 Lifecycle

- The entry script's top level runs once each time the package **starts**: on install, on enable,
  at every launch, and on **Reload Scripts** in Settings > Packages.
- Each start is a **fresh Lua state**. Globals do not survive; `transcend.state` does.
- Disabling or removing a package destroys its state. Its commands, hooks, MIDI mappings, panels,
  pages, windows and menu entries go with it, and the host sends All Notes Off to any MIDI device it
  was granted.
- Each package has its **own** Lua state. Packages cannot see each other's globals.
- Scripts run on the UI thread, never the audio thread.
- Scripting is on by default. Holding Shift while Transcend starts is safe mode: no package loads.
  Setting the environment variable `TRANSCEND_EXTENSIONS=0` switches scripts off; themes and
  layouts still work.

### 1.5 Developing: New Package, Load Folder and Export

**Themes and layouts need no code.** **Browser > Extensions > Themes > New Theme Package...** writes
the colours on screen as a package (`theme.json` with every colour role, and a README listing them);
**Browser > Extensions > Layouts > New Layout Package...** does the same for the workspace. Both are
linked and made active, and the folder opens: edit the JSON and save, and Transcend recolours (or
re-applies the layout) at once. Only the ACTIVE theme or layout re-applies on save; editing another
one says in the Console how to pick it. This works with scripting switched off.

- **Settings > Packages > New Package...** creates a ready-to-edit package folder (manifest,
  starter script, README) plus editor set-up: `.transcend/transcend.d.lua` (LuaLS type
  definitions for this whole API) and `.luarc.json` pointing the Lua language server at it, then
  loads the folder. The same definitions file is published next to this reference as
  `transcend.d.lua`; an AI assistant can use it as a precise, machine-readable version of
  sections 2 to 9 and 13.
- **Settings > Packages > Load Folder...** runs a package straight from a folder anywhere on disk.
  It gets the same checks and the same permission prompt as installing a `.tpkg`, then shows as
  **Linked**. Edit the files and save: a linked folder **reloads by itself** within about a second
  of the save, and the Console says which file changed (or why it could not reload). **Reload
  Scripts** still works for a package that is not linked. Transcend never modifies or deletes a
  linked folder; **Unlink** only stops loading it. Folders whose names start with `.` (such as
  `.git`) and `node_modules` are ignored, and a folder of more than 2,000 files is not watched.
- A linked folder that later gains scripts or a permission it did not have when approved stops
  loading until the user picks it with Load Folder again and approves the change.
- A `.tpkg` cannot be installed while a folder with the same id is linked, and a folder cannot be
  linked while a package with its id is installed.
- **Export .tpkg...** packs the selected package, leaving out dot-files and folders (`.git`,
  `.vscode`, `.DS_Store`), hidden files and `__MACOSX`, and refusing symbolic links. The result is
  checked with the installer's own rules before it is written.
- To check your logic without opening the DAW, run the package's tests with
  `Transcend --test-extension` (section 14).

---

## 2. `transcend.api`, `transcend.app`, `transcend.permissions`

| Member | Returns | Notes |
|---|---|---|
| `transcend.api.level` | number | API level of this host (13). A field, not a function. |
| `transcend.api.has(name)` | boolean | Does this host implement `name`? Takes a surface path such as `"midi.send"`, `"panels.create"`, `"project.notes"`, or `"events.<hookName>"`. Unknown names return `false`. |
| `transcend.app.version` | string | App version, e.g. `"0.7.3"`, or `"0.7.3.1"` with a hotfix number. A field. It moves independently of `api.level`. |
| `transcend.permissions.has(name)` | boolean | Was this package granted permission `name` (a manifest permission name such as `"midi.out"`)? Unknown names return `false`. |

`api.has` asks whether the **host** has a function. `permissions.has` asks whether the **package**
may use a capability. They are independent; check both where both apply:

```lua
local canSendMidi = transcend.api.has("midi.send") and transcend.permissions.has("midi.out")
```

`network` and `process.spawn` grant nothing yet.

Some surface paths worth knowing for probing newer features: `"project.currentInstrument"` (11),
`"project.tempoAt"` (12), `"launcher.active"` (8), `"menus.add"` (10),
`"panels.placement.sidebar"`, `"panels.placement.page"`, `"panels.onDrawStatic"` (7),
`"panels.placement.window"` (10), `"panels.option.mixer"`, `"panels.mixerLayout"`,
`"panels.draw.clipPreview"` (13).

---

## 3. `transcend.project` (read only)

| Function | Returns |
|---|---|
| `project.tempo()` | number, BPM. For a song with tempo changes, use `tempoAt` (section 3.1) |
| `project.trackCount()` | number |
| `project.name()` | string |
| `project.patterns()` | array of pattern tables |
| `project.activePattern()` | string id of the pattern open in the piano roll, or `nil` |
| `project.currentInstrument()` | number: the plugin id of the instrument the user is playing (the one they last opened or picked, which a new pattern starts on), or `nil` (API level 11) |
| `project.notes(patternId)` | array of note tables; `nil` if no such pattern; `{}` if the pattern is empty |
| `project.tracks()` | array of track tables, in index order (API level 5) |
| `project.clips()` | array of clip tables, in song order: by start time, then track (API level 5) |
| `project.playhead()` | number, seconds. The song position, or the pattern position when Transcend is in Pattern mode (API level 5) |
| `project.isPlaying()` | boolean (API level 5) |
| `project.samples()` | array of sample tables: the Samples bin, in its own order (API level 6) |
| `project.plugins()` | array of plugin tables: every loaded plugin (API level 7) |
| `project.parameters(pluginId)` | array of parameter tables, or `nil` if no such plugin is loaded (API level 7) |
| `project.parameterValue(pluginId, paramId)` | number from 0 to 1, or `nil` for an unknown plugin or parameter (API level 7) |
| `project.tempoAt(seconds?)` | number, the BPM in force there (API level 12) |
| `project.beatsAt(seconds?)` | number, quarter notes from the song's start (API level 12) |
| `project.secondsAtBeats(beats)` | number, the inverse of `beatsAt` (API level 12) |
| `project.meter(seconds?)` | two numbers, `num, den`: the time signature in force there (API level 12) |
| `project.barAt(seconds?)` | number, a bar count: `1.0` is bar 1's downbeat, `2.5` is halfway through bar 2 (API level 12) |
| `project.secondsAtBar(bar)` | number, the inverse of `barAt` (API level 12) |
| `project.key()` | key table, or `nil` when the song has no key (API level 12) |
| `project.markers()` | array of marker tables, in time order (API level 12) |
| `project.loop()` | two numbers, `startSeconds, endSeconds`, or `nil` when no loop is on (API level 12) |
| `project.selection()` | selection table (API level 12) |
| `project.controllers(patternId)` | array of controller points, or `nil` if no such pattern (API level 12) |

**Pattern table:**

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `name` | string | |
| `beats` | number | |
| `noteCount` | number | |
| `pluginId` | number | The instrument the pattern plays, `0` for none (API level 11). |
| `hasSample` | boolean | The built-in sampler plays a sample (API level 11). With `pluginId` 0 and no sample, the pattern's notes play nothing. |

**Note table:**

| Field | Type | Notes |
|---|---|---|
| `uid` | number | Identity for this session only. Never persist it. |
| `note` | number | MIDI note number, 0 to 127. |
| `velocity` | number | 1 to 127. |
| `startStep` | number | **Fractional.** One step is a 1/16 note. |
| `lengthSteps` | number | **Fractional.** |
| `pluginId` | number | `0` means the pattern's own instrument. |

**Track table** (API level 5):

| Field | Type | Notes |
|---|---|---|
| `index` | number | **Starts at 0.** Track N is mixer channel N. Pass this to the `track.*` actions. |
| `name` | string | The name on the arrangement's track header. |
| `kind` | string | `"track"`, `"folder"`, `"vca"` or `"take"`. A folder or VCA cannot hold clips. |
| `muted` | boolean | |
| `soloed` | boolean | |
| `volume` | number | Linear fader gain. `1.0` is 0 dB, `0.5` is about -6 dB. |
| `pan` | number | `-1` (left) to `1` (right). |
| `color` | number | The track's colour as `0xRRGGBB`, the colour its header and clips wear. Absent when none is assigned (API level 8). |
| `bandColor` | number | The tone a clip's name band and the mixer strip's name plate are painted in, `0xRRGGBB` (API level 13). Absent without a colour, like the three below. |
| `bodyColor` | number | A clip's body tone (API level 13). |
| `nameColor` | number | The ink written on the name band (API level 13). |
| `contentColor` | number | The ink of a clip's waveform or notes (API level 13). |

Use the four tones (level 13) to draw something that matches the track's clips and mixer strip.

**Clip table** (API level 5):

| Field | Type | Notes |
|---|---|---|
| `uid` | number | Pass it to the `clip.*` actions. Use it for a clip you just read, not as a key saved for the next session. |
| `track` | number | Track index (starts at 0). |
| `name` | string | |
| `startSeconds` | number | |
| `lengthSeconds` | number | For a pattern clip, its length at the current tempo. |
| `pattern` | boolean | `true` for a pattern clip, `false` for audio. |
| `patternId` | string | Pattern clips only. Pass it to `project.notes`. |
| `path` | string | Audio clips only (API level 6). The file the clip plays; pass it to `clip.placeAudio` to place another copy. |
| `muted` | boolean | |
| `selected` | boolean | |

**Sample table** (API level 6): one row of the Samples bin.

| Field | Type | Notes |
|---|---|---|
| `path` | string | The file. This is what `clip.placeAudio` takes. |
| `name` | string | The row's name in the bin. The user can rename it. |
| `lengthSeconds` | number | `0` until the file has finished loading. |
| `ready` | boolean | `true` once the file has loaded. `clip.placeAudio` declines a file that is not ready. |

A file added to the bin twice has two rows with the same `path`.

**Plugin table** (API level 7): one loaded plugin.

| Field | Type | Notes |
|---|---|---|
| `id` | number | Pass it to `project.parameters`, `plugin.setParameter`, `pattern.setInstrument` and `note.preview`. It changes when the project is reopened, so never save it. |
| `name` | string | |
| `format` | string | `"stock"`, `"vst3"`, `"vst2"`, `"clap"` or `"au"` |
| `track` | number | The track (and mixer channel) it is on, or `-1` |
| `role` | string | `"instrument"`, `"insert"` (the track's effects), `"master"` (the master effects, `track` is -1) or `"global"` (on no track) |
| `slot` | number | Its position among the effects, for `"insert"` and `"master"`; otherwise `-1` |
| `instrument` | boolean | `true` when the plugin plays notes (API level 9). |

An instrument chosen in the piano roll plays through its pattern's track but reads as `"global"`:
only routing the user set up counts as `track`.

**Parameter table** (API level 7): the same list the Add Automation picker shows.

| Field | Type | Notes |
|---|---|---|
| `id` | number | What `plugin.setParameter` takes. Not a position in the list, and it can be larger than 2,147,483,647 (VST3). |
| `name` | string | |
| `value` | number | From 0 to 1, for every plugin format |
| `min`, `max` | number | The plugin's own units (0 and 1 for VST3 and VST2). The value as the plugin shows it is `min + value * (max - min)`. |
| `default` | number | From 0 to 1. VST2 plugins have no default, so this is their current value. |

A big synth has thousands of parameters. Call `parameters` once and use `parameterValue` to watch
one. An isolated (out-of-process) VST3 lists no parameters. Automation lanes are not in the API.

These are copies. Nothing here changes the project: writes go through the actions in section 9.

### 3.1 Musical context (API level 12)

Every position is in **song seconds**, and a position you leave out is the playhead. A "beat" is a
**quarter note** counted from bar 1, the unit the tempo counts in, whatever the time signature.
`beatsAt` and `secondsAtBeats` follow the tempo map; `barAt` and `secondsAtBar` follow the tempo
map and the time-signature changes together. They are right across tempo and meter changes, where
`60 / project.tempo()` is not.

```lua
-- The start of the bar after the playhead, right across tempo and time-signature changes.
local nextBar = math.floor(transcend.project.barAt()) + 1
local t = transcend.project.secondsAtBar(nextBar)

-- Functions that return two numbers:
local num, den = transcend.project.meter()     -- 6, 8 for 6/8
local a, b = transcend.project.loop()          -- nil when no loop is on
if a then print(string.format("loop %.2f to %.2f s", a, b)) end
```

**Key table** (`project.key()`):

| Field | Type | Notes |
|---|---|---|
| `root` | number | Pitch class of the key note, `0` = C. |
| `rootName` | string | e.g. `"A"`, `"F#"`. |
| `scale` | string | e.g. `"Major"`, `"Minor"`, `"Dorian"`. |
| `notes` | array of numbers | The scale's pitch classes, starting at the root. A minor is `{9, 11, 0, 2, 4, 5, 7}`. |

**Marker table** (`project.markers()`):

| Field | Type | Notes |
|---|---|---|
| `id` | number | Stable while the project is open. |
| `name` | string | |
| `beats` | number | Where it sits, in quarter notes. A marker keeps its beat when the tempo changes. |
| `seconds` | number | Where that is now. |
| `color` | number | `0xRRGGBB`. Absent when not set (the theme's accent is used). |
| `tempo` | number | Only on a tempo change: the BPM from this marker on. |
| `sigNum`, `sigDen` | number | Only on a time-signature change. |

**Selection table** (`project.selection()`):

| Field | Type | Notes |
|---|---|---|
| `clips` | array of numbers | Uids of the selected arrangement clips. |
| `notes` | array of numbers | Uids of the selected notes in the piano roll's open pattern. |
| `notesPattern` | string | The pattern those notes belong to. Absent when no pattern is open. |

**Controller point** (`project.controllers(patternId)`): the piano roll's event lane, in step order.

| Field | Type | Notes |
|---|---|---|
| `controller` | number | `-1` is pitch bend; otherwise the CC number, 0 to 127. |
| `step` | number | Position on the pattern's step grid (a step is a 1/16 note). |
| `value` | number | 0 to 127, or 0 to 16383 for pitch bend (8192 is the centre). |
| `pluginId` | number | `0` means the pattern's instrument. |

Writing controller points is not in the API yet.

---

## 4. `transcend.actions`

| Function | Returns | Notes |
|---|---|---|
| `actions.invoke(id, params?)` | boolean, and sometimes a second value | Runs an action. `false` means it **declined** (for example, the wrong panel has focus). A decline is logged, not raised. An action that creates something also returns what it created (API level 6, section 9.2). |
| `actions.register(id, name, handler, opts?)` | string | API level 3. Adds a command to the palette and the Shortcuts settings. Returns the full id. |
| `actions.list()` | array | Every registered action: `id`, `name`, `scope`, `undoable`, `provider` (`""` for built-in). |

### `actions.register(id, name, handler, opts)`

| Argument | Rules |
|---|---|
| `id` | Matches `^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$`. Automatically prefixed with the package id: `"ramp"` in `com.you.pkg` becomes `com.you.pkg.ramp`. |
| `name` | Required. What the user sees in the command palette. |
| `handler` | `function(params) -> boolean`. Return `false` to decline. A handler that creates something can `return true, created` (a string or number, API level 6), and whatever invoked the command gets it as `actions.invoke`'s second value. Gets 10,000,000 instructions, or 200,000 when a hook handler invoked it (section 10). |
| `opts.undoable` | Default `false`. When `true`, everything the handler does is one undo step. |
| `opts.scope` | `"global"` (default), `"timeline"`, `"pianoroll"` or `"mixer"`. A scoped action declines when that area does not have focus. |

Registering the same id again replaces its handler. At most 64 actions per package. Registered
commands start with no key binding; the user can assign one in Settings > Shortcuts. A registered
action can also be put in a right-click menu (section 13) or mapped to a MIDI controller
(section 6.2).

---

## 5. `transcend.events` (API level 2)

| Function | Returns | Notes |
|---|---|---|
| `events.on(hookName, fn)` | boolean | `false` if this host does not fire that hook. At most 32 handlers per hook per package. |
| `events.off(hookName)` | boolean | Removes all of this package's handlers for that hook. |
| `events.names()` | array | Every hook name this host fires. |

Each handler receives one table:

| Hook | Payload fields |
|---|---|
| `transportStarted` | `mode` (`"song"` or `"pattern"`), `seconds`, `tempo` |
| `transportStopped` | `mode`, `seconds`, `tempo` |
| `playheadMoved` | `seconds`, `beats`, `mode`, `playing` (boolean) |
| `selectionChanged` | `view` (`"timeline"`), `count` |
| `notePlayed` | `note`, `velocity`, `channel`, `source` (`"midi"`) |
| `clipAdded` | `uid`, `track`, `startSeconds`, `lengthSeconds`, `name`, `pattern` (boolean) |
| `clipRemoved` | `uid`, `track`, `name` |
| `projectLoaded` | `path`, `name` |
| `projectSaved` | `path`, `name` |
| `parameterChanged` | `target` (`"mixer"`), `channel` (`-1` = master), `parameter` (string), `value` |
| `trackAdded` | `index`, `count` |
| `trackRemoved` | `index`, `count` |
| `notesChanged` | `patternId`. API level 12: a pattern's notes, steps, controller lanes or length really changed. |
| `activePatternChanged` | `patternId`, absent when no pattern is open. API level 12: the pattern the piano roll edits changed. |
| `tempoChanged` | `bpm`, the base tempo (the tempo before the first tempo change). API level 12: the base tempo or any tempo marker changed. Read the map with `tempoAt` / `beatsAt`. |
| `meterChanged` | `num`, `den`, the base time signature. API level 12: the base time signature or any signature marker changed. |
| `keyChanged` | `root` (number) and `scale` (string), both absent when the song now has no key. API level 12. |
| `markersChanged` | no fields. API level 12: a marker was added, moved, renamed, recoloured or removed. |

- Handlers run synchronously on the UI thread with a budget of **200,000 instructions** per call.
- `playheadMoved` fires at most once per UI frame, only when the position changed. It is not a
  sample clock.
- `projectLoaded` fires for every project opened, including the one picked on the start screen,
  which is delivered right after packages load.
- `notePlayed` is note-ons from MIDI input only.
- **The level-12 hooks are checked once per UI frame and combined.** A drag that moves a tempo
  marker sixty times a second fires one `tempoChanged` per frame, a gesture that rewrites a pattern
  several times fires one `notesChanged`, and changing a pattern's instrument (which does not change
  its content) fires none. **Opening a project fires `projectLoaded` only**, not these.
- A handler that raises an error is switched off for this package. Calling `events.on` again
  re-arms it.
- A hook cannot re-trigger itself, and chains of hooks triggering hooks stop at depth 8.
- Hook handlers are not wrapped in an undo step; each undoable action they invoke is its own step.

---

## 6. `transcend.midi` (API level 2)

### 6.1 Output: needs the `midi.out` permission and a user-chosen device

The user picks which devices a package may use in Settings > Packages > MIDI Devices. Until they
do, the package can send nothing, which is the normal state after install. `device` is a
**1-based index into the package's granted list**, never a system port number.

| Function | Returns | Notes |
|---|---|---|
| `midi.devices()` | array | Granted devices only: `device` (number), `name` (string), `connected` (boolean). |
| `midi.send(device, status, data1?, data2?)` | boolean | Channel-voice status bytes only (`0x80` to `0xEF`). Anything from `0xF0` up, including sysex, raises an error. |
| `midi.noteOn(device, channel, note, velocity?)` | boolean | `velocity` defaults to 100. |
| `midi.noteOff(device, channel, note)` | boolean | |
| `midi.cc(device, channel, controller, value?)` | boolean | `value` defaults to 0. |

`channel` is 0 to 15. Constants: `transcend.midi.NOTE_OFF` (0x80), `NOTE_ON` (0x90),
`AFTERTOUCH` (0xA0), `CC` (0xB0), `PROGRAM` (0xC0), `CHANNEL_PRESSURE` (0xD0),
`PITCH_BEND` (0xE0).

Sysex is refused because it is how a device's firmware is rewritten, and an extension must not be
one typo away from damaging a synth.

### 6.2 Controller mapping: no permission needed

| Function | Returns | Notes |
|---|---|---|
| `midi.map(match, actionId, params?)` | number | `match` is `{ status = , channel = , data1 = }`; every field is optional and an omitted field matches anything. Returns a mapping id. |
| `midi.unmap(mappingId)` | boolean | |

When an incoming message matches, the action is invoked with `params` plus the message's own
`status`, `channel`, `data1`, `data2` and `value`. Mappings only observe: a mapped note still reaches
the instrument and pads. At most 256 mappings per package.

```lua
-- Any CC 74 on any channel runs one of this package's commands.
transcend.midi.map({ status = 0xB0, data1 = 74 }, "com.you.pkg.filterSweep")
```

---

## 7. `transcend.panels` (API level 4)

A panel is something your script draws. A script never draws directly: its draw handler appends
commands to a list, and the host draws the list afterwards. By default a panel is a tab in a dock
under the arrangement (View > Extension Panels). The `placement` option puts it somewhere else.

**Sidebar (API level 7).** `panels.create(id, { placement = "sidebar" })` puts the panel on the
Browser's home screen as a card instead; clicking the card opens the panel in the sidebar. It draws
the same way and has the same limits. Check `transcend.api.has("panels.placement.sidebar")` first:
an older Transcend ignores the option. If another card already has your title, yours is shown with
your package id after it.

**Page (API level 7).** `placement = "page"` makes the panel a whole page in the workspace, beside
the arrangement, the piano roll and the mixer, with its own button in Transcend's main bar next to
theirs. Give it an icon with `icon = "images/mypage.svg"` (an SVG in your package, up to 256 KB;
not in an `icons/` folder, which replaces Transcend's own icons). The icon is drawn as a single
shape in the bar's colours, so it matches the other buttons in every theme; without one, the button
shows the first letter of the title. Clicking the button again goes back to the arrangement. A
layout can move the button with the key `page.` followed by the panel id; a layout that does not
name it puts it after the workspace buttons. The page also opens from View > Extension Pages and
Windows and from the command palette ("Open Page: " and its title). A page covers the whole
workspace, so redraw it only when something it shows changes (call `transcend.panels.invalidate`
from an event handler) rather than every frame. Check `transcend.api.has("panels.placement.page")`
first.

**Page with the real mixer under it (API level 13).** `mixer = true` on a page docks Transcend's own
mixer under the page while it is on screen. These are the real mixer strips, the same as View >
Mixer, not a drawing of them. When the user leaves the page, the mixer closes again if the page is
what opened it. Under such a page the mixer's Channel Inspector moves between the strips and the
master, so the strips start at the page's left edge. `panels.mixerLayout(id)` says where each strip
is in your panel's own coordinates, so the page can line its columns up over them. Read it in the
draw handler, because the strips move when the mixer scrolls or the window resizes. The Clip
Launcher page that ships with Transcend works this way: its columns sit over the strips. Check
`transcend.api.has("panels.option.mixer")` first.

**Window (API level 10).** `placement = "window"` puts the panel in a floating window of its own. It
stays above the DAW, has no taskbar entry, follows the theme, and sits beside the arrangement, which
a page (replacing the workspace) cannot. `width` and `height` set its size the first time it opens
(default 480 x 360, never below `minWidth` / `minHeight`); after that, the size and place the user
gives it are remembered. **It opens only when asked**: from View > Extension Pages and Windows
and windows, from the command palette ("Open Window: " and its title), or from your own
`panels.show(id)` in an action, a menu entry (section 13) or a click. Never open it when the package
loads. Closing it hides it, and a hidden panel runs no script. Check
`transcend.api.has("panels.placement.window")` first.

**Static layer (API level 7).** A panel that is mostly still with one moving part, such as a
playhead over a song, should use a static layer: draw the still part in `panels.onDrawStatic(id,
fn)` and only the moving part in `panels.onDraw`. Transcend keeps what the static handler drew as a
picture and paints the `onDraw` drawing over it, repainting only the area that drawing covers. The
static handler runs only when that layer is invalidated, the panel is resized or the theme changes.
Call `panels.invalidate(id, "dynamic")` when only the moving part changed and `panels.invalidate(id)`
when everything did. With a static layer, `onDraw` must not call `g.clear()`, because that would
paint over the picture. Check `transcend.api.has("panels.onDrawStatic")` first.

### 7.1 Lifecycle

| Function | Returns | Notes |
|---|---|---|
| `panels.create(id, opts?)` | string, the full id | Re-creating an existing id replaces it. Re-creating it with another placement moves it. At most 8 panels per package. |
| `panels.destroy(id)` | boolean | Also removes its handlers. |
| `panels.onDraw(id, fn)` | boolean | `fn(g, ctx)`. Re-registering re-arms a panel whose draw raised an error. |
| `panels.onInput(id, fn)` | boolean | `fn(e) -> boolean`. |
| `panels.onDrawStatic(id, fn)` | boolean | API level 7. The static layer, drawn once and kept as a picture. `nil` removes it. |
| `panels.invalidate(id, layer?)` | boolean | Request a redraw at the next allowed moment. `layer` (API level 7): `"dynamic"`, `"static"`, or omitted for both. A misspelt layer raises an error. |
| `panels.setTitle(id, title)` | boolean | |
| `panels.setRedraw(id, mode)` | boolean | `"onDemand"` (default) or `"continuous"`. |
| `panels.list()` | array | This package's panels: `id`, `title`, `visible`, `width`, `height`, `placement`. |
| `panels.isVisible(id)` | boolean | Is this panel on screen? |
| `panels.show(id)` | boolean | API level 10. Brings the panel into view wherever it lives: the dock opens on its tab, a page becomes the workspace, a window opens or comes to the front. A sidebar card returns `false` (the Browser is the user's to navigate). Refused during a draw. |
| `panels.mixerLayout(id)` | table | API level 13. Where the docked mixer's strips are, in this panel's coordinates (below). |

`opts` for `create`:

| Option | Notes |
|---|---|
| `title` | string |
| `minWidth`, `minHeight` | 40 to 4000 |
| `redraw` | `"onDemand"` (default) or `"continuous"` |
| `placement` | `"dock"` (default), `"sidebar"`, `"page"` (API level 7) or `"window"` (API level 10). A misspelt placement raises an error. |
| `icon` | A page's button icon (API level 7): the path of an `.svg` in your package. |
| `width`, `height` | A window's size the first time it opens (API level 10). |
| `mixer` | `true` on a page: the docked mixer sits under it while it is on screen (API level 13). |

Ids are prefixed with the package id like action ids; every function accepts the short or full
form.

A page also gets a command `page.open.` followed by its full panel id, and a window gets
`window.open.` followed by its full panel id. Both disappear when the panel does.

**`panels.mixerLayout(id)` returns** `{ strips = { {track, x, y, w, h}, ... }, master = {x, y, w, h} }`.
`track` is the track (and mixer channel) the strip shows. While the mixer is not docked on screen,
`strips` is empty and `master` is `nil`.

Redraw is on demand: call `panels.invalidate(id)` when your data changes. Use `"continuous"` only
for something animated.

### 7.2 Draw handler: `function(g, ctx)`

`ctx`: `w`, `h` (logical pixels), `dpr` (device pixel ratio), `time` (seconds, monotonic).

`g` works only while the draw handler is running; storing it and calling it later raises an error.

| Call | Notes |
|---|---|
| `g.clear(color, alpha?)` | Fill the panel. |
| `g.rect(x, y, w, h, color, alpha?)` | Filled. |
| `g.rectOutline(x, y, w, h, color, penWidth?, alpha?)` | `penWidth` defaults to 1. |
| `g.roundRect(x, y, w, h, radius, color, alpha?)` | Filled. |
| `g.line(x1, y1, x2, y2, color, penWidth?, alpha?)` | |
| `g.ellipse(cx, cy, rx, ry, color, alpha?)` | Centre and radii, not a bounding box. |
| `g.ellipseOutline(cx, cy, rx, ry, color, penWidth?, alpha?)` | |
| `g.text(x, y, str, color, size?, align?, alpha?)` | `size` defaults to 12. `align` contains `"left"`, `"center"` or `"right"`, optionally with `"bold"`, e.g. `"center bold"`. **`y` is the text baseline.** |
| `g.polyline(points, color, penWidth?, alpha?)` | `points` is flat: `{x1, y1, x2, y2, ...}`. |
| `g.polygon(points, color, alpha?)` | Flat points, closed and filled. |
| `g.clip(x, y, w, h)` / `g.clipReset()` | |
| `g.clipPreview(uid, x, y, w, h, color, alpha?)` | API level 13. The picture of one arrangement clip, drawn by Transcend into the rectangle in `color`: an audio clip's waveform (one filled shape, scaled to the clip's loudest moment) or a pattern's notes. The same picture the clip strips in the bins show. `uid` comes from `project.clips()`; an unknown uid draws nothing. Check `transcend.api.has("panels.draw.clipPreview")` first. |
| `g.themeColor(role)` | `0xRRGGBB` for the active theme, or `nil` for an unknown role. Always give a fallback: `g.themeColor("accent") or 0x2ad4ff`. Known roles include `panelBg`, `accent`, `textBright`. |

Colours are `0xRRGGBB` integers; alpha is a separate optional number from 0 to 1.

While a draw handler is running, `actions.invoke`, `panels.create`, `panels.destroy`,
`panels.show` and `files.write` refuse. Compute in the draw handler; act from input handlers and
hooks.

### 7.3 Input handler: `function(e) -> boolean`

| Field | Notes |
|---|---|
| `type` | `"press"`, `"release"`, `"move"`, `"wheel"`, `"enter"`, `"leave"`, `"key"` |
| `x`, `y` | Panel-local logical pixels, the same space as drawing. |
| `button` | 1 left, 2 right, 4 middle; 0 for move, wheel and key. |
| `mods` | Bitmask: 1 Shift, 2 Ctrl, 4 Alt. |
| `delta` | Wheel notches, +1 per notch away from the user. |
| `key` | Qt key code for `"key"`, otherwise 0. |
| `text` | The typed character, or `""`. |

Return `true` only when the panel used the event. Returning `false` or nothing lets it through to
the app. Input handlers have the 200,000-instruction hook budget.

### 7.4 Limits

| Limit | Value | When exceeded |
|---|---|---|
| Draw instruction budget | 500,000 | The draw is aborted; the previous frame stays on screen. |
| Commands per frame | 20,000 | Truncated. |
| Text per frame | 256 KB | Text that does not fit is not drawn. |
| Polyline points per frame | 100,000 | That call draws nothing. |
| Time budget | 40 ms per second | The panel's redraw interval is stretched (between 16 ms and 1000 ms) to fit. |

Hidden panels cost nothing. A draw that raises an error keeps the last frame and disables that
panel's drawing until `onDraw` is called again. A static layer's script time counts toward the same
budget as `onDraw`'s.

---

## 8. `transcend.state` and `transcend.files`

### 8.1 State (no permission needed)

| Function | Returns | Notes |
|---|---|---|
| `state.get(key)` | string, number, boolean or `nil` | |
| `state.set(key, value)` | | `nil` erases the key. Only `nil`, boolean, number and string can be stored. |
| `state.keys()` | array of strings | |

Keys are 1 to 256 characters; values up to 64 KB; at most 512 keys. State is private to the
package, survives restarts, reloads and updates, and is deleted when the package is removed.

### 8.2 Files

| Function | Returns | Needs |
|---|---|---|
| `files.readPackageFile(relativePath)` | string | Nothing. Reads from the package's own folder; no absolute paths or `..`. |
| `files.read(absolutePath)` | string | `files.read` permission **and** a folder the user granted. |
| `files.write(absolutePath, contents)` | | `files.write` permission **and** a granted folder. At most 1 MB. |

**In the beta there is no way for a user to grant a folder**, so `files.read` and `files.write`
always refuse. All three functions raise an error on refusal instead of returning `nil`.

---

## 9. Built-in actions

Invoke these with `transcend.actions.invoke(id, params)`. `transcend.actions.list()` returns the
live list, including other packages' commands. Actions scoped to one area decline when that area
does not have focus.

### 9.1 `pattern.setNotes`: the way to edit notes

Replaces all notes in a pattern. Undoable.

| Param | Notes |
|---|---|
| `patternId` | Optional; defaults to the open pattern. |
| `notes` | Array of `{ note, velocity, startStep, lengthSteps, pluginId }`. Omitted fields default to note 60, velocity 100, start 0, length 1, pluginId 0. Do not pass `uid`. At most 20,000 notes. |

**Declines (returns `false`) if the pattern is not placed on the arrangement.** Controller data
(pitch bend, CC lanes) is kept unchanged.

```lua
local id = transcend.project.activePattern()
if id then
    local out = {}
    for _, n in ipairs(transcend.project.notes(id) or {}) do
        out[#out + 1] = { note = n.note, velocity = n.velocity, startStep = n.startStep,
                          lengthSteps = n.lengthSteps * 0.5, pluginId = n.pluginId }
    end
    transcend.actions.invoke("pattern.setNotes", { patternId = id, notes = out })
end
```

### 9.2 Actions that take parameters (API levels 5 to 11)

These take parameters, so they are not in the command palette. Each one does exactly what the same
edit by hand does: the clip actions are undoable, and moving or placing a clip makes and clears
crossfades the way doing it by hand does.

| Id | Params | Undoable | Does |
|---|---|---|---|
| `clip.move` | `uid`, and `startSeconds` and/or `track` | yes | Moves a clip. `startSeconds` is exact, not snapped to the grid. `track` must be able to hold clips (not a folder or VCA). |
| `clip.delete` | `uid` | yes | Deletes a clip. |
| `clip.setMuted` | `uid`, `muted` | yes | Mutes or unmutes one clip, like the Mute tool. |
| `clip.select` | `uids`, `add` (optional) | no | Selects the listed clips. `{}` selects nothing. `add = true` keeps the current selection. |
| `track.rename` | `index`, `name` | no | Renames the arrangement track header. The mixer strip keeps its own name. |
| `track.setMute` | `index`, `muted` | no | The track's M button. |
| `track.setSolo` | `index`, `soloed` | no | The track's S button. |
| `track.setVolume` | `index`, `volume` | no | Sets the fader. Linear gain from `0` to `4`; `1.0` is 0 dB. |
| `track.setPan` | `index`, `pan` | no | `-1` (left) to `1` (right). |
| `transport.seek` | `seconds` | no | Moves the playhead. Exact, not snapped. In Pattern mode it moves the pattern playhead. The inverse of `project.playhead()`. |
| `pattern.create` | `name` (optional) | yes | API level 6. Makes a new, empty pattern, like the Patterns bin's **+ New Pattern** button. Returns the pattern id as a second value. |
| `clip.placePattern` | `patternId`, `track`, `startSeconds` | yes | API level 6. Places a copy of a pattern. `startSeconds` is exact. Returns the new clip's `uid` as a second value. |
| `clip.placeAudio` | `path`, `track`, `startSeconds` | yes | API level 6. Places a clip of a file from the Samples bin (`project.samples()`, `ready` only). Returns the new clip's `uid` as a second value. |
| `track.add` | `name` (optional) | no | Adds a track (also in section 9.3). API level 6 adds the `name` and returns the new track's `index` as a second value. Declines at the track limit (128). |
| `plugin.setParameter` | `pluginId`, `paramId`, `value` (0 to 1) | no | API level 7. Moves one plugin parameter; the plugin's own window follows. Like a fader, it is not an undo step. Automation on the same parameter takes over while the song plays. To drive it from a MIDI knob, register a command that divides `value` by 127 and map the knob to that. |
| `pattern.setInstrument` | `patternId` (optional; defaults to the open pattern), `pluginId` | no | API level 11. Gives a pattern an instrument, exactly as the piano roll's instrument box does (below). |

**Every one of them declines (returns `false`) instead of guessing** when a clip `uid` or track
`index` does not exist, a number is out of range, or a flag is not a real boolean (`muted = 1` is
refused; use `muted = true`) or a name or path is not a real, non-empty string. Nothing is changed
when an action declines.

`clip.select` is what makes `edit.copy`, `edit.duplicate` and `edit.delete` useful to a script:
select the clips, then invoke the edit action.

Each clip action is its own undo step. To make several one step, do them inside a command
registered with `undoable = true` (section 4):

```lua
-- Nudge the selected clips one beat later, as a single undo step.
-- (60 / tempo() assumes one tempo; at API level 12, use beatsAt / secondsAtBeats instead.)
transcend.actions.register("nudge-later", "Nudge Selected Clips Later", function()
    local beat = 60 / transcend.project.tempo()
    local moved = false
    for _, c in ipairs(transcend.project.clips()) do
        if c.selected then
            moved = transcend.actions.invoke("clip.move",
                { uid = c.uid, startSeconds = c.startSeconds + beat }) or moved
        end
    end
    return moved
end, { undoable = true })
```

**Creating things (API level 6).** An action that creates something returns it as a second value.
Every other call, and every decline, returns just one value.

```lua
-- A new track called "Beat" with four copies of a new one-bar pattern and a kick on every beat.
transcend.actions.register("new-beat", "New Beat on a New Track", function()
    local ok, track = transcend.actions.invoke("track.add", { name = "Beat" })
    if not ok then return false end
    local _, pid = transcend.actions.invoke("pattern.create", { name = "Beat" })
    local start = transcend.project.playhead()
    local placed, uid = transcend.actions.invoke("clip.placePattern",
        { patternId = pid, track = track, startSeconds = start })
    if not placed then return false end
    local notes = {}
    for beat = 0, 3 do
        notes[#notes + 1] = { note = 36, velocity = 110, startStep = beat * 4, lengthSteps = 1 }
    end
    transcend.actions.invoke("pattern.setNotes", { patternId = pid, notes = notes })
    local length = 0
    for _, c in ipairs(transcend.project.clips()) do
        if c.uid == uid then length = c.lengthSeconds end
    end
    for i = 1, 3 do
        transcend.actions.invoke("clip.placePattern",
            { patternId = pid, track = track, startSeconds = start + i * length })
    end
    return true, pid   -- whatever invoked this command gets the new pattern's id
end, { undoable = true })
```

Things worth knowing:

- **Place a pattern before writing its notes.** `pattern.setNotes` declines a pattern that is not on
  the arrangement yet.
- **A pattern is as long as its notes**, rounded up to whole bars. A new, empty one is one bar.
  There is no way to set a longer length.
- **`clip.placeAudio` only places files already in the Samples bin, once they have loaded.** A script
  cannot bring a new file into the project. Check `ready` in `project.samples()`.
- **Adding a track is not undoable**, just as it is not by hand. One undo of your command removes the
  patterns it created, their placements and notes, and leaves the track.
- A new pattern plays the sample last selected in the Samples bin, like **+ New Pattern** does, or
  nothing if none was selected. Use `pattern.setInstrument` to give it an instrument.

**`pattern.setInstrument` (API level 11).** It follows the piano roll's instrument box exactly:

- Notes that inherit the pattern's instrument (`pluginId` 0) follow the new instrument only when the
  pattern had no instrument before. Otherwise they stay with the instrument they were playing.
  Choosing an instrument never changes the notes already there.
- `pluginId` must be a loaded plugin that plays notes (its `instrument` field is `true`), or the
  action declines.
- It is not an undo step, like the box.
- The usual use: after writing notes into a pattern that plays nothing (`pluginId == 0` and not
  `hasSample`), give it the instrument the user is playing. Do this from a gesture in your own
  command or panel, never behind the user's back. Check
  `transcend.api.has("project.currentInstrument")` first.

```lua
local function giveInstrument(patternId)
    for _, p in ipairs(transcend.project.patterns()) do
        if p.id == patternId and p.pluginId == 0 and not p.hasSample then
            local inst = transcend.project.currentInstrument()
            if inst then
                transcend.actions.invoke("pattern.setInstrument",
                    { patternId = patternId, pluginId = inst })
            end
        end
    end
end
```

### 9.3 Everything else

These take no parameters, except that `track.add` takes an optional `name` (section 9.2) and
`launcher.stopAll` an optional `bars` (section 9.4).

| Id | Name | Scope |
|---|---|---|
| `transport.play` | Play / Pause | global |
| `transport.stop` | Stop | global |
| `transport.restart` | Restart Playback | global |
| `transport.record` | Record | global |
| `transport.recordKeep` | Stop Recording (keep take) | global |
| `transport.recordDiscard` | Stop Recording (discard take) | global |
| `transport.toggleLoop` | Toggle Loop | global |
| `transport.metronome` | Toggle Metronome | global |
| `edit.undo` | Undo | global |
| `edit.redo` | Redo | global |
| `edit.cut` | Cut | global |
| `edit.copy` | Copy | global |
| `edit.paste` | Paste | global |
| `edit.duplicate` | Duplicate Selection | global |
| `edit.delete` | Delete Selection | global |
| `roll.selectAll` | Select All Notes | pianoroll |
| `track.add` | Add Track | global |
| `track.addVca` | Add VCA | global |
| `track.group` | Group Tracks | timeline |
| `view.zoomIn` | Zoom In | timeline |
| `view.zoomOut` | Zoom Out | timeline |
| `view.mixer` | Toggle Mixer | global |
| `view.pianoRoll` | Toggle Piano Roll | global |
| `view.stepSequencer` | Toggle Step Sequencer | global |
| `view.padSampler` | Toggle Live Trigger | global |
| `view.browser` | Toggle Browser | global |
| `view.plugins` | Toggle Plugin Panel | global |
| `view.extensionPanels` | Toggle Extension Panels | global |
| `view.changes` | Changes Since Last Save | global |
| `view.versions` | Project Versions | global |
| `file.new` | New Project | global |
| `file.open` | Open Project | global |
| `file.save` | Save Project | global |
| `file.saveAs` | Save Project As | global |
| `file.importMidi` | Import MIDI File | global |
| `file.importAudio` | Import Audio File | global |
| `file.export` | Export... | global |
| `help.shortcuts` | Shortcuts Cheat Sheet | global |
| `help.reportBug` | Report a Bug | global |
| `palette.open` | Command Palette | global |

`launcher.stopAll` (section 9.4) is also in the command palette; called with no `bars`, it stops
every launched clip on the next bar.

`edit.*` actions act on whichever area has focus, exactly like the keyboard shortcuts.

Each page and window panel also adds a command of its own: `page.open.<full panel id>` and
`window.open.<full panel id>` (section 7.1).

### 9.4 The clip launcher (API level 8)

Start a clip or a pattern **on the next N-bar boundary**, loop it, and stop it on a boundary. The
timing is done by Transcend's audio engine: it picks the boundary from the song's tempo and
time-signature changes and starts the clip exactly on the bar line. A script runs on the UI thread
and cannot do that itself, which is why the launcher is built in and a script only drives it. The
Clip Launcher page that ships with Transcend is itself an extension built on exactly this.

**Actions** (none is an undo step):

| Id | Params | Does |
|---|---|---|
| `launcher.setSlot` | `slot`, `uid` | Makes the slot play that arrangement clip. |
| `launcher.clearSlot` | `slot` | Empties one slot. |
| `launcher.clearAll` | none | Empties every slot. |
| `launcher.launch` | `slot`, `bars` (optional, default 1) | Starts the slot on the next boundary. |
| `launcher.stop` | `slot`, `bars` (optional) | Stops the slot on the next boundary. |
| `launcher.stopTrack` | `track`, `bars` (optional) | Stops whatever plays on that track. |
| `launcher.stopAll` | `bars` (optional, default 1) | Stops everything. It is also in the command palette. |

**Reads** on `transcend.launcher`:

| Function | Returns |
|---|---|
| `launcher.state(slot)` | `"idle"`, `"queued"` (waiting for its boundary or for Play), `"playing"`, or `"stopping"` (playing, with a stop waiting for its boundary) |
| `launcher.progress(slot)` | number from 0 to 1 through the loop while the slot plays, otherwise `nil` |
| `launcher.active()` | array of `{ slot, state, progress }` for every slot that is not idle (`progress` may be absent). One read of the whole table: use this to draw, not `state()` for each cell. |

How it behaves:

- A **slot** is a number you choose, `0` to `1023`.
- `launcher.setSlot` builds the slot from the clip as the song plays it: an audio clip's audio as it
  sounds (crop, stretch, gain), or a pattern's played notes (MIDI effects applied) on its plugin
  instruments, its step lanes and its one-shot samples. One pass of the loop is the pattern's
  length, or the audio clip's length rounded to a sixteenth note. Setting a slot again while it
  plays keeps its place in the loop.
- `launcher.setSlot` declines (with a reason in the status bar) for a clip whose notes play on the
  built-in sampler, which the launcher cannot play yet.
- `bars` is the quantisation: `1` = the next bar line, `2`, `4` or `8` = the next 2-, 4- or 8-bar
  boundary counted from bar 1, `0` = at once. "At once" and every boundary are at least a few tens
  of milliseconds away, so a click just before a bar line takes effect on the bar after.
- **One clip per track.** A slot's track is its clip's track (or the mixer strip the clip is routed
  to). A launch on a track ends what plays there on the boundary where it starts. Launching a slot
  that is playing restarts it.
- `launcher.launch` **starts the song transport** when it is stopped. The launch then begins on the
  first boundary at or after where playback starts. Stopping the transport ends every launch.
- Launched clips play **on top of** the arrangement, through their track's fader, effects,
  mute/solo and meter.

Check `transcend.api.has("launcher.active")` first.

```lua
-- Launch the first selected clip on the next bar (needs API level 12 for selection()).
transcend.actions.register("launchSelected", "Launch Selected Clip", function()
    local uid = transcend.project.selection().clips[1]
    if not uid then return false end
    if not transcend.actions.invoke("launcher.setSlot", { slot = 0, uid = uid }) then
        return false
    end
    return transcend.actions.invoke("launcher.launch", { slot = 0, bars = 1 })
end)
```

### 9.5 `note.preview`: sounding notes (API level 9)

Plays notes on an instrument for a moment and releases them by itself: a practice game, an ear
trainer, a "hear this chord" button. Nothing is written to the project and nothing goes on the undo
stack. The Chord Practice page that ships with Transcend is built on it.

| Id | Params |
|---|---|
| `note.preview` | `notes` (array of MIDI notes 0 to 127, at most 16), `velocity` (optional, 1 to 127, default 96), `seconds` (optional, 0.05 to 8, default 1), `pluginId` (optional), `delay` (optional, 0 to 4 seconds), `stagger` (optional, 0 to 0.5 seconds) |
| `note.stopPreview` | none. Releases whatever is still ringing. |

- `pluginId` picks the instrument; use a plugin whose `instrument` field is `true`. Without it, the
  notes go to whatever the computer or MIDI keyboard plays right now (a plugin window in front,
  otherwise the open pattern's instrument).
- **The action declines when there is nothing to play the notes on.** Tell the user, rather than
  staying silent.
- **One preview at a time:** a new one releases the last.
- Scripts have no timer, so `delay` is how a game plays the next question a moment after the
  answer, and `stagger` spreads the notes into an arpeggio.

```lua
-- A C major chord, played as a quick arpeggio, ringing for 1.5 seconds.
local ok = transcend.actions.invoke("note.preview",
    { notes = { 60, 64, 67 }, seconds = 1.5, stagger = 0.08 })
if not ok then print("Pick an instrument first.") end
```

---

## 10. The sandbox

**Available:** the base library, `table`, `string`, `math`, `coroutine`, `utf8`, and
`os.time`, `os.clock`, `os.date`.

**`require(name)`** loads `scripts/lib/<name>.lua` from the package (dots become folders:
`require("util.math")` loads `scripts/lib/util/math.lua`). Module names may contain only letters,
digits, `_` and `.`. Text source only; precompiled bytecode is refused.

**Not available:** `io`, `package`, `debug`, `dofile`, `loadfile`, `load`, `loadstring`,
`collectgarbage`, `rawget`, `rawset`, `rawequal`, `rawlen`, `string.dump`, and every other `os`
function.

**`print`** writes to the Extension Console (Settings > Packages > Console), labelled with the
package.

| Limit | Value |
|---|---|
| Instructions for the entry script's top-level run | 10,000,000 |
| Instructions per registered command | 10,000,000 (200,000 if a hook handler invoked it) |
| Instructions per hook handler or panel input call | 200,000 |
| Instructions per panel draw | 500,000 |
| Memory per package | 64 MB |

A top-level run, command or hook that exceeds its budget is stopped and **the whole package is
unloaded**, with the reason in the Extension Console. A panel draw that exceeds its budget is
only aborted (section 7.4). Do expensive setup at the top level, where the budget is largest.

**String patterns count too.** `string.find`, `match`, `gmatch` and `gsub` run in C, but every
step of the pattern matcher is charged to the same budget as one instruction. Ordinary patterns
cost a few steps per character (a `gsub` over 1 MB of text is roughly 2 million). Patterns that
backtrack, such as several `.-` in a row against text that does not match, can cost millions of
steps on a short string and will stop the package.

---

## 11. API levels

| Level | Added |
|---|---|
| 1 | `project.*`, `actions.invoke`, `state.*`, `files.*`, `permissions.has`, `api.*`, `app.version` |
| 2 | `events.*`, `midi.*` |
| 3 | `actions.register`, `actions.list` |
| 4 | `panels.*` |
| 5 | `project.tracks`, `project.clips`, `project.playhead`, `project.isPlaying`; the arrangement actions in section 9.2 |
| 6 | `project.samples`; `path` on audio clips; `pattern.create`, `clip.placePattern`, `clip.placeAudio` and `track.add`'s `name` (section 9.2); `actions.invoke` returning what an action created |
| 7 | `project.plugins`, `project.parameters`, `project.parameterValue`; `plugin.setParameter` (section 9.2); `placement = "sidebar"` and `placement = "page"` for panels, `placement` in `panels.list()`, `panels.onDrawStatic` and the layer argument of `panels.invalidate` (section 7) |
| 8 | The clip launcher: `launcher.state`, `launcher.progress`, `launcher.active` and the `launcher.*` actions (section 9.4); `color` on tracks |
| 9 | Sound: the `note.preview` and `note.stopPreview` actions (section 9.5); `instrument` on plugin tables |
| 10 | Windows and menus: `placement = "window"` and `panels.show` (section 7); `transcend.menus` (section 13) |
| 11 | A pattern's instrument: `pluginId` and `hasSample` on pattern tables, `project.currentInstrument()`, the `pattern.setInstrument` action (section 9.2) |
| 12 | Musical context: `project.tempoAt`, `beatsAt`, `secondsAtBeats`, `meter`, `barAt`, `secondsAtBar`, `key`, `markers`, `loop`, `selection`, `controllers` (section 3.1); the hooks `notesChanged`, `activePatternChanged`, `tempoChanged`, `meterChanged`, `keyChanged`, `markersChanged` (section 5) |
| 13 | The track tones `bandColor`, `bodyColor`, `nameColor`, `contentColor` (section 3); `g.clipPreview` (section 7.2); `panels.create`'s `mixer = true` and `panels.mixerLayout` (section 7). Probe `panels.draw.clipPreview`, `panels.option.mixer`, `panels.mixerLayout` |

A host implements every level up to its own. Prefer declaring a low `apiLevel` and probing with
`transcend.api.has` over raising the level, which makes older hosts refuse the package outright.
Nothing at an earlier level was renamed, removed or changed to make room for a later one.

---

## 12. Complete example

`manifest.json`:

```json
{
  "format": "transcend.package",
  "formatVersion": 1,
  "id": "com.yourname.octave-tools",
  "name": "Octave Tools",
  "version": "1.0.0",
  "author": "Your Name",
  "description": "Counts and transposes the notes in the open pattern.",
  "apiLevel": 3,
  "provides": ["scripts"],
  "entry": "scripts/main.lua"
}
```

`scripts/main.lua`:

```lua
print("Octave Tools loaded")

local function openPattern()
    local id = transcend.project.activePattern()
    if id == nil or id == "" then
        print("Open a pattern in the piano roll first.")
        return nil
    end
    return id
end

transcend.actions.register("countNotes", "Octave Tools: Count Notes", function()
    local id = openPattern()
    if not id then return false end
    local notes = transcend.project.notes(id) or {}
    print(string.format("%d notes in the open pattern", #notes))
    return true
end)

transcend.actions.register("octaveUp", "Octave Tools: Up an Octave", function()
    local id = openPattern()
    if not id then return false end
    local moved = {}
    for _, n in ipairs(transcend.project.notes(id) or {}) do
        moved[#moved + 1] = {
            note        = math.min(127, n.note + 12),
            velocity    = n.velocity,
            startStep   = n.startStep,
            lengthSteps = n.lengthSteps,
            pluginId    = n.pluginId,
        }
    end
    local ok = transcend.actions.invoke("pattern.setNotes", { patternId = id, notes = moved })
    if not ok then
        print("Transcend declined the edit. Is the pattern placed on the arrangement?")
    end
    return ok
end, { undoable = true })

transcend.events.on("transportStarted", function(e)
    print(string.format("Playback started at %.2f s, %.1f BPM", e.seconds, e.tempo))
end)
```

A minimal panel (API level 4) that shows the last note played on a MIDI keyboard:

```lua
if not transcend.api.has("panels.create") then return end

local NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
local last = nil   -- MIDI note number, or nil before the first note

local ID = transcend.panels.create("lastNote", { title = "Last Note", minWidth = 200 })

transcend.panels.onDraw(ID, function(g, ctx)
    g.clear(g.themeColor("panelBg") or 0x1a1d21)
    local label = "Play a note"
    if last then
        label = NAMES[last % 12 + 1] .. tostring(last // 12 - 1)
    end
    -- y is the baseline, so add about a third of the text size to centre it.
    g.text(ctx.w / 2, ctx.h / 2 + 8, label, g.themeColor("textBright") or 0xffffff, 24, "center bold")
end)

transcend.events.on("notePlayed", function(e)
    last = e.note
    transcend.panels.invalidate(ID)   -- redraw only when there is something new to show
end)
```

---

## 13. `transcend.menus`: entries in right-click menus (API level 10)

An extension can add its own commands to four of Transcend's menus. An entry points at one of
**your registered actions** (`actions.register`). Picking it runs that action with **what was
right-clicked** as its params, which is the one thing an action run from the palette cannot know.

Entries appear under an **Extensions** heading at the end of the menu (in the clip menu, an
"Extensions" group whose bottom line names your package), so they can never pass for one of
Transcend's own commands. A menu with no entries looks exactly as it always did.

| Function | Returns | Notes |
|---|---|---|
| `menus.add(menu, actionId, opts?)` | number, the entry's id | `menu`: `"clip"`, `"track"`, `"mixer"` or `"pianoRoll"`. `actionId`: your own action, short or full id; it must be registered first. Adding the same action to the same menu again replaces the entry, so a reload does not stack them. |
| `menus.remove(entryId)` | boolean | |
| `menus.list()` | array | Your entries: `id`, `menu`, `action` (the full id), `title`, `only`. |

`opts`: `title` (what the menu reads, at most 60 characters; default the action's name), and for
the clip menu `only = "audio"` or `only = "pattern"`. **At most 12 entries per package.** No
permission is needed: an entry can do nothing its action could not already do from the palette.
Entries go when the package unloads.

The params your action receives:

| Menu | Where it appears | Params |
|---|---|---|
| `clip` | a clip's right-click menu, "Extensions" group | `clip` (uid), `track`, `pattern` (boolean), `patternId` (a pattern clip) or `path` (an audio clip) |
| `track` | a track header's right-click menu | `track` |
| `mixer` | a mixer strip's right-click menu (not the master) | `track` (a strip is its track) |
| `pianoRoll` | the piano roll's menu > Tools | `patternId`, `clip` (uid), `selected` (array of the selected notes' uids, as `project.notes` reports them; empty when none) |

The action runs **after** the menu has closed, so it may open a window (`panels.show`), invoke
other actions, or edit the project like any action. Check `transcend.api.has("menus.add")` first.

```lua
-- A track menu entry that shows the right-clicked track in a small window.
local W = transcend.panels.create("info",
    { title = "Inspector", placement = "window", width = 360, height = 230 })
local text = ""

transcend.panels.onDraw(W, function(g, ctx)
    g.clear(g.themeColor("panelBg") or 0x1b2024)
    g.text(16, 30, text, g.themeColor("textBright") or 0xffffff, 14)
end)

transcend.actions.register("showTrack", "Show Track in Inspector", function(p)
    text = "Track " .. (p.track + 1)
    transcend.panels.invalidate(W)
    transcend.panels.show(W)   -- opened because the user asked, never at load
    return true
end)

transcend.menus.add("track", "showTrack", { title = "Show in Inspector" })
```

---

## 14. Testing an extension: `Transcend --test-extension`

```
Transcend.exe --test-extension <package folder> [--tests <folder>] [--report <file.json>] [--only <name>]
```

This runs the package's tests (`tests/*.lua`, inside the package folder or beside it) in the real
sandbox, at this API level and with the same limits, against a **pretend project**. It opens no
window and plays no audio. It prints a report and exits with:

- `0` when every test passed,
- `1` when a test failed,
- `2` when nothing could run.

`--tests` points at another tests folder, `--report` also writes the results to a JSON file, and
`--only` limits the run to the named test. Transcend is a windowed program, so read its output
through a pipe (for example, pipe it to another command in a terminal). The package's saved state
(`transcend.state`) goes to a scratch folder during the run, never to your real packages.

A test file runs **inside** the extension: `require` finds `scripts/lib`, and `transcend.*` is the
real API.

```lua
test("Fade In rewrites the open pattern", function()
    testkit.truthy(testkit.run("fadeIn"))                      -- the extension's own action
    testkit.equal(#testkit.calls("pattern.setNotes"), 1)       -- what it asked Transcend to do
    testkit.equal(transcend.project.notes("p1")[1].velocity, 40)
end)
```

| Function | Does |
|---|---|
| `test(name, fn)` | One test. Tests run in file order and share the extension and the pretend project within a file; each file starts fresh. |
| `testkit.equal(got, want, what?)` | Fails unless equal (tables are compared field by field, numbers to 1e-9). |
| `testkit.near(got, want, tolerance?, what?)` | Fails unless within `tolerance` (default 1e-6). |
| `testkit.truthy(value, what?)` | Fails unless `value` is truthy. |
| `testkit.contains(list, value, what?)` | Fails unless the list holds `value`. |
| `testkit.describe(value)` | A readable one-line form of any value, for your own messages. |
| `testkit.project()` / `testkit.set(fields)` | Read / change the pretend project, e.g. `testkit.set({ tempo = 90, activePattern = "" })`. |
| `testkit.run(actionId, params?)` | Run an action (full id, or the id the package registered). Returns `ran, result`. |
| `testkit.calls(actionId?)` | Every host action the extension invoked during this test: `{ id, params }`. |
| `testkit.console()` | Every line it printed during this test (lines printed at load show in the file's first test). |
| `testkit.fire(event, payload?)` | Fire one of section 5's events at it. Nothing fires by itself. |
| `testkit.draw(panel, w?, h?, t?)` | Draw a panel (default 400 x 300; `t` is the panel's clock). Returns `{ texts = { {text, x, y, size}, ... }, commands, failed, title }`. |
| `testkit.click(panel, x, y, button?)` | Press and release a mouse button. Returns whether the panel used it. |
| `testkit.move(panel, x, y)` / `testkit.wheel(panel, x, y, delta?)` | Send it mouse moves and wheel turns. Return whether the panel used them. |
| `testkit.findText(frame, text)` | The first drawn text equal to, or containing, `text`, or `nil`. |

Every assertion that fails names the file and line.

**The pretend project** is `tests/project.json`, using the names `transcend.project` returns:
`name`, `tempo`, `meter {num, den}`, `key {root, scale, notes}`, `playhead`, `playing`,
`activePattern`, `currentInstrument`, `tracks [{name, kind, muted, soloed, volume, pan, color}]`,
`plugins [{id, name, format, track, role, slot, instrument, parameters [{id, name, value, min, max, default}]}]`,
`patterns [{id, name, beats, pluginId, hasSample, notes [...], controllers [{controller, step, value}]}]`,
`clips [{uid, track, name, patternId | path, startSeconds, lengthSeconds, muted, selected}]`,
`samples [{path, name, lengthSeconds}]`, `markers [{name, beats, tempo, sigNum, sigDen}]`,
`loop {start, end}`, `selection {clips, notes}`. Anything it leaves out comes from a default:
120 BPM, 4/4, two tracks, a "Test Synth" (plugin 1) on track 1, and pattern `p1` "Pattern 1"
holding a C major chord, placed at 0. The pretend project has one tempo and one time signature for
the whole song.

**Host actions are stand-ins.** Every call is recorded. These also change the pretend project the
way Transcend would: `pattern.setNotes`, `pattern.setInstrument`, `pattern.create`,
`clip.placePattern`, `clip.placeAudio` (files in `samples` only), `clip.move`, `clip.delete`,
`clip.setMuted`, `clip.select`, `track.add`, `track.rename`, `track.setMute`, `track.setSolo`,
`track.setVolume`, `track.setPan`, `transport.seek` and `plugin.setParameter`. `note.preview`,
`note.stopPreview`, the `launcher.*` actions and transport play/stop are only recorded.

A test fails on a failed assertion, on any Lua error, and on an error the extension reports while
the test runs (a panel that stops drawing, a handler that raises). An extension stopped for running
too long fails that test and the rest of its file.
