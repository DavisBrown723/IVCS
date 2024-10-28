private _composition = createHashMap;

// settings

_composition set ["faction", "BLU_F"];
_composition set ["isAsymmetric", false];

// groups

_composition set ["infantry", [
    ["B_Soldier_SL_F","B_soldier_AR_F","B_HeavyGunner_F","B_soldier_AAR_F","B_soldier_M_F","B_Sharpshooter_F","B_soldier_LAT_F","B_medic_F"],
    ["B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_GL_F","B_soldier_LAT_F"],
    ["B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_F","B_soldier_LAT2_F"],
    ["B_Soldier_SL_F","B_Soldier_F","B_soldier_LAT_F","B_soldier_M_F","B_Soldier_TL_F","B_soldier_AR_F","B_Soldier_A_F","B_medic_F"],
    ["B_Soldier_GL_F","B_Soldier_F"],
    ["B_Soldier_SL_F","B_soldier_AR_F","B_Soldier_GL_F","B_soldier_M_F","B_soldier_AT_F","B_soldier_AAT_F","B_Soldier_A_F","B_medic_F"],
    ["B_Soldier_TL_F","B_soldier_AA_F","B_soldier_AA_F","B_soldier_AAA_F"],
    ["B_Soldier_TL_F","B_soldier_AT_F","B_soldier_AT_F","B_soldier_AAT_F"]
]];

_composition set ["reconInfantry", [
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_F"],
    ["B_recon_M_F","B_recon_F"],
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_F","B_recon_LAT_F","B_recon_JTAC_F","B_recon_exp_F","B_Recon_Sharpshooter_F"],
    ["B_recon_TL_F","B_recon_M_F","B_recon_medic_F","B_recon_LAT_F","B_recon_JTAC_F","B_recon_exp_F"],
    ["B_sniper_F","B_spotter_F"]
]];

_composition set ["motorized", [
    ["B_MRAP_01_F","B_Soldier_F"],
    ["B_MRAP_01_gmg_F","B_Soldier_F"],
    ["B_MRAP_01_hmg_F","B_Soldier_F"]
]];
_composition set ["mechanized", [
    ["B_APC_Wheeled_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_APC_Tracked_01_rcws_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_AFV_Wheeled_01_up_cannon_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition set ["tanks", [
        ["B_MBT_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"],
        ["B_MBT_01_TUSK_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition set ["tankDestroyers", [
    ["B_AFV_Wheeled_01_cannon_F","B_crew_F","B_crew_F","B_crew_F"]
]];
_composition set ["artillery", [
    ["B_MBT_01_arty_F","B_crew_F","B_crew_F","B_crew_F"],
    ["B_MBT_01_mlrs_F","B_crew_F","B_crew_F"]
]];
_composition set ["boats", [
    ["B_Boat_Armed_01_minigun_F","B_Soldier_F","B_Soldier_F","B_Soldier_F"],
    ["B_Boat_Transport_01_F","B_Soldier_F"]
]];

_composition set ["attackHelicopter", [
    ["B_Heli_Light_01_dynamicLoadout_F","B_Helipilot_F","B_Helipilot_F"],
    ["B_Heli_Attack_01_dynamicLoadout_F","B_Helipilot_F","B_Helipilot_F"]
]];
_composition set ["transportHelicopter", [
    ["B_Heli_Transport_01_F","B_Helipilot_F","B_Helipilot_F","B_helicrew_F","B_helicrew_F"],
    ["B_Heli_Light_01_F","B_Helipilot_F","B_Helipilot_F"]
]];
_composition set ["cargoHelicopters", [
    ["B_Heli_Transport_03_F","B_Helipilot_F","B_Helipilot_F","B_helicrew_F","B_helicrew_F"],
    ["B_T_VTOL_01_infantry_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F"],
    ["B_T_VTOL_01_vehicle_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F","B_T_Pilot_F"]
]];

_composition set ["attackPlane", [
    ["B_Plane_CAS_01_dynamicLoadout_F","B_Fighter_Pilot_F"],
    ["B_Plane_Fighter_01_F","B_Fighter_Pilot_F"],
    ["B_Plane_Fighter_01_Stealth_F","B_Fighter_Pilot_F"]
]];
_composition set ["cargoPlane", []];

_composition set ["logistics_ammo", [ ["B_Truck_01_ammo_F","B_Soldier_F"] ]];
_composition set ["logistics_fuel", [ ["B_Truck_01_fuel_F","B_Soldier_F"] ]];
_composition set ["logistics_medical", [ ["B_Truck_01_medical_F","B_Soldier_F"] ]];
_composition set ["logistics_repair", [ ["B_Truck_01_Repair_F","B_Soldier_F"] ]];

_composition set ["mobile_antiair", [
    ["B_APC_Tracked_01_AA_F", "B_crew_F","B_crew_F","B_crew_F"]
]];

_composition set ["sam", ["B_SAM_System_03_F"]];
_composition set ["radar", ["B_Radar_System_01_F"]];

// objects

_composition