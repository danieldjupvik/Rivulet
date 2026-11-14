# Detail transition RE, 14 November 2026

This investigation substantially narrows the timing and choreography guesses.
It does not yet establish every active runtime setting or make the experiment
an Apple-matched implementation. It supersedes the parity assumptions behind
the provisional fixes described in [the initial handoff](README.md).

## Target and evidence provenance

Compiled target: tvOS 27.2, build 24K154, AppleTV18,1. Reused the extracted
original shared cache under `/private/tmp/rivulet-player-tvos27-20261114/`.
No firmware was downloaded again. Original-cache `ipsw` disassembly and metadata
resolve selectors, Swift witnesses, constants and view fields. Hopper/REA now
successfully decompiled both VideosUI and UIKitCore; the session was exported
and closed cleanly after recovering from the demo/bridge interruption.

| Extracted image | SHA-256 |
|---|---|
| VideosUI | `1c011f45c5e11d36048d4637328fc8d7b8470e1c407bd75739d2a7e17ee6b9c7` |
| UIKitCore | `989b223d6b3aefede80cd36c7dee32803514790deae2003b12d469dac0ddfe99` |

Local durable evidence root:

`~/.codex/visualizations/2026/11/14/01a1db10-f35a-7aa0-95c5-6e6738b505e9/detail-motion/deep-re/`

It contains `videosui-evidence.json`, `uikit-evidence.json`, corresponding
snapshots, `uikit-static/`, `season-static/`, and `recordings/`. Raw firmware,
decompiler output and personal library imagery remain outside the repository.
Addresses below are virtual addresses in this build, not portable API names.

## Recovered compiled timing

UIKit's `_UIFocusDisplayLinkScrollAnimator` implements a convergence recurrence,
not one fixed animation duration. The default convergence is **0.9934** and
the default acceleration limit is **10 per heartbeat**. Both are internal
preferences and can be overridden; the recorded device's preferences were not read.

For ordinary finite positions, ignoring optional external-offset adjustment,
each axis has this mathematical behavior:

1. Measure elapsed wall time since the previous heartbeat. Multiply seconds by
   1000 and truncate toward zero to integer milliseconds `n`. Skip when `n < 1`.
2. If both axes' unrounded distance to target is below 0.5 points, complete,
   snap to target, invoke completion with success, and remove the entry.
3. Let `a = 0.9934^n`, current position `L`, target `T`, and previous heartbeat
   displacement `V`. Desired position is `a*L + (1-a)*T`.
4. Desired acceleration is `(desiredPosition-L)-V`. Clamp to `[-10,10]` on
   an axis only when its sign points toward the remaining target. Opposite-sign
   acceleration/braking is not limited by this branch.
5. New displacement is `V + limitedAcceleration`; add that to `L`.
   Round the rendered offset to display scale, retaining the unrounded position
   and new displacement separately for the next heartbeat.

This is a behavioral description of compiled instructions, not copied Apple
source. The real routine also handles unavailable containers, nonfinite values,
external offset changes and long-distance hyperjumps.

| Behavior | UIKitCore address / supporting local evidence |
|---|---|
| Read actual time and save heartbeat time | `0x193b3abb4`, `heartbeat-common.s` |
| Integer-millisecond conversion; one entry update per heartbeat | `0x193b3abf8`, `heartbeat-body.s`; multiplier at `0x194e66148` is 1000 |
| Recurrence, 0.5-point threshold, unrounded state | `0x193b3b200`, `process-entry.s` |
| Directional acceleration limit | `0x193b3b5b8`, `acceleration-limit.s` |
| Default convergence / preference override | `0x193b3b8e8`, `scroll-convergence.s`; default at `0x194e68930` |
| Manager installs default convergence | `0x193b3b828`, `manager-init.s` |
| Native scroll request path and delegate callbacks | `0x193b3c09c`, `scroll-request.s` |
| Retarget existing entry without clearing its velocity | `0x193b39cf4`, `animator-target.s`, lookup `0x193b3a1fc` |
| Explicit cancellation invokes completion with failure and removes entry | `0x193b39e70.s` |

Hopper corroboration IDs:

