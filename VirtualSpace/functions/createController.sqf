params [
    ["_debug", false]
];

private _controller = [] call CBA_fnc_createNamespace;
private _activeEntityIDs = [];
private _inactiveEntityIDs = [];

private _virtualGroups = [] call CBA_fnc_createNamespace;
_virtualGroups setvariable ["all", [] call CBA_fnc_createNamespace];
_virtualGroups setvariable ["EAST", []];
_virtualGroups setvariable ["WEST", []];
_virtualGroups setvariable ["GUER", []];
_virtualGroups setvariable ["active", _activeEntityIDs];
_virtualGroups setvariable ["inactive", _inactiveEntityIDs];

private _mapOverlap = 4000;
private _gridOrigin = [-_mapOverlap, -_mapOverlap];
private _entitiesSpacialGrid = [_gridOrigin, worldSize + (2 * _mapOverlap), 600] call IVCS_SpacialGrid_create;

_controller setvariable ["debug", _debug];
_controller setvariable ["entities", _virtualGroups];
_controller setvariable ["nextEntityID", 0];
_controller setvariable ["entitiesToSimulate", []];
_controller setvariable ["simulationChunkSize", 10];
_controller setvariable ["nextWaypointId", 0];
_controller setvariable ["entitiesSpacialGrid", _entitiesSpacialGrid];

private _spawnerFSM = [_activeEntityIDs,_inactiveEntityIDs] call IVCS_VirtualSpace_createEntitySpawnerFSM;
_controller setvariable ["spawnerFSM", _spawnerFSM];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_VirtualSpace_onFrame];
_controller setvariable ["onFrameHandlerID", _frameEventHandler];

IVCS_VirtualSpace_KnownEntityInfo = [] call CBA_fnc_createNamespace;
IVCS_VirtualSpace_KnownEntityInfo setvariable ["EAST", [] call CBA_fnc_createNamespace];
IVCS_VirtualSpace_KnownEntityInfo setvariable ["WEST", [] call CBA_fnc_createNamespace];
IVCS_VirtualSpace_KnownEntityInfo setvariable ["GUER", [] call CBA_fnc_createNamespace];

IVCS_VirtualSpace_KnownEntityInfo_TimeLastUpdate = diag_tickTime;

_controller