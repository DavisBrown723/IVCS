// LAND currently supports helicopters.
params ["_entity", "_landingPosition", ["_landingType", "LAND"]];
["LAND", [["landingPosition", +_landingPosition], ["landingType", toUpper _landingType]]] call IVCS_EntityTasks_createTaskInstance
