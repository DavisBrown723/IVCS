/*
    MOVE context: destination [x,y,z], completionRadius, speed.
    Uses the same waypoint completion callback for spawned and virtual groups.
    Virtual waypoint completion uses a minimum 7 m radius; smaller radii are not enforced.
*/
[
    "MOVE",
    [
        ["moving", [
            ["onEnter", {
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                private _destination = _this getOrDefault ["destination", []];
                if (isNil "_entity" || { count _destination < 2 }) exitWith {
                    _this set ["moveFailed", true];
                };
                private _radius = _this get "completionRadius";
                if ((_entity get "position") distance2D _destination <= _radius) exitWith {
                    _this set ["waypointComplete", true];
                };

                [_this, _destination, "MOVE", _radius] call IVCS_EntityTasks_addWaypoint;
            }],
            ["onUpdate", {
                if (_this get "moveFailed") exitWith { "failed" };
                if (_this get "waypointComplete") exitWith { "completed" };
                private _ownedWaypoints = _this get "waypoints";
                if (_ownedWaypoints findIf { _x getOrDefault ["pathFailed", false] } != -1) exitWith {
                    "failed"
                };
                ""
            }]
        ]],
        ["completed", [["isEndState", true]]],
        ["failed", [["isEndState", true], ["result", "failed"]]]
    ],
    "moving",
    [
        ["completionRadius", 7],
        ["speed", "UNCHANGED"],
        ["waypointComplete", false],
        ["moveFailed", false]
    ]
] call IVCS_EntityTasks_createTaskTemplate;
