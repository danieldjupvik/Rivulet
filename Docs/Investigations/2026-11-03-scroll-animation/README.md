# Scroll animation investigation — 2026-11-03

Branch: `fix/scroll-animation-improvements`, based on fork main `96332a09`.
Commit: `13ffdc938a8600d34e46ba99f555dcdb3a419c20` — `fix: improve focus scroll timing and settling`.

This note is tracked on the feature branch so its findings survive checkout cleanup.
The adjacent `evidence/` directory remains local and gitignored: raw exports,
recordings, and imagery are not included in the documentation commit. Evidence was
copied out of `/tmp/rivulet-scroll-review` to preserve it beyond temporary-directory
cleanup. Back up that directory separately before deleting the local checkout.
This investigation note can be omitted from an eventual upstream contribution.

## Stopping point

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
Analysis scripts retain their original /tmp paths; update those paths to the local
evidence directory (and supplied video paths) before rerunning later.
