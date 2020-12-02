IVCS_OPCOMs = [] call CBA_fnc_createNamespace;

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_OPCOM_onFrame];
IVCS_OPCOM_OnFrameEH = _frameEventHandler;