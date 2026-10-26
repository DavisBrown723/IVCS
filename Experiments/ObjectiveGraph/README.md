# Altis objective graph experiment

Open **Open map.cmd**, or run `./start-map.ps1`. The loopback-only viewer runs at http://127.0.0.1:8770 and does not launch Arma. The saved overview works offline; detailed terrain tiles use Arma3Map online.

This experiment consumes RoadNetwork runtime schema 2 and its frozen Altis location snapshot. It creates `output/objective-graph.json` with 280 objective records, the original indexed baseline connections, and shortest full-network strategic route candidates. Strategic mode filters and displays those shortest routes; indexed mode preserves the original baseline projection. A straight-line overview is optional. Orange dashes show off-road gaps; purple dots show anchor approximations. Paths terminate at access points, not cluster centers. Node size represents neighboring objectives in the current view, not strategic importance. All alternatives remain in the underlying road index.

The browser performs runtime multi-source routing on the compact attachment graph. Each candidate origin includes its approach gap and anchor connector cost. Each destination is evaluated across its own candidates. Objective centers never become free transit vertices. Distances start/end at footprint access points; movement within an objective to a particular building is not included. Pairwise routes may choose different origin inlets and must not be concatenated as if those inlets connect freely.

Click an objective to compare routes from it. Choose a destination in the sidebar to see the actual road path, off-road gaps, anchor approximations, and other objective footprints crossed. Change Route comparison to test illustrative larger-road preferences. These weighted costs are not time estimates. Access colors represent boundary inlets versus fallback gap bands, not a validated mobility score. Settlement labels are approximate nearest-settlement labels; IDs remain authoritative. Footprint overlap does not establish tactical control, threat or a mandatory operation.

Use Access quality for an island overview, or Travel cost from selection to compare geographic reach. No-access objectives remain in the graph. Route rankings exclude destinations without an indexed road connection; this does not mean they are physically unreachable. All access candidates remain available, including disconnected source components. This is an analysis experiment, not a mission-runtime loader or commander implementation.

Rebuild after indexing changes: `python -B build.py`. Validate browser routing against an independent Python heap-based search: `python -B validate.py` (Node.js required). `viewer/graph.js` is the pure query module. `output/graph-summary.json` records source identity; `output/validation.json` records validation. Source indexing files are not modified.

The graph view retains all indexed objectives and alternatives. It does not yet score goal relevance, add ownership/intelligence overlays, simulate closures, or generate operation plans. Those can build on this inspected access foundation.


## Proximity relationships

Objective graph schema 2 adds a separate proximity layer. Offline preprocessing measures minimum horizontal gaps between indexed circle/rotated-rectangle footprints, retaining candidates up to 2,000 m. The viewer initially includes pairs within 1,000 m and allows a 0–2,000 m cutoff. Disable Include nearby objectives to restore road-only neighbors. Zero retains overlapping footprints. The cutoff is an experimental policy, not a weapon-range or mobility assertion.

The connected-objectives list is the union of qualifying strategic road neighbors and qualifying proximity neighbors, sorted by footprint gap. Green means both relationships, blue road only, pink proximity only, and gray no direct relationship under the current cutoff. Node size counts that union. Proximity links are schematic center-to-center pink dashes; inspecting one shows the measured footprint boundaries and nearest points. Road paths and routing costs remain unchanged. No proximity link can join disconnected road networks or shortcut a movement query.

Syrta (`altis_town_2067`) now includes the hilltop base (`altis_base_38`, labeled Base / Abdera by the nearest-settlement naming rule) at a footprint gap of 817.13 m and a center distance of 1,181.05 m. It is not a direct baseline road neighbor. The separate radio site may need a larger cutoff. Proximity alone does not establish line of sight, elevation advantage, tactical influence, or an operation prerequisite. These remain future Analysis inputs.

`python -B test_proximity.py` checks geometry, saved relationship integrity, and the Syrta inclusion regression. The existing routing validation ensures this strategic layer leaves road movement costs intact.


## Strategic versus indexed road view

The Graph view dropdown defaults to Strategic connectedness. Its adjustable experiment policy keeps a shortest-route road pair only if footprint gap <=2,000 m, total shortest-route distance (road + off-road gaps + anchor connectors) <=4,000 m, and road detour ratio <=2. The ratio is road distance divided by the larger of 500 m or horizontal distance between the two physical road departure points. This floor avoids rejecting short/overlapping approaches on unstable ratios. All three rules must pass. Independent proximity inclusion remains enabled by default at 1,000 m; a rejected road pair may still qualify as a proximity relationship. These are geographical strategic candidates, not mission priorities or guaranteed tactical influence.

Indexed road graph displays every split road edge as context and all original baseline objective connections without strategic or proximity filtering. Its node colors describe connectivity only. The original 734 pairs and all movement edges remain intact. Changing strategic limits never restricts route search: a geographically distant destination can remain reachable even when it is not a strategic neighbor. The separate road-preference selector changes movement cost, not these static inclusion limits.

The Galati power/Athira example (`altis_power_200` to `altis_town_3707`) retains its 8.67 km indexed road connection but is excluded by the default strategic policy. `node test_strategic.js` verifies rejection, permissive settings, retained Syrta proximity, and unchanged runtime data. Current display applies the policy at runtime; `output/objective-graph.json` retains its unfiltered candidate relationships for reuse and tuning.


## Full-network strategic routes

Schema 3 retains `links` as the unchanged indexed baseline projection and adds `strategicLinks`. These are shortest total physical-distance routes (road distance plus the two endpoint approach gaps and anchor connectors), searched on the complete road graph. Searches pass through intermediate attachments without stopping or merging their road nodes. Each pair stores its selected attachments, oriented edge path, road distance, total distance, and crossed objective footprints. Strategic filtering and drawing consume that same saved route. Selecting a connected strategic neighbor inspects that saved route, independently of the optional weighted live-route query.

Candidate discovery considers every objective pair with a footprint gap up to 5 km and searches to a total-distance bound of 10 km, rather than requiring an existing baseline pair. UI strategic limits are capped at this published preprocessing envelope. Defaults remain 2 km gap, 4 km route and 2x detour. The default display shows selected-objective links to keep the denser graph readable. Proximity is still independent and never changes movement topology. The underlying RoadNetwork index is unchanged.

Athira (`altis_town_3707`) to Ifestiona (`altis_town_3550`) now uses 1,043.37 m of roads (1,044.84 m including endpoint connectors) and intersects `altis_base_83`. Indexed view retains the original 2,954.58 m baseline road connection. Footprint intersections are evidence for later strategic analysis, not mandatory capture prerequisites. The live route-preference selector remains a separate query and may produce another route; it does not change the saved physical-distance strategic graph.

`node test_shortest.js` validates all saved strategic paths and footprint annotations, compares route costs against independent browser searches, verifies the Athira regression, and checks discovery of pairs absent from baseline indexing. `python -B validate.py` also checks browser routing against the independent heap-based reference.
