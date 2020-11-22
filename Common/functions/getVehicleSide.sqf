params ["_vehicleClass"];

[getnumber (configfile >> "CfgVehicles" >> _vehicleClass >> "side")] call IVCS_Common_sideNumToString