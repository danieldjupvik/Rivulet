# Detail motion resumption, 14 November 2026

## Cast-row hitch follow-up

[The cast-scroll audit](CAST_SCROLL_AUDIT.md) identifies synchronous circular
photo redraws during cast-cell binding. Preparation now runs off the main actor,
with a bounded cache of finished circles. All 3,618 tests passed and the updated
build launched on Stue. Subsequent Release profiling confirms remaining cast-cell
creation/native image-focus setup and a separate synchronous focus-handoff cost.
The audit records measured intervals, rendering warnings and comparison limits.
The standard-app trailers comparison also contains focus/rendering hitches, with
about 233 ms total reported hitch time in each captured run. This establishes a
pre-existing cost category, without isolating every animation change causally.
Daniel stopped the later performance experiments on 15 November after reporting
no noticeable improvement. Those edits and all temporary diagnostic switches
have been removed. The initial off-main cast-photo preparation/cache fix is
retained, alongside the animation and season-selector work he liked. No profiling
is active. The audit preserves the mixed evidence and rollback scope.
The rollback passed all 3,618 tests serially, lint is clean, and the normal Debug
build is installed and running on Stue.

## Directed season-selector follow-up

[The geometry and focus follow-up](SEASON_GEOMETRY_RE.md) recovers additive
8-point focus growth, separate title/background transforms and shared-parent
peeking compensation. It also records why exact page-specific starting position
and travel are still unresolved. The subsequent implementation separates capsule
and title scaling, uses semantic Body semibold text and 30-point padding, and
suppresses the selected capsule while another season has focus. Background fill
remains an approximation; the unresolved travel correction is unchanged.
All 3,616 tests passed (3,699 executions), lint is clean, and this updated build
was installed and launched on Stue. Complete visual parity remains unverified.

[The directed investigation](SEASON_SELECTOR_RE.md) identifies the multi-season
native horizontal index-title bar and its compiled midpoint fade. Both season
alpha assignments now use max(2q-1,0), retaining the shorter rail movement.
Apple's recording supports removing the old linear fade tail, a likely cause
of the reported translucent ghost on return. Persistent rendered ghosting is
not established without a fresh current-version Rivulet capture.

Special peeking correction is selected-section/type/visibility dependent.
Other lower rows can inherit the common parent movement; no universal per-type
stagger schedule was recovered. See the directed report for conditions and limits.
The fade follow-up built and passed all 3,614 simulator tests; lint is clean.
The updated build was installed and launched on Stue for Daniel's next check.

## Implementation after deep RE

At Daniel's request, the implementation commits were flattened onto fork main
`31f1f890`. Research notes are committed separately; implementation changes remain
uncommitted. The old history is retained locally on
`backup/detail-motion-before-uncommit-20261114`. The merge records below describe
the earlier integration steps, not the current commit graph.

The current implementation replaces the fitted continuous slide with
`DetailScrollMotion`: integer-millisecond convergence, directional acceleration
limiting, unrounded state and momentum retained across animated retargeting.
The driver measures outer hero travel, mapped to the shorter primary-row path
using live layout distances. It does not insert a guessed per-row delay.

Focus entry again overlaps movement. Primary-row focus requests cannot replace
the active slide because of small geometry differences. Reset/reversal callbacks
are guarded against completing a superseded request, including immediate updates.
Ordinary row navigation still uses main's native focus-scroll coordinator.

The selected-season simulator regression reproduced a 100-point horizontal
shift when UIKit focused the already-positioned initial episode. The handoff
now suppresses that orthogonal scroller's second landing until the focus update
returns, then restores its previous scrolling state on the main queue. Restoration
is request-guarded and also runs on cancellation/replacement/completion. This
does not defer focus until the slide ends or impose a fixed input delay.

Primary artwork keeps the shorter rail displacement for movies and shows.
Supplementary headers and lower rows follow outer content travel. Primary
trailer/extra headings are included; season controls retain the episode path.
This applies the supported hierarchy distinction without claiming to recover
Apple's active template values. Poster shelves with embedded headings remain
composite cells, so those headings still travel with their shelf.

