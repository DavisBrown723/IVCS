private _states = [
    ["INIT", [
        ["update", {
            wp = fnc_createWaypoint
        }],
        ["transitions", []]
    ]],
    ["MOVING",
        ["transitions", [
            "DESTINATION_REACHED", {
                wp != ""
            }
        ]]
    ],
    ["DESTINATION_REACHED",
        []
    ]
];

[
    "GET_IN",
    _states,
    "INIT",
    [
        ["destination", [0,0,0]]
    ]
] call fnc_createTask