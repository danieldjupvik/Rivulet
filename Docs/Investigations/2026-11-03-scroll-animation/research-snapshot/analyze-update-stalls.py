from pathlib import Path
from collections import Counter
import xml.etree.ElementTree as E
import json,sys
root=Path(__file__).parent
prefix=sys.argv[1] if len(sys.argv)>1 else 'rivulet'
tr=E.parse(root/f'{prefix}-time-profile.xml');ids={e.get('id'):e for e in tr.iter() if e.get('id')}
def get(e):return ids[e.get('ref')] if e.get('ref') else e
samples=[]
for row in tr.iter('row'):
 c=[get(e) for e in row]
 if 'Main Thread' not in c[1].get('fmt',''):continue
 frames=[get(e) for e in c[6]];names=[e.get('name','') for e in frames]
 samples.append((int(c[0].text)/1e9,names))
tr=E.parse(root/f'{prefix}-hitches-updates.xml');uids={e.get('id'):e for e in tr.iter() if e.get('id')}
def ug(e):return uids[e.get('ref')] if e.get('ref') else e
updates=[]
for row in tr.iter('row'):
 c=[ug(e) for e in row];start=int(c[0].text)/1e9;duration=int(c[1].text)/1e9
 updates.append((start,duration,c[6].get('fmt','')))
for t,d,color in sorted(set(updates),key=lambda x:-x[1])[:20]:
 ss=[ns for s,ns in samples if t<=s<t+d]
 counts={tag:sum(any(tag in n for n in ns) for ns in ss) for tag in ['ShelfRowCell.configure','PosterCell.configure','PosterCell.prepareForReuse','stepOffset','_UIFocus','layoutSubviews','ImageCache','ImageDecode']}
 leaves=Counter(ns[0] for ns in ss if ns)
 print(round(t,6),round(d*1000,3),color,len(ss),counts)
summary={'updates':updates,'long_updates':[]}
for t,d,color in sorted(set(updates),key=lambda x:-x[1])[:20]:
 ss=[ns for s,ns in samples if t<=s<t+d]
 counts=Counter(n for ns in ss for n in set(ns))
 app=Counter(n for ns in ss for n in set(ns) if any(s in n for s in ['ShelfRowCell','PosterCell','PlexHome','ImageCache','Layered','Compositor','FocusScroll']))
 summary['long_updates'].append(dict(start=t,milliseconds=d*1000,color=color,samples=len(ss),top_app_frames=app.most_common(20),top_frames=counts.most_common(20)))
(root/f'{prefix}-update-stalls.json').write_text(json.dumps(summary,indent=2))
