params ["_opcom","_pendingOrder"];

/*
    Here we determine if the order is possible
     - Either an "objectiveID" or "position" value
       must be provided
     - If no "assignedEntities" value is given,
       try to find entities to fulfill order
*/

private _orderType = _pendingOrder getvariable "type";
private _orderObjectiveID = _pendingOrder getvariable "objectiveID";
private _orderPosition = _pendingOrder getvariable "position";

if (isnil "_orderObjectiveID" && !isnil "_orderPosition") exitwith { [_opcom, _pendingOrder] call IVCS_OPCOM_denyPendingOrder };

scopename "main";

private _assignedEntities = _pendingOrder getvariable ["assignedEntities", []];
private _hasExistingEntities = !(_assignedEntities isequalto []);
private _orderConfirmed = false;
if (!_hasExistingEntities) then {
    // attempt to find entities to fulfill order

    switch (_orderType) do {
        case "garrison": {
            private _objective = [_opcom,_orderObjectiveID] call IVCS_OPCOM_getObjective;
            private _objectiveType = _objective getvariable "type";
            private _objectivePosition = _objective getvariable "position";

            private _garrisonGroupCounts = _opcom getvariable "garrisonGroupCounts";
            private _necessaryEntityCount = _garrisonGroupCounts getvariable [_objectiveType, _garrisonGroupCounts getvariable "default"];

            private _nearestEntities = [
                _opcom,
                _objectivePosition,
                _necessaryEntityCount,
                [
                    "group",
                    "car",
                    "truck",
                    "armored",
                    "tank"
                ]
            ] call IVCS_OPCOM_findNearestEntities;

            _pendingOrder setvariable ["assignedEntities", _nearestEntities apply {_x getvariable "id"}];

            if (count _nearestEntities < _necessaryEntityCount) then { breakto "main" };
        };
    };

    _orderConfirmed = true
};

if (_hasExistingEntities || _orderConfirmed) then {
    [_opcom, _pendingOrder] call IVCS_OPCOM_confirmPendingOrder;
} else {
    [_opcom, _pendingOrder] call IVCS_OPCOM_denyPendingOrder;
};