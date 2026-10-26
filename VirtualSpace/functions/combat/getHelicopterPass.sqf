// Split firing windows at phase boundaries; movement queries need only the current phase.
params ["_engagement",["_dt",0],["_now",IVCS_SimulationTime]];
private _combat=IVCS_VirtualSpace_Controller get "combat";
private _fire=_combat get "helicopterFireTime";
private _period=_fire+(_combat get "helicopterRepositionTime");
private _time=(_now-(_engagement get "startedAt")) max 0;
private _firing=(_time mod _period)<_fire;
private _cycle=floor(_time/_period);
if (_dt==0) exitWith {[0,_firing,_cycle,[]]};
private _segments=[];private _cursor=(_time-_dt) max 0;private _fireTime=0;
while {_time-_cursor>0.000001} do {
    private _phase=_cursor mod _period;
    private _active=_phase<_fire;
    private _length=(_time-_cursor) min ((if (_active) then {_fire} else {_period})-_phase);
    _segments pushBack [_active,_length];_cursor=_cursor+_length;
    if (_active) then {_fireTime=_fireTime+_length};
};
[_fireTime,_firing,_cycle,_segments]
