params ["_entity"];
(_entity get "entityType") == "group" &&
{ !(_entity get "simulationTransition") } &&
{ (_entity get "units") isNotEqualTo [] } &&
{ (_entity get "vehiclesInCommandOf") isEqualTo [] } &&
{ (_entity get "vehiclesInCargoOf") isEqualTo [] } &&
{ (_entity get "units") findIf { (_x get "vehicleAssignment") isNotEqualTo [] } == -1 }
