private _opcoms = call IVCS_OPCOM_getAll;
{
    [_x] call IVCS_OPCOM_update;
} foreach _opcoms;