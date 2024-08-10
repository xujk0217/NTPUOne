//
//  extention.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import Foundation
import Swift

extension String {
    func substring(from: Int, length: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: length)
        return String(self[start..<end])
    }
    func substring(from: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        return String(self[start...])
    }
}
