# Scroll animation investigation — 2026-11-03

Research branch: `research/tvos-scroll-animation` (formerly
`fix/scroll-animation-improvements`), originally based on fork main `96332a09`.
Commit: `13ffdc938a8600d34e46ba99f555dcdb3a419c20` — `fix: improve focus scroll timing and settling`.

This note is tracked on the feature branch so its findings survive checkout cleanup.
A small selection in `evidence/` is also tracked: reproduction scripts, numeric
scroll logs, motion CSVs, and a compact Instruments summary. See
[evidence/README.md](evidence/README.md) for the inventory and rerun instructions.
Other evidence, including raw exports and imagery, remains local and gitignored.
It was copied out of `/tmp/rivulet-scroll-review` to survive temporary-directory
cleanup. Back up those local artifacts separately before deleting the checkout.
The investigation documentation can be omitted from an upstream contribution.

## Preserved research snapshot — 2026-11-13

This branch preserves the experiments, including the recovered custom follower,
native ordinary-row rollout, artwork-reuse experiment and rejected native hero
slide. It is not the implementation PR branch. The clean native-scrolling branch
starts from fork main separately, without the artwork optimization or research
history. See [research-snapshot/README.md](research-snapshot/README.md) for the
compact reports, numeric results, original custom source and local evidence index.
Raw traces, private imagery and firmware are not committed. Existing local files
remain in place; no duplicate multi-gigabyte archive is required.

## Native hero-slide experiment — 2026-11-13

**Reverted after physical-device testing:** Daniel rejected the native slide feel.
The exact pre-experiment custom hero↔details slide and lifecycle tests are restored.
Native ordinary row scrolling remains enabled. The text below records the rejected
experiment, not the currently active transition.

At Daniel's request, the hero↔details slide now uses UIKit's
`setContentOffset(_:animated:)`, separately from native row-to-row focus scrolling.
The existing destinations and scroll-driven blur/fade/logo/pill effects are kept;
the custom 0.6-second quadratic timing is replaced by UIKit's programmatic timing.
Focus scrolling stays disabled during the slide and is restored before its
completion hands focus over. Reset, immediate reversal and window removal discard
superseded completions. A no-op or offscreen request completes immediately.

The original slide and lifecycle tests are backed up under local
`native-hero-slide/`. Simulator lifecycle tests pass for multiple progress updates,
completion, reset cancellation and immediate return. The measured test completes
in about 0.38 seconds; this is a simulator observation, not a promised duration.
The signed Debug device build passes. Physical-device feel and the complete visual
choreography still need Daniel's test. Ordinary-row rollout history follows.

## Native ordinary-row rollout — 2026-11-13

Native vertical focus scrolling now also applies to the shared browse controller's
Library, Search and other modes, plus movie/show below-fold rows, season pages and
person pages. The detail collection retains its focus bookkeeping and supplies
the existing top-band/centering targets through the owners' scroll delegates.
Browse grids retain their minimal-reveal target calculation. The old manual
fast-scroll driver is bypassed so it cannot compete with UIKit's fast scrolling.

At Daniel's request, the hero↔episodes transition keeps its custom 0.6-second
quadratic animation and synchronized effects. It disables native scrolling while
active and restores it on completion/reset; removal from the window cancels it.
Horizontal paging and other coordinated detail animations remain unchanged.
The tuned custom sources are preserved under local `native-all-pages/before/`,
in addition to the previous Home experiment's backup.

The signed Debug device build passes. Focused simulator checks pass for the new
slide/native handoff lifecycle, initial episode selection, pruned rails, season
rail scrolling, staged Menu-back behavior and collection-grid updates. No physical
detail/person verification or new performance capture has been done for this
rollout. Daniel will install/run Debug from Xcode for remote navigation checks.
Build/test logs and pre-change sources are in local `native-all-pages/` under the
same November 12 research root used below.

## Native Home experiment — 2026-11-12

Home now enables native vertical focus scrolling and supplies its existing hero/
row resting offset through `scrollViewWillEndDragging`. Its focus callback skips
the manual row driver; explicit Home scroll commands use native animated offsets.
Other modes and detail/person retain the tuned custom follower described below.
The follower and its constants are preserved, with a separate pre-experiment Home
source backup under the local `native-home-experiment/custom-follower-backup/`.

