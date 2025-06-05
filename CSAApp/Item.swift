//
//  Item.swift
//  CSAApp
//
//  Created by 飯森毅 on 2025/06/05.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
