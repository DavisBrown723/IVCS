// Called without suspension, after the shared policy revalidates the request.
params ["_recipient", "_donor", "_weapon", "_magazine", "_native"];
_magazine params ["_class", "_rounds", "", "_token", "_container"];
if (!_native) exitWith {
    _token params ["_source", "_record"];
    private _index = _source findIf { _x isEqualRef _record };
    private _destination = (_recipient get "weapons") select { (_x select 0) == _weapon };
    if (_index == -1 || { _destination isEqualTo [] }) exitWith { false };
    ((_destination select 0) select 1) pushBack (_source deleteAt _index);
    private _reload = (IVCS_VirtualSpace_Controller get "combat") get "reloadDelay";
    _recipient set ["fireDelay", (_recipient get "fireDelay") max _reload];
    true
};
private _object = _recipient get "object";
if (isNull _container || { !(_object canAdd _class) }) exitWith { false };
private _cargo = magazinesAmmoCargo _container;
private _index = _cargo findIf { (_x select 0) == _class && { (_x select 1) == _rounds } };
if (_index == -1) exitWith { false };
private _count = { (_x select 0) == _class && { (_x select 1) == _rounds } } count (magazinesAmmoFull [_object, true]);
_object addMagazine [_class, _rounds];
if (({ (_x select 0) == _class && { (_x select 1) == _rounds } } count (magazinesAmmoFull [_object, true])) != _count + 1) exitWith { false };
// Rebuild only unloaded magazines in this container. Weapons/items stay intact.
_cargo deleteAt _index;
clearMagazineCargoGlobal _container;
{ _container addMagazineAmmoCargo [_x select 0, 1, _x select 1]; } forEach _cargo;
true
