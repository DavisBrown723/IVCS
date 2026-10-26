# Virtual combat performance

## Combat resolution - 25 October 2026

Combat resolution instrumentation identified repeated infantry weapon-selection setup, vehicle crew-damage preparation and engagement registry lookups. Four production functions now avoid that work. Budgets, resolution intervals, weapon ranges, damage probabilities and ammunition consumption remain unchanged.

### Instrumentation and fixes

The detailed diagnostic records **1,932 measured frames**, **351 complete exchanges** and **18/18 passing workload checks**. It separates infantry shooters, mounted stations, turret magazine preparation, damage application, occupants, body-hit selection, splash geometry and due versus idle engagement updates. Numeric context is buffered and serialized after the measured frame scope closes.

| Selected diagnostic operations inside combat | Calls | Inclusive total ms |
| --- | ---: | ---: |
| Infantry shooter visits | 4212 | 164.283 |
| Infantry weapon selection | 3324 | 115.068 |
| Vehicle damage, including crew and test restoration | 1574 | 227.380 |
| Crew damage | 1574 | 131.849 |
| Ammo group updates | 702 | 120.015 |
| Turret shot selection | 813 | 96.607 |
| Return-fire station lookup | 813 | 82.018 |

These rows overlap: crew damage is included in vehicle damage, and weapon/damage work is included in shooter visits. They must not be summed. Turret selection visits 1,164 weapons and 2,568 magazine records, with 571 preparation misses and 1,053 negative records (including both newly prepared and cached results). The largest diagnostic exchange is 3.708 ms; the largest whole frame is 8.125 ms.

The production changes are:

- getVehicleShot filters immutable AA weapon capabilities before allocating selection state when distant or AA-only air fire excludes other weapons. Current magazine records, rounds, mounting, range and fuse checks still run for candidates. The close-range utility path remains available through exactly 35 m. No inventory or readiness cache is introduced.
- damageVehicle passes its existing vehicle profile to damageCrew. The latter keeps the existing five-argument call valid, avoids owner deduplication when there is no cargo, and retrieves body weights only when an occupant actually suffers injury. Seeded random draws, owner order, casualties and hitpoints match the archived implementation.
- update reads the entity registry once and uses direct lookups for primary groups and supporters. Existing missing-entity, transition, contact, pending-time and timeout checks remain intact. Idle polls are still performed.

The pre-change versions of all four functions are archived together in tests/combat/resolution-baseline. Review found no further required correctness changes or assertion guards to remove.

### Matched 20-group results

Both comparisons use **20 total groups, five engagements, ten AA supporters, 85 units and 30 entities**, with the existing dense-frontline helicopter/infantry/AA workload. Four 35-second windows run before/after/after/before, with paired seeds and two-second warmup. Startup, setup and teardown are excluded. The harness swaps all four functions together outside timed frames; baseline vehicle damage remains underneath the same test-only immortality wrapper.

**No budgets are lowered:** 3 ms soft combat budget, eight engagement visits, ten entity visits, 1 ms ammo-search allowance, one-second resolution and one-second discovery. accTime = 1. Detailed resolution diagnostics are disabled for comparison; standard scopes are identical across versions.

All four precise windows have complete BEGIN/END boundaries and exact RPT frame-count matches, with **1,940 before / 1,937 after frames** and no exclusions. Individual samples are pooled, rather than averaging trial percentiles.

| Precise milliseconds per real server frame | Before | After |
| --- | --- | --- |
| Whole-IVCS mean | 1.587 | 1.523 |
| Whole-IVCS p95 | 5.113 | 4.976 |
| Whole-IVCS p99 | 6.460 | 6.226 |
| Whole-IVCS maximum | 7.351 | 7.609 |
| Combat frame mean | 0.683 | 0.621 |
| Combat frame p95 | 4.375 | 4.091 |
| Combat frame p99 | 5.459 | 5.206 |
| Combat frame maximum | 6.291 | 6.793 |

Whole-IVCS pooled p99 falls **3.6%** and combat-frame p99 **4.6%**. Paired whole-frame p99 values are **6.503 -> 6.302 ms** and **6.236 -> 6.147 ms**: both improve in this run. Combat-frame mean falls **9.1%**, and whole-IVCS mean **4.1%**.

| Operation, complete precise windows | Calls before / after | Mean ms before / after | p99 ms before / after | Maximum ms before / after |
| --- | --- | --- | --- | --- |
| Infantry weapon selection | 3324 / 3330 | 0.0339 / 0.0193 | 0.0861 / 0.0851 | 0.1929 / 0.2163 |
| Crew damage | 1587 / 1592 | 0.0635 / 0.0577 | 0.1173 / 0.1211 | 0.1643 / 0.2024 |
| Vehicle damage (includes crew and test restoration) | 1587 / 1592 | 0.1124 / 0.1071 | 0.2039 / 0.2047 | 0.3111 / 0.3148 |
| Complete exchange | 351 / 352 | 1.9745 / 1.8174 | 2.8632 / 3.0418 | 3.2649 / 5.5625 |

Mean infantry weapon-selection cost falls **43.2%**, crew damage **9.2%**, and complete exchanges **8.0%**. Per-exchange p99 and maximum increase, so these results do not establish that every exchange or spike is cheaper. Idle engagement polling means fall from 0.0283/0.0279 ms in baseline windows to 0.0209/0.0211 ms after; time outside resolution in due updates remains approximately 0.45-0.48 ms.

| Unprofiled milliseconds per real server frame | Before | After |
| --- | --- | --- |
| Whole-IVCS mean | 1.399 | 1.348 |
| Whole-IVCS p95 | 4.990 | 4.005 |
| Whole-IVCS p99 | 5.997 | 5.997 |
| Whole-IVCS maximum | 12.009 | 8.003 |

The unprofiled comparison contains **3,863 frames** and uses an approximately 1 ms clock. Mean and p95 improve, while p99 remains approximately **6 ms**. The precise result is a modest measured improvement, with no unprofiled p99 improvement resolved by the coarse clock. Together both comparisons pass **72/72 workload checks across 7,740 measured frames**.

All rosters, five engagements and ten supporters survive. Combat advances 34-36 seconds over approximately 35 simulation seconds. Precise before/after shot totals are **820/827 helicopter**, **110/108 infantry AA** and **3,187/3,194 AA vehicle** shots. Unprofiled totals are **797/827**, **104/112** and **3,156/3,194** respectively. Window-boundary and scheduling differences remain visible; no ammunition transfers occur. Precise frame exchange counts are retained in the comparison JSON: baseline windows have 231 active frames with 351 exchanges, optimized windows 225 active frames with 352 exchanges, including one three-exchange frame. The unchanged soft budget can admit additional exchanges when earlier work completes sooner.

### Remaining tail and validation

The worst optimized whole frame is **7.609 ms**, with **6.793 ms combat**, **0.732 ms entities** and one **5.562 ms exchange**. That exchange includes two infantry-versus-vehicle directions totaling 3.766 ms, 12 weapon selections totaling 0.767 ms, eight vehicle damage calls totaling 1.079 ms (including 0.521 ms crew damage), a mounted-station step of 0.578 ms and a return-fire step of 0.733 ms. These nested measurements overlap. Elevated costs span several operations; this trace does not isolate the transient to a single command.

The optimized exchange p99 is **3.042 ms**, versus **2.863 ms** before, despite the lower exchange mean. The optimized whole-frame maximum is also higher, **7.609 versus 7.351 ms**. These samples are retained, and neither version exceeds 10 or 16.67 ms. Combat resolution remains the dominant frame tail. Further work should separate repeated station/selection preparation and per-occupant damage loops under heavier firing events, without assuming that a single elevated call explains the entire transient.

**1,112/1,112 engine correctness checks pass** across focused resolution (762), core combat (71), ground vehicles (58), return fire (43), AA readiness (95), scheduling (12), helicopter tactics (50) and helicopter review (21). Differential tests cover stock rifle/AA/AT/LAT/GL loadouts, ground and air targets, close-range boundaries, cold/warm caches, live ammunition and weapon changes, and seeded crew damage across cargo/duplicate owners/lethal and nonlethal outcomes. The existing 20-seed infantry calibration remains 178.1 simulation seconds on average. A separate final-source instrumentation smoke passes **9/9 checks**, after timing runs finish.

All 256 production source hashes remain unchanged through measurement. Archived baselines match the preceding flight-update source manifest. All SQF writes use CRLF.

Both traces saved normally: the diagnostic spans **150.2 seconds** (150.1 elapsed), **497,640 zones**, **3,289,357 bytes**; comparison spans **240.2 seconds** (240.1 elapsed), **865,959 zones**, **5,608,426 bytes**. Both use Tracy/Zstd, four streams and a 4 ns timer. Recorder spans define duration; exporter aggregate-percent duration estimates are not used. Environment/session evidence records Windows 10, i7-10700F, Arma 2.22 build 154126 and accTime = 1. Raw captures/events/messages stay outside Git. Owned servers and recorders exited normally.

These are server-side IVCS script costs with virtual groups and test-only immortality, whose restoration overhead is included identically. They do not measure native AI/rendering, client FPS, forced ammunition shortages, or every helicopter mission profile.

- [Shot selection](../VirtualSpace/functions/combat/getVehicleShot.sqf), [crew damage](../VirtualSpace/functions/combat/damageCrew.sqf), [vehicle damage](../VirtualSpace/functions/combat/damageVehicle.sqf), and [engagement update](../VirtualSpace/functions/combat/update.sqf).
- [Detailed scopes](../tests/combat/resolution-scopes.sqf), [context analyzer](../tests/combat/analyze-resolution-tracy.py), [focused fixture](../tests/combat/resolution.sqf), and [runner](../tests/combat/resolution.ps1).
- [Configuration and comparison](combat-performance-results/resolution-comparison.json), [source hashes](combat-performance-results/resolution-source-manifest.json), [correctness](combat-performance-results/resolution-correctness.json), [instrumentation smoke](combat-performance-results/resolution-instrumentation-smoke.json), and [environment](combat-performance-results/resolution-environment.json).
- [Diagnostic attribution](combat-performance-results/resolution-diagnostic-attribution.json), [diagnostic inclusive/self scopes](combat-performance-results/resolution-diagnostic-scopes.json), and [diagnostic session](combat-performance-results/resolution-diagnostic-session.json).
- [Unprofiled results](combat-performance-results/resolution-unprofiled-summary.json), [unprofiled samples](combat-performance-results/resolution-unprofiled-frames.csv), [precise pooled results](combat-performance-results/resolution-profiled-precise-summary.json), and [precise workload validation](combat-performance-results/resolution-profiled-summary.json).
- [Per-window operations](combat-performance-results/resolution-profiled-operations-summary.json), [remaining exchange attribution](combat-performance-results/resolution-profiled-resolution-attribution.json), [remaining entity maxima](combat-performance-results/resolution-profiled-attribution.json), [frame inclusive/self scopes](combat-performance-results/resolution-frame-scopes.json), and [capture session](combat-performance-results/resolution-session.json).

## Helicopter flight updates - 25 October 2026

Helicopter updates now share one current crew/waypoint lookup between flight policy and attack-area validation. Virtual evasion skips offensive-pass queries whose result is unused, and aircraft already at their destination skip velocity integration and their own no-op position write. Crew positions are still synchronized. Position copying moves into the forced-descent branch, where mutation requires a separate array.

Health, pilot, rotor, speed, threat expiry, current orders and area boundaries are still checked every update. Native hold-fire queries remain intact, and moving-aircraft calculations are unchanged. Shared order inputs exist only for the duration of the call: there is no persistent order cache or invalidation timer. Existing single-argument policy/area callers retain their behavior. Empty crew/waypoint inputs explicitly preserve defaults for uncrewed UAVs and aircraft without orders.

Production changes are limited to `updateHelicopter`, `getHelicopterPolicy` and `getHelicopterAttackArea`. **No budgets or cadences change:** 3 ms soft combat budget, eight engagement visits, ten entity visits, 1 ms ammo-search allowance, one-second resolution and one-second discovery interval.

### Instrumentation and findings

New test-only scopes separate health checks, evasion, area validation, destination/leash work, motion integration, position/grid helpers and grid entry searches. Numeric motion/grid context is buffered and serialized after the measured frame scope closes.

The diagnostic passes **18/18 workload checks** over **1,932 frames**. All **3,220 helicopter calls** have matching context rows; **2,991 (92.9%) are stationary**, and all measured aircraft are evading sustained incoming AA. The largest helicopter update is **1.331 ms**, at its exact destination with zero velocity. The next two large stationary calls occur within the same approximately 0.444-second cluster.

| Selected diagnostic stages inside helicopter calls | Inclusive total ms |
| --- | ---: |
| Health checks | 86.387 |
| Flight policy | 108.733 |
| Attack-area lookup | 71.999 |
| Offensive-pass query | 41.169 |
| Motion integration | 41.070 |
| Position updates, including grid work | 67.016 |
| Work outside the selected disjoint stages | 187.984 |

These stage totals cover the complete measured diagnostic windows. Nested profile/registry/grid helpers are already included in their parents. Additional evasion, area-check and leash stages are retained in the evidence. Diagnostic overhead is included; this is attribution rather than a before/after comparison.

The largest call includes 0.169 ms health, 0.071 ms policy, 0.127 ms attack-area lookup, 0.033 ms pass query and 0.038 ms zero-motion integration, with **0.753 ms outside the selected named stages**. The capture identifies avoidable repeated work but does not isolate the entire transient spike to one operation. The grid-entry search is cheap in this workload (capture-wide total 3.455 ms, maximum 0.012 ms) and does not run in that stationary call; spatial-grid production code is unchanged.

### Matched 20-group results

Both measurement runs retain **20 total groups, five engagements, ten AA supporters, 85 units and 30 entities**. The dense-frontline layout, 600 m attack areas, test-only immortality and supplied magazines match the preceding benchmark. Four 35-second windows use before/after/after/before order, paired seeds and two-second warmup.

The harness swaps all three flight functions together outside timed frames. It now accepts a manifest of function overrides while preserving older single-function baselines. Standard profiler scopes are identical in both versions; detailed flight diagnostics are disabled during comparison.

All four precise windows have complete BEGIN/END boundaries and exact frame counts matching the RPT: **1,923 before / 1,931 after frames**, no exclusions. Individual frame samples are pooled, not trial percentiles.

| Precise milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.614 | 1.570 |
| Whole-IVCS p95 | 5.270 | 5.155 |
| Whole-IVCS p99 | 6.422 | 6.352 |
| Whole-IVCS maximum | 8.315 | 7.108 |
| Entity-update mean | 0.877 | 0.833 |
| Entity-update p95 | 1.110 | 1.063 |
| Entity-update p99 | 1.227 | 1.188 |
| Entity-update maximum | 2.137 | 1.634 |
| Combat-frame mean | 0.669 | 0.669 |
| Combat-frame p99 | 5.367 | 5.525 |

| Helicopter update, complete precise windows | Before | After |
| --- | ---: | ---: |
| Calls | 3205 | 3218 |
| Total inclusive ms | 485.7685 | 410.1750 |
| Mean ms/call | 0.1516 | 0.1275 |
| p50 ms/call | 0.1479 | 0.1238 |
| p90 ms/call | 0.1904 | 0.1604 |
| p95 ms/call | 0.2416 | 0.2116 |
| p99 ms/call | 0.2936 | 0.2745 |
| Maximum ms/call | 0.4633 | 0.3425 |
| Calls above 1 / 5 / 10 ms | 0 / 0 / 0 | 0 / 0 / 0 |

Helicopter mean falls **15.9%**, and helicopter p99 **6.5%**. Entity mean falls **5.0%**, and entity p99 **3.2%**. Both versions still perform approximately 1.667 helicopter updates and exactly ten discovery visits per frame; this removes work inside existing visits.

Entity-stage offensive-pass queries fall **3,205 -> 0** in this sustained-evasion workload. Combat still makes **349 / 350** integrated firing-window queries. Total pass-scope calls therefore fall 3,554 -> 350; the remaining calls have different, more expensive work, so their per-call means are not directly comparable. Policy and area helper means, including other combat callers, fall approximately 0.0255 -> 0.0197 ms and 0.0158 -> 0.0113 ms.

Whole-IVCS pooled p99 moves **6.422 -> 6.352 ms (1.1%)**, but paired results are **6.449 -> 6.188 ms** and **6.354 -> 6.602 ms**. The second pair regresses. The measured helicopter improvement does **not** establish a reliable whole-frame p99 reduction. Combat means remain effectively identical at 0.669 ms/frame.

| Unprofiled milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.382 | 1.360 |
| Whole-IVCS p99 | 5.878 | 5.997 |
| Whole-IVCS maximum | 7.004 | 7.004 |
| Entity-update mean | 0.916 | 0.906 |
| Entity-update p99 | 1.007 | 1.007 |

The unprofiled run contains **3,834 frames**, with an approximately 1 ms clock. Whole-frame p99 stays around 6 ms and shows no improvement; the interpolated baseline p99 of 5.878 ms versus 5.997 ms after is retained. Means decrease slightly. Together the two comparisons pass **72/72 workload checks across 7,688 measured frames**.

All rosters, engagements and ten supporters survive; combat advances 34-36 seconds over approximately 35 simulation seconds. Precise before/after shot totals are 804/811 helicopter, 104/106 infantry AA and 3,163/3,173 AA-vehicle shots. Unprofiled totals are 794/805, 104/106 and 3,157/3,165. Scheduling/window-boundary differences remain visible. No ammo transfers occur. This workload predominantly measures stationary evasion under sustained AA, not native AI/rendering, forced shortages or every helicopter mission profile.

### Remaining tail and validation

The worst optimized whole frame is **7.108 ms**, including **6.310 ms combat** and **0.727 ms entities**, with two exchanges and a largest exchange of 2.697 ms. Combat resolution remains the dominant whole-frame tail. The worst optimized entity frame is **1.634 ms**, including 0.446 ms across two helicopter updates and 0.466 ms air defense. The largest individual optimized helicopter call is 0.342 ms. Neither version exceeds 10 or 16.67 ms in the precise comparison.

The 1.331 ms diagnostic call did not recur in either precise version, so the maximum reduction is not proof that every transient spike is eliminated. Further whole-frame p99 work should target combat resolution, with finer scopes required for any future unscoped helicopter spike.

**180/180 correctness checks pass:** 50 focused flight checks, 59 general helicopter, 50 tactics and 21 helicopter-review checks. Differential cases match the archived update code across movement speeds, zero/short/long timesteps, evasion and transport/attack roles. Checks also cover no-waypoint defaults, inherited order changes, new objective areas, expired threats, native hold-fire, uncrewed UAVs, stationary crew synchronization, immediate boundary/mobility changes and position aliasing during descent. Review found no further required changes. All SQF writes use CRLF.

