params ["_opcom","_scanResult"];

_scanResult params ["_objectiveID","_nearEntities", "_state"];
_nearEntities params ["_nearFriendlies", "_nearEnemies"];

private _objectives = _opcom getvariable "objectives";
private _objective = _objectives getvariable _objectiveID;

if (isnil "_objective") exitwith {};

switch (_state) do {
    case "friendly": {
        if (!isnil "_objective") then {
            private _objectiveGarrisonOrders = [_opcom, _objective, "garrison"] call IVCS_OPCOM_objectiveGetOrdersOfType;
            if (_objectiveGarrisonOrders isequalto []) then {
                private _order = ["garrison"] call IVCS_OPCOM_createOrder;
                _order setvariable ["objectiveID", _objectiveID];

                [_opcom, _order] call IVCS_OPCOM_addPendingOrder;
            }
        };
    };
    case "contested": {

    };
    case "unknown": {

    };
};

_objective setvariable ["controlState", _state];