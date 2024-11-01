private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Execution_onFrame];

createHashMapFromArray [
    ["onFrameHandlerID", _frameEventHandler],

    ["nextExecutionID", 0],
    ["executionsByID", createHashMap],

    ["executeAfterSecondsList", []],
    ["executeAfterSecondsListSorted", true],

    ["executeAfterFramesList", createHashMap],

    ["executeOverFramesList", createHashMap]
]