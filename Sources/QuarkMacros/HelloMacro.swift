import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public struct HelloMacro: ExpressionMacro {
    public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> SwiftSyntax.ExprSyntax {
        return "print(\"Hello from macro!\")"
    }
}

//@main
//struct HelloMacrosPlugin: CompilerPlugin {
//    let providingMacros: [Macro.Type] = [
//        HelloMacro.self
//    ]
//} 
