// 0 foot, 1 FFV, 2 can dismount, 3 FFV plus dismount, 4 enclosed/airborne.
params ["_unit"];
private _assignment = _unit get "vehicleAssignment";
if (_assignment isEqualTo []) exitWith { 0 };
private _vehicle = [_assignment select 0] call IVCS_VirtualSpace_getEntity;
if (isNil "_vehicle") exitWith { 4 };
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _path = (_assignment select 1) select 0;
private _ffv = _path isEqualType [] && { (_profile get "personTurrets") getOrDefault [str _path,false] };
private _position = _vehicle get "position";
private _land = (_position param [2,0]) < 3 && { !surfaceIsWater _position };
private _dismount = ((IVCS_VirtualSpace_Controller get "combat") get "autoDismount") && { _land };
if (_ffv) then { if (_dismount) then {3} else {1} } else { if (_dismount) then {2} else {4} }
