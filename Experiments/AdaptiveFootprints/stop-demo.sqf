// Owns experimental markers and variables only; the normal map demo is untouched.
terminate (missionNamespace getVariable ["IVCS_AF_DemoScript", scriptNull]);
{ if ((_x find "IVCS_AF_Demo_") == 0) then { deleteMarkerLocal _x; }; } forEach allMapMarkers;
IVCS_AF_DemoMarkers = [];
IVCS_AF_DemoLocations = [];
IVCS_AF_DemoScript = scriptNull;
