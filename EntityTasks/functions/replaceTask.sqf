/*
    Swap a queued task for a fresh instance in the same slot.
    Install the replacement before cancelling the old task, so old callbacks
    observe a consistent queue. Returns the new ID or nil if the swap is invalid.
*/
params ["_entity", "_taskID", "_replacement"];
private _tasks = _entity get "tasks";
private _index = _tasks findIf { (_x get "id") == _taskID };
if (_index == -1) exitWith { nil };
private _previous = _tasks select _index;
private _newID = [_entity, _replacement] call IVCS_VirtualSpace_entityAddTask;
if (isNil "_newID") exitWith { nil };
// entityAddTask appended the replacement without invoking callbacks.
_tasks deleteAt (count _tasks - 1);
_tasks set [_index, _replacement];
[_entity, _previous, "cancelled"] call IVCS_EntityTasks_finishTask;
_newID
