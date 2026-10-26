// Model rules are a vanilla starting point. Review the generated catalog before promotion.
// Exact overrides use lowercase class/model keys; [] explicitly ignores a model.
createHashMapFromArray [
    ["version", 7],
    ["variant", "adaptive-footprints-settlement-ports-v2"],
    ["footprints", createHashMapFromArray [
        ["enabled", true],
        ["minimumRectangleMembers", 4],
        ["minimumAspectRatio", 1.8],
        ["maximumRectangleAreaRatio", 0.70]
    ]],
    ["tileSize", 1000],
    ["terrainTypes", ["BUILDING","HOUSE","CHURCH","CHAPEL","BUNKER","FORTRESS","LIGHTHOUSE","QUAY","FUELSTATION","HOSPITAL","HIDE","TRANSMITTER","STACK","RUIN","WATERTOWER","POWERSOLAR","POWERWAVE","POWERWIND"]],
    // Port model instances must have terrain water within this sampled radius.
    ["portWaterRadius", 150],
    ["portWaterStep", 25],
    // Small neighbouring functions can belong to a dominant functional compound.
    ["compounds", createHashMapFromArray [
        ["enabled", true],
        ["primaryTypes", ["factory","power","base","airfield","port"]],
        ["secondaryTypes", ["town","factory","power","base","airfield","port","fuel","radiotower","hospital"]],
        ["minimumPrimaryObjects", 10],
        ["maximumSecondaryObjects", 20],
        ["maximumSecondaryRatio", 0.5],
        ["linkDistance", 100],
        ["maximumMemberDistance", 250]
    ]],
    // Military support is attached before general compound consolidation.
    ["militarySupport", createHashMapFromArray [
        ["enabled", true], ["primaryTypes", ["base","airfield"]], ["secondaryTypes", ["radiotower","power"]],
        ["maximumSecondaryObjects", 20], ["linkDistance", 100],
        ["maximumMemberDistance", 250]
    ]],
    // Fuel stations can support either civilian settlements or military bases.
    ["fuelSupport", createHashMapFromArray [
        ["enabled", true], ["primaryTypes", ["town","base","airfield"]], ["secondaryTypes", ["fuel"]],
        ["maximumSecondaryObjects", 20], ["linkDistance", 100],
        ["maximumMemberDistance", 250]
    ]],
    // Coastal port components can support settlements and military sites, including airfields.
    ["portSupport", createHashMapFromArray [
        ["enabled", true], ["primaryTypes", ["town","base","airfield"]], ["secondaryTypes", ["port"]],
        ["maximumSecondaryObjectsByPrimaryType", createHashMapFromArray [["town", -1]]],
        ["maximumSecondaryObjects", 20], ["linkDistance", 100],
        ["maximumMemberDistance", 250]
    ]],
    // Interpret secondary evidence in the context of the final primary site.
    ["secondaryTypeRemaps", createHashMapFromArray [
        ["factory", createHashMapFromArray [["base", "town"]]]
    ]],
    // Internal building uses, separate from site roles. Only active military members qualify.
    ["militaryBuildings", createHashMapFromArray [
        ["classOverrides", createHashMap],
        ["modelOverrides", createHashMap],
        ["rules", [
            ["_ruins", []],
            ["\barracks", ["barracks"]],
            ["\cargo_house_", ["barracks"]],
            ["\cargo_patrol_", ["fortification"]],
            ["\cargo_tower_", ["fortification"]],
            ["\bagbunker_small_", ["fortification"]],
            ["\bagbunker_large_", ["fortification"]],
            ["\pillboxbunker_01_", ["fortification"]],
            ["\bunker_01_", ["fortification"]]
        ]]
    ]],
    // These annotate an existing site's footprint; they never seed their own sites.
    ["secondaryRoles", ["radar","heli","air"]],
    ["classOverrides", createHashMapFromArray [["land_pier_small_f", []]]],
    ["modelOverrides", createHashMap],
    // [model path fragment, functional tags]. First matching rule wins.
    ["rules", [
        ["_ruins", []],
        // Wind turbines remain in the inventory, but supply no site evidence.
        ["\wpp_turbine", []],
        ["\windturbine", []],
        ["\wind_turbine", []],
        ["\powerlines\powlines_transformer", ["power"]],
        ["\powerlines\", []],
        ["\transmitter_tower\tbox", []],
        ["\transmitter_tower\communication_anchor", []],
        ["\airport\landmark", ["air"]],
        ["\helipad", ["heli"]],
        ["\mil\tenthangar", ["airfield", "base"]],
        ["\roads_f\runway\invisibleroadway", ["airfield"]],
        ["\runway_edgelight_blue", ["airfield"]],
        ["\roads_f\runway\runwaylights\naviglight", ["airfield"]],
        ["\roads_f\runway\", ["airfield","air"]],
        ["\runway", ["airfield","air"]],
        ["\radar\radar", ["base","radar"]],
        ["\radardome", ["base","radar"]],
        ["\radar_dome", ["base","radar"]],
        ["\research\", ["base"]],
        ["\wavepowerplantbroken", []],
        ["\wavepowerplant", ["power"]],
        ["\mil\", ["base"]],
        ["\military\", ["base"]],
        ["\airport\", ["airfield"]],
        ["\hangar", ["airfield"]],
        ["\radar", ["base"]],
        ["\transmitter", ["radiotower"]],
        ["\ttower", ["radiotower"]],
        ["\communication", ["radiotower"]],
        ["\power", ["power"]],
        ["\solarpanel", ["power"]],
        ["\spp_", ["power"]],
        ["\wpp_", ["power"]],
        ["\dp_", ["power"]],
        ["\pier_small_f.p3d", []],
        ["\pier", ["port"]],
        ["\quay", ["port"]],
        ["\crane", ["port"]],
        ["\fuelstation", ["fuel"]],
        ["\hospital", ["hospital"]],
        ["\factory", ["factory"]],
        ["\concretemixingplant\", ["factory"]],
        ["\pipes\", ["factory"]],
        ["\shed\", ["factory"]],
        ["\stone_big\", ["town"]],
        ["\stone_small\", ["town"]],
        ["\slum\", ["town"]],
        ["\wip\", ["town"]],
        ["\houses", ["town"]],
        ["\house_", ["town"]],
        ["\housebig", ["town"]],
        ["\housesmall", ["town"]],
        ["\shops", ["town"]],
        ["\offices", ["town"]],
        ["\church", ["town"]],
        ["\chapel", ["town"]]
    ]],
    // [type, neighbour distance, minimum members, maximum distance from seed,
    //  minimum neighbours including self for expansion, footprint padding].
    ["categories", [
        ["town", 100, 6, 650, 4, 30],
        ["base", 180, 2, 650, 1, 40],
        ["radiotower", 120, 1, 300, 1, 25],
        ["power", 180, 2, 600, 1, 40],
        ["port", 160, 2, 700, 1, 40],
        // Internal spatial category; final sites are military bases with the air role.
        ["airfield", 600, 1, 3000, 1, 80],
        ["fuel", 120, 1, 250, 1, 20],
        ["factory", 140, 3, 500, 2, 40],
        ["hospital", 100, 1, 250, 1, 30]
    ]]
]
