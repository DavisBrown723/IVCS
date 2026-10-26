# Virtual combat

Status: infantry combat, infantry attacks against vehicles, and land-vehicle return fire are implemented. The final land-vehicle return-fire section supersedes earlier passive-land-vehicle restrictions. Aircraft and boats remain passive in virtual combat.

## Purpose

Allow opposing infantry groups to fight while virtual, with damage and ammunition tracked per unit. When an engagement becomes spawned, native Arma combat takes over using the state accumulated in virtual combat.

The former engagement placeholders have been replaced by the virtual infantry combat module.

## Confirmed decisions

| Area | Initial behavior |
| --- | --- |
| Participants | Infantry versus infantry. |
| Duration | Approximately three simulation minutes. As of 14 October 2026, accTime scales combat alongside the other gameplay systems; see the clock decision below. |
| Combat range | Start with a maximum distance of 300 metres between group entity positions. |
| Visibility | Simple terrain visibility and distance checks. |
| Position | All units use their group's entity position for combat range calculations. |
| Hit selection | Successful hits select a body region using weighted probabilities. |
| Damage | Track damage to individual unit hitpoints using a configurable approximation based on weapon/ammunition and target protection. |
| Accuracy | Use weapon/ammunition and engagement range, plus reduced accuracy for damaged arms. Work with currently available unit data; expand later. |
| Movement | Groups in virtual combat stop moving. |
| Disengagement | Tactical disengagement is deferred. |
| Spawn handoff | When a group in combat spawns, its combat target group also spawns. Use reveal to transfer enemy information and help native combat begin. |

## Engagement duration and clock

As of 14 October 2026, combat uses the centralized, pause-aware `IVCS_SimulationTime`, scaled by `accTime`. This supersedes the original requirement to keep an engagement near 180 real-world seconds at every acceleration. The duration objective is now expressed in simulation seconds; 180 simulation seconds take approximately 36 real seconds at 5x when processing keeps up. It remains an average outcome, not a forced end timer.

Movement, combat, ammunition sharing and task deadlines share this clock. See [shared simulation time](simulation-time.md) for initialization, pause behavior and migration details. Future calibration should record:

- Number of units on each side.
- Unit classes, weapons, ammunition, and protection.
- Starting distance and unobstructed terrain visibility.
- Actual mission acceleration, including a 5x run.
- The definition of engagement completion.

Duration should vary with relative force strength, weapon effectiveness, range, and casualties. Evaluate an average across repeated trials rather than expecting every fight to last exactly three minutes.

Changing global mission speed or native AI behavior is not implicitly authorized by this design.

## Contact and terrain visibility

Use hostile-side relationships to identify eligible opposing groups. Check distance between their entity positions and apply the initial 300 m limit.

Terrain visibility is evaluated between the group positions with an appropriate elevation offset for infantry. Exact offsets and the visibility threshold are implementation parameters to validate.

Use spatial queries to find candidates rather than scanning every group against every other group. Candidate detection and engagement updates should have bounded work per frame.

Exposure, individual formation offsets, stance, weather, darkness, and detailed cover modeling are deferred. Building and vegetation occlusion are not required by the initial terrain-only scope.

Distance and visibility should determine whether virtual fire can occur. Loss of visibility must not permit continued fire through terrain. Tactical withdrawal or automatic disengagement on contact loss is deferred; retaining an engagement with no valid shot is distinct from firing at an unseen target.

## Unit state and available data

Current virtual units store an ID, class, native object reference, overall damage, weapons with magazine/ammunition information, and a vehicle assignment. Existing weapon and magazine caches do not yet contain all the numerical properties needed for combat.

Use those existing class and loadout identifiers to resolve weapon/ammunition configuration data. Cache the additional combat properties once per class rather than repeatedly querying configuration during shots.

The implemented persisted state additions are:

- Per-hitpoint damage for each unit, alongside overall damage.
- Protective equipment information sufficient for the damage approximation and spawn/despawn preservation.
- Engagement references and timing/firing state needed to continue an ongoing fight.

These additions support the agreed feature. A broader unit skill, stance, suppression, or fatigue system is deferred.

Any mutable damage or ammunition state must belong to an individual unit. Shared class/loadout caches must not be modified when a unit fires or takes damage.

## Firing and accuracy

Each participating unit can fire at an enemy unit using an eligible weapon and ammunition it actually has. Consume ammunition from that unit's stored loadout; exhausted ammunition must prevent further shots with that ammunition.

Hit probability depends on the selected weapon/ammunition and distance between the two group positions. Arm damage applies an accuracy penalty to the shooter. The exact penalty curve is a tuning parameter.

Do not introduce per-unit skill, stance, movement, exposure, or suppression modifiers in the initial version. All virtual combatants are stationary while engaged.

Firing cadence must be part of the model because it controls both ammunition expenditure and engagement duration. Initial cadence and reload handling should use available configuration/loadout information and simple documented defaults where information is missing. The implementation decisions below record the selected cadence, weapon support, and fallback values.

Weapon/ammunition configuration values must be interpreted according to their meaning; a fire-mode selection probability must not be assumed to be a projectile hit probability.

## Hit selection and damage

After a successful shot, choose a target body region using configurable weights. Initial regions are head, torso, arms, and legs. Map these regions onto the unit class's supported hitpoints rather than assuming every class has an identical hitpoint layout.

The implementation decisions below record body-region weights and the fallback mapping for unsupported hitpoints.

Calculate damage using a configurable approximation informed by:

- The selected weapon/ammunition's damage-relevant configuration.
- Range-dependent ammunition behavior where supported by the approximation.
- Unit and hitpoint protection, including relevant vest and helmet protection.
- Existing local and overall damage.

Define how local damage contributes to overall damage and death. Avoid treating every hitpoint as an independent health pool with no effect on survival. Multiple hitpoints can represent related anatomical regions, so mapping must avoid accidental duplicate damage.

Arm injury reduces accuracy. Additional injury effects, including reduced movement from leg damage, medical treatment, bleeding, and unconsciousness, are deferred.

The model is an approximation, not an exact reproduction of Arma's full projectile and protection simulation. Calibrate representative ammunition/protection combinations against native engine observations before tuning the overall duration target.

Native-to-virtual transitions capture individual hitpoint damage and overall damage. Virtual-to-native transitions restore both without resetting injuries or inadvertently healing related hitpoints.

## Engagement lifecycle and movement

An engagement references participating groups and their enemy targets. It owns combat timing and coordinates damage resolution.

On entering virtual combat, stop the groups' virtual movement. Preserve their existing orders and waypoint progress so stopping combat does not destroy task state. The mechanism for pausing and resuming movement is an implementation choice.

Tactical disengagement, retreat, and morale are out of scope. Groups do not retreat merely to meet the duration target.

Removing or eliminating a combat target must clean up engagement references safely. Movement resumes after the engagement has no surviving target; this is lifecycle cleanup rather than tactical disengagement.

A group without usable ammunition cannot keep dealing damage. Ammunition depletion does not complete or disengage an engagement in this version; surviving virtual groups remain stopped until their target is removed or eliminated.

The implementation uses one opposing group per group, uniform selection among surviving enemy units, and excludes third groups from claiming existing participants.

## Handoff to native combat

When either participating group spawns:

1. Prevent further virtual damage resolution for the engagement.
2. Spawn its combat target group as part of the same handoff.
3. Restore surviving units, ammunition, protective equipment, overall damage, and individual hitpoint injuries for both groups.
4. Once enemy unit objects exist, use reveal to provide the participating native groups with information about their surviving enemy units.
5. Allow native AI to maneuver using restored movement orders and let engine damage resolve the engagement. The movement pause applies only while virtual; the handoff does not issue stop orders.

Both groups must finish spawning before enemy information is transferred. Revealing targets provides knowledge; it is not a guarantee of an immediate shot. Validate that existing movement orders do not prevent the intended combat behavior.

Avoid recursive spawn requests or duplicate handoffs when each group's target is the other group. Keep directly engaged groups spawned together while native combat is active so one side does not fight nonexistent objects.

The virtual resolver must never apply damage or consume ammunition concurrently with native combat. This includes the transition window, not just the final active state.

