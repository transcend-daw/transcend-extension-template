# Stage (example layout)

An example of how far a layout package can move Transcend's workspace without touching its look. It is
data only: no script, no permissions, nothing to approve.

What it changes:

- **Panes.** The Browser moves to the left edge and the Samples / Patterns sidebar to the right
  (`mainSplitterOrder`, `mainSplitterSizes`).
- **Drawers.** The piano roll is docked open under the arrangement (`pianoRollDockOpen`,
  `pianoRollDockHeight`, `centerSplitterSizes`).
- **Top bar.** The menus come down from the line above into the bar, next to the tempo display
  (`headerLeft`). The transport sits alone in the centre with the editing tools under it
  (`headerCenter`). The workspace buttons move to the right (`headerRight`), and the Plug-ins and
  Browser buttons are left out, which hides them.
- **No trays.** The workspace buttons sit flat on the bar instead of in a rounded tray
  (`bareButtons`).
- **Where the Browser opens.** At Extensions > Layouts (`browserPath`).

Every key is optional; anything a layout does not name stays as it is. The full list of keys and
controls is in the README of any package made with **Browser > Extensions > Layouts > New Layout
Package...**.

To try it: Settings > Packages > Load Folder..., choose this folder, then apply **Stage (example
layout)** from Browser > Extensions > Layouts.
