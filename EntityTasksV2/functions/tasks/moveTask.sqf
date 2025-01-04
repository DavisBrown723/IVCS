// context: entity, destination, waypointParams

[
    "MOVE",
    10,
    [
        ["createWaypoint", [
            ["onUpdate", {
                private _entity = _this get "entity";
                private _destination = _this get "destination";
                private _waypointParams = _this get "waypointParams";
                
                private _waypoint = [_destination,"MOVE", _waypointParams] call IVCS_VirtualSpace_createEntityWaypoint;
                [_entity,_waypoint] call IVCS_VirtualSpace_addEntityWaypoint;

                _this set ["waypoint", _waypoint];

                "checkCompletion"
            }]
        ]],
        ["checkCompletion", [
            ["onUpdate", {
                
            }]
        ]]
    ],
    "start"
] call IVCS_EntityTasks_createTaskTemplate