If the groups later return to virtual simulation, capture current native damage and ammunition and resume from that state. Enemy casualties and removed groups must be reflected in the engagement. Exact despawn coordination and renewed contact checks are implementation choices.

Native combat may run at a different pace from the virtual approximation. The three-minute target is a calibration objective for virtual combat, not a promise to force native AI engagements to that duration.

## Proposed first-version limits

The initial implementation adopts these limits:

- Dismounted groups using small arms: rifles, machine guns, and pistols.
- One opposing target group per group, with coordinated reciprocal engagements.
- Simple target selection among surviving enemy units.
- No grenades, launchers, explosive area damage, or occupants firing from vehicles.

The implementation adopts these limits. The additional decisions below define the shipped behavior.

## Correctness and validation

Resolve each exchange once rather than once per participating group's update. Neither entity iteration order nor frame rate should systematically grant one side extra firing opportunities.

Use elapsed time and bounded steps to handle variable update intervals. A delayed frame must not create unbounded work or skip all ammunition consumption and damage that should have occurred.

Validation should cover:

- Hostile groups within 300 m can engage when terrain visibility permits; friendly or obstructed groups do not exchange fire.
- Groups stop moving without losing their queued tasks or waypoint progress.
- Ammunition decreases per firing unit and cannot become negative.
- Weapon/ammunition/range affect hits and damage as intended.
- Hits select valid weighted regions and damage the corresponding unit hitpoints.
- Arm damage reduces accuracy.
- Casualties follow normal unit/group removal and clean up engagement references.
- Each exchange resolves once, with comparable outcomes across update intervals and reversed entity iteration order.
- Spawning one participant also spawns its target without recursion or duplicated combat resolution.
- Native units receive enemy knowledge after both groups exist.
- Repeated spawn/despawn transitions preserve ammunition, equipment, overall damage, and hitpoint injuries.
- Reference trials report mean real-world engagement duration, casualties, and ammunition use, including at 5x acceleration.

The feature is ready when the reference trials approach the agreed duration and the transition/lifecycle checks pass. Record chosen constants and calibration results with the implementation.

## Resolved choices

These design choices are settled by the implementation decisions below:

1. Reference matchup and what counts as the end of a fight.
2. Timing behavior outside the 5x calibration setting.
3. Initial supported infantry weapons and multi-group engagement policy.
4. Body-region weights, arm-injury penalty, and damage/protection mapping.
5. Firing cadence, reload approximation, and no-ammunition behavior.
6. Movement resumption and coordinated despawn behavior.

## Implementation decisions and calibration

The implementation lives in [VirtualSpace/functions/combat](../VirtualSpace/functions/combat). Normal server startup enables it through the existing virtual-space controller. Contact discovery runs automatically from group updates; no new mission setup is needed.

### Timing and budgets

Combat reads the centralized simulation clock, which integrates `diag_tickTime` differences multiplied by `accTime` and freezes while Arma is paused. It no longer owns a separate combat clock. Movement and ammo sharing use the same epoch and acceleration. No global acceleration setting or native AI logic is changed.

Each engagement resolves fixed one-simulation-second exchanges. The frame scheduler visits at most eight engagements,
resolving at most one exchange per visit. After a visit, it stops when the default **3 ms soft combat budget**
is exhausted and rotates unfinished engagements to later frames. Outstanding elapsed time is retained for
bounded catchup; both sides finish their exchange before yielding. One exchange can exceed the budget, and
donor discovery shares this combat budget, with search/combat priority alternating each frame.
Other virtualization work is outside it. `frameBudgetMs = 0` disables the shared deadline; the search allowance and count limits still apply. Direct
`IVCS_Combat_update` calls retain the four-exchange catchup limit unless a smaller third-argument step limit
is supplied. Each free virtual group searches for contacts at most once per simulation second, within the
existing entity simulation budget. Polls without a due exchange retain elapsed time and avoid infantry and
terrain work; removal and spawn transitions still receive immediate checks.

Both sides choose shots before any hits or casualties are applied. Each engagement has its own reproducible random sequence. The update queue resolves an engagement once, independently of the order in which its groups update.

### Pairing and lifecycle

A free dismounted group selects the nearest eligible hostile free group within 300 m with an unobstructed terrain ray between infantry eye heights of 1.5 m. Side hostility uses Arma side relationships. Groups already in an engagement cannot be claimed by a third group; another free pair can form separately.

Each shooter selects a surviving enemy unit uniformly. No exposure or individual positions are modeled. Distance is horizontal distance between entity positions.

Existing task processing, virtual movement, and waypoint completion callbacks pause during combat. Their state is retained, task timeout clocks exclude the combat pause, and deferred completion events run when the engagement finishes. Surviving groups resume their orders when the target is removed or eliminated. Exhausted ammunition stops firing but does not trigger disengagement; a mutually depleted engagement can remain stalled until another lifecycle action removes its target.

The handoff owns both directly engaged groups. Native combat begins only after both groups finish restoring their objects. Both native groups receive enemy knowledge at level 4, combat behavior, and fire permission; restored movement orders remain available so native AI can maneuver and target enemies. Original group behavior/combat mode is restored when the engagement finishes. Spawn/despawn transitions that span frames cannot resolve virtual damage against incomplete state. Native damage is disabled only while unit state is being restored or captured, then enabled for normal spawned combat. Capture also removes already-dead units whose native death callbacks are pending, so corpses cannot respawn or fire virtually.

The spawner retains the opponent of any in-range participant and rechecks source proximity before processing a stale despawn queue entry. Once both are out of range, their native state is captured together before virtual resolution resumes. Default spawn/despawn radii are 200 m; both are explicit spawner settings.

### Weapons, hit regions, and damage

The first version supports primary and handgun weapons firing non-explosive shotBullet ammunition, including rifles, machine guns, and pistols. Launchers, thrown weapons, explosive ammunition, and mounted combat are excluded.

Weapon and ammunition configuration profiles are cached separately from mutable unit state and prewarmed during virtual unit creation, including carried magazines. Each engagement prepares weapon-class entries containing the immutable weapon profile, scaled firing interval, and a magazine-class map of ammunition profiles plus exact impact-speed, base-accuracy, and damage-speed factors. Prepared entries are invalidated when exact group range, accuracyScale, cadenceScale, or minimumFireInterval changes. Firing selects current magazine records every time, so round edits, transfers, insertions, reordering, and weapon replacement remain live inputs. Reload delay is also read fresh. The firing loop evaluates the short injury formula directly against these prepared factors; the standalone accuracy API remains available for other callers. No range quantization or damage/accuracy approximation is introduced. Hitpoint indices, supported target lists, and arm indices are preprocessed per unit layout at creation and native capture. Damage values and current equipment remain live inputs. Replacing/resizing the hitpoint array or changing unit class refreshes the layout cache; hitpoint names/order are immutable within an existing layout. Cumulative body-region weights are rebuilt when settings change. Each unit owns its ammunition records, so firing cannot modify another unit or the class loadout cache.

Accuracy uses weapon-mode dispersion and AI dispersion coefficients, range, and ammunition impact speed. It does not interpret AI fire-mode selection probabilities as hit probabilities. Fully damaged arms reduce virtual hit probability by 65%; intermediate arm damage scales that penalty linearly, using the most damaged arm/hand hitpoint.

Hit-region weights are head 8%, torso 52%, arms 20%, and legs 20%. A region selects one supported anatomical hitpoint uniformly. Broad engine aggregates are excluded from hit selection, while protected anatomical head/hand hitpoints remain selectable even when they have configuration dependencies. Missing regions fall back to another actual supported hitpoint; an empty custom hitpoint snapshot receives overall damage.

The damage approximation uses ammunition hit, impact speed relative to typicalSpeed, unit/hitpoint armor, and vest/helmet protection. Overall damage accumulates using passThrough and armorStructural; a fully damaged head or torso hitpoint is lethal. Limb damage contributes to overall damage but a single fully damaged limb does not itself force death. Native hitpoint snapshots, including aggregate values, overall damage, vest, and helmet are captured and restored across transitions. No separate bleeding, medical, or unconsciousness simulation is added.

