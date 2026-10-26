// Area belongs to the active order, not whichever enemy was acquired first.
params ["_helicopter",["_wp",[]]];
if (count _this<2) then {
    private _crew=[_helicopter get "commandingEntity"] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_crew") then {_wp=[_crew] call IVCS_VirtualSpace_getEntityCurrentWaypoint};
};
if (isNil "_wp" || {_wp isEqualTo []}) exitWith {[]};
private _center=_wp get "airAttackCenter";
if (_center isEqualTo []) then {_center=_wp get "position"};
private _radius=_wp get "airAttackRadius";
if (_radius<0) then {_radius=(IVCS_VirtualSpace_Controller get "combat") get "helicopterAttackRadius"};
[_center,_radius,_wp get "name"]
