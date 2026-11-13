import xml.etree.ElementTree as E
import json,csv,statistics,sys
from pathlib import Path
root=Path(__file__).parent
prefix=sys.argv[1]
tr=E.parse(root/f'{prefix}-time-profile.xml');ids={e.get('id'):e for e in tr.iter() if e.get('id')}
def get(e):return ids[e.get('ref')] if e.get('ref') else e
samples=[]
for row in tr.iter('row'):
 c=[get(e) for e in row]
 if 'Main Thread' not in c[1].get('fmt',''):continue
 samples.append((int(c[0].text)/1e9,[get(e).get('name','') for e in c[6]]))
tr=E.parse(root/f'{prefix}-hitches-updates.xml');ids={e.get('id'):e for e in tr.iter() if e.get('id')}
updates=[];seen=set()
for row in tr.iter('row'):
 c=[get(e) for e in row];t=int(c[0].text)/1e9;duration=int(c[1].text)/1e9
 if (t,duration) in seen:continue
 seen.add((t,duration));ss=[ns for s,ns in samples if t<=s<t+duration]
 tags={tag:sum(any(tag in n for n in ns) for ns in ss) for tag in ['_UIFocus','ShelfRowCell.configure','PosterCell.prepareForReuse','PosterCell.clearArtwork','PosterCell.setUp','PosterCell.init','stepOffset']}
 updates.append(dict(start=t,end=t+duration,milliseconds=duration*1000,samples=len(ss),**tags))
onsets=[]
for u in sorted(updates,key=lambda u:u['start']):
 if u['milliseconds']>=8 and u['_UIFocus']>=4 and u['_UIFocus']>u['samples']*.5:
  if onsets and u['start']-onsets[-1]['start']<.4:
   if u['milliseconds']>onsets[-1]['milliseconds']:onsets[-1]=u
  else:onsets.append(u)
tr=E.parse(root/f'{prefix}-os-signpost.xml');ids={e.get('id'):e for e in tr.iter() if e.get('id')};active={};intervals=[];seen=set()
for row in tr.iter('row'):
 c=[get(e) for e in row]
 if len(c)<12:continue
 t=int(c[0].text)/1e9;kind=c[3].get('fmt');name=c[6].text;key=(name,c[5].text)
 if (t,kind,key) in seen:continue
 seen.add((t,kind,key))
 if kind=='Begin':active[key]=t
 elif kind=='End' and key in active:intervals.append(dict(start=active.pop(key),end=t,name=name))
results=[]
for i,onset in enumerate(onsets):
 a=onset['start']+.05;b=min(onset['start']+.5,onsets[i+1]['start'] if i+1<len(onsets) else 1e9)
 window=[u for u in updates if a<=u['start']<b]
 slow=max(window,key=lambda u:u['milliseconds'],default=None)
 prep=[p for p in intervals if p['name']=='CellPrepare' and a<=p['start']<b]
 item=dict(move=i+1,onset=onset['start'],onset_ms=onset['milliseconds'],following_max_update_ms=slow['milliseconds'] if slow else None,following_max_update_at=slow['start'] if slow else None,preparation_intervals=len(prep),max_preparation_ms=max(((p['end']-p['start'])*1000 for p in prep),default=0),slow_update_samples=slow)
 results.append(item)
 print(item['move'],round(item['onset'],3),'onset',round(item['onset_ms'],2),'ms; next max',round(item['following_max_update_ms'] or 0,2),'ms; CellPrepare',item['preparation_intervals'],'max',round(item['max_preparation_ms'],2),'ms')
summary={'method':'Onsets inferred from focus-dominated sampled client updates, grouped within 400ms; not timestamped remote inputs. Post-onset window 50-500ms.','moves':results,'updates':updates,'preparation_intervals':intervals}
(root/f'{prefix}-analysis.json').write_text(json.dumps(summary,indent=2))
with (root/f'{prefix}-per-move.csv').open('w') as f:
 fields=['move','onset','onset_ms','following_max_update_ms','preparation_intervals','max_preparation_ms'];w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(results)
