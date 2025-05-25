import SwiftSyntax
import SwiftSyntaxMacros

public struct QuarkLocalizeMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Add a static property to store string information
        return [
            """
            static var _quarkStringInfo: [(value: String, line: Int, context: String)] = []
            """
        ]
    }
}

// Extension to handle View protocol conformance
extension QuarkLocalizeMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Find the body property
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAView
        }
        
        var stringInfo: [(value: String, line: Int, context: String)] = []
        
        // Find the body property
        for member in structDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       pattern.identifier.text == "body" {
                        // Transform the body
                        if let accessorBlock = binding.accessorBlock {
                            let transformedBody = try transformBody(
                                accessorBlock,
                                stringInfo: &stringInfo,
                                context: context
                            )
                            
                            // Create the extension with the transformed body
                            return [
                                try ExtensionDeclSyntax(
                                    extendedType: type,
                                    memberBlock: MemberBlockSyntax {
                                        MemberBlockItemSyntax(
                                            decl: VariableDeclSyntax(
                                                bindingSpecifier: .keyword(.var),
                                                bindings: [
                                                    PatternBindingSyntax(
                                                        pattern: pattern,
                                                        typeAnnotation: binding.typeAnnotation,
                                                        accessorBlock: transformedBody
                                                    )
                                                ]
                                            )
                                        )
                                    }
                                )
                            ]
                        }
                    }
                }
            }
        }
        
        throw MacroError.noBodyFound
    }
    
    private static func transformBody(
        _ body: AccessorBlockSyntax,
        stringInfo: inout [(value: String, line: Int, context: String)],
        context: some MacroExpansionContext
    ) throws -> AccessorBlockSyntax {
        var newStatements: [CodeBlockItemSyntax] = []
        
        for statement in body.accessors.children(viewMode: .sourceAccurate) {
            if let item = statement.as(CodeBlockItemSyntax.self) {
                if let expr = item.item.as(ExprSyntax.self) {
                    let (transformedExpr, newStringInfo) = try transformExpression(
                        expr,
                        context: context
                    )
                    stringInfo.append(contentsOf: newStringInfo)
                    newStatements.append(CodeBlockItemSyntax(item: .expr(transformedExpr)))
                } else {
                    newStatements.append(item)
                }
            }
        }
        
        return AccessorBlockSyntax(
            leftBrace: body.leftBrace,
            accessors: .getter(CodeBlockItemListSyntax(newStatements)),
            rightBrace: body.rightBrace
        )
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
    case notAView
    case noBodyFound
    
    var description: String {
        switch self {
        case .notAView: return "Macro can only be applied to structs conforming to View"
        case .noBodyFound: return "View must have a body property"
        }
    }
}
