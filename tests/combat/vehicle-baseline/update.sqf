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
if (!([_groups select 0, _groups select 1] call IVCS_Combat_canSee)) exitWith { _engagement set ["pending", 0]; };
private _steps = floor (_pending / _step) min (_combat get "stepsPerUpdate");
if (_stepLimit >= 0) then { _steps = _steps min _stepLimit; };
for "_i" from 1 to _steps do {
    if ((_engagement get "mode") == "finished") exitWith {};
    private _tick = _now - _pending + _step;
    [_engagement, _groups, _step] call IVCS_Combat_step;
    if ((_engagement get "mode") != "finished") then { { if ((_x get "entityType") == "group") then { [_x, _tick, _deferSearch] call IVCS_Ammo_updateGroup; }; } forEach _groups; };
    _pending = _pending - _step;
};
_engagement set ["pending", _pending];