The signed Release build succeeded and was installed/launched on Stue without a
debugger. Regression tests were deferred for this hypothesis experiment. Daniel
reports completely smooth scrolling before and during the fresh-process capture.

`native-home-experiment/native-home-fresh.trace` records PID 1469 on tvOS 27.2
24K122 for 111.4 seconds. Thermal state is nominal. Idle preparation is now
observed on the device: 343 main-thread samples include `_updateCycleIdleUntil:`;
all 199 samples containing `ShelfRowCell.configure` and all 35 containing
`PosterCell.prepareForReuse` are under that path. The previous warmed custom run
has zero idle-path samples and 142 row-configure samples outside it. There are
zero sampled custom `stepOffset` calls in the native run.

Using the same focus-dominated client-update detector, 17 native focus onsets
are inferred. Their median maximum client update 50–500 ms after onset is
12.41 ms, versus 29.16 ms for the previous ten-move warmed custom run. Four native
moves still have 22.04–24.33 ms post-onset updates, with additional inner poster
construction visible in sampled stacks. Onset updates also remain. This is not
evidence of zero dropped frames or a complete solution for detail transitions.

This is not a matched A/B: native uses a fresh process, the old comparator was
warmed, row identities/input timestamps are unavailable, and native's detected
onsets occur at 92–111 seconds with faster-than-requested spacing. The final
post-onset window is truncated. The user confirms the requested navigation and
smoothness, but inferred onsets cannot be equated with all remote presses. The
native os-signpost export is empty, so CellPrepare interval timing is unavailable.
Fresh process does not mean cold disk artwork cache. The on-device preparation
path change is stronger evidence than a percentage comparison of these medians.

Raw trace, XML exports, `analyze_native.py`, `comparison.json`, `per-move.csv`,
the experiment-only patch and a readable report are in local
`~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/native-home-experiment/`.

## Ordinary motion update — 2026-11-12

The branch now follows the ordinary focus-scroll model recovered from UIKitCore
in tvOS 27.2, build 24K154, AppleTV18,1 (arm64e). This supersedes the timestamp,
substep and acceleration choices described in the historical stopping point below.
It is an independent implementation through public UIKit APIs.

Home and ordinary detail/person row scrolling share a precise-position follower:
0.9934 convergence per whole elapsed millisecond, one integration step per callback,
and a 10-point change in per-callback displacement when accelerating toward the
target. Retargeting preserves displacement, including braking through reversals.
Distant targets require one viewport of travel before shortening the remaining
distance to two viewports. Completion snaps exactly when within half a point.

Row target calculations, focus guards, held-input fast scrolling, horizontal paging
and the explicit hero/detail transition retain their existing behavior. Explicit
detail transitions and resets cancel the ordinary row driver before taking over.
Home snapshot shifts translate both the follower and its target together.

Supporting compiled evidence: UIKitCore process-entry at
`0x193b3b278–0x193b3b478`, acceleration limiter at `0x193b3b60c–0x193b3b674`,
heartbeat at `0x193b3ac30–0x193b3ac44`, and hyperjump at
`0x193b3b6e4–0x193b3b79c`. Full local findings and route limitations are retained at
`~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/apple-scroll-research/`.
Static evidence establishes the recovered model, not identical physical-device
feel or a remedy for rendering hitches. Those remain separate validation questions.

The current precision probe settles the three original targets in 69–77 callbacks
at 59.94 Hz; rounded feedback still stalls two points short after 600 callbacks.
The older measurements below describe the previous implementation.

## Physical comparison — 2026-11-12

Compared fresh Apple TV and Rivulet Lab recordings on Stue, Apple TV 4K
(3rd generation), tvOS 27.2 (24K122), 4K SDR 59.94 Hz output. This runtime
build differs from the 24K154 binary research. No app code or motion constants
changed during this comparison.

- Three ordinary Apple poster-row moves and all five Rivulet moves travel about
  516 pixels in 1080p coordinates. Apple's first move travels about 560 pixels
  because its row spacing differs. Matching travel does not establish identical
  tile dimensions or resting positions on every surface.
