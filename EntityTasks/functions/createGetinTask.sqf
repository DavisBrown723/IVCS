params ["_entity", "_vehicleToBoard", ["_rendezvousPoint", [-1, -1, -1]]];
["GET IN", [
    ["vehicleID", _vehicleToBoard get "id"],
    ["rendezvousPoint", if (_rendezvousPoint isEqualTo [-1, -1, -1]) then { [] } else { +_rendezvousPoint }]
]] call IVCS_EntityTasks_createTaskInstance
