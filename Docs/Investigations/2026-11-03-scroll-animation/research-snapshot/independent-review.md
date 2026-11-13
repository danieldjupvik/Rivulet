# Rivulet Home scrolling: independent review (2026-11-12)

Scope: existing traces, recordings, exports and the current working tree of
`fix/scroll-animation-improvements`. No builds, no device, no new captures, no
source changes. Everything here was re-derived from the raw `.trace` bundles with
`xctrace show`, not from the earlier exports or summaries.

Reproduce: `scripts/classify.py <tables dir> <trace name>` joins every hitch to
its own frame (client update, render, GPU, frame lifetime, gap since the previous
commit). `scripts/run1..4.py` aggregate main-thread samples inside the update
windows. `tables/*.classified.txt` holds the per-hitch output for all seven traces.

## 1. The main finding: three hitch classes at fixed phases of every move

Hitch counts were treated as one population. They are three, and each sits at a
fixed time after a focus move. Release baseline, ten downward moves:

| Class | Phase after move onset | What the frame shows | Rivulet | Apple TV app |
| --- | --- | --- | --- | --- |
| A. Onset | 0 ms | One long client update inside `_UIFocusEventRecognizer _handlePanGesture` | every move, median 25.6 ms | every move, median 34.1 ms |
| B. Mid-scroll | +167 to +250 ms | One long client update inside `UICollectionView _createPreparedCell` for a `ShelfRowCell` | moves that bring in an unbound row, median 34.8 ms, two frames lost in 7 of 10 | none as a client update |
| C. Tail | +834 to +934 ms | Update 1.0 to 1.9 ms, render and GPU normal, previous commit 33 ms earlier, label "n/a" | 1 or 2 per move | none flagged |

Counts by trace (A / B / C / other):

- `rivulet-release-baseline`: 11 / 10 / 14 / 0 of 35
- `rivulet-release-return-test`: 9 / 5 / 7 / 3 of 24
- `rivulet-lab-by-name-device` (Debug): 3 / 3 / 6 / 0 of 12
- `apple-ordinary-by-name-device`: 16 / 0 / 0 / 8 of 24 (the 8 are render or GPU side)
- `rivulet-scroll-signposts`: 55 / 24 / 4 / 3 of 86

## 2. Class B is the visible pause, and it is Rivulet-specific

Established:

- The video plateau and class B are the same event. The trace puts the B update
  167 ms after the onset update starts; the onset update itself takes about 26 ms
  plus one frame before motion shows, which lands B about 133 ms after first
  motion. The video (a separate run) holds from 133 ms. Feeding the current
  follower 16 ms steps puts the page at 243.7 px on frame 7; the video holds at
  242 to 244 px.
- The phase is geometric. The block runs when the next row's frame crosses the
  outer collection's bounds, which at a 516 pt row pitch happens at about 244 pt
  of travel, close to peak speed (about 27 to 30 pt per frame).
- Composition of the block (Release baseline, 10 windows, sampled ms per window;
  samples are statistical, and one window is an accounting outlier, see 6):

| Work | ms | Source |
| --- | ---: | --- |
| `PosterCell.prepareForReuse` | 10.5 | `PosterCell.swift:333` |
| of which `clearArtwork()` (blank image into `TVPosterView`) | 6.7 | `PosterCell.swift:428` |
| of which UIKit's own cell `prepareForReuse` | 2.8 | |
| UIKit `_prepareViewForReuse` remainder | 4.1 | |
| New `PosterCell.init` / `setUp` | 4.8 | `PosterCell.swift:107` |
| Inner `reloadData` + `layoutIfNeeded` remainder | 4.4 | `ShelfRowCell.swift:307` |
| `PosterCell.configure` (the actual bind) | 3.6 | `PosterCell.swift:296` |
| Outer collection, layout and commit remainder | about 10 | |

  The bind is under a tenth of the block. Resetting recycled tiles costs three to
  four times what binding them does, and each tile's image is set twice (blank,
  then the cached poster).
- New `PosterCell`s are still being built mid-scroll in a Release run after many
  rows. Each `ShelfRowCell` owns a private inner collection and reuse pool
  (`ShelfRowCell.swift:192`, `:213`), so a recycled row cannot borrow tiles from
  another row.
