# Chord Helper (example)

A sidebar extension (a card on the Browser's home screen, API level 7; on an older Transcend it
falls back to a dock tab). It:

- shows the **key** of the open pattern, detected from its notes (Krumhansl-Kessler profiles,
  weighted by note length), or set by hand with the arrows; click the key name to switch major and
  minor;
- lists the **seven chords of that key**, as triads or, with **Sevenths** on, seventh chords;
- names the **chord at the playhead** in the open pattern and lights it in the list;
- **click a chord** to add it as the next bar of the open pattern, in close position around C3.
  One click is one undo step.

The music theory lives in `scripts/lib/theory.lua` (loaded with `require("theory")`) and makes no
`transcend.*` calls, so it can be read and tested on its own. `Transcend/tests/example_chords_test.cpp`
loads this folder from the source tree and checks it.

To try it: start Transcend (scripting is on unless `TRANSCEND_EXTENSIONS=0`), then **Settings > Packages > Load
Folder...** and choose this folder. Linked like that, it reloads itself every time you save a file.

## What writing it showed the API is missing

This example was written to find out what is awkward or missing. In order of how much they got in
the way:

1. **No way to audition notes.** A chord tool should let you hear a chord before you add it. There is
   no action that plays a note or a chord through the open pattern's instrument.
2. ~~**No "the open pattern changed" or "these notes changed" hook.**~~ Since API level 12 the panel
   listens to `notesChanged`, `activePatternChanged` and `tempoChanged` and never polls; on an older
   Transcend it still re-reads the pattern at most twice a second.
3. **A pattern does not say what plays it.** The pattern table has no instrument or kind, so the key
   is "detected" from a drum pattern too, which is meaningless.
4. ~~**No time signature.**~~ Since API level 12 a bar's length comes from `project.meter()` at the
   pattern's first placement; an older Transcend is taken to be in 4/4.
5. **`pattern.setNotes` keeps only note, velocity, start, length and instrument.** Writing back the
   notes it read drops anything else on them (slides, for one). It also declines for a pattern that
   is not on the arrangement.
6. **A clip's left crop is not in the clip table**, so mapping a song position to a step inside a
   cropped pattern clip comes out wrong.
7. **`notePlayed` has no note-offs**, so a script cannot know which keys are held, and cannot name a
   chord played on a MIDI keyboard.
8. **No song-position-to-pattern-step helper.** Since API level 12 the script measures through
   `project.beatsAt()`, which follows the tempo map; a helper that also knew a clip's crop would still
   be simpler.
