import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/file_logger.dart';
import 'package:telnyx_flutter_webrtc/main.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/call_state.dart';

enum CallStateStatus {
  idle,
  ringing,
  ongoingInvitation,
  ongoingCall,
}

class MainViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _loggingIn = false;
  bool callFromPush = false;
  bool _speakerPhone = true;
  CredentialConfig? _credentialConfig;
  IncomingInviteParams? _incomingInvite;

  String _localName = '';
  String _localNumber = '';

  bool get registered {
    return _registered;
  }

  bool get loggingIn {
    return _loggingIn;
  }

  CallStateStatus _callState = CallStateStatus.idle;

  CallStateStatus get callState => _callState;

  set callState(CallStateStatus newState) {
    if (newState == CallStateStatus.ongoingCall) {
      logger.i('Call ongoing');
    }
    _callState = newState;
    notifyListeners();
  }

  Call? _currentCall;

  Call? get currentCall {
    return _telnyxClient.calls.values.firstOrNull;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }

  void resetCallInfo() {
    logger.i('Mainviewmodel :: Reset Call Info');
    _incomingInvite = null;
    callState = CallStateStatus.idle;
    updateCallFromPush(false);
    notifyListeners();
  }

  void updateCallFromPush(bool value) {
    callFromPush = value;
    notifyListeners();
  }

  void observeCurrentCall() {
    currentCall?.callHandler.onCallStateChanged = (CallState state) {
      logger.i('Call State :: $state');
      switch (state) {
        case CallState.newCall:
          // TODO: Handle this case.
          break;
        case CallState.connecting:
          // TODO: Handle this case.
          break;
        case CallState.ringing:
          _callState = CallStateStatus.ringing;
          notifyListeners();
          break;
        case CallState.active:
          logger.i('current call is Active');
          _callState = CallStateStatus.ongoingCall;
          notifyListeners();
          if (Platform.isIOS) {
            // only for iOS
            // end Call for Callkit on iOS
            FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
          }

          break;
        case CallState.held:
          // TODO: Handle this case.
          break;
        case CallState.done:
          FlutterCallkitIncoming.endCall(currentCall?.callId ?? '');
          // TODO: Handle this case.
          break;
        case CallState.error:
          // TODO: Handle this case.
          break;
      }
    };
  }

  Future<void> _saveCredentialsForAutoLogin(
    CredentialConfig credentialConfig,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sipUser', credentialConfig.sipUser);
    await prefs.setString('sipPassword', credentialConfig.sipPassword);
    await prefs.setString('sipName', credentialConfig.sipCallerIDName);
    await prefs.setString('sipNumber', credentialConfig.sipCallerIDNumber);
    if (credentialConfig.notificationToken != null) {
      await prefs.setString(
        'notificationToken',
        credentialConfig.notificationToken!,
      );
    }
  }

  Future<void> _clearCredentialsForAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sipUser');
    await prefs.remove('sipPassword');
    await prefs.remove('sipName');
    await prefs.remove('sipNumber');
    await prefs.remove('notificationToken');
  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient
      ..onSocketMessageReceived = (TelnyxMessage message) async {
        logger.i(
            'Mainviewmodel :: observeResponses :: Socket :: ${message.message}');
        switch (message.socketMethod) {
          case SocketMethod.clientReady:
            {
              if (_credentialConfig != null) {
                await _saveCredentialsForAutoLogin(_credentialConfig!);
              }
              _registered = true;
              logger.i(
                'Mainviewmodel :: observeResponses : Registered :: $_registered',
              );
              break;
            }
          case SocketMethod.invite:
            {
              callState = CallStateStatus.ongoingInvitation;
              _incomingInvite = message.message.inviteParams;
              observeCurrentCall();
              if (!callFromPush) {
                await showNotification(_incomingInvite!);
              } else {
                // For early accept of call
                if (waitingForInvite) {
                  await accept();
                  waitingForInvite = false;
                }
              }

              logger.i(
                'customheaders :: ${message.message.dialogParams?.customHeaders}',
              );

              notifyListeners();
              break;
            }
          case SocketMethod.answer:
            {
              callState = CallStateStatus.ongoingCall;
              notifyListeners();
              break;
            }
          case SocketMethod.ringing:
            {
              callState = CallStateStatus.ringing;
              notifyListeners();
              break;
            }
          case SocketMethod.bye:
            {
              callState = CallStateStatus.idle;

              if (Platform.isIOS) {
                if (callFromPush) {
                  _endCallFromPush(true);
                } else {
                  await FlutterCallkitIncoming.endCall(
                    currentCall?.callId ?? _incomingInvite!.callID!,
                  );
                  resetCallInfo();
                }
              }
              break;
            }
        }
        notifyListeners();
        final messageLogger = await FileLogger.getInstance();
        await messageLogger.writeLog(message.toString());
      }

      // Observe Socket Error Messages
      ..onSocketErrorReceived = (TelnyxSocketError error) {
        Fluttertoast.showToast(
          msg: '${error.errorCode} : ${error.errorMessage}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
        );
        switch (error.errorCode) {
          case -32000:
            {
              //Todo handle token error
              break;
            }
          case -32001:
            {
              _loggingIn = false;
              break;
            }
          case -32003:
            {
              //Todo handle gateway timeout error
              break;
            }
          case -32004:
            {
              //ToDo hande gateway failure error
              break;
            }
        }
        notifyListeners();
      };
  }

  void _endCallFromPush(bool fromBye) {
    if (Platform.isIOS) {
      // end Call for Callkit on iOS
      FlutterCallkitIncoming.endCall(
        currentCall?.callId ?? _incomingInvite!.callID!,
      );
      if (!fromBye) {
        _telnyxClient.calls.values.firstOrNull?.endCall(
          _incomingInvite?.callID,
        );
      }
      // Attempt to end the call if still present and disconnect from the socket to logout - this enables us to receive further push notifications after

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _telnyxClient.disconnect();
      }
    }
    resetCallInfo();
  }

  void handlePushNotification(
    PushMetaData pushMetaData,
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
  ) {
    _telnyxClient.handlePushNotification(
      pushMetaData,
      credentialConfig,
      tokenConfig,
    );
  }

  void disconnect() {
    _telnyxClient.disconnect();
    _loggingIn = false;
    _registered = false;
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) async {
    _loggingIn = true;
    notifyListeners();

    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _credentialConfig = credentialConfig;
    _telnyxClient.connectWithCredential(credentialConfig);
  }

  void loginWithToken(TokenConfig tokenConfig) {
    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _telnyxClient.connectWithToken(tokenConfig);
  }

  void call(String destination) {
    _currentCall = _telnyxClient.newInvite(
      _localName,
      _localNumber,
      destination,
      'Fake State',
      customHeaders: {'X-Header-1': 'Value1', 'X-Header-2': 'Value2'},
    );
    observeCurrentCall();
  }

  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    currentCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  bool waitingForInvite = false;

  Future<CredentialConfig> getCredentialConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final sipUser = prefs.getString('sipUser');
    final sipPassword = prefs.getString('sipPassword');
    final sipName = prefs.getString('sipName');
    final sipNumber = prefs.getString('sipNumber');
    if (sipUser != null &&
        sipPassword != null &&
        sipName != null &&
        sipNumber != null) {
      return CredentialConfig(
        sipCallerIDName: sipName,
        sipCallerIDNumber: sipNumber,
        sipUser: sipUser,
        sipPassword: sipPassword,
        debug: true,
      );
    } else {
      return CredentialConfig(
        sipCallerIDName: 'Flutter Voice',
        sipCallerIDNumber: '',
        sipUser: MOCK_USER,
        sipPassword: MOCK_PASSWORD,
        debug: true,
      );
    }
  }

  Future<void> accept({bool acceptFromNotification = false}) async {
    if (callState == CallStateStatus.ongoingCall) {
      return;
    }

    if (_incomingInvite != null) {
      _currentCall = _telnyxClient.acceptCall(
        _incomingInvite!,
        _localName,
        _localNumber,
        'State',
      );

      if (Platform.isIOS) {
        // only for iOS
        await FlutterCallkitIncoming.setCallConnected(_incomingInvite!.callID!);
      }

      // Hide if not already hidden
      if (Platform.isAndroid && !acceptFromNotification) {
        final CallKitParams callKitParams = CallKitParams(
          id: _incomingInvite!.callID,
          nameCaller: _incomingInvite!.callerIdName,
          appName: 'Telnyx Flutter Voice',
          avatar: 'https://i.pravatar.cc/100',
          handle: _incomingInvite!.callerIdNumber,
          type: 0,
          textAccept: 'Accept',
          textDecline: 'Decline',
          missedCallNotification: const NotificationParams(
            showNotification: false,
            isShowCallback: false,
            subtitle: 'Missed call',
          ),
          duration: 30000,
          extra: {},
          headers: <String, dynamic>{'platform': 'flutter'},
        );

        _callState = CallStateStatus.ongoingCall;
        notifyListeners();

        // Hide notification when call is accepted
        await FlutterCallkitIncoming.hideCallkitIncoming(callKitParams);
      }
      notifyListeners();
    } else {
      logger.i('Answered early, waiting for invite');
      waitingForInvite = true;
    }
    notifyListeners();
  }

  Future<void> showNotification(IncomingInviteParams message) async {
    // Temporarily ignore FGBG events while showing the CallKit notification
    FGBGEvents.ignoreWhile(() async {
      final CallKitParams callKitParams = CallKitParams(
        id: message.callID,
        nameCaller: message.callerIdName,
        appName: 'Telnyx Flutter Voice',
        handle: message.callerIdNumber,
        type: 0,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: false,
          isShowCallback: false,
          subtitle: 'Missed call',
        ),
        duration: 30000,
        extra: {},
        headers: <String, dynamic>{'platform': 'flutter'},
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    });
  }

  void endCall({bool endfromCallScreen = false}) {
    logger.i(' Platform ::: endfromCallScreen :: $endfromCallScreen');
    if (currentCall == null) {
      logger.i('Current Call is null');
    } else {
      logger.i('Current Call is not null');
    }

    if (Platform.isIOS) {
      /* when end call from CallScreen we need to tell Callkit to end the call as well
       */
      if (endfromCallScreen && callFromPush) {
        // end Call for Callkit on iOS
        _endCallFromPush(false);
        logger.i('end Call: CallfromPush $callFromPush');
      } else {
        logger.i('end Call: CallfromCallScreen $callFromPush');
        // end Call normlly on iOS
        currentCall?.endCall(_incomingInvite?.callID);
      }
    } else if (Platform.isAndroid || kIsWeb) {
      currentCall?.endCall(_incomingInvite?.callID);
    }

    _callState = CallStateStatus.idle;
    notifyListeners();
  }

  void dtmf(String tone) {
    _telnyxClient.call.dtmf(_telnyxClient.call.callId, tone);
  }

  void muteUnmute() {
    _telnyxClient.call.onMuteUnmutePressed();
  }

  void holdUnhold() {
    _telnyxClient.call.onHoldUnholdPressed();
  }

  void exportLogs() async {
    final messageLogger = await FileLogger.getInstance();
    final logContents = await messageLogger.exportLogs();
    print(logContents);
  }
}
