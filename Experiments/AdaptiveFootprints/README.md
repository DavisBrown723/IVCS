> Promoted into normal map indexing on 2026-10-14. Use [Locations/Indexing](../../Locations/Indexing/README.md). This directory preserves the experimental implementation and saved comparison data; it is no longer the production build path.

# Adaptive footprint experiment

This is an opt-in fork of map indexing v6. It is **not merged into production** and is not loaded by normal startup. All new source, generated data, frozen baseline data and preview state belong to this folder. The repository has no Git metadata, so isolation uses a separate directory and namespace instead of a branch/worktree.

## Try the generated Altis demo

In an Altis mission with this `IVCS` folder available, run in the debug console using **Local Exec**:

```sqf
["compare", [], true, [14648,16551,0]] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
```

Grey outlines are the original v6 circles. Coloured outlines and labels are the experimental footprints. Rectangle labels show full dimensions and rotation; circle labels show radius. The optional fourth parameter focuses the map on the main airport; zoom in as desired.

To see only one version, re-run with `"adaptive"` or `"baseline"`. Re-running replaces only this experiment's markers:

```sqf
["adaptive", [], true, [14648,16551,0]] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
["baseline", [], true, [14648,16551,0]] execVM "IVCS\Experiments\AdaptiveFootprints\demo.sqf";
```

The second argument optionally filters site roles, for example `["air"]` or `["base","power"]`. The baseline snapshot is Altis-only. The demo checks that loaded data matches the mission terrain.

If the normal indexing demo is already running, stop it separately to avoid duplicate labels. This experiment deliberately preserves its markers. To remove the experimental preview:

```sqf
[] execVM "IVCS\Experiments\AdaptiveFootprints\stop-demo.sqf";
```

## What changes

- The original object classification and category clustering remain intact. The fork adds geometry to refinement and preview.
- Each cluster starts with a padded circle and a candidate rotated bounding rectangle. A convex hull supplies candidate orientations; the smallest unpadded bounding rectangle is padded using the existing category padding.
- A rectangle is selected when there are at least **4 distinct positions**, its padded aspect ratio is at least **1.8**, and its area is at most **70%** of the candidate circle's area. Other sites keep circles. These settings are in `settings.sqf` under `footprints`.
- Existing support/compound limits still apply: nearest member within 100 m, all child members within 250 m of the original core, plus the existing type/count restrictions. For rectangular cores, every candidate member must also lie within 100 m of the original padded rectangle. Distances are measured to the rectangle's edges/corners.
- Merge eligibility always uses the original core geometry. An absorbed neighbour cannot expand the area used to accept another neighbour.
- After legitimate merges, the final core determines a fixed site footprint. Radar, helipad and runway annotations use that shape. Adding role evidence does not expand the shape.
- No Altis-specific coordinates or manual site exceptions occur in the indexing algorithm. The algorithm remains deterministic and reusable without an LLM. The included rebuild harness and frozen comparison target Altis.

The geometry is based on object origins plus category padding. It does not infer fences, parcel boundaries, roads or concave compounds. Rectangles may still overlap independent sites; containment alone does not merge them. It also does not split the airport terminal from the runway, because existing category clustering owns that decision.

## Observed Altis result

| Measure | Frozen v6 | Experiment |
| --- | ---: | ---: |
| Locations | 280 | 280 |
| Circles | 280 | 218 |
| Rectangles | 0 | 62 |
| Main airport objects | 1,580 | 1,580 |
| Main airport footprint area | 3.97 km² | 1.64 km² |
| Nearby base objects (`altis_base_90`) | 246 | 76 |

The main airport (`altis_airfield_169`) uses a **771 × 2,132 m rectangle rotated 43.1°**, about **59% less area** than its former 1,125 m-radius circle. Its objects, role counts and merged components are unchanged.

