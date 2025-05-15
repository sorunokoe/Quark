//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

// Add the ViewModifier for tracking recomputations
public struct TrackRecomputationsModifier: ViewModifier {
    let id: String
    let file: String
    let line: Int
    
    public init(id: String, file: String, line: Int) {
        self.id = id
        self.file = file
        self.line = line
    }
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                print("View recomputation tracked - ID: \(id), File: \(file), Line: \(line)")
            }
    }
}

public extension View {
    func trackRecomputations(id: String, file: String, line: Int) -> some View {
        modifier(TrackRecomputationsModifier(id: id, file: file, line: line))
    }
}