A separate five-second smoke run passes **9/9 checks** with detailed flight scopes installed against the final optimized source; it is excluded from performance comparisons and starts after both timing runs have ended.

Both traces saved normally: the diagnostic is **150.1 seconds**, **813,953 zones**, **4,924,402 bytes**; the comparison is **240.1 seconds**, **859,467 zones**, **5,607,011 bytes**. Both use Tracy/Zstd, four streams and a 4 ns timer. Recorder spans define duration; exporter aggregate-percent estimates are not used. Embedded environment strings are unavailable from the compressed-header reader; separate environment/session evidence records Windows, i7-10700F, Arma 2.22 build 154126 and `accTime = 1`. Raw traces/events/messages stay outside Git. Owned servers and recorders exit normally.

- [Flight update](../VirtualSpace/functions/combat/updateHelicopter.sqf), [policy](../VirtualSpace/functions/combat/getHelicopterPolicy.sqf), and [area lookup](../VirtualSpace/functions/combat/getHelicopterAttackArea.sqf).
- [Focused fixture](../tests/combat/flight-update.sqf), [runner](../tests/combat/flight-update.ps1), [detailed scopes](../tests/combat/flight-scopes.sqf), and [context analyzer](../tests/combat/analyze-flight-tracy.py).
- [Configuration](combat-performance-results/flight-update-comparison.json), [source hashes](combat-performance-results/flight-update-source-manifest.json), [correctness](combat-performance-results/flight-update-correctness.json), [instrumentation smoke](combat-performance-results/flight-update-instrumentation-smoke.json), and [environment](combat-performance-results/flight-update-environment.json).
- [Diagnostic attribution](combat-performance-results/flight-update-diagnostic-attribution.json), [diagnostic inclusive/self scopes](combat-performance-results/flight-update-diagnostic-scopes.json), and [diagnostic session](combat-performance-results/flight-update-diagnostic-session.json).
- [Unprofiled results](combat-performance-results/flight-update-unprofiled-summary.json), [samples](combat-performance-results/flight-update-unprofiled-frames.csv), [precise pooled results](combat-performance-results/flight-update-profiled-precise-summary.json), and [precise workload validation](combat-performance-results/flight-update-profiled-summary.json).
- [Per-window operations](combat-performance-results/flight-update-profiled-operations-summary.json), [remaining entity maxima](combat-performance-results/flight-update-profiled-attribution.json), [frame inclusive/self scopes](combat-performance-results/flight-update-frame-scopes.json), and [capture session](combat-performance-results/flight-update-session.json).

```powershell
& tests/combat/flight-update.ps1
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 2 -Modes @('heli-infantry-aa') -FlightDiagnostics -ProfilerMarkers
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 4 -Modes @('heli-infantry-aa') -BaselineDirectory tests/combat/flight-update-baseline -ExtraArguments '-noPause'
```

Live captures add the installed profiler dependencies, 60-second startup and 90-second post delays. Connect before the first BEGIN marker and record 150 seconds for diagnostics or 240 seconds for comparison. Setup, warmup and teardown are excluded.

---

## Post-retreat AA readiness - 25 October 2026

The next recurring entity cost was the AA readiness scan after infantry reached their retreat destination. `canShootHelicopter` now tries the last successful unit index first, **revalidates its current state**, and visits every other unit if it fails. It also reads already-created immutable weapon profiles directly, lazily initializing unknown classes. Virtual seat/terrain checks follow usable-ammunition checks; native units retain their seat/weapon filters before physical inventory snapshots.

The index is a search-order hint, not a cached eligibility result. Ammo loss, resupply, weapon changes, mounting, range changes, casualties and roster reordering take effect on the next probe. Shrinking a roster bounds the starting index; empty rosters return false. Negative results are never cached. Only `VirtualSpace/functions/combat/canShootHelicopter.sqf` changes in production.

**Budgets remain unchanged:** 3 ms soft combat budget, eight engagement visits, ten entity visits, 1 ms ammo-search allowance, one-second combat resolution and one-second discovery interval.

### Instrumentation and finding

The preceding capture's 5.918 ms entity frame included 2.391 ms in air-defense updates, with 1.929 ms in readiness probes. New test-only scopes cover group/vehicle updates, positions/grid moves, task synchronization, waypoint/policy lookup, infantry qualification and weapon profiles.

The two diagnostic windows contain **1,931 frames** and pass **18/18 workload checks**. Their slowest entity frame is **2.683 ms**, including **0.950 ms air defense**, of which **0.697 ms** is three readiness probes performing **51 weapon-profile calls**. Task synchronization costs 0.160 ms, helicopter updates 0.495 ms, and discovery 0.468 ms in that frame. Named parents contain their children; these costs must not be added together.

Readiness totals **181.952 ms over 929 diagnostic calls**. Trying the previous successful slot avoids repeatedly walking the seven riflemen before the organic AA soldier while still reading current weapons and rounds. Across the diagnostic windows, task synchronization also costs 229.015 ms, positions 257.583 ms including 160.789 ms grid movement, and helicopter updates 621.060 ms. These overlapping totals include diagnostic overhead and are not comparison timings. The historical 5.918 ms maximum did not recur, so its complete cause remains unproven.

### Matched results

The comparison retains **20 total groups, five engagements, ten AA supporters, 85 units and 30 entities**. It uses the same dense-frontline layout, 600 m attack areas, test-only immortality and supplied missiles as the preceding runs. Four 35-second windows run before/after/after/before, with two-second warmup and paired seeds. Only the readiness function is swapped outside measured frames. Standard scopes are identical between versions; detailed diagnostics are disabled.

All four precise windows have BEGIN/END markers and exact frame counts matching the RPT: **1,946 before / 1,945 after frames**, no exclusions. Individual samples are pooled; trial percentiles are not averaged.

| Precise milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.727 | 1.666 |
| Whole-IVCS p95 | 5.483 | 5.135 |
| Whole-IVCS p99 | 6.668 | 6.506 |
| Whole-IVCS maximum | 7.685 | 7.650 |
| Entity-update mean | 0.964 | 0.906 |
| Entity-update p95 | 1.257 | 1.180 |
| Entity-update p99 | 1.498 | 1.352 |
| Entity-update maximum | 2.393 | 2.878 |
| Combat-frame p99 | 5.671 | 5.545 |

Entity p99 improves **9.8%**, whole-IVCS p99 **2.4%**, entity mean **6.0%**, and whole-IVCS mean **3.5%**. Paired whole-frame p99 values are **6.699 -> 6.417 ms** and **6.544 -> 6.527 ms**; the second pair's improvement is very small. These short samples do not establish a universal upper bound.

| AA readiness, complete precise windows | Before | After |
| --- | ---: | ---: |
| Calls | 935 | 936 |
| Total inclusive ms | 140.8856 | 32.5572 |
| Mean ms/call | 0.1507 | 0.0348 |
| p50 ms/call | 0.1514 | 0.0359 |
| p90 ms/call | 0.1592 | 0.0408 |
| p95 ms/call | 0.1680 | 0.0424 |
| p99 ms/call | 0.2303 | 0.0730 |
| Maximum ms/call | 0.5812 | 0.0842 |
| Calls above 1 / 5 / 10 ms | 0 / 0 / 0 | 0 / 0 / 0 |

Readiness mean falls **76.9%** and p99 **68.3%**. Probe counts are essentially unchanged: the reduction comes from less work per probe. Air-defense update p99 falls **0.218 -> 0.121 ms/call**. Readiness is already contained in air-defense/entity costs.

| Unprofiled milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.390 | 1.380 |
| Whole-IVCS p99 | 5.997 | 5.997 |
| Whole-IVCS maximum | 6.001 | 7.004 |
| Entity-update mean | 0.936 | 0.931 |
| Entity-update p99 | 1.999 | 1.007 |
| Entity-update maximum | 2.003 | 2.007 |

The unprofiled run contains **3,816 frames**. Its approximately 1 ms clock leaves whole-IVCS p99 at **about 6 ms**; this run does not establish a mod-free whole-frame p99 improvement. Coarse entity p99 drops approximately 2 -> 1 ms, while its mean is nearly unchanged. Larger optimized maxima are retained.

Both runs pass **36/36 checks**, totaling **72/72 workload checks across 7,707 measured frames**. Rosters, engagements, supporters and combat-clock progress remain valid. Unprofiled before/after shot totals are 819/819 helicopter, 110/110 infantry AA and 3,184/3,185 AA-vehicle shots; no ammo transfers occur. Native AI/rendering, forced shortages, setup, warmup and teardown are excluded.

### Remaining tail and correctness

The optimized worst complete frame is **7.650 ms**, including **6.592 ms combat** and **0.984 ms entities**. It resolves two exchanges; the largest is 3.025 ms. Exchange means remain about 2.02-2.04 ms. Combat resolution dominates the remaining whole-frame tail.

The largest optimized entity frame is **2.878 ms**, above the baseline maximum of 2.393 ms. Two helicopter updates consume **1.555 ms**, including a **1.267 ms** call; air defense is only 0.107 ms and no readiness probe runs. Helicopter movement/policy/position work is the next entity area to instrument more deeply; the current comparison scopes do not isolate that individual call's cause. Neither version has a precise frame above 10 or 16.67 ms in this capture.

**225/225 engine checks pass:** 95 AA readiness, 50 helicopter tactics, 21 helicopter review and 59 general helicopter checks. Coverage includes compatibility, current rounds, fuse/range boundaries, native weapon removal/rearming, land/airborne seats, immediate withdrawal, warm/cold profiles, failed-hint fallback, roster removal/reordering, empty groups and native handoff. The fuse-boundary fixture now explicitly loads its own ammo profile. Review found no further required changes. All SQF writes use CRLF.

The comparison capture saved normally: **869,768 zones**, **5,683,254 bytes**, Tracy/Zstd, four streams, **240.1 seconds** recorder span and **4 ns** timer resolution. The diagnostic capture is 150.1 seconds, 803,815 zones and 4,786,695 bytes. Embedded environment strings are unavailable from the compressed-header reader; separate evidence records Arma 2.22 build 154126, Windows, an i7-10700F and `accTime = 1`. Owned servers/recorders exited normally. Raw traces/events/messages remain outside Git. An exploratory intermediate-build run overlapped regression startup and is entirely excluded.

- [Optimized readiness](../VirtualSpace/functions/combat/canShootHelicopter.sqf), [regression fixture](../tests/combat/aa-readiness.sqf), [diagnostic scopes](../tests/combat/entity-scopes.sqf), and [entity attribution tool](../tests/combat/analyze-entity-tracy.py).
- [Comparison configuration](combat-performance-results/entity-update-comparison.json), [production hashes](combat-performance-results/entity-update-source-manifest.json), [correctness](combat-performance-results/entity-update-correctness.json), and [environment](combat-performance-results/entity-update-environment.json).
- [Diagnostic attribution](combat-performance-results/entity-update-diagnostic-attribution.json), [inclusive/self scopes](combat-performance-results/entity-update-diagnostic-scopes.json), and [diagnostic session](combat-performance-results/entity-update-diagnostic-session.json).
- [Unprofiled results](combat-performance-results/entity-update-unprofiled-summary.json), [frame samples](combat-performance-results/entity-update-unprofiled-frames.csv), [precise results](combat-performance-results/entity-update-profiled-precise-summary.json), and [precise workload validation](combat-performance-results/entity-update-profiled-summary.json).
- [Per-window operations](combat-performance-results/entity-update-profiled-operations-summary.json), [remaining entity maxima](combat-performance-results/entity-update-profiled-attribution.json), [frame inclusive/self scopes](combat-performance-results/entity-update-frame-scopes.json), [capture session](combat-performance-results/entity-update-session.json), and [excluded run](combat-performance-results/entity-update-excluded-runs.json).

```powershell
& tests/tasks/run.ps1 -TestScript tests/combat/aa-readiness.sqf -TimeoutSeconds 240
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 2 -Modes @('heli-infantry-aa') -EntityDiagnostics -ProfilerMarkers
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 4 -Modes @('heli-infantry-aa') -BaselineDirectory tests/combat/entity-update-baseline -ExtraArguments '-noPause'
```

For live capture, add installed profiler dependencies, a 60-second startup delay and a 90-second post delay. Record 150 seconds for diagnostics or 240 seconds for comparison, connecting before the first BEGIN marker. Session files identify the isolated server.

---

## AA support discovery - 25 October 2026

`findTarget` now checks whether the current engagement permits an AA transfer **once before walking the helicopter index**. Members of a valid air engagement and members in nontransferable engagement modes skip the candidate loop. Previously, they repeatedly called `start` and `joinHelicopterSupport` against other nearby helicopters, where the same ownership rule rejected each attempt. Helicopters and their crews retain their existing immediate return.

The filter uses the same live mode and `isHelicopterPair` predicate as public admission. There is no new cache, cooldown, scan interval or eligibility approximation. Idle/native AA and ground-engaged AA still discover air fights; finishing combat or invalidating the old pair makes discovery eligible on its next ordinary scan. Direct admission retains its existing validation, including ammunition/crew revalidation after pending combat is flushed.

Only `VirtualSpace/functions/combat/findTarget.sqf` changes in production. The existing **3 ms soft combat budget**, eight engagement visits, ten entity visits, 1 ms ammunition-search allowance, one-second resolution and one-second discovery interval remain unchanged.

### Unprofiled matched results

| Milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.704 | 1.482 |
| Whole-IVCS p95 | 5.001 | 4.997 |
| Whole-IVCS p99 | 6.001 | 5.997 |
| Whole-IVCS maximum | 7.999 | 7.004 |
| Entity-update mean | 1.162 | 0.971 |
| Entity-update p95 | 2.991 | 1.007 |
| Entity-update p99 | 3.006 | 1.999 |
| Entity-update maximum | 5.001 | 4.990 |

Whole-IVCS mean falls **13.0%**, and entity-update mean falls **16.5%**. The coarse entity p99 drops approximately **3 -> 2 ms**, while whole-IVCS p99 remains **about 6 ms**. The mod-free clock has approximately 1 ms resolution; small fractional differences do not establish a whole-frame p99 improvement. Paired whole-frame trial p99 values are 6.420 -> 5.997 ms and 5.997 -> 5.997 ms; both pairs improve their mean.

The four windows contain **3,843 frames** and pass **36/36 workload checks**. All five engagements, ten AA supporters and complete rosters remain present, and fights resolve 34-36 combat seconds per approximately 35 simulation seconds. Before/after role-shot totals over 70 seconds each are 802/811 helicopter shots, 106/108 infantry AA missiles and 3,164/3,175 AA-vehicle shots; no ammunition transfers occur. Small scheduling/window-boundary differences are retained rather than normalizing away actual work.

### Precise results and admission bursts

All four Tracy windows have BEGIN/END markers and exact frame counts matching the RPT. Both seed pairs are retained: **1,921 before / 1,928 after frames**, with no incomplete-window exclusions. The run passes **36/36 workload checks**. Together with the unprofiled run this is **72/72 workload checks across 7,692 measured frames**. Individual frame samples are pooled; trial percentiles are not averaged.

| Precise milliseconds per real server frame | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean | 1.894 | 1.702 |
| Whole-IVCS p95 | 5.441 | 5.240 |
| Whole-IVCS p99 | 6.933 | 6.434 |
| Whole-IVCS maximum | 9.149 | 7.435 |
| Entity-update mean | 1.139 | 0.952 |
| Entity-update p95 | 2.862 | 1.297 |
| Entity-update p99 | 3.495 | 1.526 |
| Entity-update maximum | 5.901 | 5.918 |
| Combat-frame p99 | 5.500 | 5.452 |

Precise entity-update p99 improves **56.3%**, while whole-IVCS p99 improves **7.2%** and whole-frame mean improves **10.1%**. Both paired whole-frame p99 comparisons improve: **7.087 -> 6.285 ms** and **6.708 -> 6.586 ms**. The benefit differs between pairs; these short sustained-load samples do not establish a universal upper bound.

The measured fixed-membership workload executes **5,120 rejected `joinHelicopterSupport` calls before, zero after**. These calls are individually short (0.0366 ms mean, 0.0600 ms p99, 0.1491 ms maximum; none above 1 ms), but cluster into bursts of up to **36 attempts in one frame**. Before trial 1 has 96 frames with admission attempts; its 5.901 ms worst entity update spends **4.363 ms in discovery**. Before trial 4 also has 96 affected frames, reaching 28 attempts/frame; its 3.862 ms worst entity update spends **2.611 ms in discovery**. Both optimized windows contain zero admission attempts after setup.

| `findTarget`, complete matched windows | Before | After |
| --- | ---: | ---: |
| Calls | 19,210 | 19,280 |
| Calls per measured frame | 10 | 10 |
| Total inclusive ms | 489.328 | 147.626 |
| Mean ms/call | 0.0255 | 0.0077 |
| p50 ms/call | 0.0050 | 0.0050 |
| p90 ms/call | 0.0094 | 0.0090 |
| p95 ms/call | 0.2765 | 0.0323 |
| p99 ms/call | 0.3348 | 0.0460 |
| Maximum ms/call | 0.5808 | 0.1534 |
| Calls over 1 / 5 / 10 ms | 0 / 0 / 0 | 0 / 0 / 0 |
| Inclusive ms per frame | 0.255 | 0.077 |

The same ten discovery visits per frame remain; only redundant work inside them is removed. Discovery mean falls approximately **70%** and its p99 **86%**. Its inclusive timings contain the admission timings and must not be added to them. Entity/combat/root percentiles are also not additive.

Rare entity maxima remain: after trial 3 contains a **5.918 ms** entity update, with only **0.268 ms** in discovery and no admission attempts. Thus this change removes the measured admission bursts, not every possible entity spike. The optimized run's worst complete frame is **7.435 ms**, comprising **6.561 ms combat**, **0.809 ms entity work**, and other loop overhead. It resolves two complete exchanges; the largest is 2.751 ms. Complete-exchange means are essentially unchanged (1.943 -> 1.957 ms/call). Neither version has a precise frame over 10 or 16.67 ms in this capture. Reducing remaining combat work is now more likely to move whole-frame p99 than further shrinking this discovery path.

The verified four-minute capture contains **942,016 zones**, **6,143,736 bytes**, Tracy/Zstd with four streams, a recorder-reported **240.2-second span** and **4 ns timer resolution**. Exact BEGIN/END markers define the windows; aggregate-percent duration estimates are not used. The compressed-header reader does not expose embedded environment strings, so OS/CIM and RPT separately record the i7-10700F, approximately 32 GB RAM, Windows 10, Arma 2.22 build 154126 and `accTime = 1`. Runs are sequential with one isolated server, at approximately 27.4-27.6 server frames/s; these are script costs rather than client rendering FPS.

