private _pathGenerator = [] call CBA_fnc_createNamespace;

// create props for path generation

private _agentMan = createAgent ["C_man_1", [0,0,0], [], 0, "NONE"]; 
private _motorizedProp = "C_Offroad_01_F" createVehicle [0,0,0];
private _mechanizedProp = "B_APC_Tracked_01_rcws_F" createVehicle [0,0,0];
private _armoredProp = "B_MBT_01_cannon_F" createVehicle [0,0,0];
private _boatProp = "C_Rubberboat" createVehicle [0,0,0];

_agentMan hideobjectglobal true;
_agentMan setvariable ["IVCS_Paths_manProp", true];
_agentMan addEventHandler ["PathCalculated", IVCS_Paths_onPathGenerated];

_motorizedProp hideobjectglobal true;
_mechanizedProp hideobjectglobal true;
_armoredProp hideobjectglobal true;
_boatProp hideobjectglobal true;

private _unitTypes = [] call CBA_fnc_createNamespace;
_unitTypes setvariable ["man", _agentMan];
_unitTypes setvariable ["car", _motorizedProp];
_unitTypes setvariable ["truck", _motorizedProp];
_unitTypes setvariable ["armored", _mechanizedProp];
_unitTypes setvariable ["antiair", _mechanizedProp];
_unitTypes setvariable ["tank", _armoredProp];
_unitTypes setvariable ["artillery", _armoredProp];
_unitTypes setvariable ["ship", _boatProp];

_pathGenerator setvariable ["props", _unitTypes];

_pathGenerator setvariable ["requestQueue", []];
_pathGenerator setvariable ["currentRequest", []];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Paths_onFrame];
_pathGenerator setvariable ["onFrameHandlerID", _frameEventHandler];

_pathGenerator