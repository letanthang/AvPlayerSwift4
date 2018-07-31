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
    var sessionReady = false
    var customInfo: SBDCustomInfo?
    private var viewInited = false
    
    static let shared = SBDAnalyzer()
    
    var playing: Bool = false
    var buffering: Bool = false
    var lastActive: Double = 0
    var lastPauseTime: Double = 0
    var hasStartup = false
    var lastPlayPosition: Double = 0
    var endView = false
    let wsUrl = "ws://ws.sa.sbd.vn:8080"
    
    var workerTimer: Timer! = nil
    var notSendCount = 0
    
    var visitorId: String! = nil
    var configEnabled = false;
    var checked = false;
    
    private override init() {
        super.init()
        //webSocket = SRWebSocket(url: URL(string: "ws://ws.stag-sa.sbd.vn:10080"))
        checkConfigEnabled()
        getVisitor()
        let os = "iOS"
        let osVersion = UIDevice.current.systemVersion
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        let appVersion = Bundle.main.releaseVersionNumberPretty;
        let deviceType = "phone"
        let device = UIDevice.current.name
        let userAgent = sdkName + "/" + sdkVersion + " " + os + "/" + osVersion + " "
            + appName + "/" + appVersion + " " + deviceType + "/" + device;
        
        var request = URLRequest(url: URL(string: wsUrl)!)
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
    
    func setCustomInfo(customInfo: SBDCustomInfo) {
        self.customInfo = customInfo
    }
    @objc func playerDidFinishPlaying(note: NSNotification) {
        endVideo()
    }
    func observerPlayer() {
        
        NotificationCenter.default.addObserver(self, selector:#selector(playerDidFinishPlaying(note:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        
        
        
        player?.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
        loadPlayer()
        startSendWorker()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath {
        case "rate":
            if ((player?.rate)! > 0.999) {
                realPlayVideo()
            } else if ((player?.rate)! < 0.001) {
                pauseVideo()
            }
        case "playbackBufferEmpty":
            bufferVideo()
        case "playbackLikelyToKeepUp":
            if (player?.currentItem?.status == AVPlayerItemStatus.readyToPlay) {
                if buffering { resumeVideo() }
            } else if (player?.currentItem?.status == AVPlayerItemStatus.failed) {
                print("sbd_failed")
            } else if (player?.currentItem?.status == AVPlayerItemStatus.unknown) {
                print("sbd_unknown")
            } else {
                print("sbd_abcxy")
            }
            
        case "playbackBufferFull":
            print("sbd_playbackBufferFull")
            //realPlayVideo()
        default:
            print("sbd_" + (keyPath)!)
        }
    }
    
    func onWSConnected() {
        if (configEnabled) {
            initWS()
            initView()
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
                    self.sessionReady = true
                }
            }
        }
    }
    
    func initView() {
        guard viewInited == false else {
            return
        }
        viewInited = true
        print("sbd_" + "initView")
        var data = [String: Any]()
        data["envKey"] = customInfo?.envKey
        data["viewerId"] = customInfo?.viewerId
        data["playUrl"] = customInfo?.videoUrl
        data["video"] = customInfo?.getVideoInfo()
        var json = [String: Any]()
        //json["data"] = data
        json["type"] = "initView"
        let tmp = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        json["data"] = String(data: tmp!, encoding: .utf8)
        _ = send(json: json, callback: { (response: String) in
            if let responseData = response.data(using: .utf8, allowLossyConversion: false) {
                let responseJSON = try? JSON(data: responseData)
                if let status = responseJSON?["status"].string, status == "OK" {
                    print("sbd_" + "initView success")
                    self.viewId = responseJSON?["data"][0]["id"].string
                    if self.afterInitQueue.count > 0 {
                        self.sendAfterInitQueue()
                    }
                }
            }
            
        })
    }
    func loadPlayer() {
        var data = [String: Any]()
        data["eventName"] = "PLAYER_LOAD"
        _ = sendViewEvent(eventData: data)
    }
    func playVideo() {
//        playing = true
        buffering = false
        lastActive = Date().timeIntervalSince1970
        
        var data = [String: Any]()
        data["eventName"] = "PLAY"
        _ = sendViewEvent(eventData: data)
    }
    func pauseVideo() {
        playing = false
        lastPauseTime = (player?.currentItem?.currentTime().seconds)!
        var data = [String: Any]()
        data["eventName"] = "PAUSE"
        data["playPosition"] = lastPauseTime
        _ = sendViewEvent(eventData: data)
    }
    func unPauseVideo() {
        playing = true
        buffering = false
        lastActive = Date().timeIntervalSince1970
        var data = [String: Any]()
        data["eventName"] = "PAUSE"
        data["playPosition"] = player?.currentItem?.currentTime().seconds
        _ = sendViewEvent(eventData: data)
    }
    func realPlayVideo() {
        
        var data = [String: Any]()
        data["eventName"] = "PLAYING"
        data["playPosition"] = player?.currentItem?.currentTime().seconds
        let startupTime: Double = (Date().timeIntervalSince1970 - lastActive) / 1000.0
        data["data"] = startupTime
        
        playing = true
        hasStartup = true
        lastActive = 0
        _ = sendViewEvent(eventData: data)
    }
    func bufferVideo() {
        buffering = true
        lastActive = Date().timeIntervalSince1970
        lastPlayPosition = (player?.currentItem?.currentTime().seconds)!
        var data = [String: Any]()
        data["eventName"] = "BUFFERING"
        data["lastPlayPosition"] = lastPlayPosition
        _ = sendViewEvent(eventData: data)
    }
    func resumeVideo() {
        var data = [String: Any]()
        data["eventName"] = "SEEKED"
        _ = sendViewEvent(eventData: data)
        buffering = false
    }
    
    func endVideo() {
        var data = [String: Any]()
        data["eventName"] = "END"
        
        sendViewEvent(eventData: data)
        lastPlayPosition = 0
        playing = false
        buffering = true
        viewId = nil
        endView = true
    }
    func changeSize(width: Int, height: Int) {
        var infos = [String: Any]()
        infos["playerWidth"] = width
        infos["playerHeight"] = height
        infos["videoWidth"] = width
        infos["videoHeight"] = height
        
        var data = [String: Any]()
        data["eventName"] = "DIMENSION"
        data["infos"] = infos
        _ = sendViewEvent(eventData: data)
        
    }
    
}

