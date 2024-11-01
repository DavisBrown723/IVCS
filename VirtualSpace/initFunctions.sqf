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
IVCS_VirtualSpace_simulateEntities = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\simulateEntities.sqf";
IVCS_VirtualSpace_onUnitKilled = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\onUnitKilled.sqf";
IVCS_VirtualSpace_createEntityDebugMarker = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntityDebugMarker.sqf";
IVCS_VirtualSpace_entityAddTask = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entityAddTask.sqf";
IVCS_VirtualSpace_countUnitsAssignedToVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\countUnitsAssignedToVehicle.sqf";
IVCS_VirtualSpace_getEntityUnit = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getEntityUnit.sqf";
IVCS_VirtualSpace_getNearEntities = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getNearEntities.sqf";
IVCS_VirtualSpace_onUnitLeaveVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\onUnitLeaveVehicle.sqf";
IVCS_VirtualSpace_getSideKnownTargets = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getSideKnownTargets.sqf";
IVCS_VirtualSpace_setEntityPosition = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\setEntityPosition.sqf";
IVCS_VirtualSpace_getCurrentEntityTask = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getCurrentEntityTask.sqf";
IVCS_VirtualSpace_getEntityTask = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\getEntityTask.sqf";
IVCS_VirtualSpace_createEntitySpawnerFSM = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\createEntitySpawnerFSM.sqf";

// waypoint functions

IVCS_VirtualSpace_createEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\createEntityWaypoint.sqf";
IVCS_VirtualSpace_entityWaypointToWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\entityWaypointToWaypoint.sqf";
IVCS_VirtualSpace_waypointToEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\waypointToEntityWaypoint.sqf";
IVCS_VirtualSpace_onWaypointCompleted = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\onWaypointCompleted.sqf";
IVCS_VirtualSpace_determineCycleWaypointLoop = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\determineCycleWaypointLoop.sqf";
IVCS_VirtualSpace_getEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\getEntityWaypoint.sqf";
IVCS_VirtualSpace_getEntityCurrentWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\getEntityCurrentWaypoint.sqf";
IVCS_VirtualSpace_entityAddWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\entityAddWaypoint.sqf";
IVCS_VirtualSpace_entityRemoveWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\entityRemoveWaypoint.sqf";
IVCS_VirtualSpace_findEntityWaypointLoops = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\findEntityWaypointLoops.sqf";
IVCS_VirtualSpace_onWaypointStarted = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\onWaypointStarted.sqf";
IVCS_VirtualSpace_resetEntityWaypoint = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\waypoints\resetEntityWaypoint.sqf";

// entity functions

IVCS_VirtualSpace_Group_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\update.sqf";
IVCS_VirtualSpace_Group_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\spawn.sqf";
IVCS_VirtualSpace_Group_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\despawn.sqf";
IVCS_VirtualSpace_Group_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\unregister.sqf";
IVCS_VirtualSpace_Group_calculateSpeed = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\calculateSpeed.sqf";
IVCS_VirtualSpace_Group_determinePathfindingStrategy = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\determinePathfindingStrategy.sqf";
IVCS_VirtualSpace_Group_getUnitLoadout = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\getUnitLoadout.sqf";
IVCS_VirtualSpace_Group_getUnseatedUnits = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\getUnseatedUnits.sqf";
IVCS_VirtualSpace_Group_assignVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\assignVehicle.sqf";
IVCS_VirtualSpace_Group_assignAsVehicleCargo = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\assignAsVehicleCargo.sqf";
IVCS_VirtualSpace_Group_unassignVehicle = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\unassignVehicle.sqf";
IVCS_VirtualSpace_Group_unassignAsVehicleCargo = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\unassignAsVehicleCargo.sqf";
IVCS_VirtualSpace_Group_getVehicleAssignmentType = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\getVehicleAssignmentType.sqf";
IVCS_VirtualSpace_Group_canEngageEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\canEngageEntity.sqf";
IVCS_VirtualSpace_Group_getEngagementCapabilities = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\getEngagementCapabilities.sqf";
IVCS_VirtualSpace_Group_getFunctionalEntityType = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\getFunctionalEntityType.sqf";
IVCS_VirtualSpace_Group_onContactSimple = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\onContactSimple.sqf";
IVCS_VirtualSpace_Group_onWaypointPathGenerated = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\group\onWaypointPathGenerated.sqf";

IVCS_VirtualSpace_Vehicle_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\update.sqf";
IVCS_VirtualSpace_Vehicle_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\spawn.sqf";
IVCS_VirtualSpace_Vehicle_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\despawn.sqf";
IVCS_VirtualSpace_Vehicle_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\unregister.sqf";
IVCS_VirtualSpace_Vehicle_onUnitGetOut = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\onUnitGetOut.sqf";
IVCS_VirtualSpace_Vehicle_onVehicleDestroyed = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\onVehicleDestroyed.sqf";
IVCS_VirtualSpace_Vehicle_getEmptySeats = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\getEmptySeats.sqf";
IVCS_VirtualSpace_Vehicle_canTransportEntity = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\canTransportEntity.sqf";
IVCS_VirtualSpace_Vehicle_updateDebugMarkerColor = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\vehicle\updateDebugMarkerColor.sqf";


//IVCS_VirtualSpace_Uav_update = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\update.sqf";
//IVCS_VirtualSpace_Uav_spawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\spawn.sqf";
//IVCS_VirtualSpace_Uav_despawn = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\despawn.sqf";
//IVCS_VirtualSpace_Uav_unregister = compile preprocessFileLineNumbers "IVCS\VirtualSpace\functions\entities\uav\unregister.sqf";