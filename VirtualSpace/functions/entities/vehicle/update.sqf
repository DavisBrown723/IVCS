params ["_entity", "_deltaTime"];
if (_entity get "simulationTransition") exitWith {};

private _uncrewedHelicopter = !(_entity get "active") && {(_entity get "vehicleType")=="helicopter"} && {(_entity get "commandingEntity")==""};
if (_uncrewedHelicopter) then {
    [createHashMap,_entity,_deltaTime] call IVCS_Combat_updateHelicopter;
};
if (_uncrewedHelicopter && {isNil {[_entity get "id"] call IVCS_VirtualSpace_getEntity}}) exitWith {};
[_entity] call IVCS_Combat_findTarget;

if (_entity get "active") then {
    [_entity, getPos (_entity get "object")] call IVCS_VirtualSpace_setEntityPosition;
} else {
    private _commandingID = _entity get "commandingEntity";
    if (_commandingID != "") then {
        private _commander = [_commandingID] call IVCS_VirtualSpace_getEntity;
        private _position = +(_commander get "position");
        _position set [2, (_entity get "position") select 2];
        if ((_entity get "vehicleType")=="helicopter" && {!(_entity get "airMovementOverride")} && {_deltaTime>0}) then {
            private _delta = _position vectorDiff (_entity get "position");
            _entity set ["flightVelocity",_delta vectorMultiply (1/_deltaTime)];
            if (vectorMagnitude _delta>0.01) then {_entity set ["flightHeading",(_entity get "position") getDir _position]};
        };
        [_entity, _position] call IVCS_VirtualSpace_setEntityPosition;
    };
};

// Update virtual passengers in the same tick, even if they simulated first.
{
    private _cargoEntity = [_x] call IVCS_VirtualSpace_getEntity;
    if !(_cargoEntity get "active") then {
        [_cargoEntity, +(_entity get "position")] call IVCS_VirtualSpace_setEntityPosition;
    };
} forEach (_entity get "entitiesInCargo");

if (IVCS_VirtualSpace_Controller get "debug") then {
    (_entity get "debugMarker") setMarkerPos (_entity get "position");
};