Across the complete mixed-version capture, root/entity/combat inclusive totals are 7.306 / 4.252 / 2.770 seconds. Leading wrapper self totals are 73.01 ms root, 29.08 ms combat and 24.65 ms entities; actual work is in child scopes. These capture-wide totals include warmup and nested overlap and are not additional frame costs.

### Correctness and measurement method

**191/191 engine checks pass**: 61 focused admission/ownership checks, 50 helicopter tactics, 21 helicopter review and 59 general helicopter checks. The focused fixture compares actual candidate-start counts with the archived function for primary groups, supporting infantry, AA vehicles, linked crews and aircraft in virtual/native/spawning/capturing modes. Reserved members generate zero rejected starts; existing aircraft fast paths remain zero. Checks also cover stale IDs, an invalidated old aircraft, idle virtual/native joins, ground-to-air transfers, firing-delay preservation, rediscovery after release, native handoff and cleanup. SQF files use CRLF.

The benchmark retains **20 total groups**, five simultaneous helicopter engagements, 85 units and 30 virtual entities, including five AA vehicles and five infantry AA support teams. It uses the same dense-frontline infantry layout, test-only immortality, supplied magazines and 600 m attack areas described below. Four 35-second windows use before/after/after/before order, two seconds warmup and paired initial seeds. Only the discovery function is swapped outside measured frames. Standard profiler scopes include `findTarget` and `joinHelicopterSupport`; no detailed per-record counters are enabled. Initial creation and support admission are outside timing; ongoing discovery is measured.

- [Optimized discovery](../VirtualSpace/functions/combat/findTarget.sqf), [focused fixture](../tests/combat/support-admission.sqf), and [focused runner](../tests/combat/support-admission.ps1).
- [Comparison configuration](combat-performance-results/support-admission-comparison.json), [production hashes](combat-performance-results/support-admission-source-manifest.json), and [correctness evidence](combat-performance-results/support-admission-correctness.json).
- [Unprofiled results](combat-performance-results/support-admission-unprofiled-summary.json), [frame samples](combat-performance-results/support-admission-unprofiled-frames.csv), and [measurement environment](combat-performance-results/support-admission-environment.json).
- [Precise pooled results](combat-performance-results/support-admission-profiled-precise-summary.json), [per-window attribution](combat-performance-results/support-admission-profiled-operations-summary.json), [burst counts and remaining entity maxima](combat-performance-results/support-admission-bursts.json), and [profiled workload validation](combat-performance-results/support-admission-profiled-summary.json).
- [Verified capture session](combat-performance-results/support-admission-session.json) and [frame inclusive/self scopes](combat-performance-results/support-admission-frame-scopes.json).

```powershell
& tests/combat/support-admission.ps1
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 4 -Modes @('heli-infantry-aa') -AdmissionBaselineDirectory tests/combat/support-admission-baseline -ExtraArguments '-noPause'
```

The precise run adds `-ProfilerMarkers`, installed CBA/Intercept/Arma Script Profiler dependencies, a 60-second startup delay, a 90-second post delay and a 240-second bundled-recorder capture. The verified session records its exact server identity. Startup/admission, warmup and teardown are excluded from timed windows. The workload is virtual-only and does not measure native AI/rendering, incoming new-support bursts or simultaneous forced ammunition shortages. Raw traces and event exports remain outside the repository; the runner removes packed missions, copied runtimes and engine caches.

---

## Air-target firing selection - 25 October 2026

Detailed instrumentation found repeated magazine scans for weapons that cannot engage the current aircraft. `getVehicleShot` now rejects an entire ineligible weapon before its magazine scan: ground-only launchers are excluded using the existing precomputed AA compatibility map, while rifles/GLs are excluded outside the existing infantry range or during AA-only support fire. Eligible weapons retain their current-round, compatibility, fuse, mount and range checks. Ground-target selection is preserved. No frame budget, cadence, damage, ammunition accounting, random sampling or scheduler allowance changes.

### Diagnostic findings

The previous worst combat frame contained a 10.533 ms exchange and a 6.783 ms infantry firing call. A new nested probe measured the selector, weapon-cache hits/misses, individual record scans, preparation misses, per-unit firing and hit sampling. Numeric work counters were buffered during each frame and serialized after the measured root scope closed. The probe uses the same 20-group, five-engagement, supporting-AA infantry layout as below, with two 35-second windows and unchanged production budgets. Diagnostic timings include instrumentation overhead and are used for attribution, not the before/after performance comparison.

The diagnostic windows contain **3,318 selector calls**, **36,981 magazine record visits**, **328 preparation misses**, **306 range-driven cache resets**, and **159 firing loops**. Only 159 record visits select a shot; **36,822 visits reject ammunition**. Riflemen repeatedly scan 9-21 records despite being outside their range, while the LAT soldier scans 12 copies of ground-only RPG ammunition, including **3,944 negative preparation-cache hits** across the run.

Across the complete diagnostic capture, record scanning costs **370.22 ms inclusive / 359.60 ms self**, versus **10.62 ms inclusive for shot preparation** and **3.10 ms for cache resets**. The expensive work is walking rejected inventories, rather than repeatedly calculating accuracy or resetting the cache. These scope totals overlap through their parents and include warmup; work-counter totals above cover measured windows only.

The slowest diagnostic exchange costs **7.140 ms**, with **2.004 ms inside record scans**. Its primary target is at 620 m: seven non-AA infantry inspect 104 records and select no shots; the organic AA soldier checks six rifle magazines before finding its usable missile. Supporting AA correctly selects two missiles from two live records. The new weapon-level rejection removes those ineligible scans while leaving the AA magazine lookup intact.

The slowest complete diagnostic frame is a different **11.545 ms** sample, dominated by **10.331 ms in entity updates**, including repeated support-admission probes. Thus the rejected-inventory issue is a confirmed combat cost, while the evidence also shows a separate entity-update tail. The exact historical 12.382 ms event lacks these finer counters; this reproduction does not establish a cause for every transient spike.

The diagnostic run passes **18/18 workload checks**. Its trace saved normally: **532,766 zones**, **3,578,181 bytes**, Tracy/Zstd, a recorder-reported **180.1-second span**, and **5 ns timer resolution**. A first pilot that failed during instrumentation setup contains no combat windows and is excluded; it is retained outside the repository. Raw traces, message exports and event CSVs remain outside the repository.

### Matched performance comparison

Only the selector function is swapped between versions, outside measured frames. Four 35-second windows use before/after/after/before order and paired initial seeds; detailed diagnostic counters are disabled. Production budgets, one-second resolution, real movement, visibility, shot selection, firing, ammunition use and damage all remain enabled. Both versions use the same test-only immortality and supplied magazines described below.

| Whole IVCS loop, no profiler, ms/frame | Before | After |
| --- | ---: | ---: |
| Mean | 1.780 | 1.520 |
| p95 | 5.005 | 4.997 |
| p99 | 7.000 | 6.001 |
| Maximum | 9.003 | 7.000 |

The mod-free mean improves **14.6%**, and coarse p99 improves **14.3%**. Both seed pairs reproduce approximately 7 -> 6 ms p99. The timer has approximately 1 ms resolution; small fractional differences are not meaningful. Before/after role-shot totals over 70 seconds are 819/811 helicopter shots, 108/108 infantry support missiles, and 3,183/3,175 AA vehicle shots. No magazine transfers occur. The run passes **36/36 workload checks**, retaining all rosters, five engagements and ten support reservations, and resolves 34-36 combat seconds per approximately 35 simulation seconds.

### Precise comparison and limits

The standard-scope profiled run passes **36/36 workload checks** across all four RPT windows. The recorder connected after the first window's BEGIN marker, so precise analysis deliberately selects only **trials 3 and 4**, one complete matched seed pair. Trial 2 is also excluded to retain pairing. Both selected windows have BEGIN/END markers and their exact frame counts match the RPT: **977 after / 978 before**. The two unprofiled seed pairs above remain complete and valid. No partial window is used for exact percentiles.

| Matched complete pair, precise ms | Before | After |
| --- | ---: | ---: |
| Whole-IVCS mean per frame | 2.268 | 2.101 |
| Whole-IVCS p95 per frame | 5.746 | 5.567 |
| Whole-IVCS p99 per frame | 7.611 | 6.788 |
| Whole-IVCS maximum per frame | 17.112 | 11.882 |
| Firing selector mean per call | 0.120 | 0.037 |
| Infantry vehicle-fire mean per call | 0.930 | 0.534 |
| Infantry vehicle-fire p99 per call | 2.064 | 1.293 |
| Complete exchange mean per call | 2.844 | 2.057 |
| Complete exchange p99 per call | 5.015 | 4.912 |
| Complete exchange maximum per call | 5.147 | 7.860 |

The matched precise pair shows **10.8% lower whole-IVCS p99**, **69.4% lower selector mean**, and **27.7% lower complete-exchange mean**. Component percentiles are not additive, and nested call times must not be added to the root frame cost. One precise pair is corroborating evidence; the two unprofiled pairs provide the repeated p99 comparison. This is not a hard upper bound on future frames.

| `getVehicleShot`, complete matched pair | Before | After |
| --- | ---: | ---: |
| Calls | 1,665 | 1,668 |
| Inclusive total ms | 199.127 | 60.946 |
| Mean ms/call | 0.120 | 0.037 |
| p50 ms/call | 0.117 | 0.030 |
| p90 ms/call | 0.215 | 0.045 |
| p95 ms/call | 0.248 | 0.053 |
| p99 ms/call | 0.257 | 0.187 |
| Maximum ms/call | 0.620 | 0.307 |
| Calls over 1 / 5 / 10 ms | 0 / 0 / 0 | 0 / 0 / 0 |

Worst-case spikes are reduced in these full-frame samples, but they remain. The before maximum is **17.112 ms**, dominated by **15.791 ms of entity updates** with no engagement exchange. The after maximum is **11.882 ms**, containing **10.931 ms combat**, including a **7.860 ms exchange**, plus **0.843 ms entity work**. Its infantry firing call reaches 3.845 ms even though no individual selector call in that frame exceeds 0.3 ms. In the complete pair, before/after frame counts above 10 ms are 1/2, and above 16.67 ms are 1/0. The rejected-magazine scans are fixed; complete firing exchanges and ordinary entity/admission work are distinct remaining tail sources. The measurements do not attribute all maximum-frame improvement to this selector change.

The precise capture contains **882,867 zones**, **5,785,284 bytes**, Tracy/Zstd with four streams and a **4 ns** recorder timer. The server exited normally after its post-delay, so the recorder saved after **193 seconds** rather than the planned 210; all selected measurement windows are complete. Embedded environment strings are unavailable through the compressed-header reader; OS/CIM and RPT record the i7-10700F, approximately 32 GB RAM, Windows 10, Arma 2.22 build 154126, and `accTime = 1`. Only the isolated server runs during each sequential measurement. Root/entity/combat inclusive and self rankings, frame distributions and exact operation distributions remain in the retained scope/attribution reports.

### Implementation and verification

The production change is confined to `VirtualSpace/functions/combat/getVehicleShot.sqf`; it reuses existing immutable `antiAirMagazines` metadata. The archived selector is checked by SHA-256 and is swapped only outside timed windows for comparison. The diagnostic scripts remain optional and are not loaded in production.

**977/977 correctness checks pass**: 812 selector parity/mutation/work checks, 58 vehicle combat, 57 vehicle expansion and 50 helicopter tactics checks. The 800 differential cases cover ten infantry classes, four ground/air target profiles, ten ranges and both AA flag values, comparing full shot results to the archived selector. Additional checks cover live ammo loss/resupply, incompatible owned magazines, settings changes and zero record visits for unreachable rifle/GL/LAT/ammo-bearer/machine-gun units. Eligible AA still visits its first usable record. SQF files retain CRLF.

- [Nested scopes](../tests/combat/shot-selection-scopes.sqf), [work/context analyzer](../tests/combat/analyze-shot-selection.py), [differential fixture](../tests/combat/shot-selection.sqf), and [test runner](../tests/combat/shot-selection.ps1).
- [Diagnostic attribution](combat-performance-results/shot-diagnostic-operations-summary.json), [work counts and slow-frame contexts](combat-performance-results/shot-diagnostic-work.json), [scope distributions and self/inclusive rankings](combat-performance-results/shot-diagnostic-scopes.json), and [verified capture session](combat-performance-results/shot-diagnostic-session.json).
- [Production source manifest](combat-performance-results/shot-selection-source-manifest.json) and [correctness evidence](combat-performance-results/shot-selection-correctness.json).
- [Matched comparison configuration](combat-performance-results/shot-selection-comparison.json), [unprofiled summary](combat-performance-results/shot-selection-unprofiled-summary.json), [unprofiled frames](combat-performance-results/shot-selection-unprofiled-frames.csv), and [environment](combat-performance-results/shot-selection-environment.json).
- [Precise complete-pair metrics](combat-performance-results/shot-selection-profiled-precise-summary.json), [per-window attribution and exclusions](combat-performance-results/shot-selection-profiled-operations-summary.json), and [all profiled RPT windows](combat-performance-results/shot-selection-profiled-summary.json).
- [Verified comparison capture](combat-performance-results/shot-selection-session.json) and [frame inclusive/self scopes](combat-performance-results/shot-selection-frame-scopes.json).

```powershell
& tests/combat/shot-selection.ps1
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 4 -Modes @('heli-infantry-aa') -ShotBaselineDirectory tests/combat/shot-selection-baseline -ExtraArguments '-noPause'
```

For detailed diagnosis, use `-ShotDiagnostics -ProfilerMarkers` without a comparison baseline. Detailed scopes fail on missing/ambiguous source anchors. The work analyzer splits native message exports at the last comma because the exporter does not quote commas inside message text. The precise comparison disables those counters. Start recording before the first BEGIN marker; use a longer startup delay when launching a new capture to retain every seed pair.

---

## AA capability after retreat - 25 October 2026

Repeated infantry AA capability checks now use precomputed weapon-to-magazine compatibility, AA suitability and minimum fuse ranges. The predicate reads current weapons, magazine rounds, mounting state and engagement range on every call; native groups still read their physical inventory. It no longer constructs accuracy, damage or cadence data just to answer whether a group can use AA. There is no readiness-result cache or invalidation delay. General infantry fire and vehicle capability selection retain their existing paths.

The same two production files differ from the preceding measured build: `canShootHelicopter.sqf` and `getWeaponProfile.sqf`. Class metadata is prewarmed during unit creation. No frame budgets, scheduler allowances, combat intervals, range rules or approximations changed.

### Matched 20-group measurement

This comparison reuses the five-engagement, 85-unit infantry layout below: 20 total groups, 30 virtual entities, five helicopters, five AA vehicles and five infantry AA support teams. One scenario holds the support participants idle; the other enables all ten supporters. Each scenario has two 35-second windows per version, two seconds of warmup, paired initial seeds, reversed scenario order, and before/after/after/before trial order. Only the capability predicate is swapped outside measured windows. Both versions share the new immutable metadata, warmed outside measurement, so this isolates runtime predicate cost.

| Whole IVCS loop, ms per real server frame, no profiler | Before mean | After mean | Before p99 | After p99 | Before maximum | After maximum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Infantry target; support held idle | 1.75 | 1.44 | 6.00 | 6.00 | 7.02 | 6.00 |
| Infantry target + infantry/vehicle AA | 1.91 | 1.67 | 7.57 | 7.00 | 11.00 | 9.00 |

The supporting-AA mean falls **12.7%**. The coarse pooled p99 falls **7.4%**, but the approximately 1 ms clock limits interpretation: paired supporting-AA trial p99 values are 8.00 -> 7.00 ms and 7.02 -> 6.99 ms. Both pairs improve their mean. These fresh matched before figures are lower than the historical measurements below; compare versions within this run rather than attributing the entire historical difference to this change.

The unprofiled run passes **68/68 workload checks**, retaining all groups, five engagements and every expected support reservation. Both AA categories fire, no native entities appear, and each fight advances 34-36 combat seconds per approximately 35 simulation seconds. Before/after supporting-AA shot totals are 820/805 helicopter shots, 108/106 infantry AA shots and 3,183/3,165 vehicle AA shots over 70 seconds each; none of these windows require magazine transfers. Initial seeds are paired, while frame scheduling and one-second window boundaries allow small firing-count differences.

### Precise timings and remaining tail

The separate matched Tracy run confirms a **3.4% reduction in supporting-AA whole-IVCS p99**, from **7.873 to 7.602 ms**. Both seed pairs improve: 8.093 -> 7.371 ms and 7.789 -> 7.739 ms. The improvement is modest and the two pairs differ in magnitude; two windows per version do not establish a universal tail-latency guarantee. All percentiles pool individual samples rather than averaging trial percentiles.

| Whole IVCS loop, precise ms/frame | Before mean | After mean | Before p99 | After p99 | Before maximum | After maximum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Infantry target; support held idle | 1.997 | 1.786 | 6.303 | 5.863 | 8.764 | 7.409 |
| Infantry target + infantry/vehicle AA | 2.252 | 2.102 | 7.873 | 7.602 | 9.781 | 12.382 |

In the supporting-AA windows, the capability helper's mean falls **69.2%**, saving approximately **0.175 ms per frame inclusive**. Ordinary entity-update mean falls from 1.316 to 1.141 ms/frame and its p99 from 4.126 to 3.526 ms. The helper timings are nested inside those entity updates and must not be added to them.

| `canShootHelicopter`, infantry + supporting AA | Before | After |
| --- | ---: | ---: |
| Calls | 939 | 935 |
| Total inclusive ms | 492.442 | 151.019 |
| Mean ms/call | 0.524 | 0.162 |
| p50 ms/call | 0.522 | 0.148 |
| p90 ms/call | 0.548 | 0.161 |
| p95 ms/call | 0.562 | 0.175 |
| p99 ms/call | 0.679 | 0.823 |
| Maximum ms/call | 2.886 | 1.030 |
| Calls over 1 / 5 / 10 ms | 5 / 0 / 0 | 1 / 0 / 0 |
| Inclusive ms per frame | 0.253 | 0.078 |

The helper's own p99 is higher despite lower mean/p95 and maximum. All 16 optimized checks over 0.5 ms cluster 25.5-34.8 seconds into the second optimized supporting-AA window; the first such window has none. This is an observation, not an identified cause, and those events remain in every reported percentile. No samples are discarded.

