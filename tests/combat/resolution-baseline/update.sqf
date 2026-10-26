params ["_engagement", ["_now", IVCS_SimulationTime], ["_stepLimit", -1], ["_deferSearch", false]];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _step = _combat get "step";
private _dt = (_now - (_engagement get "lastUpdate")) max 0;
_engagement set ["lastUpdate", _now];
private _groups = (_engagement get "groups") apply { [_x] call IVCS_VirtualSpace_getEntity };
if (_groups findIf { isNil "_x" } != -1) exitWith { [_engagement get "id"] call IVCS_Combat_finish; };
if ((_engagement get "mode") in ["spawning", "despawning"]) exitWith { _engagement set ["pending", 0]; };
private _pending = (_engagement get "pending") + _dt;
// Idle polls keep elapsed time, but do not rebuild infantry/terrain state until a tick is due.
if ((_engagement get "mode") == "virtual" && { _pending < _step } && {
    _groups findIf { _x get "active" } == -1
}) exitWith { _engagement set ["pending", _pending]; };
if (!(_groups call IVCS_Combat_isPair)) exitWith { [_engagement get "id"] call IVCS_Combat_finish; };
if ((_engagement get "mode") != "virtual") exitWith { _engagement set ["pending", 0]; };
private _activeIndex = _groups findIf { _x get "active" };
if (_activeIndex != -1) exitWith { [_groups select _activeIndex] call IVCS_Combat_onSpawn; };
private _ammoGroups=_groups+(((_engagement get "supporters") apply {[_x] call IVCS_VirtualSpace_getEntity}) select {!isNil "_x"});
if (!([_engagement,_groups] call IVCS_Combat_hasCombatContact)) exitWith {
    _engagement set ["pending",0];
    if (_now - (_engagement get "lastContactAt") >= (_combat get "contactTimeout")) then {
        [_engagement get "id","contact",_now] call IVCS_Combat_finish;
    } else {
        { if ((_x get "entityType") == "group") then { [_x,_now,_deferSearch] call IVCS_Ammo_updateGroup; }; } forEach _ammoGroups;
    };
};
_engagement set ["lastContactAt",_now];
private _steps = floor (_pending / _step) min (_combat get "stepsPerUpdate");
if (_stepLimit >= 0) then { _steps = _steps min _stepLimit; };
for "_i" from 1 to _steps do {
    if ((_engagement get "mode") == "finished") exitWith {};
    private _tick = _now - _pending + _step;
    private _shotsBefore = _engagement get "shots";
    private _transfersBefore = 0;
    { if ((_x get "entityType") == "group") then { _transfersBefore = _transfersBefore + (_x get "ammoTransfers"); }; } forEach _ammoGroups;
    [_engagement, _groups, _step,_tick] call IVCS_Combat_step;
    if ((_engagement get "mode") != "finished") then { { if ((_x get "entityType") == "group") then { [_x, _tick, _deferSearch] call IVCS_Ammo_updateGroup; }; } forEach _ammoGroups; };
    private _transfers = 0;
    { if ((_x get "entityType") == "group") then { _transfers = _transfers + (_x get "ammoTransfers"); }; } forEach _ammoGroups;
    if ((_engagement get "shots") > _shotsBefore || { _transfers > _transfersBefore }) then { _engagement set ["lastProgressAt",_tick]; };
    _pending = _pending - _step;
    if ((_engagement get "mode") != "finished" && { _tick - (_engagement get "lastProgressAt") >= (_combat get "ammoTimeout") }) then {
        private _requests = _ammoGroups findIf { (_x get "entityType") == "group" && { (_x get "ammoRequests") isNotEqualTo [] } } != -1;
        private _grace = if (_requests) then { private _sharing = _combat get "ammoSharing"; (_sharing get "virtualApproachDelay") + (_sharing get "collectionDelay") + (_combat get "reloadDelay") } else {0};
        if (_tick - (_engagement get "lastProgressAt") >= (_combat get "ammoTimeout") + _grace) then {
            private _vehicle = (_groups select 1) get "entityType" != "group";
            private _armed = if (_vehicle) then {
                if (_groups call IVCS_Combat_isHelicopterPair) then {_groups call IVCS_Combat_canFightHelicopter} else {_groups call IVCS_Combat_canFightVehicle}
            } else { _groups findIf { (_x get "units") findIf { ([_x] call IVCS_Combat_getShot) isNotEqualTo [] } != -1 } != -1 };
            if (!_armed && {_groups call IVCS_Combat_isHelicopterPair}) then {
                _armed=(_engagement get "supporters") findIf {private _support=[_x] call IVCS_VirtualSpace_getEntity;[_support,_groups select 1,true] call IVCS_Combat_canShootHelicopter} != -1;
            };
            if (_armed) then { _engagement set ["lastProgressAt",_tick]; } else { [_engagement get "id","ammunition",_now] call IVCS_Combat_finish; };
        };
    };
};
_engagement set ["pending", _pending];
