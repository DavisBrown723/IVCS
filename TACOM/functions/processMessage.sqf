params ["_tacom","_message"];

_message params ["_sender","_messageType","_messageData"];

switch (_messageType) do {
    case "newOrder": {
        private _order = _messageData;

        [_tacom, _order] call IVCS_TACOM_AddOrder;
    };
};