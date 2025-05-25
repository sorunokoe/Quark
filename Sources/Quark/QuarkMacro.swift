//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

@attached(member, names: arbitrary)
public macro QuarkLocalize() = #externalMacro(module: "QuarkMacros", type: "QuarkLocalizeMacro")

