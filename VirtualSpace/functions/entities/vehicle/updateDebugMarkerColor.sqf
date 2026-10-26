params ["_entity"];

private _marker = _entity get "debugMarker";
if (_marker != "") then {
    private _side = "NONE";
    // Owner teardown removes its registry entry before detaching every link.
    {
        private _owner = [_x] call IVCS_VirtualSpace_getEntity;
        if (!isNil "_owner") exitWith { _side = _owner get "side"; };
    } forEach ([_entity get "commandingEntity"] + (_entity get "entitiesInCargo"));
    _marker setMarkerColor ([_side] call IVCS_Common_sideStringToColor);
};
