params ["_markers"];

// marker format
// loc_type

if (isnil "_markers") then {
    _markers = allMapMarkers;
};

private _locations = [];
{
    private _markerName = _x;
    if (count _markerName > 3 && {(_markerName select [0,3]) == "loc"}) then {
        // loc_civ
        // loc_mil
        // loc_mil_airfield
        private _locationInfo = _markerName splitString "_";
        private _locationType = _locationInfo select 1;
        private _locationPosition = markerPos _x;
        private _locationSize = ((markerSize _x) select 0) max 5;

        private _location = [_locationType, _locationPosition, _locationSize] call IVCS_Locations_createLocation;
        _locations pushback _location;
    };

    _x setmarkeralpha 0;
} foreach _markers;

_locations