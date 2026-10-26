// Keep connected spawn/despawn calls and the spawner on the same state.
params ["_entity", "_active"];

_entity set ["active", _active];
private _id = _entity get "id";
private _entities = IVCS_VirtualSpace_Controller get "entities";
private _previousIDs = _entities get (if (_active) then { "inactive" } else { "active" });
private _index = _previousIDs find _id;
if (_index != -1) then { _previousIDs deleteAt _index; };

// Teardown callbacks may despawn an owner after it has left the registry.
if (_id in (_entities get "ALL")) then {
    (_entities get (if (_active) then { "active" } else { "inactive" })) pushBackUnique _id;
};