- Apple pays a comparable or larger main-thread cost per move (34 ms) but only at
  onset, before the page moves. Rivulet pays 26 ms at onset and then 35 ms at peak
  speed. The difference the eye sees is when the work happens, not how much.

Inference, not established: Apple's rows are bound earlier because UIKit's native
focus scroll knows the target offset and Rivulet's per-tick `contentOffset` writes
(`PlexHomeViewController.swift:6729`, with `isScrollEnabled = false` at `:2860`)
give UIKit nothing to prepare ahead with. The traces show where Apple's cost
lands, not why.

## 3. Class A explains the warm-row counterexample

The signposts trace, 36 to 51 s (targets 3046.5 / 3562.5, no CellPrepare, no
ImageDecode, no `ShelfRowCell.configure` samples): 20 of the hitches are single
long updates of 23.7 to 30.2 ms, one per move, 0.67 to 0.92 s apart. The 21st is
render-side (12 offscreen passes). So that interval is not a
residual mystery cause. It is the focus-move frame, once per move.

Release composition of A (11 windows, 24.5 ms sampled each): focus-map snapshot
6.4, `willUpdateFocus` layered-image focus 6.6, layout and commit 4.2, other
focus update 2.9, candidate search 1.9, `PosterCell.didUpdateFocus` 1.0.

Apple's app drops the same frame, and by more. This class is not a Rivulet
defect on the evidence available. It becomes visible only when a move lands
while the page is still travelling, which is how rapid navigation differs from
isolated moves: one visible pause per move when isolated (B), two when chained
(A lands mid-motion as well).

## 4. Class C is a measurement artifact of the scroll tail

- Simulating the follower with half-point rounding gives the first frame whose
  rounded offset does not change at 851 ms. Observed class C: 834 to 934 ms.
- Flagged frames have a 1.0 to 1.9 ms update, 8 to 11 ms render, 7 to 10 ms GPU,
  and a 50.05 ms lifetime, the same lifetime as every steady-state frame in that
  run. Nothing in them is slow.
- At that point the page moves under 0.35 pt per frame.

So 14 of 35, 7 of 24 and 6 of 12 hitches in the three November 12 Rivulet traces
are not dropped frames a viewer would see. Unresolved: why Apple's equally sparse
tail is not flagged, and whether Rivulet's mostly three-vsync pipeline (580 of
724 frames at 50 ms in the baseline; the older `rivulet-home-scrolling` trace is
mostly 33 ms) matters.

## 5. Corrections to the previous investigation

1. "12 Rivulet hitches, 24 Apple hitches." The 12 are 3 moves x (A + B + 2 C):
   six real long updates. Apple's 24 are 16 onset updates and 8 render or GPU
   frames. Apple also drops a frame about 200 ms into roughly half its moves,
   on the render or GPU side (about 10 to 18 ms), not in the app.
2. The artwork-retention experiment was rejected on a metric that could not see
   it. Hitch counts in an uncontrolled window track the number of moves (class A)
   and count a B block once whether it is 38 ms or 25 ms. The trace shows the
   blank-artwork reset is the largest single item in B. That does not prove
   retention fixes the pause; it means the rejection is unsupported and the
   experiment deserves a per-move measurement.
3. "The warm-row interval shows preparation is not necessary for the remaining
   hitches" is correct but stops short: those hitches are the onset focus frame,
   which the reference app also drops.
4. "Main-thread starvation of app-driven offset updates" is right for the
   plateau. Missing: the block is not unusually large by the platform's own
   standard; it is badly placed.
5. `ImageDecode` signposts wrap an `await` that includes disk or network, the
   decode, and the hop back to the main actor (`PosterCell.swift:411`). They are
   not decode durations and say nothing about main-thread blocking.
6. The 109.6 ms update at 40.160 s in the baseline is not a 110 ms block: the
   main thread is blocked in an 11 ms / 4.4 ms per-vsync pattern throughout, with
   about 31 ms sampled. The hitch table records 16.68 ms for it. Treat it as an
   accounting outlier.
