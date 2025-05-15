import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct QuarkMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AddPropertyMacro.self,
        HelloMacro.self,
        TrackPerformanceMacro.self
    ]
} 