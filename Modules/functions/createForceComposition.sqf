params ["_marker"];


private _forceComposition = [[],[]] call IVCS_Modules_createForceComposition;

private _createdEntitiesModule = [["marker_0"], [_forceComposition]] call IVCS_Modules_createEntitiesInMarker;


private _createCommandStructure = [["Conventional"],[_createdEntitiesModule]] call IVCS_Modules_createCommandStructure;