# Road network indexing design

Status: isolated Altis prototype implemented through nearby-road fallback, source-constrained routing anchors, corridor relationships, sparse baseline connections and a compact JSON runtime package. Production indexing is unchanged. Arma runtime integration and physical approach assessment remain future work.

The consumer requirements are recorded in [Commander design](commander-design.md#road-access-and-indexing-inputs), under **Road access and indexing inputs**. The experiment implements the offline contract below; engine integration and tactical assessment remain separate consumers.

## Current implementation

The [production road index](../Locations/Indexing/Roads/README.md) contains native extraction, deterministic graph construction, saved Altis data and a browser viewer. Normal map indexing generates adaptive location footprints and settlement-port merging first, then builds all road-dependent data from that saved location file. Indexing remains an offline authoring step, separate from mission startup.

| Capability | Current state |
| --- | --- |
| Road extraction and compressed graph | 33,733 usable sections, 3,785 nodes, 4,031 edges and 60 ordinary-link networks. |
| Boundary inlets | 827 crossings across 218 sites. Dorida has eight. Through-road crossings and close entrances are preserved without sector quotas or a count cap. |
| Sites without inlets | 56 of 60 receive fallback candidates; four have none within 500 m and retain unknown accessibility. |
| Routing references | 1,869 anchors resolved with source-constrained projection or retained junction nodes; 4,842 derived nodes and 5,088 split edges preserve source graph distances. |
| Nearby-road fallback | 1,042 typed candidates: 113 strong and 929 secondary, retaining both tiers. Road departure ASL and unmeasured footprint approach height are distinct. |
| Corridors and runtime objective graph | 11,418 source-corridor relationships, 14,967 precise split-edge relationships and 30,689 baseline connections. Runtime schema 2 is 6.89 MiB including paths; the routing core is 2.16 MiB. Complete adjacency retains alternatives; no objective creates a transit shortcut. |

The current validation report records 97 passing Python checks plus 15 native settlement-port checks, including fallback thresholds, anchor/source consistency, detours, disconnected networks, reconstruction and simulated bridge closure. The offline transform took about 10.0 seconds before export using saved Altis observations. Location refinement was rerun in an isolated Altis dedicated server over the saved 673,914-object inventory; no new terrain extraction was needed.

## Ownership and scope

Indexing exports the physical road network, location geometry references, access attachments and derived baseline corridor/objective connections. Heavy static processing belongs offline. Analysis applies mobility policies and changing runtime conditions to the compact outputs; Commander consumes those assessments and chooses goals and operations. Operations supplies executable movement and completion reporting.

Keep objective accessibility, pairwise connection cost and goal-specific strategic relevance separate. Accessibility can summarize road classes, approach gaps, independent routes and uncertainty, eventually by mobility type; retain those measurements and leave score weights tunable. Count routes as independent only when topology supports that conclusion. Two high accessibility scores plus proximity cannot establish a road connection.

Connection cost combines actual network travel and off-road approaches at both ends. Retain physical road distances, geometric approach gaps and assessed approach-path lengths separately from policy weights and uncertainty penalties. Relevance to an airport goal depends on useful corridors, staging, logistics, alternatives and bottlenecks. A nearby town is not automatically a supporting objective.

Road connectivity must never merge locations or alter their classification. Reuse the existing primary/secondary roles, component summaries and military-building records. Current ownership, intelligence, threats, damaged bridges, obstructions, supplies, active logistics services and available forces belong in runtime overlays.

A route passing a town creates geographic evidence, not a permanent requirement to capture that town. Alternative routes must survive the representation. Infantry off-road, air and sea connections can become separate relationship types later.

## Feasibility and engine limits

A dedicated road scan is feasible using `nearRoads`, which returns road sections around a position. Scan the whole terrain, including disconnected road groups; a flood fill from one starting section is insufficient. Reuse tiling and duplicate suppression concepts from the object scanner, but extract road facts separately. [Bohemia: nearRoads](https://community.bistudio.com/wiki/nearRoads)

`roadsConnectedTo` provides section relationships, but its results can be asymmetric. Its extended form includes pedestrian and otherwise missing sections at additional search cost. Preserve ordinary and extended observations separately. Neither observation direction nor an absent reverse observation establishes a one-way traffic restriction. The Altis prototype admits ordinary links as undirected physical evidence and keeps extended-only links in diagnostics. [Bohemia: roadsConnectedTo](https://community.bistudio.com/wiki/roadsConnectedTo)

`getRoadInfo` documents road type, width, pedestrian classification, ASL endpoints, a bridge flag and other surface information. Large bridges have limited metadata, and small pedestrian bridges may be outside the road network. Preserve unsupported values as unknown; do not interpret an unavailable width as a zero-width barrier or assume all crossings were found. Treat endpoints as section geometry, not proof of an exact navigable centerline. [Bohemia: getRoadInfo](https://community.bistudio.com/wiki/getRoadInfo)

Engine path probes can later provide evidence for a specific vehicle and approach. `calculatePath` can return only an initial segment for long routes, so a callback alone must not mark an approach as successfully traversable. Native drive tests and destination checks remain separate validation. [Bohemia: calculatePath](https://community.bistudio.com/wiki/calculatePath)

The native Altis probe and whole-map extraction are complete. The capture contains 892 HIDE/airport surface records with unavailable endpoint geometry; they remain diagnostic records and are excluded from routing and attachments. These observations do not establish identical behavior on other terrains or engine versions.

## Export contract

Use versioned plain data: the current authoring outputs are JSON, and a future Arma runtime adapter can use serializable HashMaps and compact arrays. Export strings, booleans, finite numbers and arrays; no live engine handles or executable data fields. Runtime graph/component IDs are dataset-scoped references, not engine network IDs. Unsupported values remain absent or explicitly unknown, distinct from false or zero. The experiment exports these records as JSON; the runtime package has its own array schema and source-reference maps.

| Record | Proposed fields and invariants |
| --- | --- |
| Manifest | `schemaVersion`, `datasetId`, `world`, available terrain/addon and engine identity, extractor revision, settings, input/output hashes, coordinate conventions, connectivity policy, geometry/length methods, validation summary and extraction coverage. |
| Raw road section | Dataset-scoped `roadId`, engine/model descriptor where meaningful, observed position and ASL endpoints, available type/width/pedestrian/bridge attributes, per-field availability, and outgoing connection observations. |
| Connection observation | Source/target road IDs, ordinary or extended extraction mode, observed direction, reciprocal status, and any uncertainty. Preserve raw evidence before deriving routing adjacency. |
| Graph node | Dataset-scoped `nodeId`, ASL position or explicitly approximate representative position, reasons for retention (junction, endpoint, bridge boundary, attribute change, loop anchor), connected-network group and source road references. |
| Graph edge | Unique `edgeId`, endpoint node IDs, ordered road references with orientation, section/connector geometry, 2D and 3D lengths with calculation method, retained attributes/ranges, connectivity evidence, and source-to-edge offset mapping. Parallel edges are legal. |
| Location geometry | Exact `locationDatasetId` and location ID, source variant/hash, footprint and geometry quality. Optionally include member/core references and positions in a separate sidecar. |
| Access attachment | Qualified location and source road IDs, kind (`boundary-inlet` or `nearby-road`), road departure ASL point, footprint approach 2D point, optional measured approach ASL point, geometric off-road gap, candidate tier, approach identity, evidence and per-check state. |
| Routing anchor | Attachment ID, source road/connection provenance, retained node or edge/offset, orientation and metric, projected position, projection error/connector measurement and approximation status. Junction alternatives remain explicit. |
| Corridor relationship | Qualified corridor/edge and location IDs, enters/traverses/bypasses relation, boundary intervals or attachment references and evidence. No implied ownership or tactical control. |
| Baseline objective connection | Endpoint attachment IDs, routing anchors, network references, road distances, off-road gaps at both ends, relevant attributes, uncertainty and reconstructable oriented edge/path references. |
| Runtime graph package | Compact adjacency and lengths/attributes, attachment anchors, source lookup references, baseline corridor connections and complete dependency manifest. Heavy geometry and diagnostic provenance remain in authoring sidecars. |

Use road geometry in metres with explicit ASL heights. Existing location/member coordinates are 2D and have zero Z; zero must not be reinterpreted as measured ASL height. Sample terrain or object heights explicitly when a check requires them. Separate bridge deck height from terrain height beneath it.

For attachment distances, retain `footprintGapM` and `straightLineDistanceM` as geometric measurements. `approachPathLengthM` is numeric only when an approach path was actually assessed, alongside its method; the prototype uses null for unassessed fallbacks. A zero footprint gap does not prove an entrance exists or that the road surface is at the location's level.

Resolve attachments into usable anchors offline. Retained edge offsets or derived edge splits are both acceptable; the compact representation must let runtime queries use them without scanning source roads. Distances between attachments on the same edge use the declared metric and offsets, not the whole edge length.

Current `graphRefs` identify source section centres. They must not be relabelled as exact physical crossing offsets. Resolve an attachment using its source road/ordinary-connection provenance and all valid incident graph choices, record the projection method and discrepancy, and preserve junction topology. Choosing the globally nearest graph line could attach a bridge to an unconnected road beneath it. Any geometry-to-anchor connector remains a separate approximation rather than silently adding traversable distance or topology.

## Topology policy

1. Enumerate all road sections, collect attributes, then collect links. Complete references to connected sections outside an initial scan tile; reject unexplained dangling IDs in the final dataset.
2. Never create a routing connection solely because roads are near each other or their projected geometry intersects. An overpass can cross another road without connecting. Preserve distinct sections at the same XY coordinates and their heights.
3. Keep the raw directed engine observations. The proposed strategic graph describes potential physical connectivity, with reciprocal, one-sided and extended-only evidence classes. It must not interpret raw observation direction as legal travel direction. The prototype admits ordinary observations and excludes extended-only links from default routes; uncertain links remain available for diagnostics and explicit consumer policies.
4. Compute connected-network groups under a named adjacency policy. A group ID is meaningful only with that policy. Emit uncertainty counts rather than silently joining gaps using nearest neighbours.
5. Condense only uninterrupted degree-two chains whose attributes and evidence permit it. Retain junctions, dead ends, bridge transitions, meaningful class/width/pedestrian changes and uncertainty boundaries. Preserve original road order, geometry, length and reverse mappings.
6. Preserve disconnected components, isolated sections, parallel routes, loops and junction-to-junction alternatives. A closed cycle with no natural junction needs deterministic anchors; it must not disappear or collapse into an unsupported self-loop. A pair of nodes may have more than one edge.
7. Keep geometry uncertainty visible. If the location of a junction or a connector between sections must be approximated, label the method and do not claim centimetre-accurate road length. Do not hide a discontinuity by drawing a straight traversable connector without qualifying its evidence.

The central compression check is preservation of reachability and route lengths under the same accepted adjacency policy. Compression must not discard a bypass or create a new path across disconnected roads. Retain source mappings so runtime damage to a source bridge/section can affect all relevant derived edges.

## Boundary inlets and nearby road fallback

Boundary inlets represent outside-to-inside transitions through the saved footprint. Retain every distinct crossing, including both ends of through-roads. Do not apply sector quotas or broad spacing rules to genuine inlets. Existing detection uses observed section chords and explicitly labelled interpolation across ordinary-connected section gaps; it never promotes extended-only evidence.

For a cluster with no boundary inlet, add `nearby-road` candidates with an explicit off-road approach. Measure the shortest horizontal distance between road geometry and the cluster footprint, not its centroid.

| Configurable initial gap threshold | Candidate treatment |
| --- | --- |
| 0 through 150 m, inclusive | Strong nearby-road candidate, subject to approach feasibility. |
| More than 150 m through 500 m, inclusive | Secondary candidate, retained for terrain- and mobility-dependent choices. |
| Beyond 500 m | Excluded from automatic nearby-road attachment generation initially. This does not declare the cluster unreachable. |

The offline search must retain useful approaches out to 500 m even when a strong candidate exists. Runtime policies can then prefer short approaches without repeating map searches. Deduplicate repeated samples of one approach using corridor topology, departure geometry and attributes while preserving materially different routes and road groups. A shared island-wide component or a similar compass bearing alone does not make two approaches redundant. Any fallback candidate budget must be configurable and report discarded coverage; it must not limit boundary inlets.

Record the location/road references, routing anchor, road departure position, footprint approach position, geometric off-road gap, kind, tier and evidence. A zero gap can also describe a road wholly inside the footprint; retain that distinction rather than claiming an external inlet. Geometry, routing-anchor resolution and mobility assessment are separate states.

Water, slope, fences and vertical separation can invalidate even a short approach. Record per-check outcomes and the measured endpoints/method. Missing checks remain unassessed; a strong distance tier does not imply confidence in vehicle traversal. A straight-line geometric gap is not an assessed approach-path length. A path probe must reach its destination before it supports traversal, and its result is scoped to the tested mobility type.

A site with no acceptable candidate keeps an explicit no-attachment result and search/assessment coverage. Separately planned off-road, air or sea access remains possible. Wind-turbine-area infrastructure is a use case for this fallback; it does not change object classification or restore turbines as power-site contributors.

## Offline corridors and objective connections

After routing anchors are resolved, associate corridors with the saved cluster footprints. Record entry, traversal and bypass evidence with source edges and attachment references. Distinguish a geometric intersection from a corridor that actually connects useful approaches. Footprint overlap does not establish control of the road, tactical influence or a capture prerequisite.

Build a sparse baseline corridor graph retaining required junctions, attachment anchors and materially different alternatives or bypasses. Store enough oriented edge references to reconstruct a selected route without exporting every full path and all alternatives. An optional baseline objective distance table is a measured optimization, not a required all-pairs artifact.

Each baseline objective connection identifies its endpoint attachments and networks, actual road travel lengths, off-road approach gaps at both ends, useful road/bridge attributes and uncertainty. Keep physical quantities separate from mobility/terrain cost weights. Disconnected road components do not gain a road path merely because their attachments belong to nearby objectives.

Preserve distinct inlets within each cluster and the actual connectivity/cost between them. A cluster is not a zero-cost transit node. Multiple fallback attachments must not create an implicit road connection through the objective. If inlets connect only through an external road detour, record that actual detour rather than an assumed internal transfer; mark an internal movement connection only when its evidence supports it.

Export a compact runtime package containing adjacency, distance/cost inputs, attributes, attachment/corridor references and source mappings for updates such as bridge closures. Keep detailed section geometry and provenance in authoring outputs when runtime consumers do not need them. Measure package size and representative query/build times before adding optional precomputed tables.

Analysis may perform bounded searches on this compact graph when mobility, threats, control or bridge/blockage state changes. Commander selects goals and operations from assessments and must not scan or rebuild raw road topology. Operations still uses executable pathfinding. Detailed tactical LOS and weapon placement remain on demand.

## Relationship to existing location data

Production indexing exports circles as `position` and `size`. The adaptive-footprint experiment additionally exports an explicit circle/rotated rectangle and keeps `size` as a broad enclosing radius. Road indexing should accept a chosen location snapshot as input, normalizing its shape without importing experimental functions into production.

Use explicit footprints when supplied. Legacy circles are acceptable broad search regions, marked as coarse geometry. Footprints describe site extent, not fences, entrances or guaranteed traversable ground.

Current `components` rows contain original IDs, types and counts, not full component geometry. `militaryBuildings` supplies useful positions for that subset only. General member references are deleted during refinement; they cannot be recovered exactly from the saved location records or aggregate model counts.

If access quality requires full compound/core geometry, add an optional authoring sidecar before member indices are discarded. Key members by the exact inventory dataset and record reference; keep core/support membership separate from radius-derived secondary annotations. This avoids using a runway annotation as if it were a building entrance. Export the useful classified members, not every vegetation object, and measure the storage cost before enabling this by default.

This sidecar would be a future indexing change requiring its own review. The roadway prototype can begin with the saved footprints and existing military positions, reporting that limitation. It must not silently reconstruct claimed membership by testing whether arbitrary inventory points fall inside a circle.

## Dataset identity and cache invalidation

Existing location IDs contain category seed indices. They are stable references within their exported snapshot; they are not promised to survive changed inputs, settings or reindexing.

Assign a road dataset ID from canonical extraction inputs, settings and output content. Assign a separate location dataset identity from its source inventory, settings, algorithm/variant and exported content. An attachment dataset depends on both datasets, geometry choice, attachment algorithm and settings. Exclude generation timestamps from content identity; keep them as descriptive metadata.

Qualified references are `(datasetId, localId)`. Do not persist engine handles or rely on engine enumeration order. Sort normalized records deterministically; retain distinct co-located sections instead of deduplicating solely by rounded XY position. Identical-descriptor ambiguity must be detected and reported rather than silently aliasing objects. Stability across independently changed datasets is a separate migration problem.

Version routing-anchor, corridor and baseline objective/runtime artifacts against the road, location and attachment dataset IDs plus preprocessing algorithm/settings identities and length/projection methods. Anchor or footprint changes invalidate dependent relationships. Tuning runtime cost weights does not rewrite physical road topology.

Analysis cache keys should include those derived dataset IDs, selected endpoint attachments, mobility/query policy, and relevant runtime overlay revisions. Rebuilding location footprints can invalidate access attachments without re-extracting unchanged road topology. Runtime obstruction or bridge damage invalidates affected corridor assessments without rewriting the authored baseline.

## Module interface

Keep acquisition separate from transformation. A native extraction adapter returns plain road observations. A road-indexing module transforms those observations and a location-geometry snapshot into the graph, candidate attachments and diagnostics. Callers should not reproduce section deduplication, connection normalization, graph compression or access ranking.

The transformation interface follows the dependency sequence:

- Build a reusable road graph from recorded observations and extraction settings.
- Build typed boundary/fallback attachments from the graph and chosen location snapshot.
- Resolve anchors, associate corridors and derive sparse baseline objective connections from those versioned inputs.
- Validate/export the authoring records and compact runtime package with manifests and diagnostics.

Native extraction and recorded fixtures feed the same transformation interface. Native commands stay in acquisition/assessment adapters; graph and baseline relationship transformations remain deterministic and testable without a running mission. Analysis owns runtime queries and costs. Optional distance tables require a measured benefit and must not discard alternative corridors.

## Implemented offline stages

Continue inside the isolated RoadNetwork experiment. Production indexing and AdaptiveFootprints remain independently reviewable.

| Order | Work | Completion criterion |
| --- | --- | --- |
| 1 | Nearby-road fallback | Typed off-road candidates for no-inlet sites, configurable 150/500 m tiers, useful alternatives, explicit coverage and uncertainty. Existing boundary inlets remain intact. |
| 2 | Routing anchors | Both attachment kinds map consistently to node/edge offsets or splits with source provenance, metric and approximation recorded. Junction choices and same-edge distances are correct. |
| 3 | Corridor relationships | Entry, traversal and bypass evidence links corridors to footprints without implying control. |
| 4 | Baseline objective connections | Sparse connections retain real connectivity, physical distances and reconstructable alternatives; distinct inlets never become a free transit shortcut. |
| 5 | Compact runtime export | Versioned adjacency/attributes/references support bounded Analysis searches and targeted updates without raw-map scans. |

## Validation cases

The Python suite now has 97 checks, plus 15 native settlement-port checks. Snapshot invariants distinguish intentionally changed footprints from unchanged road topology. The following cases guide validation. Airport/town route alternatives and bridge closures currently use synthetic topology fixtures; saved Altis roads and all baseline path references are validated separately. These checks do not establish vehicle traversal.

- Airport and town: retain a useful route through the town and a bypass; changing town relevance or closing a bridge must not erase a valid alternative.
- Remote infrastructure: no boundary inlet, several candidate road departures, correct footprint gap, explicit off-road segments and strong/secondary tiers. A nearby road across water or at the wrong height cannot be labelled assessed usable without supporting checks.
- Thresholds: 150 m is strong, just above 150 m is secondary, 500 m is included, and beyond 500 m is excluded from automatic fallback only. Preserve useful secondary approaches even when a strong one exists.
- Disconnected networks: close objectives with good road classes or fallback attachments still have no cross-component road connection.
- Internally disconnected cluster: keep its distinct inlets and prohibit a zero-cost transfer. If an external detour exists, preserve its real route and cost.
- Anchor geometry: same-edge attachments, junctions, ordinary-link interpolation and co-located overpasses retain correct ordering, alternatives and approximation evidence.
- Dependency changes: modified footprints, attachments, anchor settings or corridor settings invalidate the affected derived outputs; runtime policy changes leave physical measurements intact.

Existing foundation invariants also apply:

- Every exported reference resolves; serializing and reloading preserves facts, evidence and geometry.
- Whole-map scanning finds disconnected road groups; duplicate tile hits do not duplicate sections, while co-located unconnected sections remain distinct.
- Ordinary, one-sided and extended connection cases have documented handling; no automatic link appears at an unconnected crossing.
- Chain compression preserves reachability, source coverage and the chosen length metric, including a ring, parallel bypass, junction and isolated section fixtures.
- Bridges retain source references and attribute availability; missing bridge width is unknown. A runtime simulated closure removes only affected routes and leaves a valid bypass available if one exists.
- Airport/town attachment candidates span different approaches without changing their cluster membership. A fence, water gap, unmatched elevation or missing entrance cannot be advertised as validated vehicle access.
- Selecting a different location geometry snapshot invalidates its attachments while allowing reuse of the unchanged road graph.
- Preview colours distinguish road groups and evidence; labels expose unresolved links and unassessed attachments. Report section/node/edge counts, compression, uncertain links, candidate coverage, export size and build time.

Repeat native extraction probes when source terrain or engine behavior changes; use saved Altis observations for the current attachment/preprocessing work. Detailed LOS, static weapon placement and construction suitability remain demand-driven. Coarse water/slope/height assessment can be added offline when needed to qualify approaches.

## Concrete preprocessing policy

`fallback.py` selects the closest approach on each contiguous corridor/tier run, preserving local distance minima at least 150 m apart along a curved corridor. Flat plateaus contribute one sample. This reduces repeated section samples without combining independent corridors by compass sector or island-wide component.

`preprocess.py` projects departures only onto source-adjacent ordinary links. A retained source junction remains a node with all incident choices. Interpolated inlets use their observed source pair. `routing-graph.json` contains derived splits; neither those splits nor attachments add new topology. Approximation connectors remain separate distance fields.

Baseline connections record reached attachments and continue past fallback-only nodes. Expansion stops at non-origin genuine boundary-inlet nodes, including mixed nodes carrying both kinds. Origin nodes always expand. Actual oriented edge paths and same-site detours remain intact. This table is a reference, not an exhaustive alternative-route cache. `runtime.json` retains the complete split graph, necessary junctions and source mappings so bounded queries can find longer alternatives and apply closures. `runtime_query.py` demonstrates this without raw-map scans. Off-road gaps remain endpoint costs only and never connect road components.

Accessibility outputs contain measurements, not a fixed score or claims of independent routes. All 278 locations remain represented, including the four with no automatic candidate. Authoring sidecars retain geometry and evidence; the runtime package omits heavy geometry. See the experiment README for file names, controls and rebuild commands.

## Runtime geographic precision and execution lookup

The current export uses preprocessing version `strategic-access-3`, manifest schema 4 and runtime schema 2. Source-corridor overlap alone cannot establish overlap on a shorter routing edge. Authoring output `routing-corridors.json` clips source inside intervals to each split edge, preserving disjoint intervals and measuring gaps on that edge's geometry. Runtime corridor rows address the split edge and retain local 3D interior intervals, with `corridorsByEdge` for direct lookup. Query output reverses interval offsets with travel direction and separates true interior overlap from nearby-outside evidence.

The previous schema-2 correction resolved 824 Altis edge/location combinations where joining solely by source edge could overstate overlap. For example, `d000000` ends at source offset 889.284 m, before the `altis_town_267` interval at 986.565–1264.108 m. Its new relationship has empty interior intervals and an 84.988 m gap. All runtime intervals are checked against the full authoring intervals. Road topology and its metric remain unchanged. The later settlement-port rebuild changes location/attachment identities and regenerates dependent artifacts; baseline connections also reflect the revised stopping policy.

The compact package includes `attachmentGeometry`, aligned with attachments, containing road departure ASL, projected anchor ASL and footprint approach XY with unknown elevation and unassessed traversal status. `attachmentIndexById`, `locationIndexById` and `attachmentsByLocation` support execution handoff and per-site shortlisting without raw-road loads or global candidate scans. All alternatives remain present, including the site with 76 fallback candidates; mobility/threat filtering remains an Analysis decision. The reference query rejects schema 1 rather than silently interpreting source-edge indices as routing-edge indices.

## Fallback traversal and settlement ports

A nearby-road attachment is an endpoint access option, not an intervening objective or evidence that its site controls the road. Baseline search records its endpoint connection and continues along the same physical network. `baselineNodeKinds` distinguishes fallback-only nodes from boundary-inlet and mixed nodes. Only boundary-inlet/mixed nodes stop non-origin expansion. Full-network Analysis queries can still cross genuine objectives when policy calls for it; strategic relevance is not part of indexing.

The actual Altis baseline now includes Dorida–Chalkeia, Dorida–Power/Dorida and Chalkeia–Power/Dorida. The shortest direct town-to-town baseline road distance is 1,273.095 m. Off-road and approximation-connector costs apply only to the selected endpoints, never to intermediate fallbacks. No shared site supplies free transit between anchors or joins disconnected components.

The RoadNetwork location authoring adapter lifts the 20-object port cap only for settlements, keeping original-core distance and shape eligibility unchanged. Three large port clusters are absorbed near Kavala, Neochori and Pyrgos; all 503 port objects/roles remain represented and 19 ports remain independent. The input, footprints and every dependent road artifact are regenerated. See the RoadNetwork README and `location-comparison.json` for the exact ownership changes and secondary-site effects. Production indexing, AdaptiveFootprints and the separate ObjectiveGraph experiment are unchanged.