Firing counts all deliberate single-round attempts due within each one-second window, capped by actual ammunition. Attempts are aggregated per unit and selected magazine; ammunition/weapon changes split the batch. The firing interval is independent of resolution, with minimumFireInterval = 0.5 seconds retaining the former cadence floor. The selected weapon mode's reloadTime plus an aiRateOfFire-derived pause supplies the interval; unavailable values have bounded defaults. Empty magazines add a three-second reload pause. A batch that empties a magazine adds this pause before selecting another magazine or weapon. Dry units do not bank missed firing attempts. Successful-hit counts use a binomial distribution rather than deterministic expected damage; enemy units, weighted body regions and individual hitpoints are selected only for successful hits. Accuracy and arm injury are sampled at the window boundary, and both firing rosters complete before any damage is applied. Consequently casualty/arm-injury reactions within a window are approximated and seeded outcomes change. Initial accuracyScale is 1.1 and cadenceScale is 1; both are exposed in the combat controller, together with range, region weights, reload delay, and work budgets.

### Reference result and verification

The reference is eight B_Soldier_F units per side, identical default equipment/loadouts, 200 m separation, and unobstructed terrain on Altis. An engagement ends when one side has no surviving units. Twenty seeded trials completed with mean combat-clock duration **170.45 seconds** (2 minutes 50 seconds), ranging from 110.5 to 298 seconds. All completed through casualties, without a forced end timer. This is the initial approximation of the requested three-minute average; unequal forces and different equipment/ranges intentionally change duration.

The calibration runs the production resolver inside Arma using a synthetic real-time clock so repeated three-minute trials do not require a long wall-clock wait. A separate live frame-clock check validates the real-time integration. These historical calibration durations use an explicit simulation-time argument. Since 14 October 2026 the shared runtime clock scales by accTime; the calibration does not claim an observed three-minute native AI engagement or a dedicated-server 5x acceleration run.

Native 9 mm and 6.5 mm projectile observations check the local damage approximation. Tests also verify actual native firing after reveal, precise restoration of native bullet injuries, pair retention/despawn, casualties, ammunition exhaustion/reload delay, task resumption, transition interleaving, and equal seeded outcomes with coarse versus fine updates and reversed sides.

Run the combat suite:

    powershell -File tests/tasks/run.ps1 -TestScript tests/combat/run.sqf -Port 2494 -TimeoutSeconds 240

Existing virtualization and task suites remain applicable:

    powershell -File tests/tasks/run.ps1 -TestScript tests/virtualization/run.sqf -Port 2493 -TimeoutSeconds 180
    powershell -File tests/tasks/run.ps1 -Port 2492 -TimeoutSeconds 600

## Magazine retention (implemented)

`IVCS_Common_getUnitInventoryInfo` accepts a unit class or live unit object and returns `[weaponLoadout, magazineCargo]`. Both lists use magazine records `[class, remainingRounds, ammoUses]`. Each magazine appears once: under the first compatible carried weapon, or in cargo if no carried weapon accepts it. Compatibility uses the weapon cache augmented by Arma's primary-muzzle magazine-well lookup. Other muzzles remain outside primary-weapon sharing.

Class inventories are cached templates. Unit creation copies both lists and their mutable records; live capture returns a fresh snapshot. `IVCS_Common_UnitInfo` now caches complete inventory pairs. The existing Common weapon-loadout functions continue returning only the weapon list, and the legacy group lookup retains its two-field magazine format while delegating to Common.

Virtual units own `magazineCargo` alongside `weapons`. Spawn restores both lists; despawn captures both, including partially filled incompatible magazines, support ammunition, grenades, and other magazines outside virtual combat's supported firing inventory. Virtual shot selection continues reading only weapon-associated magazines. Native Arma can use restored explosives normally.

Native regressions compare full magazine inventories for all 16 standard BLU_F/OPF_F squad classes, check ownership isolation, and verify three spawn/despawn cycles for each faction's ammo bearer with a 17-round incompatible magazine and an 11-round loaded rifle magazine.

Verification on 2026-10-12: inventory regression 93/93, virtualization 96/96, and combat 71/71. The review also preserves the original live weapon-capture behavior, including binoculars. All SQF files changed for magazine retention use CRLF.

## Ammunition sharing (implemented)

`IVCS_Ammo_updateGroup` is the shared group-level interface. One implementation owns requests, compatibility, donor selection, reserve protection, approach/collection timing, cancellation, and cooldowns. Internal virtual/native adapters normalize inventories and move magazines. Settings live at `(IVCS_VirtualSpace_Controller get "combat") get "ammoSharing"`. A bounded frame queue gives pending native requests frequent proximity/reload checks even when ordinary entity updates are spread over many frames; movement orders remain limited to once per second so repeated orders do not restart Arma pathfinding.

Weapon classification and primary-muzzle magazine compatibility are preprocessed once per weapon class and
warmed during virtual unit creation. Shared profiles contain no mutable inventory state. Supplied virtual
units read current rounds without full snapshots. Pending requests snapshot only their participants when
needed and invalidate those per-call snapshots after a transfer. Virtual approach/collection waiting checks
recipient need and token ownership cheaply; arrival and transfer reconstruct current donor reserves.
Native scans read actual inventories, including pickups, reloads, and container changes.

Large donor searches retain recipient, weapon, and donor cursors across frames. A slice inspects at most two
donors, with an additional atomic winner revalidation before reservation. Search jobs rotate fairly and share
the combat frame deadline; their own 1 ms soft allowance limits discovery work. Alternate priority guarantees
that a busy engagement queue cannot starve searches. Native proximity/reload servicing remains in its separate
bounded queue. Searches do not retain inventory snapshots across frames as authoritative state. Stale winners
restart discovery for that weapon, so another donor remains discoverable. Spawn/despawn, engagement lifecycle,
and unregister cancel cursors and queue entries as well as existing reservations.

All durations in the following table use simulation seconds; CPU allowances remain real milliseconds.

| Setting | Default |
| --- | ---: |
| enabled | true |
| scanInterval (idle scans and movement orders) | 1 second |
| pendingScanInterval (native) | 0.1 seconds |
| groupsPerFrame (pending native queue) | 8 |
| donorsPerSlice (discovery) | 2 |
| searchesPerFrame (discovery) | 8 |
| searchBudgetMs (within shared combat deadline) | 1 ms |
| retryDelay | 5 seconds |
| virtualApproachDelay | 3 seconds |
| collectionDelay | 2 seconds |
| collectionDistance | **1 metre** |
| approachTimeout | 30 seconds |
| reloadTimeout (native) | 15 seconds |

Every living eligible AI infantry group member can donate. Recipients request ammunition for empty rifles or handguns, prioritizing their primary weapon even when pistol ammunition remains. A unit holds at most one request at a time; if no rifle donor exists, an empty handgun can receive ammunition. Only magazines usable by the requested weapon are candidates. Launcher resupply is outside this first infantry-sharing implementation. Empty magazines are never donated. Loaded magazines and the fullest spare usable by each carried weapon are protected from donation; weapons with overlapping compatibility may protect the same spare. This protection does not prevent the donor from consuming its own reserve. Unloaded magazines the donor cannot use may all be donated.

Donors are ranked by the number of available compatible magazines, with stable unit IDs resolving ties. Transfer one magazine at a time, prefer the greatest remaining round count, and prefer a backpack source when otherwise equal. Reservations prevent concurrent recipients claiming the same magazine. Compatibility includes primary-muzzle magazine wells, so rifle tracer magazines and MX 100-round magazines are handled using Arma's compatibility rules rather than caliber matching.

Needs discovery checks four roster members per deferred visit (`needsUnitsPerSlice = 4`), using the existing search queue and allowance. A shallow roster snapshot preserves actual unit references; each visit reads current inventory. Added members enter the next scan cycle, while removed members and stale needs cannot commit a reservation. Only shortage candidates need eligibility validation, and eligible donor/recipient ordering is rebuilt from the current roster. Supplied groups finish without allocating donor cursors or winner state. Discovery may span several frames before a reservation is committed. Approach/expiry timing starts at that commit, then virtual requests approximate approach for three seconds and collection for two seconds. Virtual collection ends at the scheduled arrival timestamp plus two seconds; a delayed poll does not restart that timer, and delivery cannot occur before both delays have elapsed. The combat resolver advances requests at each simulated step's timestamp after firing/damage processing, so the recipient waits the full normal reload delay after delivery. Direct batch `IVCS_Combat_update` calls drain the same search policy synchronously by default to preserve coarse/fine synthetic-clock equivalence; the real frame caller passes its fourth `deferSearch` argument as true. `IVCS_Ammo_updateGroup` defaults to deferred discovery, with an optional third false argument for synchronous batch callers. Deferred slices count winner inventory revalidation toward the two-inspection quota; if that quota is exhausted, revalidation resumes on a later visit. Outside combat, inactive group updates also run sharing. Group movement remains stopped during virtual combat.

