params ["_entity"];
private _side=_entity get "side";
if ((_entity get "entityType")!="group") then {
    private _owner=[_entity get "commandingEntity"] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_owner") then {_side=_owner get "side"};
};
_side call IVCS_Common_sideStringToObject
