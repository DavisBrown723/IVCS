// Active requests receive frequent checks even when ordinary entity updates
// are spread over many frames. The group budget bounds work in large missions.
if (IVCS_SimulationPaused) exitWith {};
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
private _queue = _settings get "nativeQueue";
private _count = count _queue min (_settings get "groupsPerFrame");
for "_i" from 1 to _count do {
    if (_queue isEqualTo []) exitWith {};
    private _id = _queue deleteAt 0;
    private _entity = [_id] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        [_entity] call IVCS_Ammo_updateGroup;
        if (_entity get "active" && { (_entity get "ammoRequests") isNotEqualTo [] }) then { _queue pushBackUnique _id; };
    };
};
