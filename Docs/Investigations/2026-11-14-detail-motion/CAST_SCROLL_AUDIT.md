# Cast-row scroll hitch follow-up

## Current state: later experiments reverted

On 15 November Daniel requested an end to the performance experiments. Retain
the first fix: off-main circular cast-photo preparation, a bounded rendered-image
cache, and cancellation/stale-result protection. That is the change for which he
reported a clear improvement. The subsequent placeholder/image-assignment cleanup
and hero focus-handoff/reset edits have been reverted. All temporary blur/glass
diagnostic hooks and their helper file have been removed. Normal effects are
restored; all recordings are stopped. No further profiling is authorized by this
completed diagnostic sequence without a new request.

The detail motion and season-selector implementation Daniel liked is retained.
The later sections below are historical evidence and experiments, not a list of
active fixes. No reliable additional hero-scroll hitch fix was established.

Rollback validation: all 3,618 tests passed serially (3,701 executions, zero
failures/skips), SwiftLint found zero violations, and the normal Debug build
was installed and launched on Stue without a debugger (PID658). Results:
`/private/tmp/rivulet-performance-rollback-20261115.xcresult`. Device build log:
`/var/folders/bf/h64vt90x6ng70m3_wqd7dtb80000gn/T/ActionArtifacts/default/RunProject/RunProject-Log-20261115-003954.txt`.
The preview controller matches the pre-performance-experiment index version.
No commits or pushes were made.

14 November 2026. Daniel reports a hitch entering a show's episode details when
Cast & Crew is immediately below episodes. Entering the show's root, where a
trailer row intervenes, feels smoother. This is a UIKit surface; the requested
performance-audit workflow was applied to main-thread image and layout work.

## Code-backed finding

CastCell.configure previously called its circular bitmap renderer synchronously
for every decoded image-cache hit. Cache misses also rendered inside MainActor.run
after loading. Rebinding the same photo redrew it because only the source image
was cached. When several cast cells are realized together during the transition,
their clipping, aspect-fill drawing and bitmap allocation compete with scrolling
on the main thread. Trailer cells do not perform this circular-photo preparation.
An intervening trailer row also places cast farther below the initial viewport.

This is a concrete avoidable cost consistent with the report, not a sampled proof
that it accounts for the entire physical-device hitch. At this initial stage no
frame-drop, CPU-time or memory-peak delta was measured; the later device traces
are recorded below.

## Change

CastArtwork prepares the circular image through an explicit @concurrent function
and caches the finished bitmap by URL, point size and display scale. The cache
has a 32 MiB cost limit. Synchronous lookup never draws a missing image. Source
loading still goes through the existing ImageCacheManager; no second downloader
or disk cache was added. The cell only assigns the completed image on the main
actor. Superseded/deallocated cells cancel their tasks; cancellation and the
existing configuration token prevent stale completion from replacing new content.

The aspect-fill circle, transparent corners and native masked focus effect are
preserved. Transition timing, section movement and season-selector behavior are
unchanged. Placeholder images remain visible until uncached preparation completes.

## Validation and device comparison

All 3,618 tests passed (3,701 executions, zero failures/skips). Targeted checks
also passed after removing a test diagnostic warning. New coverage verifies
background execution, transparent circle geometry, reuse of the rendered bitmap,
size/scale cache separation, and cancellation after source loading followed by a
successful retry. SwiftLint reported zero violations.

Full result: `/private/tmp/rivulet-cast-scroll-20261114.xcresult`.
Final targeted result: `/private/tmp/rivulet-cast-scroll-verified-20261114.xcresult`.
The device build succeeded and launched on Stue (PID554); log:
`/var/folders/bf/h64vt90x6ng70m3_wqd7dtb80000gn/T/ActionArtifacts/default/RunProject/RunProject-Log-20261114-230009.txt`.

Next compare the same episode-entry route with Cast & Crew directly beneath
episodes, first entry and repeated hero-to-details entry, against the show-root
route. If the hitch persists, record that interaction with Time Profiler and
animation-hitch data to distinguish remaining cell/layout cost from rendering
or focus-scroll work. Installation and simulator tests do not prove the reported
physical-device hitch has disappeared. Implementation changes remain uncommitted.

## Release profiling on Stue

Daniel reported that the major hitch was gone but small hitches remained in the
optimized Release build. Recorded two Down/Up repetitions on each route using
Animation Hitches plus Time Profiler, system-wide on Stue (AppleTV14,1,
tvOS 27.2.1). Filtered analysis to the verified Release process Rivulet (556).
Direct process attachment could not find the process, so system-wide recording
was used. Recording has stopped and both usable traces are saved locally.

