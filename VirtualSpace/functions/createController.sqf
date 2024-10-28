params [
    ["_debug", false]
];

private _activeEntityIDs = [];
private _inactiveEntityIDs = [];

private _virtualGroups = createHashMapFromArray [
    ["all", createHashMap],
    ["EAST", []],
    ["WEST", []],
    ["GUER", []],
    ["active", _activeEntityIDs],
    ["inactive", _inactiveEntityIDs]
];

private _mapOverlap = 4000;
private _gridOrigin = [-_mapOverlap, -_mapOverlap];
private _entitiesSpacialGrid = [_gridOrigin, worldSize + (2 * _mapOverlap), 600] call IVCS_SpacialGrid_create;

private _controller = createHashMapFromArray [
   ["debug", _debug],
    ["entities", _virtualGroups],
    ["nextEntityID", 0],
    ["entitiesToSimulate", []],
    ["simulationChunkSize", 10],
    ["nextWaypointId", 0],
    ["entitiesSpacialGrid", _entitiesSpacialGrid]
];

private _spawnerFSM = [_activeEntityIDs,_inactiveEntityIDs] call IVCS_VirtualSpace_createEntitySpawnerFSM;
_controller set ["spawnerFSM", _spawnerFSM];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_VirtualSpace_onFrame];
_controller set ["onFrameHandlerID", _frameEventHandler];

IVCS_VirtualSpace_KnownEntityInfo = createHashMapFromArray [
    ["EAST", createHashMap],
    ["WEST", createHashMap],
    ["GUER", createHashMap]
];

IVCS_VirtualSpace_KnownEntityInfo_TimeLastUpdate = diag_tickTime;

_controller