7. Video scripts: the tracking and registration are sound for the plateau (a
   10 px RMS effect). The 0.27 to 0.49 px fit RMS from 480x270 frames is
   optimistic as a precision claim; do not read differences of a few pixels or one
   frame between the apps as real.

## 6. Motion scheduling, positioning and focus

- Scheduling is not the cause. `stepOffset` reads `CFAbsoluteTimeGetCurrent()`
  and floors to whole milliseconds, which mirrors the recovered UIKit heartbeat.
  After a three-frame stall the follower steps 37 pt where 27 was due, then 21:
  a one-frame surge, no runaway. An 18 ms / 15 ms callback pair changes a step by
  under 1 pt. Minor: the wall clock can step; nothing in the traces shows it did.
- Positioning matters only through phase: row geometry decides when B fires.
- Focus contributes class A, at parity with Apple.
- Render load is a secondary risk, not a current cause. Offscreen passes per
  frame: Rivulet median 20, max 81; Apple median 5, max 7. Render 7.5 vs 5.2 ms,
  GPU 7.3 vs 4.9 ms. One Rivulet frame was flagged for render (38 passes, 23 ms).

## 7. Ranking

| # | Explanation | Confidence | Impact |
| --- | --- | --- | --- |
| 1 | B: synchronous rebind of a recycled shelf row at peak scroll speed | High (phase, position, stacks agree across separate runs) | High: the visible plateau |
| 2 | A landing mid-motion during chained moves | Medium (mechanism established; visibility inferred) | Medium, shared with Apple |
| 3 | Render-server load near budget | Low to medium | Low today |
| 4 | Follower timing or clock | Low | Negligible |
| 5 | C tail frames | High that it is an artifact | None visible; inflates counts |

## 8. Optimization candidates, smallest first

All keep row targets, focus rules, native effects and constants.

1. Stop setting blank artwork on a tile that is about to be rebound. Move the
   clear from `prepareForReuse` to the paths that have no cached image. Worth
   about 6.7 ms, up to 10. Risk: a stale poster showing for a frame on a tile
   whose new image is not cached; the placeholder panel already covers that case.
2. Rebind a recycled row in place when the tile kind is unchanged, instead of
   `reloadData()` + `layoutIfNeeded()`: reconfigure the tiles already in the row.
   Removes the dequeue, both reuse passes and mid-scroll `PosterCell.init`,
   about 12 to 16 ms sampled. Risk: stale focus transforms and offsets must be
   reset explicitly. Unknown: the cost of a poster-to-poster swap in
   `TVPosterView`; the trace only shows blank-to-poster (1.5 ms) and
   poster-to-blank (6.7 ms).
3. Move the bind out of the motion window: bind the row that will enter next once
   the scroll settles, or widen the realized band so the trigger falls in the
   tail (after about 0.8 s, under 0.5 pt per frame). Changes when, not what.
4. Give rows a shared tile pool so a recycled row never builds a `PosterCell`
   mid-scroll.

Not recommended: changing the focus path (at parity with Apple), the curve, or
native focus effects.

## 9. Validation for later

- Controlled input: Release build, N presses down then N up, fixed pause above
  1.3 s; a second run with rapid presses for the chained case.
- Per-move metrics, not totals: client-update duration of the frame 150 to 260 ms
  after each onset update (target under 16.7 ms); frames whose lifetime exceeds
  the run's steady state, by phase; drop class C (update under 8 ms after a
  commit gap over 25 ms).
- Video: registration RMS for moves 2 to 5 back to the level of move 1, no hold
  at 242 to 244 px.

## 10. Cannot be resolved from existing data

- Whether class C is ever visible, and why Apple's tail is not flagged.
- Whether candidate 1 or 2 alone brings B under one frame.
- Why Apple's cost lands at onset.
- Input-to-motion latency (no timestamped input or focus markers). A signpost in
  `didUpdateFocusIn` and one per `stepOffset` tick would settle it and would also
  give the trace an exact move boundary.
- What the three "other" frames in the return test are (5.239, 36.003, 43.527 s).

## Addendum: `rivulet-first-entry-revisit.trace` (same Release build, same process, PID 818)

