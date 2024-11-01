if (isGamePaused) exitwith {};

[] call IVCS_VirtualSpace_simulateEntities;

private _spawnerFSM = IVCS_VirtualSpace_Controller get "spawnerFSM";
[_spawnerFSM] call IVCS_FSM_execute;

// if (diag_tickTime - IVCS_VirtualSpace_KnownEntityInfo_TimeLastUpdate > 60) then {
//     private _confidenceDegradation = 1 / 60;

//     {
//         private _side = _x;
//         private _knownTargets = IVCS_VirtualSpace_KnownEntityInfo get _side;

//         {
//             private _targetInfo = _knownTargets get _x;
//             if (!isnil "_targetInfo") then {
//                 _targetInfo params ["_unitType","_confidence"];

//                 private _newConfidence = _confidence - _confidenceDegradation;
//                 if (_newConfidence <= 0) then {
//                     _knownTargets set [_x, nil];
//                 } else {
//                     _targetInfo set [1, _confidence - _confidenceDegradation];
//                 };
//             };
//         } foreach (keys _knownTargets);
//     } foreach (keys IVCS_VirtualSpace_KnownEntityInfo);

//     IVCS_VirtualSpace_KnownEntityInfo_TimeLastUpdate = diag_tickTime;
// };