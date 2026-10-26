params ["_entity", "_vehicle"];

private _vehicleID = _vehicle get "id";
{
    private _assignment = _x get "vehicleAssignment";
    _assignment isNotEqualTo [] && { (_assignment select 0) == _vehicleID }
} count (_entity get "units")
