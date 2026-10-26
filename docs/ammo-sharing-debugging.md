# Ammo sharing after combat handoff - 14 October 2026

The reported symptoms were repeated native collection attempts, units remaining unable to fire, and several empty magazines on bodies after a virtual fight. Testing used 1x simulation speed, matching the reported session.

## Findings and fixes

1. **Virtual firing retained spent magazines, and spawning materialized them.** The original rifleman probe restored ten zero-round magazines; a BLUFOR team leader restored six. An over-capacity stress case restored eighteen empty magazines, made two collection attempts, transferred no ammunition and remained dry. Virtual firing now deletes a magazine when its last round is spent, keeping its reload delay. Spawn skips all nonpositive weapon/cargo magazine records, including legacy data and dry magazines captured from native weapons. Positive partial magazines and support ammunition remain intact.
2. **Native discovery ignored receiving capacity.** Transfer already rejected an item that could not fit, but movement and collection happened before that check. A full unit could repeatedly approach and animate without receiving anything. Discovery now filters by recipient capacity, rechecks the winner before committing a request, and cancels an existing request if capacity is lost before collection. The final transfer check remains necessary because inventory can change during approach. A unit can request ammunition again after space becomes available.
3. **A delivered magazine can disappear before Arma reports a reload phase.** A separate OPFOR team-leader reproduction, after the empty-magazine fixes, still requested the same Katiba rifle magazine twice. The first request entered `reloading` at 3.199 seconds; at 3.644 seconds another request began while `weaponState` still reported zero rounds and reload phase zero. The old helper interpreted the missing inventory magazine as failure, released ownership and allowed immediate rediscovery. It now holds the delivered request across this gap until loaded rounds appear or the existing reload timeout expires. Weapon removal, death and normal lifecycle cancellation still release requests.

These were separate reproductions: the reload-gap case contained no empty magazines, so deleting empty magazines alone did not fix every repeated pickup. The current game RPT also contains repeated inventory-storage warnings for demo units, including OPFOR autoriflemen. Those warnings support inspecting the inventory path but do not identify the cause of an individual request.

## Correctness and efficiency review

Prepared shots return their freshly selected magazine source/index for immediate deletion on exhaustion. They are not stored in the immutable class/factor cache. This avoids another inventory scan when a magazine empties. Subsequent selections read the current array again, so deletion cannot leave a cached index behind.

The independent timestamp reference still retains zero balances as a ledger. Its comparison normalizes usable magazines, while focused tests separately verify physical removal, preservation of the next magazine's rounds and the full reload delay. This avoids duplicating the cleanup implementation in the reference model.

Magazine compatibility, donor reserve policy, one-metre collection distance, simulation clock, damage, shot cadence and work budgets are unchanged. Native capacity checks short-circuit out of virtual searches. All changed SQF uses CRLF.

## Verification

The focused regression covers riflemen, grenadiers and automatic riflemen from BLU_F and OPF_F, a forty-empty-record legacy stress case, a paired mid-combat spawn, full receiving inventory, space becoming available, and capacity disappearing after reservation. It checks exact round conservation and one collection per dry primary weapon. Native reloads run through the production sharing updater; targeting and movement are disabled to isolate inventory behavior, then a real `Fired` event verifies weapon readiness after `forceWeaponFire`.

Run it with:

```powershell
powershell -File tests/tasks/run.ps1 -TestScript tests/combat/handoff-ammo.sqf -Port 2516 -TimeoutSeconds 180
```

Restart the mission before retesting the interactive demo so the updated functions are compiled. Existing live objects can still contain empty magazines created by the previous code.

Completed verification: **720 checks passed, zero failed** across ten selected suites, including 53 focused handoff checks, 46 sharing checks, 109 aggregation checks, 71 combat checks, 21 resumable-search checks, 59 arrival checks, 93 inventory-import checks, 96 virtualization checks, 160 prepared-shot checks and 12 scheduling checks. The 20 reference fights still average 166.15 simulation seconds. [Verification evidence and reproduction traces](ammo-sharing-debug-results/verification.json).
