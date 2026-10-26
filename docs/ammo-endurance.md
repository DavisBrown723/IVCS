# Virtual infantry ammunition endurance

Measured 2026-10-12 inside the native Arma dedicated-server test harness. The original runs left production combat and loadout import code unchanged. A five-trial follow-up now verifies the corrected backpack importer; the original results remain below for comparison.

## Sharing follow-up

A one-trial smoke check after enabling sharing and magazine-well compatibility exhausts the standard BLU_F squad at **14:32** (872 s), firing **2,884** supported rounds while preserving all eight BLU_F units. This is one seeded trial, not an average. The settings below otherwise remain unchanged. The new compatibility lookup recognizes two additional 30-round tracer magazines each for the NATO squad/team leaders and the ammo bearer's 100-round MX magazine, adding 220 usable rounds to the prior inventory. Sharing also changes who consumes those rounds.

The tables below are historical measurements before those two changes; they should not be read as current sharing-enabled endurance. Per-unit exhaustion accounting now follows current ownership and resets when a unit receives more ammunition, so it records the final depletion episode.

- [Sharing-enabled smoke results](ammo-endurance-results/sharing-smoke-results.json)

## Result

| Loadout source | Trials | Mean time until the whole BLU_F squad is empty | Range | Usable BLU_F rounds fired |
| --- | ---: | ---: | ---: | ---: |
| IVCS virtual factory before importer fix | 20 | **15:59** (958.775 s) | 15:56 to 16:02 | 2,514 |
| Ammunition captured from stock native units | 5 | **21:27** (1287.4 s) | 21:26 to 21:28.5 | 2,664 |
| IVCS virtual factory after importer fix | 5 | **21:27** (1287.4 s) | 21:26 to 21:28.5 | 2,664 |

The corrected factory reproduces the stock-ammunition endurance result. All five trials exhaust 2,664 usable rounds, preserve all eight BLU_F units without injuries, and leave three unsupported NLAW rounds.

The pre-fix factory median is 958.5 seconds and standard deviation is 1.308 seconds. The stock-ammunition comparison has median 1288.0 seconds and standard deviation 1.158 seconds.

The ammo bearer determines the whole-squad endpoint. Other members exhaust ammunition substantially earlier. Across the pre-fix factory trials, the mean individual-unit exhaustion time is 9:45; the last unit remains armed until approximately 16 minutes.

## Conditions

- Eight-unit standard NATO BLU_F Rifle Squad: CfgGroups/West/BLU_F/Infantry/BUS_InfSquad.
- Eight-unit standard CSAT OPF_F Rifle Squad: CfgGroups/East/OPF_F/Infantry/OIA_InfSquad.
- 200 m separation on unobstructed terrain at Altis positions [14500,16400,0] and [14700,16400,0].
- BLU_F fires using the production resolver and cannot take virtual damage. OPF_F retains normal firing, ammunition consumption, and damage handling.
- Immediately replace an eliminated OPF_F squad with a fresh standard squad. Preserve BLU_F ammunition; do not rearm, share ammunition, or resupply it.
- Stop on the exact exchange where no BLU_F unit has a shot available through IVCS_Combat_getShot.
- Count every supported round, including secondary handguns. Unsupported launcher ammunition remains: two NLAW rounds in pre-fix factory profiles, three in corrected factory profiles and native inventories. Explosives and spare magazines not associated with a usable weapon are outside this model's firing inventory.
- Default combat settings: 0.5-second steps, accuracyScale 1.1, cadenceScale 1, and three-second empty-magazine reload delay.

The resolver runs inside Arma with a synthetic real-time clock advanced in 0.5-second steps. These are modeled real-world combat durations, not the time spent executing the benchmark. The 20 pre-fix factory trials took approximately 306.8 seconds of test execution; the five stock-ammunition trials took 108.9 seconds, excluding server startup and native-loadout preparation. Combat timing does not multiply by accTime, so these model durations apply at both 1x and 5x.

Enemy replacement follows normal engagement finish/start behavior, including its current reset of firing delays. There is no detection or movement delay before a replacement engagement begins.

## Per-unit exhaustion

Times include the unit's eligible primary and secondary ammunition. All BLU_F units stay alive and uninjured throughout.

