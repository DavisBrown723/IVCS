# Map indexing

Map indexing is an offline authoring step. The normal pipeline builds adaptive location clusters, extracts or reuses the road network, finds site inlets and nearby approaches, and exports routing and browser data together. The supplied runner uses an isolated vanilla Altis dedicated server and does not enable indexing during mission startup.

## Generate Altis data

From the workspace root:

```powershell
powershell -File .\IVCS\Locations\Indexing\run.ps1
```

The runner uses the existing Arma dedicated server and FileBank paths in `IVCS/tests/tasks/run.ps1`. It retains the native RPT under the temporary test artifact directory printed at startup. All generated SQF uses CRLF. Road data is built automatically after locations; no experiment entry point is required.

The default destination is `IVCS/Locations/Indexing/output/altis`:

| File | Return value when compiled and called |
| --- | --- |
| `locations.sqf` | Candidate location hash maps |
| `catalog.sqf` | `[class, model, tags, count, samplePosition]` rows |
| `objects.sqf` | `[class, model, position]` records, stored in compact batches by model |
| `roads/manifest.json` | Road summary, schema versions and dataset identities |
| `roads/runtime.json` | Compact road graph, site attachments, corridor relations and baseline connections |
| `roads/*.json` | Full road geometry, topology, access coverage and routing authoring data |
| `viewer/data.js` | Browser projection from this same build |
| `source.json` | Native location build provenance and source hashes |
| `index.json` | Completed build manifest, dependency identities and file hashes |

Rebuild after editing `settings.sqf`, using the saved inventory from the same terrain:

```powershell
powershell -File .\IVCS\Locations\Indexing\run.ps1 -InventoryPath .\IVCS\Locations\Indexing\output\altis\objects.sqf
```

This reruns classification, spatial validation, clustering, consolidation, and export without scanning objects again. Port validation still samples water in the running terrain. `-RescanRoads` refreshes the native road capture; otherwise the previously published capture is reused, falling back to the bundled Altis capture on the first build. `-OutputDirectory`, `-Port`, and `-TimeoutSeconds` are optional. OutputDirectory must be a named direct child of `Locations/Indexing/output`. The PowerShell runner is currently specific to Altis; the SQF scanner itself uses the current world. Reusing an inventory requires the same world and terrain version.

The runner builds in a staging directory and validates matching location, road, runtime and viewer identities before publishing. Failed builds leave the prior published output intact and retain their stage for diagnosis. Successful builds retain the previous output in `.previous-*` under `output`; these backups can be removed later after review. Two builds must not publish to the same destination concurrently.

Open `Roads/Open map.cmd` or run `Roads/start-map.ps1` for the browser map at http://127.0.0.1:8767. The viewer reads the published `output/altis/viewer/data.js` directly. Viewing does not launch Arma. The existing in-game demo uses the same production `locations.sqf` and now draws saved rectangles as well as circles.

This promotes authoring and saved data. Mission startup does not scan terrain, and this change does not add an SQF road loader or Commander behavior. See [road indexing](Roads/README.md) for data contracts and routing limitations.

## Inspect and tune

Load IVCS functions in the Altis editor, then preview the generated candidates:

```sqf
IVCS_IndexLocations = call compile preprocessFileLineNumbers "IVCS\Locations\Indexing\output\altis\locations.sqf";
IVCS_IndexMarkers = [IVCS_IndexLocations] call IVCS_Locations_indexPreview;
```

The local markers show each cluster's saved circular or rotated rectangular footprint, primary function, secondary functions where present, and unique object count. Clear the previous preview before replacing it:

```sqf
{ deleteMarkerLocal _x; } forEach IVCS_IndexMarkers;
```

Use the catalog to review a model once instead of classifying each instance. Match precedence is exact class override, exact full model-path override, then the first matching model-path fragment. Override keys and rule fragments must be lowercase. An empty tag list explicitly ignores an identity. Class overrides take precedence even when their result is empty; model overrides also work for terrain objects without class names.

```sqf
private _settings = call IVCS_Locations_indexSettings;
(_settings get "modelOverrides") set ["myterrain\buildings\hq.p3d", ["base"]];
(_settings get "classOverrides") set ["land_decorative_tower", []];
```

