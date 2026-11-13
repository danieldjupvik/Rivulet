# Reproduction files

This small selection is tracked. Other files in this directory remain ignored.
No screenshots, video, Instruments XML exports, compiled binaries, or build logs
are part of the tracked evidence set.

## Contents

- `PrecisionProbe.swift`: reproduce the rounded-position stall using the app's
  actual `FocusScrollMotion` helper; verify that precise feedback settles.
- `device-scroll-trace.txt`: numeric debug output before the precision fix,
  with timestamp and substep changes already applied. Only the first buffered
  segment was printed; it does not capture the final stalled endpoint.
- `device-scroll-precision-trace.txt`: numeric output after the precision fix,
  including 16 completed scroll animations. Buffer segments can share a start
  timestamp; do not treat each segment as a separate animation.
- `summarize_trace.py` and `trace-summary.json`: regenerate/read the final
  Instruments counts without depending on the original investigation scripts.
- `motion.py`: reproduce the approximate video motion measurements.
- `apple-latest-motion.csv`, `rivulet-latest-motion.csv`, and
  `public-latest-motion.csv`: measurements from `apples-tv-animation-latest.mov`,
  `rivulet-animation-latest.mov`, and `rivulet-public-version-animation-latest.mov`.
  The local Rivulet recording includes timestamp/substep changes but predates
  the precise-position fix. Do not present these as final before/after evidence.

## Rounding reproduction

From the repository root, with Xcode command-line tools available:

```sh
evidence_dir=Docs/Investigations/2026-11-03-scroll-animation/evidence
xcrun swiftc Rivulet/Views/Media/FocusScrollMotion.swift \
  "$evidence_dir/PrecisionProbe.swift" -o /tmp/rivulet-precision-probe
/tmp/rivulet-precision-probe
```

The rounded-feedback cases remain two points short after 600 iterations. The
precise-feedback cases settle in 69–77 iterations at approximately 59.94 Hz
with the November 12 model update (the historical model took 65–73).
This is a numerical reproduction, not a UIKit integration test.

## Instruments summary

Requires the original `rivulet-scroll-signposts.trace`, which is NOT in Git.
Substitute its path below. Export using the matching Xcode/Instruments version:

```sh
trace_path=/path/to/rivulet-scroll-signposts.trace
export_dir=/tmp/rivulet-trace-exports
mkdir -p "$export_dir"
for schema in hitches time-profile os-signpost; do
  xcrun xctrace export --input "$trace_path" \
    --xpath "/trace-toc/run[@number='1']/data/table[@schema='$schema']" \
    --output "$export_dir/latest-$schema.xml"
done
python3 Docs/Investigations/2026-11-03-scroll-animation/evidence/summarize_trace.py "$export_dir"
```

The Python script uses only the standard library, resolves XML references and
deduplicates signpost events. Its two time windows apply only to this recording.
The saved `trace-summary.json` preserves results if the raw trace is unavailable;
it cannot substitute for the call stacks when investigating a new hypothesis.

## Video motion estimates

Requires Python with Pillow, `ffmpeg`, `ffprobe`, and the original video:

```sh
python3 Docs/Investigations/2026-11-03-scroll-animation/evidence/motion.py \
  /path/to/rivulet-animation-latest.mov /tmp/rivulet-motion
```

Outputs a CSV and plot named after the input video. The CSV columns are timestamp
in seconds, interval since the previous captured frame, estimated vertical shift
in pixels normalized to 1080p, and mean grayscale matching error.

The estimator reduces frames to 192×108 and searches integer vertical shifts
within a fixed central/right crop. Resolution is therefore about 10 pixels at
1080p. It avoids the leftmost focused poster but can still be affected by scene
changes, scale, overlays, or focus effects. Captured-frame intervals are NOT
display-link intervals or app FPS. Uneven capture timing limits conclusions.

Validation: the portable summary reproduced the documented Instruments counts;
the motion script reproduced the saved Rivulet CSV exactly; the Swift probe
compiled and all its assertions passed. App code was unchanged by this evidence
commit.
