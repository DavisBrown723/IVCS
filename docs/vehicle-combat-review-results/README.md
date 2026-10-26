# Vehicle combat review - 25 October 2026

Reviewed both infantry attacks against vehicles and land-vehicle return fire against infantry. Findings were implemented without changing frame budgets or resolution frequency.

## Correctness fixes

- **Arming distance:** both shot-selection paths reject explosive ammunition below its configured `fuseDistance`. Existing grenade-launcher safety ranges and vehicle AI mode ranges also apply. The decision reads current range even when prepared ammunition is cached.
- **Interrupted placement:** an in-progress mine/charge placement rechecks reach and ownership of its reserved magazine each tick. Leaving range, losing/replacing that record, or changing weapon cancels its progress. Restarting requires the full placement time; ammunition remains unspent until completion.
- **Secondary-muzzle firing data:** grenade-launcher attacks use their muzzle's dispersion, AI dispersion coefficients, cadence and speed settings. Primary rifle profiles retain their existing mode selection and values.
- **Autonomous native crews:** implicit UAV AI groups receive enemy knowledge during handoff. Stored crew groups and implicit crews share the same hostility-aware target selection, including allied UGVs linked to an attacking infantry group.

## Efficiency and simplification

- Splash footprints are prepared lazily and cached per engagement by exposed target count, formation spacing, magazine and impact index. Entries contain indices and small immutable damage profiles; they never retain unit references. Roster replacement, casualty-count changes and spacing changes are covered by regressions.
- Squared distances replace repeated square roots. `(radiusSquared / distanceSquared)^2` retains the previous fourth-power falloff. Full ammunition hash maps are no longer copied for every splash victim. The thin blast profiles are used only with explicit prepared damage factors.
- Machine-gun fire does not allocate splash geometry or a splash cache.
- `canFightVehicle.sqf` replaces the duplicated engagement-start and ammunition-recovery scans. Inventory ownership, remaining rounds, mounting, arming distance and return-fire eligibility use one policy.
- Transition, empty-inventory and configuration-default guards remain where they enforce actual invariants; this review adds no speculative assertion layer.

## Verification

Run focused review tests:

```powershell
./tests/combat/vehicle-review.ps1 -Port 2522 -TimeoutSeconds 300
```

The runner injects the two retained pre-review resolver functions as code literals. The focused suite reproduces the former infantry arming-distance error, checks interrupted placement and both autonomous handoff directions, distinguishes GL dispersion from rifle dispersion, and compares real anatomical damage/ammunition/random state against the old HE resolver across 32 seeds. Numeric damage comparisons tolerate at most 0.00001 engine arithmetic roundoff.

The HE microbenchmark runs four paired trials with reversed order: 20 warmup calls followed by 300 measured calls per implementation per trial. The workload uses a stock GMG, eight exposed infantry, identical seeds and real damage calculations. Each call resets the fixture's damage, magazines and counters; timings include that identical reset work. Batches run unscheduled on the isolated test server, avoiding scheduled-script suspension inside each timed batch. The coarse `diag_tickTime` clock measures batches rather than individual submillisecond calls.

This microbenchmark measures resolver throughput. It does not measure gameplay frame p99, native AI, cold profile creation or spawn cost. The prior [20-engagement frame measurements](../vehicle-return-fire-results/README.md) are historical results from the earlier implementation and were not remeasured in this review.

`verification.json` records the latest passing engine run per suite, RPT hashes, labels, packaged-source availability and differences from final production hashes. Earlier damage/integration runs precede the final muzzle metadata or native-knowledge refactor; the focused review, expansion, return-fire and infantry regressions were rerun after relevant changes. Unavailable temporary copies are unknown rather than mismatches. All SQF writes retain CRLF endings.

One test-package copy ran out of disk space. Generated PBO files and copied map-index outputs were deleted only inside this review's temporary mission directories, retaining logs and combat sources; `package-cleanup.json` and `copied-map-cleanup.json` record those paths. Tests then resumed. The regression harness itself is unchanged.

## Results

**481 checks passed across six engine suites**, including 23 focused review checks, 44 return-fire checks, 58 vehicle integration checks, 57 expansion checks, 228 vehicle calibration checks and 71 infantry checks. Final infantry calibration remains **178.1 simulation seconds** on average across 20 seeds.

The paired HE workload averaged **0.512 ms before and 0.455 ms after per call including fixture reset**, a **11.2% reduction** across 1,200 measured calls per implementation. All 32 seed comparisons preserved ammunition, hit/casualty-related damage outputs and random state within the stated numeric tolerance. Exact batch rows are retained in [he-batch-timings.json](he-batch-timings.json).
