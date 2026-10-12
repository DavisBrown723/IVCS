// Returns false for an absent task; cancellation has no repeat effects.
params ["_entity", "_taskID"];
private _task = [_entity, _taskID] call IVCS_VirtualSpace_getEntityTask;
if (isNil "_task") exitWith { false };
[_entity, _task, "cancelled"] call IVCS_EntityTasks_finishTask;
true