New regressions cover momentum/reversal, dropped or invalid heartbeats,
subpixel settling, focus callbacks superseding an active or immediate slide,
movie artwork/header separation and selected-season focus during movement.
The final combined build passed all 3,613 tests (3,694 executions including
dynamic parameters) on the tvOS 27.2 1080p simulator; SwiftLint found zero
violations. The new focus regression first exposed the 100-point rail shift,
then passed for animated and immediate handoffs after the ownership fix.
Final logs/results are `/private/tmp/rivulet-detail-re-final-20261114.log`
and `/private/tmp/rivulet-detail-re-final-20261114.xcresult`.
Physical-device captures, remote gestures and accessibility behavior still
require device validation; simulator success alone does not establish parity.

## Superseding deep RE findings

[The deeper investigation](RE_FINDINGS.md) recovered UIKit's default focus-scroll
recurrence, VideosUI's geometry-driven peeking hierarchy, and frame-by-frame
recording measurements. Hopper successfully analyzed UIKitCore after the Codex
restart. The recovered driver explains the earlier approximately .158s tail.

The initial fixes below were provisional: Apple's first card visibly gains focus
during movement, and movie primary artwork/header travel differs. Completion-only
focus and uniform cell/header translation should not be treated as Apple parity.
The implementation section above records the subsequent source changes.

## Recovered handoff

Branch `feat/detail-motion` was clean at `319587f4` when resumed. Its motion work
is in `90c21d12` (`chore: preserve detail motion experiment as work in progress`).
That commit records three remaining device-observed issues:

1. Season controls start inside the episode rail and rise too slowly with the logo.
2. Early episode focus reveals/repositions the season divider before the slide settles.
3. Movie sections miss the stagger because the first section is excluded by index.

`319587f4` subsequently merged fork main. It did not finish the experiment.

The earlier research is local, outside the repository:

`~/.codex/visualizations/2026/11/04/01a1a76d-da47-7a52-9349-f364741f4174/detail-motion-investigation/`

Start with `report.html`, `metadata/findings.md`, `episode/findings.md`,
`episode/findings-extra.md`, and `recording-measurements/results.json`.

## What the old Apple research established

The target was tvOS 27.2, build 24K154, AppleTV18,1. Successful evidence came
from `ipsw` metadata and original-cache ARM64 instruction bodies. REA/Hopper
had startup/cleanup problems; the old report is explicit that its results
were not successful new decompilation.

Recovered behavior includes showcase-height-normalized progress, backdrop
alpha `1-p`, title alpha `max(1-2p,0)`, and focus-coordinated episode-description
placement. Shelf scaling was conditional browser-inset handling, not proof of
a universal vertical-transition animation. Global .75s and .25s constants did
not establish the requested route's timing.

Recording fits supported an acceleration-plus-exponential-tail approximation
much more closely than quadratic easing for the measured downward logo travel.
The fitted .158s value describes tail decay, not total transition duration.
Those fits do not prove every layer shares that motion or recover Apple's source.

## Main integration and changes this session

Fetched and verified fork remote main at `31f1f8903c9b2aa79d9ab83dd37989cddc6f3bda`.
Prepared a local, uncommitted merge into the experiment. The remote motion branch
was still at `90c21d12`. No push or PR changes were made.

Conflicts were in `BelowFoldCollectionView` and
`FocusScrollControlledCollectionView`. Preserve main's native UIKit focus
scrolling, target/delegate forwarding, reset cancellation and scrolling restoration.
Only the hero/detail slide owns its display-link motion; ordinary row navigation
continues through `NativeFocusScrollCoordinator`. Cancellation clears both stale
completion and early-focus callbacks. Main's deterministic `advanceSlide(at:)`
test hook remains, using the experiment's motion model.

Provisional changes for the recorded WIP issues:

- Season controls follow the episode rail's displacement and begin fading with
  scroll progress, independently of the logo's longer trajectory/midpoint fade.
- The controller hands focus into details at slide completion, preventing the
  orthogonal episode/divider focus scroll from starting during the transition.
  This is a lifecycle boundary, not a fixed one-second delay.
