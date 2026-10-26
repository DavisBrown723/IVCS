params ["_entity"];
(_entity get "entityType") in ["vehicle","uav"] &&
{ (_entity get "class") isKindOf "AllVehicles" } &&
{ !((_entity get "class") isKindOf "Man") } &&
{ !(_entity get "simulationTransition") } &&
{ (_entity get "damage") < 1 }
