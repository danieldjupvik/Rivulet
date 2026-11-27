# Directed season-selector and lower-section RE

14 November 2026. Target: tvOS 27.2 / 24K154 / AppleTV18,1, using the same
VideosUI extraction and original shared cache identified in [RE_FINDINGS.md](RE_FINDINGS.md).
This pass investigates the reported season-selector ghosting on return to hero,
the selector's actual compiled route, and the scope of lower-section correction.

## Findings that change the implementation

The multi-season episode path uses UIKit's **horizontal index-title bar**.
This is a stronger match than the previously investigated generic SegmentedControl
or single-label SeasonPickerButton. Its no-custom-header peeking path directly
sets alpha to **max(1-2p,0)**, where p is showcase progress (0 details, 1 hero).
In Rivulet's opposite progress convention q, this is **max(2q-1,0)**.

Rivulet instead used alpha=q in both ExpandedDetailContainerView update paths.
At halfway through return, its bar remained 50% visible around Y582 on a 1080p
layout, and at q=.25 remained 25% visible around Y762. The bar is frontmost, so
that translucent moving content remained exposed over the returning hero.

Both alpha assignments now use the recovered midpoint fade, retaining the
shorter episode-rail translation. This removes the unsupported long visibility
tail without adding a delay, a second clock, or private UIKit API calls.
The new view-level regression covers collection-driven and container-driven
updates, entry and exit, and invisibility while return travel is still underway.

This addresses a supported cause of a faint moving trail. No fresh recording of
the installed Rivulet version was supplied, so it does not prove whether the
reported ghosting also includes persistent rendered images or focus compositing.

## Compiled route and selectors

All addresses below belong to the target build. Hopper dossiers were checked
against original-cache ARM64 and resolved Objective-C selector stubs because
floating-point expressions in Hopper pseudocode are incomplete.

| Step | Evidence |
|---|---|
| Episode header configuration | Body `0x2399ea210`, called at `0x2399e9c08`; reads header VM at +0x138 and season VM array at +0x150. |
| Multi-season branch | At `0x2399ea280`, array count >=2 takes the native-bar branch; smaller counts take the generic header-factory branch. |
| Enable native bar | `0x2399ea298` calls stub `0x240011440`, resolved to `_setDisplaysHorizontalIndexTitleBar:`, with YES. |
| Preserve separate header layout | The multi-season branch writes header layout through global `0x25a255ce8`; it does not create a generic header view on that branch. |
| Initial custom header state | Constructor helper `0x239ba56d0` zeroes collection/header/header-layout fields; metadata identifies the custom header at +0x1f0. Reused runtime instance state was not observed. |
| Alternative generic header | The <2 branch calls factory `0x239a86750` at `0x2399ea4d8`, then stores the returned view through `0x239ba50e4`. |
| Native-bar progress update | `0x239ba519c` calculates max(1-2p,0) at `0x239ba51c8`-`0x239ba51dc`. If custom header is absent, it checks the collection's `_displaysHorizontalIndexTitleBar` (stub `0x24000ea40`). |
| Apply native-bar alpha | It gets `_horizontalIndexTitleBar` through stub `0x24000f500`, then calls `setAlpha:` through `0x2400205a0` at `0x239ba5248`. This bypasses the generic header conformance decision. |
| Bar and rail movement | The same update conditionally changes EpisodeContainerView bounds.origin.y to p*(d+k); the native bar belongs to its collection. Geometry/template values still determine the distance. |
| Bar layout | UIKitCore `-[UICollectionView layoutHorizontalIndexTitleBar]`, `0x193843918`, uses collection contentOffset.x plus stored bar X offset, stored bar Y offset, bounds width, and height constant 66.0 at `0x194e661c0`. |
| Season titles | Data-source `indexTitlesForCollectionView:` IMP `0x23a3281bc` forwards through `0x23a328174` to controller helper `0x2399ee654`. |

The native bar's 66-point height agrees with the existing Rivulet pill height.
The exact active page payload, bar Y offset and runtime class instances in the
recording remain unobserved. This is recovered compiled behavior with recording
corroboration, not a live class dump from Apple's running process.

Hopper evidence IDs:

- Header configuration: `ev_d1fb0ada6b6eaec1af2fdc0e282b65bd99cd47a41713f561b19b46c3b5aa23a8`.
- Episode peeking: `ev_ba3c20d958c959b2a01fae9a83a26e07228a5688846232a87c903b88b9738634`.
- Index titles: `ev_4a891ea0cc50b0db5154bcb086ac417a1ce91cf97c72443118739d4d7877c807`.
- Generic header helper, rechecked: `ev_86bd42d5cba716435b63f1736c650085ab88b596ff05408a19d9ab99cea728c2`.

