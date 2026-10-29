# Song Map (example page)

An example of an extension adding a whole PAGE to Transcend: the song on one screen, every track a
lane and every clip a bar, with the playhead. Click a lane to move the playhead there.

A page is a panel created with `placement = "page"` (API level 7). It sits in the workspace beside
the arrangement, the piano roll and the mixer, and gets its own button in the main bar next to
theirs, drawn from `images/songmap.svg` in Transcend's own icon colours. It also opens from
**View > Extension Pages** or the command palette (**Open Page: Song Map**). Clicking its button again,
or the arrangement button, takes you back.

It is drawn in two layers, which is what keeps a page that covers the whole workspace cheap. The
song (lanes and clips) is the STATIC layer, `panels.onDrawStatic`: it runs only when the song
changes, and Transcend keeps what it drew as a picture. The playhead is the dynamic layer,
`panels.onDraw`, drawn over that picture: moving it re-runs one small function
(`panels.invalidate(PAGE, "dynamic")`) and repaints a thin strip instead of the whole page.

To try it: start Transcend (scripting is on unless `TRANSCEND_EXTENSIONS=0`), then Settings > Packages > Load Folder...
and choose this folder.
