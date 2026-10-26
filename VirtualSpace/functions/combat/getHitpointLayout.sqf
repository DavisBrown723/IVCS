// Cache indices, never damage. Capture replaces the layout; damage edits only values.
params ["_unit"];
private _hitpoints = _unit get "hitpoints";
private _class = _unit get "class";
private _cached = _unit getOrDefault ["hitpointLayout",[]];
if (_cached isNotEqualTo [] && { (_cached select 0) isEqualRef _hitpoints } && { (_cached select 1) == _class } && { (_cached select 5) == count _hitpoints }) exitWith { _cached };
private _profile = [_class] call IVCS_Combat_getUnitProfile;
private _available = _hitpoints apply { _x select 0 };
private _indices = createHashMap;
private _arms = [];
{
    private _name = _x select 0;
    if !(_name in _indices) then { _indices set [_name,_forEachIndex]; };
    private _info = (_profile get "hitpoints") get _name;
    if (!isNil "_info" && { (_info select 2) == "arms" }) then { _arms pushBack _forEachIndex; };
} forEach _hitpoints;
private _makeTargets = {
    params ["_names"];
    (_names arrayIntersect _available) apply { [_indices get _x,(_profile get "hitpoints") get _x,_x] }
};
private _regions = createHashMap;
{ _regions set [_x,[(_profile get "regions") get _x] call _makeTargets]; } forEach ["head","torso","arms","legs"];
_cached = [_hitpoints,_class,_arms,_regions,[_profile get "targets"] call _makeTargets,count _hitpoints];
_unit set ["hitpointLayout",_cached];
_cached
