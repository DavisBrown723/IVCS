# Land-vehicle return fire verification

Implementation and approximation policy are described in [the combat design](../virtual-combat-design.md#land-vehicle-return-fire--25-october-2026).

The review corrected countermeasure stations being treated as weapons, zero-flag GMG eligibility, stale gunner/inventory references, splash victims inflating projectile counters, direct impacts double-counting blast, premature casualty cleanup, and discovery of already-native infantry. Prepared firing profiles retain only fields consumed by the shot model. Bullet preference also applies when a non-bullet projectile has no blast damage.

**716 correctness checks passed across eight engine suites**, including 44 return-fire checks. Existing infantry calibration remains 178.1 simulation seconds on average across 20 seeds.

`verification.json` records engine suites, retained RPT hashes, and source comparisons. `source-hashes.json` freezes production SQF files. Missing temporary source copies are explicitly unknown. Earlier regression suites precede the final discovery, bullet-priority and GMG metadata edits; relevant return-fire, vehicle integration and virtualization checks were rerun, with exact source differences retained.

## Sustained workload

Run from the repository root with the installed CBA, Intercept Minimal Dev and Arma Script Profiler mods:

```powershell
$mods = @(
  'C:/Program Files (x86)/Steam/steamapps/workshop/content/107410/450814997',
  'C:/Program Files (x86)/Steam/steamapps/workshop/content/107410/1645973522',
  'C:/Program Files (x86)/Steam/steamapps/workshop/content/107410/1652506957'
)
$extra = @('-noPause', ('"-mod=' + ($mods -join ';') + '"'))
./tests/combat/vehicle-performance.ps1 -Seconds 12 -Trials 2 -GroupCounts 20 `
  -ReturnFireComparison -ProfilerMarkers -StartupDelaySeconds 30 `
  -PostDelaySeconds 75 -Port 2522 -TimeoutSeconds 400 -ExtraArguments $extra
```

The comparison removes only the return-fire call from the current resolver for the disabled phases. All other production functions and settings are shared. The default historical-baseline mode remains available when `-ReturnFireComparison` is omitted.

Twenty engagements means **40 groups, 20 vehicles and 200 infantry**, including the crews. Benchmark wrappers retain actors and reset lethal damage so all engagements remain active; normal damage calculations and ammunition expenditure still execute. Two trials reverse phase order, with 12 measured seconds and two warmup seconds per phase, at accTime 1. Production limits remain 3 ms combat budget, eight engagements per frame, and one-second resolution. No native objects are spawned inside the measured workload.

Results describe a short, instrumented dedicated-server workload. They do not include cold profile creation, native spawn cost, native AI, or a long gameplay session. Function inclusive times overlap; use the root frame distribution for total cost and do not add parent and child timings.

## Results: 25 October 2026

The trace covers all **eight complete measurement windows and 2,651 measured frames**. All **52 workload checks passed**: combat stayed active, all 20 forced transfers completed in each shortage phase, and progress remained within one resolution interval plus scheduling slack. Enabled phases fired 3,612 vehicle rounds in total; disabled phases fired none.

| Workload | Return fire | Mean IVCS frame | p99 IVCS frame | Maximum |
| --- | --- | ---: | ---: | ---: |
| Normal | Disabled | 1.377 ms | 4.493 ms | 4.952 ms |
| Normal | Enabled | 1.510 ms | 4.849 ms | 5.077 ms |
| Forced shortage | Disabled | 1.654 ms | 4.664 ms | 5.107 ms |
| Forced shortage | Enabled | 1.801 ms | 4.984 ms | 5.925 ms |

Percentiles pool the frame samples from both trials rather than averaging trial percentiles. Return fire increased normal p99 by 0.357 ms and shortage p99 by 0.320 ms in this sample. Mean added frame cost was 0.133 ms and 0.147 ms respectively. Gameplay changes also affect the comparison: vehicle damage and injuries can change infantry firing and sharing work.

Return-fire operations across enabled measured windows:

| Operation | Mean per call | p99 per call | Maximum |
| --- | ---: | ---: | ---: |
| `stepReturnFire` | 0.218 ms | 0.340 ms | 0.556 ms |
| `getReturnFireStations` | 0.072 ms | 0.104 ms | 0.165 ms |
| `getReturnFireShot` | 0.028 ms | 0.039 ms | 0.160 ms |

These are inclusive timings. Station discovery is nested inside return fire, and shot selection is nested inside the firing loop. They must not be added together. The next measurable return-fire optimization candidate is preparing more station eligibility metadata: live station construction averaged 0.072 ms per call. Current gunner assignments and damage still need live checks.

The capture is a **3,084,637-byte Tracy container with Zstd compression and four streams**, a recorded span of 180.1 seconds, 4 ns timer resolution, 4,524 captured frames and 454,529 zones. The tested runtime was Arma 3 2.22 build 154126, Windows x64 profiling branch, accTime 1. The bundled exporter does not expose CPU/host metadata. Its `capture_duration_ns` estimates duration from rounded aggregate percentages and is not used as the connected recording duration.

Exact pooled distributions (p50/p90/p95/p99, maximum, and counts over 1/5/10 ms), capture/RPT hashes, and the session location are in [precise-summary.json](performance/precise-summary.json). [Operation attribution](performance/land-return-fire-operations-summary.json) retains complete per-frame samples and window boundaries; [root](trace-root.json) and [vehicle](trace-vehicle.json) reports include inclusive/self-time rankings. No >10 ms frame occurred in the measured windows. Expensive work clusters in resolution frames; return-fire calls topped out at 0.556 ms while the highest full frame was 5.925 ms in a shortage window.

Production source hashes did not change during measurement. The final GMG fix subsequently changed only the uncached ammo-profile eligibility path to reuse shared metadata; the selected MG firing path is unchanged. This measurement does not quantify a GMG-only splash workload. `measurement-source-hashes.json` retains the measured version; `source-hashes.json` retains the final version. Retained packaged sources matched wherever available; 381 of the 432 copies were unavailable by verification time, recorded as unknown in [source-verification.json](performance/source-verification.json).
