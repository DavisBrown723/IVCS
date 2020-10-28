params [
    ["_debug", false]
];

private _controller = [] call CBA_fnc_createNamespace;

private _virtualGroups = [] call CBA_fnc_createNamespace;
_virtualGroups setvariable ["all", [] call CBA_fnc_createNamespace];

_controller setvariable ["debug", _debug];
_controller setvariable ["entities", _virtualGroups];
_controller setvariable ["nextEntityID", 0];
_controller setvariable ["entitiesToSimulate", []];
_controller setvariable ["simulationChunkSize", 3];
_controller setvariable ["nextWaypointId", 0];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_VirtualSpace_onFrame];
_controller setvariable ["onFrameHandlerID", _frameEventHandler];

_controller