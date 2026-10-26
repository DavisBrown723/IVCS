params ["_a", "_b"];
if (_a isEqualType 0) exitWith { _a isEqualTo _b };
(_a select 1) isEqualRef (_b select 1)
