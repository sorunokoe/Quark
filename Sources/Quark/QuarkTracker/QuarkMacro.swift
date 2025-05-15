//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

@attached(member)
public macro TrackPerformance() = #externalMacro(module: "QuarkMacros", type: "TrackPerformanceMacro")
