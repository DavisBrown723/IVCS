# Commander implementation design

Status: Draft. Staff names are Personnel, Intelligence, Operations, and Logistics. Analysis, Fortify, reusable Withdraw, and Build Logistics Hub are agreed. The Commander selects broad goals and the operations needed to achieve them; Operations executes those operations. Objective analysis, goal selection rules, data structures, and detailed authority remain proposals.

IVCS needs a commander that turns campaign goals into coordinated action by virtual and spawned forces. The design separates staff responsibilities, authority over priorities and force allocation, and operation execution. Virtual combat and map indexing are being developed separately; commander design should give those systems clear interfaces.

## Agreed starting staff

- Personnel manages the availability of forces.
- Intelligence handles enemy intelligence, threat estimates, and reconnaissance needs.
- Operations handles executing operations.
- Logistics handles logistical needs across objectives and forces.

Signals is outside the initial scope. These staff responsibilities do not require a separate update loop or FSM for every section.

## Agreed Analysis module

Analysis is a shared module for reusable analytical work, starting with terrain analysis. It supports the staff and operation planners. Its responsibilities can expand when other concrete analysis needs emerge.

Analysis derives candidate options and measurements from supplied data and constraints. The requesting staff module or operation interprets those results and chooses what to do. Intelligence retains enemy intelligence and threat interpretation, Operations retains detailed planning and execution of selected operations, and Logistics retains logistics decisions. Analysis adds analytical capability without introducing another level of command.

## Commander goals and operation execution

Use two command layers. The Commander identifies and prioritizes broad goals and selects the operations needed to achieve them. Operations plans the detailed execution of those selected operations, coordinates their assigned forces, and reports outcomes or problems. EntityTasks remains the execution module below individual operations.

The Commander may pursue several goals concurrently. It owns the overall plan for each goal, including supporting objectives, selected operation types, their dependencies, and resource commitments. Planning functions can be organized internally without introducing another independent command authority.

| Concept | Meaning | Example |
| --- | --- | --- |
| Objective | A location, area, or other target with its own world state. | An airport and surrounding towns. |
| Commander goal | A desired outcome worth committing forces to. | Capture Airport while retaining a designated reserve. |
| Goal plan | The Commander's selected operations, dependencies, and commitments for that goal. | Obtain intelligence, secure an approach, build required support, stage forces, and capture the airport. |
| Operation | A coordinated activity executed by Operations with its own outcome and resources. | Recon the airport, Attack a supporting town, or Build Logistics Hub. |
| Entity task | An individual group's executable action. | Move to an assembly area, board transport, or Withdraw to a fallback. |

### Commander responsibilities

The Commander chooses what should change or remain true, why it matters, and the resources and constraints attached to that outcome. Candidate goals might be Capture Airport, Retain the Eastern Sector, Provide Forward Logistics Support, or Preserve the Northern Force. These are examples rather than a settled goal catalog.

Each goal needs a desired world state, a target or area, a reason, priority, approved resources, and conditions for success, reconsideration, or abandonment. A goal is not complete merely because every selected operation reported completion.

Capture Airport requires an explicit end condition. Friendly control may be sufficient for one mission; another may require a garrison, usable access, or support capacity. Continued retention can become a standing goal. A directly requested Build Logistics Hub may produce a goal plan with one main operation and the support it needs.

The Commander selects supporting targets and which operations to undertake. Choosing to capture a town, construct a hub, stage a force, or replace Attack with Occupy belongs here. It balances all active goals, reserves, shared support needs, and available resources.

### Operations responsibilities

Operations accepts the selected operation intents, dependencies, and authorized resources. It plans execution details such as routes, formations, group roles, timing, deployment positions, task sequences, and coordination between assigned groups. It schedules execution within the Commander's conditions and uses EntityTasks to carry out individual actions.

Operations reports progress, losses, unmet requirements, changed feasibility, and candidate alternatives. Those reports feed the Commander's decisions about which operations should continue, change, or be added. Operations does not independently choose new campaign targets or add supporting operations outside its authorization.

The distinction is in the scope of the decision: choosing to secure a town to support the airport is a Commander decision; choosing how assigned groups approach and occupy that town is an Operations decision.

### Authority between the layers

The Commander authorizes operation selection and commitments across goals. Personnel records concrete assignments and reservations so several plans cannot promise the same forces. Operations coordinates authorized assignments and requests changes when execution needs them.

Routine execution adjustments within an operation do not need a new Commander decision. Adding an operation, changing its objective or intended outcome, consuming protected reserves, or expanding its resource authorization returns to the Commander.

The Commander may authorize conditional branches in advance, including a local withdrawal response. Operations can execute such a branch under its defined conditions and report the change; the branch is prior Commander authorization, not independent campaign planning. The exact scope of emergency withdrawal and task-level reactions remains open.

Existing hubs, controlled locations, intelligence, and shared support operations may benefit several goals. The Commander tracks those dependencies and consumers; Operations handles the corresponding execution lifecycle. Cancelling one goal must not cancel support still needed by another. Physical assets already built remain world state.

### Capture Airport example

The Commander might select:

