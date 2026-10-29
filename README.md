# Velocity Fade: a Transcend extension template

A small, complete Transcend extension, set up so that publishing it is **one tagged release and one
pull request**. Replace the extension with your own; keep the tooling.

What it does, so you can see every part working: a panel in Transcend's Browser sidebar shows the open
pattern, and two buttons (also in the command palette) fade its velocities in or out.

```
package/            the extension itself: this folder is what Transcend installs
  manifest.json     its id, name, version, and what it asks for
  scripts/main.lua  the code that runs first
  scripts/lib/      your own modules (require("fade") finds scripts/lib/fade.lua)
tests/              tests that run inside Transcend, against a pretend project
tools/test.ps1      runs the tests in the Transcend on your computer
tools/check_extension.ps1   the checks the Get Extensions shelf runs, and the .tpkg builder
.github/workflows/  check every push; build the .tpkg on every version tag
.transcend/         Transcend's API: definitions for autocomplete in VS Code, and extensions-api.md
examples/           the extensions on the Get Extensions shelf, as source to read and copy from
```

## Where to learn

- **`.transcend/extensions-api.md`**: the complete API reference, with every function, event,
  built-in action, sandbox rule and limit. If you use an AI assistant, give it this file: it keeps the
  assistant to functions that really exist.
- **[Build your first package](https://dawtranscend.com/docs/extensions-first-package.html)**: a
  step-by-step walkthrough, from an empty folder to a published extension.
- **[Make a theme or a layout](https://dawtranscend.com/docs/extensions-themes-layouts.html)**: no
  code needed.
- **`examples/`**: Chord Helper (a Browser card that writes chords into a pattern, with tests),
  Song Map (a full page of its own) and Stage (a layout).

## 1. Make it yours

1. Click **Use this template** on GitHub and create your repository.
2. In `package/manifest.json` change:
   - `id`: an id nobody else uses. Use your GitHub name: `io.github.<you>.<extension>`.
     It never changes after your first release (it is how Transcend knows an update is the same
     extension). `com.transcend.` is kept for Transcend's own.
   - `name`, `author`, `description`: shown on the shelf and in the consent box.
   - `version`: start at `1.0.0`.
3. Open the folder in VS Code and install the **Lua** extension when it is suggested: every function
   Transcend offers autocompletes, with its description.

The API reference is in `.transcend/transcend.d.lua`. Reads go through `transcend.project`; changes go
through `transcend.actions.invoke`, so the user can undo them.

## 2. Try it in Transcend while you work

In Transcend: **Settings > Packages > Load Folder...** and pick the `package` folder. It is linked, not
copied: every time you save a file, Transcend reloads it. `print()` output appears in
**Settings > Packages > Console**.

## 3. Test it

```
pwsh tools/test.ps1
```

(Windows PowerShell works too: `powershell -File tools\test.ps1`.) It finds the Transcend installed on
your computer and runs every `tests/*.lua` inside Transcend's real script sandbox (the same API, the
same limits) against a pretend project. No window opens and nothing plays.

A test file is a list of `test(name, function)`:

```lua
local fade = require("fade")            -- your own modules load as they do in main.lua

test("a fade in rises from soft to loud", function()
    local out = fade.fade(notes, 40, 100)
    testkit.equal(out[1].velocity, 40)
end)

test("clicking the button changes the pattern", function()
    local frame = testkit.draw("panel", 260, 160)          -- draw a panel, read what it drew
    local button = testkit.findText(frame, "Fade out")
    testkit.click("panel", button.x, button.y - 4)          -- click it
    testkit.equal(#testkit.calls("pattern.setNotes"), 1)    -- what the extension asked Transcend to do
    testkit.equal(transcend.project.notes("p1")[1].velocity, 110)   -- and the result
end)
```

- **The pretend project** is `tests/project.json`: tempo, meter, key, tracks, patterns with their
  notes, clips, plugins, markers, selection. The field names are the ones `transcend.project` hands your code.
  Anything you leave out comes from a default (120 BPM, 4/4, two tracks, one pattern "Pattern 1"
  holding a C major chord). `testkit.set({...})` changes it inside a test.
- **Changes your extension asks for** (`pattern.setNotes`, `clip.placePattern`, `track.rename`, ...)
  are recorded (see `testkit.calls()`) and applied to the pretend project, so reading it afterwards shows
  them. Previews, the clip launcher and transport play/stop are only recorded.
- **Events** do not happen by themselves: fire the one you want with
  `testkit.fire("notesChanged", { patternId = "p1" })`.
- Within one file the extension and the pretend project carry over from one test to the next, in
  order. Each file starts fresh.
- `testkit.equal`, `near`, `truthy`, `contains` fail the test with a message naming the file and line;
  so does any error, including one your extension raises while a test drives it.

Every helper is described in `.transcend/testkit.d.lua`. Run some of them with
`pwsh tools/test.ps1 -Only "Fade"`.

## 4. Publish

```
git tag v1.0.0
git push origin v1.0.0
```

The tag must be `v` + the version in `package/manifest.json`. GitHub then runs the shelf's checks,
builds `<id>-1.0.0.tpkg` and attaches it to a release (Actions tab). That release is all anyone needs:

- **Right away**, anyone can install it in Transcend: **Browser > Extensions > Get Extensions**, then
  paste `your-name/your-repo` into the "Install from a link" box (or VIEW > Get Extensions... >
  Install from a link...).
- **To be on the Get Extensions shelf**, add a file to the index repository,
  [transcend-daw/transcend-extensions-index](https://github.com/transcend-daw/transcend-extensions-index), in a pull request:

  `entries/<your-name>-<your-repo>.json`

  ```json
  { "repo": "your-name/your-repo", "tag": "v1.0.0", "asset": "io.github.your-name.velocity-fade-1.0.0.tpkg", "id": "io.github.your-name.velocity-fade" }
  ```

  The pull request runs the same checks on your release. Once it is merged, the next shelf update
  lists your extension in the **Community** section, with your GitHub name on its card.

**An update** is a new version: raise `version`, tag it, and change `tag` and `asset` in your entry in
another pull request. A listed version is pinned to its file's exact size and checksum, so a file
replaced after listing is refused by every copy of Transcend. Always publish a new version instead.

### What the shelf checks

- `manifest.json` is a Transcend package with a usable id and a version number;
- what it says it provides is what is in the folder, and nothing else;
- a script package names an API level Transcend has;
- no picture, font or sound over 4 MB, no package over 64 MB;
- a Community extension does not ask for network access.

`pwsh tools/check_extension.ps1 -Folder package -Community` runs exactly these on your computer.

### What people see

Before installing, Transcend shows what your extension asks for. For a Community extension it also says
*"Transcend hasn't read this one's code yet."* That is all it says about it. If you would like it
**Reviewed** (read line by line by Transcend, and marked so on the shelf), ask in your pull request.

## A picture for the shelf

Put a `shelf.png` (16:9, at least 480x270) in `package/` and the shelf card shows it.

## Licence

Choose one for your code and put it in `LICENSE` (MIT is a common choice). The template itself may be
used for anything, without credit.
