//
//  SBDCustomInfo.swift
//  TableDatabase
//
//  Created by Lê Tấn Thắng on 6/8/18.
//  Copyright © 2018 david lopez. All rights reserved.
//

import Foundation

class SBDCustomInfo {
    var envKey: String;
    var viewerId: String;
    var videoUrl: String?;
    var videoId: String?;
    var videoTitle: String?;
    var videoSeries: String?;
    var videoDuration: String?;
    var videoAuthor: String?;
    var videoCdn: String?;
    var videoIsp: String?;
    init(envKey: String, viewerId: String) {
        self.envKey = envKey
        self.viewerId = viewerId
    }
    func getVideoInfo() -> [String: Any] {
        var obj = [String: Any]()
        var filter = [String: Any]()
        filter["author"] = videoAuthor
        filter["cdn"] = videoCdn
        filter["isp"] = videoIsp
        obj["url"] = videoUrl
        obj["id"] = videoId
        obj["title"] = videoTitle
        obj["series"] = videoSeries
        obj["duration"] = videoDuration
        obj["filter"] = filter
        return obj
    }
}
