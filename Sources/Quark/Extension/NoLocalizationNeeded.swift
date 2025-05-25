//
//  SwiftUIView.swift
//  Quark
//
//  Created by Yeskendir Salgara on 25/05/2025.
//

import SwiftUI

public struct NoLocalizationNeeded: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
    }
}

public extension View {
    func noLocalizationNeeded() -> some View {
        modifier(NoLocalizationNeeded())
    }
}
