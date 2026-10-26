// Return native units to dismount after both sides of the link are detached.
params ["_entity", "_vehicleID"];

// Removed owners leave native objects to the despawn caller. Do not replace
// their task cleanup orders with new dismount orders during teardown.
private _native = (_entity get "active") && { (_entity get "id") in (IVCS_VirtualSpace_Controller get "entities" get "ALL") };
private _objects = [];
{
    private _assignment = _x get "vehicleAssignment";
    if (_assignment isNotEqualTo [] && { (_assignment select 0) == _vehicleID }) then {
        (_assignment select 1) set [1, ""];
        _x set ["vehicleAssignment", []];
        if (_native) then { _objects pushBack (_x get "object"); };
    };
} forEach (_entity get "units");

_objects