| Operation or plan step | Contribution | When it is needed |
| --- | --- | --- |
| Recon airport and relevant approaches | Provide information needed to evaluate and execute the goal. | Required intelligence is missing or stale. |
| Attack or Occupy a selected outlying town | Improve access, reduce a relevant threat, or obtain a needed support location. | The town materially contributes to the goal compared with alternatives. |
| Build Logistics Hub | Provide the required support capacity. | Existing accessible hubs cannot support the planned commitment. |
| Stage and reinforce the assault force | Assemble suitable forces at the required readiness. | The main operation's force conditions are not met. |
| Attack or Occupy the airport | Establish required control. | Preconditions are met and the Commander retains the commitment. |
| Hold and optionally Fortify the airport | Meet retention or handover requirements. | The goal requires continued presence or defense preparation. |

These are conditional choices, not a mandatory sequence. Reconnaissance, logistics preparation, and staging can overlap when resources and prerequisites allow. Operations coordinates their execution; the Commander selects and revises the plan.

If a supporting attack fails, Operations reports the result and may execute an authorized fallback. The Commander decides whether to use another approach, reinforce, defer, or abandon the goal. Failure of one operation need not cancel Capture Airport.

## Proposed objective assessment model

The Commander needs to understand relationships between objectives and the force's current situation. A graph of objectives and relevant connections is a useful foundation, but the graph alone does not choose goals or prove that a supporting operation is necessary.

Separate a reusable objective network from each goal's operation plan. The network describes geographic and capability relationships; the plan describes selected work and its conditions. A network relationship can make an operation useful without making it mandatory.

### Reusable objective network

Use objective records keyed by stable IDs and adjacency lists of typed relationships. Existing indexed locations supply identity, position, extent, and classification. Additional candidate sites, route corridors, or connectors may be included when they matter; a viable support location need not already be an indexed objective.

| Data | Proposed content | Responsibility |
| --- | --- | --- |
| Objective record | ID, location or area, type, relevant geographic features, and potential capabilities. | Indexed world data, extended through Analysis queries where needed. |
| Relationship | Endpoints, relationship type, mobility assumptions, physical measures, provenance, and validity conditions. | Analysis evaluates geographic and physical relationships. |
| Commander assessment | Permitted control information, known threats, confidence and age, available forces, and operational support capabilities. | Intelligence, Personnel, and Logistics supply their authoritative assessments. |
| Goal candidate | Desired change or maintained condition, reasons, expected benefit, estimated cost, uncertainty, and supporting needs. | Commander planning uses those assessments and mission priorities. |
| Goal plan | Selected operations, prerequisite conditions, resource reservations, alternatives, and outcome reports. | Commander owns selection; Operations owns execution records. |

Useful relationships include:

- Access: which objectives or areas are connected by a usable route or corridor, for a specified mobility profile.
- Support reach: which existing or potential hubs could support an objective, given access, transport, range, and capacity.
- Physical influence: which positions or areas could observe or affect an approach, subject to actual equipment and permitted intelligence.
- Staging suitability: which areas offer sufficient room, access, or proximity for a specified force to assemble.

Relationships may be directed and may have several alternatives. Distance is one measure, not proof of access or influence. A town near an airport does not automatically control its approach. A road crossing an area is not automatically unusable because that area is hostile.

An indexed airport or military site indicates potential capabilities. Actual logistics support or other usable capability depends on current assets, staff, resources, and access. Capturing a location must not automatically create services that have not been established.

### Per force assessments

Keep reusable geographic facts separate from information specific to a commander. Intelligence supplies observed or inferred enemy information and its confidence. Personnel supplies available and committed force capabilities. Logistics supplies functional support capacity, stocks, and demand.

Analysis may combine explicitly supplied assessments with geography to evaluate candidate relationships or alternatives. It must not obtain hidden enemy positions on behalf of the Commander. Cached results that depend on intelligence or current capacity must be keyed and invalidated accordingly.

The objective network is a derived planning view. It should reference authoritative records and evidence rather than become a competing source of truth for casualties, inventories, or objective ownership. Relevant evidence should be fresh enough when an operation is authorized to begin.

### Identifying broad goals

Goal candidates arise from mission priorities, deficiencies, and opportunities. Objective type and network position help evaluate them, but do not give every objective an automatic goal.

Candidate generation can consider:

- A strategically valuable objective whose control would advance the mission or enable needed capability.
- Existing holdings whose loss would damage current commitments or sever important access.
- A support shortage affecting several valuable objectives or planned operations.
- An overextended or depleted force whose preservation merits changing commitments.

For each candidate, the Commander evaluates expected benefit, threat, force and supply requirements, uncertainty, prerequisites, and opportunity cost. The value of an airport depends on mission intent and usable capability, not just its type or number of neighbors.

Consider several candidates together. Shared infrastructure may support more than one goal, while the same groups or supplies cannot be committed twice. A support operation may belong to one goal's plan or merit a separate broad goal if its value spans several commitments.

Exact scoring remains open. Begin with explicit mission priorities and transparent assessments rather than treating one geometric score as a complete strategic policy. Reevaluate existing goals alongside new candidates, accounting for current commitments and the cost of changing direction so small score changes do not repeatedly replace useful plans.

### Deriving supporting operations from unmet conditions

For a candidate goal, describe the conditions required for a feasible attempt and the desired final state. Compare them with the current assessment. Each unmet condition suggests possible operations; the Commander chooses among those alternatives.

For Capture Airport, missing information may suggest Recon; insufficient support may suggest using an existing hub, arranging Sustain, or Build Logistics Hub; insufficient ready forces may suggest Reinforce or Stage. A threatened approach may suggest capturing a relevant objective or choosing another route.

