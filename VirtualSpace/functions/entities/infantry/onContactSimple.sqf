params ["_entity","_nearEnemies"];

// private _currentEngagementTask = _entity get "currentEngagementTask";
// if (_currentEngagementTask isequalto "") then {
//     private _enemiesByDistance = [_nearEnemies, [], {
//         _entityPos distance (_x get "position")
//     }] call BIS_fnc_sortBy;

//     private _closestEngageableEnemy = _enemiesByDistance findIf {
//         [_entity, _x] call IVCS_VirtualSpace_Infantry_canEngageEntity
//     };
//     if (_closestEngageableEnemy != -1) then {
//         _entity set ["currentEngagementTask", "true"]; // REMOVE
//         systemchat format ["Beginning attack on %1", _closestEnemy get "id"];
//     };
// };