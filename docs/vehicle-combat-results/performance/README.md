# Vehicle combat performance — 25 October 2026

All eight windows passed **44 workload checks**, including simulated-time progress, firing, delivery and cleanup. The trace contains **2,674 measured frames** across two 12-second windows per mode, with the phase order reversed in the second trial. Each phase runs 20 engagements: 20 eight-man infantry squads, 20 passive APCs and 20 two-man crew groups (40 groups, 20 vehicles, 200 infantry).

These are precise Tracy wall times for IVCS work on a local dedicated server with Arma Script Profiler enabled. They are not the entire Arma frame time. Production settings remain 1-second combat resolution, 3 ms combat budget and eight engagements per scheduler pass. The comparison swaps four frozen resolver functions while sharing current metadata and scheduling.

| Resolver / scenario | Frames | Mean ms | p50 | p90 | p95 | p99 | Max | >1 ms | >5 ms | >10 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Original, normal ammo | 668 | 1.358 | 0.666 | 3.515 | 4.176 | 4.389 | 5.368 | 191 | 1 | 0 |
| Expanded, normal ammo | 669 | 1.424 | 0.747 | 3.579 | 4.143 | 4.665 | 5.259 | 209 | 1 | 0 |
| Original, forced shortage | 668 | 1.644 | 0.756 | 4.003 | 4.297 | 4.547 | 5.483 | 308 | 2 | 0 |
| Expanded, forced shortage | 669 | 1.692 | 0.783 | 4.107 | 4.359 | 4.627 | 5.699 | 291 | 4 | 0 |

The expansion adds about **0.28 ms to normal-ammunition p99** and **0.08 ms to forced-shortage p99** in this run. A short pair of windows does not establish a stable hardware-wide p99; the complete samples and per-trial results are retained rather than treating the coarse RPT clock as authoritative.

## Attribution

Normal-ammunition magazine selection averages **0.039 ms/call**, down from **0.051 ms** with the original resolver. The expanded vehicle firing step averages **0.429 ms**, compared with **0.463 ms** originally. Applying a successful vehicle hit averages **0.269 ms**, up from **0.031 ms**, reflecting the recorded component deltas and occupant injury/casualty calculation. These are nested inclusive timings: do not add them together. The trace exports also retain self-time rankings.

The slowest 1% of expanded, normal ammo frames average 4.815 ms total: 4.441 ms combat, 0.295 ms entity updates, and 0.010 ms native-ammo queue work. The exact worst-frame timestamps are in the operation report.
The slowest 1% of expanded, forced shortage frames average 5.162 ms total: 4.784 ms combat, 0.290 ms entity updates, and 0.010 ms native-ammo queue work. The exact worst-frame timestamps are in the operation report.

The tail is mostly accumulated combat work, rather than one extreme vehicle-hit call. No measured frame exceeded 10 ms. Forced shortages completed all 20 initial deliveries in each window; subsequent searches/requests can remain active after the recipient fires its delivered rocket.

Benchmark-only wrappers keep targets and crew alive to sustain comparable work. Damage and injury/casualty decisions execute, but actual roster/entity removal is intercepted; mass destruction cleanup, cold profile construction, native spawning and capture spikes are excluded. Mines/charges and AA/boat workloads have functional coverage but are not represented by this APC timing fixture.

## Capture and reproduction

The bundled recorder completed and compressed its save: **180.1 seconds, 5,001 recorder frames, 422,091 zones, 4 ns timer resolution**. The saved file is **2,720,282 bytes**, a Tracy container using **Zstd** with four streams. The RPT identifies Arma 3 **2.22 / build 154126**, Windows x64, profiling branch, at `accTime = 1`. The bundled exporter does not expose CPU/host metadata here. Its maximum event-end timestamp (208.23 seconds) is relative to application profiling startup, not the connected recording duration.

`C:/Users/spyde/.codex/skills/capture-tracy/captures/vehicle-expansion-20261025-001505.tracy`

Repeat the workload with `tests/combat/vehicle-performance.ps1 -Seconds 12 -Trials 2 -GroupCounts 20`. Add `-ProfilerMarkers` with the installed CBA, Intercept Minimal Dev and Arma Script Profiler mods to capture the named scopes. Use the matching bundled recorder; verify save completion before analysis.

Evidence: [precise aggregate statistics](vehicle-expanded-precise-summary.json), [per-trial operation attribution](vehicle-expanded-operations-summary.json), [RPT validation and coarse samples](vehicle-expanded-summary.json), all RPT frame samples (raw frame samples retired), [frame trace report](../trace-root.json), and [vehicle function trace report](../trace-vehicle.json).
