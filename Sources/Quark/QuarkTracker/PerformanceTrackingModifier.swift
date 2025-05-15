//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

public struct PerformanceTrackingModifier: ViewModifier {
    let id: String
    let file: String
    let line: Int
    
    public func body(content: Content) -> some View {
        TestContext.shared.recordRecomputation(id: id, file: file, line: line)
        return content
    }
}

extension View {
    public func trackRecomputations(id: String, file: String = #file, line: Int = #line) -> some View {
        modifier(PerformanceTrackingModifier(id: id, file: file, line: line))
    }
}
