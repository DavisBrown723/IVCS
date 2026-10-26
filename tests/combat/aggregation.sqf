// Compare optimized calculations against the pre-optimization resolver.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap; IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap; IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed = 0; private _failed = 0;
private _assert = {
    params ["_ok","_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label];
};

private _combat = IVCS_VirtualSpace_Controller get "combat";
[(_combat get "step") == 1,"default resolution is one simulation second"] call _assert;
[(_combat get "minimumFireInterval") == 0.5,"minimum firing cadence is independent of resolution"] call _assert;
private _draws = 0;
private _roll = 0;
private _random = { _draws = _draws + 1; _roll };
[([0,0.5,_random] call IVCS_Combat_sampleHits) == 0 && { _draws == 0 },"zero attempts consume no random draws"] call _assert;
[([100,0,_random] call IVCS_Combat_sampleHits) == 0 && { _draws == 0 },"zero accuracy cannot hit"] call _assert;
[([100,1,_random] call IVCS_Combat_sampleHits) == 100 && { _draws == 0 },"certain hits preserve every attempt"] call _assert;
_roll = 0.56;
[([2,0.25,_random] call IVCS_Combat_sampleHits) == 0,"binomial zero-hit probability is respected"] call _assert;
_roll = 0.6;
[([2,0.25,_random] call IVCS_Combat_sampleHits) == 1,"binomial one-hit probability is respected"] call _assert;
_roll = 0.99;
[([2,0.25,_random] call IVCS_Combat_sampleHits) == 2,"multiple hits remain possible"] call _assert;
{
    private _n = _x;
    {
        private _p = _x;
        private _sum = 0; private _squares = 0; private _bounds = true;
        isNil {
            for "_i" from 0 to 2047 do {
                _roll = (_i + 0.5) / 2048;
                private _hits = [_n,_p,_random] call IVCS_Combat_sampleHits;
                _sum = _sum + _hits; _squares = _squares + _hits * _hits;
                _bounds = _bounds && { _hits >= 0 && { _hits <= _n } && { _hits == floor _hits } };
            };
        };
        private _mean = _sum / 2048;
        private _variance = _squares / 2048 - _mean * _mean;
        [_bounds && { abs (_mean - _n * _p) < 0.02 } && { abs (_variance - _n * _p * (1 - _p)) < 0.08 },"sampled hit counts retain binomial mean, variance and bounds"] call _assert;
    } forEach [0.03,0.5,0.8];
} forEach [1,2,8,32];
_roll = 0.8; _draws = 0;
private _large = [1024,0.5,_random] call IVCS_Combat_sampleHits;
[_large > 0 && { _large < 1024 } && { _draws == 32 },"large batches use bounded chunks without probability underflow"] call _assert;
west setFriend [east,0]; east setFriend [west,0];
private _make = { params ["_side","_pos"]; private _u = ["B_Soldier_F","u"] call IVCS_VirtualSpace_Group_createUnit; [_side,"BLU_F",_pos,[_u]] call IVCS_VirtualSpace_Group_createEntity };
private _a = ["WEST",[14500,16400,0]] call _make;
private _b = ["EAST",[14700,16400,0]] call _make;
private _unit = (_a get "units") select 0;
private _reference = ["B_Soldier_F","ref"] call IVCS_VirtualSpace_Group_createUnit;
private _engagement = [_a,_b,0,1] call IVCS_Combat_start;
((_b get "units") select 0) set ["weapons",[]];
_combat set ["accuracyScale",0];
private _weapon = ["arifle_MX_F"] call IVCS_Combat_getWeaponProfile;
private _savedInterval = _weapon get "interval";
private _referenceStep = {
    params ["_unit","_dt"];
    private _next = _unit get "fireDelay";
    private _shots = 0;
    while { _next <= _dt } do {
        private _shot = [_unit] call IVCS_Combat_getShot;
        if (_shot isEqualTo []) exitWith {};
        _shot params ["_mag","_weapon","_ammo"];
        _mag set [1,(_mag select 1) - 1];
        _shots = _shots + 1;
        _next = _next + ((_weapon get "interval") * (_combat get "cadenceScale") max (_combat get "minimumFireInterval"));
        if ((_mag select 1) == 0) then { _next = _next + (_combat get "reloadDelay"); };
    };
    _unit set ["fireDelay",(_next - _dt) max 0];
    _shots
};
{
    _weapon set ["interval",_x];
    {
        private _inventory = _x;
        {
            private _dt = _x;
            { _x set ["weapons",+_inventory]; _x set ["fireDelay",0]; } forEach [_unit,_reference];
            _engagement deleteAt "shotFactors";
            private _same = true;
            for "_window" from 1 to 12 do {
                private _before = _engagement get "shots";
                [_engagement,[_a,_b],_dt] call IVCS_Combat_step;
                private _expected = [_reference,_dt] call _referenceStep;
                // The independent ledger retains zero balances; compare usable physical inventory.
                private _actualInventory = (_unit get "weapons") apply { [_x select 0,(_x select 1) select { (_x select 1) > 0 }] };
                private _expectedInventory = (_reference get "weapons") apply { [_x select 0,(_x select 1) select { (_x select 1) > 0 }] };
                _same = _same && { (_engagement get "shots") - _before == _expected } && { _actualInventory isEqualTo _expectedInventory } && { abs ((_unit get "fireDelay") - (_reference get "fireDelay")) < 1e-5 };
            };
            [_same,"batches match individual due timestamps, magazine accounting and reload pauses"] call _assert;
        } forEach [0.25,0.5,1,1.5,8];
    } forEach [
        [["arifle_MX_F",[["30Rnd_65x39_caseless_mag",30]]]],
        [["arifle_MX_F",[["30Rnd_65x39_caseless_mag",1],["30Rnd_65x39_caseless_mag_Tracer",2]]]],
        [["launch_NLAW_F",[["NLAW_F",1]]],["arifle_MX_F",[["1Rnd_HE_Grenade_shell",1],["30Rnd_65x39_caseless_mag",1]]],["hgun_P07_F",[["16Rnd_9x21_Mag",4]]]],
        [["arifle_MX_F",[["30Rnd_65x39_caseless_mag",0]]]]
    ];
} forEach [0.5,0.75,1,2];
_weapon set ["interval",_savedInterval];
[_a] call IVCS_VirtualSpace_unregisterEntity; [_b] call IVCS_VirtualSpace_unregisterEntity;
// Empty groups outside combat keep their existing spawn behavior.
private _empty = ["WEST","BLU_F",[14500,16400,0],[]] call IVCS_VirtualSpace_Group_createEntity;
[_empty] call IVCS_VirtualSpace_Group_spawn;
[_empty get "active" && { !isNull (_empty get "group") },"noncombat empty groups still materialize"] call _assert;
[_empty] call IVCS_VirtualSpace_Group_despawn;
[_empty] call IVCS_VirtualSpace_unregisterEntity;
// Fractional recorded time resolves before either native roster is created.
_a = ["WEST",[14500,16400,0]] call _make; _b = ["EAST",[14700,16400,0]] call _make;
_engagement = [_a,_b,0,1] call IVCS_Combat_start;
_engagement set ["pending",0.4]; _engagement set ["lastUpdate",0.4];
[_a] call IVCS_VirtualSpace_Group_spawn;
{ { _x disableAI "ALL"; } forEach units (_x get "group"); } forEach [_a,_b];
[abs ((_engagement get "elapsed") - 0.4) < 1e-6 && { (_engagement get "shots") == 2 } && { (_engagement get "pending") == 0 },"handoff flushes fractional time once"] call _assert;
[(_engagement get "mode") == "native" && { _a get "active" } && { _b get "active" },"flush preserves paired native handoff"] call _assert;
{
    private _u = (_x get "units") select 0;
    private _object = _u get "object";
    private _record = (_u get "weapons") select 0 select 1 select 0;
    private _class = _record select 0;
    private _expected = 0; private _actual = 0;
    { { if ((_x select 0) == _class) then { _expected = _expected + (_x select 1); }; } forEach (_x select 1); } forEach (_u get "weapons");
    { if ((_x select 0) == _class) then { _actual = _actual + (_x select 1); }; } forEach magazinesAmmoFull _object;
    [_actual == _expected,"native inventory receives post-flush ammunition totals"] call _assert;
} forEach [_a,_b];
private _shots = _engagement get "shots";
[_a] call IVCS_Combat_flushPending;
[(_engagement get "shots") == _shots,"native handoff cannot flush virtual fire again"] call _assert;
[_a] call IVCS_VirtualSpace_Group_despawn;
[_a] call IVCS_VirtualSpace_unregisterEntity; [_b] call IVCS_VirtualSpace_unregisterEntity;
// A group killed by the final pending window must not create an empty ghost group.
_a = ["WEST",[14500,16400,0]] call _make; _b = ["EAST",[14700,16400,0]] call _make;
_engagement = [_a,_b,0,1] call IVCS_Combat_start;
((_b get "units") select 0) set ["damage",0.999];
_combat set ["accuracyScale",10000];
_engagement set ["pending",0.25]; _engagement set ["lastUpdate",0.25];
[_b] call IVCS_VirtualSpace_Group_spawn;
[(_b get "units") isEqualTo [] && { !(_b get "active") } && { isNull (_b get "group") },"lethal pending hit prevents materializing a deleted group"] call _assert;
[_a] call IVCS_VirtualSpace_unregisterEntity;
[count ((IVCS_VirtualSpace_Controller get "entities") get "ALL") == 0,"aggregation regressions release all groups"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
