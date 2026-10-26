// Commit a reservation only after the resumable search revalidates its winner.
params ["_entity","_recipient","_donor","_weapon","_magazine","_now","_native"];
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
private _request = createHashMapFromArray [
    ["recipient",_recipient],["donor",_donor],["weapon",_weapon],["token",_magazine select 3],
    ["native",_native],["phase","approaching"],["collectAt",-1],
    ["nextMoveAt",_now + (_settings get "scanInterval")],
    ["arriveAt",_now + (_settings get "virtualApproachDelay")],["expiresAt",_now + (_settings get "approachTimeout")],
    ["oldCommand",""],["oldDestination",[]],["oldForcedWalk",false]
];
if (_native) then {
    private _object = _recipient get "object";
    _request set ["oldForcedWalk",isForcedWalk _object];
    _request set ["oldCommand",currentCommand _object];
    _request set ["oldDestination",(expectedDestination _object) select 0];
    [_object,_donor get "object"] call IVCS_Ammo_approach;
    (_settings get "nativeQueue") pushBackUnique (_entity get "id");
};
(_entity get "ammoRequests") pushBack _request;
_recipient set ["ammoRetryAt",_now + (_settings get "retryDelay")];
