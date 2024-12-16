IVCS_Common_normalizeDegrees = compile preprocessFileLineNumbers "IVCS\Common\functions\normalizeDegrees.sqf";
IVCS_Common_generateRandomPosition = compile preprocessFileLineNumbers "IVCS\Common\functions\generateRandomPosition.sqf";
IVCS_Common_findRandomPositionsInMarker = compile preprocessFileLineNumbers "IVCS\Common\functions\findRandomPositionsInMarker.sqf";
IVCS_Common_generateRandomPositionsInRadius = compile preprocessFileLineNumbers "IVCS\Common\functions\generateRandomPositionsInRadius.sqf";

IVCS_Common_findConvexHull = compile preprocessFileLineNumbers "IVCS\Common\functions\findConvexHull.sqf";
IVCS_Common_findOffsetFromSegment = compile preprocessFileLineNumbers "IVCS\Common\functions\findOffsetFromSegment.sqf";
IVCS_Common_findMidpoint = compile preprocessFileLineNumbers "IVCS\Common\functions\findMidpoint.sqf";
IVCS_Common_isPointInsideShape = compile preprocessFileLineNumbers "IVCS\Common\functions\isPointInsideShape.sqf";
IVCS_Common_doSegmentsIntersect = compile preprocessFileLineNumbers "IVCS\Common\functions\doSegmentsIntersect.sqf";
IVCS_Common_pointDistanceFromSegment = compile preprocessFileLineNumbers "IVCS\Common\functions\pointDistanceFromSegment.sqf";

// arrays

IVCS_Common_flattenArray = compile preprocessFileLineNumbers "IVCS\Common\functions\arrays\flattenArray.sqf";
IVCS_Common_foreachArrays = compile preprocessFileLineNumbers "IVCS\Common\functions\arrays\foreachArrays.sqf";

// units

IVCS_Common_findUnitType = compile preprocessFileLineNumbers "IVCS\Common\functions\units\findUnitType.sqf";
IVCS_Common_getUnitLoadoutInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\units\getUnitLoadoutInfo.sqf";
IVCS_Common_getUnitObjectLoadoutInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\units\getUnitObjectLoadoutInfo.sqf";
IVCS_Common_getUnitClassesFromGroupConfig = compile preprocessFileLineNumbers "IVCS\Common\functions\units\getUnitClassesFromGroupConfig.sqf";
IVCS_Common_getBackpackCargo = compile preprocessFileLineNumbers "IVCS\Common\functions\units\getBackpackCargo.sqf";

// allegiances

IVCS_Common_getSideAllegiances = compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\getSideAllegiances.sqf";
IVCS_Common_getFactionSide = compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\getFactionSide.sqf";
IVCS_Common_sideStringToObject = compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\sideStringToObject.sqf";
IVCS_Common_sideObjectToString = compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\sideObjectToString.sqf";
IVCS_Common_sideNumToString= compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\sideNumToString.sqf";
IVCS_Common_sideStringToNum= compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\sideStringToNum.sqf";
IVCS_Common_sideStringToColor = compile preprocessFileLineNumbers "IVCS\Common\functions\allegiances\sideStringToColor.sqf";

// weapons

IVCS_Common_findDisposableWeapons = compile preprocessFileLineNumbers "IVCS\Common\functions\weapons\findDisposableWeapons.sqf";
IVCS_Common_getWeaponInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\weapons\getWeaponInfo.sqf";
IVCS_Common_getMagazineInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\weapons\getMagazineInfo.sqf";
IVCS_Common_getAmmoInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\weapons\getAmmoInfo.sqf";

// vehicles

IVCS_Common_findVehicleSeats = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\findVehicleSeats.sqf";
IVCS_Common_getVehicleSide = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getVehicleSide.sqf";
IVCS_Common_getAllHardpointMagazines = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getAllHardpointMagazines.sqf";
IVCS_Common_getVehicleTurrets = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getVehicleTurrets.sqf";
IVCS_Common_getPylonsFromVehicleConfig = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getPylonsFromVehicleConfig.sqf";
IVCS_Common_getHardpointMagazines = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getHardpointMagazines.sqf";
IVCS_Common_getAllVehicleTurretsFromConfig = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getAllVehicleTurretsFromConfig.sqf";
IVCS_Common_getVehicleWeapons = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getVehicleWeapons.sqf";
IVCS_Common_getVehiclePylonsMagazineInfo = compile preprocessFileLineNumbers "IVCS\Common\functions\vehicles\getVehiclePylonsMagazineInfo.sqf";

// containers

IVCS_Common_getContainerInventoryFromConfig = compile preprocessFileLineNumbers "IVCS\Common\functions\containers\getContainerInventoryFromConfig.sqf";
IVCS_Common_getContainerInventory = compile preprocessFileLineNumbers "IVCS\Common\functions\containers\getContainerInventory.sqf";
IVCS_Common_applyContainerInventory = compile preprocessFileLineNumbers "IVCS\Common\functions\containers\applyContainerInventory.sqf";
IVCS_Common_clearContainerInventory = compile preprocessFileLineNumbers "IVCS\Common\functions\containers\clearContainerInventory.sqf";
IVCS_Common_getContainerType = compile preprocessFileLineNumbers "IVCS\Common\functions\containers\getContainerType.sqf";

// internal

IVCS_Common_calculateFrameNumber = compile preprocessFileLineNumbers "IVCS\Common\functions\internal\calculateFrameNumber.sqf";
IVCS_Common_onFrame = compile preprocessFileLineNumbers "IVCS\Common\functions\internal\onFrame.sqf";