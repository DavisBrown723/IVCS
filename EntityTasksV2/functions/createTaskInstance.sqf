params ["_templateName", "_instanceInfo"];

_instanceInfo params ["_arguments"];

private _template = IVCS_EntityTasks_TaskTemplates get _templateName;

// https://gameprogrammingpatterns.com/flyweight.html
// the use of templates here is to reduce the amount of instanced data being stored
// instead each instance stores a reference to its common data

private _instance = createhashmapfromarray [
    ["template", _template],
    ["arguments", _arguments],
    ["currentState", _template get "initState"],
    ["currentStatePhase", 0], // 0 = onEnter, 1 = onUpdate, 2 = onLeaving
    ["nextState", []]
];

_instance