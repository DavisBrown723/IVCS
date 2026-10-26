# Altis spatial merge review

Generated from the normal production index. Merge eligibility now uses compatible site types, nearest original member within 100 m, all child members within 250 m, and the existing 100 m rectangular margin. There is no object-count cap, half-size requirement or extra minimum host count in the merge pass. Initial category minimums still determine whether a core can host other sites; lone power objects are secondary evidence only. General compound hosts must have at least the original footprint area of their child. Explicit support relationships retain their direction and do not require area dominance. Airfields are considered first, then larger original footprint areas, with stable IDs breaking ties.

Locations: **278 → 268**. 15 previous site records were absorbed; 5 site IDs appeared. Every previous primary source cluster remains represented in the new index.

## Central airport

`altis_airfield_169`: 1580 → 1602 objects. Shape: rectangle. Roles: air, base, factory, power, radar, radiotower.

- `altis_base_90` now belongs to `altis_airfield_169`.
- `altis_base_132` now belongs to `altis_base_132`.

The southwest military component now merges into the airport. The northern component remains independent: its owned power transformer at [15589.4, 17401.3] is about 439.6 m from the nearest original airport member, beyond the retained 250 m whole-component bound. Twelve of its 27 original military/support objects exceed that bound. These distances were checked against reconstructed category memberships from the unchanged native inventory (1547 airport members; component counts verified against saved provenance).

Object counts include secondary-role annotations. Shared annotation evidence can disappear from map-wide totals when overlapping records merge; original source component ownership is checked independently.

## Changed sites

Map links open the current viewer at the resulting site. Existing roads, access points and routing data were regenerated from these same location records.