Class B has two sub-cases.

| Sub-case | Trigger | Client update | Sampled CPU | Frame lifetime (steady 33.4 ms) |
| --- | --- | --- | --- | --- |
| B1 construction | row cell and its tiles do not exist yet | 91.1 ms (14.570 s), 94.3 ms (22.879 s) | 53 ms, 83 ms | 116.8 ms, 133.5 ms |
| B2 recycled rebind | an existing row cell is handed to a different row | median 34.8 ms (downward run) | about 38 ms | 66.7 to 83.4 ms |
| Revisit, same row | row cell returns to the row it last showed | 4.9 to 11.4 ms | n/a | no hitch |

- Verified: 15 onset updates (19.8 to 32.7 ms), 13 moves with no long update after onset, two B1 entries, no `PosterCell.prepareForReuse` samples in either.
- B1 composition, 14.570 s: `PosterCell.init` 20 ms, `ShelfRowCell.init` 9, layout 13, bind 3.
  22.879 s: `PosterCell.init` 50 ms, of which 35 is the blank image set in `setUp`
  (`PosterCell.swift:117`), 25 of that in `_UIStackedImageContainerView initWithFrame`. One window each: rough.
- 22.828 s (20 ms update before the second B1): Auto Layout and text sizing with font creation, no focus work.
  A new header being laid out; consistent with move 14 reaching a row not shown before. Not proven.
- 14.920 s: one render-side hitch (render 16.0 ms, GPU 14.6 ms) after the first entry.
- The hitch table records each B1 as one 16.68 ms hitch. Use frame lifetime or update duration, not hitch count.
- Onset updates at a 0.6 s cadence land while the previous scroll is in its slow tail and were reported smooth.
  That weakens the earlier inference that onset frames are visible when moves are chained; it is untested for faster input.

## Addendum 2: artwork-reset experiment, and what the remaining work is

Recomputed with `scripts/run6.py` from the three `artwork-*` traces and their per-move windows.

### Audit of the comparison

Measured:

| Run | Process | Binding update, median | Sampled CPU, median | Onset update, median | Windows with tile construction |
| --- | --- | ---: | ---: | ---: | ---: |
| baseline | PID 818 (old) | 35.4 ms | 35 ms | 26.4 ms | 0 of 10 |
| patched, first pass | PID 1107 (new) | 36.5 ms (all 10) | 36 ms | 26.4 ms | 2 of 10 |
| patched, warm | PID 1107 | 29.1 ms | 29 ms | 26.0 ms | 0 of 10 |

- The numbers reproduce. Every binding update starts 163 to 167 ms after its onset in all three runs.
- Onset medians are equal across runs, which is a usable internal control: the device was not generally faster in the warm run.
- The first patched pass still samples `clearArtwork` (about 4 ms per window). The posters were not in the memory cache, so the patch took its uncached path. That run measures cache state, not the patch.
- What the runs establish: with cached artwork the patch removes about 6 ms from a recycled bind. What they do not: that the pause is gone. 29 ms is still one frame late (lifetime 66.7 ms).
- Unverified by me: the stale-content behaviour of the patch on device, and the intermittent failure
  `BelowFoldRailScrollTests/test_switchingSeasonScrollsTheRailToItsFirstEpisode` (2498 vs 3780). It asserts a scroll position; I did not examine why it is timing-sensitive.

### Remaining work in the warm binding frame (sampled ms per window, 29.7 total)

| Work | ms | Kind |
| --- | ---: | --- |
| UIKit `-[UICollectionViewCell prepareForReuse]` → `_removeAllAnimations:` (row cell 5.8, tiles 3.7) | 9.5 | cost of recycling; walks the tile subtree for the row and again per tile |
| Outer `_createPreparedCell` apply-attributes and layout | 4.3 | recycling |
| Other layout in the commit | 4.6 | partly unavoidable |
| `TVPosterView setImage` (cached poster) | 3.0 | unavoidable while the tile shows a new poster |
| Inner `layoutIfNeeded` | 2.9 | forced synchronously at `ShelfRowCell.swift:308` |
| `PosterCell.configure` other | 2.2 | unavoidable |
| Inner `reloadData` | 1.1 | recycling |
| Rest | about 2 | |

