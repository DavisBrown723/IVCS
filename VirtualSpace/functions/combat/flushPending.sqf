// Resolve recorded virtual time before either participant creates native objects.
params ["_entity"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _engagement = (_combat get "engagements") get (_entity get "combatID");
if ((_engagement get "mode") != "virtual") exitWith {};
private _groups = (_engagement get "groups") apply { [_x] call IVCS_VirtualSpace_getEntity };
if (_groups findIf { isNil "_x" || { _x get "active" } || { _x get "simulationTransition" } } != -1) exitWith {};
private _now = _engagement get "lastUpdate";
private _step = _combat get "step";
while { (_engagement get "mode") == "virtual" && { (_engagement get "pending") >= _step } } do {
    [_engagement,_now] call IVCS_Combat_update;
};
private _pending = _engagement get "pending";
if ((_engagement get "mode") == "virtual" && { _pending > 0 } && {
    _groups call IVCS_Combat_isPair
} && { [_engagement,_groups] call IVCS_Combat_hasCombatContact }) then {
    [_engagement,_groups,_pending,_now] call IVCS_Combat_step;
    if ((_engagement get "mode") != "finished") then { { if ((_x get "entityType") == "group") then { [_x,_now,false] call IVCS_Ammo_updateGroup; }; } forEach _groups; };
};
_engagement set ["pending",0];
