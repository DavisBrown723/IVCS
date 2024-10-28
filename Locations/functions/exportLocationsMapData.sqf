private _locations = IVCS_Locations_CurrentMapData;

private _newLine = toString [13,10];

private _exportString = "private _locations = [];" + _newLine;
_exportString = _exportString + "private '_location';" + _newLine + _newLine;

{
    private _location = _x;
    private _type = _location get "type";
    private _position = _location get "position";
    private _size = _location get "size";

    private _createLocStr = "_location = createHashMap;" + _newLine;
    _createLocStr = _createLocStr + (format ["_location set ['type', '%1'];", _type]) + _newLine;
    _createLocStr = _createLocStr + (format ["_location set ['position', %1];", _position]) + _newLine;
    _createLocStr = _createLocStr + (format ["_location set ['size', %1];", _size]) + _newLine;
    _createLocStr = _createLocStr + "_locations pushback _location;" + _newLine;

    _exportString = _exportString + _createLocStr + _newLine;
} foreach _locations;

_exportString = _exportString + "_locations";

_exportString