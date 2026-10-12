params [
    "_entity",
    "_destinationPos",
    ["_completionRadius", 50],
    ["_moveSpeed", "UNCHANGED"]
];
["MOVE", [
    ["destination", _destinationPos],
    ["completionRadius", _completionRadius],
    ["speed", _moveSpeed]
]] call IVCS_EntityTasks_createTaskInstance