| Captured route | App-attributed hitch events | Longest reported hitch |
|---|---:|---:|
| Cast & Crew immediately below episodes | 17 | 16.67 ms |
| Trailers-first comparison | 13 | 33.33 ms |

Duplicate display rows with process n/a are excluded. These are descriptive
capture totals, not a strict A/B benchmark: the trailers run also includes a
carousel expansion, input timing differs, and profiling introduces overhead.
The aborted navigation-only trailers recording is excluded. Reported hitch
duration is missed presentation time; it is not the same as app-update duration.

The cast run does identify remaining work during two long app updates:

- At trace 29.211080s, the update lasts 43.76 ms. In its 44 ms sample window,
  collection layout takes about 26 ms; vending cells takes about 23 ms, including
  roughly 13 ms in CastCell initialization. UIKit constructs the image view's
  layered focus-effect hierarchy. These inclusive sample weights overlap.
- At 35.110918s, the repeat update lasts 26.80 ms. Its samples include about
  16 ms in CastCell.configure, with 14 ms assigning the UIImage, 12 ms configuring
  the layered-image stack, and 10 ms checking the nonopaque shadow state. The
  stack descends into vImage alpha conversion. Those are nested weights, not
  additional independent costs. Our circular bitmap renderer is no longer doing
  this work on the main thread; UIKit performs its own image/focus preparation.
- The trailers run's 24.31 ms update at 19.893776s includes about 17 ms in the
  early-focus callback inside advanceSlide, about 16 ms updating focus, and
  native focus animations/FocusableActionButton visibility work. This provides
  a separate, shared transition cost rather than a cast-specific image issue.

Both runs also have render/GPU warnings. Repeated cast frames were flagged with
22 and 101 offscreen passes; trailers frames include 17 and 86. These are
Instruments diagnostics, not proof that one particular blur or mask caused each
miss. They do establish that CPU image preparation alone does not describe all
remaining frame costs.

Next optimization targets are cast-cell realization/reuse and UIKit image/focus
setup during entrance, plus the synchronous focus handoff inside the display-link
callback. Preserve the recovered movement and focus appearance; any scheduling
or preparation change needs another matched device capture. These traces do not
justify changing easing constants or disabling native effects indiscriminately.
No additional app code changed during the profiling pass.

Durable local root:
`~/.codex/visualizations/2026/11/14/01a1db10-f35a-7aa0-95c5-6e6738b505e9/detail-motion/profiling-release/`

Usable traces are `season-cast-system.trace` and
`season-trailers-ready-system.trace`. `summary.json` and ten exported query
reports retain counts, interval timestamps and the symbolicated call trees.
`season-trailers-system.trace` is the excluded navigation-only capture.

## Standard Rivulet comparison

Recorded the app Daniel selected as TestFlight, on the same show's trailers-first
view, with two reported Down/Up repetitions. Inventory identifies standard
`com.gstudios.rivulet`, version 1.3.0 build 127, process 422, separately from
Lab 1.3.1 build 93, process 556. Inventory marked builtByDeveloper true; a
TestFlight receipt/distribution origin was not independently verified. The
comparison is between those identified installed apps. Both captures use the
same Animation Hitches + Time Profiler setup on Stue. Recording is stopped.

| Trailers-view capture | App hitch events | Total reported hitch time | Maximum hitch |
|---|---:|---:|---:|
| Standard Rivulet 1.3.0 (127) | 10 | about 233 ms | 50.00 ms |
| Lab Release 1.3.1 (93) | 13 | about 233 ms | 33.33 ms |

Standard has seven 16.67 ms events, two 33.33 ms events and one 50 ms event.
Lab has twelve 16.67 ms events and one 33.33 ms event. Duplicate n/a display
rows are excluded. Summing rounded display values produces 233.35/233.37 ms;
that rounding difference has no interpretive significance. These are capture
totals, not frame-drop rates or repeated-trial benchmark statistics.

The standard app has a 29.06 ms update starting at 26.059007s. In a 30 ms CPU
window, a display-link callback leads through unsymbolicated Rivulet frames into
updateFocusIfNeeded (about 25 ms), focus update (22 ms), TVCardView/TVLockupView
appearance work (20 ms), floating-content focus animation (16 ms) and view
visibility work. Weights are inclusive and approximate. This is the same broad
focus-transition cost category seen in Lab's early-focus handoff. It does not
establish identical app-level implementations, because the standard app's own
frames lack matching symbols (image UUID 9EC423F0-371C-3F40-8E69-BE30BA8A1878).
The current Lab dSYM must not be used to assign names to that different binary.

