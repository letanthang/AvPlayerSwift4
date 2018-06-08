//
//  Bundle+ReleaseInfo.swift
//  TableDatabase
//
//  Created by Lê Tấn Thắng on 6/8/18.
//  Copyright © 2018 david lopez. All rights reserved.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var releaseVersionNumberPretty: String {
        return "v\(releaseVersionNumber ?? "1.0.0")"
    }
}