No single item is left to remove. With cross-row recycling the floor is roughly 15 to 20 ms, at or over one frame.

### New measured fact: Apple's rows are prepared by UIKit in idle time

`apple-ordinary-by-name-device.trace`, main thread:

- 132 samples under `-[UICollectionView _updateCycleIdleUntil:]` → `_updatePrefetchedCells:` → `_prefetchItemsForPrefetchingContext:` → `_createPreparedCell…`, against 35 samples creating cells in the visible-cells pass.
- The prefetch work is spread at 1 to 5 samples per frame over 5 to 10 consecutive frames, starting 150 to 300 ms after onset. Those updates last 2 to 13.6 ms.
- Rivulet, six traces: zero samples under `_updateCycleIdleUntil:` or `_prefetchItemsForPrefetchingContext:`. `_updatePrefetchedCells:` is only reached from `layoutSubviews`.

So the reference app does the same class of work mid-scroll, in slices that fit the frame. Rivulet does it in one block.
Code-derived: one outer item is a whole row (`makeHubSectionLayout`, `PlexHomeViewController.swift:3113`), and the row fills its tiles with `reloadData()` + `layoutIfNeeded()` in one call, so there is nothing for UIKit to slice.
Not established: whether UIKit prefetch is even allowed on the outer collection (`isScrollEnabled = false`, programmatic offsets).

### New measured fact: memory warnings cause the construction case

- `rivulet-release-baseline`: `-[UIApplication _performMemoryWarning]` at 36.61 s, about 50 ms on the main thread, including `-[UICollectionView _purgeReuseQueues]`. The next move's binding update (40.16 s, 109.6 ms) contains `PosterCell.init`. I earlier called that update an accounting outlier; that was wrong.
- `rivulet-first-entry-revisit`: memory warning and `_purgeReuseQueues` at 22.445 s; move 14 at 22.73 s constructs (94.3 ms).

Two of two recurrences of construction follow a memory warning. Unknown: the app's footprint (no memory instrument in any trace) and whether warnings occur without Instruments attached.
Code: the image memory cache allows 400 MB (`ImageCacheManager.swift:127`).

### Ranked proposals

1. Move the bind to the slow end of the scroll by realizing rows one band earlier (experiment below). Addresses recycled rebind and construction.
2. Find out why the app gets memory warnings. It is the measured trigger for the 90 to 110 ms case and it empties caches.
3. Keep the artwork patch if device checks show no stale posters: measured 6 ms, low risk.
4. Incremental tile population (bind a few tiles per frame). The Apple-like end state; larger change.
5. In-place rebind, shared pool, lazy subviews: each trims the block, none gets it under a frame alone.

### Experiment: realize the next row early (Home, downward moves)

Hypothesis: the pause is visible because the block lands at about 244 pt of travel, at 27 to 30 pt per frame. The same block at 1 to 2 pt per frame is not visible.

Change: extend the Home collection view about 270 to 300 pt below the screen (bottom constraint at `PlexHomeViewController.swift:2893`) and use the screen height, not `collectionView.bounds.height`, in the 13 places that compute offsets. Resting offsets, focus rules and constants are untouched. The top edge does not move, so content offsets keep their meaning.

Predictions (falsifiable):

- The long binding update still exists per move but starts about 550 to 650 ms after onset instead of 163 to 167 ms.
- No client update over 16.7 ms between 100 and 400 ms after onset.
- Video: no hold at 242 to 244 px; fit RMS for moves 2 to 5 at the level of move 1.
- Disproved if the long update stays at about 167 ms, or if it moves and the pause is still seen.

Controls: same build pair installed fresh, alternate A-B-A-B, one warm-up pass over the route before each recorded pass, at least 6 rows down with 3 s pauses, discard any move within 5 s after a memory warning (visible in the time profile as `_performMemoryWarning`), classify each move as construction or recycle from `PosterCell.init` samples.

Tradeoffs:

