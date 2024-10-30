params ["_entityID","_waypointID"];

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";
private _entity = _allEntities get _entityID;

if (!isnil "_entity") then {
    private _wpCallbackToIgnore = _entity get "ignoreWpCallback";
    if (_waypointID != _wpCallbackToIgnore) then {
        if (_wpCallbackToIgnore != "") then {
            _entity set ["ignoreWpCallback", ""];
        };

        private _waypoint = [_entity,_waypointID] call IVCS_VirtualSpace_getEntityWaypoint;
        if (!isnil "_waypoint") then {
            private _waypointType = _waypoint get "type";
            
            if (_waypointType != "CYCLE") then {
                [_waypoint] call IVCS_VirtualSpace_resetEntityWaypoint;

                // execute waypoint callbacks

                private _waypointStatements = _waypoint get "statements";
                {
                    [_entity, _waypoint] call (compile _x);
                } foreach _waypointStatements;

                // remove waypoint if not cycling

                private _minWaypointIndex = _entity get "minWaypointIndex";
                private _maxWaypointIndex = _entity get "maxWaypointIndex";

                if (_minWaypointIndex == -1) then {
                    [_entity,_waypoint] call IVCS_VirtualSpace_entityRemoveWaypoint;
                };

                // update current waypoint index

                private _waypoints = _entity get "waypoints";
                private _currentWaypointIndex = _entity get "currentWaypointIndex";
                if (_minWaypointIndex == -1) then {
                    //_currentWaypointIndex = _currentWaypointIndex + 1;
                    if (_currentWaypointIndex >= count _waypoints) then {
                        _currentWaypointIndex = 0;
                    };
                } else {
                    // there is a cycle waypoint
                    if (_currentWaypointIndex == _maxWaypointIndex) then {
                        _currentWaypointIndex = _minWaypointIndex;
                    } else {
                        _currentWaypointIndex = _currentWaypointIndex + 1;
                    };
                };

                _entity set ["currentWaypointIndex", _currentWaypointIndex];

                // waypoint-type specific updates

                switch (_waypointType) do {
                    case "LAND": {
                        private _active = _entity get "active";
                        if (!_active && { _waypoints isequalto [] }) then {
                            private _vehiclesInCommandOf = _entity get "vehiclesInCommandOf";
                            {
                                private _vehicleEntity = [_x] call IVCS_VirtualSpace_getEntity;
                                private _vehicleEntityPosition = _vehicleEntity get "position";
                                
                                _vehicleEntity set ["engineOn", false];
                                _vehicleEntityPosition set [2, 0.2];
                            } foreach _vehiclesInCommandOf;
                        };
                    };
                };
            };
        };
    };
};