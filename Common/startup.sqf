IVCS_Common_OnFrame_LastIteration = diag_tickTime;

IVCS_Common_SideAllegiances = [] call CBA_fnc_createNamespace;
IVCS_Common_SideAllegiances setvariable ["EAST", [[],[]]];
IVCS_Common_SideAllegiances setvariable ["WEST", [[],[]]];
IVCS_Common_SideAllegiances setvariable ["GUER", [[],[]]];

IVCS_Common_WeaponInfo = [] call CBA_fnc_createNamespace;
IVCS_Common_AmmoInfo = [] call CBA_fnc_createNamespace;