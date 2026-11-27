# Season-bar geometry and focus follow-up

14 November 2026. Target: tvOS 27.2 / 24K154 / AppleTV18,1. This pass
extends [the fade investigation](SEASON_SELECTOR_RE.md) with original-cache
ARM64, UIKit metadata, Hopper analysis and original-resolution recording checks.
The initial research pass changed no app implementation. The subsequent focus
implementation and device build are recorded below; full parity is not established.

## Recovered movement relationship

UIKit's native bar is a direct child of the episode collection. Setup
`0x1938437dc` calls `addSubview:` at `0x193843848`. Layout `0x193843918`
sets its frame to `(contentOffset.x + barOffset.x, barOffset.y, width, 66)`.
Only horizontal scrolling is canceled by that frame calculation. The bar
inherits its collection's vertical bounds offset and its episode container's
peeking correction; it is not independently pinned vertically.

EpisodeContainer update `0x239ba519c` conditionally sets bounds.origin.y to
`p*(d+k)`, where p is showcase progress, d comes from selected-row geometry,
and k is template peeking metadata. The finite-value predicate is d>=0 or
(d<0 and k>abs(d)). Otherwise that update retains the previous bounds value.
EpisodeContainer layout `0x239ba536c` places the inner collection at (0,0).
For identity ancestor transforms, the resulting bar top is:

```
Y = episodeContainerOuterOriginScreenY - p*(d+k)
    - innerCollection.contentOffset.y + barOffset.y
```

If outer origin is R-o and p=1-o/O with the other values fixed, total travel
is O-(d+k). This is a conditional derivation, not a recovered page-specific
number. Rivulet's separate season-header sibling currently uses the full
`detailsRestOff-off` displacement without this explicit shared-parent correction.
That is a possible structural mismatch when Apple's correction is nonzero.

Neither 725 nor 1035 is established as Apple's native travel. Active template
values, initial inner content offset, bar offset and ancestor geometry remain
unobserved. A fallback k=40 is not proof of the recording's active payload.
Bounded offset references found no VideosUI setter; the broader selector xref
failed parsing and supplies no negative proof. Do not substitute an assumed zero
offset or guessed absolute starting Y.

## Recovered conditional modern focus appearance

Bar cell factory `0x193b25d88` identifies `_UIHorizontalIndexTitleBarCell`.
The modern path is conditional on Solarium enablement; runtime flag values were
not acquired. Its compiled behavior includes:

| Property | Modern native behavior | Rivulet before this follow-up |
|---|---|---|
| Background | Separate UIVisualEffectView, radius 33 | Filled control background |
| Horizontal padding | 30 each side | 32 each side |
| Font | Preferred Body, semibold in every state | Fixed 31pt, medium/semibold |
| Focus background size | W+8 by H+8 | Entire control scaled 1.05 |
| Focus title scale | Uniform (W+8)/W | Same fixed control scale |
| Focus title color | Black | Black |
| Selected/unfocused title | labelColor only when no other index cell is focused | White selected title |
| Other title | secondaryLabelColor | White at .72 |

Cell initialization is `0x193b278a4`; transforms `0x193b28424`; modern colors
`0x193b2866c`; font selection `0x193b277c4`. The transparent sizing label is
intentional and is not a second visible title. Focus background scaling is
independent on X and Y, while the visible title uses the width-derived scale.
A 66-point background therefore becomes 74 points tall, rather than 69.3.

Native selected/focused backgrounds use internal blur styles, not fixed white
fills at .35/.88. Those internal enum values are not a supported reconstruction
API. Material pixels and inherited shadows were not recovered. Use public UIKit
for any implementation and label a material substitution as an approximation.

Focus callback `0x193b28054` schedules colors and transforms together through
`addCoordinatedAnimations`; its block is `0x193b28124`. It supplies no local
duration or spring. Coordinator configuration and focus context can alter timing;
global configuration constants do not establish this route's actual duration.
Rivulet already uses the public focus animation coordinator, which should remain
the owner of focus timing rather than adding a guessed independent timer.

## Recording corroboration and starting-position limit

Original show recording identity is retained in the earlier report. Native
1920x1080 frame 165 (PTS 2.993483) gives an unfocused capsule approximately
x80..260, y208..274: width 180, height 66, center Y241. Focused frames show
approximately width 188 and height 74, centered in the same place. Pixel edge
quantization can produce a measured height of 75. This agrees with additive
8-point growth; it does not independently prove the runtime feature flags.

During return, the capsule center moves with independently tracked episode
artwork to about 2 pixels while trackable. Its focused appearance begins
unfocusing before measurable page translation: the title has returned to white
while the capsule remains enlarged and bright. Focus styling and parent fade
are therefore overlapping effects, rather than one opacity animation.

The bar is invisible over part of its travel. The recording cannot reveal an
exact offscreen/invisible starting position. Crop origins must not be mistaken
for capsule frame coordinates. Settled Y208 is an observed recording position,
not a recovered universal template constant or justification for blindly moving
Rivulet's layout by a fixed amount.

## Evidence and remaining work

Local evidence root:

`~/.codex/visualizations/2026/11/14/01a1db10-f35a-7aa0-95c5-6e6738b505e9/detail-motion/season-exact-re/`

Contains focus and geometry ledgers, raw instruction/constant evidence, recording
measurements and exported UIKitCore evidence/snapshot. Hopper focus-bar analysis
is `ev_70e433f725d7c95203701d3ec5a1d58c737be21e37e09771056a9559b63ac5df`.
The native analysis session was closed cleanly. Raw Apple artifacts remain local.

## Implemented focus follow-up

SeasonPillView now separates background and title transforms. Focus grows the
background by 8 points in each dimension while uniformly scaling the title by
the width-derived factor, without changing the control's layout frame. Layout
updates recompute the transforms so focused resizing and unfocus reset correctly.
After the layout sync, Rivulet uses 32 points of padding on each side and a
fixed 29-point system font. The title is semibold when focused or selected and
medium otherwise. Title colors are black when focused, white on the selected
capsule, and white at 52% opacity otherwise. The selected capsule is hidden
while another season has focus. The public UIKit focus animation coordinator
still drives these effects.

The white background fills are retained as an explicit material approximation.
Resting Y and transition travel are unchanged: exact page-specific movement still
needs active layout inputs or matching runtime measurements. No private blur
styles or guessed replacement travel distances were introduced.

In the 14 November follow-up, all 3,616 tests passed (3,699 executions, zero
failures or skips), including focus handoff and focused resize/reset cases.
SwiftLint found zero violations. Results:
`/private/tmp/rivulet-season-focus-verified-20261114.xcresult`. Xcode built,
installed and launched the updated app on Stue (PID546); log:
`/var/folders/bf/h64vt90x6ng70m3_wqd7dtb80000gn/T/ActionArtifacts/default/RunProject/RunProject-Log-20261114-223927.txt`.
Full visual parity remains unverified.