- Apple's ordinary paths and Rivulet's first path closely follow the current
  model with convergence and acceleration held fixed. Apple reaches 95% travel
  in about 0.50–0.52 seconds; Rivulet takes about 0.52–0.53 seconds. Allow roughly
  one captured frame of timing uncertainty and several pixels of tracking error.
- Rivulet moves 2–5 hold at roughly 242–244 pixels of travel from about 133 ms
  until movement resumes at about 183 ms. Focused-poster changes continue while
  the page holds, arguing against a duplicated whole recording frame. A second
  artwork crop reproduces the plateau. Interrupted app-driven offset updates
  are the concrete next investigation; callback starvation, synchronous update
  work and layer submission have not been separated.
- Separate Instruments runs recorded 12 Rivulet hitches (about 200 ms) and
  24 Apple hitches (about 417 ms). Navigation amounts differ, so these totals
  must not rank app performance. Apple was not hitch-free under profiling.
  The videos and traces are separate runs, not synchronized event pairs.
- Exact input-to-scroll and focus-callback-to-scroll latency remain unresolved:
  the videos contain no timestamped remote presses or internal focus events.
  Visible focus effects precede page motion in both apps.

The actual Swift helper was compiled into a trajectory probe for comparison.
Video tracking retains source timestamps without 60-fps resampling; encoded
sample cadence is not app FPS. Full local report, CSVs, scripts, recordings and
traces: `~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/row-scroll-comparison/report.html`.
Keep constants unchanged while investigating the repeatable page-update pause.

## Pause mechanism and optimized baseline — 2026-11-12

The existing Debug trace contains three long client updates lasting 39.38,
45.49 and 36.21 ms. Main-thread samples during each show the same chain:
outer collection layout → `configureShelfRow` → `ShelfRowCell.configure` →
`reloadData` / forced inner layout → poster reuse/configuration. The scroll
callback is absent from these blocks except for occasional boundary samples;
it waits while the main thread prepares the shelf. Poster reset changes
`TVPosterView` images, with image-view/layer work and some histogram calculation
in the stacks. Sample weights are not invocation counts or exact method costs.

Built the unchanged branch in Release, installed it as Rivulet Lab build 93,
and recorded two further Animation Hitches + Points of Interest traces. The
first was downward-only by Daniel's clarification; the repeat requested five
Up moves followed by five Down moves. They are separate runs, not matched
frame-for-frame benchmarks. Ordinary preparation updates still take about
31–41 ms in the downward run and 27–35 ms in the repeat. Existing CellPrepare
signposts also measure substantial preparation intervals. Release therefore
does not eliminate the blocking path. Both runs also contain separate focus
work; do not attribute every hitch to shelf preparation.

Thermal state is nominal throughout the Debug, Apple, Release and repeat
traces. No measured thermal throttling explains this pause. The 59.94 Hz
refresh period is 16.683 ms versus 16.667 ms at 60 Hz, a 0.1% difference.
Both stable intervals truncate to 16 ms in the recovered follower; this does
not produce the observed mid-scroll plateau. The display link follows display
cadence rather than a hard-coded 60 Hz timer.

Matching ordinary-row travel does not establish identical focus decisions or
all resting positions. Initial focus updates themselves can exceed a refresh
interval, but the identified preparation block occurs later, during scrolling.
Exact input/focus-to-scroll latency remains unmeasured. Changing row placement
or easing is not an established remedy for this preparation cost.

The causal mechanism is main-thread starvation of app-driven offset updates;
the best code change within preparation remains unverified. Reduce repeated
shelf/poster setup or move preparation out of the scrolling deadline before
changing the curve. Do not move UIKit operations to a background thread or
restore the previously rejected artwork-retention experiment as a proven fix.
No app source or constants changed during this investigation. The optimized
Release build remains installed on Stue. Local details: `row-scroll-comparison/pause-root-cause.html`
under the November 12 research root above.

## Independent review and validation metric — 2026-11-12

Claude's independent review re-derived frame classifications from the raw traces.
Full report and reproducible scripts/tables:
`~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/independent-review/REPORT.md`.
This refines the earlier summaries; raw hitch totals combine different phases.

