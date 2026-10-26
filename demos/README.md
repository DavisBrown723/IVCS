# IVCS demos

## Infantry combat demo

With IVCS running, execute this in the debug console using **Local Exec** in single player or **Server Exec** in multiplayer:

```sqf
[] execVM "IVCS\demos\infantry-combat.sqf";
```

This creates a standard BLU_F infantry squad and a standard OPF_F infantry squad, 500 m apart. Both receive normal MOVE waypoints to the same battlefield centre. Virtual combat starts once they reach the configured combat range (currently 300 m) and have terrain visibility. If terrain blocks visibility, they continue approaching the shared destination rather than stopping at separate positions. Their movement stops when combat starts.

The battlefield defaults to 400 m ahead of the player (the first connected player on a dedicated server). Choose a battlefield centre and starting positions on land. To supply a centre and the BLUFOR approach heading instead:

```sqf
[[14500,16400,0],90] execVM "IVCS\demos\infantry-combat.sqf";
```

The example coordinates are on Altis. Blue/red map markers follow the squads and show movement, virtual combat, or live simulation. Initially the squads are virtual. Approach within the current spawn radius (200 m by default) of an engaged squad to spawn both sides and resume combat with native AI. Moving away allows normal virtualization. Existing mission spawn settings, side relationships, and simulation speed are used unchanged; WEST and EAST must be hostile.

Rerunning replaces only the previous demo squads and markers. To remove them:

```sqf
[] execVM "IVCS\demos\stop-infantry-combat.sqf";
```

The demo does not start automatically or move the player. Server-side entity IDs are available in `IVCS_Demo_InfantryCombatIDs` for inspection.

## Map indexing demo

On **Altis**, run this in the debug console using **Local Exec**:

```sqf
[] execVM "IVCS\demos\map-index.sqf";
```

The demo loads the generated location file for the current terrain and opens the map at an overview scale. Each location has a colored outline showing its radius and a matching label describing its primary function, any secondary functions, unique object count, and radius. Merged industrial compounds can show `Industrial area (+ power, housing)`. Absorbed military evidence is reported as housing in industrial sites. Civilian settlements and military bases can show fuel and port as secondary functions. Airfields display as military bases with an `[air]` badge. Military sites can also show secondary radio, power, and radar functions. Sites containing helipads or runway evidence also display `[heli]` or `[air]` badges. For example: `Military base | 18 objects | radius 240 m`. Zoom in to inspect overlapping areas. The supplied Altis file contains 280 candidate locations.

IVCS does not need to be started first. Markers are local to the player running the demo. The generated candidates are loaded for inspection; the demo does not change the mission's active location data or start another terrain scan. You can close the map normally and reopen it with the markers still present.

To reduce clutter, display selected categories:

```sqf
[["base", "radiotower"]] execVM "IVCS\demos\map-index.sqf";
```

Available categories: `town`, `base`, `radiotower`, `power`, `port`, `fuel`, `factory`, and `hospital`. Secondary-role filters also accept `radar`, `heli`, and `air`. Airfields are included under `base` and `air`; legacy `airfield` filters also match `air`. Rerunning replaces the previous demo markers. An empty category list shows all locations. Filters match secondary functions too: selecting `power` also displays an industrial compound containing power equipment, while `fuel` and `port` include settlements and bases with those absorbed facilities. Industrial housing matches `town`, and does not match `base`.

For example, show every site with a helipad or air capability:

```sqf
[["heli", "air"]] execVM "IVCS\demos\map-index.sqf";
```

An optional second argument selects another generated or reviewed hash-map location file for the current terrain. The third argument, when false, leaves the map view as it is:

```sqf
[[], "IVCS\Locations\Indexing\output\altis\locations.sqf", false] execVM "IVCS\demos\map-index.sqf";
```

To remove the demo markers:

```sqf
[] execVM "IVCS\demos\stop-map-index.sqf";
```

The displayed location records and marker names are available in `IVCS_Demo_MapIndexLocations` and `IVCS_Demo_MapIndexMarkers` for inspection. For classification rules and rebuilding, see [the indexing guide](../Locations/Indexing/README.md).
