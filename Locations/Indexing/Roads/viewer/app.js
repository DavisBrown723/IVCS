/* Local viewer; no game connection, telemetry or write-back. */
(() => {
'use strict';
const $=id=>document.getElementById(id), esc=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt=n=>Number(n).toLocaleString('en-US',{maximumFractionDigits:0});
try {
if (!window.ROAD_DATA || !window.L) throw new Error('Viewer files are missing. Keep index.html, data.js and vendor together.');
const data=window.ROAD_DATA, summary=data.manifest.summary, source=data.manifest.basemap;
const roads=new Map(data.roads.map(r=>[r.id,r])), sites=new Map(data.locations.map(s=>[s.id,s]));
const routingEdges=new Map(data.routingEdges.map(e=>[e.id,e]));
const connections=new Map(data.objectiveConnections.map(c=>[c.id,c]));
const accessById=new Map(data.attachments.map(a=>[a.id,a]));
const accessBySite=new Map();data.attachments.forEach(a=>{if(!accessBySite.has(a.locationId))accessBySite.set(a.locationId,[]);accessBySite.get(a.locationId).push(a);});
const colours={'MAIN ROAD':'#b34713','ROAD':'#176ca0','TRACK':'#578241','TRAIL':'#7b54a3','HIDE':'#707e87'};
const names={'MAIN ROAD':'Main road','ROAD':'Road','TRACK':'Track','TRAIL':'Footpath','HIDE':'Other surface'};
$('headline').innerHTML=`<div><b>${fmt(summary.mappedSections)}</b>road sections</div><div><b>${fmt(summary.components)}</b>networks</div><div class="optional"><b>${fmt(summary.bridgeSections)}</b>bridge sections</div>`;
$('dataset').textContent='Access index · '+data.manifest.attachmentDatasetId.slice(0,12)+' · '+data.manifest.generatedAtUTC.slice(0,10);
const crs=L.extend({},L.CRS.Simple,{projection:L.Projection.LonLat,transformation:new L.Transformation(source.factorX,0,-source.factorY,source.tileSize),scale:z=>2**z,zoom:s=>Math.log2(s),distance:(a,b)=>Math.hypot(a.lng-b.lng,a.lat-b.lat)});
const map=L.map('map',{crs,minZoom:1,maxZoom:9,zoomControl:false,preferCanvas:true,zoomAnimation:false,fadeAnimation:false,inertia:true,maxBounds:[[-3000,-3000],[34000,34000]],maxBoundsViscosity:0.6});
L.control.zoom({position:'topright'}).addTo(map);L.control.scale({position:'bottomright',imperial:false,maxWidth:170}).addTo(map);
const worldNorth=source.tileSize/source.factorY, worldEast=source.tileSize/source.factorX;
map.createPane('overview');map.getPane('overview').style.zIndex='150';
const fallback=L.imageOverlay('altis-overview.png',[[0,0],[worldNorth,worldEast]],{opacity:1,interactive:false,pane:'overview'}).addTo(map);
const tiles=L.tileLayer(source.tileUrl,{tileSize:source.tileSize,minZoom:0,maxZoom:9,maxNativeZoom:source.maxNativeZoom,bounds:[[0,0],[worldNorth,worldEast]],noWrap:true,keepBuffer:2,attribution:'Terrain © Bohemia Interactive · tiles <a href="https://jetelain.github.io/Arma3Map/altis.html" target="_blank" rel="noopener">Arma3Map</a>'}).addTo(map);
let successfulTiles=0,failedTiles=0;
tiles.on('tileload',()=>{successfulTiles++;$('tileStatus').textContent='Online tiles';$('tileStatus').classList.remove('offline');});
tiles.on('tileerror',()=>{failedTiles++;$('tileStatus').textContent='Tile unavailable';$('tileStatus').classList.add('offline');});
const state={roads:true,nodes:false,bridges:true,extended:false,locations:true,access:false,colour:'class',selectedRoad:null,selectedSite:null,selectedAccess:null,selectedConnection:null,component:null,hover:null,hoverSite:null};
const buckets=new Map(),bucketSize=500;
for(const r of data.roads){if(r.geometryStatus==='unavailable')continue;const a=r.beginASL,b=r.endASL;for(let x=Math.floor(Math.min(a[0],b[0])/bucketSize);x<=Math.floor(Math.max(a[0],b[0])/bucketSize);x++)for(let y=Math.floor(Math.min(a[1],b[1])/bucketSize);y<=Math.floor(Math.max(a[1],b[1])/bucketSize);y++){const k=x+','+y;if(!buckets.has(k))buckets.set(k,[]);buckets.get(k).push(r);}}
function nearby(bounds){const found=new Map();for(let x=Math.floor(bounds.getWest()/bucketSize);x<=Math.floor(bounds.getEast()/bucketSize);x++)for(let y=Math.floor(bounds.getSouth()/bucketSize);y<=Math.floor(bounds.getNorth()/bucketSize);y++)for(const r of buckets.get(x+','+y)||[])found.set(r.id,r);return [...found.values()];}
function point(p){return map.latLngToContainerPoint([p[1],p[0]]);}
function footprint(s){return s.footprint||['circle',s.position,[s.size,s.size],0];}
function corners(f){const c=Math.cos(f[3]*Math.PI/180),s=Math.sin(f[3]*Math.PI/180);return [[-1,-1],[1,-1],[1,1],[-1,1]].map(([x,y])=>[f[1][0]+x*f[2][0]*c+y*f[2][1]*s,f[1][1]-x*f[2][0]*s+y*f[2][1]*c]);}
function siteRadius(s){return map.getZoom()<3?(s.id===state.selectedSite?9:6):(s.id===state.selectedSite?12:9);}
function pickSite(p){
 if(!state.locations||map.getZoom()<2)return null;
 let best=null,nearest=Infinity;
 for(const s of data.locations){const d=point(footprint(s)[1]).distanceTo(p);if(d<=siteRadius(s)+5&&d<nearest){best=s;nearest=d;}}
 return best;
}
function componentColour(id){let n=Number(id.slice(1));return `hsl(${(n*137.508+192)%360} 65% 37%)`;}
const overlay=L.Layer.extend({onAdd(){this.canvas=L.DomUtil.create('canvas','road-canvas');this.canvas.setAttribute('aria-hidden','true');map.getPane('overlayPane').appendChild(this.canvas);map.on('move zoom resize moveend',schedule);schedule();},onRemove(){map.off('move zoom resize moveend',schedule);this.canvas.remove();}});
const layer=new overlay();let frame=0,visible=[];layer.addTo(map);
function schedule(){if(!frame)frame=requestAnimationFrame(draw);}
function draw(){frame=0;const size=map.getSize(),dpr=window.devicePixelRatio||1,c=layer.canvas,ctx=c.getContext('2d');L.DomUtil.setPosition(c,map.containerPointToLayerPoint([0,0]));c.width=Math.round(size.x*dpr);c.height=Math.round(size.y*dpr);c.style.width=size.x+'px';c.style.height=size.y+'px';ctx.scale(dpr,dpr);ctx.lineCap='round';ctx.lineJoin='round';const z=map.getZoom(),bounds=map.getBounds().pad(0.1);visible=nearby(bounds);$('visibleCount').textContent=fmt(visible.length)+' in view';$('zoomLabel').textContent='Zoom '+z.toFixed(1);const projectionScale=crs.scale(z),pixelsPerMetreX=source.factorX*projectionScale,pixelsPerMetreY=source.factorY*projectionScale,pp=Math.max(pixelsPerMetreX,pixelsPerMetreY);
function stroke(a,b,colour,width,dash=[]){a=point(a);b=point(b);ctx.beginPath();ctx.setLineDash(dash);ctx.strokeStyle=colour;ctx.lineWidth=width;ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();ctx.setLineDash([]);}
const visibleSites=state.locations?data.locations.filter(s=>{const f=footprint(s),p=point(f[1]),reach=(f[2][0]+f[2][1])*pp;return Math.abs(p.x-size.x/2)<=size.x/2+reach&&Math.abs(p.y-size.y/2)<=size.y/2+reach;}):[];
function traceSite(s){const f=footprint(s),p=point(f[1]);ctx.beginPath();if(f[0]==='circle')ctx.ellipse(p.x,p.y,f[2][0]*pixelsPerMetreX,f[2][0]*pixelsPerMetreY,0,0,Math.PI*2);else corners(f).forEach((q,i)=>{const t=point(q);i?ctx.lineTo(t.x,t.y):ctx.moveTo(t.x,t.y);});ctx.closePath();}
// Fill below roads; crisp outlines and handles are drawn separately above them.
for(const s of visibleSites){traceSite(s);ctx.fillStyle=s.id===state.selectedSite?'#f4bd3340':'#3879b426';ctx.fill();}

if(state.roads){for(const r of visible){const highlight=r.id===state.selectedRoad||r.id===state.hover;ctx.globalAlpha=state.component&&r.componentId!==state.component?0.13:1;const colour=highlight?'#f6af16':state.colour==='component'?componentColour(r.componentId):(colours[r.type]||'#637b84');let width=z<4?1.25:r.type==='MAIN ROAD'?3:r.type==='ROAD'?2.4:1.6;if(highlight)width=6;stroke(r.beginASL,r.endASL,colour,width);}ctx.globalAlpha=1;}
if(state.extended&&z>=3){for(const link of data.graph.connections){if(link.evidence!=='extended-only')continue;const a=roads.get(link.a).positionASL,b=roads.get(link.b).positionASL;if(!bounds.contains([a[1],a[0]])&&!bounds.contains([b[1],b[0]]))continue;stroke(a,b,'#c33450',2,[5,4]);}}
if(state.nodes&&z>=4){for(const r of visible){if(r.degree===2)continue;const p=point(r.positionASL);ctx.beginPath();ctx.arc(p.x,p.y,r.degree>2?3.5:2.6,0,Math.PI*2);ctx.fillStyle=r.degree>2?'#152f55':'#fbfcf6';ctx.fill();ctx.strokeStyle='#234660';ctx.lineWidth=1;ctx.stroke();}}
if(state.bridges){for(const r of visible){if(!r.bridge)continue;const p=point(r.positionASL);ctx.fillStyle='#805d9e';ctx.strokeStyle='#ffffff';ctx.lineWidth=1.3;ctx.beginPath();ctx.moveTo(p.x,p.y-6);ctx.lineTo(p.x+6,p.y);ctx.lineTo(p.x,p.y+6);ctx.lineTo(p.x-6,p.y);ctx.closePath();ctx.fill();ctx.stroke();}}

for(const s of visibleSites){const chosen=s.id===state.selectedSite;traceSite(s);ctx.strokeStyle='#fffffff0';ctx.lineWidth=chosen?6:4.5;ctx.stroke();ctx.strokeStyle=chosen?'#b46a00':'#294f83';ctx.lineWidth=chosen?3.5:2.2;ctx.stroke();}

if(state.selectedConnection){
 const route=connections.get(state.selectedConnection);
 for(const [eid] of route.edgePath){const line=routingEdges.get(eid).geometryASL;for(let i=1;i<line.length;i++){stroke(line[i-1],line[i],'#ffffff',9);stroke(line[i-1],line[i],'#116c69',5);}}
 for(const [i,aid] of [route.fromAttachmentId,route.toAttachmentId].entries()){
  const a=accessById.get(aid),p=point(a.positionASL);
  stroke(a.positionASL,a.routingAnchor.projectedPositionASL,'#3579b5',3,[3,3]);
  if(a.kind==='nearby-road')stroke(a.positionASL,a.footprintApproach2D,'#bb4c98',3,[7,5]);
  ctx.fillStyle='#115852';ctx.strokeStyle='white';ctx.lineWidth=2;ctx.beginPath();ctx.arc(p.x,p.y,13,0,Math.PI*2);ctx.fill();ctx.stroke();
  ctx.fillStyle='white';ctx.font='700 12px Segoe UI';ctx.textAlign='center';ctx.fillText(i?'B':'A',p.x,p.y+4);
 }
}
if(state.access&&z>=4){
 for(const a of data.attachments){
  if(state.selectedConnection)continue;
  if(state.selectedSite&&a.locationId!==state.selectedSite)continue;
  if(!bounds.contains([a.positionASL[1],a.positionASL[0]]))continue;
  const selected=a.id===state.selectedAccess,numbered=!!state.selectedSite;
  const isFallback=a.kind==='nearby-road',interpolated=!isFallback&&!a.evidence.includes('road-section-crossing');
  const colour=isFallback?(a.candidateTier==='strong'?'#008279':'#b14494'):interpolated?'#3974a6':'#b97208',p=point(a.positionASL);
  if(isFallback){
   stroke(a.positionASL,a.footprintApproach2D,colour,selected?4:2,[6,5]);
   const target=point(a.footprintApproach2D);ctx.beginPath();ctx.arc(target.x,target.y,3,0,Math.PI*2);ctx.fillStyle=colour;ctx.fill();
  } else {
  stroke(a.outsideASL,a.positionASL,colour,selected?5:3,interpolated?[3,3]:[]);
  stroke(a.positionASL,a.insideASL,colour,selected?5:3,interpolated?[3,3]:[]);
  const inner=point(a.insideASL),angle=Math.atan2(inner.y-p.y,inner.x-p.x);
  // A fixed-size direction glyph stays visible when a short road section ends under the marker.
  const tip={x:p.x+22*Math.cos(angle),y:p.y+22*Math.sin(angle)};
  ctx.beginPath();ctx.moveTo(tip.x,tip.y);
  ctx.lineTo(tip.x-7*Math.cos(angle-.5),tip.y-7*Math.sin(angle-.5));
  ctx.lineTo(tip.x-7*Math.cos(angle+.5),tip.y-7*Math.sin(angle+.5));
  ctx.closePath();ctx.fillStyle=colour;ctx.fill();
  }
  ctx.beginPath();ctx.arc(p.x,p.y,numbered?(selected?12:10):4.5,0,Math.PI*2);
  ctx.fillStyle=isFallback?(a.candidateTier==='strong'?'#c5f6e9':'#f7d8ef'):interpolated?'#e3f2ff':selected?'#fff3c7':'#ffd574';
  ctx.strokeStyle=selected?'#382805':colour;ctx.lineWidth=selected?3:1.5;ctx.fill();ctx.stroke();
  if(numbered){ctx.font='700 11px Segoe UI';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle='#493608';ctx.fillText(a.number,p.x,p.y);ctx.textBaseline='alphabetic';}
 }
}
if(z>=2&&z<=6){ctx.font='600 12px Segoe UI';ctx.textAlign='center';const placed=[];for(const place of data.places){if(!['NameCityCapital','NameCity','NameVillage'].includes(place.type))continue;const p=point(place.position);if(p.x<60||p.y<40||p.x>size.x-60||p.y>size.y-25)continue;if(placed.some(q=>Math.abs(q.x-p.x)<90&&Math.abs(q.y-p.y)<28))continue;ctx.lineWidth=3;ctx.strokeStyle='#fcfffbe6';ctx.strokeText(place.name,p.x,p.y-10);ctx.fillStyle='#294f48';ctx.fillText(place.name,p.x,p.y-10);placed.push(p);}}
// High-contrast selection handles stay on top of roads, fills and access lines.
if(z>=2){for(const s of visibleSites){const p=point(footprint(s)[1]),chosen=s.id===state.selectedSite,hover=s.id===state.hoverSite,radius=siteRadius(s);ctx.beginPath();ctx.arc(p.x,p.y,radius+3,0,Math.PI*2);ctx.fillStyle='#ffffff';ctx.fill();ctx.strokeStyle='#163954';ctx.lineWidth=1;ctx.stroke();ctx.beginPath();ctx.arc(p.x,p.y,radius,0,Math.PI*2);ctx.fillStyle=chosen?'#d78000':hover?'#147b99':'#294f83';ctx.fill();ctx.beginPath();ctx.arc(p.x,p.y,chosen?3:2,0,Math.PI*2);ctx.fillStyle='#ffffff';ctx.fill();}}
$('loading').style.display='none';}
function legend(){if(state.colour==='class')$('legend').innerHTML=Object.entries(names).filter(([k])=>k!=='HIDE'&&summary.roadTypes[k]).map(([k,v])=>`<div><span class="swatch" style="background:${colours[k]}"></span>${v}</div>`).join('')+'<div><span style="color:#805d9e">◆</span> Bridge</div>';else $('legend').innerHTML='<div style="grid-column:1/-1">Each colour is a separate ordinary-link network.</div>';}
legend();for(const key of ['roads','nodes','bridges','extended','locations','access'])$(key).addEventListener('change',()=>{state[key]=$(key).checked;schedule();});
$('colour').addEventListener('change',()=>{state.colour=$('colour').value;state.component=null;legend();schedule();});
$('baseOpacity').addEventListener('input',()=>{const value=Number($('baseOpacity').value)/100;tiles.setOpacity(value);fallback.setOpacity(value);$('opacityValue').value=Math.round(value*100)+'%';});
function facts(rows){return '<dl class="facts">'+rows.map(([k,v])=>`<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('')+'</dl>';}
function inspectRoad(r){state.selectedConnection=null;state.selectedRoad=r.id;state.selectedSite=null;state.selectedAccess=null;const extras=r.extended.filter(n=>!r.ordinary.includes(n));$('inspector').innerHTML=`<div class="section-title">Road section <button id="clear" class="clear">×</button></div><h2 class="detail-title">${esc(names[r.type]||r.type)}${r.bridge?' · bridge':''}</h2><div class="detail-id">${esc(r.id)} / ${esc(r.componentId)}</div>${facts([['Section length',fmt(r.length2dM)+' m'],['Width',r.widthM?fmt(r.widthM)+' m':'Unknown'],['Deck / surface ASL',r.positionASL[2].toFixed(1)+' m'],['Ordinary neighbours',r.degree],['Extended additions',extras.length],['Graph references',r.graphRefs.length]])}<div class="detail-note">${r.bridge?'Bridge widths are not reliably supplied by the engine. ':''}Connectivity is physical evidence, not guaranteed vehicle traversal.</div><div class="detail-actions"><button id="highlightNetwork">Highlight this network</button><button id="zoomRoad">Zoom to section</button></div>`;$('clear').onclick=clear;$('highlightNetwork').onclick=()=>{state.component=state.component===r.componentId?null:r.componentId;state.colour='component';$('colour').value='component';legend();schedule();};$('zoomRoad').onclick=()=>map.setView([r.positionASL[1],r.positionASL[0]],8);schedule();}
function siteName(s){const nearby=data.places.filter(p=>['NameCityCapital','NameCity','NameVillage'].includes(p.type)).sort((a,b)=>Math.hypot(a.position[0]-s.position[0],a.position[1]-s.position[1])-Math.hypot(b.position[0]-s.position[0],b.position[1]-s.position[1]))[0];const labels={base:'Military base',factory:'Industrial area',town:'Settlement',power:'Power facility',port:'Port',fuel:'Fuel site',radiotower:'Radio site',hospital:'Hospital'};return (labels[s.type]||s.type)+(nearby?' · '+nearby.name:'');}
const siteLabels=new Map(data.locations.map(s=>[s.id,siteName(s)]));

function inspectSite(s,zoom=false){
 state.selectedSite=s.id;state.selectedRoad=null;state.selectedAccess=null;state.selectedConnection=null;state.component=null;
 state.locations=true;$('locations').checked=true;state.access=true;$('access').checked=true;
 const f=footprint(s),access=accessBySite.get(s.id)||[],coverage=data.accessCoverage.find(c=>c.locationId===s.id);
 const hasFallback=access.some(a=>a.kind==='nearby-road');
 const description=coverage.inletCount
  ?'Numbered inlets cross the footprint. Arrows point inward.'
  :hasFallback?'No boundary inlet. Dashed lines show unassessed off-road approaches: green up to 150 m, purple over 150 m through 500 m.'
  :'No candidate within 500 m of this footprint. This does not establish that the site is unreachable.';
 $('inspector').innerHTML='<div class="section-title">Location <button id="clear" aria-label="Clear selection">×</button></div>'
  +'<h2 class="detail-title">'+esc(siteLabels.get(s.id))+'</h2><div class="detail-id">'+esc(s.id)+'</div>'
  +facts([['Objects',fmt(s.objectCount)],['Footprint',f[0]],['Boundary inlets',coverage.inletCount],['Fallback approaches',coverage.fallbackCount],...(hasFallback?[['Strong / secondary',coverage.strongFallbacks+' / '+coverage.secondaryFallbacks]]:[])])
  +'<div class="detail-note">'+esc(description)+'<br><br>Water, slopes, fences and vehicle access remain unassessed.</div>'
  +(access.length?'<div class="inlet-list" aria-label="Access points for selected location">'+access.map(a=>'<button class="inlet-chip '+(a.kind==='nearby-road'?a.candidateTier:'')+'" data-inlet="'+esc(a.id)+'" aria-label="Inspect '+(a.kind==='nearby-road'?'approach ':'inlet ')+a.number+'"><b>'+a.number+'</b> '+esc(a.kind==='nearby-road'?fmt(a.footprintGapM)+' m':names[roads.get(a.roadId).type]||'Road')+'</button>').join('')+'</div><div id="inletDetail" aria-live="polite"></div><div id="connectionPicker"></div>':'')
  +'<div class="detail-actions"><button id="zoomSite">Frame '+(hasFallback?'approaches':'this location')+'</button></div>';
 $('clear').onclick=clear;$('zoomSite').onclick=()=>frameAccess(s);
 for(const b of $('inspector').querySelectorAll('[data-inlet]'))b.onclick=()=>selectInlet(accessById.get(b.dataset.inlet));
 renderConnections();if(zoom)frameAccess(s);schedule();
}
function frameAccess(s){
 const candidates=(accessBySite.get(s.id)||[]).filter(a=>a.kind==='nearby-road');
 if(!candidates.length){frameSite(s);return;}
 const f=footprint(s),points=candidates.flatMap(a=>[a.positionASL,a.footprintApproach2D]);
 points.push(f[1]);map.fitBounds(points.map(p=>[p[1],p[0]]),{padding:[90,90],maxZoom:8});
}
function selectInlet(a){
 if(state.selectedSite!==a.locationId)inspectSite(sites.get(a.locationId));
 state.selectedAccess=a.id;state.selectedRoad=null;state.selectedConnection=null;
 for(const b of $('inspector').querySelectorAll('[data-inlet]'))b.classList.toggle('active',b.dataset.inlet===a.id);
 const r=roads.get(a.roadId),isFallback=a.kind==='nearby-road',interpolated=!a.evidence.includes('road-section-crossing');
 $('inletDetail').innerHTML='<div class="inlet-detail"><strong>'+(isFallback?'Approach ':'Inlet ')+a.number+' · '+esc(names[r.type]||r.type)+'</strong>'
  +facts([['X / Y',fmt(a.positionASL[0])+' / '+fmt(a.positionASL[1])],['Surface ASL',a.positionASL[2].toFixed(1)+' m'],...(isFallback?[['Off-road gap',fmt(a.footprintGapM)+' m'],['Candidate tier',a.candidateTier]]:[]),['Anchor connector',a.routingAnchor.connectorLength3dM.toFixed(1)+' m']])
  +'<span>'+esc(isFallback?'Straight gap to footprint; approach height and vehicle path are unknown.':interpolated?'Crossing interpolated between ordinary-connected sections.':'Crossing of an observed road section and the saved footprint.')+'</span>'
  +'<div class="detail-id">'+esc(a.roadIds.join(', '))+'</div><div class="detail-actions"><button id="zoomInlet">Zoom to '+(isFallback?'approach':'inlet')+'</button></div></div>';
 $('zoomInlet').onclick=()=>map.setView([a.positionASL[1],a.positionASL[0]],8);
 renderConnections();schedule();
}
function renderConnections(){
 const panel=$('connectionPicker');if(!panel)return;
 const matches=data.objectiveConnections.filter(c=>state.selectedAccess
  ?c.fromAttachmentId===state.selectedAccess||c.toAttachmentId===state.selectedAccess
  :c.fromLocationId===state.selectedSite||c.toLocationId===state.selectedSite).sort((a,b)=>a.roadDistanceM-b.roadDistanceM);
 panel.innerHTML='<label for="connectionChoice">Baseline road connections ('+matches.length+')</label>'
  +'<select id="connectionChoice"><option value="">Select a connection…</option>'+matches.map(c=>{
   const forward=c.fromLocationId===state.selectedSite&&(!state.selectedAccess||c.fromAttachmentId===state.selectedAccess);
   const a=accessById.get(forward?c.fromAttachmentId:c.toAttachmentId),b=accessById.get(forward?c.toAttachmentId:c.fromAttachmentId);
   return '<option value="'+c.id+'">'+a.number+' → '+esc(b.locationId===a.locationId?'same site':siteLabels.get(b.locationId))+' #'+b.number+' · '+fmt(c.roadDistanceM)+' m road</option>';
  }).join('')+'</select><div id="connectionDetail"></div>';
 $('connectionChoice').onchange=()=>{
  state.selectedConnection=$('connectionChoice').value||null;
  const c=connections.get(state.selectedConnection);
  $('connectionDetail').innerHTML=c?facts([['Road travel',fmt(c.roadDistanceM)+' m'],['Off-road gaps A / B',c.offRoadGapM.map(n=>fmt(n)+' m').join(' / ')],['Anchor connectors',fmt(c.anchorConnectorM.reduce((a,b)=>a+b,0))+' m']])+'<p class="note">Teal follows the indexed road graph. Endpoint approaches remain unassessed. Other routes remain in the routing graph.</p><div class="detail-actions"><button id="frameConnection">Frame connection</button></div>':'';
  if(c)$('frameConnection').onclick=()=>{
   const points=c.edgePath.flatMap(([eid])=>routingEdges.get(eid).geometryASL);
   for(const id of [c.fromAttachmentId,c.toAttachmentId]){const a=accessById.get(id);points.push(a.positionASL,a.footprintApproach2D);}
   map.fitBounds(points.map(p=>[p[1],p[0]]),{padding:[90,90],maxZoom:8});
  };
  schedule();
 };
}
function pickAccess(p){
 if(!state.access||map.getZoom()<4)return null;
 let best=null,gap=state.selectedSite?13:7;
 for(const a of (state.selectedSite?accessBySite.get(state.selectedSite)||[]:data.attachments)){
  const d=point(a.positionASL).distanceTo(p);if(d<gap){best=a;gap=d;}
 }
 return best;
}
function frameSite(s){const f=footprint(s);if(f[0]==='rectangle')map.fitBounds(corners(f).map(p=>[p[1],p[0]]),{padding:[80,80],maxZoom:8});else map.fitBounds([[f[1][1]-f[2][0],f[1][0]-f[2][0]],[f[1][1]+f[2][0],f[1][0]+f[2][0]]],{padding:[80,80],maxZoom:8});}
function clear(){state.selectedConnection=null;state.selectedRoad=null;state.selectedSite=null;state.selectedAccess=null;state.component=null;$('inspector').innerHTML='<div class="section-title">Inspect the network</div><p class="intro">Click a road or site marker to see its connections and indexing evidence.</p>';schedule();}
function pointLine(p,a,b){const dx=b.x-a.x,dy=b.y-a.y,len=dx*dx+dy*dy,t=len?Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/len)):0;return Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);}
function pickRoad(p){let best=null,near=9;for(const r of visible){const d=pointLine(p,point(r.beginASL),point(r.endASL));if(d<near){best=r;near=d;}}return best;}
let tooltip=null;
map.on('mousemove',event=>{
 $('coordinates').textContent=`X ${fmt(event.latlng.lng)} / Y ${fmt(event.latlng.lat)}`;
 const s=pickSite(event.containerPoint),r=!s&&state.roads?pickRoad(event.containerPoint):null;
 const siteId=s?s.id:null,roadId=r?r.id:null;
 if(siteId!==state.hoverSite||roadId!==state.hover){
  state.hoverSite=siteId;state.hover=roadId;map.getContainer().style.cursor=s||r?'pointer':'';
  if(tooltip){map.removeLayer(tooltip);tooltip=null;}
  const label=s?siteLabels.get(s.id)+' · '+fmt(s.objectCount)+' objects':r?(names[r.type]||r.type)+' · '+r.id+(r.bridge?' · bridge':''):null;
  if(label)tooltip=L.tooltip({direction:'top',offset:[0,-16],opacity:0.97}).setLatLng(event.latlng).setContent(esc(label)).addTo(map);
  schedule();
 }
});
map.on('mouseout',()=>{state.hover=null;state.hoverSite=null;map.getContainer().style.cursor='';if(tooltip){map.removeLayer(tooltip);tooltip=null;}schedule();});
map.on('click',event=>{const s=pickSite(event.containerPoint);if(s){inspectSite(s);return;}const inlet=pickAccess(event.containerPoint);if(inlet){selectInlet(inlet);return;}const r=state.roads?pickRoad(event.containerPoint):null;if(r)inspectRoad(r);});
const views={airport:{pos:[16551,14648],zoom:5,title:'Altis International Airport'},athira:{pos:[18710,14000],zoom:6,title:'Athira'},kavala:{pos:[12970,3460],zoom:6,title:'Kavala'}};
function jump(pos,zoom,title){map.setView(pos,zoom);$('viewTitle').textContent=title;$('viewSubtitle').textContent='Engine-extracted roads • click a section to inspect';}
for(const button of document.querySelectorAll('[data-view]'))button.onclick=()=>{clear();const v=views[button.dataset.view];jump(v.pos,v.zoom,v.title);};

$('doridaJump').onclick=()=>{
 const place=data.places.find(p=>p.name==='Dorida');
 if(!place)return;
 const site=data.locations.filter(s=>s.type==='town').sort((a,b)=>Math.hypot(a.position[0]-place.position[0],a.position[1]-place.position[1])-Math.hypot(b.position[0]-place.position[0],b.position[1]-place.position[1]))[0];
 if(site){inspectSite(site,true);$('viewTitle').textContent='Dorida · road inlets';$('viewSubtitle').textContent='Select a numbered inlet to inspect its crossing';}
};
$('fallbackJump').onclick=()=>{const s=sites.get('altis_power_1145');inspectSite(s,true);$('viewTitle').textContent='Dorida · off-road approaches';$('viewSubtitle').textContent='Dashed gaps are unassessed; select a numbered approach';};
$('bridgeJump').onclick=()=>{clear();const bridge=data.roads.filter(r=>r.bridge&&r.geometryStatus!=='unavailable').sort((a,b)=>Math.hypot(a.positionASL[0]-14648,a.positionASL[1]-16551)-Math.hypot(b.positionASL[0]-14648,b.positionASL[1]-16551))[0];if(bridge){jump([bridge.positionASL[1],bridge.positionASL[0]],7,'Bridge inspection');inspectRoad(bridge);}};
$('island').onclick=()=>{clear();jump([15360,15360],2,'Altis road network');map.fitBounds([[5000,0],[26500,30500]],{padding:[30,30]});};
let results=[];
function search(){const q=$('search').value.trim(),lower=q.toLowerCase();results=[];if(q.length<2){$('results').innerHTML='';return;}const coord=q.match(/^\s*(\d+(?:\.\d+)?)\s*[, ]\s*(\d+(?:\.\d+)?)\s*$/);if(coord)results.push({label:`Coordinates ${coord[1]}, ${coord[2]}`,hint:'X / Y metres',run:()=>jump([Number(coord[2]),Number(coord[1])],7,'Map coordinates')});const r=roads.get(lower);if(r)results.push({label:r.id,hint:names[r.type],run:()=>{jump([r.positionASL[1],r.positionASL[0]],8,'Road inspection');inspectRoad(r);}});for(const p of data.places.filter(p=>p.name.toLowerCase().includes(lower)).slice(0,5))results.push({label:p.name,hint:p.type.replace(/^Name/,''),run:()=>jump([p.position[1],p.position[0]],6,p.name)});for(const s of data.locations.filter(s=>(s.id+' '+siteLabels.get(s.id)+' '+s.types.join(' ')).toLowerCase().includes(lower)).slice(0,5))results.push({label:siteLabels.get(s.id),hint:s.id,run:()=>{inspectSite(s,true);$('viewTitle').textContent=siteLabels.get(s.id);}});$('results').innerHTML=results.length?results.map((r,i)=>`<button role="option" data-result="${i}">${esc(r.label)}<small>${esc(r.hint)}</small></button>`).join(''):'<div class="note">No matching place, site or road.</div>';for(const b of $('results').querySelectorAll('button'))b.onclick=()=>choose(Number(b.dataset.result));}
function choose(index=0){if(results[index]){results[index].run();$('results').innerHTML='';$('search').value='';}}
$('search').addEventListener('input',search);$('search').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();choose();}if(e.key==='Escape')$('results').innerHTML='';});$('searchGo').onclick=()=>{search();choose();};
map.on('moveend',()=>{const c=map.getCenter();history.replaceState(null,'',`#${map.getZoom().toFixed(2)}/${c.lng.toFixed(1)}/${c.lat.toFixed(1)}`);});
const saved=location.hash.slice(1).split('/').map(Number);if(saved.length===3&&saved.every(Number.isFinite)&&saved[0]>=1&&saved[0]<=9)map.setView([saved[2],saved[1]],saved[0]);else jump(views.airport.pos,views.airport.zoom,views.airport.title);
schedule();
} catch(error){$('loading').style.display='none';$('error').hidden=false;$('error').textContent=error.message;console.error(error);}
})();
