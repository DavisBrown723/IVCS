> Promoted into normal map indexing on 2026-10-14. Use [Locations/Indexing](../../Locations/Indexing/README.md). This directory preserves the experimental implementation and saved comparison data; it is no longer the production build path.

# Road network experiment

This prototype lives entirely in `IVCS/Experiments/RoadNetwork`. It is not registered in mission startup. Its 278 sites now come from the isolated `Locations/` authoring adapter, based on AdaptiveFootprints with extended settlement-port absorption; see `inputs/source.json`. Production indexing, the original AdaptiveFootprints experiment and ObjectiveGraph are unchanged. Road extraction, topology, access candidates and browser assets have their own namespace and outputs.

## View the saved result

Double-click **Open map.cmd**, or run `.\start-map.ps1`. Open **http://127.0.0.1:8767**. Python 3.9+ is required (already installed here); Arma is not launched. The launcher reuses this viewer if already running and otherwise starts a hidden, loopback-only server. Use `.\stop-map.ps1` to stop it, or `-Port 8768` on both scripts if the default port is occupied.

Scroll to zoom; drag to pan. Use Airport, Athira, Kavala, Bridge, Dorida inlets, Dorida fallback or Whole island. Dorida inlets selects the town and numbers its eight perimeter crossings. Click a numbered marker or its sidebar button, then Zoom to inlet for a close view. Search town names, location IDs, road IDs (for example `r015377`), or `14000,18710` world coordinates. Click a road to inspect its evidence or highlight its connected network. Click a site marker to show its numbered attachments. Dorida fallback selects a nearby power site with a 36 m strong approach and secondary approaches. Select a baseline road connection in the sidebar to draw its road path; Frame connection includes both endpoints. Teal is road travel; dashed approach lines are unassessed off-road gaps. Layers include road classes, connected networks, junctions/dead ends, bridges, diagnostic extended connections and saved location footprints. The URL fragment preserves the viewed position and zoom.

