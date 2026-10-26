params ["_entity"];
(_entity get "entityType") == "group" && { !(_entity get "simulationTransition") } && { (_entity get "units") isNotEqualTo [] }