Full engagement work remains the main tail limit. Supporting-AA combat-frame p99 is essentially unchanged, **6.500 -> 6.461 ms**. The optimized run includes one **12.382 ms whole frame**, containing **11.717 ms combat** and **0.575 ms entity updates**. Its single exchange costs **10.533 ms**, including a **6.783 ms infantry AA firing resolution** with expensive nested `getVehicleShot` selections. No capability-helper call occurs in that worst frame. The complete-exchange mean/p99/max changes from 2.786 / 4.652 / 6.179 to 2.857 / 5.234 / 10.533 ms; this optimization does not improve that atomic operation. There is one optimized supporting-AA frame over 10 ms, versus zero before; neither version exceeds 16.67 ms. Reducing complete firing/selection work is a more promising next target than reducing the frame allowance.

Both performance runs pass **136/136 workload checks** across **15,507 measured frames**, including 7,763 precise frames whose window counts match the RPT exactly. Every scenario retains its complete roster and expected reservations, both support categories fire when enabled, and combat advances within the existing progress tolerance. Measurements remain virtual-only and exclude native AI/rendering, startup/admission spikes and forced shortages, as described below.

The measurement uses the same i7-10700F / 32 GB / Windows 10 machine, Arma 2.22 build 154126 and `accTime = 1`, with one isolated server and sequential runs. Observed server cadence is approximately 27.5-27.8 frames/s. The verified capture contains **1,760,681 zones**, **11,549,635 bytes**, Tracy/Zstd with four streams, a recorder-reported **360.1-second span** and **4 ns timer resolution**. Exact BEGIN/END messages define measurement windows; the reader's aggregate-percent duration estimate is not used. Embedded environment strings are unavailable through the compressed-header reader, so the environment is recorded separately from OS/CIM and the engine RPT.

Across the complete mixed-version capture, frame/entity/combat inclusive scope totals are 16.612 / 9.854 / 6.179 seconds. Their wrapper self totals are 146.0 / 50.9 / 68.7 ms; actual work is in child scopes. These capture-wide figures include warmup and overlap through nesting; they are not additional frame costs. Inclusive/self rankings and all requested frame distributions are retained in the scope report.

### Correctness and reproduction

**211/211 correctness checks pass** across the focused AA-readiness differential/mutation suite and the existing helicopter review, tactics and combat suites. The focused suite compares the new predicate against the canonical firing selector for eight stock infantry classes at seven ranges, including fuse/range boundaries, empty/incompatible ammunition, weapon removal/restoration, cargo ownership, mounting/dismounting, native inventory changes, and immediate post-retreat withdrawal when the last usable round disappears. Capability probes leave ammunition untouched and build no full shot records. Changed/new SQF files use CRLF.

```powershell
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 4 -Modes @('heli-infantry','heli-infantry-aa') -BaselineDirectory tests/combat/aa-readiness-baseline -ExtraArguments '-noPause'
C:\Python39\python.exe tests/combat/analyze-helicopter-performance.py <retained-server.rpt> --output docs/combat-performance-results --label aa-readiness-unprofiled
```

The archived predicate hash matches the preceding measured production source. The precise variant adds profiler markers and the installed profiler dependencies, with 30 seconds startup delay, 50 seconds post delay and a 360-second capture. Raw traces and event exports stay outside the repository; the runner removes copied runtimes, packed missions and engine caches.

- [Comparison configuration](combat-performance-results/aa-readiness-comparison.json), [production source hashes](combat-performance-results/aa-readiness-source-manifest.json), and [correctness evidence](combat-performance-results/aa-readiness-correctness.json).
- [Unprofiled results](combat-performance-results/aa-readiness-unprofiled-summary.json) and [frame samples](combat-performance-results/aa-readiness-unprofiled-frames.csv).
- [Precise pooled metrics](combat-performance-results/aa-readiness-profiled-precise-summary.json), [per-window operation attribution](combat-performance-results/aa-readiness-profiled-operations-summary.json), and [profiled workload validation](combat-performance-results/aa-readiness-profiled-summary.json).
- [Verified capture session](combat-performance-results/aa-readiness-tracy-session.json), [inclusive/self scope report](combat-performance-results/aa-readiness-tracy-frame-scopes.json), and [measurement environment](combat-performance-results/aa-readiness-environment.json).

---

## Helicopter combat with supporting AA - 25 October 2026

At **1x simulation speed**, the sustained 20-group infantry/AA workload costs **2.71 ms mean, about 9.00 ms p99, and 12.01 ms maximum** per real server frame for the whole IVCS loop without profiler mods. Helicopter versus ground vehicle with the same support structure costs **1.91 ms mean, about 6.99 ms p99, and 9.00 ms maximum**. These are new helicopter workloads, not a matched comparison with the historical 20-group infantry-only figures below.

### Workload and interpretation

Here **20 groups means five simultaneous engagements**, each comprising one helicopter crew group, one enemy target group, one allied infantry AA team, and one allied AA vehicle crew group. This is five attack helicopters, five AA vehicles, and ten AA support participants. The infantry layout has 85 units and 30 total virtual entities; the vehicle layout has 60 units and 35 entities, adding five target APCs. It does not represent 20 simultaneous helicopter engagements.

The infantry target starts from the stock OPF_F infantry squad and replaces one member with organic AA so a sustained target does not immediately withdraw when the supporting AA comparison is disabled. Support teams are stock `OIA_InfTeam_AA`; aircraft are `B_Heli_Attack_01_dynamicLoadout_F`; AA vehicles are `O_APC_Tracked_02_AA_F`; vehicle targets are `O_APC_Wheeled_02_rcws_v2_F`.

Both runs use two 35-second windows per scenario, two seconds of warmup, paired initial seeds, and reversed scenario order in the second trial. Each window covers a complete 33-second helicopter pass cycle. Battle cells overlap spatially to exercise a dense-frontline helicopter-index scan. Assigned attack areas use a 600 m radius so evasive flight and the 100 m infantry retreat retain contact; weapon/encounter ranges and flight altitude retain production defaults.

The production **3 ms soft combat budget**, eight engagement visits per frame, 1 ms ammunition-search allowance, ten entity visits per frame, and one-second resolution remain unchanged. Production flight/evasion, retreat/exposure, visibility, ammunition selection/consumption, reloads, damage, crew damage and shared entity updates execute. Initial construction/admission, warmup, sample logging and teardown are outside the timed windows. Repeated discovery/admission probes during combat are included.

Test-only immortality prevents roster collapse: real damage/crew calculations execute, then vehicle health is restored and lethal unit removals are intercepted. This restoration overhead is inside the timings. Each infantry launcher starts with 12 magazines to sustain the load. These are sustained-load timings; native handoff, physical AI, rendering, initial AA admission spikes, normal casualty teardown and simultaneous forced ammunition shortages need separate measurements. No magazine transfers occurred in these supplied windows.

### Frame costs

All values below are **milliseconds of IVCS work per real server frame**. The mod-free timer has approximately 1 ms resolution; tiny fractional p99 differences are not meaningful. Tracy provides precise named-scope timings in a separate matched run, with profiler/mod overhead. Component and operation scopes are nested and must not be added to the full-loop figures.

| Scenario, 20 total groups | Mod-free mean | Mod-free p95 | Mod-free p99 | Mod-free max | Precise Tracy p99 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Idle, same infantry-layout entities | 1.21 | 2.01 | 3.00 | 5.00 | 3.15 |
| Infantry target, supporting AA held idle | 2.31 | 6.00 | 8.00 | 10.01 | 7.71 |
| Infantry target + infantry/vehicle AA | 2.71 | 7.00 | 9.00 | 12.01 | 10.06 |
| Ground vehicle target + infantry/vehicle AA | 1.91 | 5.00 | 6.99 | 9.00 | 7.83 |

Adding the ten supporting-AA participants to the matched infantry layout raises the mod-free mean by **0.40 ms/frame (17%)**, with p99 rising from about **8 to 9 ms**. The p99 result repeats in both scenario orders. The lower vehicle-layout cost also reflects fewer units and different weapons/firing patterns; it is not an isolated estimate of vehicle-versus-infantry algorithm efficiency.

| Accepted workload | Frames without profiler | Frames with profiler | Helicopter shots without profiler | Infantry AA support shots | Vehicle AA support shots |
| --- | ---: | ---: | ---: | ---: | ---: |
| Idle, same infantry-layout entities | 1905 | 1911 | 0 | 0 | 0 |
| Infantry target, supporting AA held idle | 1928 | 1929 | 852 | 0 | 0 |
| Infantry target + infantry/vehicle AA | 1931 | 1932 | 819 | 106 | 3183 |
| Ground vehicle target + infantry/vehicle AA | 1917 | 1918 | 160 | 104 | 3164 |

The accepted runs pass **128/128 validity checks**. Every fighting window retains five engagements and all expected support reservations, both support categories fire, no native entities appear, rosters stay intact, and all fights advance within one resolution interval plus 0.5 seconds of simulation-clock progress. Mod-free windows advance 34-36 combat seconds over roughly 35 elapsed simulation seconds. The runs sample **15,371 measured frames** in total; precise frame counts match the RPT windows exactly.

### What drives the tail

| Infantry + supporting AA | Mean | p99 | Maximum |
| --- | ---: | ---: | ---: |
| Whole IVCS frame, precise ms/frame | 3.079 | 10.055 | 14.832 |
| Combat scheduler, resolution and search, precise ms/frame | 1.161 | 6.875 | 8.764 |
| Ordinary entity updates, precise ms/frame | 1.817 | 5.894 | 7.613 |
| One complete engagement exchange, precise ms/call | 3.943 | 6.559 | 7.003 |

The scheduler yields between complete engagements, while a helicopter exchange resolves its primary target and all supporting AA together. The measured **3.94 ms mean / 6.56 ms p99 / 7.00 ms maximum per infantry+AA exchange** already exceeds the 3 ms soft combat allowance. The worst precise infantry+AA frame is **14.83 ms**: **8.76 ms combat + 5.92 ms entity updates + 0.15 ms other work**. It contains one 6.33 ms exchange; combat also does work outside that exchange. A lower budget alone cannot split that atomic work.

Among instrumented operations, `canShootHelicopter` averages **0.787 ms/call**, p99 **1.684 ms**, across 935 measured calls in the infantry+AA windows. After infantry reaches its retreat destination, `updateAirDefense` repeats this current-AA check on subsequent entity updates. That helper accounts for about **0.38 ms/frame inclusive**, nested inside its callers. `getVehicleShot` is another significant nested selection/preparation cost. These observations suggest checking AA readiness less often with appropriate invalidation, and reducing or staging complete exchange work, before changing time budgets.

The fixed-membership infantry+AA windows still execute **5,172 support-admission probes** during entity scanning, about **0.13 ms/frame inclusive**. Participants already reserved in an air engagement cannot transfer to another air engagement, so early exclusion of those retries is another concrete efficiency candidate. Ground-target windows execute 6,996 such probes. No optimization is implemented by this measurement change.

Precise infantry+AA samples contain 22/1,932 frames over 10 ms; none exceed 16.67 ms. Ground-target+AA samples contain 2/1,918 over 10 ms. This is a server-side script-cost distribution on this machine; the rest of Arma and a populated client mission require their own frame budget.

### Environment, evidence and reproduction

Intel i7-10700F, 8 cores / 16 logical processors, approximately 32 GB RAM, Windows 10 Home 10.0.19045. Arma 3 x64 profiling executable **2.22 build 154126**, `accTime = 1`. Only the isolated benchmark Arma server runs during each measurement; runs are sequential. Observed server cadence is about 27.2-27.6 frames/s. The 256 production SQF source hashes match between runs and after analysis; gameplay sources are unchanged.

The verified six-minute capture contains **1,570,028 zones**, **11,195,832 bytes**, **Zstd compression with four streams**, and a recorder-reported **5 ns timer resolution**. The recorder reports 360.2 seconds of trace span and completed saving. The read-tracy aggregate-percent duration estimate is imprecise for this capture and is not used for measurement windows; exact BEGIN/END messages define all eight validated windows. The compressed-header reader does not expose embedded environment strings for Zstd, so the environment above comes from the current OS/CIM snapshot and RPT configuration.

Trace and raw event exports remain outside the repository under the capture-tracy skill captures directory. Regenerable packed missions, copied runtimes and engine caches are automatically removed by the runner. Pilot runs with setup errors or contact loss are excluded from the accepted results.

```powershell
& tests/combat/helicopter-performance.ps1 -Seconds 35 -Trials 2 -ExtraArguments "-noPause"
C:\Python39\python.exe tests/combat/analyze-helicopter-performance.py <retained-server.rpt> --output docs/combat-performance-results --label helicopter-rerun
```

The precise run uses `-ProfilerMarkers`, installed CBA/Intercept/Arma Script Profiler dependencies, a 30-second startup delay, a 50-second post delay, and the bundled 360-second recorder. The capture session records the exact trace path and verified server identity.

- [Benchmark](../tests/combat/helicopter-performance.sqf), [runner](../tests/combat/helicopter-performance.ps1), [frame/workload analyzer](../tests/combat/analyze-helicopter-performance.py), and [precise percentile pooling](../tests/combat/analyze-helicopter-tracy.py).
- [Unprofiled summary](combat-performance-results/helicopter-unprofiled-summary.json) and [frame samples](combat-performance-results/helicopter-unprofiled-frames.csv).
- [Precise pooled metrics](combat-performance-results/helicopter-profiled-precise-summary.json), [per-window attribution](combat-performance-results/helicopter-profiled-operations-summary.json), and [profiled validation](combat-performance-results/helicopter-profiled-summary.json).
- [Capture session/save verification](combat-performance-results/helicopter-tracy-session.json), [frame inclusive/self scopes](combat-performance-results/helicopter-tracy-frame-scopes.json), [environment](combat-performance-results/helicopter-environment.json), and [production source manifest](combat-performance-results/helicopter-source-manifest.json).

---

Timing update, 14 October 2026: gameplay now uses the centralized, pause-aware simulation clock scaled by `accTime`. The measurements below remain historical results from the 13 October implementation and workload. Reference engagement durations now represent simulation seconds; see [shared simulation time](simulation-time.md).

## One-second combat and firing aggregation - 13 October 2026

Implemented one-second virtual combat resolution and per-unit, per-magazine firing batches. In the matched 20-group benchmark, precise whole-IVCS p99 fell from **4.6336 to 4.2148 ms (9.0%)**; both seed pairs improved. This is a measured improvement for the normal workload, not a universal tail-latency win: the mod-free forced-ammunition-shortage workload had a higher coarse p99 after the change.

### Implementation and review

- Combat resolution changes from 0.5 to 1 second. The minimum weapon firing interval remains 0.5 seconds and is independent of resolution, preserving the existing cadence floor. Accuracy scale, reload delay, damage, weighted body selection and frame budgets are unchanged.
- Each ready unit counts all firing attempts due in the window, bounded by the current magazine's rounds. It debits those rounds together and advances its firing timer. Empty magazines add the reload delay; if time remains, selection reads fresh inventory and continues with the next compatible magazine or weapon. Dry units cannot bank missed attempts.
- A binomial draw selects the number of successful hits. Only successful hits require enemy selection, body selection and damage records. Independent chunks of at most 32 attempts keep the inverse-CDF calculation numerically stable; this is a numerical bound, not a frame-work budget. Injury-adjusted accuracy is read once per unit's firing window.
- Both groups finish firing before damage and casualty cleanup. Accuracy and casualty effects are resolved at one-second boundaries. The stochastic hit-count distribution is retained, but exact seeded trajectories change because misses no longer consume target-selection draws.
- Review found a handoff race between flushing pending combat and marking the group as spawning. Both now happen in the same atomic setup. Recorded whole and fractional pending time resolves before native objects are created; it is flushed once when both combatants spawn. A combat group killed during that flush cannot create ghost units, while an ordinary empty noncombat group can still spawn.
- The preparation cache depends on the firing interval floor rather than the resolution interval. Current rounds, inventory and injury remain mutable inputs. No production assertions were added. Changed SQF files use CRLF.
- Instrumentation follows the new batching and binomial paths and still supports the archived individual-attempt implementation. Common parent scopes remain comparable; old per-attempt accuracy and new per-window arm-damage scopes represent different work.

### Validation

**473 checks passed, zero failed** across aggregation, original accuracy/damage formulas, scheduling, combat, virtual and live sharing, resumable searches, live movement, prepared shots and instrumentation context. A separate individual-shot timestamp reference validates ammunition consumption, reload timing and firing delays across multiple cadences, magazine inventories and time-window sizes. Hit-count distribution tests validate mean, variance, bounds and large batches. Handoff tests cover fractional pending time, ammunition totals, paired spawning and lethal pending damage.

Twenty reference engagements all finished, averaging **166.15 real-world seconds** (90-259 seconds), against the roughly three-minute target. No accuracy retuning was needed. Native ammunition is checked as totals by magazine class because Arma may select the fullest magazine when creating a unit.

### Matched performance

Stock BLU_F and OPF_F infantry: 20 groups, 10 engagements, 200 m separation. ABBA order uses archived 0.5-second code in trials 1 and 4 and current one-second aggregation in trials 2 and 3, with paired seeds. Normal windows run 30 seconds after two seconds of warmup; pressure windows run 10 seconds. The compared source snapshot matches the final production files byte for byte.

| Workload and timer | Before mean | After mean | Before p99 | After p99 | Before max | After max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Normal, precise Tracy | 1.1918 ms | 1.1265 ms | 4.6336 ms | 4.2148 ms | 5.0575 ms | 5.1447 ms |
| Normal, mod-free coarse timer | 0.7460 ms | 0.6814 ms | 3.9978 ms | 3.9978 ms | 5.0049 ms | 5.0049 ms |
| Forced shortages, mod-free coarse timer | 0.8839 ms | 0.8409 ms | 3.9986 ms | 4.9973 ms | 4.9992 ms | 5.0011 ms |

Precise p99 improves in both pairs: 4.5805 to 4.1736 ms and 4.6342 to 4.2537 ms. Pooled frame counts are 1,676 before and 1,671 after. Shot-preparation CPU totals over the equal-duration measured windows fall from 283.09 to 253.39 ms (10.5%). Combat exchanges fall from 1,202 to 597 because each exchange covers twice as much simulation time. A larger per-exchange duration does not imply more work per second. Parent/child scope timings overlap and must not be added together.

Normal mod-free mean falls 8.7%; its quantized p99 remains about 4 ms. Forced-shortage mean falls 4.9%, but quantized p99 rises from about 4 to 5 ms. The pressure runs complete 39 transfers before and 38 after and pass all throughput checks, including the 90% transfer threshold. After trials finish with 16 and 10 pending donor searches; before trials finish with none. These results identify ammunition-search tail work as remaining follow-up rather than showing that every workload improved. Coarse timing has approximately 1 ms resolution.

