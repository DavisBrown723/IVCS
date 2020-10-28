params ["_sideNum"];

switch (_sideNum) do {
    case 0: { "EAST" };
    case 1: { "WEST" };
    case 2: { "GUER" };
    case 3: { "CIV" };
    default { "EAST" };
};