import SwiftSyntax
import SwiftSyntaxMacros

public struct QuarkLocalizeMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Get the view expression from the macro arguments
        guard let viewExpr = node.argumentList.first?.expression else {
            throw MacroError.noViewExpression
        }
        
        // Transform the view expression to handle string localization
        let (transformedExpr, _) = try transformExpression(viewExpr, context: context)
        
        return transformedExpr
    }
    
    private static func transformExpression(
        _ expr: ExprSyntax,
        context: some MacroExpansionContext
    ) throws -> (ExprSyntax, [(value: String, line: Int, context: String)]) {
        var stringInfo: [(value: String, line: Int, context: String)] = []
        
        func transform(_ syntax: Syntax) -> Syntax {
            if let stringLiteral = syntax.as(StringLiteralExprSyntax.self) {
                let value = stringLiteral.segments.description
                let lineExpr = context.location(of: stringLiteral)?.line ?? ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
                let line = Int(lineExpr.description) ?? 0
                let context = context.location(of: stringLiteral)?.file.description ?? "<unknown>"
                
                stringInfo.append((value: value, line: line, context: context))
                
                // Transform the string literal into a localized version
                let localizedString = FunctionCallExprSyntax(
                    calledExpression: ExprSyntax("NSLocalizedString"),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(
                            expression: stringLiteral
                        )
                        LabeledExprSyntax(
                            label: "comment",
                            expression: StringLiteralExprSyntax(content: "Localized string from \(context):\(line)")
                        )
                    },
                    rightParen: .rightParenToken()
                )
                
                return Syntax(localizedString)
            }
            
            // Create a new syntax node with transformed children
            var transformedChildren: [Syntax] = []
            for child in syntax.children(viewMode: .sourceAccurate) {
                transformedChildren.append(transform(child))
            }
            
            // Create a new syntax node with the transformed children
            if let expr = syntax.as(ExprSyntax.self) {
                if let functionCall = expr.as(FunctionCallExprSyntax.self) {
                    return Syntax(functionCall)
                } else if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
                    return Syntax(memberAccess)
                } else if let identifier = expr.as(IdentifierExprSyntax.self) {
                    return Syntax(identifier)
                }
            }
            
            return syntax
        }
        
        let result = ExprSyntax(transform(Syntax(expr)))!
        return (result, stringInfo)
    }
}

// MARK: - Errors
enum MacroError: Error, CustomStringConvertible {
    case noViewExpression
    
    var description: String {
        switch self {
        case .noViewExpression: return "No view expression provided to QuarkLocalize macro"
        }
    }
}