Persist authoring changes in `settings.sqf` when using the PowerShell runner. Multiple tags are supported: one structure may provide evidence to several functions. Unknown objects receive no tags and remain in the catalog and inventory. Catalog tags describe model-level classification before spatial validation. `unclassifiedCount` counts instances with no accepted tags, including explicit exclusions and inland port evidence; it is not a count of classification errors. `rejectedPortObjects` reports how many instances lost their port tag during water validation.

The vanilla rules intentionally exclude `Land_Pier_small_F` / `pier_small_f.p3d`, wind turbines, electricity poles, telecom junction boxes, loose shipping containers, and ruins as functional evidence. Helipads and runway boundary markers provide secondary roles only. Stone houses and slum housing contribute town evidence. Runway objects contribute airfield evidence; radar domes contribute military and radar evidence. Rules are editable heuristics, not a universal model database.

## Clustering behavior

The first stage clusters each category independently using a spatial bucket search. Nearby members expand a cluster only when the category's local density threshold is met. Expansion is also bounded by distance from the initial seed. Failed candidates do not reserve objects; successful clusters assign each object once per category. Support passes attach small radio/power sites to bases and fuel/port sites to civilian settlements or bases (including airfields), then general consolidation combines other eligible functional compounds. A final pass annotates existing footprints with radar, heli, and air evidence. Substantial independent sites can still overlap.

Each category row contains:

```sqf
[type, neighbourDistance, minimumMembers, maximumDistanceFromSeed, minimumNeighboursIncludingSelf, padding]
```

Defaults distinguish settlement density from isolated infrastructure. A town requires six members and four local neighbours including the point itself. A single radio tower may form an objective. Standalone power sites, ordinary bases, and ports each require at least two members. The internal airfield category keeps its one-member minimum and larger spacing, and exports as a military base with an air role. A lone power object can contribute to a nearby compound, but cannot survive as its own site. Fuel evidence links within 120 m with a 250 m seed extent, joining station signs to nearby pumps and roofs. Large settlements can split at the configured extent, and separate facilities can still merge when their same-category structures are close enough.

Port evidence also needs terrain water within 150 m of each object, sampled on a 25 m grid with `surfaceIsWater`. This rejects pier models reused inland, such as those in Paros. `Land_Pier_small_F` is excluded by class override and `pier_small_f.p3d` by model rule before this check, so these small piers cannot create, enlarge, or support any port even at the coast. `portWaterRadius` and `portWaterStep` control the check; modded water represented only by objects may need a custom water predicate. The fourth argument to `IVCS_Locations_indexBuild` accepts a predicate called as `[position] call predicate`, primarily for tests. Production builds must run on the terrain matching the inventory.

Military support uses `militarySupport` in `settings.sqf`. Any valid military cluster (normally at least two objects, or a valid internal airfield cluster) can absorb radio and power sites with at most 20 objects, without the general ten-object primary minimum or half-size restriction. The nearest member must be within 100 m of an original base member, and every support member within 250 m. If several bases qualify, the closest wins, with ID as a deterministic tie-breaker. This runs before general consolidation so a small support facility retains the military site's primary identity. If that base is subsequently absorbed by a larger compound, all support members and component records are carried along; the combined secondary must fit the general size and distance limits.

Fuel support uses `fuelSupport`. Valid civilian settlements (`town`) and military bases (`base`, including internal `airfield` clusters) can absorb a fuel cluster containing at most 20 objects. At least one fuel object must be within 100 m of an original host member, and every fuel object within 250 m. The closest eligible host wins across both categories, with ID breaking ties. Original members determine eligibility even if a host already absorbed another support site. This rule does not require the host to contain ten objects or twice as many objects as the station. Distant or substantial fuel facilities remain independent. Fuel evidence and source components survive subsequent compound merging. Other functional sites retain their existing fuel absorption through general compound rules.

Port support uses `portSupport`, after military and fuel support and before general consolidation. Settlements can absorb a valid coastal port without a member-count cap; military bases, including airfields, retain the 20-object cap. The per-primary setting is `maximumSecondaryObjectsByPrimaryType`, with `town = -1` meaning unlimited. The nearest port member must be within 100 m of the original host core, and every port member within 250 m. The closest eligible host owns the port, with ID breaking ties. Absorbed radio, power, fuel, or port objects never extend that host's reach. Ports failing the spatial checks retain their independent identity, as do military support candidates above their count cap. The host keeps the `port` secondary role, its evidence counts, and original component provenance; the demo's `port` filter includes these hosts.

Compound rules are grouped under `compounds` in `settings.sqf`:

