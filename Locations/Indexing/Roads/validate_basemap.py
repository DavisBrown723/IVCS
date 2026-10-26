"""Optional basemap check; requires Pillow + NumPy, never adjusts road coordinates."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
a=np.asarray(Image.open(ROOT/'viewer/altis-overview.png').convert('RGB')).astype(float)
mask=(a[:,:,0]>a[:,:,1]+4)&(a[:,:,1]>a[:,:,2]+8)&(a[:,:,2]<200)
mask=np.maximum.reduce([np.roll(np.roll(mask,dy,axis=0),dx,axis=1) for dx,dy in [(0,0),(1,0),(-1,0),(0,1),(0,-1)]])
roads=json.loads((ROOT.parent/'output/altis/roads/roads.json').read_text())
manifest=json.loads((ROOT.parent/'output/altis/roads/manifest.json').read_text())
base=manifest['basemap']
points=np.array([r['positionASL'][:2] for r in roads if r['type']=='MAIN ROAD'])
x=np.rint(points[:,0]*base['factorX']*8).astype(int)
y=np.rint((base['tileSize']-points[:,1]*base['factorY'])*8).astype(int)
valid=(x>=0)&(x<1696)&(y>=0)&(y<1696)
score=float((mask[np.clip(y,0,1695),np.clip(x,0,1695)]&valid).mean())
result={'method':'Main-road centres intersect the overview brown-road mask with 1-pixel tolerance',
        'mainRoadSections':len(points),'fractionMatching':score,'projection':base,
        'caveat':'A coarse independent alignment check, not a survey-accuracy measurement.'}
assert score>0.95,result
(ROOT.parent/'output/altis/roads/basemap-validation.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