- Onset updates are predominantly focus work and also occur in Apple's app.
  The review attributes the old 36–51 s warm-row counterexample to 20 onset
  updates plus one render-side event. Shared cost is not proof it is impossible
  to improve, but it is separate from the first optimization target.
- The visible mid-scroll pause corresponds to synchronous shelf rebind work,
  near 244 points of travel. The review estimates substantial reuse/reset work,
  including setting blank artwork, and additional new-cell and forced-layout
  work. Those statistical estimates are not guaranteed optimization savings.
- Short tail updates after commit gaps should not be counted as equivalent to
  long blocking updates. The actual Swift trajectory's first unchanged
  half-point-rounded offset occurs at 850.85 ms, corroborating the review's
  sparse-commit explanation. Whether this class is ever perceptible remains
  unresolved; a short update alone does not prove invisibility.
- `ImageDecode` signposts encompass the awaited image-loading operation and
  scheduling, rather than measuring only CPU decode work.

The historical artwork-retention experiment neither established a visual
benefit nor ruled one out. Its uncontrolled aggregate counts were insufficient
to reject the optimization itself. It may be revisited as a controlled
experiment, with stale-image, placeholder, cancellation and focus-state checks.

Validate candidate changes per move: identify onset, measure the mid-scroll
client update around 150–260 ms afterward, and inspect excess frame lifetime
and the visible plateau separately from short tail commit gaps. First evaluate
avoiding unnecessary blank-image assignment; then evaluate reconfiguration in
place when safe. Keep constants, row targets and native focus effects unchanged.
This review updated documentation only; app source and constants are unchanged.

## First entry versus repeated boundary — 2026-11-12

Daniel observed a visible hitch when a move realizes another poster row, but
not while repeatedly reversing over the same boundary afterward. Captured
`row-scroll-comparison/rivulet-first-entry-revisit.trace` on the unchanged
optimized Release build, PID 818; the local artwork-reset patch was not installed.

Focus-dominated update windows identify 15 moves. The first and move 14 have
eight CellPrepare intervals each (including enclosing/nested intervals); the
other 13 have none in the following 50–500 ms window, clipped before the next
onset. Their largest updates in that window range from 4.94 to 11.37 ms,
median 8.85 ms. Focus-onset work persists, median 27.35 ms. Thermal state is
nominal throughout.

The two preparation events predominantly construct new PosterCells, with no
sampled PosterCell.prepareForReuse or clearArtwork work. Their longest
CellPrepare intervals are 40.46 and 28.94 ms. Whole client-update intervals
extend farther and must not be interpreted as exact continuous CPU time.
This supports the first-appearance observation and distinguishes it from the
earlier recycled-row reset cost. Skipping blank assignment on reuse is not
expected to remove new-cell construction; both cases require separate validation.

The actual inferred move spacing is 0.45–1.08 seconds, mostly about 0.6 s,
so this is a rapid-reversal test, not the requested three-second isolated
sequence. Onsets are inferred from sampled focus work, not input markers;
row identities and the reason for renewed preparation at move 14 are not
established. Files alongside the trace: `revisit-per-move.csv`,
`revisit-analysis.json`, `revisit-report.html`, `analyze_revisit.py`, and
`revisit-*.xml`. The artwork-reset measurement follows below.

## Artwork-reset Release experiment — 2026-11-12

The working patch retains artwork through PosterCell reuse and directly replaces
it on a cached rebind. Uncached/missing images and explicit placeholders still
clear immediately. Changing between poster and square artwork retains the
correctly sized blank-image reset required by TVPosterView geometry. Motion
constants, row targets, focus behavior and native effects are unchanged.

Recorded three ten-Down sequences on Stue, requested about three seconds apart:
unchanged Release PID 818, newly launched patched Release PID 1107, then a warmed
repeat in PID 1107 after returning ten rows Up. All mid-scroll maxima occur about
163–167 ms after inferred focus onset. Compare per-move updates, not hitch totals.

| Run | Sampled recycled-only moves | Median binding update | Median associated frame lifetime |
| --- | ---: | ---: | ---: |
| Baseline | 10 | 35.41 ms | 83.41 ms |
| Initial patch traversal | 8 | 35.53 ms | 83.41 ms |
| Warmed patch traversal | 10 | 29.16 ms | 66.73 ms |