| Area | Previous site | Resulting site | Change | Previous → resulting objects |
| --- | --- | --- | --- | --- |
| Agios Dionysios | `altis_factory_190` | [altis_factory_190](http://127.0.0.1:8767/#6.00/9224.4/16012.0) | changed | 3 → 4 |
| Agios Georgios | `altis_base_313` | [altis_factory_506](http://127.0.0.1:8767/#6.00/20851.1/19367.1) | absorbed | 36 → 105 |
| Agios Georgios | `altis_factory_506` | [altis_factory_506](http://127.0.0.1:8767/#6.00/20851.1/19367.1) | changed | 69 → 105 |
| Alikampos | `altis_factory_228` | [altis_power_207](http://127.0.0.1:8767/#6.00/10248.1/14829.9) | absorbed | 4 → 9 |
| Alikampos | `altis_power_207` | [altis_power_207](http://127.0.0.1:8767/#6.00/10248.1/14829.9) | changed | 5 → 9 |
| Anthrakia | `altis_factory_428` | [altis_power_1076](http://127.0.0.1:8767/#6.00/16945.1/15355.2) | absorbed | 7 → 20 |
| Anthrakia | `altis_fuel_76` | [altis_power_1076](http://127.0.0.1:8767/#6.00/16945.1/15355.2) | absorbed | 7 → 20 |
| Anthrakia | `altis_power_1076` | [altis_power_1076](http://127.0.0.1:8767/#6.00/16945.1/15355.2) | changed | 6 → 20 |
| Edessa | `altis_factory_138` | [altis_power_136](http://127.0.0.1:8767/#6.00/8214.6/10916.6) | absorbed | 37 → 85 |
| Edessa | `altis_power_136` | [altis_power_136](http://127.0.0.1:8767/#6.00/8214.6/10916.6) | changed | 48 → 85 |
| Fotia | `altis_power_0` | [altis_power_0](http://127.0.0.1:8767/#6.00/3007.0/18425.0) | changed | 39 → 32 |
| Kalochori | `altis_factory_485` | [altis_power_1155](http://127.0.0.1:8767/#6.00/20668.9/15749.5) | absorbed | 38 → 245 |
| Kalochori | `altis_power_1155` | [altis_power_1155](http://127.0.0.1:8767/#6.00/20668.9/15749.5) | changed | 207 → 245 |
| Kavala Pier | `altis_factory_1` | [altis_factory_1](http://127.0.0.1:8767/#6.00/3280.0/12439.0) | changed | 6 → 8 |
| Kavala Pier | `altis_power_33` | [altis_factory_1](http://127.0.0.1:8767/#6.00/3280.0/12439.0) | absorbed | 2 → 8 |
| Panagia | `altis_factory_477` | [altis_factory_477](http://127.0.0.1:8767/#6.00/20271.6/8803.8) | changed | 4 → 6 |
| Panagia | `altis_power_1153` | [altis_factory_477](http://127.0.0.1:8767/#6.00/20271.6/8803.8) | absorbed | 2 → 6 |
| Pyrgos | `altis_base_229` | [altis_factory_438](http://127.0.0.1:8767/#6.00/17402.5/13183.3) | absorbed | 69 → 69 |
| Rodopoli | `altis_factory_470` | [altis_factory_470](http://127.0.0.1:8767/#6.00/19318.7/16529.9) | changed | 5 → 6 |
| Terminal | `altis_airfield_169` | [altis_airfield_169](http://127.0.0.1:8767/#6.00/14711.7/16462.0) | changed | 1580 → 1602 |
| Topolia | `altis_factory_123` | [altis_factory_123](http://127.0.0.1:8767/#6.00/6836.5/15818.1) | changed | 4 → 5 |
| airbase | `altis_base_90` | [altis_airfield_169](http://127.0.0.1:8767/#6.00/14711.7/16462.0) | absorbed | 76 → 1602 |
| factory | `altis_factory_73` | [altis_factory_73](http://127.0.0.1:8767/#6.00/6231.8/16247.6) | changed | 40 → 61 |
| factory | `altis_power_93` | [altis_factory_73](http://127.0.0.1:8767/#6.00/6231.8/16247.6) | absorbed | 21 → 61 |
| power plant | `altis_factory_355` | [altis_power_386](http://127.0.0.1:8767/#6.00/15461.0/16317.8) | absorbed | 40 → 632 |
| power plant | `altis_port_252` | [altis_base_146](http://127.0.0.1:8767/#6.00/15403.0/15813.1) | absorbed | 37 → 47 |
| power plant | `altis_power_386` | [altis_power_386](http://127.0.0.1:8767/#6.00/15461.0/16317.8) | changed | 685 → 632 |
| quarry | `altis_factory_26` | [altis_factory_26](http://127.0.0.1:8767/#6.00/4203.9/12833.6) | changed | 5 → 6 |
| quarry | `altis_factory_7` | [altis_power_39](http://127.0.0.1:8767/#6.00/3806.7/12384.1) | absorbed | 13 → 13 |
| storage | `altis_factory_452` | [altis_factory_452](http://127.0.0.1:8767/#6.00/18299.0/15557.9) | changed | 9 → 12 |
| storage | `altis_power_1116` | [altis_factory_452](http://127.0.0.1:8767/#6.00/18299.0/15557.9) | absorbed | 2 → 12 |

## Newly independent sites or new primary IDs

| Area | Current site | Primary type | Objects | Previous owner of this source core |
| --- | --- | --- | --- | --- |
| Fotia | [altis_town_4](http://127.0.0.1:8767/#6.00/3009.9/18502.5) | town | 7 | `altis_power_0` |
| Pyrgos | [altis_factory_438](http://127.0.0.1:8767/#6.00/17402.5/13183.3) | factory | 69 | `altis_base_229` |
| power plant | [altis_base_146](http://127.0.0.1:8767/#6.00/15403.0/15813.1) | base | 47 | `altis_power_386` |
| power plant | [altis_base_152](http://127.0.0.1:8767/#6.00/15352.2/16214.3) | base | 2 | `altis_power_386` |
| quarry | [altis_power_39](http://127.0.0.1:8767/#6.00/3806.7/12384.1) | power | 13 | `altis_factory_7` |

Location dataset: `f86c54200a6562fdecede38d92e40db4db86e9aa603dcd096709e5f9734c0338`.
