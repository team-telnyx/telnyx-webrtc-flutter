import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/received_message_body.dart';

class TelnyxMessage {
  String socketMethod;
  ReceivedMessage message;

  TelnyxMessage({required this.socketMethod, required this.message});
}