The initial patch run also has construction (67.18 ms) and mixed construction /
reuse (46.95 ms), excluded from its recycled-only median. Remaining blank-image
stacks arise inside loadImage, so deferring the reset alone does not remove work
when artwork is unavailable synchronously. The warmed patch run has no sampled
construction or clearArtwork in its ten binding updates. Across those updates,
75 baseline main-thread samples contain TVPosterView.setImage under
PosterCell.prepareForReuse; the warmed patch has zero. These are statistical
samples, not exact method durations or invocation counts.

All ten warmed binding updates are shorter than their requested corresponding
baseline moves. The median reduction is 6.25 ms (17.6%). Associated frame lifetime
is 83.41 ms on nine baseline moves versus one warmed patch move; the others are
66.73 ms. Focus-onset medians remain similar, 26.42 versus 26.03 ms. Both compared
runs report nominal thermal state. This supports a modest warm-rebind benefit,
not removal of the pause: binding updates still take 27.69–35.86 ms. It does not
fix new-row construction or establish an improvement on detail/hero routes.

Onsets are inferred from focus-dominated CPU samples, not input signposts. Row
identities and exact cache hits are not logged. These sequential runs differ in
process age and warming; an alternating-order experiment would strengthen causal
confidence. The first patched traversal showed no clear recycled-update benefit.

Local evidence under the November 12 `row-scroll-comparison` directory:
`artwork-baseline-rebind.trace`, `artwork-patched-rebind.trace`,
`artwork-patched-warm-rebind.trace`, matching exported XML, per-move CSV/JSON,
`analyze_per_move.py`, `compare_artwork.py`, and `artwork-comparison.html`.
The unchanged installable app is retained as `artwork-baseline.app`.
Release build and eight focused artwork/edition tests pass, including cached
replacement, both aspect-change directions and uncached/missing/placeholder
fallbacks. The full simulator suite passes all 3,648 cases on the final run.
The preceding full run passed 3,647 and failed the season-rail scroll assertion
in BelowFoldRailScrollTests after its fixed 0.6-second run-loop wait. That suite
passed alone, then the full suite passed without source changes; retain this
intermittent failure in the validation record rather than claiming an always-green
run. The patch remains uncommitted and installed on Stue.

## Memory ownership and idle preparation — 2026-11-12

No further Rivulet implementation changes were made. Two new physical captures
and a standalone simulator probe investigate the remaining mechanism. Full local
report, reproducible analysis, exports and raw evidence:
`~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/memory-prefetch-investigation/report.html`.

The already-warm PID 1312 run reports physical footprint 68.77 MiB initially,
79.13 MiB peak and 67.86 MiB finally. Daniel had already visited the bottom and
the Up/Down sequence was approximate. Time Profiler samples contain new-poster
construction but no sampled memory-warning/purge stacks: the earlier two purge
events do not establish that every construction event requires a warning.

The fresh launch under Allocations, PID 1383, peaks at 494.89 MiB footprint and
ends at 232.16 MiB. Instruments' full-run Created & Persistent statistics show
497.92 MiB heap plus anonymous VM allocations, including 398.30 MiB CG Raster
Data. The largest allocation stack is ImageCacheManager.downsampledImage through
ImageIO and CG bitmap-copy allocation. Allocation totals and physical footprint
are different measurements; do not sum them. The allocation stack identifies
where buffers were made, not whether a cache or image view retains each one.
Footprint declines rather than continuously growing over the captured interval.

The fresh navigation confirmed six Down/six Up from the hero; a second pass was
requested later without timestamped input or confirmed completion. Do not call
this a controlled two-pass leak test. Allocations adds overhead, saving reported
overlapping dyld timeline mappings, and the VM Tracker snapshot graphs are empty.
No source-supported cache risk is thereby a proven leak or warning cause.

The source audit identifies a 400 MiB / 100-object main NSCache policy, other
rendered-image caches, and image references retained outside those caches by
hero views and per-row reuse pools. NSCache cost limits are not strict. Download
bytes are coalesced but same-key decoded-image tasks are not, so concurrent
duplicate decoding is possible. No explicit app memory-warning handler was found
in Rivulet/RivuletCore Swift source; Foundation may independently evict caches.

