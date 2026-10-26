// Enclosed passengers are protected by their transport; FFV occupants remain exposed.
params ["_infantry"];
(_infantry get "units") select {
    (_x get "vehicleAssignment") isEqualTo [] || {([_x] call IVCS_Combat_mountState) in [1,3]}
}
