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
                        _currentWaypoint = -1;
                    };
                };

                _entity setvariable ["currentWaypoint", _currentWaypoint];
            };
        } foreach _waypoints;

    };
};