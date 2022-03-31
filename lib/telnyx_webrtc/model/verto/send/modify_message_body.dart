import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';

class ModifyMessage {
  String? id;
  String? jsonrpc;
  String? method;
  ModifyParams? params;

  ModifyMessage({this.id, this.jsonrpc, this.method, this.params});

  ModifyMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
    json['params'] != null ? ModifyParams.fromJson(json['params']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['jsonrpc'] = jsonrpc;
    data['method'] = method;
    if (params != null) {
      data['params'] = params!.toJson();
    }
    return data;
  }
}

class ModifyParams {
  String? action;
  DialogParams? dialogParams;
  String? sessionId;

  ModifyParams({this.action, this.dialogParams, this.sessionId});

  ModifyParams.fromJson(Map<String, dynamic> json) {
    action = json['action'];
    dialogParams = json['dialogParams'] != null
        ? DialogParams.fromJson(json['dialogParams'])
        : null;
    sessionId = json['sessionId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['sessionId'] = sessionId;
    return data;
  }
}
