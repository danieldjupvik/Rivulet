from pathlib import Path
import csv
import html
import json
import statistics
import xml.etree.ElementTree as E

root = Path(__file__).parent

def rows(path):
    tree = E.parse(path)
    ids = {element.get('id'): element for element in tree.iter() if element.get('id')}
    return [[ids.get(element.get('ref'), element) for element in row] for row in tree.iter('row')]

records = []
summaries = {}
for prefix in ['artwork-baseline', 'artwork-patched', 'artwork-patched-warm']:
    analysis = json.loads((root / f'{prefix}-analysis.json').read_text())
    updates = rows(root / f'{prefix}-hitches-updates.xml')
    lifetimes = rows(root / f'{prefix}-hitches-frame-lifetimes.xml')
    lifetime_by_swap = {(row[3].text, row[4].text): int(row[1].text) / 1e6 for row in lifetimes}
    for move in analysis['moves']:
        update = move['slow_update_samples']
        construction = update['PosterCell.init'] > 0 or update['PosterCell.setUp'] > 0
        reuse = update['PosterCell.prepareForReuse'] > 0
        kind = 'mixed' if construction and reuse else 'construction' if construction else 'recycled' if reuse else 'unclassified'
        matching = [row for row in updates if abs(int(row[0].text) / 1e9 - update['start']) < 1e-8]
        life = [lifetime_by_swap[(row[4].text, row[5].text)] for row in matching if (row[4].text, row[5].text) in lifetime_by_swap]
        records.append(dict(run=prefix, move=move['move'], onset_s=move['onset'], onset_ms=move['onset_ms'],
                            update_ms=update['milliseconds'], phase_ms=(update['start']-move['onset'])*1000,
                            frame_lifetime_ms=max(life) if life else None, sampled_kind=kind,
                            reuse_samples=update['PosterCell.prepareForReuse'], init_samples=update['PosterCell.init'],
                            clear_samples=update['PosterCell.clearArtwork'], max_preparation_ms=move['max_preparation_ms']))
    selected = [record for record in records if record['run'] == prefix and record['sampled_kind'] == 'recycled']
    summaries[prefix] = dict(total_moves=len(analysis['moves']), recycled_moves=len(selected),
                             median_recycled_update_ms=statistics.median(record['update_ms'] for record in selected) if selected else None,
                             median_recycled_lifetime_ms=statistics.median(record['frame_lifetime_ms'] for record in selected) if selected else None)
    reset_samples = image_reset_samples = 0
    profile = E.parse(root / f'{prefix}-time-profile.xml')
    profile_ids = {element.get('id'): element for element in profile.iter() if element.get('id')}
    for raw_row in profile.iter('row'):
        row = [profile_ids.get(element.get('ref'), element) for element in raw_row]
        time = int(row[0].text) / 1e9
        if 'Main Thread' not in row[1].get('fmt', ''):
            continue
        if not any(move['slow_update_samples']['start'] <= time < move['slow_update_samples']['end'] for move in analysis['moves']):
            continue
        names = [profile_ids.get(frame.get('ref'), frame).get('name', '') for frame in row[6]]
        if any('PosterCell.prepareForReuse' in name for name in names):
            reset_samples += 1
            if any('setImage:' in name or '_configureForLayeredImage' in name for name in names):
                image_reset_samples += 1
    summaries[prefix]['sampled_reuse_cpu_count'] = reset_samples
    summaries[prefix]['sampled_image_under_reuse_count'] = image_reset_samples

method = ('Onsets inferred from focus-dominated CPU samples, not timestamped remote input. '
          'Largest client update in 50–500 ms after onset, clipped at the next onset. '
          'Duplicate color representations deduplicated by start and duration. Frame lifetime joined by swap and surface IDs. '
          'Construction/reuse classifications describe sampled stacks; absence of a sample does not prove absence of a call. '
          'Runs requested on the same route, with no logged row identities. Sequential runs are not a randomized benchmark.')
(root / 'artwork-comparison.json').write_text(json.dumps(dict(method=method, summaries=summaries, moves=records), indent=2))
with (root / 'artwork-comparison.csv').open('w') as file:
    writer = csv.DictWriter(file, fieldnames=list(records[0]))
    writer.writeheader()
    writer.writerows(records)
headers = list(records[0])
table = '<tr>' + ''.join(f'<th>{html.escape(key)}</th>' for key in headers) + '</tr>'
for record in records:
    table += '<tr>' + ''.join(f'<td>{value:.2f}</td>' if isinstance(value, float) else f'<td>{html.escape(str(value))}</td>' for value in record.values()) + '</tr>'
document = '<!doctype html><meta charset="utf-8"><title>Artwork reset Release comparison</title><style>body{font:16px system-ui;margin:32px}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #bbb;text-align:left}pre{white-space:pre-wrap}</style><h1>Artwork reset Release comparison</h1>'
document += '''<p>The patch avoids blank artwork during reuse when a cached replacement can be assigned directly. Missing/uncached images, placeholders and aspect changes retain their required clears. Motion constants, row positioning and focus behavior are unchanged.</p>
<p>The warmed patch traversal reduces the median recycled binding update from 35.41 to 29.16 ms (6.25 ms / 17.6%), with median associated frame lifetime 83.41 to 66.73 ms. All ten warmed updates are shorter than their requested corresponding baseline moves. This supports a modest warm-rebind benefit; updates still take 27.69–35.86 ms and the pause is not eliminated.</p>
<p>The first patch traversal showed no clear recycled-update benefit (35.53 ms median) and also contained construction and mixed construction/reuse, excluded from that median. Blank-image work remained inside loadImage when replacement artwork was unavailable synchronously. The warmed run has no sampled clearArtwork or tile construction in its binding windows. Across these ten windows, TVPosterView.setImage appears under prepareForReuse in 75 baseline CPU samples versus zero warmed patch samples. Sample counts are statistical, not exact method durations.</p>
<p>Both baseline and warmed captures report nominal thermal state. Focus-onset medians are 26.42 and 26.03 ms. New-row construction and detail/hero hitches are outside this experiment. Different process ages and cache warming remain confounders; an alternating-order comparison would strengthen confidence.</p>
<p>Captures: artwork-baseline-rebind.trace (PID 818), artwork-patched-rebind.trace (PID 1107), artwork-patched-warm-rebind.trace (PID 1107). Baseline app retained as artwork-baseline.app. Exports, per-move JSON/CSV and scripts reside beside this report.</p>'''
document += '<p>' + html.escape(method) + '</p><h2>Recycled update summaries</h2><pre>' + html.escape(json.dumps(summaries, indent=2)) + '</pre><h2>Per move</h2><table>' + table + '</table>'
(root / 'artwork-comparison.html').write_text(document)
print(json.dumps(summaries, indent=2))
