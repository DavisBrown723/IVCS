// Service existing reservations atomically, snapshotting only their participants.
params ["_entity","_units","_now","_native"];
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
private _requests = _entity get "ammoRequests";
private _snapshots = createHashMap;
private _getSnapshot = {
    params ["_index"];
    private _snapshot = _snapshots get _index;
    if (isNil "_snapshot") then {
        _snapshot = [_units select _index,_native] call IVCS_Ammo_snapshot;
        _snapshots set [_index,_snapshot];
    };
    _snapshot
};
private _retained = [];
// Complete existing requests before creating any new ones.
{
    private _request = _x;
    private _recipient = _request get "recipient";
    private _donor = _request get "donor";
    private _recipientIndex = _units findIf { _x isEqualRef _recipient };
    private _donorIndex = _units findIf { _x isEqualRef _donor };
    private _reloading = (_request get "phase") == "reloading";
    private _valid = (_request get "native") == _native && { _recipientIndex != -1 } && { _reloading || { _donorIndex != -1 } } && { _now <= (_request get "expiresAt") };
    private _magazine = [];
    private _waiting = !_native && { !_reloading } && {
        ((_request get "phase") == "approaching" && { _now < (_request get "arriveAt") }) || {
            (_request get "phase") == "collecting" && { _now < (_request get "collectAt") }
        }
    };
    if (_valid && { _waiting }) then {
        // No collection can finish yet. Read current need and token ownership,
        // but defer expensive reserve reconstruction until arrival/transfer.
        (_request get "token") params ["_source","_record"];
        _valid = (_request get "weapon") in ([_recipient] call IVCS_Ammo_getNeededWeapons) && {
            (_record select 1) > 0 && { _source findIf { _x isEqualRef _record } != -1 } && {
                ((_donor get "magazineCargo") isEqualRef _source) || { (_donor get "weapons") findIf { (_x select 1) isEqualRef _source } != -1 }
            }
        };
    };
    if (_valid && { _reloading }) then { _valid = [_request, ([_recipientIndex] call _getSnapshot)] call IVCS_Ammo_reloadRequest; };
    if (_valid && { !_reloading } && { !_waiting }) then {
        private _weapon = _request get "weapon";
        private _compatible = ([_weapon] call IVCS_Ammo_getWeaponProfile) select 2;
        if (_native) then {
            private _snapshot = [_recipientIndex] call _getSnapshot;
            _valid = _weapon in (_snapshot select 2) && { (_snapshot select 3) findIf { (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] } } == -1 };
        } else {
            _valid = _weapon in ([_recipient] call IVCS_Ammo_getNeededWeapons);
        };
        if (_valid) then {
            _magazine = [([_donorIndex] call _getSnapshot),_request get "token"] call IVCS_Ammo_getReservedMagazine;
            _valid = _magazine isNotEqualTo [] && { _compatible getOrDefault [_magazine select 0, false] } && {
                !_native || { (_recipient get "object") canAdd (_magazine select 0) }
            };
        };
    };
    if (_valid && { !_reloading } && { !_waiting }) then {
        private _near = !_native;
        if (_native) then {
            private _object = _recipient get "object";
            private _target = _donor get "object";
            _near = (_object distance _target) <= (_settings get "collectionDistance");
            if (!_near) then {
                _request set ["phase", "approaching"];
                _request set ["collectAt", -1];
                if (_now >= (_request get "nextMoveAt")) then {
                    [_object, _target] call IVCS_Ammo_approach;
                    _request set ["nextMoveAt", _now + (_settings get "scanInterval")];
                };
            };
        } else { _near = _now >= (_request get "arriveAt"); };
        if (_near) then {
            if ((_request get "phase") != "collecting") then {
                _request set ["phase", "collecting"];
                // Virtual arrival has an exact timestamp even between combat ticks.
                // A late poll must not restart its already elapsed collection delay.
                private _arrivedAt = if (_native) then { _now } else { _request get "arriveAt" };
                _request set ["collectAt", _arrivedAt + (_settings get "collectionDelay")];
                if (_native) then {
                    private _object = _recipient get "object";
                    doStop _object;
                    _object setDir (_object getDir (_donor get "object"));
                    _object playActionNow "PutDown";
                };
            };
            if (_now >= (_request get "collectAt")) then {
                // End collection before adding ammo can start an automatic reload.
                if (_native) then { (_recipient get "object") playActionNow "Stop"; };
                private _success = [_recipient, _donor, _request get "weapon", _magazine, _native] call IVCS_Ammo_transfer;
                if (_success) then {
                    _entity set ["ammoTransfers", (_entity get "ammoTransfers") + 1];
                    _request set ["delivered", [_request get "weapon", _magazine select 0]];
                };
                _valid = _success && { _native };
                if (_valid) then {
                    _request set ["phase", "reloading"];
                    _request set ["expiresAt", _now + (_settings get "reloadTimeout")];
                    private _object = _recipient get "object";
                    _object forceWalk (_request get "oldForcedWalk");
                    _object selectWeapon (_request get "weapon");
                };
                // Other requests must revalidate against the edited inventories.
                { _snapshots deleteAt _x; } forEach [_recipientIndex,_donorIndex];
            };
        };
    };
    if (_valid) then { _retained pushBack _request; } else {
        [_entity, _request] call IVCS_Ammo_releaseRequest;
        _recipient set ["ammoRetryAt", if ((_request getOrDefault ["delivered", []]) isEqualTo []) then { _now + (_settings get "retryDelay") } else { _now }];
    };
} forEach _requests;
_requests resize 0;
_requests append _retained;