- Memory: one more realized row.
- Input latency: a press during the tail waits for the block (29 ms recycled, about 90 ms construction).
- Focus: the extra row is inside the collection's bounds though off screen; check that Down cannot land on it and that the focus-map snapshot does not grow the onset update.
- Upward moves are not covered; they need the top edge extended, which shifts offset coordinates.

### Missing observations

- Memory footprint and warning frequency without Instruments.
- Whether `_prefetchingAllowed` is true for the outer collection.
- A trace of a detail page and of the hero-to-episodes slide.

## Addendum 3: broader review, web research, and a revised verdict

### Verdict

Immediate blocker (measured): one client update of 29 to 35 ms (recycled row) or 90 to 110 ms (construction) lands about 165 ms into each move.

Underlying cause (best-supported, not yet tested on device): Home, detail and Person replaced the focus engine's own scroll with a hand-driven `contentOffset` loop. That loop gets the row where it should rest, but UIKit's idle-time cell preparation does not run for it. The work UIKit would have started early in spare frame time is instead done when the row crosses the bounds, in one block. The row-as-one-cell design then makes that block large.

The same repository already steers the native focus scroll without replacing it: `EPGGuideView.swift:417` and `LiveMultiviewViewController.swift:1192` override `targetContentOffset` in `scrollViewWillEndDragging`, with the comment "tvOS routes every focus scroll through `scrollViewWillEndDragging`, Up/Down included". Home never tried that route; its driver dates from `8f545bff` (2026-06-11) and the comment at `PlexHomeViewController.swift:2858` only records that the engine's animator raced the display link.

### Corrections to earlier addenda

- "Nothing for UIKit to slice" was overstated. Codex's simulator probe shows row-sized items are prepared on the idle path under a native animated scroll (9 idle, 3 other).
- The 400 MB image cache is not shown to cause the warnings. Jetsam reports put the warned process (PID 818) at 65 to 78 MiB while `mediaplaybackd` held 0.9 to 2.1 GiB and `videocodecd` 0.6 to 1.3 GiB. The warnings look system-wide. Which client drove the media daemons is unknown.
- The band-extension experiment is demoted to a fallback. It moves the block; the native-scroll test asks whether the block needs to exist at that moment at all.

### What the new evidence establishes, and what it does not

Measured:
- Simulator, tvOS 27.2 (24K150), plain flow layout, cheap cells: per-frame offset writes give 0 idle-path cell preparations in every variant; native animated offsets give 54 of 72 (flat) and 9 of 12 (row), with `isScrollEnabled` on or off. `_prefetchingAllowed` was true in both.
- Apple TV app on device: idle-path preparation during native focus scrolls (addendum 2).
- Rivulet on device: none.

Not established:
- That the focus engine's scroll (as opposed to `setContentOffset(animated:)`) engages the idle path in Rivulet's compositional layout on the device.
- That engaging it removes the visible pause. Apple's stated budget is "up to twice the amount of time to prepare each cell" (WWDC21 10252, iOS 15, tvOS not mentioned). A 29 to 35 ms row is at or over that; a 90 ms construction is far over.
- Absence of idle samples explains where Apple's work goes. It does not by itself explain why Rivulet's block is 30 ms.

### App-wide checks (existing traces, main-thread samples; statistical)

| Trace | Main samples | Focus | Snapshot apply | Observation sinks | SwiftUI graph | Other-thread samples, mostly |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| artwork-patched-warm (60 s) | 2384 | 713 | 0 | 10 | 12 | 275, idle workers |
| release baseline (41 s) | 2518 | 688 | 0 | 7 | 18 | 889, JPEG decode |
| memory warm (100 s) | 3943 | 975 | 8 | 24 | 45 | 1407, image downsample |

- No reload or invalidation storm, no observation churn, no Sentry, no player work on the main thread in these windows.
- Focus is the largest single consumer (about a quarter to 30% of main-thread samples). It is the per-move onset frame, which Apple's app also pays.
- Background CPU is image decoding. Not shown to block the main thread.

So the traces do not support a hidden app-wide cause. They cannot exclude effects outside sampled CPU (memory pressure from media daemons, GPU contention).

### Web research

