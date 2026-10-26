/*
    Helicopter landing at landingPosition. LAND touches down; GET IN/GET OUT
    request the corresponding low-hover mode. Pads belong to this task.
*/
[
    "LAND",
    [
        ["landing", [
            ["onEnter", {
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                private _vehicles = (_entity get "vehiclesInCommandOf") apply { [_x] call IVCS_VirtualSpace_getEntity };
                private _index = _vehicles findIf { !isNil "_x" && { (_x get "vehicleType") == "helicopter" } };
                private _position = _this getOrDefault ["landingPosition", []];
                if (_index == -1 || { count _position < 2 } || { !((_this get "landingType") in ["LAND", "GET IN", "GET OUT"]) }) exitWith {
                    _this set ["landingFailed", true];
                };
                private _vehicle = _vehicles select _index;
                _this set ["vehicleID", _vehicle get "id"];
                _this set ["startedAt", IVCS_SimulationTime];
                if ((_vehicle get "position") distance2D _position <= 25 && { ((_vehicle get "position") select 2) < 4 }) exitWith {
                    _this set ["waypointComplete", true];
                };
                [_this, _position, "LAND", 25, [
                    ["scripted", false], ["landingType", _this get "landingType"]
                ]] call IVCS_EntityTasks_addWaypoint;
            }],
            ["onUpdate", {
                if (_this get "landingFailed") exitWith { "failed" };
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (IVCS_SimulationTime - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                if ((_this get "waypoints") findIf { _x getOrDefault ["pathFailed", false] } != -1) exitWith { "failed" };
                private _position = _vehicle get "position";
                private _native = _vehicle get "active";
                if (_native) then {
                    private _object = _vehicle get "object";
                    if (!alive _object || { !canMove _object }) exitWith { _this set ["landingFailed", true]; "failed" };
                    _position = getPosATL _object;
                    if (isNull (_this get "helipad") && { !(_this get "waypointComplete") || { (_position select 2) >= 4 } }) then {
                        _this set ["helipad", createVehicle ["Land_HelipadEmpty_F", _this get "landingPosition", [], 0, "NONE"]];
                    };
                    // Helicopters can complete a MOVE waypoint before reaching
                    // the pad. Keep the approach order until the actual landing area.
                    if ((_this get "approachObject") isNotEqualTo _object || {
                        unitReady _object && { (_this get "landingObject") isNotEqualTo _object } &&
                        { _position distance2D (_this get "landingPosition") > 25 }
                    }) then {
                        // A priority landing may have left the helicopter grounded.
                        // Release that landing order before resuming this approach.
                        _object land "NONE";
                        _object engineOn true;
                        _object doMove (_this get "landingPosition");
                        _this set ["approachObject", _object];
                    };
                    if (_position distance2D (_this get "landingPosition") <= 25 && { (_this get "landingObject") isNotEqualTo _object }) then {
                        _object land (_this get "landingType");
                        _this set ["landingObject", _object];
                    };
                } else {
                    if (!isNull (_this get "helipad")) then {
                        deleteVehicle (_this get "helipad");
                        _this set ["helipad", objNull];
                    };
                    _this set ["approachObject", objNull];
                    _this set ["landingObject", objNull];
                    // Native waypoint completion can precede touchdown. After
                    // despawn, restore a virtual LAND waypoint to finish the trip.
                    if (_this get "waypointComplete" && {
                        _position distance2D (_this get "landingPosition") > 25 ||
                        { (_position select 2) >= 4 }
                    }) then {
                        (_this get "waypoints") resize 0;
                        [_this, _this get "landingPosition", "LAND", 25, [
                            ["scripted", false], ["landingType", _this get "landingType"]
                        ]] call IVCS_EntityTasks_addWaypoint;
                    };
                };
                if (_this get "landingFailed") exitWith { "failed" };
                private _landed = (_position select 2) < 4;
                if (_native && { (_this get "landingType") == "LAND" }) then {
                    _landed = isTouchingGround (_vehicle get "object");
                };
                if (_position distance2D (_this get "landingPosition") <= 25 && { _landed }) exitWith { "completed" };
                ""
            }]
        ]],
        ["completed", [["isEndState", true]]],
        ["failed", [["isEndState", true], ["result", "failed"]]]
    ],
    "landing",
    [
        ["landingType", "LAND"], ["timeout", 180], ["startedAt", -1],
        ["landingFailed", false], ["waypointComplete", false],
        ["helipad", objNull], ["approachObject", objNull], ["landingObject", objNull]
    ],
    {
        _this call IVCS_EntityTasks_releaseLanding;
    },
    {},
    { _this call IVCS_EntityTasks_releaseLanding; }
] call IVCS_EntityTasks_createTaskTemplate;
