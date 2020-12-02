params ["_opcom","_message"];

_message params ["_sender","_type","_data"];

switch (_type) do {
    case "orderRequest": {
        // _data params ["_orderType","_orderData"];

        // _orderData params ["_objectiveID"];
    };
    case "orderComplete": {
        systemchat format ["OPCOM: Order Complete"];

        private _order = _data;

        systemchat format ["Garrison is done - %1", diag_tickTime];

        [_opcom,_order] call IVCS_OPCOM_deleteOrder;
    };
};