Do not store a permanent property such as requiresSupportingOperations on the airport. The necessary work changes with current control, intelligence, force readiness, logistics, the selected approach, and the Commander's constraints.

Plan conditions must express alternatives. Adequate support can come from an existing hub or a new one. Access can come from either of several routes. Requiring all possible supporting operations would create unnecessary expansion.

Analysis can return candidate access or support relationships and their measures. Intelligence explains the threat assessment; Logistics explains the support deficit; Personnel explains force feasibility. The Commander decides whether an operation's contribution justifies its cost.

The selected plan forms a dependency graph of operations and conditions. Check for circular requirements, missing resources, and unsupported assumptions. Limit dependency expansion and candidate exploration. If no feasible plan is found, report the blocking conditions, defer the goal, or seek information or resources rather than generating operations indefinitely.

### Airport and supporting town example

Suppose a town lies on one plausible access route to the airport and contains a suitable site for a hub. The objective network records those relationships and their evidence.

The current assessment may show that friendly forces lack sufficient support near that route and that known opposition around the town makes its use unacceptable under the Commander's policy. This makes taking the town and building a hub a candidate way to enable the airport goal.

A second route and an existing hub may offer another feasible plan. The Commander compares their benefit, resource needs, uncertainty, and delay. It may select the town plan, choose the alternative, or defer the airport goal. Operations then executes the selected work.

The town's relationships explain its potential value. Its current assessment and the specific goal explain whether operations there are actually warranted.

### Initial data and analysis scope

Start with a small objective network containing strategic locations, access relationships, and logistics support relationships. Use stable IDs, HashMaps, and adjacency arrays; the design does not require a graph library.

Begin with one Capture Objective goal evaluator that returns candidate supporting operations and reasons. Keep goal evaluation inside the Commander and reusable relationship calculations inside Analysis. Let Operations report feasibility and execution progress without choosing the broad plan.

Use cheap geographic filtering to shortlist relevant relationships, then evaluate routes or terrain in detail only where a candidate goal needs it. Cache reusable physical results. Refresh affected assessments when control, intelligence, hub availability, force commitments, or relevant physical conditions change, with bounded reconciliation as needed.

A useful first design artifact is one small airport example with alternative approaches and hub options, including the expected goal assessment and selected operations under several ownership and intelligence states. This tests the data model before extending indexing or implementing a general planner.

### Road access and indexing inputs

The agreed approach uses a reusable physical road network, location access attachments, and derived objective relationships. Heavy processing of static road topology and baseline corridors belongs in indexing. Analysis evaluates those relationships against the current situation; Commander chooses goals and supporting operations. Sharing a road does not merge distinct location compounds.

The RoadNetwork experiment already exports compressed topology, connected components, source-road references, and footprint boundary inlets. It remains separate from mission startup and production location indexing. Inlet graph references currently use road-section centers rather than projected crossing offsets. These exports are the foundation for the next preprocessing stage, not yet the complete runtime objective access graph.

#### Nearby road fallback

A cluster without a boundary inlet may use nearby roads through an explicit off-road approach. Remote power infrastructure is a typical case: no road needs to cross the cluster for a nearby road to provide useful access. Keep this attachment distinct from a boundary inlet and preserve several materially different approaches where useful.

Measure the shortest horizontal gap from the road geometry to the saved cluster footprint, not its center. The accepted initial tuning defaults are:

| Road-to-footprint gap | Treatment |
| --- | --- |
| Up to 150 m | Strong nearby-access candidate, subject to approach feasibility. |
| More than 150 m and up to 500 m | Secondary candidate; terrain and force mobility have greater influence. |
| Beyond 500 m | Exclude from automatic nearby-road attachments initially; separately planned off-road access remains possible. |

Indexing should retain useful fallback candidates out to 500 m so runtime policies can prefer shorter approaches without repeating map searches. These thresholds are configurable tuning values, not physical reachability limits. A cluster without an attachment is not necessarily unreachable. Water, steep terrain, fences, and vertical separation may invalidate even a short approach; missing terrain or obstacle evidence must remain explicitly unassessed.

Each fallback attachment should identify the location and road, graph anchor, road departure and footprint approach positions, off-road gap distance, candidate type, and available evidence or uncertainty. A geometric gap is not a validated executable path or confirmed compound entrance. Dataset identity and extraction settings must accompany the references.

#### Accessibility, connection cost, and relevance

Keep three distinct measures:

| Measure | Meaning |
| --- | --- |
| Objective accessibility | How easily forces can reach and support the location. |
| Connection cost | How difficult movement is between two locations through a particular approach. |
| Strategic relevance | How much the location helps or hinders a particular goal. |

An accessibility score can summarize road classes, approach distances, independent routes, and uncertainty. Preserve those underlying measurements and allow mobility-specific assessments: infantry and supply trucks need not receive the same score. Exact score weights remain to be tuned. Main roads generally offer better road access than minor roads or footpaths, but road class alone does not establish usefulness.

Actual network connectivity establishes road links. Geographic distance and high accessibility scores alone cannot establish a connection across disconnected networks. Baseline connection cost combines network travel weighted by road characteristics, off-road approaches at both ends weighted by terrain and mobility, and explicitly represented uncertainty. Keep physical distances separate from policy weights so costs can change without reconstructing topology.