- Industrial, power, military, airfield, or port clusters with at least 10 objects can be primary sites. Largest eligible clusters are considered first.
- A secondary cluster can contain at most 20 objects and at most half as many objects as the original primary cluster.
- At least one secondary object must lie within 100 m of an original primary member, and every secondary object must be within 250 m of an original primary member.
- Eligibility always uses the original primary members, preventing chains of mergers from spreading through a town. Same-category clustering happens in the first stage.
- Settlements can be small supporting components and can absorb fuel through `fuelSupport` and ports through `portSupport`; they do not act as primary sites in general compound consolidation. Nearby substantial sites remain independent.

These rules combine Athira's factory, power equipment, barracks, and adjacent housing while preserving the larger town and the separate base to the west. They are reusable spatial rules, with no terrain coordinates or LLM calls in the indexer. Review and tune thresholds against other terrains.

Locations retain the existing `type`, `position`, and `size` fields and add `id`, `objectCount`, per-model counts, `source`, `world`, `indexVersion`, and `reviewed`. The primary `type` is retained after consolidation, except that a compound owning airfield evidence always becomes `base`. `types` lists all accepted member roles; `typeCounts` contains `[type, count]` evidence totals. Merged sites also store `components` as `[originalId, originalType, originalObjectCount]` rows. Multi-tag objects may contribute to several role/component counts, but `objectCount`, model counts, the center, and the radius count each inventory object only once per merged site. `size` is recomputed as a radius in metres around the mean member position plus primary-category padding. Coordinates are 2D with zero Z. These are descriptive areas, not validated land positions for spawning units, especially at ports.

Airfields always have military identity. The internal `airfield` category retains its 600 m neighbour distance and 3,000 m seed extent so airport structures continue to form a coherent site. Airfields participate as military hosts in radio, power, fuel, and port support. A base cluster whose members are entirely shared with an airfield is folded into that airfield before support ownership, preventing duplicate sites from dual-tagged hangars.

At export, each owned `airfield` member contributes `base` and `air` evidence, deduplicated against existing tags. `airfield` is removed from public `type`, `types`, and `typeCounts`; original IDs and component categories remain traceable. Every airfield, including one identified by hangars or airport infrastructure without a separate runway model, displays `Military base [air]`. If a different compound absorbs an airfield, military primary identity takes precedence there too, before contextual housing remaps. Merely annotating a neighbouring site's footprint with runway evidence grants `air` without transferring ownership of the airfield or promoting that neighbouring site's primary type. Demo callers should filter on `base` or `air`; legacy `airfield` filters also match `air`.

`secondaryTypeRemaps` interprets member roles using the final primary site type. For `factory` sites, `base` becomes `town` (displayed as housing). This affects saved `types`, `typeCounts`, preview labels, and filters. An object already tagged as both military and housing contributes only once to the housing count. Raw catalog tags and original `components` retain their source classification for review; standalone military sites retain `base`. Physical evidence such as radar, heli, air, power, and fuel remains available after the housing remap.

Military building uses are saved separately from site roles. Sites with an active `base` role have `militaryBuildings` rows in the form `[kind, class, model, position]` and `militaryBuildingCounts` rows such as `[["barracks", 3], ["fortification", 2]]`. Zero counts are explicit. These fields do not add map labels, badges, or category filters. A site can contain other military structures that belong to neither kind.

- `barracks`: barracks buildings and military cargo houses used as accommodation.
- `fortification`: military cargo guard posts/towers, small and large bag bunkers, pillboxes, and the `Bunker_01` family. These default model families expose native building positions suitable for occupation. Loose walls, barriers, the classless Altis `bunker_f.p3d`, and towers without native positions are excluded from this subtype. HQ offices, radar structures, and hangars are not automatically assigned either use.

The `militaryBuildings` settings contain their own `classOverrides`, `modelOverrides`, and ordered `rules`, with the same precedence as functional classification. An object must first provide military or airfield evidence; subtype overrides cannot make civilian objects military. The final member role controls whether metadata is retained, so industrial evidence remapped to housing does not become an active military building. Compounds with a surviving military secondary role retain the metadata. Each recognized member is recorded once per kind, after merging, with class/model identity and its 2D map position. These are building origins, not soldier slots; runtime garrison code must resolve the building and select native positions before placing units. Subtype classification uses the saved inventory and needs no new scan or LLM.

For example, inspect the buildings in a loaded military site:

