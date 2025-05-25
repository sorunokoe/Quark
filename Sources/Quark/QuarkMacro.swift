//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

@freestanding(expression)
public macro QuarkLocalize<T: View>(_ view: T) -> T = #externalMacro(module: "QuarkMacros", type: "QuarkLocalizeMacro")

