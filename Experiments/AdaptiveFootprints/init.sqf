// Opt-in experiment; never overrides the production IVCS_Locations functions.
IVCS_AF_indexSettings = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\settings.sqf";
IVCS_AF_indexClassify = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\classify.sqf";
IVCS_AF_indexScan = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\scan.sqf";
IVCS_AF_indexNearWater = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\nearWater.sqf";
IVCS_AF_indexBuild = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\build.sqf";
IVCS_AF_indexRefine = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\refine.sqf";
IVCS_AF_indexPreview = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\preview.sqf";
IVCS_AF_serializeMapValue = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\serialize.sqf";
IVCS_AF_createLocation = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\createLocation.sqf";
IVCS_AF_exportLocationsMapData = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\exportLocations.sqf";
IVCS_AF_fitFootprint = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\geometry\fit.sqf";
IVCS_AF_footprintDistance = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\geometry\distance.sqf";
IVCS_AF_footprintContains = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\geometry\contains.sqf";
IVCS_AF_footprintCorners = compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\geometry\corners.sqf";