Another standard-app update at 33.908845s lasts 37.93 ms and includes native
arrow-input focus navigation and focus-region snapshot/search work. Its largest
50 ms presentation hitch is flagged for render/GPU work, with 20 offscreen passes.
The other multi-frame hitches also have render/GPU warnings. This independently
confirms that trailers-view hitching and native focus/rendering costs exist in
the standard app, outside this experiment.

This does not prove that every hitch is pre-existing or that the animation changes
cannot regress a particular phase. The apps have other version differences, the
input timing differs, Lab's capture contains carousel expansion, and profiling
adds overhead. No standard-app cast-first capture was made, so the separate
cast-specific cost is not controlled by this comparison. The evidence supports
retaining the current choreography while targeting measured focus/setup and
rendering costs, followed by matched before/after captures of any optimization.

Local trace: `testflight-trailers-ready-system.trace`. Local comparison summary:
`testflight-comparison.json`, alongside five exported standard-app query reports
in the same profiling evidence root. No app code changed during this comparison.

## Conservative setup/focus follow-up, 15 November

Further return-window queries find about 13 ms (cast route) and 16 ms (trailers
route) in native focus-map capture/search. This is distinct from cast photo
preparation and precedes the application's return handler in the sampled path.
Queries are saved as `cast-return-update.txt` and `trailers-return-update.txt`.
The shared focus-search and render/GPU costs remain unresolved.

The next implementation pass avoids assigning a placeholder during CastCell
initialization. Configure binds the cached final photo directly when available;
missing/uncached photos still receive the same placeholder. Both synchronous
and asynchronous assignments skip an identical UIImage object, avoiding
redundant native layered-image preparation. Focus flags and circle rendering
are unchanged. The new regression checks cached binding and clearing reused
content for a person without artwork.

The entrance now disables hero action-row focus before requesting the selected
episode, rather than invalidating the old row after focus has already changed.
The redundant focus request at return-slide completion is removed, so a completed
slide does not request the default hero target again after focus was restored.
The actual entrance and return handoffs still resolve synchronously.

An attempted change to use only setNeedsFocusUpdate failed the selected-episode
landing regression when the test exercised the deferred focus path. That change
was discarded. The final implementation and regression retain the synchronous
handoff; do not simply remove updateFocusIfNeeded to move cost out of the
display-link stack without solving initial focus ownership first. No motion
constants, travel geometry, fade rules, native focus effects or remote guards
were changed. Physical-device appearance/performance comparison remains needed.

Final full serial suite: 3,619 tests passed (3,702 executions, zero failures/skips),
result `/private/tmp/rivulet-focus-setup-final-20261115.xcresult`. SwiftLint is clean.
Two earlier parallel runs failed the unrelated timing-sensitive music-favorite
test; it passed in isolation and in both full serial runs. Its 20 ms/200 ms
scheduling assumptions were left unchanged. Failed runs and the discarded
coalesced-focus regression remain available in `/private/tmp/rivulet-focus-setup*`.

Debug built, installed and launched on Stue without a debugger (PID613). Log:
`/var/folders/bf/h64vt90x6ng70m3_wqd7dtb80000gn/T/ActionArtifacts/default/RunProject/RunProject-Log-20261115-000518.txt`.
No post-change performance capture has been taken, so no measured hitch-reduction
claim is made for this pass. Implementation changes remain uncommitted.

## Effect-isolation results and rollback

The matched Debug normal-effects capture (PID620) recorded 9 app hitch events,
about 166.69 ms total. The fullscreen-blur-disabled run (PID645) recorded 14,
about 300.03 ms total. On the comparable high-pass frames, GPU durations changed
from 22.439/24.157 ms to 20.074/19.844 ms; offscreen passes changed from 86 to84.
Daniel felt the blur-disabled run was the smoothest, but the aggregate metrics
did not establish a fix. Both the subjective report and the contrary aggregate
numbers are retained; neither should be silently discarded.

The hero-action-glass capture was interrupted when Daniel asked to stop the
experiments. It is not a completed controlled comparison and was not analyzed
for a result. Normal effects were restored immediately afterward. Source review
also showed that the branch keeps moving hero chrome at full opacity where the
pre-branch implementation faded it early, and uses a different blur-compositing
path. Standard-app hitching therefore does not prove equal branch rendering cost.

The requested rollback removes every later unproven performance edit and all
diagnostic switches, while retaining the original cast-photo fix and the approved
animation work. Raw traces and query reports remain local for reference.
