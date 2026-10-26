params ["_a","_b"];
(_b get "vehicleType") == "helicopter" && {[_b] call IVCS_Combat_isVehicleTarget} && {
    if ((_a get "entityType") == "group") then {[_a] call IVCS_Combat_isAttackingGroup} else {
        [_a] call IVCS_Combat_isVehicleTarget && {([_a get "class"] call IVCS_Combat_getVehicleProfile) get "kind" == "land"}
    }
}
