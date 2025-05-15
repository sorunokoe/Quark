//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

//@attached(member)
@freestanding(expression)
public macro TrackPerformance() = #externalMacro(module: "QuarkMacros", type: "TrackPerformanceMacro")

@freestanding(expression)
public macro Hello() = #externalMacro(module: "QuarkMacros", type: "HelloMacro")
