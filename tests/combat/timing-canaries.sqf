// Identical fixed work after the measured IVCS root; diagnostic timing controls only.
IVCS_Timing_Frame=IVCS_VirtualSpace_onFrame;
IVCS_VirtualSpace_onFrame={
    [] call IVCS_Timing_Frame;
    if (IVCS_Perf_Enabled && {IVCS_Perf_Recording}) then {
        call {
            private _scope=createProfileScope "IVCS_CLOCK_Arithmetic";
            private _value=1;
            for "_i" from 1 to 128 do {_value=sqrt (_value+_i)};
        };
        call {
            private _scope=createProfileScope "IVCS_CLOCK_Allocation";
            for "_i" from 1 to 16 do {private _value=createHashMapFromArray [["i",_i],["a",[_i,_i+1]]]};
        };
        if (diag_frameNo mod 30==0) then {profilerLog format ["IVCS CLOCK SYNC %1",[diag_frameNo,systemTimeUTC]]};
    };
};
diag_log "[IVCS PERF] CLOCK_CANARIES installed";
