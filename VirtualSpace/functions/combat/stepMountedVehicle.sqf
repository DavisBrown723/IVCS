// Queue both vehicles' impacts before applying damage; pylon records remain owned by pylons.
params ["_engagement","_shooter","_target","_range","_dt"];
private _profile = [_target get "class"] call IVCS_Combat_getVehicleProfile;
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _settings = [_range,_target get "class",_combat get "accuracyScale",_combat get "cadenceScale",_combat get "minimumFireInterval"];
private _key = "mountedFactors_"+(_shooter get "id");
private _state = _engagement getOrDefault [_key,[]];
if (_state isEqualTo [] || {(_state select 0) isNotEqualTo _settings}) then {_state=[_settings,createHashMap];_engagement set [_key,_state]};
private _cache = _state select 1;
private _delays = _shooter get "turretFireDelays";
private _seed = _engagement get "seed";
private _random = {_seed=(_seed*75+74) mod 65537;_seed/65537};
private _hits = []; private _shots = 0;
private _air = (_shooter get "vehicleType") == "helicopter";
private _policy = if (_air) then {[_shooter] call IVCS_Combat_getHelicopterPolicy} else {[]};
{
    _x params ["_turret","_operator"];
    if (!_air || {(_policy select 0)=="ATTACK" || {(_turret select 0) isNotEqualTo [-1]}}) then {
        private _key = str (_turret select 0);
        private _delay = (_delays getOrDefault [_key,0])-_dt;
        private _arm = 0;
        if (_operator isNotEqualTo []) then {{_arm=_arm max ((_operator get "hitpoints") select _x select 1)} forEach (([_operator] call IVCS_Combat_getHitpointLayout) select 2)};
        private _shot = if (_delay<=0) then {[_turret,_cache,_range,_profile,_air] call IVCS_Combat_getReturnFireShot} else {[]};
        while {_delay<=0 && {_shot isNotEqualTo []}} do {
            _shot params ["_record","_weapon","_ammo","_factors","_interval","_records","_index",["_roundIndex",1],["_remove",true]];
            private _attempts = (floor(-_delay/_interval)+1) min (_record select _roundIndex);
            _record set [_roundIndex,(_record select _roundIndex)-_attempts]; _shots=_shots+_attempts;
            _delay=_delay+_attempts*_interval;
            if ((_record select _roundIndex)==0) then {if (_remove) then {_records deleteAt _index}; _delay=_delay+(_combat get "reloadDelay")};
            private _successes = [_attempts,(((_factors select 0)*(1-0.65*_arm)) max 0) min 0.8,_random] call IVCS_Combat_sampleHits;
            for "_hit" from 1 to _successes do {_hits pushBack [_target,_ammo,_factors select 1,call _random,call _random]};
            if (_delay<=0) then {_shot=[_turret,_cache,_range,_profile,_air] call IVCS_Combat_getReturnFireShot};
        };
        _delays set [_key,_delay max 0];
    };
} forEach ([_shooter] call IVCS_Combat_getReturnFireStations);
_engagement set ["seed",_seed];
_engagement set ["shots",(_engagement get "shots")+_shots];
_engagement set ["vehicleShots",(_engagement get "vehicleShots")+_shots];
_engagement set ["hits",(_engagement get "hits")+count _hits];
_engagement set ["vehicleHits",(_engagement get "vehicleHits")+count _hits];
if (_shots>0) then {[_target,_shooter] call IVCS_Combat_markAirThreat};
_hits
