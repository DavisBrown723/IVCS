params ["_marker"];

IVCS_Locations_CurrentMapData select {
    private _position = _x get "position";

    _position inArea _marker
};