- Entry processing: `ev_355ea59fc72068225d25ea4ab499baa19351873665464b579fa593adb869a13d`.
- Heartbeat: `ev_164cdf0a2c98c36e0ce29ac9b4667635b5dd52822630ce4e3a6a52893350d7fa`.
- Acceleration: `ev_38458911972a75e1df863f978d38f00376634258caaf6eb5b1f8feba38485d17`.
- Convergence: `ev_c8e8a42561f96b41301e95659f610dcf310e6631489b2c87ffc216713ba856d9`.

Hopper's pseudocode loses some floating-point/register expressions and leaves
external stubs unresolved. The original-cache ARM64 bodies, selector disassembly
and dumped constants are necessary to establish the complete arithmetic.

An idiom-specific distance/rate branch in the manager checks idiom 3, which is
CarPlay. TV is idiom 2. Do not apply that branch's `.979` / `-4000` constants
to tvOS. The separate long-jump path is also not evidence for ordinary one-screen
detail travel. Reduce Motion behavior and other active runtime branches remain
unverified.

### Why the earlier 0.158-second fit was close

Using real-valued milliseconds, the convergence tail has time constant
`-1/(1000*ln(0.9934)) = 0.151015 s`. At an assumed steady 60 Hz, each 16.667 ms
heartbeat truncates to 16 ms. The per-heartbeat factor is approximately 0.899466,
giving a wall-time tail constant of **0.157307 s**. That explains the recordings'
approximately 0.158 s tail without inventing a literal Apple 0.158 s constant.

The current continuous 0.158 / 36000 approximation therefore has a sound fit,
but differs in cadence handling, directional limiting and velocity retention.
Replacing 0.158 with 0.151 alone would not reproduce the recovered driver.

## Recovered compiled choreography

VideosUI's StackTemplate subscribes to showcase progress (`p=1` at hero,
`p=0` at details): `0x23a03f96c` -> sink `0x23a0467f0` -> `0x23a03fb44`
-> virtual slot `+0xa90`. StackTemplate and CanonicalTemplate both resolve that
slot to `0x23a03d1f4`, which stores changed progress and dispatches through
`0x23a03e0bc` -> `0x23a04507c` to `NonScrollPeekingUpdating` controllers.

Besides `p`, the dispatcher forwards geometry `d`, template peeking value `k`,
and a header-display boolean. `d` is selected-row top height plus adjusted top
inset minus root bounds height. Missing/unconvertible template values default
to **40 points** and **false**. These are defaults, not recovered configuration
for the pages shown in the recordings.

For finite inputs, the bounds correction runs when
`d >= 0 || (d < 0 && k > abs(d))` and sets the relevant bounds origin Y to
`p*(d+k)`. This condition includes nonnegative `d`; an earlier intermediate
reading incorrectly omitted that case.

| Route | Recovered behavior |
|---|---|
| Episodes | Witness `0x2399efd00` -> `0x2399efa08` -> `0x239ba519c` shifts EpisodeContainerView's own bounds. Its header and collection are children. |
| Carousel | Witness `0x23992f1c8` -> `0x23a046ccc` shifts the inner carousel child (`+0x1d8`), while the header (`+0x1f8`) is distinct. |
| Header | `0x239b26440`: when configured and conforming to SupplementaryViewAnimating, use peeking translation `VUIRoundValue(-(d+k)*p)`; otherwise alpha is `max(1-2*p,0)`. |
| Header composition | `0x2399753a4` concatenates content-peeking and position-adjustment transforms onto `floatingViewContainer.layer`; getter/creation `0x239975da8`. |

For positive `d+k`, removing the bounds correction as `p` falls cancels part of
the outer upward travel. This explains how artwork can travel less than the
outer content while using the same progress. Header hierarchy and selected
branch determine whether its movement differs again. It is not evidence for a
universal fixed delay, or constant artwork travel ratios of 0.68 or 0.71.

VideosUI header adjustments also use UIKit's
`addCoordinatedUnfocusingAnimations:completion:` path (`0x23a182e30`, stub
`0x240012ca0`). The traced closure dispatches through `0x23a18307c` to header
restoration/update helpers `0x23a183120` / `0x23a1831b0`. This supports focus
coordination but does not establish a universal duration or precise callback
time for the recorded transition.

