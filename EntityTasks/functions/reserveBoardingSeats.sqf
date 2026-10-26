// Used on genuine entry to boarding, including after an interrupted approach.
private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
if (isNil "_vehicle") exitWith { _this set ["boardingFailed", true]; };
private _units = _entity get "units";
private _vehicleID = _this get "vehicleID";
private _alreadyAssigned = _units findIf {
    private _assignment = _x get "vehicleAssignment";
    _assignment isEqualTo [] || { (_assignment select 0) != _vehicleID }
} == -1;
if (_alreadyAssigned) exitWith {};
private _unseated = [_entity] call IVCS_VirtualSpace_Group_getUnseatedUnits;
private _empty = [_vehicle, true] call IVCS_VirtualSpace_Vehicle_getEmptySeats;
private _capacity = 0;
{ _capacity = _capacity + count (_x select 1); } forEach _empty;
if (count _unseated != count _units || { _capacity < count _units }) exitWith {
    _this set ["boardingFailed", true];
};
if (_entity get "active" && { !(_vehicle get "active") }) then {
    [_vehicle] call IVCS_VirtualSpace_Vehicle_spawn;
};
_this set ["reservedVehicle", _vehicle];
_this set ["reservedUnits", _unseated];
_this set ["cargoLinks", _entity get "vehiclesInCargoOf"];
if (_entity get "active" && { _entity getOrDefault ["movementStopped", false] }) then {
    private _group = _entity get "group";
    (units _group) doFollow (leader _group);
    _entity set ["movementStopped", false];
};
[_entity, _vehicle] call IVCS_VirtualSpace_Group_assignAsVehicleCargo;
