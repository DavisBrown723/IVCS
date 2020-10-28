IVCS_VirtualSpace_createController = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createController.sqf";
IVCS_VirtualSpace_createEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntity.sqf";
IVCS_VirtualSpace_createGroupEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createGroupEntity.sqf";
IVCS_VirtualSpace_createEntityUnit = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntityUnit.sqf";
IVCS_VirtualSpace_entityAddUnits = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityAddUnits.sqf";
IVCS_VirtualSpace_createVehicleEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createVehicleEntity.sqf";
IVCS_VirtualSpace_getEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getEntity.sqf";
IVCS_VirtualSpace_registerEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\registerEntity.sqf";
IVCS_VirtualSpace_unregisterEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\unregisterEntity.sqf";
IVCS_VirtualSpace_entityRemoveUnit = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityRemoveUnit.sqf";
IVCS_VirtualSpace_onFrame = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\onFrame.sqf";
IVCS_VirtualSpace_onUnitKilled = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\onUnitKilled.sqf";
IVCS_VirtualSpace_createEntityDebugMarker = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntityDebugMarker.sqf";
IVCS_VirtualSpace_createEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntityWaypoint.sqf";
IVCS_VirtualSpace_waypointToEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypointToEntityWaypoint.sqf";
IVCS_VirtualSpace_entityWaypointToWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityWaypointToWaypoint.sqf";
IVCS_VirtualSpace_entityAddWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityAddWaypoint.sqf";
IVCS_VirtualSpace_entityRemoveWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityRemoveWaypoint.sqf";
IVCS_VirtualSpace_getEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getEntityWaypoint.sqf";
IVCS_VirtualSpace_onWaypointCompleted = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\onWaypointCompleted.sqf";
IVCS_VirtualSpace_determineCycleWaypointLoop = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\determineCycleWaypointLoop.sqf";
IVCS_VirtualSpace_entityAddTask = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityAddTask.sqf";
IVCS_VirtualSpace_assignEntityToVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\assignEntityToVehicle.sqf";
IVCS_VirtualSpace_unassignEntityFromVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\unassignEntityFromVehicle.sqf";
IVCS_VirtualSpace_countUnitsAssignedToVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\countUnitsAssignedToVehicle.sqf";
IVCS_VirtualSpace_getEntityUnit = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getEntityUnit.sqf";

// entity functions

IVCS_VirtualSpace_Infantry_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\infantry\update.sqf";
IVCS_VirtualSpace_Infantry_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\infantry\spawn.sqf";
IVCS_VirtualSpace_Infantry_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\infantry\despawn.sqf";
IVCS_VirtualSpace_Infantry_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\infantry\unregister.sqf";

IVCS_VirtualSpace_Vehicle_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\update.sqf";
IVCS_VirtualSpace_Vehicle_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\spawn.sqf";
IVCS_VirtualSpace_Vehicle_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\despawn.sqf";
IVCS_VirtualSpace_Vehicle_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\unregister.sqf";

IVCS_VirtualSpace_Uav_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\update.sqf";
IVCS_VirtualSpace_Uav_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\spawn.sqf";
IVCS_VirtualSpace_Uav_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\despawn.sqf";
IVCS_VirtualSpace_Uav_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\unregister.sqf";