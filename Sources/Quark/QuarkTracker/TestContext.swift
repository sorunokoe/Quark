//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import Foundation

@MainActor
public final class TestContext {
    public static let shared = TestContext()
    
    var recomputeCounts: [String: (count: Int, file: String, line: Int)] = [:]
    
    private init() {}
    
    public func recordRecomputation(id: String, file: String, line: Int) {
        let currentCount = recomputeCounts[id]?.count ?? 0
        recomputeCounts[id] = (count: currentCount + 1, file: file, line: line)
    }
    
    public func reset() {
        recomputeCounts = [:]
    }
    
    public func getRecomputeCounts() -> [String: (count: Int, file: String, line: Int)] {
        return recomputeCounts
    }
}
