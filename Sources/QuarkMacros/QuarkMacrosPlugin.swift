import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct QuarkMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        QuarkMacro.self
    ]
} 
