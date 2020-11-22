params ["_marker"];

IVCS_Locations_CurrentMapData select {
    private _position = _x getvariable "position";

    _position inArea _marker
};