Relevance to Capture Airport depends on whether a town lies on a useful approach or supply corridor, offers staging or logistics support, provides an alternative route, affects a bottleneck, or can influence the approach given terrain and permitted intelligence. Nearby accessible towns are candidates for assessment, not automatic supporting objectives. A remote village 2 km away may be irrelevant unless it contributes to those conditions or contains a relevant known threat. A physical route relationship never creates a permanent capture prerequisite.

#### Additional offline preprocessing

1. Resolve boundary inlets and nearby-road attachments into routing anchors. Project them consistently onto the routing representation, splitting edges or retaining usable offsets as appropriate. Record approximation where physical road chords and strategic center-based geometry differ. Preserve topology at junctions and separate roads at geometric crossings.
2. Associate road corridors with cluster footprints. Record which clusters a corridor enters, traverses, or bypasses, together with source evidence. Passing through a footprint does not imply political control or tactical domination of the route.
3. Build baseline objective access connections with endpoint attachment IDs, network/component references, road and off-road distances, relevant attributes, and reconstructable road-edge references. Begin with a sparse corridor graph retaining necessary junctions. Preserve materially different alternative corridors, including bypasses.
4. Preserve distinct inlets within each cluster. Movement between inlets must follow actual connectivity and incur its cost; collapsing a town into one freely traversable node must not connect unrelated roads or create shortcuts. Nearby-road approaches must not manufacture connections between separate road networks.
5. Export compact runtime adjacency, attributes, costs, and reference lookups. Keep full source geometry and diagnostic provenance in authoring outputs where runtime planning does not need them. Version derived data against road, location, attachment, and preprocessing settings.

A baseline objective-to-objective distance table is an optional optimization if measurement justifies it. Do not require an exhaustive export of full paths and all alternatives. Static topology processing, candidate searches, and baseline relationship construction belong offline; changed threats or blocked bridges still require bounded route evaluation over the compact graph at runtime.

#### Runtime responsibilities and later terrain work

Keep ownership, enemy estimates, route safety, current obstructions, usable logistics services, supplies, and force availability in runtime assessments. Analysis applies these overlays and the requesting force's mobility constraints to indexed relationships. Commander consumes the assessment instead of scanning or rebuilding the raw road network. Operations still needs executable movement paths; the strategic graph does not replace pathfinding.

Reuse existing compound roles, component summaries, and military-building positions. Add coarse elevation, slope, and land/water sampling when needed to improve approach assessment and shortlist staging or logistics sites. The general object scan flattens recorded heights, so terrain elevation requires explicit sampling. Detailed visibility, static weapon placement, and construction suitability remain on-demand analyses with operation-specific constraints. Road access is one relationship type; infantry off-road, air, and sea access can be added separately.

Validate the derived graph with the airport and alternative town approaches, a remote infrastructure cluster using the fallback, a disconnected network, and a cluster whose inlets do not connect internally. Current seed-based location IDs remain dataset-scoped unless stability across reindexing is deliberately implemented.

## Operation catalog

The following operations are reusable ways for Operations to fulfill commander goals. A plan may combine several, and some goals may require only one. An operation still has its own desired outcome and execution state; it is not a synonym for an objective's ownership or threat state.

### Inputs to operation selection

Keep these assessments separate:

- Assessed control: friendly, hostile, neutral, or unknown, with the information available to this commander. An ongoing contest is additional information; it need not erase the previous owner immediately.
- Threat: no identified immediate threat, a credible approaching threat, or an active attack. Intelligence retains confidence and observation age.
- Enemy presence: known or strongly assessed opposition, recently assessed clear with adequate observation coverage, or unresolved. No contact report by itself does not establish that an area is clear.
- Force adequacy: ready forces present, compatible forces already committed and inbound, and the desired force for the objective or operation.
- Strategic value and feasibility: priority, access, sustainment, reserve requirements, and what committing these forces would prevent elsewhere.

These inputs are derived from staff assessments and any ownership information the mission intentionally makes available. Operation selection must not consult hidden enemy state. Friendly allied control should be treated according to the mission's command and ownership policy, rather than automatically marked for takeover.

### Control and information operations

| Operation | Desired outcome | Typical reason to select it | Completion or continuation |
| --- | --- | --- | --- |
| Hold | Retain control and maintain the desired presence and readiness. | Objective is friendly controlled with no identified immediate threat. | Standing operation while the objective remains a commitment; may generate reinforcement or sustainment needs. |
| Defend | Retain or restore effective control while resisting a threat. | A friendly objective faces an active attack or a credible imminent threat. | Continues while the threat requires a defensive response; returns to Hold when the threat is sufficiently resolved. |
| Recon | Obtain the information needed for a commander or planning decision. | Enemy presence, strength, disposition, or an approach is insufficiently known. | Satisfied when the requested information has sufficient coverage, freshness, and confidence, or reports failure to obtain it. |
| Occupy | Establish control and the intended friendly presence in an objective assessed as clear. | Objective is outside friendly control and reliable recent information indicates no opposition requiring a planned attack. | Confirmed control and the specified occupation condition, followed by Hold or Defend as appropriate. |
| Attack | Gain control by overcoming known or strongly assessed opposition. | Opposition must be overcome at a target selected within the approved plan. | Confirmed control under the objective's capture rules, followed by Hold or Defend as appropriate. |

Defend includes preparing for a credible imminent attack so the commander can react before taking fire. A possible threat with weak evidence may instead justify Recon while retaining Hold.

Attack describes an intended outcome even while its operation is preparing or awaiting resources. Execution status records whether the attack is actually underway. Known enemies at a neutral or contested objective may require Attack; an enemy-owned objective recently verified as undefended may instead justify Occupy.

