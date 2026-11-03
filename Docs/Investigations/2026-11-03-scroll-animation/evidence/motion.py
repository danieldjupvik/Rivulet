import argparse
import subprocess,json,csv
from PIL import Image,ImageChops,ImageStat,ImageDraw
from pathlib import Path
parser = argparse.ArgumentParser(description="Estimate vertical motion between captured video frames.")
parser.add_argument("video", type=Path)
parser.add_argument("output_directory", type=Path)
args = parser.parse_args()
root = args.output_directory
root.mkdir(parents=True, exist_ok=True)
for label, p in [(args.video.stem, str(args.video))]:
 frames=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_frames','-show_entries','frame=best_effort_timestamp_time','-of','json',p]))['frames']
 times=[float(f['best_effort_timestamp_time']) for f in frames]
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',p,'-vf','scale=192:108','-fps_mode','passthrough','-f','rawvideo','-pix_fmt','gray','-'])
 if len(raw) != len(times) * 20736:
  raise ValueError("Decoded frame count does not match timestamps")
 rows=[];prev=None
 for i,t in enumerate(times):
  im=Image.frombytes('L',(192,108),raw[i*20736:(i+1)*20736])
  if prev:
   scores=[]
   target=im.crop((50,25,175,83))
   for d in range(-18,19):
    error=ImageStat.Stat(ImageChops.difference(target,prev.crop((50,25-d,175,83-d)))).mean[0]
    scores.append((error,d))
   err,d=min(scores)
   rows.append((t,t-times[i-1],d*10,round(err,2)))
  prev=im
 with (root/(label+'-motion.csv')).open('w') as f:
  w=csv.writer(f);w.writerow(['time','dt','dy1080','error']);w.writerows(rows)
 gaps=[r for r in rows if r[1]>.03]
 print(label,'frames',len(times),'intervals >30ms',len(gaps),'max interval',max(r[1] for r in rows))
 print('first 3s movement:',[(round(t,3),round(dt,3),dy) for t,dt,dy,e in rows if t<3 and (dy or dt>.04)])
 # Plot measured translation per frame, exclude unrelated huge scene mismatch
 plot=Image.new('RGB',(1500,330),'white');draw=ImageDraw.Draw(plot)
 draw.text((12,5),label+' vertical displacement per captured frame (pixels); blue line = zero',fill='black')
 draw.line((0,165,1500,165),fill='blue')
 pts=[(t/times[-1]*1499,165-max(-150,min(150,dy))) for t,dt,dy,e in rows]
 draw.line(pts,fill='black',width=1)
 for n in range(int(times[-1])+1):draw.text((n/times[-1]*1499,310),str(n),fill='black')
 plot.save(root/(label+'-motion.png'))
