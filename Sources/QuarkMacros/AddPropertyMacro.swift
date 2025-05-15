import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public struct AddPropertyMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [
            """
            var greeting: String = "Hello from AddPropertyMacro!"
            """
        ]
    }
}
