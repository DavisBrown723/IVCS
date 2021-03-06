params ["_entityID","_waypointID"];

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";
private _entity = _allEntities getvariable _entityID;

if (!isnil "_entity") then {
    private _wpCallbackToIgnore = _entity getvariable "ignoreWpCallback";
    if (_waypointID != _wpCallbackToIgnore) then {
        if (_wpCallbackToIgnore != "") then {
            _entity setvariable ["ignoreWpCallback", ""];
        };

        private _waypoints = _entity getvariable "waypoints";
        {
            private _waypoint = _x;
            private _id = _waypoint getvariable "name";
            if (_id == _waypointID) exitwith {
                // execute waypoint callbacks

                private _waypointStatements = _waypoint getvariable "statements";
                {
                    [_entity, _waypoint] call (compile _x);
                } foreach _waypointStatements;

                // remove waypoint if not cycling

                private _minWaypoint = _entity getvariable "minWaypoint";
                private _maxWaypoint = _entity getvariable "maxWaypoint";

                if (_minWaypoint == _maxWaypoint) then {
                    [_entity,_waypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
                };

                // update current waypoint

                private _currentWaypoint = _entity getvariable "currentWaypoint";
                private _minWaypoint = _entity getvariable "minWaypoint";
                private _maxWaypoint = _entity getvariable "maxWaypoint";
                if (_minWaypoint != _maxWaypoint) then {
                    // there is a cycle waypoint
                    if (_currentWaypoint == _maxWaypoint) then {
                        _currentWaypoint = _minWaypoint;
                    } else {
                        _currentWaypoint = _currentWaypoint + 1;
                    };
                } else {
                    _currentWaypoint = _currentWaypoint + 1;
                    if (_currentWaypoint >= count _waypoints) then {
                        _currentWaypoint = 0;
                    };
                };

                _entity setvariable ["currentWaypoint", _currentWaypoint];
                _entity setvariable ["movePoints", []];
                _entity setvariable ["currentWaypointPathGenerated", false];

                private _active = _entity getvariable "active";
                if (!_active) then {
                    private _waypointType = _waypoint getvariable "type";
                    if (_waypointType == "LAND") then {
                        private _vehiclesInCommandOf = _entity getvariable "vehiclesInCommandOf";
                        {
                            private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                            private _vehicleEntityPosition = _vehicleEntity getvariable "position";
                            
                            _vehicleEntity setvariable ["engineOn", false];
                            _vehicleEntityPosition set [2, 0.5];
                        } foreach _vehiclesInCommandOf;
                    };
                };
            };
        } foreach _waypoints;
    };
};