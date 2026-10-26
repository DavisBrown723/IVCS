// Small integer generator keeps arithmetic exact even on SQF float implementations.
params ["_engagement"];
private _seed = ((_engagement get "seed") * 75 + 74) mod 65537;
_engagement set ["seed", _seed];
_seed / 65537
