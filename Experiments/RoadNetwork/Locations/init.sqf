// Run only in the isolated authoring/test mission. No production functions are replaced.
call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\init.sqf";
IVCS_AF_indexSettings = compile preprocessFileLineNumbers "IVCS\Experiments\RoadNetwork\Locations\settings.sqf";
IVCS_AF_indexRefine = compile preprocessFileLineNumbers "IVCS\Experiments\RoadNetwork\Locations\refine.sqf";