extension SBDAnalyzer: SRWebSocketDelegate {
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("sbd_" + "open: you are connected to server: " + webSocket.url.absoluteString)
        onWSConnected()
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
            guard configEnabled else {
                return false
            }
            let arr = [ json ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted) {
                let jsonString = String(data: jsonData, encoding: .utf8)
                webSocket?.send(jsonString)
                print("sbd_" + "send initWS " + jsonString!)
            }
        } else {
            guard configEnabled || !self.checked else {
                return false;
            }
            print("sbd_" + "add to queue: " + type)
            queue.append(json)
            startSendWorker()
        }
        return true
    }
    
    func sendViewEvent(eventData: [String: Any]) -> Bool {
        guard configEnabled || !checked else {
            return false;
        }
        
        var data = eventData;
        do {
            print("sbd_" + (eventData["eventName"] as! String));
            if (data["date"] == nil) {
                data["date"] = getUTCDate()
            }
            if (data["playPosition"] == nil) {
                data["playPosition"] = player?.currentItem?.currentTime().seconds
            }
            var json = [String: Any]()
            json["type"] = "event"
            
            if let viewId = viewId {
                data["viewId"] = viewId
                let tmp = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                json["data"] = String(data: tmp, encoding: .utf8)
                return send(json: json)
            } else {
                json["data"] = data
                afterInitQueue.append(json)
            }
            
        } catch {
            print("Error : \(error)")
            return false
        }
        return true
    }
    
    func sendAfterInitQueue() {
        do {
            for i in 0...afterInitQueue.count - 1 {
                var json = afterInitQueue[i]
                var data: [String: Any] = json["data"] as! [String : Any]
                
                data["viewId"] = viewId
                json.removeValue(forKey: "data")
                //json["data"] = data
                let tmp = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                json["data"] = String(data: tmp, encoding: .utf8)
            }
            sendArray(arr: afterInitQueue)
            afterInitQueue = [[String: Any]]()
        } catch {
            print("Error : \(error)")
        }
        
    }
    
    func sendArray(arr: [[String: Any]]) {
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted) {
            let jsonString = String(data: jsonData, encoding: .utf8)
            webSocket?.send(jsonString)
            print("sbd_" + "sendArray " + jsonString!)
        }
    }
    func startSendWorker() {
        guard workerTimer == nil else {
            return
        }
        print("sbd_" + "start sworker")
        workerTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(sendWorker), userInfo: nil, repeats: true)
        
    }
    func stopSendWorker() {
        guard let _ = workerTimer else {
            return
        }
        workerTimer.invalidate()
        workerTimer = nil
    }
    @objc func sendWorker() {
        print("sbd_" + "send worker " + String(notSendCount))
        
        guard queue.count > 0 && webSocket?.readyState == SRReadyState.OPEN && sessionReady else {
            notSendCount += 1
            if queue.count == 0 {
                print("sbd_" + "queue has nothing to send")
            } else {
                print("queue not send: websocket or session not ready")
            }
            
            
            if notSendCount >= 30 {
                stopSendWorker()
            }
            if notSendCount >= 20 && webSocket?.readyState != SRReadyState.OPEN {
                webSocket?.open()
            }
            return
        }
        notSendCount = 0
        print("sbd_" + "send worker data")
        sendArray(arr: queue)
        queue = [[String: Any]]()
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

extension SBDAnalyzer {
    func getVisitor() {
        if visitorId != nil {
            return
        }
        loadVisitor()
        if visitorId != nil {
            return
        }
        let todoEndpoint: String = "http://api.sa.sbd.vn/visitor"
        guard let url = URL(string: todoEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        let urlRequest = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: urlRequest) { (data, urlResponse, error) in
            if let error = error {
                print(error.localizedDescription);
                return;
            }
            if let data = data {
                let responseJSON = try? JSON(data: data)
                if let status = responseJSON?["status"].string, status == "OK" {
                    self.visitorId = responseJSON?["data"][0]["id"].string
                    self.saveVisitor(visitorId: self.visitorId)
                }
            }
        }
        task.resume();
    }
    
    func loadVisitor() {
        if let vId = UserDefaults.standard.value(forKey: "visitorId") as? String {
            self.visitorId = vId
        }
    }
    
    func saveVisitor(visitorId: String) {
        UserDefaults.standard.set(visitorId, forKey: "visitorId")
    }
    
    func checkConfigEnabled() {
        let todoEndpoint: String = "http://api.thvli.vn/backend/cm/tracking/config/"
        guard let url = URL(string: todoEndpoint) else {
            print("Error: cannot create URL")
            return
        }
        let urlRequest = URLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: urlRequest) { (data, urlResponse, error) in
            if let error = error {
                print(error.localizedDescription);
                return;
            }
            if let data = data {
                let responseJSON = try? JSON(data: data)
                let lastConfigEnabled = self.configEnabled
                self.configEnabled = (responseJSON?["enable"].bool)! && (responseJSON?["partners"]["qos"].bool)!
                self.configEnabled = true
                self.checked = true;
                if !lastConfigEnabled && self.configEnabled && self.webSocket?.readyState == SRReadyState.OPEN {
                    self.onWSConnected()
                }
            }
        }
        task.resume();
    }
}