All normal workload checks pass (20/20 in each profiled and mod-free run); forced-shortage checks pass 24/24. The progress check allows one resolution interval plus the existing 0.5-second scheduling slack: 1 second before and 1.5 seconds after. Frame/search budgets and service limits are unchanged. Startup and cold imports are outside the warm measured windows. The comparison measures this combined resolution-and-aggregation change; it does not isolate their individual contributions.

Evidence: [precise comparison](combat-performance-results/aggregation-profiled-comparison.json), [operation attribution](combat-performance-results/aggregation-operations-summary.json), [mod-free comparison](combat-performance-results/aggregation-unprofiled-comparison.json), [shortage comparison](combat-performance-results/aggregation-pressure-comparison.json), [regression and source verification](combat-performance-results/aggregation-verification.json).

Precise capture: `C:\Users\spyde\.codex\skills\capture-tracy\captures\arma-20261013-155620-0af305cc.tracy` (3,507,878 bytes; Zstd, four streams). Capture saving completed successfully. Raw frame CSVs and benchmark summaries are stored beside the comparisons.




## Prepared firing entries and hot accuracy path - 13 October 2026

Additional preprocessing is implemented. **A complete ready 16-shooter exchange costs 11.6% less CPU**, but this pass **does not demonstrate a lower whole-IVCS 20-group p99**. The matched final precise comparison is **4.5329 ms before and 4.5772 ms after**. Keep these results distinct from the earlier needs-scan improvement and from unrelated runs with different host timing.

### Implementation and review

- Unit import prewarms combat weapon and ammunition configuration profiles, including ammunition carried in cargo. Configuration parsing moves out of first-shot work. Startup costs are not measured by the warm comparison.
- Each engagement prepares a weapon-class entry with its immutable weapon profile, scaled firing interval, and ammunition-class map. Each supported ammunition entry holds its profile and exact-range factors. Selection and preparation now use two cache lookups instead of separately looking up class metadata and then the same weapon/ammunition pair again.
- Range, accuracy scale, cadence scale and simulation tick size invalidate these entries. Reload delay is read each exchange. The original multiplication, maximum and addition order is retained.
- Every attempt reads current weapon arrays and magazine records. Empty rounds, ammunition transfers, insertion, reordering and weapon replacement are not cached. Unsupported ammunition remains excluded; cold metadata adapters handle gear classes introduced later.
- The firing loop evaluates the short injury expression using prepared factors, retaining fresh arm damage and the existing validated layout cache. This avoids the five-argument accuracy dispatch and its unused configuration/factor fallback checks. The standalone accuracy API remains available; differential tests keep its formula and the hot expression aligned.
- The standalone shot selector uses an early-ending find instead of maintaining a separate exit guard. No production assertions were added. RNG draw order, magazine identity, simultaneous firing and casualty resolution remain unchanged. Changed SQF uses CRLF.
- Review found a stale profiling-context anchor that expected factor misses inside `step`. The hook now follows preparation in `getPreparedShot`, retains legacy-step support, and passes the context smoke test. Accuracy scopes cover equivalent work on both versions. The comparison harness supports reversed order for replication.

### Final matched 20-group timings

Stock BLU_F/OPF_F squads at 200 m run four 30-second windows in before/after/after/before order with paired seeds and two seconds of warmup. All **20/20** workload checks pass. The **3 ms combat allowance**, **1 ms search allowance**, queue caps and needs/donor slice sizes are unchanged. Exact frame counts and operation-scope counts match the RPT.

| Metric | Before | After |
| --- | ---: | ---: |
| Whole IVCS frame mean ms | 1.2557 | 1.2464 |
| Whole IVCS frame p99 ms | **4.5329** | **4.5772** |
| Whole IVCS frame maximum ms | 5.8570 | 9.3350 |
| Shot preparation mean per exchange ms | 0.2804 | 0.2464 |
| Shot preparation p95 per exchange ms | 0.8040 | 0.6741 |
| Shot preparation p99 per exchange ms | 0.9386 | 0.9291 |
| Summed shot preparation p99 per frame ms | 2.5380 | 2.2997 |
| Ready 16-shooter exchange mean ms, mod-free | 0.5500 | 0.4863 |

Preparation CPU falls **12.1%** per exchange and its summed frame p99 falls **9.4%**. Per-exchange p99 is nearly flat. Whole-frame p99 is **1.0% higher**, rather than an improvement; matched seed pairs are mixed: **4.6913 to 4.5214 ms** and **4.3943 to 4.6210 ms**. The maximum after frame is retained in the analysis. Faster firing alone has not removed the remaining tail.

Trace: `arma-20261013-145855-24eeff76.tracy`, **3,903,964 bytes**, Tracy **0.12.4**, **Zstd**, four streams; recorder elapsed **230.1 s**, timeline **243.0 s**. Embedded environment: Windows 10.0.19045, i7-10700F, 16 logical CPUs and 32,689 MB RAM. Across the whole trace including warmups, preparation totals **693.04 ms inclusive** and **80.94 ms self**; its children overlap the inclusive total and must not be added again. Measured-window distributions and frame attribution are separate from those whole-trace aggregates. [Final precise comparison](combat-performance-results/firing-final-profiled-comparison.json), [frame attribution](combat-performance-results/firing-final-operations-summary.json), [ready-exchange samples](combat-performance-results/firing-final-micro-summary.json).

### Mod-free costs, replication and correctness

| Workload | Metric | Before | After |
| --- | --- | ---: | ---: |
| Normal 20 groups | Frame mean ms | 0.8385 | 0.7914 |
| Normal 20 groups | Frame p99 ms | 3.9978 | 3.9978 |
| Normal 20 groups | Frame maximum ms | 4.9896 | 5.0049 |
| Forced shortages, 20 groups | Frame mean ms | 0.9731 | 0.9427 |
| Forced shortages, 20 groups | Frame p99 ms | 4.4397 | 4.0016 |
| Forced shortages, 20 groups | Frame maximum ms | 5.0011 | 6.0005 |

Normal windows last 30 seconds, shortage windows ten. The timer has approximately **1 ms resolution**; the shortage p99 difference is interpolation between coarse bins and is not evidence of a precise 0.438 ms gain. Before and after each complete **39/40** forced transfers. All **20 normal** and **24 shortage** workload checks pass, including actual firing, simulation progress and transfer throughput. [Normal comparison](combat-performance-results/firing-final-unprofiled-comparison.json), [shortage comparison](combat-performance-results/firing-final-pressure-comparison.json).

An earlier preprocessing-only prototype appeared to improve p99 in one ABBA capture. A reverse-order BAAB replication did not reproduce that result: pooled p99 was **4.9842 before / 5.0298 after**, and mod-free mean increased. Those captures are retained, not presented as a performance win. The final hot accuracy change subsequently reduced firing CPU. [Prototype replication evidence](combat-performance-results/prepared-profiled-comparison.json), [prototype mod-free evidence](combat-performance-results/prepared-unprofiled-pooled.json).

Final verification passes **504/504** checks: prepared-shot/mutation differential tests 376, original-formula/layout tests 40, combat/handoff tests 71, scheduling tests 12, and profiling-context smoke tests 5. All **20 complete seeded fight outcomes match exactly**, with mean duration **170.45 s**. The final benchmark's production sources match the saved final files. [Verification and review](combat-performance-results/firing-final-verification.json).

**Next tail work:** reduce the size of a complete firing-preparation batch while preserving simultaneous damage application and safe native handoff. More immutable metadata caching can still save small amounts of CPU, but the measurements do not support expecting it alone to substantially lower whole-frame p99. Smaller resumable firing phases are a more promising next experiment than lowering budgets. That is a recommendation from the remaining frame attribution, not a measured result or an implemented change in this pass.


## Resumable whole-group needs scans - 13 October 2026

Needs scanning now shares the existing discovery job and frame queue. A standard eight-unit squad is checked in **two four-member visits** rather than one whole-roster pass. The **3 ms combat allowance**, **1 ms search allowance**, two donor inspections per slice, queue visit caps, scan interval and approach/collection delays remain unchanged. This changes the size and placement of inventory work, not the time budget.

### Implementation and review

- `scanNeeds` retains a roster cursor and shortage candidates. Roster copying uses native shallow slicing so the job holds actual unit HashMap references. Weapon arrays, rounds, cargo and native inventories are read when a member is visited; no inventory-content cache is introduced.
- Group updates use their existing validation to run the initial needs slice. Subsequent visits resume through `advanceSearch` and its existing queue. Supplied jobs clear without donor-state allocation. Filtered roster and parallel needs arrays are no longer constructed for every supplied scan.
- Eligibility is checked when a shortage is found. Reading an ineligible actor's inventory is harmless; these actors still cannot become recipients/donors or receive movement/transfer commands. Recipient and donor priority is rebuilt from the current eligible roster when scanning finishes. Existing reservation and transfer checks retain current need, membership, eligibility, compatibility, reserve and token validation.
- Virtual primary priority is applied when adding a shortage, removing unconditional final-list processing and its array copies. Duplicate primary entries retain the original deduplication policy. Native class metadata uses the warm shared cache, with adapters retained for misses.
- A queued visit executes atomically, including validation and its scan/donor work. Batch callers drain the same policy synchronously with a negative limit. Spawn/despawn, cancellation and unregister clear the same existing job/queue state.
- Profiling distinguishes the inclusive `DiscoverySlice` wrapper from its donor body. Needs and donor blocks remain disjoint even when a visit finishes scanning and then inspects donors. Existing context hooks track visited members and new shortage candidates.

New members enter the next scan cycle; removed members cannot reserve ammunition. An observation from an earlier slice is revalidated before committing. No production assertion guards were added. The cold-class adapters and queue-membership checks remain necessary. Changed SQF uses CRLF.

### Complete, matched precise 20-group comparison

One saved trace contains all four **before / after / after / before** windows, with paired seeds, stock BLU_F/OPF_F squads at 200 m, normal combat and identical instrumentation. Each window lasts 30 seconds after two seconds of warmup. All **20/20** workload checks pass; phase boundaries, exact frame counts and disjoint scope counts match the RPT.

| Metric | Before | After |
| --- | ---: | ---: |
| Whole IVCS frame p99 ms | **5.0506** | **4.4581** |
| Whole IVCS frame mean ms | 1.2015 | 1.2339 |
| Whole IVCS frame max ms | 5.7253 | 5.4488 |
| Needs visit mean ms | 0.2251 | 0.1302 |
| Needs visit p99 ms | 0.3034 | 0.1823 |
| Needs visits | 1,200 | 2,400 |

Aggregate whole-frame p99 falls **11.7%**; needs-visit p99 falls **39.9%**. Both seed pairs improve independently: **5.1445 → 4.4833 ms** and **4.9081 → 4.4489 ms**. Before records 1,672 frames and after 1,673. Smaller visits must not be mistaken for less total CPU: there are twice as many visits, with resume overhead. Inclusive discovery timings also overlap their needs children and must not be summed with them.

Trace: `arma-20261013-140255-36fa277d.tracy`, **3,770,644 bytes**, Tracy **0.12.4**, **Zstd**, four streams. Recorder elapsed time is 205.4 seconds; the trace timeline extends to 244.9 seconds because scopes can start before connection. Embedded environment: Windows 10.0.19045, i7-10700F, 16 logical CPUs and 32,689 MB RAM. [Complete distributions, matched pairs and metadata](combat-performance-results/needs-profiled-comparison.json), [operation attribution](combat-performance-results/needs-operations-summary.json).

### Mod-free costs and throughput

A separate ABBA run uses paired seeds and unchanged budgets. Normal 20-group combat has two 30-second windows/version. Forced-shortage 20/80-group workloads have two 10-second windows/version, reversing size order on alternating trials.

| Workload | Version | IVCS mean ms | IVCS p99 ms | IVCS max ms |
| --- | --- | ---: | ---: | ---: |
| Normal 20 groups | Before | 0.6867 | 4.0054 | 5.0049 |
| Normal 20 groups | After | 0.7421 | 3.9978 | 4.9973 |
| Shortage 20 groups | Before | 0.8907 | 4.9973 | 5.9967 |
| Shortage 20 groups | After | 0.9589 | 4.4220 | 5.9967 |
| Shortage 80 groups | Before | 2.5445 | 5.0049 | 7.0000 |
| Shortage 80 groups | After | 2.6987 | 5.0011 | 6.0043 |

The approximately 1 ms clock does **not establish a normal 20-group mod-free p99 reduction**. The shortage 20-group p99 is interpolated between coarse bins in short windows; it is not a precise 0.58 ms guarantee. Means are slightly higher in every workload: normal 20-group mean adds about **0.055 ms/frame**. This is a latency/CPU tradeoff, not an overall CPU-saving claim.

All normal **20/20** and shortage **48/48** checks pass, including real-time progress and the original 90% transfer requirement within 10 seconds. Both versions complete **39/40** forced transfers at 20 groups. At 80 groups, before completes **153/160**, after **154/160**; alive unresolved recipients total five/four respectively across the two windows.

A direct stock probe alternates version order for 16 samples/version, each repeating 200 complete synchronous scans. Mean cost is **0.19469 → 0.20531 ms**, about **5.5% higher**, including eligibility and bookkeeping. Splitting work is retained because the precise frame tail improves in both matched pairs while throughput holds, despite this small overhead. Earlier prototypes with larger overhead were simplified before the final comparison.

[Normal validity](combat-performance-results/needs-unprofiled-summary.json), [normal version distributions](combat-performance-results/needs-unprofiled-comparison.json), [shortage validity](combat-performance-results/needs-pressure-summary.json), [shortage distributions](combat-performance-results/needs-pressure-comparison.json), [complete-scan samples](combat-performance-results/needs-micro-summary.json).

### Correctness and reproduction

The existing context/instrumentation benchmark also passes **5/5** workload checks. All **433 behavioral checks pass**: bounded scan/mutation/batch equivalence 28, independent inventory/needs/reserve equivalence 197, resumable discovery 21, virtual/live sharing 45, arrival/collection 59, scheduling 12 and combat 71. All **20 complete seeded fights match the previous baseline exactly**, retaining the **170.45-second** mean duration. Cases include large rosters, zero limits, live reference identity, replaced inventory arrays, pickups, removals/additions, stable priorities, cold caches, reserved spares, native transitions, token conservation and fair queue rotation. [Verification and exact source hashes](combat-performance-results/needs-verification.json).

```powershell
& tests/combat/needs-performance.ps1 -BaselineDirectory <saved-before-functions> -Seconds 30
& tests/combat/needs-performance.ps1 -BaselineDirectory <saved-before-functions> -AmmoPressure -GroupCounts @(20,80) -Seconds 10
& tests/tasks/run.ps1 -TestScript tests/combat/needs-scan.sqf
```

The remaining tail still includes firing preparation and complete exchanges admitted near a coarse deadline. This change reduces clustered scan work without lowering allowances or relaxing inventory/reserve correctness.

## Shot path efficiency and 20-group p99 - 13 October 2026

The next change removes repeated work in firing preparation without changing the **3 ms combat allowance**, **1 ms donor-search allowance**, scan intervals, exchange quota or donor slice size. Infantry rules, damage, accuracy, reloads and deterministic random draw order remain the same.

### Implementation

- `getShot` reads immutable weapon/ammunition class caches directly, retaining the profile-building adapters for misses. It returns the supported ammunition profile captured during selection instead of looking it up again. The chosen magazine remains the current unit's mutable record; rounds and replaced weapon/magazine arrays are always read afresh.
- Engagement factors use nested weapon-class / magazine-class maps instead of serializing a pair into a string for every shot. Exact range and accuracy-setting invalidation remains unchanged.
- Firing holds the integer random seed and shot count locally, then writes each once after both rosters fire. Settings, target count and weighted region data are read once per exchange or roster. Both firing rosters still resolve before damage, preserving simultaneous fire.
- Context instrumentation reads the shot counter after the batched write. No production assertion guards were added; cache-miss fallbacks remain necessary for newly introduced gear classes.

### Direct stock operation measurements

These mod-free probes alternate version order and repeat calls enough times to exceed the approximately 1 ms clock quantum. Stock eight-unit BLU_F/OPF_F squads provide 16 inventory shapes. The ready exchange includes resetting all 16 fire delays; zero accuracy isolates firing work from damage. Complete frame benchmarks below use normal accuracy.

| Operation | Before mean ms | After mean ms | Reduction |
| --- | ---: | ---: | ---: |
| Warm stock shot selection, 64 samples/version | 0.01603 | 0.00863 | 46.2% |
| Ready 16-shooter exchange, 8 samples/version | 0.85751 | 0.63875 | 25.5% |

[Method and raw samples](combat-performance-results/shot-micro-summary.json).

### Precise paired 20-group frame costs

A saved Tracy trace provides one complete **after / before** pair using the same seed set, 30 seconds per window and two seconds of warmup. Both versions have identical operation/per-shooter scopes. The recorder attached after the first before window began, so only complete, matched **trials 3 and 4** contribute to this comparison; the partially captured first trial and unpaired second trial are explicitly excluded.

| Metric | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Whole IVCS frame mean ms | 1.2734 | 1.2098 | 5.0% |
| Whole IVCS frame p99 ms | **5.1778** | **4.6509** | **10.2%** |
| Whole IVCS frame max ms | 5.7466 | 5.2565 | 8.5% |
| Shot preparation mean ms/call | 0.3516 | 0.2684 | 23.7% |
| Shot preparation p99 ms/call | 1.2041 | 0.8508 | 29.3% |

Before has 831 measured frames / 604 exchanges; after has 833 frames / 602 exchanges. Selected phase boundaries, exact frame counts and disjoint block scope counts are validated against the passing RPT. There are no donor searches in these normal-combat windows. Nested helper timings must not be added to their parents. This is evidence of improvement in a scoped matched pair, not a guaranteed production p99.

The trace is **3,443,256 bytes**, Tracy **0.12.4**, **Zstd**, four streams. Recorder elapsed capture time is 128.5 seconds; its trace timeline extends to 191.5 seconds because scopes can begin before connection. Embedded environment: Windows 10.0.19045, i7-10700F, 16 logical CPUs and 32,689 MB RAM. [Paired distributions and capture metadata](combat-performance-results/shot-profiled-comparison.json), [complete operation attribution](combat-performance-results/shot-operations-summary.json).

### Production frame costs without profiler mods

A separate complete **before / after / after / before** benchmark uses paired seeds, stock groups and unchanged budgets. All 20 normal-combat workload checks pass. Each version has two 30-second windows and **1,202 exchanges**.