Recon is an information operation. It can be the only active undertaking at an uncertain objective, or support Hold, Defend, Occupy, or Attack. For example, knowing that an enemy garrison exists may justify Attack while still requiring reconnaissance of its strength or approaches. The existence of a recon need does not automatically invalidate the current objective operation.

Occupy still requires movement planning, local security, and confirmation of control. Unexpected resistance prompts reassessment of the intent and resources. It does not automatically authorize an occupation force to launch an unrestricted attack.

### Fortify and Build Logistics Hub

Development operations improve a position or create capabilities needed by the force. They can coexist with Hold and other compatible commitments. Creating a facility or fortification does not itself provide the forces required to hold it.

| Operation | Desired outcome | Typical scope | Completion |
| --- | --- | --- | --- |
| Fortify | Harden a held objective against enemy attacks. | Prepare and man static weapon positions; construct sandbags, razor wire, mines, or other mission-supported defenses. | The specified defensive improvements are in place and any required weapons, crews, and supplies are ready, or unmet requirements are reported. |
| Build Logistics Hub | Make the requested support capabilities available at an existing or newly constructed site. | Activate or adapt a military site, or create a new site providing ammunition replenishment, repair, healing, and other requested support such as fuel. | The required services are operational with their specified access, resources, and staffing; placing structures alone is insufficient. |

Build Logistics Hub is the selected operation name. It can adapt an existing military site or construct a new site. Logistics Hub names the resulting runtime site. Its service set is explicit: a small ammunition point need not also support repair or healing.

For Fortify, Intelligence supplies likely enemy approaches and threat assessments. Analysis evaluates physical position and placement candidates. Operations coordinates the defensive plan, construction, deployment, and manning. Personnel identifies available forces and required roles; Logistics assesses the equipment, supplies, and construction resources needed. The commander approves the plan's overall commitment; Operations schedules Fortify within that commitment and requests approval for changes beyond its limits.

Fortify needs a target plan and resource limits so completion is meaningful. Evaluate existing defenses and request only missing improvements. Hold can continue while assigned construction forces work. If an attack develops, Defend takes priority; unfinished work may pause or be revised while completed defenses remain usable. Later damage or a changed requirement may justify another Fortify operation.

Completed defenses belong to persistent world state, not to the temporary task that built them. Cancelling work releases its task reservations while preserving completed structures and deployed assets. Their ownership, condition, staffing, and supplies affect what capability they provide. Obstacles and mines need runtime records that friendly planning can use. Relevant world changes must invalidate affected physical analysis results.

For Build Logistics Hub, Logistics identifies the required services, service area, demand, capacity, and supply source. Analysis contributes site suitability and access information. Within the commander-approved commitment, Personnel and Operations provide and coordinate the assigned forces, deliveries, setup, and supporting security. Logistics tracks the resulting site's resources and service availability.

An existing location retains its geographic identity while a runtime logistics site records the services established there. A newly created site also needs a runtime record; it can be associated with an existing objective or become an objective if it warrants independent control and defense. It must not require rewriting the authored map index.

Once the hub is operational, Sustain covers continued replenishment and maintenance, while Hold, Defend, and Fortify can cover the site's security and improvement. Running out of ammunition or losing a repair asset can disable the relevant service without deleting the site's identity. Which resources, staff roles, capacities, and construction costs are modeled remains open.

### Reusable Withdraw capability

Withdraw means conduct a controlled retreat from an area while preserving the selected forces. It can be assigned to a group regardless of its current operation or whether it is idle. It does not require that the group currently holds an objective.

Separate the desired outcome from execution:

- The Commander can select Withdraw for specified forces, including replacing a failed Attack or an overmatched Defend. Operations can execute withdrawal behavior under an explicitly authorized fallback policy and report it; adding or replacing a plan operation otherwise returns to the Commander. A local withdrawal does not itself cancel the broader goal.
- Operations coordinates the withdrawal when several groups, destinations, or supporting assets are involved.
- EntityTasks should expose reusable group withdrawal behavior that operations can request. Existing operations must not each reimplement it.

The request identifies the participating group or groups, the area being left, and a fallback destination or criteria for selecting one. The plan also needs the relevant constraints and what to do after regrouping. Detailed routes and coordination remain execution decisions informed by Intelligence and Analysis.

A withdrawal of selected groups does not automatically withdraw every group from their previous operation or relinquish objective ownership. The original operation updates its available force and reports any resulting inability to meet its intent. If the whole operation changes to Withdraw, Operations preserves the participating force and relevant progress while replacing the former intent.

For each withdrawing group, incompatible tasking must be stopped or suspended through the task interface, and execution authority handed over explicitly. A failed attack must not automatically resume when its withdrawal finishes. Resuming any saved work requires an explicit decision that it is still valid. Other groups and unrelated task resources remain intact.

Completion requires reaching the fallback or regroup condition and satisfying the requested withdrawal conditions, including resolving the relevant engagement when required. An issued movement order alone is insufficient. Reports must identify surviving participants, losses, and groups still blocked or missing.

Controlled withdrawal requires cooperation with combat and movement. Current combat pauses can prevent ordinary movement, so this is an explicit interface to design with the combat work. Withdraw must not imply instant disengagement, immunity, or removal of unresolved enemies. The exact standing policy for local withdrawal remains open. Operations should report when a withdrawal makes the broad goal infeasible or requires a larger change in commitment.