Device jetsam reports also show substantial system-media memory use. At 17:10,
the frontmost Release PID 818 has about 64.9 MiB in rpages while mediaplaybackd,
backboardd and videocodecd are much larger. The suspended upstream PID 756 is
reclaimed under sustained pressure. The 17:29 report identifies mediaplaybackd
with per-process-limit and about 2,099 MiB, while PID 818 is about 77.6 MiB.
These reports do not match individual warning frames exactly or identify the
client responsible for media-service allocations. Preserve timeDelta/genCounter;
late aggregate reports must not be treated as fresh snapshots from filenames.

The standalone tvOS 27.2 simulator probe (24K150, versus Stue 24K122) corrects
two earlier suspicions. isScrollEnabled=false alone does not block idle cell
preparation, and neither does a row-sized outer item. All tested public prefetch
flags and diagnostic readonly private gates are true. Direct CADisplayLink
offset writes create 66 flat cells with zero idle-path calls in either scrolling
setting. Native animated offsets create 54 cells through the idle path and 18
otherwise, also in either setting. Native animated row-sized cells yield nine
idle calls and three others. UIUpdateLink before-CADisplayLink and
after-update-scheduled variants, plus pulsed CADisplayLink writes, still show
zero idle-path calls. Complete synchronous stacks, not data-prefetch callbacks,
establish these counts. Run 2 required a foreground relaunch after an activation
gap; later motion phases completed. Its raw evidence records that limitation.

This supports native animated-scroll machinery as a stronger distinction than
the disabled scroll flag or callback phase. It does not recover the exact missing
internal state in Rivulet. The probe uses cheap flow-layout cells; Rivulet uses
compositional layout and forced nested shelf realization. Shelf granularity
still controls synchronous work per preparation, even though it does not by
itself disable prefetch. No private API belongs in the shipping implementation.
The dedicated probe simulator was removed; Rivulet was neither rebuilt nor
reinstalled during this investigation.

## Historical stopping point

Daniel asked to stop after one last signpost trace unless it exposed a clear,
small fix. The trace narrowed the remaining problem but did not establish such
a fix. No more performance experiments should be implied by these notes.

Kept changes:

- Use CADisplayLink.targetTimestamp and one display interval for the first tick,
  instead of including the wait between requesting a scroll and its first callback.
- Integrate delayed callbacks in steps of at most 1/60 second, retaining the
  existing easing constants, acceleration, and 50 ms elapsed-time cap. This has
  mathematical regression coverage, but its incremental visual benefit was unclear.
- Retain the unrounded animation position between ticks. Initialize from the real
  collection offset when starting a new animation; preserve it when retargeting.
  This prevents UIKit's half-point rounding from feeding back into the integrator.
- Preserve the existing focus behavior and fast-scroll driver.

Temporary debug output and Instruments signposts were removed before committing.
`evidence/PlexHomeViewController.instrumented.swift` preserves the complete
instrumented source for reference. Do not overwrite a future controller with this
snapshot: selectively port the tracing. The saved controller patch is relative
to the original base and contains both the fix and instrumentation.

## Evidence and confidence

The first timestamp adjustment felt clearly smoother to Daniel. Video comparison
did not establish a clear additional benefit from substeps. Recordings have uneven
timestamps, missing frames, different scroll distances, and different input cadence;
their average capture frame rate is NOT the app's rendered frame rate.

Device debug trace before precision fix (`device-scroll-trace.txt`):

- Initial movement builds approximately 10, 20, 30, 40 points per frame.
- Callback gaps up to 66.732 ms; a gap is followed by an approximately 84-point move.
- Applied offset differs from the requested value by at most 0.25 points in this
  sample, consistently showing half-point rounding. No between-callback offset
  discrepancy in the captured 53 frames.
- The synchronous scroll update takes less than 0.4 ms in this sample. That does
  not include later layout, transaction commit, rendering, or all focus work.

Rounding reproduction (`PrecisionProbe.swift`, using the actual helper):
feeding the half-point-rounded value back stalls two points short of targets
515, 982.5 and -515 after 600 frames. Keeping the precise value settles in
65–73 frames. This is a numerical reproduction, not an integration test of UIKit.