The separate 0.2-second SeasonPickerButton animation remains unrelated evidence;
it was not repurposed as this native bar's entrance or exit duration.

## Recording cross-check

Used original show recording SHA-256
`97e61391596e963ece34821ad34b38a1bf4728726f3130090f84a922bf90653c`,
all 410 decoded frames at original presentation timestamps. Contrast measurements
use unselected Season 3/6 glyphs, quadratic background subtraction and reference
patch correlation. These are opacity proxies, not exact UIKit alpha values.

For the comparison only, outer progress is inferred from centered-title travel,
or the independently tracked hero control when the title becomes faint. Primary
episode displacement cannot be normalized by a constant ratio during return;
an exploratory calculation using that normalization was rejected.

| Return PTS | Outer p proxy | Season 3 contrast proxy | Linear 1-p | Compiled max(1-2p,0) |
|---|---:|---:|---:|---:|
| 5.348300 | .0962 | .815 | .904 | .808 |
| 5.398467 | .2692 | .528 | .731 | .462 |
| 5.431833 | .4077 | .261 | .592 | .185 |
| 5.481883 | .5692 | No reliable glyph | .431 | 0 |
| 5.548667 | .7192 | No reliable glyph | .281 | 0 |

Full-height glyph search checks that disappearance is not just a mistaken crop
position. The bar fades while still onscreen; mid/late exit is much closer to the
compiled midpoint rule than the old linear fade. Background texture, subpixel
sampling and overlapping chrome prevent an empirical exact-curve claim.

The selected Season 1 capsule changes focus appearance around return start.
Its settled reference is not the same palette, so its contrast was rejected as
a parent-alpha measurement. A concurrent focus-style transition may contribute
to a different ghosting symptom; it has not been established as the cause here.

## Lower sections: what is actually conditional

The special NonScrollPeeking correction targets **one selected section**.
Handler `0x23a03e0bc` filters visible paths by sectionIndexForNonScrollPeeking
(field +0x550), resolves that snapshot section and checks a supported-type set.
Canonical setup `0x23a147528` chooses section1, or section2 when a verified
canonicalTitleBanner child exists. Default selection is -1, which skips updates.

The update allowlist contains flowcase, expansiveBrowsingCollection,
expansiveBrowsingEditor, channelOfferCarousel, carousel, episodeCollection,
orthogonalCollection, libEpisodeCollection, horizontalMultiGroupCollection and
gridCollection. A further subset controls hosted-controller dispatch; a successful
dictionary lookup and NonScrollPeekingUpdating conformance are also required.

Three conformers are present in this image: CarouselViewController,
EpisodeCollectionViewController and MultiGroupHorizontalCollectionController.
The latter's witness `0x255723cf0` leads through `0x23a209b94` -> `0x23a209ad0`
-> `0x23a20bac8` and uses the same conditional header/bounds geometry pattern.
Generic fallback `0x23a045378` affects suitable BaseCollectionViewCell instances
from that selected section; `0x23a045f48` also factors in browserContentScale.

This does not imply that other lower rows should stay stationary. They can
inherit the shared parent's scrolling while the primary section receives a
counteracting peeking correction. No per-type lower-row delay/stagger schedule
was found in these bounded bodies. Rivulet's shared lower-row motion remains
consistent with that arrangement, but every content type is not runtime-verified.

## Durable local evidence

`~/.codex/visualizations/2026/11/14/01a1db10-f35a-7aa0-95c5-6e6738b505e9/detail-motion/directed-re/`

Contains exported VideosUI evidence/snapshot, original-cache disassembly and
constant bytes in `season-static/`, section-scope evidence in `lower-static/`,
source audit in `ghosting-source/`, and recording ledger/contact sheets/CSVs in
`recordings/`. Large disposable decoded-frame arrays are excluded. Raw firmware
and personal library imagery remain local. The Hopper session was closed cleanly.

## Validation and device build

The combined tvOS simulator build passed all 3,614 tests (3,696 executions with
dynamic parameters), including both season-fade paths. SwiftLint reported zero
violations. Logs/results: `/private/tmp/rivulet-detail-season-verified-20261114.log`
and `/private/tmp/rivulet-detail-season-verified-20261114.xcresult`.

The device build succeeded and launched Rivulet Lab on Stue (PID533). This
confirms installation/launch, not a fresh visual comparison or ghosting verdict.
Implementation changes remain uncommitted.