### Supporting operations

Supporting operations fulfill needs that may coexist with control or information operations in the same plan.

| Operation | Desired outcome | Relationship to objective operations |
| --- | --- | --- |
| Reinforce | Bring the assigned force or objective up to the required strength and capabilities. | Supports Hold, Defend, Attack, or another committed undertaking. |
| Sustain | Restore or maintain ammunition, fuel, equipment condition, and other modeled supplies. | Logistics identifies needs across both forces and objectives; delivery and repair work support the existing objective operation. |
| Reposition | Redistribute available or surplus forces to meet changed priorities or access requirements. | Can fulfill Reinforce or maintain reserves; unnecessary surplus should not remain committed forever. |
| Relieve | Replace a depleted force while preserving the required objective presence. | Supports Hold or Defend and allows withdrawn forces to recover or reconstitute. |

A supporting need does not imply a new operation for every request. Reinforce might be fulfilled by changing an existing operation's allocation and issuing movement tasks. Transport or sustainment may require coordinated supporting operations. Each entity still has one execution owner at a time, with explicit handoff between operations.

For reinforcement, account for ready compatible forces present and already committed inbound before requesting more. Pending allocation and arrival are distinct from being available elsewhere. Update the same need as assignments, losses, cancellations, or arrival estimates change.

For example, a held objective requiring three comparable groups with one present and one credible inbound commitment has a remaining deficit of one group. If the inbound group is lost or reassigned, the deficit becomes two. Actual adequacy should eventually account for personnel, equipment, readiness, and required roles; group count is only an illustrative starting measure.

### Reserve policy and auxiliary operations

Maintain Reserve keeps a configured amount of useful, ready force available at suitable locations. It gives the commander an explicit reason not to consume every available group on current objective deficits. Reserve allocation and release remain commander decisions, and the desired reserve can vary with priorities and threat.

Withdraw applies across existing operations and group states. Fortify and Build Logistics Hub create lasting capabilities at sites. Reinforce, Sustain, and Maintain Reserve address ongoing resource competition. Reposition and Relieve can initially be expressed as supporting work without requiring separate operation types.

Patrol, transport, escort, assembly, construction, and static weapon placement are initially ways to execute these operations. They can begin as steps within the operation types that need them. Stage can coordinate assembly and readiness across groups before an offensive. Some plans may also justify explicit transport or escort operations when coordination exceeds an individual task.

### Example selections and transitions

| Assessment within an approved goal | Candidate operation response |
| --- | --- |
| Friendly objective, no immediate threat, adequate force | Hold. |
| Held objective with insufficient prepared defenses | Hold with Fortify to achieve a specified defensive plan. |
| Forces need local support capacity that existing sites cannot provide | Build Logistics Hub with an explicit service set, at an existing location or a new site. |
| Friendly objective, no immediate threat, inadequate force | Hold with a Reinforce need. |
| Friendly objective under attack, inadequate force | Defend with a Reinforce need; compare relief or withdrawal against other commitments. |
| Friendly objective, uncertain activity on an approach | Hold or Defend according to credible threat, with Recon to resolve uncertainty. |
| Objective outside friendly control, enemy presence unresolved | Recon if the objective warrants investigation. |
| Objective outside friendly control, recent reliable assessment of no opposition | Occupy if establishing control is worth the commitment. |
| Objective with known opposition that the commander wants to take | Attack, potentially supported by Recon, Reinforce, or Sustain. |
| Occupy or Attack establishes control | Hold if the area is sufficiently secure; Defend if a threat remains. |
| Threat at a defended objective is resolved | Return to Hold after sufficient confirmation. |
| Attack fails or defending forces are being overpowered | Change the intent for the affected forces to Withdraw and coordinate a fallback. |
| Selected groups need to leave while the remaining force continues its operation | Assign Withdraw to those groups and reassess the original operation's remaining capability. |
| Commitment is no longer justified | Withdraw or release the operation, with explicit handling of any assigned forces. |

These are candidate-generation rules for the Commander within a goal. Staff assessments explain needs and feasibility; the Commander selects operations that contribute to the goal and fit its resource commitments. Operations executes the selected work and reports changes. Work can remain uncommitted or wait for resources; there is no requirement to attack every known enemy objective or investigate every unknown one.

Information decays. A stale clear assessment should reopen uncertainty. Changes in operation should use meaningful evidence and retain useful assignments where possible, avoiding repeated Hold/Defend switching or duplicate reinforcement requests on every scan. Operation satisfaction depends on its actual outcome, not just a completed movement waypoint.


## Command scope and alternatives

Start with one commander controlling an explicitly assigned force. A simple mission can create one commander per side. Side affiliation determines allegiance; it does not automatically grant command over every entity on that side. The need for several commanders on one side remains open.

The agreed split places goal selection and the selection of contributing operations in the Commander, with detailed execution in Operations. The Commander's planning implementation can be decomposed into goal evaluators, plan construction, and prioritization functions. Persistent subordinate headquarters remain a separate question about geographic responsibility and autonomy; this split does not require them.

## Proposed responsibilities and authority

