IVCS_Common_OnFrame_LastIteration = -999;

IVCS_Common_SideAllegiances = createHashMapFromArray [
	["EAST", [[],[]]],
	["WEST", [[],[]]],
	["GUER", [[],[]]]
];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Common_onFrame];
IVCS_Common_OnFrameEH = _frameEventHandler;

IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;

IVCS_Common_HardpointMagazines = [] call IVCS_Common_getAllHardpointMagazines;
IVCS_Common_VehiclePylons = [] call IVCS_Common_getAllVehiclePylons;

IVCS_Common_WeaponAliases = createHashMapFromArray [
	["CUP_launch_FIM92Stinger", "CUP_launch_FIM92Stinger_Loaded"],
	["CUP_launch_NLAW","CUP_launch_NLAW_Loaded"],
	["CUP_launch_M136", "CUP_launch_M136_Loaded"],
	["CUP_launch_RPG18", "CUP_launch_RPG18_Loaded"],
	["CUP_launch_9K32Strela", "CUP_launch_9K32Strela_Loaded"],
	["CUP_launch_Igla", "CUP_launch_Igla_Loaded"],
	["CUP_launch_M72A6", "CUP_launch_M72A6_Loaded"],
	["CUP_launch_APILAS", "CUP_launch_APILAS_Loaded"]
];