The detailed topographic basemap loads tiles from [Arma3Map](https://jetelain.github.io/Arma3Map/altis.html) (terrain copyright Bohemia Interactive). High-detail tiles require internet access. A bundled 1696-pixel island overview remains available offline, with the full local road overlay. Maximum native detail is zoom 6; zooms 7-9 enlarge those tiles. All graph data and Leaflet assets stay local; the server exposes only the viewer directory. No map data is uploaded.

## Current Altis snapshot

- 34,625 native sections returned; 33,733 with usable endpoint geometry, approximately 732.3 km of endpoint chords.
- 892 HIDE/airport surface objects have unavailable endpoints. They remain in diagnostics and are excluded from routing and access candidates.
- 33,979 ordinary links, 1,412 additional extended-only pairs kept as diagnostics.
- 3,785 retained section-centre nodes, 4,031 compressed edges, 60 connected networks.
- 1,016 junction sections, 562 dead-end sections, 40 bridge sections (not necessarily 40 distinct bridges).
- 827 boundary inlets across 218 of 278 sites, including Dorida's eight. Three crossings use ordinary-link gap interpolation. No inlet cap or sector quota is applied.
- 1,042 fallback approaches at 56 of the remaining 60 sites: 113 strong and 929 secondary. Four sites have no candidate within 500 m; they remain in the export with unknown accessibility.
- 1,869 resolved routing anchors; 4,842 routing nodes and 5,088 split edges.
- 11,418 source-corridor relationships, 14,967 precise split-edge geographic relationships and 30,689 baseline attachment connections.
- Runtime schema 2 package: 7,224,671 bytes (6.89 MiB), including the expanded baseline path catalogue. The routing core without that catalogue is 2,265,294 bytes (2.16 MiB). Road preprocessing took about 10.0 seconds before export.

## Rebuild without an LLM

Run `.\run.ps1` to rebuild from the promoted `inputs/altis-locations.sqf` and `output/altis/capture.json`, then run validation. This does not launch Arma. Use `.\run.ps1 -RebuildLocations` to run native settlement-port tests, rebuild locations from the saved 673,914-object Altis inventory, validate/promote the new input, and rebuild every road-dependent output. This launches a hidden isolated dedicated server for the location transform and water checks; it does not rescan terrain. Run `.\run.ps1 -Rescan` only when a fresh native terrain extraction is needed. That authoring step uses the existing isolated Altis test harness, the installed dedicated server and Arma Tools FileBank; it takes several minutes and retains its temporary RPT for diagnostics. Native engine references are converted to capture IDs before export.

Alternatively: `python index.py --rpt PATH_TO_COMPLETED_RPT --locations PATH_TO_SAVED_LOCATIONS`, then `python -m unittest discover -s tests -p 'test_*.py' -v`. The extraction and graph algorithm use the active terrain and do not depend on an LLM or hand-edited coordinates. This prototype's launcher, output folder, basemap calibration and regression fixture are Altis-specific. Another terrain needs a matching native extraction mission, location data and correctly georeferenced basemap; it is not yet a one-command terrain selector.

## Data and boundaries

1. `extract.sqf` observes native `nearRoads`, ordinary/extended `roadsConnectedTo` and `getRoadInfo`. Output is a chunked RPT stream.
2. `index.py` creates stable per-snapshot road IDs, an undirected physical graph, connected components, compressed chains. The pure `access.py` module identifies boundary inlets, `fallback.py` adds typed off-road candidates, and `preprocess.py` resolves routing anchors, corridors, baseline connections and compact runtime data.
3. `viewer/` reads a compact display projection of those outputs. Full-precision JSON remains under `output/altis/`.

`roads.json` preserves section endpoints, source positions, ASL deck heights, ordinary and extended observations, attributes and graph references. `graph.json` stores nodes, edges, components and connection evidence. `locations.json` is the regenerated location snapshot; `location-comparison.json` records absorption changes against the preserved pre-change snapshot. `attachments.json` links sites to nearby road sections; `access-coverage.json` records inlet counts, interpolation evidence and sites with nearby roads but no boundary crossing. `manifest.json` identifies schema, source engine, settings, methods and SHA-256 dataset dependencies. The new authoring outputs are `routing-anchors.json`, `routing-graph.json`, `corridors.json`, `routing-corridors.json`, `objective-connections.json` and `accessibility.json`. `runtime.json` contains compact adjacency, physical distances, attributes, attachment references, baseline connections and accessibility measurements for all 278 sites.

Graph nodes are retained road-section centres. Edges preserve distances and reachability in the original centre-to-centre graph; they are not exact lane geometry or guaranteed vehicle routes. Ordinary observations are treated as undirected potential physical links. An asymmetric observation is not interpreted as a one-way restriction. Geometric crossings alone do not add connections, and extended-only links are not promoted into routes. Bridge metadata can omit width.

Access version **boundary-inlets-1** intersects every observed road-section chord with the saved circle or rotated rectangle. A crossing requires road geometry on both the outside and inside. A through-road contributes two inlets, even when both endpoints are outside. Roads entirely inside, nearby parallel roads and tangencies do not create inlets.

Only coincident contacts (within 5 cm horizontally and 50 cm vertically) supported by the same road or an ordinary engine connection are combined. Nearby independent roads remain separate, including roads belonging to the same island-wide network. There is no compass-sector quota, 65 m spacing rule or 12-inlet cap. Gaps between ordinary-connected sections use a closest-chord connector and are labelled as interpolation; extended-only evidence never creates these connectors.

Each attachment includes the boundary position, all contributing road IDs, source segment parameters, interior/exterior samples, inward orientation and graph references. Marker numbers run clockwise for each site. The legacy `graphRefs` still refer to source section centres. The matching record in `routing-anchors.json` resolves each physical departure onto a source-supported node or edge offset. Projection is restricted to ordinary links adjacent to the source section, or the source pair for interpolated crossings. Junction attachments retain the junction node and all branches. The derived graph splits edges at those offsets without changing source graph distances. Projection errors and geometry-to-anchor connector lengths remain explicit approximations. Inlet records remain candidates for physical entrance/vehicle access; gates, fences, slopes, water and vertical separation from the site are unassessed. No saved footprint or road is changed.

Fallback version **nearby-approaches-1** runs only for sites without boundary inlets. It measures the shortest horizontal road-chord-to-footprint gap. Up to 150 m inclusive is strong; more than 150 m through 500 m inclusive is secondary. Both tiers are retained. Selection uses contiguous runs on compressed corridors, divided by tier and coverage, with distinct local closest approaches along curved corridors. Flat distance plateaus contribute one sample. Junctions, attribute changes and separate networks retain alternatives; there is no island-component or compass-sector quota. These candidates are deliberately conservative and may still need feasibility filtering.

Configure thresholds with `python index.py --strong-gap 150 --maximum-gap 500`. Additional selection settings live in `FALLBACK_SETTINGS`. Departures retain measured road ASL; footprint approaches are 2D with unknown height. A zero gap can mean an internal road without an exterior inlet. `approachPathLengthM: null` means no approach path was assessed. No terrain-water, slope, fence or vehicle test is inferred from distance.

Preprocessing version **strategic-access-3** supplies geographic corridor relationships (`enters`, `traverses`, `within`, `bypasses`). The full source-corridor records remain in `corridors.json`. `routing-corridors.json` clips their interior intervals to each split routing edge and recomputes the nearest footprint gap on that portion. Runtime consumers join geographic records by split edge index, never by source edge alone. Interior intervals are distances from the split edge's from-node along its 3D centreline. Empty intervals, including boundary-only contact, do not count as interior overlap. These measurements describe approximate graph geometry relative to the saved footprint. A bypass relationship means a nearby corridor stays outside that footprint; it does not establish tactical utility, control or a complete alternative journey.

Baseline discovery records connections to every reached attachment, then continues along physical road edges past **fallback-only** nodes. A non-origin node with any genuine boundary inlet stops expansion, including a **mixed** node with both an inlet and a fallback. The origin always expands. `baselineNodeKinds` exposes these distinctions without changing the existing node/edge array layouts. They include paths between inlets of the same site with their actual costs. Every record includes endpoint attachment IDs, network identity, oriented split-edge references, road distance, two off-road gaps and two anchor connectors. The table is bounded by genuine inlet nodes, not an exhaustive list of objective pairs or alternative paths. It grows from 3,780 to 30,689 records because fallbacks no longer hide farther endpoints; useful alternatives are not capped to recover the old file size. Intermediate fallback gaps and connector costs are never added to a road path: only its two selected endpoints contribute approach costs. Dorida–Chalkeia now has two direct baseline attachment routes, with the shortest road distance 1,273.095 m. Dorida–Power/Dorida and Chalkeia–Power/Dorida also remain present. The complete routing adjacency preserves junctions, parallel paths and bypasses for queries. **Never merge attachments into a free objective transit node**, and never use off-road fallback lines to join road components.

`accessibility.json` reports road classes, component IDs, counts and gap measurements independently of connection costs. Independent-route counts and goal-relevance scores remain unknown rather than invented. Current ownership, threat, vehicle policy, destruction and bridge availability are runtime inputs.

`runtime_query.py` demonstrates bounded searches against only `runtime.json`. It supports source-edge closures, bridge-section closures, road-class weights and off-road weights, keeping physical distances separate from policy cost. For example:

```powershell
python runtime_query.py altis_power_1145-nearby-002 altis_town_5090-inlet-003
```

The prototype supplies JSON and a reference query implementation; an Arma loader, Analysis/Commander integration, approach feasibility and executable vehicle movement remain future work. The viewer draws saved baseline routes, not tactical navigation.

Previous versions remain under `baseline/nearby-access-v1`, `baseline/boundary-inlets-v1`, `baseline/runtime-v1` and `baseline/nonstopping-fallbacks-before`. Road identity is unchanged. Location, attachment, preprocessing and runtime identities were regenerated. The location variant is `adaptive-footprints-settlement-ports-v2` (index version 7); preprocessing is `strategic-access-3`. Manifest schema 4 and runtime schema 2 remain compatible; the new node-kind lookup is additive. Derived identities include road/location/attachment dependencies, preprocessing settings and the metric. Runtime cost changes do not rewrite physical datasets.

## Settlement-port location variant

`Locations/` reuses the existing AdaptiveFootprints classifier, geometry and builder with isolated settings/refinement overrides, active only inside the authoring mission. The earlier rule already admitted ports of up to 20 objects into towns. The new per-primary override removes that count cap for settlement-owned ports; military port support retains its 20-object limit. Eligibility still uses the original core: nearest member within 100 m, every child member within 250 m, and all members within the 100 m margin of an original rectangular footprint. Merging a child never grows later eligibility. Coastal checks and the small-pier exclusion remain intact.

The new Altis snapshot absorbs `altis_port_38` into `altis_town_23` near Kavala, `altis_port_195` into `altis_town_3310` near Neochori, and `altis_port_291` into `altis_town_4303` near Pyrgos. Their 67, 50 and 82 port members, port roles and source components remain represented. All 503 port objects are retained across the map; 19 ports remain standalone. Town member counts and footprints are rebuilt from the merged objects, not hidden in the viewer.

Support ownership runs before general compound consolidation, as before. One former port military companion (`altis_base_220`, four military objects plus one power object) now survives as an independent base. Two single-object power components formerly absorbed by port compounds no longer qualify as standalone power sites under the existing two-object minimum; both remain in the source inventory/catalog. These effects account for 278 final sites rather than simply subtracting three from 280.

The generated native source is `Locations/output/altis/locations.sqf`, promoted to `inputs/altis-locations.sqf`. `inputs/source.json` records inventory, source hashes and successful native RPT provenance. `Locations/promote.py` checks the output variant, CRLF, unique settlement ownership of removed ports and unchanged total port evidence before promotion. Production and original AdaptiveFootprints outputs are read-only inputs to this experiment.

## Runtime schema 2 integration

Schema 1 discarded corridor intervals and associated locations with entire source edges. It must not be interpreted as schema 2. `runtime_query.py` rejects old packages explicitly. In the saved correction example, `d000000` ends at source offset 889.284 m while `altis_town_267` begins at 986.565 m. The new row has no interior interval and reports an 84.988 m nearby gap. Positive overlap survives on the later split edge.

| Runtime field | Contract |
| --- | --- |
| `corridors` | `[locationIndex, routingEdgeIndex, relation, gapM, insideIntervalsM]`. The edge index addresses `edges`, not `sourceEdgeIds`. Intervals are local 3D offsets in the edge's from-to direction. |
| `corridorsByEdge` | Direct edge-index lookup of corridor row indices. `route_geography` consumes only rows belonging to traversed edges and reverses offsets when travel direction is reversed. |
| `attachmentGeometry` | Parallel to `attachments`: `[roadDepartureASL, projectedAnchorASL, footprintApproach2D, footprintApproachHeightStatus, vehicleTraversalStatus]`. XY approach points never silently acquire zero elevation. |
| `attachmentIndexById` | Direct attachment ID lookup for routing and execution handoff. |
| `locationIndexById` / `attachmentsByLocation` | Direct per-location candidate lookup, sorted by off-road gap, anchor connector and ID. All candidates are retained; four locations have empty lists. |

`find_route` now returns `endpointApproaches` with coordinates, gap, connector length and uncertainty, plus `geography` containing actual interior overlap and separate nearby-outside evidence. Overlap excludes off-road gaps and anchor approximation connectors. Nearby-outside evidence is geographic only; it does not establish a complete alternate journey, tactical influence or control. The browser still renders authoring geometry and has no schema-1 corridor consumer to migrate.

Use `candidate_indices(package, location_id)` for the complete small per-site list. Optional kind, tier, maximum-gap and limit arguments provide a caller-selected geometric shortlist without altering the exported alternatives. `attachment_details(package, attachment_id)` provides execution coordinates without loading raw roads. The largest site still has 76 fallback candidates; mobility and threat filtering belong to runtime Analysis, not an arbitrary authoring cap.

## Validation

The 97 Python checks under `tests/` cover source topology, raw-versus-compressed distances, all observed Altis endpoint transitions, unchanged Dorida inlets, fallback thresholds and plateaus, source-constrained anchors, junctions and overpasses, same-edge costs, disconnected networks, a same-site external detour, and bridge-closure alternatives. Saved baseline paths are reconstructed and checked, source lengths survive splitting, all 278 sites survive the runtime export, dependency identities are checked, and runtime policy changes leave physical measurements intact. Schema 2 tests compare every exported interval with the full authoring intervals, cover all current source/split interval mappings and the preserved `d000000`/`altis_town_267` example, check positive/reversed intervals, compare all coordinate lookups to source data, and run 100 seeded runtime-only queries. New checks validate the actual Dorida triangle, fallback-only and mixed-node stopping, endpoint-only costs, non-bridging sites, retained standalone ports, and consistency of all regenerated dependencies. The native settlement-port suite passes 15 checks, and the full native inventory rebuild passes its catalog/output integrity check. The airport/town/bypass closure case is a synthetic topology fixture; actual Altis vehicle traversal remains untested.

`isolation-manifest.json` records hashes of 79 existing indexing/demo files before this experiment. `validation.json` records final checks. All SQF files use CRLF.

Leaflet 1.9.4 is bundled under its BSD-2-Clause license in `viewer/vendor/LICENSE.txt`. The published basemap's original coordinate scale is preserved; no road geometry is shifted to fit imagery.
