//
//  SBDAnalyzer.swift
//  TableDatabase
//
//  Created by Thang Le Tan on 6/5/18.
//  Copyright © 2018 david lopez. All rights reserved.
//

import UIKit
import AVKit

class SBDAnalyzer: NSObject {
    var playerLayer: AVPlayerLayer?
    var playerVC: AVPlayerViewController?
    var player: AVPlayer?
    
    static let shared = SBDAnalyzer()
    
    private override init() {
        super.init()
    }
    
    public func setupABC(playerLayer: AVPlayerLayer) {
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
        case "playbackBufferFull":
            print("end buffering")
        default:
            print(keyPath)
        }
        
    }
    
}
