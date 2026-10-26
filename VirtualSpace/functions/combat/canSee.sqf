params ["_a", "_b"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _aPos = _a get "position";
private _bPos = _b get "position";
// Keep the established infantry map-range policy; altitude matters for vehicle/air targets.
private _range = if ((_a get "entityType") == "group" && {(_b get "entityType") == "group"}) then {_aPos distance2D _bPos} else {_aPos distance _bPos};
private _maximum = if ((_a get "vehicleType")=="helicopter" || {(_b get "vehicleType")=="helicopter"}) then {
    _combat get (if ((_a get "entityType")=="group" || {(_b get "entityType")=="group"}) then {"helicopterInfantryRange"} else {"helicopterVehicleRange"})
} else {_combat get "range"};
if (_range > _maximum) exitWith { false };
private _height = _combat get "eyeHeight";
private _aEye = AGLToASL [_aPos select 0, _aPos select 1, (_aPos param [2, 0]) + _height];
private _bEye = AGLToASL [_bPos select 0, _bPos select 1, (_bPos param [2, 0]) + _height];
!terrainIntersectASL [_aEye, _bEye]
