# Scrolling research handoff — 2026-11-13

This compact snapshot preserves the findings and experiments. The research branch
is not ready-to-merge application code. Its main README records the chronological
evidence and corrections; historical claims in the independent review must be
read with its later addenda and the qualifications below.

## Conclusions and implementation split

- Native Home scrolling enabled UIKit idle cell preparation on the physical
  Apple TV. All 199 sampled row-configure stacks in that run were under the idle
  path, versus none in the previous warmed custom-driver capture. Daniel reported
  smooth Home navigation and found no navigation problems in his manual check.
- The 12.4 versus 29.2 ms post-move medians are exploratory comparisons, not a
  matched A/B. Process/cache state, navigation cadence and move mix differ.
- Native ordinary-row scrolling was then enabled on details, season/person pages
  and other shared browse modes. Simulator checks and Debug builds passed;
  physical checks on those routes remain provisional.
- The native programmatic hero slide felt wrong on the device and was reverted
  exactly. Preserve the custom 0.6-second hero-to-details slide and reverse,
  synchronized effects, focus gating and cancellation behavior.
- The artwork-retention change reduced work in a warmed custom-driver run, but
  the size of its benefit is confounded by warming. Preserve it here; omit it
  from the first native-scrolling implementation change and evaluate separately.
- Custom scrolling is not universally invalid. The measured issue is this
  per-tick-offset implementation's interaction with cell preparation. An isolated
  expanded-layout-attributes probe did not restore preparation ahead of movement.

## Apple reference and saved custom implementation

`apple-reference.html` preserves the compiled-behavior findings, addresses,
build identities, model values and route limitations without Apple binaries or
disassembled instruction bodies. Ordinary rows use the shared UIKit focus-scroll
path in the examined routes; a conditional hero/top return has separate spring
evidence. Do not generalize either to every Apple TV app transition.

The independently implemented ordinary follower uses convergence 0.9934 per whole
millisecond, precise retained position, one integration step per callback, a
10-point change limit on displacement while accelerating toward the target,
snap below half a point, and the recorded far-jump policy after one viewport of
travel with more than two viewports remaining. The app-specific reference spring
values and their limited route attribution are in the Apple report.

`custom-FocusScrollMotion.swift.reference`,
`custom-FocusScrollControlledCollectionView.swift.reference` and
`custom-PlexHomeViewController.swift.reference` preserve the pre-native custom
implementation. These are reference files, not compilation inputs. The research
branch's active app also retains the custom hero slide and motion tests.

## Reports, measurements and reproduction

- `independent-review.md`: independent raw-trace review and later corrections.
- `native-comparison-summary.json`, `native-per-move.csv`: native Home sample
  counts, inferred focus moves and comparison limitations.
- `artwork-comparison.json`, `artwork-per-move.csv`: artwork experiment results.
- `memory-summary.json`: footprint/allocation evidence and its limitations.
- `custom-preparation-probe.json`: negative result of the layout-only probe.
- `analyze-native.py`, `analyze-per-move.py`, `analyze-update-stalls.py` and
  `compare-artwork.py`: analysis scripts archived verbatim. They expect the
  original relative evidence-directory layout and raw exports; copying them here
  does not make them runnable without those inputs.
- The parent `evidence/` directory retains the numerical precision probe, motion
  measurements and original small reproduction scripts.

Use frame/client-update timing and preparation call paths, not total hitch
counts, to compare scrolling. Samples are not invocation counts or exact method
durations. Video tracking and traces were separate captures. Input-to-motion
latency and detail-transition performance were not conclusively measured.

## Local evidence, not part of Git

Original root:
`~/.codex/visualizations/2026/11/12/01a1ceb7-4954-7d11-bea5-f13bc33da0f6/`.
Existing files remain in place; no full duplicate archive is retained.

For a minimal raw before/after set, retain:

- `row-scroll-comparison/artwork-patched-warm-rebind.trace` (about 156 MiB).
- `native-home-experiment/native-home-fresh.trace` (about 421 MiB).

Optional deeper evidence includes the first-appearance/revisit trace, Apple
ordinary-row trace, fresh allocations trace and the other baseline/artwork runs.
Raw exports can be regenerated from retained traces with the matching Instruments
version. Reports and tables preserve conclusions but cannot replace raw traces
when testing a new stack-level hypothesis. No existing evidence was deleted as
part of this branch split.

Build/test logs and source backups remain in `native-all-pages/`,
`native-hero-slide/` and `native-home-experiment/`. Firmware remains outside this
snapshot. Local evidence is not an off-machine backup.

## Clean implementation review

Start from the latest fork main. Keep the patch limited to native ordinary focus
scrolling and the necessary destination/focus integration. Check already-visible
destinations, nested rows, interruption/cancellation, snapshot shifts, preview
restoration, held arrows/system fast scrolling, sidebar escape, and first/last
row boundaries. Retain custom coordinated transitions. Explain the measured
preparation reason in a short code comment, without claiming all custom scrolling
hitches. Build, run relevant tests, and verify remote navigation on the device.
