// Keep ownership through weapon switching and the completed native reload.
params ["_request", "_snapshot"];
private _weapon = _request get "weapon";
private _object = (_request get "recipient") get "object";
if !(_weapon in (_snapshot select 2)) exitWith { false };
// A GL rifle may still have its secondary muzzle selected.
if (currentMuzzle _object != _weapon) exitWith { _object selectWeapon _weapon; true };
private _state = weaponState _object;
// A loading magazine can temporarily leave inventory before rounds appear.
if ((_state select 6) > 0) exitWith { true };
if ((_state select 4) > 0) exitWith { false };
private _compatible = ([_weapon] call IVCS_Common_getWeaponInfo) select 2;
// Inventory can lose the magazine before weaponState reports a reload phase.
// Keep the delivered request through that gap; updateRequests owns its timeout.
if ((_snapshot select 3) findIf { (_x select 1) > 0 && { (_x select 0) in _compatible } } != -1) then {
    _object reload [_weapon, (_request get "delivered") select 1];
};
true