| Workload | Version | Frames | IVCS mean ms | IVCS p99 ms | IVCS max ms |
| --- | --- | ---: | ---: | ---: | ---: |
| Normal 20-group combat | Before | 1,665 | 0.7040 | 4.0016 | 5.0049 |
| Normal 20-group combat | After | 1,661 | 0.6888 | 4.0054 | 5.0049 |
| 20 groups with forced shortages | Before | 558 | 0.9355 | 4.9992 | 7.0000 |
| 20 groups with forced shortages | After | 558 | 0.9445 | 5.0011 | 6.0005 |

The coarse clock does **not establish a mod-free p99 reduction**. The forced-shortage run uses two 10-second windows/version and passes all **24/24** validity checks. Each version completes 39 of 40 forced transfers, with one recipient still unresolved; both meet the original 90% requirement and maintain real-time combat progress. Its slightly higher optimized mean does not establish a throughput improvement under shortage pressure.

A separate road-extraction Arma server was also active during this investigation. It was left untouched. Paired results reflect that background workload; they should not be treated as measurements from an otherwise idle machine. An earlier incomplete benchmark and an aborted instrumentation setup are excluded from the comparison.

Normal frame samples (raw frame samples retired), [normal version distributions](combat-performance-results/shot-unprofiled-comparison.json), [shortage validity](combat-performance-results/shot-pressure-summary.json), [shortage version distributions](combat-performance-results/shot-pressure-comparison.json).

### Remaining tail and reproduction

Shot preparation is cheaper, but whole-group needs scans still cluster with due exchanges. The optimized worst frame has three exchanges and **1.529 ms needs scans**. Another tail frame has five exchanges and **2.461 ms needs scans**, versus **0.902 ms shot preparation**. The next meaningful efficiency target is the repeated supplied-group scan, with current-inventory freshness and sidearm/primary needs preserved. Finishing complete exchanges near a coarse deadline also remains a contributor; no budget reduction was used here.

```powershell
& tests/combat/shot-performance.ps1 -BaselineDirectory <saved-before-functions> -Seconds 30
& tests/combat/shot-performance.ps1 -BaselineDirectory <saved-before-functions> -AmmoPressure -Seconds 10
& tests/tasks/run.ps1 -TestScript tests/combat/shot-work.sqf
& C:\Python39\python.exe tests/combat/analyze-operations.py <trace> --output docs/combat-performance-results --label shot-operations --benchmark-summary docs/combat-performance-results/shot-profiled-summary.json --trials 3 4
```

All **448 behavioral checks pass**: shot selection/exchange equivalence 280, preprocessing/invalidation 40, virtual/live sharing 45, scheduling 12 and combat 71. The existing 20-group context/instrumentation benchmark also passes **5/5** workload checks. All **20 complete seeded fight outcomes match the previous baseline exactly**; mean duration remains **170.45 seconds**. Review verified current inventory reads, mutable record identity, cold caches, RNG order, simultaneous firing and settings invalidation. Correctness records and source hashes are in [verification](combat-performance-results/shot-verification.json). All changed SQF uses CRLF.

## Donor inventory and needs-scan optimization - 13 October 2026

The earlier **6.758 ms** frame contains four inline slices and four group needs scans. Disjoint block costs are **3.089 ms donor slices** and **2.233 ms needs scans**. Inside those slices, eight donor inventory inspections consume **2.040 ms**, including **1.229 ms surplus reconstruction** and **0.519 ms snapshots**. These nested costs must not be summed with their parent slices. Compatibility fallbacks contribute only **0.147 ms** across the frame; they are not its main expense.

### Final changes

- Surplus selection removes the separate loaded-magazine protection pass. The final availability filter already rejects loaded magazines. Starting each spare search at zero also removes the duplicate positive-rounds check. Warm weapon metadata is read directly, with a cache-miss adapter for new classes. Fullest-spare selection, inventory-order ties, overlapping compatibility pools and outgoing magazine order remain unchanged.
- Virtual snapshots classify each weapon once using the shared immutable class cache. The supported-weapon filter is folded into that pass, eliminating another walk and duplicate profile calls. Every magazine and its current loaded flag, source and record token remain present.
- Needs checks read prewarmed class metadata directly and skip the already searched weapon-record array during compatibility fallback. They still read current rounds, cargo and weapon lists; no inventory-content cache is introduced.
- Winner revalidation uses the existing targeted reservation validator rather than rebuilding all donor surplus. That inventory inspection consumes a slice slot too. A slice that exhausts its donor quota leaves winner validation for the next visit.
- Virtual collection uses its scheduled arrival timestamp plus the full collection delay. A poll after arrival no longer restarts the collection timer. Native collection still starts when the recipient is observed within 1 m.

**Existing searches still advance inline**, using the original two-inspection slice. Their inventory work is cheaper and winner validation can no longer become a third inspection. The **3 ms combat allowance**, **1 ms search allowance**, scan intervals and largest-surplus donor preference remain unchanged.

### Direct operation timings without profiler mods

Stock eight-unit BLU_F and OPF_F squads provide 16 inventory shapes. Four trials alternate version order. Each unscheduled sample executes 200 reserve/snapshot calls or 500 needs calls, then divides total elapsed time by repetitions to exceed the Windows timer quantum. Class caches are warm and inventories are read afresh. Values below are means across 64 samples per version, in milliseconds per call.

| Operation | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Surplus reconstruction | 0.13485 | 0.10336 | 23.3% |
| Virtual inventory snapshot | 0.04813 | 0.03899 | 19.0% |
| Supplied-unit needs check | 0.02678 | 0.02103 | 21.5% |

These isolate the identified operations on stock inventories. They do not predict a complete frame by adding inclusive profiler timings. [Samples, method and comparisons](combat-performance-results/sharing-micro-summary.json).

### Matched production frame costs

A separate mod-free benchmark alternates **before / after / after / before**, with paired combat seeds, reversed size order, and one forced rifle recipient per group. It uses two 10-second windows per implementation and group count, after two seconds of warmup. All **48/48 workload checks pass**, including real-time progress and at least 90% of forced transfers completing in the original 10-second window.

| Groups | Version | IVCS mean ms | IVCS p99 ms | IVCS max ms |
| --- | --- | ---: | ---: | ---: |
| 20 | Before | 1.942 | 5.997 | 9.998 |
| 20 | After | 2.005 | 5.997 | 11.002 |
| 80 | Before | 3.902 | 9.277 | 13.001 |
| 80 | After | 3.783 | 8.293 | 12.001 |

The observed 80-group p99 falls about **10.6%**. The 20-group p99 is unchanged and its mean/max are slightly higher. These short windows and the approximately 1 ms timer resolution do not establish a general p99 guarantee. [Passing validity](combat-performance-results/sharing-unprofiled-summary.json), complete frame samples (raw frame samples retired), [version-separated distributions](combat-performance-results/sharing-unprofiled-comparison.json).

### Correctness and review

All **405 behavioral checks pass**: independent snapshot/reserve/needs equivalence and quota checks 197, arrival/collection 59, native/virtual sharing 45, resumable search 21, scheduling 12, and combat 71. The snapshot, surplus and needs references are the archived previous implementations. Cases include changed weapon lists, missing class-cache entries, loaded/empty magazines, overlapping pools, equal-round ties, incompatible cargo, stale winners, exact partial rounds, conservation and spawn/despawn cleanup. All 20 complete seeded combat outcomes match the previous baseline; mean engagement duration remains **170.45 seconds**.

Review retained freshness, eligibility, compatibility and ownership checks. It removed redundant reserve guards/passes and duplicate metadata work. No assertion guards were added. All changed SQF uses CRLF.

Rejected variants are not part of the final implementation or comparison evidence. Grouping reserves by magazine class added allocations and was slower on the stock workload. Moving all donor work to the frame queue, limiting inline continuations to one inspection, and allocating 2 ms to discovery each produced failed 10-second sharing checks in at least one 80-group trial. The final version keeps original throughput and budgets while reducing operation cost. [Source hashes, regression records and rejected-variant notes](combat-performance-results/sharing-verification.json).

```powershell
& tests/combat/sharing-performance.ps1 -BaselineDirectory <saved-before-functions> -Unprofiled -Seconds 10 -StartupDelaySeconds 0 -PostDelaySeconds 0
& tests/tasks/run.ps1 -TestScript tests/combat/sharing-micro.sqf
& tests/tasks/run.ps1 -TestScript tests/combat/sharing-work.sqf
```

## Arrival and collection optimization - 13 October 2026

The expensive operation was rebuilding the donor's complete surplus list to validate one already reserved magazine. In the earlier trace, ready checks averaged **0.515-0.522 ms**: surplus reconstruction consumed **0.257-0.261 ms**, snapshots **0.142-0.144 ms**, and transfer averaged **0.009 ms** across arrival/collection calls.

`IVCS_Ammo_getReservedMagazine` now validates that one token against the current donor snapshot, checking only compatible donor weapons and stopping when another reserve proves the candidate shareable. It preserves loaded magazines, one fullest spare, first-in-inventory tie order, and overlapping compatibility pools. Virtual recipients use direct needs checks. A recipient who already has ammunition cancels before donor reconstruction. Snapshots remain local to the atomic update and are invalidated after a transfer.

### Matched scoped timings

A single capture alternates **before / after / after / before** with stock eight-unit BLU_F/OPF_F groups at 200 m and forced ammo shortages. Adjacent trials use paired engagement seeds; size order reverses on alternate trials. Each window lasts 20 seconds after two seconds of warmup. The allowance remains **3 ms**. Means below are weighted by call count across two trials of each version, in milliseconds per request.

| Groups | Check | Before mean | After mean | Reduction |
| --- | --- | ---: | ---: | ---: |
| 20 | Arrival ready | 0.688 | 0.331 | 51.8% |
| 20 | Collection ready | 0.671 | 0.397 | 40.8% |
| 80 | Arrival ready | 0.635 | 0.297 | 53.3% |
| 80 | Collection ready | 0.686 | 0.355 | 48.2% |

At 20 groups, arrival p99 is **1.423 / 1.619 ms** before and **0.625 / 0.496 ms** after. Collection p99 is **0.845 / 0.938 ms** before and **1.878 / 0.482 ms** after: one optimized trial has an outlier, so collection tail improvement is not established. Each window has only 20-21 ready calls. The targeted helper has **0.068 ms mean**, **0.176 ms p99**, **0.823 ms max**, and no calls above 1 ms across the capture. Inclusive parent and helper times must not be added together.

All **4,551 measured frames** have context. The scoped run finishes with **44 passing / 4 failing** checks: all failures are 80-group real-time progress checks, for both versions. All forced-sharing checks pass, and every 20-group window passes. These diagnostic timings establish smaller request work, not production frame p99 improvement.

### Production frame costs without profiler mods

A separate **mod-free** before/after/after/before run uses the same paired-seed ammo-pressure workload and 3 ms allowance, with two 10-second windows per implementation and size. All **48/48 workload checks pass**, including real-time progress at 80 groups and forced sharing. It records **2,284 frames**.

| Groups | Version | IVCS mean ms | IVCS p99 ms | IVCS max ms |
| --- | --- | ---: | ---: | ---: |
| 20 | Before | 2.076 | 5.999 | 6.996 |
| 20 | After | 1.959 | 5.998 | 7.004 |
| 80 | Before | 3.969 | 7.000 | 11.993 |
| 80 | After | 4.040 | 7.274 | 10.002 |

The cheaper request checks do **not** demonstrate a whole-frame p99 improvement in these short windows. The 80-group mean/p99 are slightly higher after the change; this run does not isolate that variation from other combat and scheduler work. Shot preparation, group needs scans and inline donor slices remain the larger tail contributors. Windows timers have approximately 1 ms resolution here. [Passing validity and raw frame summaries](combat-performance-results/arrival-unprofiled-summary.json), samples (raw frame samples retired), [version-separated distributions](combat-performance-results/arrival-unprofiled-comparison.json).

### Correctness and evidence

All **121 engine regression checks pass**: arrival policy 55, live/virtual sharing 45, resumable sharing 21. The new suite compares **576 candidates** with full surplus policy, covering rifles/pistols/launchers, overlapping pools, equal-round ties, loaded/empty magazines, and incompatible cargo. It also covers recipients obtaining ammo before arrival, moved tokens, candidates becoming loaded, inventory changes during collection, and multiple requests sharing a donor. Live checks verify walking, the 1 m distance, physical backpack removal, exact rounds, reloading, and conservation.

Review retained current-inventory checks and transfer invalidation, removed unused surplus caches and the unnecessary empty-weapon fallback in the internal request path, and added no assertion guards. All changed SQF files use CRLF.

- [Before/after request comparisons](combat-performance-results/arrival-comparison.json), [context and substage timings](combat-performance-results/arrival-situations-summary.json), [complete scoped operations](combat-performance-results/arrival-operations-summary.json).
- [Regression/source verification](combat-performance-results/arrival-verification.json), [scoped workload validity](combat-performance-results/arrival-profiled-summary.json), [recorder session](combat-performance-results/arrival-session.json).
- [Targeted validation](../VirtualSpace/functions/ammo/getReservedMagazine.sqf), [regression suite](../tests/combat/arrival-sharing.sqf), [matched benchmark](../tests/combat/arrival-performance.ps1).

The trace saved and compressed successfully: Zstd, four streams, **13,110,309 bytes**, **1,978,535 zones**, about **246 seconds of recorded data**. The exported axis spans 278.7 seconds, including profiler startup before connection. The server reports Arma 3 **2.22.154103**, Windows x64, speed **1x**. Raw traces and exports remain in the recorder capture directory.

```powershell
& tests/combat/arrival-performance.ps1 -BaselineUpdateRequests <saved-before-updateRequests.sqf> -Seconds 20 -ExtraArguments <profiler/dependency arguments>
# Connect the matching recorder during the startup delay.
& tests/combat/arrival-performance.ps1 -BaselineUpdateRequests <saved-before-updateRequests.sqf> -Unprofiled -Seconds 10 -StartupDelaySeconds 0 -PostDelaySeconds 0
```

## Contextual instrumentation — 13 October 2026

Opt-in `-ContextScopes` diagnostics now pair precise operation scopes with workload context. They are installed only in the isolated benchmark. Production combat, sharing, and scheduler source hashes remain unchanged.

Captured context includes engagement/group/unit IDs, roster sizes, shots/hits, factor-cache misses, needs scans and needy recipients, weapon magazine-record counts and cargo counts, own-record versus inventory-fallback checks, compatibility-cache hit/miss scopes, donor cursors and inline/queued origins, inventory inspections and winner revalidation, request phase/waiting state, pending combat time, queue sizes, search priority, and remaining deadline at each engagement visit. The analyzer joins records to actual scope occurrences and lists the operations in each slow frame.

### Situations behind multi-millisecond frames

| Observed frame | Work in the frame | Measured contributions |
| --- | --- | --- |
| Normal combat, 20 groups: **6.245 ms** | Two full-roster exchanges, **32 shots**, four supplied-group needs scans | Shots **2.742 ms**; needs scans **2.202 ms** |
| Ammo shortage, 80 groups: **6.758 ms** | Two exchanges, four shots, **four inline donor slices**, four needs scans | Donor slices **3.089 ms**; needs scans **2.233 ms**; shots **0.474 ms** |

The shortage example performs eight donor inventory inspections, with no winner revalidation and no queued slices in that frame. The second engagement visit is recorded near the deadline (approximately 0.015 ms remaining on the coarse clock) but completes another whole exchange and its sharing work. Inline search work occurs for existing jobs as well as newly created jobs: in pressure-80 trial 1 there are **225 inline slices** for **82 needy scans**. This shows that resumable jobs can still concentrate several inspections inside combat updates.

Normal peaks repeatedly coincide with several firing exchanges and group scans in one frame. Needs scans also produce slow frames without shots. Compatibility fallbacks are measurably more expensive than supplied-unit checks, but their observed individual costs are far below the frame spikes.

| Situation (sampled diagnostic calls) | Typical mean across windows |
| --- | ---: |
| Every current unit fires in one exchange | **1.11–1.31 ms** for shot preparation |
| No unit fires in an exchange | **0.061–0.068 ms** |
| One unit needs check, using own magazine records | **0.046–0.057 ms** |
| One unit needs check, falling back to cargo/other weapons | **0.074–0.078 ms** |
| Pending request still waiting | **0.108–0.116 ms** |
| Arrival ready; reserves validated | **0.489–0.502 ms** |
| Collection ready; validation/transfer performed | **0.526–0.542 ms** |
| Queued donor slice with winner revalidation | **0.877–0.955 ms** |

These means come from frames that emitted context in the long capture; they are conditional samples, not whole-run population means. Inclusive parent/helper timings overlap and must not be summed. Arrival/collection handling is about five times as expensive as cheap waiting checks. Winner slices can add an extra inventory/reserve inspection to the normal donor quota.

Compatibility-cache hit scopes have **0.003 ms p99** and **0.043 ms maximum** across the long capture; no misses occurred inside its measurement windows. Own-record checks have **0.007 ms p99**, and fallback scopes have **0.031 ms p99**. The earlier 5.824 ms group-needs outlier was not reproduced. The largest needs scan here is **2.836 ms** and the largest contextual single-unit needs check is **0.594 ms**. This does not establish the cause of the earlier outlier or rule out OS/profiler stalls.

### Coverage and instrumentation overhead

The long capture covers **6,715 frames**, two 30-second windows per mode and size at 20/80 groups, with reversed order on trial 2 and two seconds of warmup. Context covers **3,389 of 3,392 frames above 3 ms (99.91%)**. The three uncovered frames remain listed with their operation timings; all report coarse costs of 1.9989 ms and precise totals of 3.137/3.500/3.320 ms. A `>=2` coarse-timer output filter suppressed their context.

The final collector therefore emits **every measured frame’s context**, after the measured root closes, in small trace messages. `IVCS_DIAG_ContextFlush` measures emission separately. No context messages go to the RPT. Message parsing uses tab-separated export because the exporter does not quote commas in array payloads. Default context analysis rejects missing coverage; an explicit `--allow-partial-context` flag is required for the earlier filtered capture and retains every gap.

The final 20/80-group validation capture has **281 frames**, **10/10 passing benchmark checks**, and complete matching of all **114/114 frames above 3 ms**. Flush mean/p99/max is **0.062/0.219/0.222 ms** at 20 groups and **0.121/0.276/0.281 ms** at 80 groups. These five-second windows validate instrumentation and coverage, not steady-state performance.