- Staggered content movement excludes actual episode sections, rather than
  every section zero. A movie's first available trailer/related/cast section
  now participates. Cells and supplementary headers use the same selection.

These changes address identified code causes, but the deeper findings above
challenge the focus and movie-header policies. Visual matching, remote behavior,
and responsiveness still require implementation revision, fresh physical-device
captures and testing.

## New RE attempt

REA 6.8.0 successfully connected to Hopper this time. Reused the existing
same-build extraction at `/private/tmp/rivulet-player-tvos27-20261114/` rather
than downloading firmware again. Extracted VideosUI with `ipsw dyld extract
<cache> VideosUI --slide --output /private/tmp/rivulet-detail-motion-re`.

The new extraction's SHA-256 is
`1c011f45c5e11d36048d4637328fc8d7b8470e1c407bd75739d2a7e17ee6b9c7`.
It differs from the old report's extraction hash; keep identities separate.

Hopper returned assembly, pseudocode, and call/reference inventories for:

- `0x23a1480c4`, the canonical end-drag body identified in the old investigation:
  evidence `ev_aa94da3e5a488895c52700939f2727419537ae9fba9fef12dfda396257637298`.
- Its helper `0x23a2f624c`:
  evidence `ev_a5d3e2253d3bcb74cab66fc60cb0818fea60f7b8fccd50e9287eb856661e669a`.

These stripped bodies have unresolved external stubs and reconstructed register
expressions. They do not yet establish scroll timing or season-row choreography.
A procedure-name search for “Season” mainly found media/library operations;
that bounded search does not exclude stripped Swift UI implementations.

Original-cache Swift/ObjC metadata additionally identifies
`VideosUI.EpisodeSectionHeaderView` with `buttonView: SeasonPickerButton?` and
`viewLayout: ViewLayout?`. The picker has current/alternate labels, header titles,
current index and a delegate. This is a candidate route for further tracing;
its activity on the recorded screen has not been established. Metadata parsing
from the standalone extraction failed on an external indirect context descriptor;
parsing through the original shared cache succeeded.

Local durable output for this session:

`~/.codex/visualizations/2026/11/14/01a1db10-f35a-7aa0-95c5-6e6738b505e9/detail-motion/`

`rea-evidence.json` retains five evidence records and `rea-snapshot.json` allows
same-artifact/provider analysis reuse. The native session was closed cleanly.

## Comparison viewer

`index.html` in that output directory is a local paired viewer for all four
6 November recordings in `~/Downloads/*details-animation.mov`. It provides
paired playback, .1/.25/.5/1x speed, timeline scrubbing, 1/60s sampling, keyboard
controls, and separate source start offsets. Local MP4 viewing copies are
1280px wide and resampled to 60 fps. Original recordings are unchanged.

The clips have different artwork, seasons and focus/input timing. They predate
the current merge and fixes. Do not use their pixel differences or recording
frame-rate metadata as proof of current behavior or rendered FPS.

For final comparison, capture the same movie/show, artwork where possible,
season, episode, focus state and input sequence. Compare down, reverse, rapid
reversal, episode-to-description, season changes, and movie lower-row navigation.
Repeat with Reduce Motion and both swipe and discrete-press remotes.

## Validation and remaining work

The combined merge built and passed the full 3,603-test suite in the tvOS 27.2
1080p simulator. The full suite also passed after the three motion corrections.
A subsequent focused run passed all 11 executions (10 tests, one parameterized).
Regression coverage checks primary movie-row movement versus the episode rail,
slide cancellation, stale focus callbacks, immediate reversal and scroll restoration.
SwiftLint reported zero violations. No physical-device visual or remote validation
was performed in this session; simulator results do not establish Apple parity.

`Docs/DESIGN_GUIDE.md`, `Docs/RIVULET_PLAYER.md`, and the maintainer's
`rivulet-tvos-uikit` skill were unavailable. `Docs/UIKIT_FOUNDATIONS.md` and
current `CLAUDE.md` were read. Preserve one transition clock and native focus
ownership when extending this work.