```sqf
private _buildings = _site getOrDefault ["militaryBuildings", []];
private _fightingStructures = _buildings select { (_x select 0) == "fortification" };
private _counts = createHashMapFromArray (_site getOrDefault ["militaryBuildingCounts", []]);
private _barracksCount = _counts getOrDefault ["barracks", 0];
```

Wind-turbine exclusion runs before clustering. Turbines remain in the raw inventory and catalog with empty tags, but cannot supply power-site membership, meet minimum object counts, extend a footprint, connect power clusters, or contribute a secondary power role. Other power equipment remains eligible.

Secondary roles are stored as strings in `types` and counted in `typeCounts`:

- `radar`: a military site (or compound containing military evidence) has a radar dome. Vanilla large and small radar domes are recognized.
- `heli`: any site's footprint contains a helipad. Helipads cannot seed standalone sites or satisfy the minimum membership of a primary category.
- `air`: automatically present on every airfield, including hangar or airport-infrastructure clusters. Other sites can also receive this role when their footprints contain runway models, landing guidance, runway lighting, or runway boundary markers.

The role pass uses each site's footprint before annotation. It adds contained evidence once per site, recomputes model counts, center and radius, and does not repeatedly expand to collect further objects. Overlapping sites may share contained role evidence. Attaching a runway object grants `air` without absorbing its whole airfield category. Model overrides can provide these same tags for other terrains. Runtime-placed helipads are outside the terrain inventory, like other mission-placed objects.

The preview shows radar alongside other secondary functions and displays literal `[heli]` and `[air]` badges. Demo filters accept `radar`, `heli`, and `air` as well as the existing categories.

Sorting tagged evidence before clustering gives reproducible membership and IDs for the same inventory and settings. IDs are not guaranteed to survive terrain or rule changes. Strategic priority, ownership, terrain-name labels, and a hierarchy between remaining independent areas are not inferred yet.

## Use reviewed data in a mission

Edit or remove candidate locations after inspecting them, and set `reviewed` as appropriate. Export the resulting array:

```sqf
copyToClipboard ([IVCS_IndexLocations] call IVCS_Locations_exportLocationsMapData);
```

Save it as `IVCS/Locations/MapData/altis.sqf`, then explicitly load it where needed:

```sqf
[worldName] call IVCS_Locations_loadLocationsMapData;
```

The authoring runner writes candidates only. The existing Locations startup remains disabled in `IVCS/startup.sqf`. The exporter accepts an explicit array or, with no arguments, the current mission data. OPCOM now accepts hash-map locations while retaining its legacy namespace input.

## Scan scope and validation

