params ["_sideStr"];

switch (_sideStr) do {
    case "EAST": { "ColorEast" };
    case "WEST": { "ColorWest" };
    case "GUER": { "ColorGuer" };
    case "CIV": { "ColorCiv" };
    case "NONE": { "ColorUNKNOWN" };
    default { "ColorEast" };
};