All site IDs, primary categories, role sets, merged components and military building records remain unchanged in this rebuild. Only one site's object/model/role counts change: the nearby base stops collecting 170 runway air-role annotations outside its rectangle. It retains its military structures, power, radio, radar and air roles; the main airport's runway model counts remain unchanged. This change is secondary evidence containment, not a hand-edited exception or a changed merge assignment.

`output/altis/summary.json` records measured counts and source hashes. `comparison.json` records every footprint and semantic difference. `airport-comparison.png` and `.svg` show the two airport boundaries at the same scale without a terrain basemap. In-game visual review is still needed before adoption.

## Saved shape and compatibility

Every experimental location adds:

```sqf
["footprint", ["rectangle", [centerX,centerY,0], [halfWidth,halfHeight], clockwiseDegrees]]
["indexVariant", "adaptive-footprints-v1"]
```

Circles use equal half-axes and angle zero. Rotated rectangle angles follow Arma's native rectangular markers and `inArea` convention. The shape center can differ from `position`.

`position` remains the member centroid. `size` remains a conservative enclosing radius, including the full rectangle and its corners. **Use `footprint` for precise containment and drawing**; legacy radius-only consumers will still see a broad circle. A rectangle's compatibility radius can be larger than the old radius even though its footprint area is smaller.

Geometry functions are `IVCS_AF_fitFootprint`, `IVCS_AF_footprintContains`, `IVCS_AF_footprintDistance` and `IVCS_AF_footprintCorners`. All forked indexing functions and demo variables use `IVCS_AF_`. Nothing registers experimental locations into the production location manager or OPCOM.

## Rebuild and verify

From the workspace root in PowerShell:

```powershell
& ./IVCS/Experiments/AdaptiveFootprints/run.ps1
```

This reads the existing Altis inventory and writes only under this experiment's `output` directory. The output path guard rejects production destinations. The runner reuses the existing dedicated-server test harness; Arma 3 dedicated server and FileBank must be installed. Default test port is 2506.

To regenerate the comparison report after rebuilding:

```powershell
python ./IVCS/Experiments/AdaptiveFootprints/review.py
```

Python standard library produces JSON and SVG. If Pillow is installed, it also produces a PNG using the Windows Segoe UI font. Reports assume the supplied Altis baseline and airport IDs. They are review tools, separate from the reusable SQF indexing algorithm.

Native test commands:

```powershell
& ./IVCS/tests/tasks/run.ps1 -TestScript ./IVCS/Experiments/AdaptiveFootprints/tests/geometry.sqf -Port 2506
& ./IVCS/tests/tasks/run.ps1 -TestScript ./IVCS/Experiments/AdaptiveFootprints/tests/regressions.sqf -Port 2506
& ./IVCS/tests/tasks/run.ps1 -TestScript ./IVCS/Experiments/AdaptiveFootprints/tests/generated.sqf -Port 2506
& ./IVCS/Experiments/AdaptiveFootprints/verify-isolation.ps1
```

Validated: **26 geometry checks + 119 indexing regressions + 20 generated-data/demo checks = 165 passing checks**, with no SQF script errors in the successful runs. The regression suite is the existing suite forked into the experimental namespace, excluding its one production OPCOM integration check. Native tests verify rotated containment against `inArea`, support boundaries, non-growing merges, serialization, conservative legacy bounds, markers, filters and cleanup. The production isolation check compares 35 indexing/demo/test/entrypoint files against the pre-experiment hashes. All `.sqf` files use CRLF.

`validation.json` links the successful local engine runs to this result. Production integration is intentionally deferred until the visual experiment is accepted.

## Later merge

The frozen `baseline/source` files preserve the original source for comparison. If accepted, port the geometry module, footprint settings/refinement, serialization metadata and preview support into the main indexer, then migrate precise runtime queries to the new footprint interface and rerun production integration tests. Do not replace the production output merely by copying this folder's data: current consumers still interpret `size` as a circle.
