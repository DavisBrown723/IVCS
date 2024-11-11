params ["_sideString"];

switch (_sideString) do {
    case "EAST": { 0 };
    case "WEST": { 1 };
    case "GUER": { 2 };
    case "CIV": { 3 };
    default { 0 };
};