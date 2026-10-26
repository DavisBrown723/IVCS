/*
    Board all units into available non-driver seats. Optional rendezvous first.
    Spawned completion requires actual occupants, not merely seat reservations.
*/
[
    "GET IN",
    [
        ["start", [
            ["onEnter", { _this set ["startedAt", IVCS_SimulationTime]; }],
            ["onUpdate", {
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle" || { !((_vehicle get "entityType") in ["vehicle", "uav"]) }) exitWith { "failed" };
                if (count (_this get "rendezvousPoint") >= 2) then { "rendezvous" } else { "approaching" }
            }]
        ]],
        ["rendezvous", [
            ["onEnter", {
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                private _rendezvous = _this get "rendezvousPoint";
                private _position = _rendezvous getPos [30, _rendezvous getDir (_entity get "position")];
                _position set [2, 0];
                [_this, _position] call IVCS_EntityTasks_addWaypoint;
            }],
            ["onUpdate", {
                if (isNil { [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity }) exitWith { "failed" };
                if (IVCS_SimulationTime - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                if ((_this get "waypoints") findIf { _x getOrDefault ["pathFailed", false] } != -1) exitWith { "failed" };
                if (_this get "waypointComplete") then { "waiting" } else { "" }
            }]
        ]],
        ["waiting", [
            ["onUpdate", {
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (IVCS_SimulationTime - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                private _position = _vehicle get "position";
                if (_vehicle get "active") then {
                    private _object = _vehicle get "object";
                    if (!alive _object) exitWith { _this set ["boardingFailed", true]; };
                    _position = getPosATL _object;
                };
                if (_this get "boardingFailed") exitWith { "failed" };
                private _distance = _position distance2D (_this get "rendezvousPoint");
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                if (_distance < 200 && { _entity get "active" } && { !(_this get "signalSent") }) then {
                    _this set ["smoke", createVehicle ["SmokeShellGreen", _this get "rendezvousPoint", [], 0, "NONE"]];
                    _this set ["signalSent", true];
                };
                if (_distance <= 30 && { (_position select 2) < 4 }) then { "approaching" } else { "" }
            }]
        ]],
        ["approaching", [
            ["onUpdate", {
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (IVCS_SimulationTime - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                private _position = +(_vehicle get "position");
                if (_vehicle get "active") then {
                    private _object = _vehicle get "object";
                    if (!alive _object) exitWith { _this set ["boardingFailed", true]; };
                    _position = getPosATL _object;
                };
                if (_this get "boardingFailed") exitWith { "failed" };
                private _range = if (_entity get "active") then { 20 } else { 7 };
                if ((_entity get "position") distance2D _position <= _range && { (_position select 2) < 4 }) exitWith { "boarding" };
                _position set [2, 0];
                private _owned = _this get "waypoints";
                private _last = if (_owned isEqualTo []) then { createHashMap } else { _owned select (count _owned - 1) };
                if (_last getOrDefault ["pathFailed", false]) exitWith { "failed" };
                if (_owned isEqualTo [] || { _this get "waypointComplete" } || { (_last get "position") distance2D _position > 10 }) then {
                    { [_entity, _x] call IVCS_VirtualSpace_entityRemoveWaypoint; } forEach (_owned select [0]);
                    _owned resize 0;
                    [_this, _position] call IVCS_EntityTasks_addWaypoint;
                };
                ""
            }]
        ]],
        ["boarding", [
            ["onEnter", {
                _this call IVCS_EntityTasks_reserveBoardingSeats;
            }],
            ["onUpdate", {
                if (_this get "boardingFailed") exitWith { "failed" };
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (IVCS_SimulationTime - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
                private _units = _entity get "units";
                private _object = _vehicle get "object";
                if (_vehicle get "active" && { !alive _object }) exitWith { "failed" };
                private _vehicleID = _this get "vehicleID";
                private _missing = _units findIf {
                    private _assignment = _x get "vehicleAssignment";
                    _assignment isEqualTo [] || { (_assignment select 0) != _vehicleID } ||
                    { (_entity get "active") && { vehicle (_x get "object") != _object } }
                };
                if (_missing == -1) then { "completed" } else { "" }
            }]
        ]],
        ["completed", [["isEndState", true]]],
        ["failed", [["isEndState", true], ["result", "failed"]]]
    ],
    "start",
    [
        ["vehicleID", ""], ["rendezvousPoint", []], ["timeout", 300], ["startedAt", -1],
        ["waypointComplete", false], ["boardingFailed", false],
        ["reservedVehicle", createHashMap], ["reservedUnits", []], ["cargoLinks", []],
        ["smoke", objNull], ["signalSent", false]
    ],
    {
        _this call IVCS_EntityTasks_releaseBoarding;
    },
    {
        if (_this getOrDefault ["boardingSuspended", false]) then {
            private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
            private _task = [_entity, _this get "taskID"] call IVCS_VirtualSpace_getEntityTask;
            // The group may have moved away. Approach again before reserving seats.
            _task set ["currentState", "approaching"];
            _task set ["stateEntered", false];
            _this set ["boardingSuspended", false];
        };
    },
    {
        private _entity = [_this get "entityID"] call IVCS_VirtualSpace_getEntity;
        if (!isNil "_entity") then {
            private _task = [_entity, _this get "taskID"] call IVCS_VirtualSpace_getEntityTask;
            if (!isNil "_task" && { (_task get "currentState") == "boarding" }) then {
                _this set ["boardingSuspended", true];
            };
        };
        _this call IVCS_EntityTasks_releaseBoarding;
    }
] call IVCS_EntityTasks_createTaskTemplate;