Native requests use physical inventories as the source of truth. Locally owned, living, conscious, dismounted AI units are eligible; players and remotely owned actors are excluded from automatic movement/inventory changes. The recipient walks toward the donor and must be within **1 m** to start and finish collection. A short PutDown action represents collecting ammunition. The approach compensates for Arma's normal move-order stopping tolerance without teleporting units. The previous walking setting is restored on delivery/cancellation, and movement orders are restored at request completion. Donors continue their normal behavior.

A native transfer checks recipient capacity, adds the exact partial/full magazine, verifies insertion, and removes one matching magazine from the actual donor container. Only magazine cargo in that container is rebuilt; items and loaded weapons are preserved. The update/commit executes without suspension. Rebuilding cargo changes native magazine IDs, so snapshots are refreshed before processing subsequent requests. Collection stops before adding a magazine can trigger an automatic reload. A native reload phase retains ownership while loading is reported in progress, handles primary-weapon switching and waits for reload completion, rather than assuming that a reload command issued during the collection animation succeeded. A reload timeout leaves already-delivered ammunition in the recipient inventory.

Requests revalidate life, eligibility, primary weapon, recipient need, donor reserve, and the reserved magazine before delivery. They time out if arrival fails, reset collection if proximity is lost, and are cancelled during spawn/despawn, engagement start/finish, and group removal. Native tokens never survive a simulation transition. Recipient inventory is captured normally at despawn, including magazines received through sharing.

Verification: the sharing suite covers virtual and physical round conservation, reserve protection, incompatible/empty ammunition, competing recipients, cooldowns, donor death/consumption, full native inventory, approach timeout, transition cancellation, exact virtual reload timing, identical coarse/fine results, and actual native AI collection/reloading under COMBAT behavior through the production group updater. Native verification on 2026-10-12 passes 45 sharing checks, 93 inventory checks, 96 virtualization checks, 71 combat checks, and 210 entity-task checks. The one-trial endurance smoke run passes 7 checks. Script logs contain no SQF errors. All changed SQF files use CRLF.

Run the sharing suite:

    powershell -File tests/tasks/run.ps1 -TestScript tests/combat/ammo-sharing.sqf -Port 2496 -TimeoutSeconds 180

The standard-squad endurance harness now follows each unit's current magazines after transfers and records its final exhaustion episode. Earlier endurance measurements predate sharing and expanded magazine-well compatibility. See [the endurance report](ammo-endurance.md) for historical results and the new one-trial smoke check.

Native movement regression coverage is in `tests/combat/live-movement.sqf`: live handoff issues no stop orders, restored waypoints move the leader and followers, and ammunition-request cleanup resumes movement/formation during combat while preserving deliberate prior STOP orders. Leaders also return to their waypoint orders after collection when no prior movement command was recorded.

## Frame scheduling and preprocessing verification

`tests/combat/scheduling.sqf` verifies fair queue rotation, retained catchup time, unchanged seeded shot
cadence, reserves, and mutable inventory with cached metadata (12/12 checks). `shot-preprocessing.sqf`
compares against the original formulas and checks movement/settings/layout invalidation (40/40).
`resumable-sharing.sqf` checks bounded cursors, shared deadlines, waiting scans, reserve changes, alternate
donor recovery, native transitions, and cleanup (21/21). Combat (71/71), sharing (45/45), and virtualization
(96/96) pass. All 20 seeded calibration outcomes remain identical, averaging 170.45 seconds. An isolated
native reload failure during this work led to reload-phase and collection-action ordering fixes; subsequent
live reruns pass. Engine timing tests run individually.

See [measured optimization results](virtual-combat-performance.md) for frame costs and real-time progress.

## References

