IVCS_Common_OnFrame_LastIteration = -999;

IVCS_Common_SideAllegiances = [] call CBA_fnc_createNamespace;
IVCS_Common_SideAllegiances setvariable ["EAST", [[],[]]];
IVCS_Common_SideAllegiances setvariable ["WEST", [[],[]]];
IVCS_Common_SideAllegiances setvariable ["GUER", [[],[]]];

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Common_onFrame];
IVCS_Common_OnFrameEH = _frameEventHandler;

IVCS_Common_WeaponInfo = [] call CBA_fnc_createNamespace;
IVCS_Common_MagazineInfo = [] call CBA_fnc_createNamespace;
IVCS_Common_AmmoInfo = [] call CBA_fnc_createNamespace;
IVCS_Common_UnitInfo = [] call CBA_fnc_createNamespace;

IVCS_Common_WeaponAliases = [] call CBA_fnc_createNamespace;
IVCS_Common_WeaponAliases setvariable ['CUP_launch_FIM92Stinger', 'CUP_launch_FIM92Stinger_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_NLAW', 'CUP_launch_NLAW_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_M136', 'CUP_launch_M136_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_RPG18', 'CUP_launch_RPG18_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_9K32Strela', 'CUP_launch_9K32Strela_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_Igla', 'CUP_launch_Igla_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_M72A6', 'CUP_launch_M72A6_Loaded'];
IVCS_Common_WeaponAliases setvariable ['CUP_launch_APILAS', 'CUP_launch_APILAS_Loaded'];