private _composition = [] call CBA_fnc_createNamespace;

// settings

_composition setvariable ["faction", "BLU_F"];
_composition setvariable ["isAsymmetric", false];

// groups

_composition setvariable ["infantry", [
    ["B_Soldier_SL_F","B_soldier_AR_F","B_HeavyGunner_F","B_soldier_AAR_F","B_soldier_M_F","B_Sharpshooter_F","B_soldier_LAT_F","B_medic_F"],
    ["B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_GL_F","B_soldier_LAT_F"],
    ["B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_F","B_soldier_LAT2_F"],
    ["B_Soldier_SL_F","B_Soldier_F","B_soldier_LAT_F","B_soldier_M_F","B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_A_F","B_medic_F"],
    ["B_Soldier_GL_F","B_Soldier_F"],
    ["B_Soldier_SL_F","B_soldier_AR_F","B_Soldier_GL_F","B_soldier_M_F","B_soldier_AT_F","B_soldier_AAT_F","B_Soldier_A_F","B_medic_F"],
    ["B_Soldier_TL_F","B_soldier_AA_F","B_soldier_AA_F","B_soldier_AAA_F"],
    ["B_Soldier_TL_F","B_soldier_AT_F","B_soldier_AT_F","B_soldier_AAT_F"]
]];

_composition setvariable ["reconInfantry", [
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_F"],
    ["B_recon_M_F","B_recon_F"],
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_F","B_recon_LAT_F","B_recon_JTAC_F","B_recon_exp_F","B_Recon_Sharpshooter_F"],
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_LAT_F","B_recon_JTAC_F","B_recon_exp_F"],
    ["B_sniper_F","B_spotter_F"]
]];

_composition setvariable ["motorized", [
    ["B_MRAP_01_F","B_Soldier_F"],
    ["B_MRAP_01_gmg_F","B_Soldier_F"],
    ["B_MRAP_01_hmg_F","B_Soldier_F"]
]];
_composition setvariable ["mechanized", [
    ["B_APC_Wheeled_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_APC_Tracked_01_rcws_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_AFV_Wheeled_01_up_cannon_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition setvariable ["tanks", [
        ["B_MBT_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"],
        ["B_MBT_01_TUSK_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition setvariable ["tankDestroyers", [
    ["B_AFV_Wheeled_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition setvariable ["artillery", [
    ["B_MBT_01_arty_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_MBT_01_mlrs_F","B_crew_F","B_crew_F"]
]];
_composition setvariable ["boats", [
    ["B_Boat_Armed_01_minigun_F","B_Soldier_F","B_Soldier_F","B_Soldier_F"],
    ["B_Boat_Transport_01_F","B_Soldier_F"]
]];

_composition setvariable ["attackHelicopter", [
    ["B_Heli_Light_01_dynamicLoadout_F","B_Helipilot_F","B_Helipilot_F"],
    ["B_Heli_Attack_01_dynamicLoadout_F","B_Helipilot_F","B_Helipilot_F"]
]];
_composition setvariable ["transportHelicopter", [
    ["B_Heli_Transport_01_F","B_Helipilot_F","B_Helipilot_F","B_helicrew_F","B_helicrew_F"],
    ["B_Heli_Light_01_F","B_Helipilot_F","B_Helipilot_F"]
]];
_composition setvariable ["cargoHelicopters", [
    ["B_Heli_Transport_03_F","B_Helipilot_F","B_Helipilot_F","B_helicrew_F","B_helicrew_F"],
    ["B_T_VTOL_01_infantry_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F"],
    ["B_T_VTOL_01_vehicle_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F"]
]];

_composition setvariable ["attackPlane", [
    ["B_Plane_CAS_01_dynamicLoadout_F","B_Fighter_Pilot_F"],
    ["B_Plane_Fighter_01_F","B_Fighter_Pilot_F"],
    ["B_Plane_Fighter_01_Stealth_F","B_Fighter_Pilot_F"]
]];
_composition setvariable ["cargoPlane", []];

_composition setvariable ["logistics_ammo", [ ["B_Truck_01_ammo_F","B_Soldier_F"] ]];
_composition setvariable ["logistics_fuel", [ ["B_Truck_01_fuel_F","B_Soldier_F"] ]];
_composition setvariable ["logistics_medical", [ ["B_Truck_01_medical_F","B_Soldier_F"] ]];
_composition setvariable ["logistics_repair", [ ["B_Truck_01_Repair_F","B_Soldier_F"] ]];

_composition setvariable ["mobile_antiair", [
    ["B_APC_Tracked_01_AA_F", "B_crew_F","B_crew_F","B_crew_F"]
]];

_composition setvariable ["sam", ["B_SAM_System_03_F"]];
_composition setvariable ["radar", ["B_Radar_System_01_F"]];

// objects

_composition