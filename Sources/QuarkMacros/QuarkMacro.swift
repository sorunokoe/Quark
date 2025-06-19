import SwiftSyntax
import SwiftSyntaxMacros

public struct QuarkMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Get the view expression from the macro arguments
        guard let viewExpr = node.argumentList.last?.expression else {
            throw MacroError.noViewExpression
        }
        
        // Simply return the view expression without any transformations
        return viewExpr
    }
}

// MARK: - Errors
enum MacroError: Error, CustomStringConvertible {
    case noViewExpression
    
    var description: String {
        switch self {
        case .noViewExpression:
            return "No view expression provided to Quark macro"
        }
    }
} 
