// Combat intervals use the centralized, scaled simulation clock.
createHashMapFromArray [
    ["ammoSharing", [] call IVCS_Ammo_createSettings],
    ["helicopterInfantryRange",750], ["helicopterVehicleRange",1000],
    ["helicopterStandoff",400], ["helicopterAltitude",100],
    ["helicopterAttackRadius",750], ["helicopterFireTime",8], ["helicopterRepositionTime",25],
    ["helicopterInfantryStandoff",225], ["helicopterRepositionDistance",450],
    ["airReactionDelay",3], ["airCoverTime",10], ["airMinimumExposure",0.35],
    ["airRetreatDistance",100], ["airWithdrawalCooldown",60],
    ["helicopterEvasionTime",10], ["helicopterEvasionDistance",400], ["helicopterDescentSpeed",8],
    ["range", 300], ["eyeHeight", 1.5], ["scanInterval", 1],
    ["step", 1], ["stepsPerUpdate", 4], ["engagementsPerFrame", 8],
    ["frameBudgetMs", 3],
    ["accuracyScale", 1.1], ["cadenceScale", 1], ["minimumFireInterval", 0.5], ["reloadDelay", 3],
    ["blastSpacing",6], ["autoDismount",true], ["placementDelay",8],
    ["contactTimeout",30], ["ammoTimeout",15], ["reengageDelay",15],
    ["bodyWeights", [["head", 0.08], ["torso", 0.57], ["arms", 0.20], ["legs", 0.15]]],
    ["helicopters",createHashMap], ["engagements", createHashMap], ["queue", []], ["nextID", 0]
]
