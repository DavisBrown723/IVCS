/* Strategic relationship policy only; never removes edges from the movement graph. */
(function(root){
const defaults={maximumGapM:2000,maximumRouteM:4000,maximumDetour:2,detourFloorM:500};
function assess(data,link,settings=defaults){const c=link.route||data.runtime.connections[link.connection];const a=data.runtime.attachmentGeometry[c[0]][0],b=data.runtime.attachmentGeometry[c[1]][0];const direct=Math.hypot(a[0]-b[0],a[1]-b[1]);const detour=c[2]/Math.max(settings.detourFloorM,direct);const reasons=[];if(link.gapM>settings.maximumGapM)reasons.push('footprint separation');if(link.cost>settings.maximumRouteM)reasons.push('route distance');if(detour>settings.maximumDetour)reasons.push('road detour');return {included:reasons.length===0,reasons,roadDistanceM:c[2],totalDistanceM:link.cost,gapM:link.gapM,directRoadEndpointDistanceM:direct,detourRatio:detour};}
const api={defaults,assess};if(typeof module!=='undefined')module.exports=api;root.StrategicPolicy=api;
})(typeof window!=='undefined'?window:globalThis);
