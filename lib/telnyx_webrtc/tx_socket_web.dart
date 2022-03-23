// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'package:logger/logger.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int code, String reason);
typedef OnOpenCallback = void Function();

class TxSocketWeb {
  TxSocketWeb(this.hostAddress) {
    hostAddress = hostAddress.replaceAll('https:', 'wss:');
  }

  String hostAddress;
  final logger = Logger();

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;

  connect(String providedHostAddress) async {
    try {
      _socket = WebSocket(providedHostAddress);
      _socket.onOpen.listen((e) {
        onOpen.call();
      });

      _socket.onMessage.listen((e) {
        onMessage.call(e.data);
      });

      _socket.onClose.listen((e) {
        onClose.call(e.code ?? 0, e.reason ?? "Closed for unknown reason");
      });
    } catch (e) {
      onClose.call(500, e.toString());
    }
  }
}