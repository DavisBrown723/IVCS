// Shared sharing interface. Deferred searches use the same policy as batch updates.
params ["_entity",["_now",IVCS_SimulationTime],["_deferSearch",true]];
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
if (!(_settings get "enabled") || { !([_entity] call IVCS_Combat_isAttackingGroup) }) exitWith { [_entity] call IVCS_Ammo_cancelGroup; };
if (_now < (_entity get "ammoNextScan")) exitWith {};
private _native = _entity get "active";
private _requests = _entity get "ammoRequests";
private _interval = _settings get "scanInterval";
if (_native && { _requests isNotEqualTo [] }) then { _interval = _interval min (_settings get "pendingScanInterval"); };
_entity set ["ammoNextScan",_now + _interval];
isNil {
    if (_requests isNotEqualTo []) then {
        private _units = if (_native) then {
            (_entity get "units") select { [_x,true] call IVCS_Ammo_isEligible }
        } else { (_entity get "units") select { (_x get "damage") < 1 } };
        [_entity,_units,_now,_native] call IVCS_Ammo_updateRequests;
    };
    private _advance = true;
    if ((_entity get "ammoSearch") isEqualTo []) then {
        // Shallow roster snapshot: unary + would clone the units' HashMaps and inventory.
        // Each visit reads current inventory and eligibility.
        _entity set ["ammoSearch",createHashMapFromArray [
            ["native",_native],["scanUnits",(_entity get "units") select [0]],["scanIndex",0],["recipients",[]]
        ]];
        _advance = [_entity,_entity get "ammoSearch",_now,if (_deferSearch) then { _settings get "needsUnitsPerSlice" } else { -1 }] call IVCS_Ammo_scanNeeds;
    };
    if ((_entity get "ammoSearch") isNotEqualTo []) then {
        if (_advance) then {
            [_entity,_now,if (_deferSearch) then { _settings get "donorsPerSlice" } else { -1 }] call IVCS_Ammo_advanceSearch;
        };
        if ((_entity get "ammoSearch") isNotEqualTo []) then { (_settings get "searchQueue") pushBackUnique (_entity get "id"); };
    };
    if (_native && { _requests isNotEqualTo [] }) then { (_settings get "nativeQueue") pushBackUnique (_entity get "id"); };
};
