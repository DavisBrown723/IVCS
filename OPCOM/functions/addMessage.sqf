params ["_opcom","_message"];

private _messageQueue = _opcom get "messageQueue";
_messageQueue pushback _message;