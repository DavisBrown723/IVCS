// Called after infantry attempts are queued and before either side removes casualties.
params ["_engagement","_infantry","_vehicle","_range","_dt"];
private _stations = [_vehicle] call IVCS_Combat_getReturnFireStations;
private _air = (_vehicle get "vehicleType")=="helicopter";
if (_air && {(([_vehicle] call IVCS_Combat_getHelicopterPolicy) select 0)=="TRANSPORT"}) then {_stations=_stations select {((_x select 0) select 0) isNotEqualTo [-1]}};
if (_stations isEqualTo []) exitWith {};
private _targets = [_infantry] call IVCS_Combat_getReturnFireTargets;
if (_targets isEqualTo []) exitWith {};
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _now=if (_air) then {_engagement get "stepTime"} else {IVCS_SimulationTime};
private _exposure=if (_air) then {[_infantry,_now] call IVCS_Combat_getAirExposure} else {1};
private _spacing=_combat get "blastSpacing";
private _defense=_infantry get "airDefense";
if (_air && {_defense isNotEqualTo []} && {_now-(_defense select 1)>=(_combat get "airReactionDelay")}) then {_spacing=_spacing*2};
private _settings = [_range,_combat get "accuracyScale",_combat get "cadenceScale",_combat get "minimumFireInterval"];
private _state = _engagement getOrDefault ["returnFactors",[]];
if (_state isEqualTo [] || {(_state select 0) isNotEqualTo _settings}) then {_state=[_settings,createHashMap];_engagement set ["returnFactors",_state]};
private _cache = _state select 1;
private _delays = _vehicle get "turretFireDelays";
private _seed = _engagement get "seed";
private _random = {_seed=(_seed*75+74) mod 65537;_seed/65537};
private _selection = [] call IVCS_Combat_getBodySelection;
private _cumulative = _selection select 2;
private _targetCount = count _targets;
// MG fire does not allocate or prepare splash geometry.
private _splashCache = nil;
private _shots = 0;private _successfulHits = 0;private _hits=[];
private _queueHit = {
    params ["_target","_weapon","_ammo","_factors"];
    private _roll = (call _random)*(_selection select 1);
    private _region = (_cumulative select (count _cumulative-1)) select 0;
    {if (_roll<(_x select 1)) exitWith {_region=_x select 0}} forEach _cumulative;
    _hits pushBack [_target,_weapon,_ammo,_range,_region,call _random,_factors];
};
{
    _x params ["_turret","_gunner"];
    private _key = str (_turret select 0);
    private _delay = (_delays getOrDefault [_key,0])-_dt;
    private _armDamage = 0;
    if (_gunner isNotEqualTo []) then {
        {_armDamage=_armDamage max ((_gunner get "hitpoints") select _x select 1)} forEach (([_gunner] call IVCS_Combat_getHitpointLayout) select 2);
    };
    private _shot = if (_delay<=0) then {[_turret,_cache,_range,createHashMap,_air] call IVCS_Combat_getReturnFireShot} else {[]};
    while {_delay<=0 && {_shot isNotEqualTo []}} do {
        _shot params ["_record","_weapon","_ammo","_factors","_interval","_records","_index",["_roundIndex",1],["_remove",true]];
        private _attempts = (floor(-_delay/_interval)+1) min (_record select _roundIndex);
        _record set [_roundIndex,(_record select _roundIndex)-_attempts];_shots=_shots+_attempts;
        _delay=_delay+_attempts*_interval;
        if ((_record select _roundIndex)==0) then {if (_remove) then {_records deleteAt _index};_delay=_delay+(_combat get "reloadDelay")};
        private _accuracy = ((((_factors select 0)*(1-0.65*_armDamage)) max 0) min 0.8)*_exposure;
        private _successes = [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits;
        _successfulHits=_successfulHits+_successes;
        for "_hit" from 1 to _successes do {
            private _targetIndex = floor ((call _random)*_targetCount);
            [_targets select _targetIndex,_weapon,_ammo,_factors] call _queueHit;
            private _radius = _ammo get "blastRadius";
            if ((_ammo get "blast")>0 && {_radius>0}) then {
                if (isNil "_splashCache") then {
                    private _settings = [_targetCount,_spacing];
                    private _state = _engagement getOrDefault ["returnSplash",[]];
                    if (_state isEqualTo [] || {(_state select 0) isNotEqualTo _settings}) then {
                        _state = [_settings,createHashMap];
                        _engagement set ["returnSplash",_state];
                    };
                    _splashCache = _state select 1;
                };
                private _byTarget = _splashCache get (_ammo get "class");
                if (isNil "_byTarget") then {_byTarget=createHashMap;_splashCache set [_ammo get "class",_byTarget]};
                private _splash = _byTarget get _targetIndex;
                if (isNil "_splash") then {
                    _splash = [];
                    private _width = ceil sqrt _targetCount;
                    private _blastSpacing = _spacing;
                    private _radiusSquared = _radius*_radius;
                    for "_index" from 0 to (_targetCount-1) do {
                        if (_index!=_targetIndex) then {
                            private _dx = (_index mod _width)-(_targetIndex mod _width);
                            private _dy = (floor(_index/_width))-(floor(_targetIndex/_width));
                            private _distanceSquared = (_dx*_dx+_dy*_dy)*_blastSpacing*_blastSpacing;
                            if (_distanceSquared<16*_radiusSquared) then {
                                private _damage = (_ammo get "blast")*(if (_distanceSquared<=_radiusSquared) then {1} else {(_radiusSquared/_distanceSquared)^2});
                                _splash pushBack [_index,createHashMapFromArray [["hit",_damage]]];
                            };
                        };
                    };
                    _byTarget set [_targetIndex,_splash];
                };
                {[_targets select (_x select 0),_weapon,_x select 1,[0,1]] call _queueHit} forEach _splash;
            };
        };
        if (_delay<=0) then {_shot=[_turret,_cache,_range,createHashMap,_air] call IVCS_Combat_getReturnFireShot};
    };
    _delays set [_key,_delay max 0];
} forEach _stations;
_engagement set ["seed",_seed];
_engagement set ["shots",(_engagement get "shots")+_shots];
_engagement set ["vehicleShots",(_engagement get "vehicleShots")+_shots];
_engagement set ["hits",(_engagement get "hits")+_successfulHits];
_engagement set ["vehicleHits",(_engagement get "vehicleHits")+_successfulHits];
if (_air && {_shots>0}) then {[_infantry,_vehicle,_now] call IVCS_Combat_markInfantryAirThreat};
{_x call IVCS_Combat_damageUnit} forEach _hits;
