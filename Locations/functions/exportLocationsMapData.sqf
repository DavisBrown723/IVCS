private _locations = IVCS_Locations_CurrentMapData;

private _newLine = toString [13,10];

private _exportString = "private _locations = [];" + _newLine;
_exportString = _exportString + "private '_location';" + _newLine + _newLine;

{
    private _location = _x;
    private _type = _location getvariable "type";
    private _position = _location getvariable "position";
    private _size = _location getvariable "size";

    private _createLocStr = "_location = [] call CBA_fnc_createNamespace;" + _newLine;
    _createLocStr = _createLocStr + (format ["_location setvariable ['type', '%1'];", _type]) + _newLine;
    _createLocStr = _createLocStr + (format ["_location setvariable ['position', %1];", _position]) + _newLine;
    _createLocStr = _createLocStr + (format ["_location setvariable ['size', %1];", _size]) + _newLine;
    _createLocStr = _createLocStr + "_locations pushback _location;" + _newLine;

    _exportString = _exportString + _createLocStr + _newLine;
} foreach _locations;

_exportString = _exportString + "_locations";

_exportString