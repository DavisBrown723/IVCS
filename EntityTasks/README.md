# Entity tasks

Templates define shared named states. Instances own their context, queue ID,
waypoints, and resources. Register templates during server startup and enqueue
fresh instances through IVCS_VirtualSpace_entityAddTask.

## Cancellation and replacement

    private _cancelled = [_entity, _taskID] call IVCS_EntityTasks_cancelTask;
    private _newID = [_entity, _taskID, _freshTask] call IVCS_EntityTasks_replaceTask;

Cancellation removes a queued instance, marks it cancelled, exits an entered
state once, releases its owned waypoints and resources, then invokes its callback
once. A pending task is never entered. Repeating cancellation returns false.
Removing the owner instead terminates its queued tasks with failed.

Replacement preserves the old queue slot and other queued work. It installs a
fresh instance with a new ID before cancelling the old instance, so the old
callback observes the replacement in the queue. The replacement starts on normal
queue processing; it does not inherit progress or context. An absent task
or a used replacement instance rejects the swap without changing the queue.

Instances are single-use, including tasks cancelled before they start. IDs are
allocated monotonically per entity and retained after finishing. Templates may
provide an onFinish(context) callback, which runs on completed, failed, and
cancelled exits before the instance callback. context.result identifies the exit.

Cancellation stops native AI movement when no other owner waypoints remain.
A later movement or boarding task releases that stop. Stopping creates no
placeholder MOVE task and leaves an otherwise empty task queue empty.

## Movement

    private _move = [_entity, _position, _radius, _speed] call IVCS_EntityTasks_createMoveTask;

The creator accepts entity, destination, optional radius (default 50), and speed
(default UNCHANGED). Named MOVE instance creation defaults to radius 7.
Virtual waypoints use a minimum 7 m completion radius; smaller radii are not
enforced.

## Waypoint options and ownership

    private _waypoint = [_position, "MOVE", [
        ["speed", "NORMAL"],
        ["completionRadius", 7],
        ["behavior", "SAFE"]
    ]] call IVCS_VirtualSpace_createEntityWaypoint;

Options are named pairs. Omitted options retain defaults. Supported properties
include speed, completionRadius, behavior, formation, combatMode, statements,
callbacks, attachedVehicle, timeout, and description. Task-specific properties
such as scripted and landingType can also be supplied. The constructor owns
position/type, generated names, and path bookkeeping.

entityAddWaypoint sets waypoint.entity to the live owner HashMap. Removal clears
that key, including completion, cancellation/replacement, and owner teardown.
Unattached and removed waypoints have no entity reference. Owner references are
runtime links; avoid deep-copying attached waypoint graphs.

Native waypoint import supplies the same complete defaults and leaves the
waypoint detached until attached. It removes standalone framework completion
calls while preserving user code, quoted strings, nested blocks, and comments.
The retained native code executes as one body to preserve private-variable scope.
Completion callbacks execute while the waypoint still has its owner.

## Landing and boarding

    private _landing = [_crew, _position, "LAND"] call IVCS_EntityTasks_createLandTask;
    private _boarding = [_group, _vehicle, _rendezvous] call IVCS_EntityTasks_createGetinTask;

The creators produce named task instances directly. _rendezvous is optional;
omitted or [-1,-1,-1] boards directly. Named instance creation also supports LAND
and GET IN.

LAND targets the first commanded helicopter. It approaches a task-owned invisible
helipad and requires actual touchdown in spawned simulation. GET IN/GET OUT
landing modes request low hover. Virtual landing updates height and engine state.
Completion and interruption delete the pad; cancellation also clears native
landing/approach orders. Its context accepts landingPosition, landingType, and
timeout (180 simulation seconds by default).

GET IN optionally moves to a rendezvous and signals with task-owned smoke, then
approaches the target. It requires enough non-driver seats for the whole group;
mixed pre-existing assignments fail rather than partially reserving seats.
Already fully assigned groups retain their assignments. Spawned completion waits
for actual occupants; virtual completion uses logical seat assignments.

Failed/cancelled boarding releases only reservations made by that task, removes
its cargo links, and stops its boarding orders, including ejecting passengers it
has already boarded. Completed boarding retains seats and cargo links. Missing
or destroyed targets and timeout fail the task. Context accepts vehicleID,
rendezvousPoint, and timeout (300 simulation seconds by default).

New tasks do not remove or suspend existing waypoint cycles. Cycles should be
created as part of the task that owns them. A later waypoint can remain blocked
behind such a cycle. Task cancellation removes only the owning task's waypoints.

Task callers use this framework. OPCOM/TACOM remain placeholders and are not
covered by the task regression suite.

See [engine regression runner](../tests/tasks/run.ps1) for running the local suite.
