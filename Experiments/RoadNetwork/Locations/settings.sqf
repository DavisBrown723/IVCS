// Opt-in RoadNetwork location snapshot; leave production and AdaptiveFootprints unchanged.
private _settings = call compile preprocessFileLineNumbers "IVCS\Experiments\AdaptiveFootprints\settings.sqf";
_settings set ["version", 7];
_settings set ["variant", "adaptive-footprints-settlement-ports-v2"];
// Settlement ownership follows the existing spatial bounds without a member-count cap.
// Military port support keeps its established twenty-object cap.
(_settings get "portSupport") set ["maximumSecondaryObjectsByPrimaryType", createHashMapFromArray [["town", -1]]];
_settings