That short capture also contains a **40.547 ms first root frame** at 80 groups: combat accounts for **3.289 ms**, while **36.923 ms** sits outside the named component scopes. The coarse benchmark timer reports 4.002 ms. The handler’s first-frame RPT diagnostic executes before that timer starts, inside the root scope, making first-frame logging/wrapper startup a measurement artifact candidate. That RPT diagnostic has now been removed from the timed handler. The retained validation data preserve the artifact; its wall-time gap is not attributed to combat.

### Validity limits and evidence

The long run is **diagnostic evidence**, explicitly **ineligible for performance comparisons**. It completes with **42 passing / 2 failing** benchmark checks. Both failures are normal-80 progress checks: minimum progress is 29 seconds during 30.034/30.005-second windows, just beyond the existing one-second limit. All combat-activity and forced-sharing checks pass. Instrumentation increases group-scan cost and changes scheduling; these data do not replace the unprofiled baseline or demonstrate production p99 improvement. The combat allowance stays at **3 ms**.

Analysis defaults remain strict. `--diagnostic` permits attribution of a completed run with failed progress checks while retaining the failures and disabling comparison eligibility. It does not permit missing frame samples, script errors, broken combat activity, missing phase boundaries, or mismatched scopes. The engine benchmark’s checks themselves remain unchanged.

Context-enabled combat regression passes **71/71 checks**, with all **20 seeded outcomes identical** and mean fight duration **170.45 seconds**. The final flush change passes an additional single-size smoke run (5/5 checks) and the paired collector capture (10/10). The subsequent removal of the first-frame diagnostic only removes benchmark logging. All edited SQF files use CRLF.

**Next targets supported by these situations:** make shot preparation smaller; route or subdivide inline donor work so two group updates cannot stack several slices inside one engagement visit; spread or subdivide supplied-group needs scans; then evaluate cost-aware admission against the remaining deadline. Preserve real-time progress while doing so. Damage/casualty processing and warm compatibility lookups remain smaller targets in these stock virtual scenarios.

- [Slow-frame situations, operation inputs, conditional timings, and explicit gaps](combat-performance-results/context-situations-summary.json).
- [Diagnostic operation timings](combat-performance-results/context-operations-summary.json), [complete frame samples and validity](combat-performance-results/context-profiled-summary.json), and [fine inventory/cache scopes](combat-performance-results/context-fine-scopes.json).
- [Final collector coverage and flush timings](combat-performance-results/context-validation-situations-summary.json), [passing validation](combat-performance-results/context-validation-summary.json), and [flush distribution](combat-performance-results/context-validation-flush.json).
- [Source/regression verification](combat-performance-results/context-verification.json), [long recorder session](combat-performance-results/context-session.json), [validation recorder session](combat-performance-results/context-validation-session.json), and [embedded environment](combat-performance-results/context-embedded-metadata.json).
- [Context hooks](../tests/combat/context-scopes.sqf) and [situation analyzer](../tests/combat/analyze-situations.py).

The long trace is Tracy 0.12.4, Zstd, four streams, **18,010,485 bytes**, **2,946,838 zones**, approximately **319.3 seconds**; timer resolution is 4 ns. Both captures saved and compressed successfully. Embedded environment remains Windows 10.0.19045, x64, i7-10700F, 16 logical CPUs, and 32,689 MB RAM. Raw traces and event exports remain outside the repository in the recorder capture directory.

```powershell
& tests/combat/performance.ps1 -ContextScopes -CombatOnly -IncludeAmmoPressure -GroupCounts 20,80 -Seconds 30 -Trials 2 -StartupDelaySeconds 40 -PostDelaySeconds 20 -ExtraArguments <profiler/dependency arguments>
# Connect the matching recorder before the startup delay expires.
C:\Python39\python.exe tests/combat/analyze-performance.py <rpt> --output docs/combat-performance-results --label context-profiled
C:\Python39\python.exe tests/combat/analyze-operations.py <trace> --output docs/combat-performance-results --label context-operations --benchmark-summary docs/combat-performance-results/context-profiled-summary.json
C:\Python39\python.exe tests/combat/analyze-situations.py docs/combat-performance-results/context-operations-summary.json --output docs/combat-performance-results
# Use explicit --diagnostic on the first two analyzers only for completed attribution runs with failed validity.
# Only older filtered captures require --allow-partial-context on the situation analyzer.
```

## Remaining operation timings (current implementation)

Operation scopes are installed **only in the isolated benchmark**; production source hashes remain unchanged. Stock eight-unit BLU_F / OPF_F squads were tested at 200 m with 20, 40, and 80 groups. Each size has one 20-second normal-combat window and one 20-second ammunition-pressure window, after two seconds of warmup. All groups remain virtual; damage, casualties, ammunition use, and retries remain enabled.

All **33/33 benchmark validity checks pass**, with **3,335 measured frames** at approximately 28 Hz. Every engagement stays within one second of real-time progress. Forced transfers completed: 20 / 39 / 78; forced surviving recipients still needing ammo at the boundary: 0 / 0 / 1. Instrumented combat passes **71/71 regression checks** and reproduces all 20 previous seeded outcomes exactly (mean duration 170.45 seconds).

Values below are **milliseconds per invocation**, shown as **mean / p99 / maximum**. Inclusive parents and helpers contain child scopes and must not be summed. One exchange handles both opposing groups. A needs scan covers one group; pending-request servicing handles its current requests. A donor slice inspects up to two donors plus any final winner revalidation, rather than completing the entire search.

### Normal combat

| Operation | 20 groups | 40 groups | 80 groups |
| --- | ---: | ---: | ---: |
| Complete exchange (parent) | 0.461 / 1.839 / 2.415 | 0.428 / 1.327 / 1.462 | 0.449 / 1.530 / 1.969 |
| Shot preparation / ammunition consumption | 0.422 / 1.743 / 2.149 | 0.394 / 1.236 / 1.410 | 0.411 / 1.409 / 1.897 |
| Group ammunition-needs scan | 0.312 / 0.558 / 5.824 | 0.280 / 0.382 / 0.458 | 0.289 / 0.471 / 0.612 |
| Apply all hits | 0.015 / 0.154 / 0.238 | 0.012 / 0.129 / 0.209 | 0.014 / 0.142 / 0.231 |
| Remove casualties | 0.011 / 0.032 / 0.092 | 0.010 / 0.033 / 0.038 | 0.011 / 0.036 / 0.077 |

### Ammunition pressure

| Operation | 20 groups | 40 groups | 80 groups |
| --- | ---: | ---: | ---: |
| Complete exchange (parent) | 0.464 / 1.504 / 1.635 | 0.451 / 1.418 / 2.632 | 0.439 / 1.419 / 2.150 |
| Shot preparation / ammunition consumption | 0.424 / 1.395 / 1.522 | 0.413 / 1.269 / 2.321 | 0.403 / 1.272 / 2.002 |
| Group ammunition-needs scan | 0.288 / 0.475 / 0.627 | 0.283 / 0.454 / 0.649 | 0.281 / 0.445 / 0.611 |
| Donor search slice | 0.756 / 1.005 / 1.203 | 0.758 / 1.168 / 1.190 | 0.737 / 1.186 / 1.517 |
| Service group pending requests | 0.259 / 0.632 / 0.934 | 0.235 / 0.618 / 0.657 | 0.253 / 0.679 / 0.865 |
| Apply all hits | 0.015 / 0.142 / 0.177 | 0.014 / 0.134 / 0.267 | 0.013 / 0.130 / 0.214 |
| Remove casualties | 0.012 / 0.039 / 0.072 | 0.011 / 0.037 / 0.044 | 0.011 / 0.036 / 0.068 |

### Helpers at 80 groups

| Operation | Normal: mean / p99 / max | Pressure: mean / p99 / max |
| --- | ---: | ---: |
| One shooter visit | 0.025 / 0.119 / 0.259 | 0.024 / 0.109 / 0.251 |
| Weapon / magazine selection | 0.029 / 0.057 / 0.184 | 0.029 / 0.052 / 0.186 |
| Shot accuracy | 0.017 / 0.034 / 0.163 | 0.016 / 0.029 / 0.158 |
| One unit ammunition-needs check | 0.031 / 0.055 / 0.218 | 0.032 / 0.073 / 0.179 |
| One donor inventory / reserves | - | 0.268 / 0.466 / 0.629 |
| Winner revalidation | - | 0.411 / 0.521 / 0.532 |
| Inventory snapshot | - | 0.071 / 0.118 / 0.137 |
| Build surplus magazines | - | 0.178 / 0.307 / 0.420 |
| Magazine transfer | - | 0.019 / 0.036 / 0.037 |

### Slowest frames

These averages cover the **slowest 1% of full IVCS frames** (six frames in each scenario), rather than the p99 of individual calls. The combat-operation rows are disjoint and restricted to the combat frame scope. Any sharing work during ordinary entity updates belongs to the entity row.

| Component | Normal, 80 groups | Pressure, 80 groups |
| --- | ---: | ---: |
| Shot preparation | 3.377 ms | 1.643 ms |
| Ammunition-needs scans | 1.054 ms | 0.818 ms |
| Donor search slices | 0.000 ms | 2.707 ms |
| Pending requests | 0.000 ms | 0.093 ms |
| Damage application | 0.159 ms | 0.051 ms |
| Casualty cleanup | 0.057 ms | 0.022 ms |
| Other combat work / scope overhead | 0.803 ms | 0.573 ms |
| Ordinary entity updates | 0.415 ms | 0.428 ms |
| Native ammunition queue | 0.014 ms | 0.013 ms |
| Spawner | 0.030 ms | 0.030 ms |
| Remaining frame / scope overhead | 0.051 ms | 0.042 ms |
| Full IVCS total | 5.959 ms | 6.421 ms |

Normal tail frames are dominated by shot preparation (**57%**), followed by group needs scans (**18%**). Under simultaneous shortages, donor slices dominate (**42%**), followed by shots (**26%**) and needs scans (**13%**). Several slices, including initial inline slices, can accumulate in one frame even though each search resumes. All six pressure-80 tail frames occur within the first 5.6 seconds. Normal-80 tails are distributed across the window.

**Priorities supported by this capture:** subdivide shot preparation for normal-combat peaks; reduce or subdivide donor inventory/reserve work and initial inline slices for shortage peaks; then spread or subdivide group-wide needs scans. Damage application and casualty removal are much smaller costs in these scenarios. This ranking does not predict the resulting p99 after a scheduler change.

One normal-20 needs scan took **5.824 ms**, including a **5.205 ms** single-unit needs check at 14.493 seconds. Needs-scan maxima in the other five scenarios were 0.458-0.649 ms. The outlier is retained; one trace cannot establish whether script work, profiling, or OS scheduling caused it. Normal-20 also had the largest captured full frame, 10.710 ms.

### Capture and measurement limits

The verified trace is **7,412,822 bytes**, Tracy **0.12.4**, Zstd, four streams, with **1,259,888 zones** and an approximately **187.2-second** recorded span. The recorder reports **4 ns** timer resolution. Embedded metadata identifies arma3server_x64, Windows 10.0.19045, x64, an i7-10700F, 16 logical CPUs, and 32,689 MB RAM. All six complete BEGIN/END windows and every phase frame count match the passing RPT. Startup, warmup, logging, teardown, and post-run delay are excluded from phase timings.

This capture loads Arma Script Profiler, CBA, and Intercept and adds operation/function scopes. It supplies attribution, and its full-loop results **do not replace the unprofiled baseline below**. Profiling adds overhead and can change the soft scheduler's admission decisions. These short virtual-only windows do not measure live collection, AI, rendering, or a complete mission.

| Scenario | Groups | Full IVCS mean | Full IVCS p99 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| combat | 20 | 1.487 ms | 5.380 ms | 10.710 ms |
| combat | 40 | 1.959 ms | 5.093 ms | 6.292 ms |
| combat | 80 | 3.263 ms | 5.392 ms | 6.388 ms |
| ammo-pressure | 20 | 1.639 ms | 5.595 ms | 7.105 ms |
| ammo-pressure | 40 | 2.353 ms | 5.862 ms | 8.756 ms |
| ammo-pressure | 80 | 3.666 ms | 5.922 ms | 7.347 ms |

The hotspot export contains inclusive and self totals. Self time excludes all child zones, including automatic SQF-function scopes, so named-scope self totals alone do not account for every helper's work. The phase summary retains invocation counts, totals, mean, p50/p90/p95/p99, maxima, counts above 1/5/10 ms, per-frame contributions, and the worst frames. Raw trace and event CSVs stay beside the recorder output outside the repository.

The first attempted run is excluded: instrumentation blocks were initially code literals rather than executed calls, and six combat-activity checks failed. Corrected instrumentation was validated before the accepted rerun; rejected RPT/trace locations remain in the verification manifest.

- [Per-operation distributions and frame attribution](combat-performance-results/operation-timings-summary.json).
- [Passing benchmark summary](combat-performance-results/operation-profiled-summary.json) and profiled frame samples (raw frame samples retired).
- [Inclusive/self hotspots](combat-performance-results/operation-hotspots.json), [recorder and save verification](combat-performance-results/operation-session.json), [embedded metadata](combat-performance-results/operation-embedded-metadata.json), and [source/calibration verification](combat-performance-results/operation-verification.json).
- [Benchmark-only scopes](../tests/combat/operation-scopes.sqf) and [phase analyzer](../tests/combat/analyze-operations.py).

```powershell
& tests/combat/performance.ps1 -OperationScopes -CombatOnly -IncludeAmmoPressure -Seconds 20 -Trials 1 -StartupDelaySeconds 40 -PostDelaySeconds 20 -ExtraArguments <profiler/dependency arguments>
# Connect the matching bundled Tracy recorder before the startup delay expires.
C:\Python39\python.exe tests/combat/analyze-performance.py <rpt> --output docs/combat-performance-results --label operation-profiled
C:\Python39\python.exe tests/combat/analyze-operations.py <capture.tracy> --output docs/combat-performance-results --benchmark-summary docs/combat-performance-results/operation-profiled-summary.json
```

## Shot preprocessing and resumable sharing (current implementation)

Both changes are implemented. Shot preprocessing reuses exact range-dependent calculations and indexed hitpoint layouts. Expensive donor discovery now resumes across frames for virtual and live groups. Frame-queued searches share the existing **3 ms soft combat deadline**, alternate priority with engagements, and receive a **1 ms soft search allowance** with **two donor inspections per slice** plus atomic winner revalidation.

Compared with the first optimization below, the clearest p99 improvement is in simultaneous ammunition demand at 80 groups. Normal combat p99 remains near 5 ms; these changes do not establish a further normal-combat p99 reduction.

### Matched normal fighting

The same setup, two 20-second windows, warmup, reversed order, stock squads, and unprofiled dedicated server were used. All times measure the full IVCS loop per frame.

| Groups | Mean before / after | Combat mean before / after | p99 before / after | Maximum after |
| ---: | ---: | ---: | ---: | ---: |
| 20 | 0.95 / 0.98 ms | 0.65 / 0.57 ms | 4.97 / 5.00 ms | 5.98 ms |
| 40 | 1.50 / 1.42 ms | 1.17 / 1.02 ms | 5.00 / 5.00 ms | 5.00 ms |
| 80 | 2.48 / 2.32 ms | 2.24 / 2.03 ms | 5.00 / 5.00 ms | 6.01 ms |

The final run retains 7,682 frames and passes **62/62 validity checks**. All six combat windows keep every engagement within one second of real-time progress. At 80 groups, the full-loop mean falls about 6%, while the combat component falls about 9%. Sub-millisecond differences at smaller loads should not be overinterpreted.

Idle means after the change are 0.79 / 0.94 / 1.25 ms for 20 / 40 / 80 groups, versus 0.72 / 0.86 / 1.10 ms previously. The new job machinery has some overhead; the benefit is concentrated in firing and expensive sharing work rather than a demonstrated idle speedup.

### Simultaneous ammunition demand

One forced rifle shortage per group; one 10-second window per size. Casualties, cancellations, and retry cooldowns remain enabled.

| Groups | Mean before / after | p99 before / after | Maximum before / after | Transfers | Forced recipients still needing ammo |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | 1.31 / 1.20 ms | 5.00 / 5.00 ms | 5.00 / 5.00 ms | 20 | 0 |
| 40 | 2.23 / 1.87 ms | 5.22 / 5.00 ms | 6.00 / 6.00 ms | 38 | 1 |
| 80 | 4.00 / 3.29 ms | 7.00 / 6.00 ms | 8.00 / 6.00 ms | 77 | 2 |

The final stress run retains 829 frames and passes **18/18 validity checks**. Combat stays within one second of wall time. At least 90% of the forced transfers complete, and no more than 10% of the original forced cohort remains unsupplied. New or retrying searches may still be active at the window boundary; their counts and the original cohort's status are retained separately. This finite window does not claim every surviving recipient has completed collection. The 80-group full-loop mean falls about 18%, and p99 falls from roughly 7 to 6 ms.

The original aggregate idle-search completion check was too broad. It first rejected a run with a remaining search at the boundary, and a stricter all-survivors check then rejected ordinary retries despite 38 / 78 completed transfers. The final check explicitly tracks the forced recipients and applies the stated 90% target, while retaining real-time progress and transfer-count requirements. The rejected captures remain in their printed temporary artifact directories; they are not accepted timing summaries.

### Changes and review findings

- Cached per-engagement factors include exact impact speed effects on accuracy and damage. Range or accuracyScale edits invalidate them. Hitpoint layouts cache indices and supported target order; damage and equipment remain current. Cumulative region weights refresh on settings edits. No range bucketing or physics approximation was added.
- Donor jobs retain recipient/weapon/donor cursors, not authoritative inventory snapshots. Each winner is checked again before reservation; collection checks reserves again before transfer. A stale winner restarts discovery for that weapon so another donor can be found.
- Virtual waiting periods inspect recipient need and current token ownership without rebuilding donor reserves. Arrival and transfer perform the expensive validation. Existing request processing snapshots only involved units and invalidates their cached snapshots after inventory edits.
- The initial separate search allowance stacked onto combat costs. Search continuation now shares the combat deadline with alternating priority; native proximity/reload checks retain their separate bounded queue.
- Review removed redundant per-unit adapter calls for virtual eligibility. A native reload failure led to preserving reported reload progress and ending the collection action before delivery can trigger automatic reload. Subsequent actual AI collection/reload reruns pass.

A separate shot-only run before resumable sharing passes 30 checks and records about 9% lower mean full-loop cost at 80 groups, with normal p99 still around 5 ms. It is retained to distinguish that stage from the completed implementation.

### Budget choice and verification

A **2 ms** shared-budget experiment was rejected. At 80 groups under ammo pressure, engagements advanced only 8.5-9 seconds during a 10.032-second window and completed 55 transfers. Lower measured frame costs would therefore have hidden delayed combat and sharing. The default remains **3 ms**. This is a soft deadline checked between atomic work items, not a hard maximum for the entire mission.

