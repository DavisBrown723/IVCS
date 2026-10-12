/*
    Board all units into available non-driver seats. Optional rendezvous first.
    Spawned completion requires actual occupants, not merely seat reservations.
*/
[
    "GET IN",
    [
        ["start", [
            ["onEnter", { _this set ["startedAt", time]; }],
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
                if (time - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
                if ((_this get "waypoints") findIf { _x getOrDefault ["pathFailed", false] } != -1) exitWith { "failed" };
                if (_this get "waypointComplete") then { "waiting" } else { "" }
            }]
        ]],
        ["waiting", [
            ["onUpdate", {
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (time - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
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
                if (time - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
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
                    { [_entity, _x] call IVCS_VirtualSpace_entityRemoveWaypoint; } forEach _owned;
                    _owned resize 0;
                    [_this, _position] call IVCS_EntityTasks_addWaypoint;
                };
                ""
            }]
        ]],
        ["boarding", [
            ["onEnter", {
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
            }],
            ["onUpdate", {
                if (_this get "boardingFailed") exitWith { "failed" };
                private _vehicle = [_this get "vehicleID"] call IVCS_VirtualSpace_getEntity;
                if (isNil "_vehicle") exitWith { "failed" };
                if (time - (_this get "startedAt") > (_this get "timeout")) exitWith { "failed" };
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
        if (!isNull (_this get "smoke")) then { deleteVehicle (_this get "smoke"); };
        _this set ["smoke", objNull];
        if ((_this get "result") != "completed") then {
            private _reserved = _this get "reservedUnits";
            private _vehicle = _this get "reservedVehicle";
            if (_reserved isNotEqualTo []) then {
                private _vehicleID = _this get "vehicleID";
                private _unitsToRelease = [];
                {
                    private _assignment = _x get "vehicleAssignment";
                    if (_assignment isNotEqualTo [] && { (_assignment select 0) == _vehicleID }) then {
                        (_assignment select 1) set [1, ""];
                        _x set ["vehicleAssignment", []];
                        private _object = _x get "object";
                        if (!isNull _object && { alive _object }) then { _unitsToRelease pushBack _object; };
                    };
                } forEach _reserved;
                private _links = _this get "cargoLinks";
                private _index = _links find _vehicleID;
                if (_index != -1) then { _links deleteAt _index; };
                private _cargo = _vehicle get "entitiesInCargo";
                _index = _cargo find (_this get "entityID");
                if (_index != -1) then { _cargo deleteAt _index; };
                {
                    unassignVehicle _x;
                    [_x] orderGetIn false;
                    if (vehicle _x == (_vehicle get "object")) then { moveOut _x; };
                } forEach _unitsToRelease;
            };
        };
        (_this get "reservedUnits") resize 0;
        _this set ["reservedVehicle", createHashMap];
        _this set ["cargoLinks", []];
    }
] call IVCS_EntityTasks_createTaskTemplate;
