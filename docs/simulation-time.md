# Shared simulation time

IVCS exposes two globals after `IVCS/startup.sqf`:

```sqf
IVCS_SimulationTime    // elapsed simulation seconds since IVCS starts
IVCS_SimulationPaused  // sampled isGamePaused state
```

`Common/functions/internal/startSimulationClock.sqf` registers one `EachFrame` handler before gameplay handlers. It starts time at zero on each machine. Repeated startup preserves both time and the existing handler. The server's clock drives authoritative gameplay; this is not a network-synchronized client timestamp.

Every frame, `Common/functions/internal/updateSimulationTime.sqf` samples `diag_tickTime`, `isGamePaused` and `accTime`. While unpaused, it adds the elapsed real seconds multiplied by the current acceleration. At 5x, one real second adds five simulation seconds. It refreshes the real-time baseline even while paused, so resuming cannot replay the paused interval. Acceleration changes apply per frame, even when individual entities are visited less often. A zero speed does not imply that Arma is paused.

Bohemia documents that EachFrame continues during pause, and that isGamePaused always returns false in multiplayer: a player's pause menu does not pause the server. See [isGamePaused](https://community.bistudio.com/wiki/isGamePaused).

## Migrated gameplay timers

- Virtual group and vehicle timestamps and movement deltas.
- Combat discovery, engagement updates, native handoff and task pause accounting.
- Virtual and live ammo search, approach, collection, retry and reload deadlines.
- Boarding and landing task timeouts, including task suspension and resumption.
- Delayed and repeating gameplay callbacks in the Execution module.
- Movement path request failure timeouts.

Combat no longer maintains its own `clock` or `lastFrame`. A combat step now represents one **simulation second**. Fire intervals, reloads and damage calculations retain their existing simulation-second values. The previous reference average of 166.15 seconds is therefore approximately 166 simulation seconds, or 33 real seconds at 5x if processing keeps up. This supersedes the earlier request to keep virtual combat near three real minutes regardless of acceleration.

Direct combat and ammo update APIs still accept explicit simulation timestamps for deterministic batch callers. They must use the same epoch consistently within a scenario. Runtime callers can omit the argument to use the shared clock.

CPU budgets, profiler durations and benchmark measurement windows continue using `diag_tickTime`. Background maintenance/strategic scan schedules retain their existing real-time cadence. The clock does not change Arma's acceleration setting, native AI logic, frame budgets or queue quotas.

## Verification

Run the clock and timer integration checks with:

```powershell
powershell -File tests/tasks/run.ps1 -TestScript tests/simulation/time.sqf -Port 2514 -TimeoutSeconds 120
```

The dedicated-server test uses real frame sampling plus explicit timestamp, pause and scale inputs to the production accumulator. It tests simulated pause transitions and 5x integration, rather than claiming that the multiplayer server itself can be paused. It also exercises the production movement, combat, ammo, task, path and execution consumers. The generic engine test mission starts the shared clock before spawning each regression script.

Completed verification on 14 October 2026: **792 checks passed, zero failed**, including 30 focused clock checks, the full task suite (211), virtualization (96), normal demo startup (11), combat and ammo regressions, and the normal/shortage progress smoke run (11). The final smoke mission contains byte-identical copies of the 28 migrated production sources, all using CRLF. See [verification evidence](simulation-time-results/verification.json) and [smoke results](simulation-time-results/clock-smoke-summary.json). The initial undersized task-runner timeout and profiler-loader parse attempt are excluded from completed-check totals; both were corrected and rerun.