**285 regression checks pass:** shot preprocessing 40, resumable sharing 21, scheduling 12, combat 71, live/virtual sharing 45, and virtualization 96. All 20 seeded calibration outcomes remain identical to the prior resolver, with mean duration **170.45 seconds**. Source hashes, retained RPT locations, and verification scope are recorded below. All modified SQF files use CRLF.

Production frame calls defer searches. Direct batch combat updates drain the same search algorithm synchronously to preserve synthetic-clock coarse/fine equivalence. Discovery latency precedes reservation; approach, collection, expiry, and reload timing remain based on their actual start/delivery timestamps. Lifecycle changes cancel jobs and reservations.

- [Final normal summary](combat-performance-results/shot-resumable-summary.json) and every normal frame (raw frame samples retired).
- [Final pressure summary](combat-performance-results/shot-resumable-pressure-summary.json) and every pressure frame (raw frame samples retired).
- [Independent shot-only summary](combat-performance-results/shot-preprocessing-summary.json) and frames (raw frame samples retired).
- [Regression evidence and source hashes](combat-performance-results/shot-resumable-verification.json), [shot regression](../tests/combat/shot-preprocessing.sqf), and [resumable-sharing regression](../tests/combat/resumable-sharing.sqf).

## First optimization and measured results

Combat now spreads unfinished work across frames with a **3 ms soft combat budget**, at most eight engagement visits per frame, and one complete exchange per visit. Elapsed time remains queued for later catchup. Class preprocessing and cheaper ammunition scans reduce total work; the budget reduces its concentration in individual frames.

The matched rerun uses the same machine, stock squads, 200 m separation, warmup, two 20-second windows, reversed scenario order, and no profiler mods as the baseline below. Values measure the **full IVCS loop per server frame**, not only combat.

| Groups | Mean before / after | p99 before / after | Maximum before / after | Mean reduction |
| ---: | ---: | ---: | ---: | ---: |
| 20 | 2.27 / 0.95 ms | 14.70 / 4.97 ms | 23.01 / 6.00 ms | 58% |
| 40 | 2.99 / 1.50 ms | 20.00 / 5.00 ms | 29.00 / 6.00 ms | 50% |
| 80 | 4.44 / 2.48 ms | 20.00 / 5.00 ms | 24.99 / 6.00 ms | 44% |

All six combat windows kept every engagement within one second of real-time progress. Across approximately 20-second windows, each engagement advanced 19.5-20.5 combat seconds. The rerun retained 7,768 frames and passed **62/62 validity checks**. None of its combat frames exceeded 16.67 ms. This verifies that lower costs did not come from slowing the simulation.

### Simultaneous ammunition demand

One emptied rifle recipient per group after warmup; one 10-second window per group count, matching the earlier stress test.

| Groups | Mean before / after | p99 before / after | Maximum before / after | Transfers after |
| ---: | ---: | ---: | ---: | ---: |
| 20 | 2.79 / 1.31 ms | 24.19 / 5.00 ms | 56.00 / 5.00 ms | 20 |
| 40 | 3.87 / 2.23 ms | 29.38 / 5.22 ms | 63.00 / 6.00 ms | 38 |
| 80 | 6.16 / 4.00 ms | 54.00 / 7.00 ms | 63.00 / 8.00 ms | 77 |

The stress rerun passed **15/15 validity checks**, including real-time progress at each size, with 840 frames. The 80-group case remains relatively busy, averaging about 4 ms for the complete loop, but its observed peak is about 8 ms rather than 63 ms.

### What preprocessing changed

- Weapon classification and primary-muzzle compatibility are cached once per class as an immutable profile, including a magazine-membership map. Profiles are warmed at virtual unit creation; weapons added later populate them lazily.
- Supplied virtual units inspect their current rounds and weapons without allocating full inventory snapshots. Full snapshots are built only for a needy group or pending request.
- Each donor reserve list is computed once per sharing scan. A transfer refreshes only its recipient and donor, invalidating those reserve lists.
- Engagement polls without a due exchange retain elapsed time and skip infantry/terrain rebuilding. Actual exchanges still validate eligibility and visibility.

Magazine quantities, weapon lists, damage, positions, visibility, and live inventories remain mutable. They are not cached as class data. Native sharing reads actual inventories; loaded magazines and one compatible reserve remain protected. Preprocessing adds per-class setup/memory cost, outside these steady-state timing windows. Existing combat weapon/ammunition configuration caches already avoid repeated configuration work, so the new preprocessing targets sharing metadata rather than duplicating those caches.

A separate short run disabled the time budget (`-CombatOnly -CombatBudgetMs 0`, one 10-second window per size). This checks the combined work-reduction changes independently of the time cutoff; it is not an isolated cache-only microbenchmark.

| Groups | Mean with budget disabled | p99 with budget disabled | Maximum with budget disabled |
| ---: | ---: | ---: | ---: |
| 20 | 0.93 ms | 15.00 ms | 15.00 ms |
| 40 | 1.44 ms | 15.00 ms | 15.00 ms |
| 80 | 2.48 ms | 15.23 ms | 17.00 ms |

All three unbudgeted windows also kept up with real time (15/15 checks, 831 frames). Means are close to the budgeted run, but periodic bursts still reach 15-17 ms. Reducing work and distributing it across frames both contribute to the improvement. The idle mean also fell to 0.72 / 0.86 / 1.10 ms for 20 / 40 / 80 groups, consistent with avoiding unnecessary inventory construction outside engagements.

### Limits, correctness, and reproduction

The 3 ms setting is a soft limit checked between engagement visits. Both sides finish selecting shots and applying casualties before yielding, so one exchange may overshoot it. Entity updates, spawning, live AI, rendering, and other mission scripts are outside the combat budget. These short dedicated-server results are measured improvements, not a guaranteed client frame bound or proof of unlimited capacity.

The review checked inventory freshness, reserve overlap, transfer invalidation, lifecycle transitions, fair queue rotation, and retained catchup time. Regression suites pass: scheduling **12/12**, combat **71/71**, sharing **45/45**, virtualization **96/96**. The 20-seed combat calibration remains exactly **170.45 seconds mean**. Sharing passed when rerun alone after one native reload check failed during concurrent test execution; native reload phase/state diagnostics remain in the suite. All changed SQF files use CRLF.

```powershell
& tests/combat/performance.ps1 -Seconds 20 -Trials 2 -ExtraArguments "-noPause"
& tests/combat/performance.ps1 -AmmoPressure -Seconds 10 -Trials 1 -ExtraArguments "-noPause"
& tests/combat/performance.ps1 -CombatOnly -CombatBudgetMs 0 -Seconds 10 -Trials 1 -ExtraArguments "-noPause"
```

Run engine benchmarks individually. The analyzer retains each engagement window's minimum/maximum combat progress and rejects failed or lagging runs. Older baseline artifacts predate this explicit progress metric.

- [Optimized summary](combat-performance-results/optimized-summary.json) and every optimized frame (raw frame samples retired).
- [Optimized pressure summary](combat-performance-results/optimized-pressure-summary.json) and every pressure frame (raw frame samples retired).
- [Budget-disabled summary](combat-performance-results/optimized-no-budget-summary.json) and every budget-disabled frame (raw frame samples retired).
- [Scheduling regression](../tests/combat/scheduling.sqf) and [updated design/settings](virtual-combat-design.md).

## Original baseline and profiler investigation

With 20 groups (10 simultaneous engagements), normal virtual combat costs about **2.27 ms per frame for the full virtualization loop**, including **1.63 ms inside the combat scheduler**. The average is manageable, but its **23 ms peak** already exceeds a complete 60 FPS frame budget. Simultaneous ammunition requests raise the observed peak to **56 ms**. Improving burst scheduling and ammunition scans should precede assuming larger battles will hold a smooth client frame rate.

## Normal fighting

These are the runs **without Arma Script Profiler**. All values are milliseconds per real server frame. Full IVCS includes combat, the pending native-ammo queue, ordinary entity updates, and the spawn/despawn FSM. Combat is a child of that total; do not add the two columns together.

| Groups | Engagements | Nominal units | Full IVCS mean | Combat mean | Full IVCS p95 | Full IVCS p99 | Full IVCS max |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | 10 | 160 | 2.27 | 1.63 | 5.00 | 14.70 | 23.01 |
| 40 | 20 | 320 | 2.99 | 2.40 | 12.00 | 20.00 | 29.00 |
| 80 | 40 | 640 | 4.44 | 3.90 | 16.01 | 20.00 | 24.99 |

p99 means 99% of measured frames cost no more than that value. A 60 FPS frame has 16.67 ms available for all work; a 30 FPS frame has 33.33 ms. These measurements cover server-side script work. Client rendering and the rest of a populated mission need their own budget.

| Groups | Idle IVCS mean | Additional mean versus idle | Frames over 16.67 ms | Combat-step frames / sampled frames |
| ---: | ---: | ---: | ---: | ---: |
| 20 | 1.51 | 0.76 | 11 (1.0%) | 161 / 1131 |
| 40 | 1.89 | 1.10 | 21 (1.9%) | 240 / 1133 |
| 80 | 2.73 | 1.71 | 56 (4.9%) | 401 / 1137 |

The idle comparison suppresses contact acquisition but retains the same inventories, positions, and routine ammunition scans. Combat moves those scans into engagement updates, so combat-scheduler time is not wholly additional CPU cost. The empty controller averages 0.05 ms per frame.

Costs cluster when the half-second combat ticks, firing cadence, and ammunition scan deadlines coincide. The scheduler processes up to eight engagements per frame; the worst normal frames in all three loads contained eight combat steps. The group-count limit bounds engagement count, rather than milliseconds of work.

## Simultaneous ammunition requests

This separate controlled stress run empties one unit’s compatible rifle ammunition in every group immediately after warmup. Other members retain their standard inventories. Donor selection, delayed collection, transfer, and reload therefore occur inside the measured window. It is a single 10-second window per size, so these are observed stress results rather than a long-run average. Casualties and invalidated requests remain possible.

| Groups | Full IVCS mean | Combat mean | Full IVCS p99 | Full IVCS max | Completed magazine transfers |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | 2.79 | 2.17 | 24.19 | 56.00 | 20 |
| 40 | 3.87 | 3.28 | 29.38 | 63.00 | 38 |
| 80 | 6.16 | 5.63 | 54.00 | 63.00 | 77 |

At 20 groups, simultaneous ammunition demand produced a 56 ms frame. That makes frame spikes a concern at the intended starting scale, even though the normal average is only a few milliseconds.

## Tracy findings

The installed profiler was run separately with its CBA/Intercept dependencies. The recorder saved and compressed a nonempty **2,767,818-byte Tracy 0.12.4 capture (Zstd, four streams)**. It recorded approximately **116 seconds**, ending when the isolated benchmark server completed; the recorder’s configured maximum was 180 seconds. Embedded metadata identifies `arma3server_x64.exe`, Windows 10.0.19045, an i7-10700F, x64, 16 logical CPUs, and 32,689 MB RAM.

The capture covers the end of idle-40, the complete combat-40, idle-80, and combat-80 windows and their warmups. It does not cover the 20-group window or the ammunition-pressure run. Trace timestamps use time since profiler startup: the final timestamp is 228.205 seconds, not 228 seconds of recorded data. There are 452,375 recorded zones and 1,923 active virtualization frames.

| Zone | Calls | Inclusive total | Self total | Mean inclusive |
| --- | ---: | ---: | ---: | ---: |
| Full IVCS named frame scope | 1,923 | 6,788 ms | See child breakdown | 3.530 ms |
| Combat named frame scope | 1,923 | 4,222 ms | See child breakdown | 2.196 ms |
| Ammunition updateGroup | 12,058 | 3,244 ms | 1,247 ms | 0.269 ms |
| Ammunition snapshot | 34,276 | 1,549 ms | 1,549 ms | 0.045 ms |
| Infantry qualification | 31,850 | 481 ms | 481 ms | 0.015 ms |
| Shot accuracy | 12,102 | Includes impact-speed/profile lookups | 418 ms | See raw export |
| Terrain visibility | 9,896 | 153 ms | 153 ms | 0.015 ms |

Inclusive parents contain their children. For example, `snapshot` is nested inside `updateGroup`; their inclusive totals must not be summed. Snapshotting plus updateGroup’s own self time account for about 2,797 ms of the recorded work. This work happens even without a completed transfer: the normal measured windows recorded zero transfers.

Targeted full-capture frame distributions (including idle and warmup) were:

| Scope | Mean | p50 | p90 | p95 | p99 | Maximum | >1 ms | >5 ms | >10 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Full IVCS | 3.530 | 1.233 | 11.096 | 12.957 | 22.129 | 43.828 | 1,125 | 396 | 213 |
| Combat | 2.196 | 0.528 | 10.186 | 12.568 | 21.782 | 43.239 | 574 | 219 | 195 |

Using only complete measured phase boundaries, combat-40 had a 3.017 ms full-IVCS mean and 21.981 ms p99; combat-80 had 4.632 ms mean and 22.723 ms p99. The largest captured combat-80 frame, 43.828 ms, contained eight steps taking 6.566 ms and ammunition updates taking 34.468 ms. In another 25.251 ms combat-80 frame, steps took 13.785 ms and ammunition updates took 10.103 ms. Both firing work and ammo scans contribute to the periodic bursts.

## Optimization targets identified from the baseline

1. **Ammunition scans and snapshots:** reduce rebuilding full inventories when no weapon needs ammunition; cache weapon classification/compatibility metadata while keeping magazine counts mutable. This targets the largest self-time costs.
2. **Spread scan deadlines and expensive work:** stagger ammunition checks across groups and use a frame-time budget for engagement work. Eight full engagement updates can currently put 16 group scans in the same frame; simultaneous requests amplify that cost. Preserve combat-clock and reload/collection timing when spreading work.
3. **Avoid redundant validation on frames with no due tick:** profile a cheap next-due path for engagement updates and track infantry/transport eligibility changes instead of repeatedly scanning every unit assignment. Preserve lifecycle checks when units or groups are removed.

These were the targets identified before implementation. The measured results and implemented behavior are described at the beginning of this report.

## Measurement setup and limits

- Local hidden dedicated server; Altis; Arma 3 2.22 build 154103, Windows x64 profiling executable. The timing runs load no profiler mods. A retail executable or another CPU can differ.
- CPU: Intel Core i7-10700F, eight cores / 16 logical processors; approximately 32 GB RAM; Windows 10 Home 10.0.19045. No Arma game client was running during measurement.
- Stock `BUS_InfSquad` and `OIA_InfSquad`, eight units each. “20 groups” means ten opposing pairs, not twenty pairs.
- Each pair uses the clear 200 m reference positions `[14500,16400,0]` and `[14700,16400,0]`. Virtual pairs reuse those positions; there are no native collision/AI costs. Contacts are established before the timed window.
- All groups remain inactive/virtual throughout. Debug markers are off. There are no movement tasks, path generation, players/UAV spawn sources, or live ammunition collection. The production combat, sharing, entity-update, and spawner functions run through a real EachFrame handler.
- Normal runs: two 20-second windows per scenario, two seconds of warmup, reversed scenario order on the second trial. Full frames retained: 7,901 across empty, idle, and combat. All 56 validity checks pass.
- Normal fighting uses real damage, ammunition consumption, and casualties. Combat windows started with 159–160, 319, and 637–639 units, and ended with 150–154, 299–306, and 604–608 respectively. These are early-fight measurements; they do not hold rosters artificially immortal.
- The pressure run retains 843 frames and passes 12 validity checks; the separate profiler run passes 28. Actual pressure transfers were 20, 38, and 77.
- Observed dedicated-server cadence is about 28 frames/second. This measures CPU cost at that cadence, not a 60 Hz rendered-client benchmark. Combat’s wall-clock timing is independent of accTime; measurements use 1x. No separate 5x benchmark was performed.
- `diag_tickTime` has approximately millisecond timer granularity on Windows. Normal-run averages aggregate many frames; fine differences below a millisecond and individual 0/1 ms samples should not be overinterpreted. Tracy supplies nanosecond-resolution hotspot timings (recorder reported 3 ns timer resolution).
- Startup, entity creation, warmup, sample logging, and teardown are excluded from the timed windows. The timing wrappers add a small overhead; the empty-controller result provides a floor.

## Reproduce

```powershell
& tests/combat/performance.ps1 -Seconds 20 -Trials 2 -GroupCounts 20,40,80 -ExtraArguments "-noPause"
& tests/combat/performance.ps1 -AmmoPressure -Seconds 10 -Trials 1 -GroupCounts 20,40,80 -ExtraArguments "-noPause"
C:\Python39\python.exe tests/combat/analyze-performance.py <retained-server.rpt> --output docs/combat-performance-results --label rerun
```

The runner prints the retained artifact directory. Use its `profile/*.rpt` as the analyzer input. The analyzer rejects failed/incomplete runs, truncated sample rows, and missing combat activity. SQF files use CRLF.

Profiler recording requires the installed Arma Script Profiler and Intercept/CBA dependencies; `-ProfilerMarkers` enables named scopes and phase messages. `-ExtraArguments` passes mod startup arguments to the isolated server. Allow sufficient startup/post-run delay for a recorder to connect and save. Profiler output remains separate from the primary timing results.

## Data and sources

- [Normal frame distributions](combat-performance-results/unprofiled-summary.json) and every normal frame (raw frame samples retired).
- [Ammunition-pressure distributions](combat-performance-results/ammo-pressure-summary.json) and every pressure frame (raw frame samples retired).
- [Profiled timing distributions](combat-performance-results/profiled-summary.json), [Tracy hotspots](combat-performance-results/tracy-hotspots.json), [combat frame percentiles](combat-performance-results/tracy-combat.json), [full frame percentiles](combat-performance-results/tracy-ivcs.json), and [phase-specific trace attribution](combat-performance-results/tracy-phase-summary.json).
- [Capture location and recorder session](combat-performance-results/tracy-session.json), [embedded trace metadata](combat-performance-results/tracy-embedded-metadata.json), and [measurement environment](combat-performance-results/environment.json). Raw trace and recorder logs remain in the capture-tracy skill’s captures directory rather than Git.
- [Benchmark](../tests/combat/performance.sqf), [runner](../tests/combat/performance.ps1), and [analyzer](../tests/combat/analyze-performance.py).
- [Bohemia: diag_tickTime](https://community.bohemia.net/wiki/diag_tickTime), [performance profiling](https://community.bohemia.net/wiki/Performance_Profiling), and [profiler startup parameters](https://github.com/dedmen/ArmaScriptProfiler/wiki/Command-line-parameters).
