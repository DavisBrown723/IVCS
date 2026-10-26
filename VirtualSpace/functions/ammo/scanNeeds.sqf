// Read each visited unit's current inventory; retain only unfinished roster work.
// Return true only when donor discovery can proceed. A negative limit drains the scan.
params ["_entity","_job","_now","_limit"];
private _native = _job get "native";
private _units = _job get "scanUnits";
private _requests = _entity get "ammoRequests";
private _recipients = _job get "recipients";
private _cursor = _job get "scanIndex";
private _end = if (_limit < 0) then { count _units } else { (_cursor + _limit) min count _units };
{
    private _unit = _x;
    if (_now >= (_unit get "ammoRetryAt") && { _requests findIf { (_x get "recipient") isEqualRef _unit } == -1 }) then {
        private _wanted = [_unit,_native] call IVCS_Ammo_getNeededWeapons;
        // Inventory reads are harmless for an ineligible actor. Only a shortage
        // needs eligibility validation, before entering recipient/donor selection.
        if (_wanted isNotEqualTo [] && {
            if (_native) then { [_unit,true] call IVCS_Ammo_isEligible } else { (_unit get "damage") < 1 }
        }) then { _recipients pushBack [_unit,_wanted]; };
    };
} forEach (_units select [_cursor,_end - _cursor]);
_job set ["scanIndex",_end];
if (_end < count _units) exitWith { false };
_job set ["scanIndex",-1];
_job deleteAt "scanUnits";
if (_recipients isNotEqualTo []) then {
    // Sort only when there is a shortage, using the current eligible roster.
    // Removed units cannot become recipients or donors; donor inventory stays live.
    private _current = if (_native) then {
        (_entity get "units") select { [_x,true] call IVCS_Ammo_isEligible }
    } else { (_entity get "units") select { (_x get "damage") < 1 } };
    private _ordered = [];
    { _ordered pushBack [_x get "id",_forEachIndex]; } forEach _current;
    _ordered sort true;
    private _donors = _ordered apply { _current select (_x select 1) };
    private _sorted = [];
    {
        private _unit = _x;
        private _index = _recipients findIf { (_x select 0) isEqualRef _unit };
        if (_index != -1) then { _sorted pushBack (_recipients select _index); };
    } forEach _donors;
    _job set ["recipients",_sorted];
    if (_sorted isNotEqualTo []) then {
        _job set ["donors",_donors];
        _job set ["recipientIndex",0]; _job set ["weaponIndex",0]; _job set ["donorIndex",0];
        _job set ["best",[]]; _job set ["bestDonor",createHashMap]; _job set ["bestCount",-1];
    };
};
if ((_job get "recipients") isEqualTo []) exitWith {
    _entity set ["ammoSearch",[]];
    private _queue = ((IVCS_VirtualSpace_Controller get "combat") get "ammoSharing") get "searchQueue";
    private _index = _queue find (_entity get "id");
    if (_index != -1) then { _queue deleteAt _index; };
    false
};
true
