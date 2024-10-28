private _pathGenerator = createHashMap;

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

private _unitTypes = createHashMapFromArray [
	["man", _agentMan],
	["car", _motorizedProp],
	["truck", _motorizedProp],
	["armored", _mechanizedProp],
	["antiair", _mechanizedProp],
	["tank", _armoredProp],
	["artillery", _armoredProp],
	["ship", _boatProp]
];

_pathGenerator set ["props", _unitTypes];

_pathGenerator set ["requestQueue", []];
_pathGenerator set ["currentRequest", []];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Paths_onFrame];
_pathGenerator set ["onFrameHandlerID", _frameEventHandler];

_pathGenerator