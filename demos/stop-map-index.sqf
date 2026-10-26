// Run with Local Exec: [] execVM "IVCS\demos\stop-map-index.sqf";
terminate (missionNamespace getVariable ["IVCS_Demo_MapIndexScript", scriptNull]);
// The owned prefix also catches markers from an interrupted preview build.
{
    if ((_x find "IVCS_Demo_MapIndex_") == 0) then { deleteMarkerLocal _x; };
} forEach allMapMarkers;
IVCS_Demo_MapIndexMarkers = [];
IVCS_Demo_MapIndexLocations = [];
IVCS_Demo_MapIndexScript = scriptNull;