A separate SeasonPickerButton label switch has an exact **0.2 s** UIView layout
animation: `0x239cef654`, duration load at `0x239cef8a4`, constant `0x23a4159f0`,
call at `0x239cef8b0`, layout closure `0x239cf0120`. It belongs to a single-label
chevron picker. The captured horizontal season bar's runtime identity is not
established; do not reuse this duration for its arrival or the hero slide.

## Observed recordings and bounded replay

Analyzed original Apple movie/show recordings in Downloads with decoded-frame
presentation timestamps, without temporal resampling. Movie: 352 decoded frames;
show: 410. Tracking at 480x270 gives a 4-source-pixel coordinate grid, with
additional compression/focus uncertainty. Video metadata does not establish
rendered frame rate, input time, or the capture device's firmware build.

Observed relationships:

- Outgoing hero controls and incoming centered title share a displacement:
  `(912-heroPlusY)+(smallTitleY-44)=1040` on the measurement grid across nine
  overlapping downward frames per clip, and two upward frames per clip.
- Show nonfocused episode artwork has shorter downward travel (fitted ratio
  0.6802, 29 samples). Episode text and artwork move together; season text
  matches that rail in seven reliable overlapping samples.
- Movie Related header/artwork follow the centered title. Primary trailer
  artwork has shorter travel (ratio 0.7093, 28 samples), while its header follows
  the title in five reliable late-tail samples. Two separated internal artwork
  patches remain equally spaced, so changing focus scale alone does not explain
  that late-tail difference.
- Primary cards visibly gain focus during page movement: approximately movie
  1.40-1.45 s and show 1.15-1.20 s in their respective clips. These are visual
  observations, not callback timestamps. Completion-only focus is not supported.
- Return acceleration does not preserve a constant primary/title travel ratio.
  Movie primary artwork loses reliable correlation during its return focus
  change. The clips contain no mid-flight reversals.

Replaying the recovered defaults at assumed 60 Hz with integer 16 ms steps,
fitting only unknown onset/phase and travel distance, gives:

| Model | Show RMS error | Movie RMS error |
|---|---:|---:|
| Native recurrence, held heartbeat samples | 0.924 px | 1.476 px |
| Native recurrence, interpolated samples | 0.902 px | 1.460 px |
| Earlier continuous 0.158 / 36000 approximation | 1.102 px | 1.565 px |

Each fit uses 52 reliable hero/title observations per clip. Errors below the
4-pixel measurement grid establish compatibility, not unique identification of
the live driver or its settings. The fit's onset is not the remote input time.
Detailed measurements, coverage gaps, hashes, CSVs, replay scripts and charts
are in `deep-re/recordings/findings.md` and neighboring local artifacts.

## Implications for the experiment

The earlier changes build and pass tests, but two policies need revision before
claiming Apple parity: focus handed off only at completion, and uniform extra
movie translation applied to both cells and headers. Tests asserting those
policies verify the provisional implementation, not Apple's behavior.

Keep one transition owner/progress and public UIKit APIs. Prefer preserving
native focus-scroll ownership where the existing architecture allows it. If
the hero slide still requires a custom driver, account for measured heartbeat
time, directional acceleration and retarget continuity rather than tuning a
fixed duration. Derive primary peeking from actual geometry and keep header
and artwork hierarchy distinct. Resolve the divider's competing positioning
owner so early focus can overlap motion without the observed jump.

Still missing: active page template values, concrete header/controller instances,
runtime preferences, any extra position-adjustment transform, exact input/focus
callback ordering, Reduce Motion, rapid reversal and physical remote behavior.
The binary recovers conditional behavior; it does not supply those runtime facts.

This deeper pass changes research documentation only. App source and the pending
main merge remain as in the initial handoff. Its previously passing builds/tests
remain the last code validation; no new device-parity claim is made.

The subsequent implementation pass is recorded at the top of [the handoff](README.md).
It applies the recovered recurrence, outer/primary travel distinction, overlapping
focus and request-lifecycle guards. The research-only status in the preceding
paragraph describes the state when these findings were first saved.