Device validation after precision fix (`device-scroll-precision-trace.txt`):
16 reported scroll completions, every actual offset equals its final target.
Isolated 516-point moves finish around 1.1 seconds. Callback gaps still reach
66.732 ms. The first sequence contains multiple retargets, so its total duration
must not be described as one isolated scroll. This verifies correct completion
on-device, not elimination of visible hitches.

## Final Instruments trace

Original local recording: `Downloads/rivulet-scroll-signposts.trace`.
Apple TV 4K (3rd generation), tvOS 27.2 (24K122), Release Profile build.
Duration 66.434 seconds. Animation Hitches + Time Profiler + Points of Interest.
Exports are `latest-hitches.xml`, `latest-time-profile.xml`, `latest-os-signpost.xml`;
TOC is `signposts-toc.xml`. Scripts and output are in the local `evidence/` directory.

86 hitches totaling 1434.744 ms across the recording. This includes startup and
unequal interaction periods; do not compare raw totals with the earlier traces.

| Interval | Behavior | Hitches | CellPrepare intervals | ImageDecode intervals |
| --- | --- | ---: | ---: | ---: |
| 10–25 s | Navigating among several row targets | 32 | 85 | 11 |
| 36–51 s | Repeated targets 3046.5 / 3562.5 | 21 | 0 | 0 |

The latter interval also has no sampled ShelfRowCell.configure stacks. It still
contains focus searches, layout, layered poster focus/parallax effects, and Core
Animation commits. Thus preparing/decoding new posters is NOT necessary for the
remaining hitches. This does not establish which piece is fixable or justify
disabling native focus effects. All captured ScrollStep intervals are <=1.183 ms.
Twenty of the 21 repeated-row hitches were labeled potentially expensive app
updates; one flagged rendering with 12 offscreen passes. Those labels are clues,
not causal proof. Sample counts overlap across stack frames and are not call counts.

The os-signpost XPath exported duplicate events from multiple matching tables.
Deduplicate events and intervals (as signpost-windows.py does) before counting.
Hitch counts come from the separate hitches table. XML id/ref resolution is
document-wide. Metadata numbers use localized decimal commas and grouping spaces.

## Rejected experiment

Retaining poster artwork through prepareForReuse reduced sampled image-reset work
but did not demonstrate smoother scrolling. It and its tests were fully reverted.
Baseline: `rivulet-home-scrolling.trace`; experiment:
`rivulet-home-scrolling-artwork-fix.trace`, both in Downloads. In the approximate
8–26 s windows, 45 vs 54 hitches; input sequences were not controlled, so this does
not prove a regression. Do not reintroduce it as a proven performance fix.

## Resume later

1. Read this note and inspect the commit, rather than restoring instrumentation
   wholesale. Reconfirm current source and upstream changes.
2. Prefer a reproducible warm-row focus transition. Compare click-only with touch
   input; the final repeated-row trace contains UIKit pan/focus-effect stacks.
3. Inspect the main-thread work immediately preceding ScrollDelayedFrame events,
   separating focus search/layout from focus effects and transaction commits.
4. Any experiment should retain native interaction and have an A/B device trace.
   There is no established need for private APIs or a large rewrite.

Validation: simulator app build + four existing XCTest cases and six parameterized
Swift Testing cases passed throughout; final result recorded below. SwiftLint clean
for changed files. Full suite not rerun; earlier reported full-suite failures in
photo-date, Live TV title and TMDB tests were not established as regressions here.
Xcode diagnostics show four existing warnings outside the changed scroll driver.

Raw videos and .trace bundles remain in Downloads/Desktop at their supplied paths;
they have NOT been duplicated here. Extracted tables, motion CSVs, plots, contact
sheets, numerical probes, analysis scripts, and console traces are preserved in the
local `evidence/` directory.
The artifacts can contain personal library imagery and should remain local.

Final verification: clean simulator build and all targeted tests passed after removing
instrumentation. Final build log is `evidence/final-tests.log`. No full-suite run.
The tracked reproduction scripts accept input paths; see `evidence/README.md`.
Older, untracked investigation scripts still contain their original local paths.