| Module | Owns | Main decisions |
| --- | --- | --- |
| Commander | Broad goals, goal plans, selected operations and their dependencies, priorities, reserves, resource commitments | Which outcomes and supporting operations to pursue, which commitments receive resources, and when to revise the plan |
| Personnel | Force roster, availability assessments, assignment and reservation records, replacement needs | Which forces meet a request; commit actual assignments within the commander's authorization |
| Intelligence | Known enemy information, threat assessments, reconnaissance needs | What the commander can infer about the enemy, and what information is missing |
| Operations | Selected operation execution, detailed execution plans, operation registry, progress, spatial reservations | How assigned forces carry out selected operations, how to coordinate their tasks, and what needs a revised Commander decision |
| Logistics | Supply and maintenance requirements across objectives and forces, logistics site requirements and service availability, sustainment proposals | Where support capacity, resupply, repair, replacement equipment, or transport are needed |
| Individual Operation | Intent execution, assigned force roles, coordination phases, task references, progress report | How to approach the target, which assigned group performs each role, when to advance a phase, whether to retry or request assistance |
| EntityTasks | Individual entity task execution and its resources | Movement, boarding, landing, waiting, interruption, completion, failure, and cleanup |
| Analysis | Reusable analytical queries, candidate evaluation, bounded analysis work and caches; terrain analysis initially | Which candidate options satisfy supplied constraints and how they compare on requested measures |
| World state and simulation | Objective state, entity state, virtual movement and combat, spawned execution | How commanded actions and encounters unfold |

Staff modules provide assessments and proposals within their responsibilities. The Commander selects goals and operations and resolves competition. Personnel records committed assignments; Operations coordinates detailed execution. Logistics may propose Build Logistics Hub or resupply, and Intelligence may propose reconnaissance; the Commander decides which work to undertake.

Analysis and simulation support multiple staff modules. They do not allocate forces. Entity and inventory data remain authoritative in simulation; staff assessments derive from that data rather than create competing copies.

Individual operations can respond locally within their intent and assigned forces. Operations coordinates assignments within explicit authorization; changes in selected operations or their commitments return to the Commander unless already authorized by a conditional branch. Individual operations cannot take forces directly from one another. EntityTasks must not select campaign objectives.

## Analysis responsibilities and initial terrain scope

Analysis provides shared queries for the Commander and staff modules. Proposed capabilities include reusable objective relationships as well as physical candidate generation and terrain evaluation. The Commander uses strategic assessments to select goals and operations; Operations uses detailed terrain results to execute them. The queries and examples below describe proposed capabilities within the agreed module.

| Question | Responsible module |
| --- | --- |
| Which candidate positions overlook a specified area, fit the requested footprint, or provide terrain screening? | Analysis |
| Which approaches are plausible for the reported enemy force, and where is reconnaissance needed? | Intelligence using terrain results and its known enemy information |
| Which supporting objectives and broad approach justify the selected operations? | Commander using objective relationships and staff assessments |
| Which detailed routes, group positions, and static weapon locations fulfill a selected operation? | Operations and the individual operation planner |
| Which delivery or staging locations meet supply access requirements? | Logistics using Analysis and path results |

Intelligence owns enemy interpretation and uncertainty. The Commander selects the broad plan and its supporting operations. Operations plans friendly execution within those selected operations, using physical suitability and Intelligence's threat assessment. Logistics applies logistics constraints. Sharing the physical calculations avoids requiring every staff module to implement its own terrain reasoning.

### Query results and mission decisions

The Analysis interface should initially support terrain requests such as finding candidate observation positions, evaluating a weapon position against a specified sector, or measuring screening along candidate routes. Candidate generation and physical evaluation belong inside the module; it should provide more than a collection of low-level geometry helpers.

Inputs should specify the search area, target area or sector, and relevant physical constraints such as observer height, mobility, or equipment footprint. Results should expose candidate positions and meaningful measures such as coverage, screening, slope, clearance, and the limits of the evaluation. These are proposed capabilities, not guarantees of what the current index or engine can provide.

The planner ranks suitable candidates for its mission and selects a coordinated set. A physically valid position is not automatically a good assignment. Analysis does not reserve positions or issue tasks. Operations coordinates reservations across operations, while each operation retains the reservations it owns.

Threat-aware route or position evaluation must consume Intelligence's permitted information. Analysis must not discover actual hostile positions through unrestricted entity queries. Static terrain knowledge and uncertain enemy knowledge remain separate inputs.

### Static weapon placement example

1. Intelligence identifies a likely enemy approach and the confidence in that assessment.
2. A defend operation asks Analysis for positions that could cover the relevant sector with the intended equipment.
3. Analysis returns candidates with physical suitability and coverage measures.
4. The operation selects positions together, considering overlapping coverage, access, known threats, available weapons, and other friendly assignments.
5. Operations coordinates any reservation conflicts, and the operation issues placement, construction, and manning tasks when those capabilities exist. Preparing new defenses can fulfill Fortify alongside the site's Hold operation.
6. Execution validates the selected position against current conditions and reports failure if it is unusable. The operation can then choose an alternative.

The same candidate query can serve reconnaissance with different physical inputs. Intelligence identifies what needs observation; the recon operation selects and occupies a suitable position through the execution framework in Operations.

### Relationship to indexing and paths

The current location index groups classified terrain objects into locations and records positions, sizes, types, compound roles, component summaries, and military-building positions. It does not yet supply road topology, tactical visibility, elevation, or cover measures. Extend or consume indexed data through an agreed interface with the indexing work; terrain analysis is additional functionality.

Cache reusable geographic features and physical results where valid. Keep expensive detailed checks bounded and local to the current query. A coarse search followed by detailed evaluation of a shortlist is a suitable starting approach.

