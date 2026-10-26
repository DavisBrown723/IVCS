// Optional explicit locations keep authoring separate from the active mission data.
params [["_locations", missionNamespace getVariable ["IVCS_Locations_CurrentMapData", []]]];
private _lines = ["private _locations = [];"];
{
    private _location = _x;
    private _keys = keys _location;
    _keys sort true;
    private _pairs = _keys apply { [_x, _location get _x] };
    _lines pushBack format ["_locations pushBack (createHashMapFromArray %1);", [_pairs] call IVCS_Locations_serializeMapValue];
} forEach _locations;
_lines pushBack "_locations";
_lines joinString toString [13,10]
