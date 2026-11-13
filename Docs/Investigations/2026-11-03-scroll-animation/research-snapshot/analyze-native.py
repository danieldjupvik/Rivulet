from pathlib import Path
from collections import Counter
import csv
import json
import statistics
import xml.etree.ElementTree as E

ROOT = Path(__file__).parent
OLD = ROOT.parent / 'row-scroll-comparison'

def rows(path):
    tree = E.parse(path)
    ids = {e.get('id'): e for e in tree.iter() if e.get('id')}
    def resolve(e):
        return ids[e.get('ref')] if e.get('ref') else e
    return [[resolve(e) for e in row] for row in tree.iter('row')], resolve

def analyze(root, prefix):
    raw, resolve = rows(root / f'{prefix}-time-profile.xml')
    samples = [(int(c[0].text) / 1e9, [resolve(e).get('name', '') for e in c[6]])
               for c in raw if 'Main Thread' in c[1].get('fmt', '')]
    counts = Counter()
    for t, names in samples:
        idle = any('_updateCycleIdleUntil' in n for n in names)
        counts['main_samples'] += 1
        counts['idle_samples'] += idle
        for tag in ['ShelfRowCell.configure', 'PosterCell.init', 'PosterCell.prepareForReuse', 'stepOffset']:
            if any(tag in n for n in names):
                counts[f'{tag}:idle' if idle else f'{tag}:other'] += 1
    raw, _ = rows(root / f'{prefix}-hitches-updates.xml')
    updates = {}
    for c in raw:
        t, d = int(c[0].text) / 1e9, int(c[1].text) / 1e9
        ss = [names for s, names in samples if t <= s < t + d]
        focus = sum(any('_UIFocus' in n or 'UIFocusSystem' in n for n in names) for names in ss)
        tags = {tag: sum(any(tag in n for n in names) for names in ss)
                for tag in ['ShelfRowCell.configure', 'PosterCell.init', '_updateCycleIdleUntil']}
        updates[(t, d)] = dict(start=t, milliseconds=d * 1000, focus=focus,
                              sample_count=len(ss), **tags)
    updates = sorted(updates.values(), key=lambda u: u['start'])
    onsets = []
    for u in updates:
        if u['milliseconds'] >= 8 and u['focus'] >= 4 and u['focus'] > u['sample_count'] * .5:
            if onsets and u['start'] - onsets[-1]['start'] < .4:
                if u['milliseconds'] > onsets[-1]['milliseconds']:
                    onsets[-1] = u
            else:
                onsets.append(u)
    moves = []
    for i, onset in enumerate(onsets):
        end = min(onset['start'] + .5, onsets[i+1]['start'] if i+1 < len(onsets) else float('inf'))
        following = [u for u in updates if onset['start'] + .05 <= u['start'] < end]
        worst = max(following, key=lambda u: u['milliseconds'], default=None)
        moves.append(dict(move=i+1, onset=onset['start'], onset_ms=onset['milliseconds'],
                          following_max_ms=worst['milliseconds'] if worst else None,
                          following_max_update=worst))
    return dict(counts=dict(counts), moves=moves, updates=updates,
                median_following_max_ms=statistics.median(m['following_max_ms'] for m in moves if m['following_max_ms'] is not None))

native = analyze(ROOT, 'native-home-fresh')
previous = analyze(OLD, 'artwork-patched-warm')
result = dict(native=native, previous_warmed_custom=previous,
    user_observation='User confirms requested sequence and reports 100% hitch free and smooth.',
    method='Deduplicated client updates. Focus onsets inferred from >=8ms updates with >=4 focus samples and >50% focus samples, grouped within 400ms. Following window 50-500ms, truncated at next inferred onset. Samples are statistical, not exact durations.',
    limitations=['No input signposts or row identities; inferred onsets need not equal remote presses.',
                 'Native capture is a fresh process; previous comparator is warmed. Not a controlled matched A/B.',
                 'Detected native onsets occur late in the capture (92-111s), at faster than requested spacing; the final following window is truncated by capture end.',
                 'Native os-signpost export has no rows; no CellPrepare interval comparison is available.',
                 'Fresh process does not imply cold disk artwork cache.',
                 'User smoothness observation is not a measurement of zero dropped frames.'])
(ROOT / 'comparison.json').write_text(json.dumps(result, indent=2))
with (ROOT / 'per-move.csv').open('w') as f:
    fields = ['move', 'onset', 'onset_ms', 'following_max_ms']
    writer = csv.DictWriter(f, fields, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(native['moves'])
for label, run in [('native', native), ('previous warmed custom', previous)]:
    print(label, run['counts'])
    print('moves', len(run['moves']), 'median following maximum ms', run['median_following_max_ms'])
    for m in run['moves']:
        print(m['move'], round(m['onset'], 3), round(m['onset_ms'], 2), round(m['following_max_ms'] or 0, 2))
