params ["_engagement", "_groups", "_dt",["_now",-1]];
if (_groups call IVCS_Combat_isHelicopterPair) exitWith {
    _engagement set ["stepTime",if (_now<0) then {(_engagement get "startedAt")+(_engagement get "elapsed")+_dt} else {_now}];
    [_engagement,_groups,_dt] call IVCS_Combat_stepHelicopter
};
if (((_groups select 1) get "entityType") in ["vehicle","uav"]) exitWith { [_engagement,_groups,_dt] call IVCS_Combat_stepVehicle; };
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _range = ((_groups select 0) get "position") distance2D ((_groups select 1) get "position");
private _hits = [];
private _factorState = _engagement getOrDefault ["shotFactors",[]];
private _accuracyScale = _combat get "accuracyScale";
private _cadenceScale = _combat get "cadenceScale";
private _minimumInterval = _combat get "minimumFireInterval";
if (_factorState isEqualTo [] || { (_factorState select 0) != _range } || { (_factorState select 1) != _accuracyScale } || { (_factorState select 3) != _cadenceScale } || { (_factorState select 4) != _minimumInterval }) then {
    _factorState = [_range,_accuracyScale,createHashMap,_cadenceScale,_minimumInterval];
    _engagement set ["shotFactors",_factorState];
};
private _factorCache = _factorState select 2;
private _reloadDelay = _combat get "reloadDelay";
private _shots = _engagement get "shots";
// The same local integer generator drives hit counts and successful-hit details.
private _seed = _engagement get "seed";
private _random = { _seed = (_seed * 75 + 74) mod 65537; _seed / 65537 };
private _selection = [] call IVCS_Combat_getBodySelection;
private _cumulative = _selection select 2;
private _weightTotal = _selection select 1;
private _lastRegion = (_cumulative select (count _cumulative - 1)) select 0;
// Take both firing rosters before applying hits: no first-side casualty advantage.
{
    private _shooters = _x get "units";
    private _targets = (_groups select (1 - _forEachIndex)) get "units";
    private _targetCount = count _targets;
    {
        private _unit = _x;
        private _delay = (_unit get "fireDelay") - _dt;
        _unit set ["fireDelay", _delay max 0];
        if (_delay <= 0) then {
            private _shot = [_unit,_factorCache,_range,_cadenceScale,_minimumInterval] call IVCS_Combat_getPreparedShot;
            if (_shot isNotEqualTo []) then {
                // Read injuries once for this simultaneous window; inventory stays live per batch.
                private _armDamage = 0;
                private _hitpoints = _unit get "hitpoints";
                { _armDamage = _armDamage max (_hitpoints select _x select 1); } forEach (([_unit] call IVCS_Combat_getHitpointLayout) select 2);
                while { _delay <= 0 && { _shot isNotEqualTo [] } } do {
                    _shot params ["_magazine", "_weapon", "_ammo", "_factors", "_interval", "_magazines", "_magazineIndex"];
                    // Include attempts due exactly at the window end; preserve fractional cadence.
                    private _attempts = (floor (-_delay / _interval) + 1) min (_magazine select 1);
                    _magazine set [1, (_magazine select 1) - _attempts];
                    _shots = _shots + _attempts;
                    _delay = _delay + _attempts * _interval;
                    if ((_magazine select 1) == 0) then {
                        _delay = _delay + _reloadDelay;
                        // Reuse this selection's source/index; don't rescan inventory on exhaustion.
                        _magazines deleteAt _magazineIndex;
                    };
                    private _accuracy = (((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8;
                    private _hitCount = if (_attempts == 1) then {
                        if (call _random < _accuracy) then { 1 } else { 0 }
                    } else { [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits };
                    // Misses require neither an enemy selection nor a body/hitpoint selection.
                    for "_hit" from 1 to _hitCount do {
                        private _target = _targets select floor ((call _random) * _targetCount);
                        private _roll = (call _random) * _weightTotal;
                        private _region = _lastRegion;
                        { if (_roll < (_x select 1)) exitWith { _region = _x select 0; }; } forEach _cumulative;
                        _hits pushBack [_target,_weapon,_ammo,_range,_region,call _random,_factors];
                    };
                    if (_delay <= 0) then {
                        // Exhaustion can select another magazine/ammunition/weapon within this window.
                        _shot = [_unit,_factorCache,_range,_cadenceScale,_minimumInterval] call IVCS_Combat_getPreparedShot;
                    };
                };
                // A dry weapon cannot bank firing attempts while waiting for ammunition.
                _unit set ["fireDelay",_delay max 0];
            };
        };
    } forEach _shooters;
} forEach _groups;
_engagement set ["shots",_shots];
_engagement set ["seed",_seed];
_engagement set ["hits", (_engagement get "hits") + count _hits];
{ _x call IVCS_Combat_damageUnit; } forEach _hits;
{
    private _group = _x;
    {
        _engagement set ["casualties", (_engagement get "casualties") + 1];
        [_group, _x] call IVCS_VirtualSpace_Group_RemoveUnit;
    } forEach ((_group get "units") select { (_x get "damage") >= 1 });
} forEach _groups;
_engagement set ["elapsed", (_engagement get "elapsed") + _dt];
