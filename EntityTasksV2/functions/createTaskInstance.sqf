params ["_templateName", "_instanceContext"];

private _template = IVCS_EntityTasks_TaskTemplates get _templateName;

// https://gameprogrammingpatterns.com/flyweight.html
// the use of templates here is to reduce the amount of instanced data being stored
// instead each instance stores a reference to its common data

private _instance = createhashmapfromarray [
    ["template", _template],
    ["context", (template get "context") merge [_instanceContext, true]],
    ["currentState", _template get "initState"],
    ["currentStatePhase", 0], // 0 = onEnter, 1 = onUpdate, 2 = onLeaving
    ["nextState", []],
    ["waypoints", []]
];

_instance