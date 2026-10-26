params ["_vehicle","_attacker"];
if ((_vehicle get "vehicleType") == "helicopter") then {
    _vehicle set ["airThreat",[+(_attacker get "position"),IVCS_SimulationTime + ((IVCS_VirtualSpace_Controller get "combat") get "helicopterEvasionTime"),_attacker getOrDefault ["id",""]]];
};