| Role | Pre-fix usable rounds | Pre-fix mean time | Stock / fixed usable rounds | Stock / fixed mean time |
| --- | ---: | ---: | ---: | ---: |
| Squad leader | 168 | 6:07 | 168 | 6:07 |
| Rifleman | 348 | 12:41 | 348 | 12:41 |
| Rifleman (LAT) | 228 | 8:18 | 228 | 8:18 |
| Marksman | 288 | 10:30 | 288 | 10:29 |
| Team leader | 168 | 6:07 | 168 | 6:07 |
| Autorifleman | 648 | 10:02 | 648 | 10:02 |
| Ammo bearer | 438 | 15:59 | 588 | 21:27 |
| Medic | 228 | 8:18 | 228 | 8:18 |

Pre-fix factory BLU_F starts with 2,130 primary-weapon rounds and 384 pistol rounds. Its 20 trials eliminate a mean of 24.65 OPF_F units and 2.8 complete squads before exhaustion; the last target squad can remain partially alive. Stock-ammunition trials eliminate a mean of 28.2 units and 3.2 complete squads.

## Loadout importer fix

The original [backpack cargo importer](../Common/functions/units/getBackpackCargo.sqf) read TransportMagazines/count but appended each magazine class only once, regardless of quantity. The importer now expands each item, magazine, and weapon entry by its configured count. It also reads the correct TransportItems/name field. The three flat output arrays and category flags are preserved, and inherited cargo is included.

For both factions' ammo bearers, the default backpack contains six compatible 30-round rifle magazines. The old importer added one, losing five magazines or **150 usable rounds per ammo bearer**. Native unit creation/capture confirmed the following pre-fix discrepancy; both factory inventories now contain 588 usable rounds:

| Unit | Pre-fix factory usable rounds | Native usable rounds | Previously missing usable rounds |
| --- | ---: | ---: | ---: |
| B_soldier_A_F | 438 | 588 | 150 |
| O_soldier_A_F | 438 | 588 | 150 |

NLAW/RPG backpack quantities also differed and are now corrected, but those rounds are unsupported by the current infantry resolver and do not determine this endpoint. Every other standard squad member's usable small-arms count matches in the diagnostic comparison.

The stock-ammunition comparison corrects the test input by capturing actual native unit inventories for both factions, then cloning those ammunition records into otherwise identical virtual profiles. It does not modify the production importer. The extra 150 rounds on the last surviving shooter extend group endurance by approximately 328.6 seconds (5:29).

## Reproduce

Corrected factory profiles, 20 trials (the original pre-fix run cannot be reproduced with the corrected importer):

    powershell -File tests/combat/ammo-endurance.ps1 -Trials 20 -Port 2495 -TimeoutSeconds 600

Stock native ammunition comparison, five trials:

    powershell -File tests/combat/ammo-endurance.ps1 -NativeStockAmmo -Trials 5 -Port 2497 -TimeoutSeconds 300

Native-versus-factory inventory regression:

    powershell -File tests/tasks/run.ps1 -TestScript tests/combat/ammo-loadout-check.sqf -Port 2497 -TimeoutSeconds 120

The two port-2497 commands run sequentially. All new SQF sources use CRLF. The endurance harness overrides damage handling only inside the isolated test mission to protect BLU_F, then restores the original function.

## Verification and data

The original pre-fix factory endurance run passed 83 checks and the stock-ammunition run passed 23. After the fix, the factory endurance rerun passes 23 checks across five trials. The expanded importer regression passes 58 checks: individual weapon/magazine records and ammunition totals for all 16 squad unit classes, physical cargo quantities, all category-flag combinations, and absent/unknown backpack configs. Checks confirm unchanged initial loadouts across trials, complete exhaustion, BLU_F survival without injuries, preservation of unsupported rounds, nonnegative ammunition, and clean group/engagement teardown. Engine logs contain no script errors.

- [Post-fix endurance metrics, loadouts, and log location](ammo-endurance-results/post-fix-results.json)
- [Original trial results](ammo-endurance-results/trials.csv)
- [Original per-unit trial times](ammo-endurance-results/unit-times.csv)
- [Original captured metrics, loadouts, and log locations](ammo-endurance-results/results.json)
- [Parameterized benchmark runner](../tests/combat/ammo-endurance.ps1)
- [Endurance mission script](../tests/combat/ammo-endurance.sqf)
- [Native loadout comparison script](../tests/combat/ammo-loadout-check.sqf)
