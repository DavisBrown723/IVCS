params ["_entity"];

private _assignedVehicles = _entity getvariable "assignedVehicles";
if (_assignedVehicles isequalto []) exitwith {
    "man";
};

// pick most-strict pathfinding strategy

private _vehicleTypes = _assignedVehicles apply {
    private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
    private _vehicleType = _vehicleEntity getvariable "vehicleType";
    _vehicleType
};

private _strategyOrder = ["tank","artillery","armored","antiair","car","truck","ship"];
private _strategy = {
    if (_vehicleTypes find _x != -1) exitwith {
        _x
    };
} foreach _strategyOrder;

_entity setvariable ["pathfindingStrategy", _strategy];

_strategy