| Source | Date, platform | Says | Matches Rivulet? |
| --- | --- | --- | --- |
| WWDC21 session 10252, Apple UIKit engineer | 2021, iOS 15 | "Cell prefetching in iOS 15 takes advantage of this spare time by preparing the next cell right after finishing a short commit"; "up to twice the amount of time to prepare each cell"; cells must be fully configured in the provider | Mechanism matches the Apple-trace stacks. tvOS not mentioned |
| Apple forum 761108, DTS engineer answer | Aug 2024, tvOS, compositional layout with orthogonal rows | Focused row would not pin to the top; Apple suggests `scrollToItem` from `canFocusItemAt` / `shouldUpdateFocusIn` | Same goal (custom resting position). Apple's answer keeps UIKit's scroll |
| Apple forum 131031, developer post | Jun 2024, tvOS | Edits `targetContentOffset.pointee.y` to tame focus scrolling | Supports target override as a working hook. Not Apple staff |
| Apple forum 767129, DTS asks for a bug report | Oct 2024 to Jan 2025, tvOS 18 | Focus stops moving to off-screen collection cells when another view sits beside the collection | A risk for any change that relies on off-screen cells being focusable. Different mechanism |

No published reproduction of "manual offset writes disable idle cell preparation" was found. That link rests on Codex's probe and the device traces.

### Isolation experiments (production shell, Release, one factor each)

E1. Native focus scroll for Home's vertical moves.
- Change: `isScrollEnabled = true` on the Home collection; resting offset supplied through `scrollViewWillEndDragging` using the existing `restingOffsetY(forSection:)`; the display-link driver not started for row-to-row moves. Row targets and focus rules unchanged.
- Predicts: samples under `_updateCycleIdleUntil:` appear; `ShelfRowCell` preparation moves onto that path; no client update over 16.7 ms between 100 and 400 ms after onset for recycled rows.
- Disproves the underlying-cause claim if idle samples still do not appear. Disproves "sufficient" if they appear and the long update remains; then the unit size is the cause and E2 decides.

E2. Unit size, with E1's driver held fixed.
- Change: a debug switch that makes rows cheap (tiles bound without artwork, or three tiles per row).
- Predicts: the binding update scales with tile count; under one frame at a small count.
- Disproves "block size is tile work" if the update does not scale.

E3. Media-service pressure.
- Change: hero theme video off for one session; nothing else.
- Predicts: if Rivulet drives `mediaplaybackd`/`videocodecd`, their footprint in a sysdiagnose or jetsam report drops and no `_performMemoryWarning` appears in a ten-minute browse.
- Disproves it if warnings and daemon sizes are unchanged; then the pressure is external (other apps, recording).

Order: E1 first. It is the only one that tests the cause rather than the cost.

### Unresolved

- Whether E1's idle preparation engages on the device.
- Who retains the 398 MiB of raster data seen in the fresh allocations run.
- Detail-page and hero-slide hitches: still untraced.

## Addendum 4: native Home scrolling on the device (`native-home-fresh.trace`, PID 1469)

Re-derived from the raw trace (`tables/native.*`, `scripts/classify.py`).

### Established

- Idle preparation engages on the device. 343 main-thread samples sit under `_updateCycleIdleUntil:`. All 199 sampled `ShelfRowCell.configure` stacks are on that path; none are in the visible-cells pass.
- The idle work fits. 34 client updates contain idle preparation; the longest is 14.8 ms, median 12.1 ms, none over 16.7 ms.
- The 29 to 35 ms recycled-row update at about +167 ms is gone from every move where the row cell already existed.
- No memory warning was sampled in this capture.

### Inferred, not established

- That the idle path is why Daniel sees no pause. The trace shows the block removed; visibility is his observation. No video was taken.
- Size of the improvement. Different process, cache state and cadence from the comparison run.

### Remaining long updates (11 of 1,143)

| Kind | Count | Duration | What it is |
| --- | ---: | --- | --- |
| Focus-move onset | 7 | 20.9 to 55.3 ms | Same class as before, also paid by Apple's app. The first is 55 ms (first move after 90 s idle) |
| Mid-scroll, +167 ms | 4 | 22.0 to 24.3 ms | `PosterCell.init` in the inner collection's own visible pass, 8 to 10 samples each, not on the idle path |

