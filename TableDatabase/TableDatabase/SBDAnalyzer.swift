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

class SBDAnalyzer: NSObject {
    var playerLayer: AVPlayerLayer?
    var playerVC: AVPlayerViewController?
    var player: AVPlayer?
    var webSocket: SRWebSocket?
    var queue = [[String: Any]]()
    var callbacks = [String: (Data)]()
    var afterInitQueue = [[String: Any]]()
    var viewId: String? = nil
    var session: String? = nil
    
    static let shared = SBDAnalyzer()
    
    private override init() {
        super.init()
        webSocket = SRWebSocket(url: URL(string: "ws://ws.stag-sa.sbd.vn:10080"))
        webSocket?.delegate = self
        print("sbd_" + "websocket try to connect")
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
        send(json: json)
    }
}

extension SBDAnalyzer: SRWebSocketDelegate {
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("sbd_" + "open: you are connected to server: " + webSocket.url.absoluteString)
        let json = ["type": "initWS"]
        send(json: json)
    }
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        guard let msg = message as? String else {
            print("sbd_" + "message: receive data message")
            return
        }
        print("sbd_" + "message: receive string: " + msg)
    }
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("sbd_" + "close webSocket")
    }
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("sbd_" + "fail with error " + error.localizedDescription)
    }
}

extension SBDAnalyzer {
    func send(json: [String: Any], callback: (Data) ) -> Bool {
        let key = NSUUID.init().uuidString
        var js = json
        js["callback"] = key
        callbacks[key] = callback
        if (send(json: js)) {
            return true;
        }
        callbacks[key] = callback
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
                webSocket?.send(jsonData)
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