Geometry caches must include the parameters that affect their results and a way to handle relevant world changes. Enemy-dependent assessments remain specific to the force and its current intelligence. Final placement checks account for current obstacles and occupancy; cached candidates are provisional.

Existing Paths remains responsible for generating movement paths. Analysis can evaluate route alternatives or suggest intermediate positions, but physical screening alone does not prove a route is traversable. Operation planners need path feasibility as well as terrain and threat assessments.

For an initial implementation, support a small set of observation or defense position queries around one objective. Expand to broader route analysis as actual planning needs become clear.

## Goal and operation interfaces

The Commander maintains goal plans and supplies Operations with selected operation intents, prerequisite conditions, authorized resources, and constraints. Operations returns execution feasibility, resource requirements, progress, outcomes, and reasons for requesting a revised decision. The Commander should not need to understand individual waypoints or every operation's internal coordination phases.

Within Operations, each operation has a small interface: start or revise intent, grant or withdraw assigned forces, cancel, and report progress or results. Operation types can hide substantial coordinated behavior behind that interface. Detailed schemas and function names remain open.

An operation owns the entity task IDs it creates and consumes their completion, failure, and cancellation results. It may be finite, such as Build Logistics Hub, or standing, such as Hold. Arrival alone does not complete a standing operation.

Goal assessments support the Commander's prioritization and plan construction. Operation reports show whether the selected plan remains feasible and which conditions have changed. Operations handles routine local progress without asking the Commander to replan every goal.

## Force allocation

Keep one authoritative assignment record in Personnel. The Commander authorizes commitments for its selected operations across goals; Operations requests concrete assignments within that authorization. Each controllable group belongs to at most one operation at a time. A group's commanded vehicles and their crews must be treated coherently when allocating resources.

An operation may distribute roles among its assigned groups, but it cannot take another operation's forces directly. Assistance requests return to Operations for resolution within its authorized resources. Changes to operation commitments, competing goals, or protected reserves return to the Commander.

Reassignment requires a defined handoff: cancel or finish the former operation's owned tasks, release its reservations, then grant control to the next operation. Cleanup must not cancel unrelated mission tasks. Completion reports from an old assignment must not release or redirect a newer assignment.

Interruptibility is part of the handoff. Current combat can pause task progress, and a new movement order does not itself guarantee immediate disengagement. Operations need a way to report a delayed or blocked handoff while simulation resolves the current activity.

For the first implementation, exclusive assignments are sufficient. Shared transports, artillery, and other support assets can later use explicit support requests if the gameplay needs them.

## Relationship to current IVCS systems

The existing OPCOM code provides a starting vocabulary for objectives, pending orders, and force assignment. TACOM contains an initial garrison flow. These are implementation references, not constraints on the new structure.

Several command paths still use namespace access for entity and FSM data that now uses HashMaps, and OPCOM startup is disabled. The command layer needs integration work before its current behavior can serve as a working baseline.

EntityTasks already provides task instances, callbacks, cancellation, replacement, and interruption. Operations should use that interface and retain their own task references rather than modify entity queues directly.

Map indexing supplies location data. Runtime objective ownership and capture rules require their own agreed interface. Commander design can proceed with manually created objectives.

Combat supplies encounter progress and losses through an agreed interface. The commander should use the information permitted to its force. Intelligence owns the intelligence policy and preserves the distinction between actual world state and a commander's knowledge.

## Execution and observability

Begin with server-owned command state and bounded updates. The logical layers do not require separate permanent scheduling loops. Planning can run less frequently than operation progress checks, with important changes prompting earlier evaluation.

Useful reports should explain how each operation contributes to its goal, why a plan step is waiting, what resources are assigned, and why allocations changed. Reports should distinguish operation failure from goal infeasibility or insufficient available forces.

Validate the structure through its interfaces: two goals competing for one reserve, a plan reusing an existing hub, a lost prerequisite after an operation completes, a failed attack followed by local Withdraw, cancellation of a plan with shared supporting work, and reassignment followed by a late result from the old task. These cases exercise planning, authority, and lifecycle behavior.

## Decisions to settle next

1. Define the first objective records, relationship types, and staff assessment inputs, using an airport with two possible approaches and support options.
2. Define how the Commander generates and compares goal candidates, including mission priorities, expected value, feasibility, uncertainty, and existing commitments.
3. Define the first Capture Airport goal's success condition and the unmet conditions that can justify supporting operations.
4. Define the selected plan's prerequisite conditions and alternatives, including how existing world state satisfies them and how blocked or circular plans are handled.
5. Define the Commander's operation intents and the execution reports returned by Operations.
6. Define authorized execution adjustments and fallback branches, especially local withdrawal, while preserving Commander ownership of operation selection.
7. Define how Personnel commits assignments and reservations without double booking across concurrent goals.
8. Settle the initial operation catalog and whether retained objectives continue under a revised operation or a new standing operation.
9. Decide whether several commanders on one side or persistent subordinate headquarters are required.
10. Define the first Analysis query needed by goal evaluation and the first detailed terrain query needed by execution.
11. Define Fortify completion targets, construction requirements, and ownership of defenses and crews.
12. Define logistics hub services, supply sources, staffing, capacity, and the initial construction or activation model.
13. Define how mission scripts and player requests supply goals or explicit operation requests through the same authority and assignment rules.

Next, work through the small objective network and its per-force assessments, then derive the Commander's selected operations for Capture Airport under several different conditions.
