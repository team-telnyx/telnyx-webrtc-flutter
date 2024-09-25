import UIKit
import AVFAudio
import CallKit
import PushKit
import Flutter
import flutter_callkit_incoming

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
        print("onRunner ::  Accept")
        action.fulfill()
    }
    
    func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        
    }
    
    func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        action.fulfill()
    }
    
    func onTimeOut(_ call: flutter_callkit_incoming.Call) {
        
    }
    
    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        print("onRunner  :: Activate Audio Session")
    }
    
    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        print("onRunner  :: DeActivate Audio Session")
    }
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
      //Setup VOIP
      let mainQueue = DispatchQueue.main
      let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
      voipRegistry.delegate = self
      voipRegistry.desiredPushTypes = [PKPushType.voIP]
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    // Call back from Recent history
        override func application(_ application: UIApplication,
                                  continue userActivity: NSUserActivity,
                                  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
            
            guard let handleObj = userActivity.handle else {
                return false
            }
            
            guard let isVideo = userActivity.isVideo else {
                return false
            }
            let nameCaller = handleObj.getDecryptHandle()["nameCaller"] as? String ?? ""
            let handle = handleObj.getDecryptHandle()["handle"] as? String ?? ""
            let data = flutter_callkit_incoming.Data(id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
            //set more data...
            data.nameCaller = "Johnny"
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)
            
        
            return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        
        // Handle updated push credentials
        func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
            print(credentials.token)
            let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
            print(deviceToken)
            //Save deviceToken to your server
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
        }
        
        func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
            print("didInvalidatePushTokenFor")
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
        }
        
        // Handle incoming pushes
        func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
            print("didReceiveIncomingPushWith")
            print("Payload \(payload.dictionaryPayload)")
            guard type == .voIP else { return }
            
            if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
                var callID = UUID.init().uuidString
                if let newCallId = (metadata["call_id"] as? String),
                   !newCallId.isEmpty {
                    callID = newCallId
                }
                let callerName = (metadata["caller_name"] as? String) ?? ""
                let callerNumber = (metadata["caller_number"] as? String) ?? ""
                
                let id = payload.dictionaryPayload["call_id"] as? String ??  UUID().uuidString
                let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false
                
                let data = flutter_callkit_incoming.Data(id: id, nameCaller: callerName, handle: callerNumber, type: isVideo ? 1 : 0)
                data.extra = payload.dictionaryPayload as NSDictionary
                data.normalHandle = 1
                print("\(callerName)")
              
                
                let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
                let uuid = UUID(uuidString: callID)
                
                //set more data
                //data.iconName = ...
                data.uuid = uuid!.uuidString
                data.nameCaller = caller
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
            }
            
        
            
        }
    
    
}
