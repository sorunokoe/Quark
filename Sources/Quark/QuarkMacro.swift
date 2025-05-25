//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

@freestanding(expression)
public macro Quark<T: View>(_ parameters: [QuarkParameters], @ViewBuilder _ view: () -> T) -> T = #externalMacro(module: "QuarkMacros", type: "QuarkMacro")

public enum QuarkParameters {
    case localize
    case snapshot
}

