params ["_entityID","_waypointID"];

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "all";
private _entity = _allEntities get _entityID;

if (!isnil "_entity") then {
    private _wpCallbackToIgnore = _entity get "ignoreWpCallback";
    if (_waypointID != _wpCallbackToIgnore) then {
        if (_wpCallbackToIgnore != "") then {
            _entity set ["ignoreWpCallback", ""];
        };

        private _waypoints = _entity get "waypoints";
        {
            private _waypoint = _x;
            private _id = _waypoint get "name";
            if (_id == _waypointID) exitwith {
                // execute waypoint callbacks

                private _waypointStatements = _waypoint get "statements";
                {
                    [_entity, _waypoint] call (compile _x);
                } foreach _waypointStatements;

                // remove waypoint if not cycling

                private _minWaypoint = _entity get "minWaypoint";
                private _maxWaypoint = _entity get "maxWaypoint";

                if (_minWaypoint == _maxWaypoint) then {
                    [_entity,_waypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
                };

                // update current waypoint

                private _currentWaypoint = _entity get "currentWaypoint";
                private _minWaypoint = _entity get "minWaypoint";
                private _maxWaypoint = _entity get "maxWaypoint";
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

                _entity set ["currentWaypoint", _currentWaypoint];
                _entity set ["movePoints", []];
                _entity set ["currentWaypointPathGenerated", false];

                private _active = _entity get "active";
                if (!_active) then {
                    private _waypointType = _waypoint get "type";
                    if (_waypointType == "LAND") then {
                        private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
                        {
                            private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                            private _vehicleEntityPosition = _vehicleEntity get "position";
                            
                            _vehicleEntity set ["engineOn", false];
                            _vehicleEntityPosition set [2, 0.5];
                        } foreach _vehiclesInCommandOf;
                    };
                };
            };
        } foreach _waypoints;
    };
};