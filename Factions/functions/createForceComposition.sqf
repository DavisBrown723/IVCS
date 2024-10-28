params ["_faction","_composition"];

/*
    Example
    private _forceComposition = [
        "BLU_F",
        [
            ["infantry", [40,50]],
            ["reconInfantry", [4,6]],
            ["tanks", 5],
            ["tankDestroyers", [2]]
        ]
    ] call IVCS_Factions_createForceComposition;
*/

private _factionComposition = [_faction] call IVCS_Factions_getComposition;

private _factionSide = [_faction] call IVCS_Common_getFactionSide;

private _compositionGroupTypeData = [];
private _returnComposition = [_factionSide, _faction, 0, _compositionGroupTypeData];

private _totalGroups = 0;
{
    _x params ["_unitType","_count"];

    private _realCount = if (_count isequaltype []) then {
        switch (count _count) do {
            case 3: { round (random [_count select 0, _count select 1, _count select 2]) };
            case 2: {
                _count params ["_low","_high"];
                round (random [_low, _low + ((_high - _low) / 2), _high])
            };
            default {
                private _mid = _count select 0;
                private _variance = ceil (_mid * 0.15);
                round (random [_mid - _variance, _mid, _mid + _variance])
            };
        };
    } else {
        _count
    };

    private _groups = [];
    if (!isnil "_factionComposition") then {
        private _factionGroupsForType = _factionComposition get _unitType;

        for "_i" from 0 to _realCount - 1 do {
            _groups pushback (selectrandom _factionGroupsForType);
        };
    };

    _totalGroups = _totalGroups + _realCount;

    _compositionGroupTypeData pushback [_unitType, _realCount, _groups];
} foreach _composition;

_returnComposition set [2, _totalGroups];

_returnComposition