The four mid-scroll updates are moves 2 to 5, the first visits to new rows. Code-derived explanation: a newly built `ShelfRowCell` starts with its inner collection 260 pt wide (`ShelfRowCell.swift:231`) and widens to the cell width only in `layoutSubviews`. Configured in idle time before that layout, it builds one or two tiles; the rest are built when the cell is first displayed. Recycled row cells already have the full width, which is why moves 6 to 17 show no such update. Not measured directly: tile counts per pass were not logged.

Effect on motion: each of the four frames has a lifetime of 66.7 ms against a steady 33.3 ms. That is a late frame at peak speed on first visits only; it was 90 to 110 ms before.

### A separate hitch found in this trace

Ten render-server hitches recur every 8.0 s while the page sits on the hero (8.35, 16.36, 32.38, … 88.42 s): render 25 to 46 ms, GPU 15 to 27 ms, 21 offscreen passes, app update about 1 ms. The period matches `HeroOverlayView.autoAdvanceInterval = 8`. This is the hero page change, costs one or two frames each time, and has nothing to do with scrolling.

### Audit of the native implementation (`native-home-only.patch`, read against the working tree)

Risks found by reading; none exercised in the capture:

1. Moves where the engine sees no need to scroll. The resting offset is applied only inside `scrollViewWillEndDragging`. If the newly focused view is already fully on screen the engine may not scroll and the delegate may not fire, so the page would not move to its resting offset. The old code always called `scrollSectionToRest`. Most likely on Up to the hero from row 1 (the hero's buttons stay on screen there) and at the last rows.
2. Hero return uses a different animation. The hero overlay's `onFocusEntered` still calls `scrollHeroIntoView()` → `animateContentOffset` → `setContentOffset(animated: true)` (`PlexHomeViewController.swift:6707`), which is UIScrollView's standard animation, not the focus scroll, and can run alongside the engine's own.
3. Interruptions. `scrollToContentTop()`, `returnToTopRow()` and the preview-restore paths cancel a scroll with `offsetLink?.invalidate()` and then write `contentOffset`. A native scroll in flight is not cancelled by that.
4. Snapshot shifts mid-scroll. `applySnapshotKeepingFocusedRowStill` moves the in-flight target only when `offsetLink != nil` (`:1510`). A row inserted above during a native scroll would land off by the shift.
5. Held arrows. With scrolling enabled the system's fast-scroll index bar can take focus after a long hold. `pressesBegan` then starts the manual fast-scroll link (`:4259`), which writes `contentOffset` while the native scroller is live. Home has no grid, so `landFocusOnCenterTile` has nothing to land on.
6. Nested rows. `sectionIndex(forFocusedView:)` resolves the row from the focused tile; it returned a section for every move in the capture, but the engine's proposed offset for a tile inside a scroll-disabled inner collection is simply overwritten. Fine while the override always fires (see 1).

### Detail and Person

- Person page: three `ShelfRowCell` rows on `FocusScrollControlledCollectionView`, every row centred. Same shape as Home; the same change should apply.
- Detail below-fold: applicable to row-to-row moves, with one condition. The hero-to-details slide runs its own display link and the code notes the engine's scroll "fights it and overshoots to Cast" (`PreviewCarouselViewController.swift:1345`). Native scrolling would have to stay off during that slide and its reverse. That transition is separate and untouched by this result.

### Weaknesses

- All 17 detected moves fall in 92 to 111 s at 0.4 to 1.7 s spacing; several are revisits. First-visit and recycled cases are not separated by design, only by sampled stacks.
- Onset updates fall to about 12 ms from move 7 on. The detector's threshold (8 ms, focus-dominated) may be picking a different event than in the custom-driver runs; do not read it as focus getting cheaper.
- No signposts in the export, so no `CellPrepare` comparison.

### Recommendation

Keep the experiment. The cause is supported on the device; no further capture is needed to decide that.
Before it ships, check items 1 to 5 by hand on the device (no trace needed). One later capture is worth taking for a single question: does setting the row's inner width before first configure remove the four 22 to 24 ms first-visit updates. Route: fresh launch, six rows down with 3 s pauses, then back up.