The scanner queries configured terrain map types in tiles with half-open ownership bounds, avoiding duplicate objects in overlapping queries. It uses unsorted 2D [nearestTerrainObjects](https://community.bistudio.com/wiki/nearestTerrainObjects) queries. That command filters by terrain model map properties, not class inheritance; `HIDE` is included because useful infrastructure can have that property. It also brings in many rocks and decorative objects. Mission-placed objects are outside this scan.

For a custom scan or a different terrain, run in scheduled execution:

```sqf
[] spawn {
    private _settings = call IVCS_Locations_indexSettings;
    private _records = [_settings] call IVCS_Locations_indexScan;
    IVCS_IndexResult = [_records, _settings] call IVCS_Locations_indexBuild;
    IVCS_IndexMarkers = [IVCS_IndexResult get "locations"] call IVCS_Locations_indexPreview;
};
```

The scanner's optional second argument is `[minX,minY,maxX,maxY]`, useful for regional authoring and tests. The default is the current world's square extent. Incomplete terrain-type filters can miss infrastructure, so modded maps require catalog and coverage review.

Run the native regression suite from the workspace root:

```powershell
powershell -File .\IVCS\tests\tasks\run.ps1 -TestScript .\IVCS\tests\locations\run.sqf -Port 2503 -TimeoutSeconds 240
```

Checks cover port support ownership and boundaries, small-pier exclusion, military airfield identity and shared-member deduplication, internal military building uses and override precedence, turbine exclusion from standalone and compound evidence, model precedence and exclusions, water validation, minimum power evidence, fuel linking, civilian/military fuel ownership, contextual industrial housing counts, military support ownership, nested compound consolidation and deduplication, preservation of independent sites, bounded growth, radar/heli/air evidence, footprint containment, input-order reproducibility, role badges, precise export round trips, quoted metadata, native scan tile coverage, and the OPCOM location input.

## Verified Altis baseline

The vanilla Altis inventory contains **673,914 objects** across **788 class/model identities**. Version 6 generates **280 unreviewed candidate areas**: 108 towns or settlements, 42 military bases (including all five airfields), 14 radio sites, 55 power sites, 22 ports, 29 industrial areas, 9 fuel sites, and 1 hospital. These are primary-type counts; 57 locations are mixed compounds with additional roles. There are **4 radar sites, 12 heli sites, and 8 air sites** across the primary categories. There are 661,945 untagged instances, including natural objects, decoration, explicit exclusions, and 8 rejected inland port objects.

All 128 wind turbines remain in the raw inventory with empty catalog tags and no site membership. Compared with version 4, the power-site count falls from 71 to 55. The 44 sites with a military role contain 176 barracks/accommodation buildings and 84 fortifications, with 260 unique recorded building identities and positions. Native checks verify occupiable positions for all five fortification models present in the saved Altis sites.

The northeastern radar base includes its nearby power site and the `radar` role. The small base near the central airfield absorbs its radio facility and displays `[heli]`. Every generated role has matching model evidence and works in the demo's category filter.

The Paros inland port is removed. Chalkeia's seven fuel objects are now a secondary fuel component of its 95-object settlement. Athira's 46-object industrial compound reports 29 industrial, 2 power, and 15 housing objects; its former military secondary role is interpreted as housing. The larger Athira settlement stays separate and now contains its original 163 settlement objects plus a seven-object fuel station. The separate western base remains independent. No standalone power site contains only one object.

Fuel roles occur in 13 settlements, 2 military bases (one an airfield), and 9 standalone fuel sites. All 113 classified fuel objects are preserved exactly once across those locations. Industrial sites no longer appear in the military filter, and absorbed fuel facilities remain discoverable through the fuel filter.

Port roles occur in 8 settlements, 2 military bases, 1 industrial compound, and 22 standalone ports. All 503 accepted coastal port objects are preserved exactly once. The 18 small-pier objects remain in the inventory and catalog with no tags or site membership. Airfields use military primary identity and `[air]` labels; all five appear in the military filter, and legacy `airfield` filters still work through the `air` role.

The native regression suite passes 120 checks. Loading the saved artifacts and running the demo in Arma passes another 57 checks, including the reported locations, secondary-function labels and filtering, inventory expansion, unique IDs, precise location export round trips, catalog/rule agreement, military building identities and counts, native fortification positions, turbine and small-pier exclusions, port ownership, and military airfield labels and filters, with no script errors. `output/altis/summary.json` records this baseline and the settings and location hashes. Its validation applies to these generated files; regenerate the report if the baseline changes.

To verify saved output after generation:

```powershell
powershell -File .\IVCS\tests\tasks\run.ps1 -TestScript .\IVCS\tests\locations\generated.sqf -Port 2503 -TimeoutSeconds 300
```

## Adaptive footprints

Location index version 7 uses `adaptive-footprints-settlement-ports-v2`. A padded rectangle is selected for at least four members when its aspect ratio is at least 1.8 and its area is at most 70 percent of the covering circle. Otherwise a circle is retained. Footprints are saved as `[shape, center, halfExtents, clockwiseDegrees]`. `position` and `size` remain a conservative enclosing circle for legacy consumers.

Rectangular host cores also constrain absorption: every secondary member must fit within the existing 100 m shape margin as well as the 100 m nearest-member and 250 m whole-component distance bounds. Absorbed components never extend the original core's eligibility. Role-only evidence is tested against the fixed saved shape.

The three ports near Kavala, Neochori and Pyrgos are part of their settlement records; all 503 port evidence objects remain represented and 19 ports remain independent in the promoted Altis snapshot. The normal build preserves the reviewed 278-site snapshot exactly.

## Validation

Run `python -m unittest discover -s IVCS/Locations/Indexing/Roads/tests -p "test_*.py"` from the workspace root. Historical Altis regression fixtures intentionally describe the promoted snapshot; deliberate rule changes may require reviewing their expected results. Every normal build also performs general dataset consistency validation before publishing, independent of these snapshot assertions.

Native tests use `IVCS/tests/tasks/run.ps1 -TestScript` with `IVCS/tests/locations/footprints.sqf`, `run.sqf`, `settlement-ports.sqf`, and `generated.sqf`. These execute production functions and data. The original experiment directories remain historical references.
