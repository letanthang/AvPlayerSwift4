//
//  SBDAnalyzer.swift
//  TableDatabase
//
//  Created by Thang Le Tan on 6/5/18.
//  Copyright © 2018 david lopez. All rights reserved.
//

import UIKit
import AVKit
import SocketRocket
import SwiftyJSON

class SBDAnalyzer: NSObject {
    let sdkName = "iOS_SDK"
    let sdkVersion = "0.1"
    var playerLayer: AVPlayerLayer?
    var playerVC: AVPlayerViewController?
    var player: AVPlayer?
    var webSocket: SRWebSocket?
    var queue = [[String: Any]]()
    var callbacks = [String: (String) -> Void]()
    var afterInitQueue = [[String: Any]]()
    var viewId: String? = nil
    var session: String? = nil
    
    static let shared = SBDAnalyzer()
    
    private override init() {
        super.init()
        //webSocket = SRWebSocket(url: URL(string: "ws://ws.stag-sa.sbd.vn:10080"))
        
        let os = "iOS"
        let osVersion = UIDevice.current.systemVersion
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        let appVersion = Bundle.main.releaseVersionNumberPretty;
        let deviceType = "phone"
        let device = UIDevice.current.name
        let userAgent = sdkName + "/" + sdkVersion + " " + os + "/" + osVersion + " "
            + appName + "/" + appVersion + " " + deviceType + "/" + device;
        
        var request = URLRequest(url: URL(string: "ws://ws.stag-sa.sbd.vn:10080")!)
        request.allHTTPHeaderFields = ["user-agent": userAgent]
        webSocket = SRWebSocket(urlRequest: request)
        webSocket?.delegate = self
        print("sbd_" + "websocket try to connect, user-agent=" + userAgent)
        webSocket?.open()
    }
    
    public func setup(playerLayer: AVPlayerLayer) {
        self.playerLayer = playerLayer
        player = playerLayer.player
        observerPlayer()
        
    }
    public func setup(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        player = playerVC.player
        observerPlayer()
    }
    
    func observerPlayer() {
        player?.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "rate":
            print(player?.rate)
        case "playbackBufferEmpty":
            print("start buffering")
        case "playbackLikelyToKeepUp":
            print("end buffering")
        case "playbackBufferFull":
            print("end buffering")
        default:
            print(keyPath)
        }
        
    }
    
    func initWS() {
        var json = [String: Any]()
        json["type"] = "initWS"
        json["session"] = session
        _ = send(json: json) { (response: String) in
            if let responseData = response.data(using: .utf8, allowLossyConversion: false) {
                let responseJSON = try? JSON(data: responseData)
                if let status = responseJSON?["status"].string, status == "OK" {
                    print("sbd_" + "initWS success")
                    self.session = responseJSON?["data"][0].string
                }
            }
            
        }
    }
}

extension SBDAnalyzer: SRWebSocketDelegate {
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("sbd_" + "open: you are connected to server: " + webSocket.url.absoluteString)
        initWS()
    }
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        guard let msg = message as? String else {
            print("sbd_" + "message: receive data message")
            return
        }
        print("sbd_" + "message: receive string: " + msg)
        let data = msg.components(separatedBy: "::")
        let cbKey = data[0]
        let respString = data[1];
        callbacks[cbKey]!(respString)
        
    }
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("sbd_" + "close webSocket")
    }
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("sbd_" + "fail with error " + error.localizedDescription)
    }
}

extension SBDAnalyzer {
    func send(json: [String: Any], callback: @escaping (String) -> Void ) -> Bool {
        let key = NSUUID.init().uuidString
        var js = json
        js["callback"] = key
        callbacks[key] = callback
        if (send(json: js)) {
            return true;
        }
        callbacks.removeValue(forKey: key)
        return false
    }
    func send(json: [String: Any]) -> Bool {
        guard let type = json["type"] as? String else {
            return false
        }
        if (type == "initWS") {
            let arr = [ json ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted) {
                let jsonString = String(data: jsonData, encoding: .utf8)
                webSocket?.send(jsonString)
                print("sbd_" + "send initWS " + jsonString!)
            }
        } else {
            queue.append(json)
        }
        return true
    }
    
    func sendViewEvent(eventData: [String: Any]) -> Bool {
        var data = eventData;
        do {
            if (data["date"] == nil) {
                data["date"] = getUTCDate()
            }
            if (data["playPosition"] == nil) {
                data["playPosition"] = player?.currentItem?.currentTime()
            }
            var json = [String: Any]()
            json["type"] = "event"
            
            if let viewId = viewId {
                data["viewId"] = viewId
                let tmp = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                json["data"] = String(data: tmp, encoding: .utf8)
                return send(json: json)
            } else {
                let tmp = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                json["data"] = String(data: tmp, encoding: .utf8)
                afterInitQueue.append(json)
            }
            
        } catch {
            print("Error : \(error)")
            return false
        }
        return true
    }
    
    func getUTCDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        return formatter.string(from: Date())
    }
}
