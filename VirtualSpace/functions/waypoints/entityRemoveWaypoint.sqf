// keepOrder is used only by task suspension; normal removal forgets the order.
params ["_entity", "_entityWaypoint", ["_keepOrder", false]];
if (!_keepOrder) then {
    private _task = [_entity, _entityWaypoint getOrDefault ["taskID", ""]] call IVCS_VirtualSpace_getEntityTask;
    if (!isNil "_task") then {
        private _owned = _task get "waypoints";
        private _ownedIndex = _owned find _entityWaypoint;
        if (_ownedIndex != -1) then {
            _owned deleteAt _ownedIndex;
            if ((_task getOrDefault ["resumeWaypoint", ""]) == (_entityWaypoint get "name")) then {
                _task set ["resumeWaypoint", if (_owned isEqualTo []) then { "" } else {
                    (_owned select (_ownedIndex min (count _owned - 1))) get "name"
                }];
            };
        };
    };
};
private _waypoints = _entity get "waypoints";
private _index = _waypoints find _entityWaypoint;
if (_index == -1) exitWith {};
_waypoints deleteAt _index;
_entityWaypoint deleteAt "entity";
_entityWaypoint set ["nativeGeneration", (_entityWaypoint get "nativeGeneration") + 1];
private _deferred = _entity get "combatWaypointCompletions";
private _deferredIndex = _deferred find (_entityWaypoint get "name");
if (_deferredIndex != -1) then { _deferred deleteAt _deferredIndex; };
[_entityWaypoint] call IVCS_VirtualSpace_resetEntityWaypoint;

private _currentIndex = _entity get "currentWaypointIndex";
if (_index < _currentIndex) then { _currentIndex = _currentIndex - 1; };
_entity set ["currentWaypointIndex", _currentIndex min (count _waypoints - 1)];
[_entity] call IVCS_VirtualSpace_determineCycleWaypointLoop;
if (_entity get "active") then { deleteWaypoint [_entity get "group", _index]; };
