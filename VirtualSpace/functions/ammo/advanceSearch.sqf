// One discovery job retains needs and recipient/weapon/donor cursors across frames.
// A negative donor limit drains the same job for deterministic batch simulation.
params ["_entity","_now","_limit"];
isNil {
    private _job = _entity get "ammoSearch";
    if (_job isEqualTo []) exitWith {};
    private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
    if (!(_settings get "enabled") || { (_job get "native") != (_entity get "active") } || { !([_entity] call IVCS_Combat_isAttackingGroup) }) exitWith { [_entity] call IVCS_Ammo_cancelGroup; };
    if ((_job get "scanIndex") >= 0 && { !([_entity,_job,_now,if (_limit < 0) then { -1 } else { if (_limit == 0) then { 0 } else { _settings get "needsUnitsPerSlice" } }] call IVCS_Ammo_scanNeeds) }) exitWith {};
    private _native = _job get "native";
    private _units = _entity get "units";
    private _requests = _entity get "ammoRequests";
    private _recipients = _job get "recipients";
    private _donors = _job get "donors";
    private _work = 0;
    private _checkedRecipient = -1;
    private _currentWanted = [];
    private _present = {
        params ["_unit"];
        _units findIf { _x isEqualRef _unit } != -1 && {
            if (_native) then { [_unit,true] call IVCS_Ammo_isEligible } else { (_unit get "damage") < 1 }
        }
    };
    private _availableFor = {
        params ["_donor","_compatible"];
        ([[_donor,_native] call IVCS_Ammo_snapshot] call IVCS_Ammo_surplus) select {
            private _magazine = _x;
            _compatible getOrDefault [_magazine select 0,false] && { !_native || {
                !isNull (_magazine select 4) && { (_recipient get "object") canAdd (_magazine select 0) }
            } } && {
                _requests findIf { (_x get "donor") isEqualRef _donor && { [_x get "token",_magazine select 3] call IVCS_Ammo_sameToken } } == -1
            }
        }
    };
    private _resetDonors = {
        _job set ["donorIndex",0]; _job set ["best",[]];
        _job set ["bestDonor",createHashMap]; _job set ["bestCount",-1];
    };
    while { (_job get "recipientIndex") < count _recipients && { _limit < 0 || { _work < _limit } } } do {
        (_recipients select (_job get "recipientIndex")) params ["_recipient","_wanted"];
        private _eligible = [_recipient] call _present && { _requests findIf { (_x get "recipient") isEqualRef _recipient } == -1 };
        if (!_eligible || { (_job get "weaponIndex") >= count _wanted }) then {
            if (_eligible) then { _recipient set ["ammoRetryAt",_now + (_settings get "retryDelay")]; };
            _job set ["recipientIndex",(_job get "recipientIndex") + 1]; _job set ["weaponIndex",0]; call _resetDonors;
        } else {
            private _weapon = _wanted select (_job get "weaponIndex");
            if (_checkedRecipient != (_job get "recipientIndex")) then {
                _currentWanted = [_recipient,_native] call IVCS_Ammo_getNeededWeapons;
                _checkedRecipient = _job get "recipientIndex";
            };
            if !(_weapon in _currentWanted) then {
                _job set ["weaponIndex",(_job get "weaponIndex") + 1]; call _resetDonors;
            } else {
                private _compatible = ([_weapon] call IVCS_Ammo_getWeaponProfile) select 2;
                if ((_job get "donorIndex") < count _donors) then {
                    private _donor = _donors select (_job get "donorIndex");
                    _job set ["donorIndex",(_job get "donorIndex") + 1];
                    if !(_donor isEqualRef _recipient) then {
                        _work = _work + 1;
                        if ([_donor] call _present) then {
                            private _available = [_donor,_compatible] call _availableFor;
                            if (count _available > (_job get "bestCount")) then {
                                private _candidate = [];
                                {
                                    if (_candidate isEqualTo [] || { (_x select 1) > (_candidate select 1) } || {
                                        (_x select 1) == (_candidate select 1) && { _native } && { (_x select 4) isEqualTo backpackContainer (_donor get "object") }
                                    }) then { _candidate = _x; };
                                } forEach _available;
                                if (_candidate isNotEqualTo []) then {
                                    _job set ["best",_candidate]; _job set ["bestDonor",_donor]; _job set ["bestCount",count _available];
                                };
                            };
                        };
                    };
                };
                if ((_job get "donorIndex") >= count _donors && { _limit < 0 || { _work < _limit } }) then {
                    private _best = _job get "best";
                    private _donor = _job get "bestDonor";
                    private _hadCandidate = _best isNotEqualTo [];
                    // Firing, pickups, death, and other requests may have changed a winner.
                    if (_best isNotEqualTo []) then {
                        // Rebuilding the winner's current inventory consumes a quota
                        // slot too; a full donor slice leaves it for a later frame.
                        _work = _work + 1;
                        if ([_donor] call _present) then {
                            private _token = _best select 3;
                            _best = if (_requests findIf { (_x get "donor") isEqualRef _donor && { [_x get "token",_token] call IVCS_Ammo_sameToken } } == -1) then {
                                [[_donor,_native] call IVCS_Ammo_snapshot,_token] call IVCS_Ammo_getReservedMagazine
                            } else { [] };
                            if (_best isNotEqualTo [] && {
                                !(_compatible getOrDefault [_best select 0,false]) || { _native && {
                                    isNull (_best select 4) || { !((_recipient get "object") canAdd (_best select 0)) }
                                } }
                            }) then { _best = []; };
                        } else { _best = []; };
                    };
                    if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;
                        _job set ["recipientIndex",(_job get "recipientIndex") + 1]; _job set ["weaponIndex",0];
                    } else {
                        // A stale winner is not evidence that no ally can share.
                        // Rescan this weapon in bounded slices before applying cooldown.
                        if (!_hadCandidate) then { _job set ["weaponIndex",(_job get "weaponIndex") + 1]; };
                    };
                    call _resetDonors;
                };
            };
        };
    };
    if ((_job get "recipientIndex") >= count _recipients) then {
        _entity set ["ammoSearch",[]];
        private _index = (_settings get "searchQueue") find (_entity get "id");
        if (_index != -1) then { (_settings get "searchQueue") deleteAt _index; };
    };
};
