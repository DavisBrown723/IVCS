// Standalone waypoint sequences use the same activation lifecycle as other tasks.
[
    "WAYPOINTS",
    [["following", [["onUpdate", {
        if ((_this get "waypoints") findIf { _x getOrDefault ["pathFailed", false] } != -1) exitWith { "failed" };
        if ((_this get "waypoints") isEqualTo []) then { "completed" } else { "" }
    }]]], ["completed", [["isEndState", true]]], ["failed", [["isEndState", true], ["result", "failed"]]]],
    "following"
] call IVCS_EntityTasks_createTaskTemplate;