- [Sharing implementation](../VirtualSpace/functions/ammo/updateGroup.sqf)
- [Sharing regression suite](../tests/combat/ammo-sharing.sqf)
- [Bohemia magazine compatibility command](https://community.bohemia.net/wiki/compatibleMagazines)
- [Bohemia native reload state](https://community.bohemia.net/wiki/weaponState)
- [Current entity task behavior](../EntityTasks/README.md)
- [Virtual unit state](../VirtualSpace/functions/entities/group/createEntityUnit.sqf)
- [Current simulation clock](../Common/functions/internal/updateSimulationTime.sqf)
- [Bohemia reveal command](https://community.bistudio.com/wiki/reveal)
- [Bohemia damage description](https://community.bistudio.com/wiki/Arma_3%3A_Damage_Description)
- [Bohemia weapon configuration reference](https://community.bistudio.com/wiki/CfgWeapons_Config_Reference)


## One-second aggregation verification - 13 October 2026

The new resolver retains per-unit magazine rounds, compatibility, weapon/ammunition-specific damage, and three-second reload pauses. The binomial sampler uses small independent numerical chunks to avoid probability underflow for large batches; these chunks do not set frame budgets. Default combat accuracy/cadence settings remain 1.1/1.

Before native creation, an atomic spawn setup drains recorded pending whole windows and resolves the fractional remainder once. A combatant killed by that last window does not materialize. Existing noncombat empty-group spawning remains supported. Native participants receive the resulting ammunition and injuries, and the existing paired spawn/reveal handoff continues.

Twenty reference fights now average **166.15 seconds**, versus the earlier 170.45 seconds; all finish through casualties. Coarse and fine update calls still produce identical results within the new fixed-step model. Original seeded per-bullet equality tests are replaced by independent timestamp/ammunition reference tests and binomial distribution checks.

Performance comparisons report each phase's resolution explicitly. Progress permits one resolution interval plus the existing half-second scheduling allowance: 1 second for the old 0.5-second model, 1.5 seconds for the new one-second model. This accounts for output quantization; combat/search budgets and queue/slice caps are unchanged.


## Ammo handoff corrections - 14 October 2026

Spent virtual magazines are removed on exhaustion while retaining the normal reload delay. Native spawn skips zero-round weapon and cargo records, including legacy inventories. Shot selection returns a fresh source/index for immediate removal; inventory references and indexes are never kept in the class/factor cache.

Native sharing requires the recipient to have room for the chosen magazine before approaching, at winner validation and before collection. Transfer still validates actual insertion. A delivered request stays in its reload phase through temporary inventory disappearance, even before Arma reports its reload animation; loaded ammunition or the existing timeout ends that phase. See [debugging findings and regressions](ammo-sharing-debugging.md).


## Infantry attacking ground vehicles - 24 October 2026

Dismounted infantry can now discover and engage hostile ground vehicle entities within the existing 300 m range and terrain visibility rules. Aircraft, UAV entities, vehicle-versus-vehicle combat, and vehicle return fire in virtual simulation remain outside this increment. Native Arma AI behaves normally after handoff, including vehicle return fire.

Weapon selection checks the carried weapon's compatible magazine set and positive remaining rounds. Rifles and pistols can attack soft vehicles. Ground-capable rockets and missiles can attack soft vehicles; armored vehicles require a penetrator submunition or projectile caliber of at least 5. AA-only missiles (`airLock >= 2`), thrown explosives, mines, and grenade-launcher muzzles are excluded. A vehicle is conservatively classified as armored when it inherits from `Tank` or its configured `armor` is at least 100. Small arms do not target armored vehicle windows or occupants in this version. An infantry group without suitable usable ammunition does not initiate the engagement.

Vehicle shot accuracy uses weapon dispersion, target map size, range, and the existing arm-injury penalty. Guided ammunition has a gentler range falloff. The probability before injury/capping is `accuracyScale * 0.75 / (1 + (range / effectiveRange)^2 + (dispersion * range / (mapSize / 2))^2)`, where effectiveRange is 600 m for guided missiles and 300 m otherwise. The existing 0.8 hit-probability cap applies. Weapon cadence, magazine exhaustion, reload delay, one-second resolution, and the centralized simulation clock remain shared policies. Launchers now participate in the existing virtual/native magazine-sharing policy, including the donor's loaded magazine and one spare reserve.

Damage is an explicit configuration-based approximation. Incoming damage is `(projectile hit + penetrator submunition hit) * impactFactor / (vehicle armor * armorStructural)`. Bullets retain their velocity/range impact factor; rockets and missiles use 1 rather than treating their low launch speed as impact speed. Each hit increases overall damage and one uniformly selected stored component, adjusted by its configured resistance. Negative component armor is interpreted as absolute resistance relative to hull armor; positive values are hull multipliers. Profiles and per-engagement shot factors are cached; rounds and component damage remain owned by individual entities. This is not detailed armor geometry, penetration direction, ERA/slat behavior, blast propagation, or a native-damage calibration.

Virtual vehicles do not shoot back or expend turret ammunition. The infantry group and the vehicle's connected crew, passenger groups, and transports reserve one engagement and stop virtual movement. Only the infantry participant fires. Vehicle hostility follows its commanding group when assigned, otherwise its stored side. Existing ammunition exhaustion and visibility-loss behavior still retains the engagement without automatic disengagement.

Spawning any member creates the complete connected engagement, restores vehicle overall/component damage and infantry ammunition, seats assigned occupants, and reveals the vehicle to the infantry group. Crew groups receive knowledge of the attacking infantry. Capturing any member returns the engagement to virtual authority only after every connected entity finishes capture. Spawn/despawn transitions suppress virtual resolution; recorded pending fire is resolved before objects are created. Vehicle capture freezes native damage and position updates while state is being stored. Infantry restoration loads one magazine into each weapon before adding reserves, so a loaded rocket does not temporarily need an extra backpack slot. This also avoids one weapon's reserve magazines blocking another weapon's loaded magazine.

Overall vehicle damage reaching 1 unregisters the virtual vehicle and clears the engagement. Existing transport cleanup dismounts surviving stored occupants; this increment does not invent crew casualties or injury propagation from vehicle destruction. Native destruction continues to use native casualties and the existing Killed handler. Removing any reserved member also ends the engagement and releases the others.

The regression suite is `tests/combat/vehicles.sqf`; run it with `tests/tasks/run.ps1 -TestScript tests/combat/vehicles.sqf`. It covers weapon/magazine suitability, terrain/range/hostility, passive vehicles, damage, ammunition consumption and sharing, vehicle-led and infantry-led handoff, connected transport retention, pending fire, and destruction cleanup.

Verification on 24 October 2026: **621 checks passed across eight engine suites**, including 58 vehicle integration checks. The final weapon-restoration change was rechecked by the vehicle, virtualization, ammunition-sharing, aggregation, and ammo-handoff suites. Existing infantry calibration averaged 178.1 simulation seconds with the current repository settings. The damage approximation is functional but has not been calibrated against native vehicle impacts. Source hashes, retained RPT paths, and per-suite results are in [verification evidence](vehicle-combat-results/verification.json).

## Expanded infantry attacks against vehicles â€” 25 October 2026

This increment addresses native damage calibration, occupants, additional ammunition, target categories, stalled fights and vehicle workload measurement. Vehicles remain passive in virtual resolution. Native Arma AI resumes ordinary combat after handoff, including return fire.

### Targets and attack selection

Groups can attack land vehicles, boats, aircraft and UAV entities within 300 m using three-dimensional distance and terrain visibility. Infantry-versus-infantry retains its existing two-dimensional range policy. Visibility uses sea-surface-relative positions over water. Weapon profiles cache every attack muzzle and its compatible magazines, with an inverse magazine lookup; current inventory and remaining rounds are always read from the unit. The inventory importer associates grenade-launcher ammunition with its carried weapon without letting grenades satisfy a rifle ammunition shortage.

| Ammunition | Virtual vehicle attack policy |
| --- | --- |
| Rifle/pistol bullets | Soft vehicles; armored occupants/windows are not separately targeted. |
| Ground rockets and missiles | Compatible launcher, ground-capable ammunition; armor requires anti-armor capability. |
| AA missiles | Air targets require air-lock capability; AA-only ammunition is excluded against ground targets. |
| Grenade-launcher HE | Soft vehicles, 20â€“300 m; smoke does no damage. |
| Hand grenades | Soft vehicles within 35 m. |
| Mines and placed charges | Suitable ammunition within 5 m, with eight seconds of placement before expenditure. Anti-armor ammunition is required against armor. |

Placement is an abstract close attack followed by detonation. It does not create persistent minefields, model remote detonator ownership, or simulate native AI approaching to place a charge. A second charge pays one placement delay plus the existing reload delay. Spawning during placement preserves the unspent charge and lets native AI take over. Grenade/charge attacks currently extend the vehicle resolver; the calibrated infantry-versus-infantry resolver remains unchanged. Existing primary/pistol/launcher sharing continues; dedicated grenade-launcher and utility-ammunition resupply is a later extension.

An enclosed squad automatically dismounts together when its transport is on land and near ground level. Valid personal-weapon seats can fire compatible weapons while mounted; launchers and close explosives require a land dismount. Enclosed airborne or waterborne occupants cannot dismount to launch a virtual attack. Releasing the last commanded/cargo vehicle retains the actual transport position, preventing the squad from following a transport after dismounting.

### Damage and occupants

The native calibration fixture collected **96 samples across 32 vehicle/ammunition pairs**: three samples for each of four stock ground vehicles and eight ammunition classes. Direct shots verify that a collision ray intersects the intended vehicle; 40 mm HE uses armed blasts rather than unarmed short-range projectiles. The accepted observations, fixture parameters and source RPT paths are in [native calibration evidence](vehicle-combat-results/native-calibration.json). Reproduce with `tests/combat/vehicle-native.sqf`, `vehicle-native-blast.sqf` and `analyze-vehicle-native.py`.

Cached profiles preindex each observed damage sample to the vehicle's stored component indices, including turret components. A seeded hit selects a sample and applies both overall and component deltas. Rifle range scaling is normalized to the reference impact velocity. Native observations distinguish an engine/body being damaged from overall hull destruction: rifle fire can disable a soft vehicle without falsely setting overall damage to one. Engine failure, a destroyed track, or two destroyed wheels stops virtual vehicle movement. Native capture recalculates mobility so repairs can restore speed.

Uncalibrated classes/ammunition use the configuration-based fallback. Calibration is a practical reference approximation using frontal shots/nearby blasts, not a full armor geometry model. Directional penetration, ERA/slat behavior, ammunition cookoff, blast propagation and aircraft crash dynamics remain outside this increment. Three samples per pair do not establish a statistical damage distribution.

Hits can injure or kill actual stored occupants; casualties go through normal roster cleanup, and survivors keep their overall/anatomical injuries when spawned. Region selection uses the same configurable body weights as infantry. Occupant injury probability is an approximation based on armor, anti-armor capability and destruction; it has not been calibrated against native casualty probabilities. Destroyed aircraft above 10 m have catastrophic crew loss. Removing the final attached crew group releases that attachment without ending an attack against a surviving vehicle. Destroying the vehicle dismounts surviving occupants and finishes the primary engagement.

UAV handoff creates and owns its implicit native AI crew. Capture/destruction removes those objects and their implicit groups. Spawning any connected combat member restores the complete engagement and reveals opposing participants; damage, compatible magazine counts and seat assignments remain authoritative through capture.

### Stalled fights and recovery

A virtual fight finishes after **30 simulation seconds without terrain visibility** or **15 simulation seconds without usable ammunition/progress**. A concrete transfer already underway receives its approach/collection/reload allowance (eight additional seconds with default settings). A weapon waiting through a long firing cadence is not treated as ammunition exhaustion. Actual shots and delivered magazines reset progress; unsuccessful searches do not keep a dry fight alive indefinitely.

Finishing releases the combat stop and resumes existing orders. Groups avoid the same target for 15 simulation seconds to prevent immediate restart loops; other targets remain eligible. Native combat time does not consume the next virtual recovery window. These intervals use the centralized simulation clock, including pause and `accTime` scaling.

### Validation and performance

The expanded integration suite is `tests/combat/vehicle-expansion.sqf` (57 checks); exact replay of all native damage samples and mobility transitions is covered by `vehicle-calibration.sqf` (228 checks). **999 checks passed across 11 engine suites**, including existing infantry, virtualization, inventory, handoff and sharing regressions. Infantry reference fights still average **178.1 simulation seconds** across 20 seeded trials. Counts, retained engine logs and source hashes are recorded in [expansion verification](vehicle-combat-results/expansion-verification.json). Temporary mission-source availability is recorded separately from the retained RPT evidence.

`tests/combat/vehicle-performance.ps1` compares the original and expanded vehicle resolvers with shared current metadata/scheduling. Each phase runs **20 engagements: 20 eight-man attacking squads, 20 passive APCs and 20 two-man crew groups** (40 groups, 20 vehicles, 200 infantry). Separate normal-ammunition and forced-AT-shortage phases verify continued firing, simulated-time progress, successful delivery and cleanup. Benchmark-only wrappers keep targets/crew alive while executing damage and crew-injury/casualty calculation; actual removal is intercepted to sustain the workload. The four original resolver functions are preserved under `tests/combat/vehicle-baseline/`; this isolates resolver cost rather than comparing two complete historical builds. No production frame budgets are reduced for this change.

Engine references: [triggerAmmo fuse/time parameters](https://community.bistudio.com/wiki/triggerAmmo?useskin=vector), [AGL/ATL/ASL position formats](https://community.bistudio.com/wiki/Position2D?useskin=darkvector), and [weapon magazine compatibility](https://community.bistudio.com/wiki/compatibleMagazines). The native 40 mm fixture explicitly sets the remaining fuse distance to zero before triggering its blast.

Final instrumented results: total IVCS **p99 4.665 ms with normal ammunition and 4.627 ms under forced shortages**, compared with 4.389 ms and 4.547 ms using the original resolver. All eight windows passed 44 workload checks. No frame budget was reduced. See the [vehicle performance report](vehicle-combat-results/performance/README.md) for distributions, attribution, capture metadata, and the limits of the sustained APC fixture.

## Land-vehicle return fire â€” 25 October 2026

Land vehicles now fire back at exposed infantry in the existing 300 m, terrain-visible engagement. Existing group discovery can start the fight when only the vehicle has effective weapons, so a rifle squad does not become immune merely because it cannot penetrate armor. Aircraft, helicopters and boats retain passive virtual behavior. Native Arma AI continues ordinary combat after spawning.

Virtual land vehicles also scan for nearby hostile infantry, including already-spawned groups. Discovering native infantry spawns the linked vehicle and crew and transfers combat to Arma. Vehicle scans exclude vehicle targets.

Each manned firing station requires a living unit actually assigned to its gunner/driver path. Ground UAVs can operate their unmanned stations. Fully damaged gun/turret components disable the corresponding station; engine or track failure alone does not silence an intact weapon. Arm injuries reduce the current gunner's accuracy using the same penalty as infantry. Empty seats, unarmed vehicles and depleted stations cannot produce rounds.

A station chooses one compatible weapon at a time, preferring bullets, then other infantry-capable projectiles. Selection checks positive stored turret-magazine rounds, the shared ammunition-use classification (including its target-category fallback when `aiAmmoUsageFlags` is zero), and `allowAgainstInfantry`; smoke, countermeasures, artillery ammunition and AA-only ammunition are excluded. The weapon's configured AI range modes, dispersion, burst size, cyclic interval and pause determine averaged firing attempts. Different stations fire independently. Vehicle inventory cargo and pylons are not treated as ordinary turret reserves, and this change does not add turret resupply from allied infantry.

Class-level muzzle, ammunition, mode and component metadata is prepared during vehicle creation. The engagement caches only range/settings-dependent factors; gunner identity, injuries, magazine ownership and remaining rounds are read live. Shot batches consume exact rounds and delete exhausted virtual records, apply the shared magazine-change delay, and cannot bank attempts while dry. Per-station delays stop virtual catch-up during native combat. `vehicleShots` and `vehicleHits` report vehicle contributions; total engagement hits remain projectile hits, rather than counting every splash victim.

Infantry and vehicle attempts are queued before casualties are removed, allowing mutual destruction in one resolution interval. Vehicle bullets use the existing weighted anatomical hitpoints and equipment protection. Direct explosive impacts use the stronger of impact damage and blast, without adding both. A successful explosive impact also affects exposed squadmates in an assumed **6 m formation grid**, controlled by combat `blastSpacing`. Splash applies full `indirectHit` inside `indirectHitRange`, drops with the fourth power of radius/distance outside that radius, and stops at four radii. This is a group-local approximation: misses do not create near-miss blast events, and there is no individual world-position, building-cover, turret-arc, cross-group or friendly-fire model. Enclosed passengers are protected by their transport; FFV occupants remain exposed.

A fight remains active while either side has usable ammunition, including during a long vehicle firing cadence. The existing 30-second visibility timeout, 15-second ammunition/progress timeout, sharing allowance, target cooldown and centralized simulation clock remain in effect. Spawning/capture preserves partial turret magazines and injuries; native combat never also receives virtual return-fire damage.

Regression coverage is `tests/combat/vehicle-return-fire.sqf`: crew eligibility, land/air/sea separation, ammunition compatibility, component disabling, injury accuracy, damage and splash, exhaustion/recovery, passenger protection, mutual lethality and native magazine conservation. The sustained workload harness accepts `-ReturnFireComparison` to compare return fire enabled versus disabled while keeping the rest of the current resolver identical. Benchmark-only actors remain alive so all 20 engagements continue to execute damage calculations.

Engine references: [infantry ammunition-use flags](https://community.bistudio.com/wiki/CfgAmmo), [weapon modes and AI cadence](https://community.bistudio.com/wiki/CfgWeapons_Config_Reference), and [indirect damage ranges](https://community.bistudio.com/wiki/Arma_3_Damage_Description). Formation spacing and use of the shared infantry hit model are IVCS approximations rather than native damage calibration.

Performance verification: the 20-engagement comparison passed all 52 workload checks. Precise pooled IVCS frame p99 was **4.849 ms normal** and **4.984 ms with forced shortages**, compared with 4.493/4.664 ms when only return fire was disabled. The mean added frame cost was 0.133/0.147 ms; production budgets were unchanged. See [return-fire verification and measurement details](vehicle-return-fire-results/README.md).

Correctness verification: **716 passing checks across eight engine suites**, including 44 return-fire checks covering both stock tank HE and automatic grenade-launcher splash. The review fixed zero-flag GMG eligibility by sharing the inventory importer's ammunition-use classification. Final return-fire and vehicle integration runs passed after that change. All changed SQF files retain CRLF line endings.


## Vehicle combat correctness and efficiency review - 25 October 2026

Both infantry-to-vehicle and vehicle-to-infantry attack selection now enforce the ammunition's configured arming distance. Existing GL safety ranges and vehicle AI mode ranges still apply. Underslung GL attacks use the firing muzzle's own dispersion, cadence and speed metadata. An interrupted mine/charge placement loses its progress and must restart with a currently owned magazine in reach.

Native handoff gives implicit UAV AI crews enemy knowledge using the same side-aware selection as stored crew groups, including allied autonomous vehicles linked to the attacking group. Engagement creation and ammunition-recovery checks now share `canFightVehicle`.

HE splash footprints and small immutable damage profiles are cached by exposed target count, spacing, ammunition and impact index. Cached indices resolve against current units each tick, so dead/replaced records are not retained. Preparation is lazy; ordinary MG fire does not build splash geometry. The squared-distance calculation preserves the group-local damage policy and random ordering. See [review findings and verification](vehicle-combat-review-results/README.md) for exact coverage and a paired HE throughput comparison.


## Helicopter ground combat (2026-10-25)

This increment enables armed helicopters against infantry and land vehicles,
including suitable infantry and ground-vehicle AA return fire. It supersedes the
earlier passive-helicopter limitation. Fixed-wing, air-versus-air, sea return fire,
and ground-vehicle-versus-ground-vehicle combat remain separate work.

### Waypoint policy

Waypoints accept `airCombatRole`: `TRANSPORT` by default, or `ATTACK`. This is
explicit per waypoint, independent of helicopter class and passengers. Transports
continue the route, return fire through manned turret weapons after incoming
virtual attempts, and temporarily detour when behavior permits. Attack orders can
initiate combat inside their assigned area, make firing passes against infantry,
and use standoff fire against vehicles. The pilot's fixed
weapons are excluded from transport defensive fire.

`combatMode` BLUE prohibits virtual fire; GREEN/WHITE allow defensive fire only;
YELLOW/RED allow proactive fire for ATTACK. CARELESS suppresses virtual fire and
tactical evasion; other behaviors permit evasion. Speed affects flight movement.
UNCHANGED/NO CHANGE inherit previous activated/completed leg settings, initially
YELLOW/AWARE/NORMAL. These are framework policies using the existing
[Arma waypoint combat modes](https://community.bistudio.com/wiki/Combat_Modes).

```sqf
private _wp = [_destination, "MOVE", [
    ["airCombatRole", "ATTACK"],
    ["combatMode", "YELLOW"],
    ["behavior", "AWARE"],
    ["speed", "NORMAL"]
]] call IVCS_VirtualSpace_createEntityWaypoint;
[_crewEntity, _wp] call IVCS_VirtualSpace_entityAddWaypoint;
```

Use TRANSPORT with GREEN/AWARE for defensive fire while retaining the route.
Native waypoint imports default to TRANSPORT. Framework waypoint metadata survives
capture/spawn. Spawned crew keep waypoint combat settings and receive enemy
knowledge. ATTACK uses temporary standoff move and targeting orders; native AI
executes the flight and weapon handling. Orders are refreshed when their target or
destination changes, and released when route following resumes. Native YELLOW/RED can
permit gunners to fire before receiving fire, according to native fire discipline.

### Flight and contact

The configurable helicopter contact caps are **750 m against infantry** and
**1,000 m against land vehicles**, measured in **3D** with the existing terrain ray.
The same encounter cap applies to both firing directions. Weapon AI range modes and fuse distance still constrain firing.
Infantry small arms retain 300 m; compatible infantry AA can use the 750 m infantry/helicopter
envelope. Ground-only combat retains 300 m. Ground discovery retains its local
spatial query and separately checks a helicopter index, avoiding a broad 1,000 m
ground scan. Autonomous rotary UAVs do not require a human pilot.

Virtual attack flight targets **100 m AGL**. Vehicle attacks use **400 m horizontal
standoff**. Infantry attacks alternate between **225 m firing destinations** and
**450 m repositioning destinations**, within their assigned attack area. Firing
is allowed while approaching, subject to weapon and encounter range checks. Helicopter crew tasks and waypoint completion can
progress during combat. Incoming attempts trigger defense even when they miss.
When permitted, evasion takes a **400 m detour**, angled 45 degrees away from the
threat, targeting the configured combat altitude, until
**10 simulation seconds** pass without further fire. Repeated fire
extends the threat window. The original route/task remains intact, outstanding
route requests are cancelled, and the route is rebuilt on return.

Native FiredNear/Hit/IncomingMissile notifications enter the same threat state and
issue temporary move orders, then resume the current route. Native avoidance
therefore depends on engine notifications and AI movement; this is not continuous
bullet-trajectory tracking. Landing orders are released during evasion and their
approach state is refreshed on resumption. A cancelled route is not resurrected.

Transport task deadlines continue in simulation time during combat, including
when evasion temporarily suspends task updates. Finishing combat does not credit
them with the whole combat duration. Passengers follow their helicopter and never
automatically dismount in midair. Loss of a pilot or a fully destroyed rotor causes
an abstract descent and crash on ground contact, using existing occupant casualty
rules. Engine failure alone produces a simple descent and engine shutdown. This
is not autorotation or detailed crash physics.

### Weapons and handoff

The shared mounted selector handles turret magazines and real pylon records,
requires a living operator/autonomous station and functional gun, respects weapon
compatibility, target suitability, AI ranges, and arming distance, and deducts exact
rounds from the actual source. Empty pylons retain identity/loadout/owner with zero
rounds. They are never duplicated into ordinary turret reserves. Native capture
regroups pylons under their current pilot/gunner owner. Weapon and pylon class
profiles are prepared during creation; firing factors are reused until relevant
geometry/settings change. Infantry hits reuse anatomy/protection/HE splash;
vehicle hits reuse existing calibrated/configuration damage and crew injury.
Both vehicle firing snapshots precede damage application.

Spawn/capture transfers connected enemies, crew and passengers together with
partial ammunition, damage, altitude, heading and velocity. Motion is restored
after boarding because boarding can reset it. Helicopter crew fire settings are
not forced to RED/COMBAT or restored to an obsolete completed waypoint's settings.
Native mode never also resolves virtual damage. Time remains pause-aware and
accTime-scaled; one-second resolution and scheduler limits are unchanged.
Settings live in `VirtualSpace/functions/combat/createController.sqf`.

Detailed turret arcs/exposure, missile lock acquisition/flight time,
countermeasures, fuel/rearm, advanced terrain avoidance, pitch/roll restoration,
native helicopter damage/duration calibration, and a new 20-engagement p99 capture
are deferred. Virtual evasion is approximate and native AI flight trajectories are
not guaranteed to match it.

### Verification

Run `tests/tasks/run.ps1 -TestScript ./tests/combat/helicopters.sqf`. The focused
engine suite covers role/fire permission, AA, pylon consumption, stored vehicle
damage, virtual/native evasion orders, route progress/inheritance, handoff,
partial ammunition/velocity, low-altitude flight, autonomous UAVs, and fine-step
pilotless descent. These checks do not establish native flight trajectories or
performance percentiles.


Verification on 2026-10-25: helicopter integration **53/53**, land return fire
**43/43**, vehicle expansion **57/57**, infantry/vehicle integration **58/58**,
infantry combat **71/71**, and task lifecycle **211/211**: **493 checks passed**.
The helicopter suite covers the final flight refinements; infantry and basic
vehicle runs preceded the last helicopter-only refinements. The complete task run
passed with the normal 600-second allowance after an initial 300-second harness
timeout during live landing scenarios. Engine runs reported no SQF errors. All
changed SQF sources use CRLF; `git diff --check` passed. No helicopter performance
percentiles or native armed-flight balance claims are inferred from these checks.


Range/altitude tuning verification (2026-10-25): helicopter integration **59/59**
and vehicle expansion **57/57** passed, **116 checks total**. New checks cover
inclusive 750/1,000 m 3D boundaries in both participant orders, rejection just
outside each limit, and attack/evasion targeting 100 m AGL from higher altitude.
The prior single helicopter range setting is replaced by
`helicopterInfantryRange` and `helicopterVehicleRange`; discovery, ongoing contact,
and infantry AA eligibility use the corresponding encounter limit. All modified
SQF files retain CRLF and `git diff --check` passes.


## Helicopter counterplay (2026-10-25)

This increment adds supporting AA, bounded attack orders, firing passes, and an
infantry defensive response. Encounter limits remain 750 m for infantry and
1,000 m for vehicles, measured in 3D; combat flight targets 100 m AGL.

### Supporting AA and ownership

Infantry with usable compatible AA launchers and land vehicles with suitable
anti-air firing stations can join an existing helicopter engagement. Discovery
includes already-spawned defenders. AA in a ground fight can prioritize the air
threat by ending its old engagement and joining the helicopter fight; AA already
committed to another helicopter fight retains its current target. Friendly,
out-of-range, obstructed, unarmed, transitioning, and already-reserved duplicate
participants are rejected. Hostility uses a vehicle's current commanding side.

A single engagement owns all supporters and their linked crew/transport graph.
Supporters are not scheduled as separate copies of that engagement. They spend
only their own ammunition and their queued impacts resolve alongside the primary
exchange. A join timestamp prevents retroactive support fire during catch-up;
switching fights preserves reload/cadence delays. Known pending work is flushed
before admission and linked membership is refreshed after pending casualties.

Supporting fire can continue when the primary target loses contact, provided an
AA supporter still sees the helicopter. Removal of a supporter does not cancel
the surviving primary fight. When an engagement ends, all support reservations,
ammunition-sharing requests, temporary stances, and owned native firing holds are
released. Supporting infantry participate in the shared ammunition lifecycle.

Spawning or capturing a supporter transfers the entire engagement. Native
helicopter AI receives knowledge of supporting AA as well as its primary enemy.
Adding late native AA preserves the helicopter's current motion and original
native combat settings. Native ownership resolves physical fire; virtual ownership
resolves aggregate fire. General multi-target combat and merging simultaneous air
engagements are not introduced.

### Bounded attack orders

ATTACK waypoints default to a **750 m horizontal attack radius around the waypoint
position**. Both the helicopter and target must be inside the area for proactive
acquisition. Optional `airAttackCenter` and `airAttackRadius` override the center
and radius. An empty center uses waypoint position; a negative radius uses the
controller default. Destinations are clamped to the area. An offensive engagement
ends when its helicopter or target leaves that area, with target cooldown and the
original route retained. A defensive response outside the area can still evade
and return fire without becoming an offensive pursuit. Transport behavior keeps
its existing defensive route policy.

These are IVCS waypoint options, not additional native waypoint types:

```sqf
private _wp = [_objective, "MOVE", [
    ["airCombatRole", "ATTACK"],
    ["airAttackCenter", _objective],
    ["airAttackRadius", 750],
    ["combatMode", "YELLOW"],
    ["behavior", "AWARE"]
]] call IVCS_VirtualSpace_createEntityWaypoint;
[_crewEntity, _wp] call IVCS_VirtualSpace_entityAddWaypoint;
```

### Firing passes

Proactive helicopter attacks on infantry alternate **8 simulation seconds of
firing** with **25 seconds of repositioning**. Firing destinations are 225 m
horizontally from the target; repositioning destinations are 450 m away at an
angle, all at 100 m AGL and bounded by the attack area. Firing may begin on the
approach within normal weapon/encounter range; the approximation does not require
an exact physical pass over the target. Vehicle attacks retain 400 m standoff.

Phase timing uses the shared simulation clock and survives native handoff. Tick
segments that cross a boundary resolve only actual firing time. Reload/cadence
timers advance during repositioning without banking shots. A loaded helicopter
in a long break is not classified as out of ammunition. The scheduler's existing
step and frame limits are preserved.

Native repositioning temporarily applies
[`setUnitCombatMode "BLUE"`](https://community.bistudio.com/wiki/setUnitCombatMode)
to the helicopter's actual AI crew, including gunners belonging to linked groups.
Player occupants are excluded. Original unit modes are restored when firing
resumes, combat ends, or the aircraft is captured; changes to the group's combat
mode take precedence over obsolete saved settings. Crew changes refresh the owned
hold. Temporary target orders are released during the break. Flight trajectories
remain subject to native AI.

### Infantry response

Actual incoming virtual attempts trigger defense even when they miss. Native
helicopter firing uses the same response policy for its profiled infantry target;
flares and other unsupported non-damaging magazines do not trigger it.

After a **3-second reaction delay**, dismounted infantry retreat gradually up to
**100 m** away from the threat. Group exposure falls linearly from 1 to **0.35**
over the following **10 seconds**, reducing helicopter hit probability. Formation
spacing for the existing splash approximation doubles once the reaction delay
has elapsed. These are cheap group-level cover/dispersion approximations; no
individual geometric cover search, building interior, or guaranteed real cover is
claimed. Exposure changes affect air fire, not ground-only combat or damage per hit.

Infantry without usable AA can disengage after reaching the retreat destination.
A **60-second target cooldown** prevents immediate reacquisition. Infantry with
usable AA retain the fight while responding defensively. Original tasks and
waypoints remain available, and the retreat's movement tick is not spent again
on the resumed route. Cover state is reset when combat ends.

Native infantry receive a crouched stance and a retreat order. Prior stances are
restored on completion/capture, while virtual defense state survives capture.
Native Arma damage and terrain/AI movement continue to determine physical results;
the virtual exposure multiplier is not applied as a native damage modifier.

Settings are in `VirtualSpace/functions/combat/createController.sqf`. Missile
countermeasures, detailed cover geometry, full multi-target air combat, native
attack-pass balance, and a new 20-engagement p99 capture remain separate work.


Counterplay verification on 2026-10-25: tactics **50/50**, helicopter integration
**59/59**, infantry/vehicle integration **58/58**, land return fire **43/43**,
vehicle expansion **57/57**, infantry combat **71/71**, and task lifecycle
**211/211**: **549 checks passed across seven engine suites**. Final tactics,
helicopter, and vehicle runs cover the last AA admission/reload refinements; other
regression runs preceded those AA-specific refinements. Successful runs reported
no SQF errors. All changed SQF files retain CRLF and `git diff --check` passes.

The review fixed timestamp dispatch into ground combat, native motion restoration
on late AA joins, supporter timing during catch-up, reload preservation when AA
switches fights, queued AA damage after primary casualty cleanup, stale graph
membership after pending damage, idle-visit allocation work, and retreat movement
being spent twice in one tick. Tests verify native orders and state ownership;
they do not establish detailed flight trajectories, new combat balance, or p99
performance for the expanded support graph.

### Follow-up helicopter review (2026-10-25)

The correctness and simplification review implemented these fixes:

- Native AA admission reads current physical weapons and magazine rounds instead
  of the virtual ledger captured before spawning. This covers removed launchers,
  empty loaded magazines, exhausted vehicle turrets, and rearmament. Eligibility
  probes leave virtual inventories unchanged. Rifle-only native support candidates
  are rejected before allocating an inventory snapshot.
- Incapacitated native aircraft release combat movement, temporary target orders,
  and crew fire holds. Shared cleanup retains the original route and resets owned
  LAND approach state. Virtual forced descent retains flight ownership and downward
  velocity through ordinary vehicle updates, so handoff preserves falling motion.
- A native group combat-mode change can overwrite a per-unit firing hold without
  changing the crew. Reposition updates reapply BLUE when needed; releasing the
  hold still respects the group's newer combat mode.
- Clamped destinations stay 10 cm inside the attack radius. This prevents floating
  point projection/movement rounding from cancelling the aircraft's own offensive
  engagement. Explicit area checks retain their configured radius. Native area
  disengagement clears the assigned attack target even when a defensive evasive
  detour is still active.
- Exposure scales the final capped hit probability. Even a weapon already at the
  0.8 accuracy cap receives the configured cover benefit: full cover gives 0.28
  probability with the default 0.35 exposure. Ground return fire is unchanged.
- Supporting AA receives the same bounded ammunition-collection timeout grace as
  primary participants. An unsuccessful collection still expires normally.

Movement updates reuse one area lookup and one firing-phase query. Phase-only
queries skip segment construction, while combat ticks integrate the actual firing
segments without two extra callback evaluations. Redundant policy/ID conditions
and the duplicate case-sensitive rotor-name check were removed. Required lifecycle,
zero-distance, and optional-waypoint checks remain.

`tests/combat/helicopter-review.sqf` adds engine regressions for these cases,
including 72 attack-area bearings and phase-boundary integration. The initial
focused run reproduced six failing checks; subsequent native-mode and boundary
probes reproduced two more before their fixes. Validation checks native orders and
stored state; flight trajectories, combat balance, and the expanded engagement
p99 are not remeasured by this review.

Review validation: **570 checks passed across eight Arma engine suites**, with no
SQF errors reported:

| Suite | Passed |
| --- | ---: |
| Helicopter review regressions | 21 |
| Helicopter tactics | 50 |
| Helicopter integration | 59 |
| Infantry/vehicle integration | 58 |
| Land vehicle return fire | 43 |
| Vehicle expansion | 57 |
| Infantry combat | 71 |
| Task and waypoint lifecycle | 211 |

The final three helicopter suites ran after the last target-cleanup refinement.
The task lifecycle run covers the movement-cleanup extraction; later helicopter
refinements were exercised by the final helicopter runs. Infantry reference trials
still averaged **178.1 simulation seconds** over 20 completed fights. All ten SQF
files changed during this review retain CRLF, and `git diff --check` passes.
