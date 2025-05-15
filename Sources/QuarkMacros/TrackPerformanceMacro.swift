//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftUI

public struct TrackPerformanceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self),
              structDecl.inheritanceClause?.inheritedTypes.contains(where: { $0.type.description == "View" }) == true else {
            throw MacroError.notAView
        }
        
        // Find the body property
        guard let bodyDecl = structDecl.members.members.first(where: { member in
            member.decl.as(VariableDeclSyntax.self)?.bindings.contains(where: { $0.pattern.description == "body" }) == true
        })?.decl.as(VariableDeclSyntax.self),
              let bodyAccessor = bodyDecl.bindings.first?.accessorBlock?.accessors.as(CodeBlockSyntax.self) else {
            throw MacroError.noBodyFound
        }
        
        // Extract dependencies (e.g., @State, @Binding, @ObservedObject)
        var dependencies: [String] = []
        for member in structDecl.members.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       varDecl.attributes.contains(where: { attr in
                           attr.description.contains("@State") ||
                           attr.description.contains("@Binding") ||
                           attr.description.contains("@ObservedObject")
                       }) {
                        dependencies.append(pattern.identifier.text)
                    }
                }
            }
        }
        
        // Transform the body and collect metadata
        var metadata: [(id: String, file: String, line: Int, deps: [String])] = []
        let transformedBody = try transformBody(
            bodyAccessor,
            structName: structDecl.name.text,
            dependencies: dependencies,
            metadata: &metadata,
            context: context
        )
        
        // Create new body declaration
        let newBodyDecl = try VariableDeclSyntax(
            bindingSpecifier: .keyword(.var),
            bindings: [
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("body")),
                    typeAnnotation: TypeAnnotationSyntax(type: SomeOrAnyTypeSyntax(someOrAnySpecifier: .keyword(.some), constraint: TypeSyntax(stringLiteral: "View"))),
                    accessorBlock: AccessorBlockSyntax(
                        leftBrace: .leftBraceToken(),
                        accessors: .getter(CodeBlockItemListSyntax {
                            for statement in transformedBody.statements {
                                CodeBlockItemSyntax(item: statement.item)
                            }
                        }),
                        rightBrace: .rightBraceToken()
                    )
                )
            ]
        )
        
        // Generate metadata dictionary
        let metadataDict = try DictionaryExprSyntax {
            for entry in metadata {
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: entry.id),
                    value: ArrayExprSyntax(elements: ArrayElementListSyntax {
                        for dep in entry.deps {
                            ArrayElementSyntax(expression: StringLiteralExprSyntax(content: dep))
                        }
                    })
                )
            }
        }
        
        let metadataDecl = try VariableDeclSyntax(
            "static let performanceMetadata: [String: [String]] = \(metadataDict)"
        )
        
        return [DeclSyntax(newBodyDecl), DeclSyntax(metadataDecl)]
    }
    
    private static func transformBody(
        _ body: CodeBlockSyntax,
        structName: String,
        dependencies: [String],
        metadata: inout [(id: String, file: String, line: Int, deps: [String])],
        context: some MacroExpansionContext
    ) throws -> CodeBlockSyntax {
        var newStatements: [CodeBlockItemSyntax] = []
        var index = 0
        
        for item in body.statements {
            if let expr = item.item.as(ExprSyntax.self) {
                let (transformedExpr, usedDeps) = transformExpression(
                    expr,
                    structName: structName,
                    dependencies: dependencies,
                    index: index,
                    context: context
                )
                newStatements.append(CodeBlockItemSyntax(item: .expr(transformedExpr)))
                
                let file = context.location(of: expr)?.file.description ?? "<unknown>"
                let lineExpr = context.location(of: expr)?.line ?? ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
                let lineNumber = Int(lineExpr.description) ?? 0
                let id = generateUniqueID(expr: expr, structName: structName, index: index)
                metadata.append((id: id, file: file, line: lineNumber, deps: usedDeps))
                index += 1
            } else if let ifStmt = item.item.as(IfExprSyntax.self) {
                // Handle if statements by transforming their body
                let transformedIfStmt = try IfExprSyntax(
                    conditions: ifStmt.conditions,
                    body: transformBody(
                        ifStmt.body,
                        structName: structName,
                        dependencies: dependencies,
                        metadata: &metadata,
                        context: context
                    ),
                    elseKeyword: ifStmt.elseKeyword,
                    elseBody: ifStmt.elseBody.map { elseBody in
                        .codeBlock(try transformBody(
                            elseBody.as(CodeBlockSyntax.self)!,
                            structName: structName,
                            dependencies: dependencies,
                            metadata: &metadata,
                            context: context
                        ))
                    }
                )
                newStatements.append(CodeBlockItemSyntax(item: .expr(ExprSyntax(transformedIfStmt))))
                index += 1
            } else {
                newStatements.append(item)
            }
        }
        
        return CodeBlockSyntax(statements: CodeBlockItemListSyntax(newStatements))
    }
    
    private static func transformExpression(
        _ expr: ExprSyntax,
        structName: String,
        dependencies: [String],
        index: Int,
        context: some MacroExpansionContext
    ) -> (ExprSyntax, [String]) {
        // Extract dependencies used in this expression
        var usedDependencies: [String] = []
        func findDependencies(_ syntax: Syntax) {
            if let ident = syntax.as(IdentifierExprSyntax.self),
               dependencies.contains(ident.identifier.text) {
                usedDependencies.append(ident.identifier.text)
            }
            for child in syntax.children(viewMode: .sourceAccurate) {
                findDependencies(child)
            }
        }
        findDependencies(Syntax(expr))
        
        // Generate unique ID
        let id = generateUniqueID(expr: expr, structName: structName, index: index)
        let file = context.location(of: expr)?.file.description ?? "<unknown>"
        let lineExpr = context.location(of: expr)?.line ?? ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
        
        // Apply trackRecomputations modifier
        let transformed = ExprSyntax(
            """
            \(expr).trackRecomputations(id: "\(raw: id)", file: "\(raw: file)", line: \(lineExpr))
            """
        )
        
        return (transformed, Array(Set(usedDependencies)))
    }
    
    private static func generateUniqueID(expr: ExprSyntax, structName: String, index: Int) -> String {
        let typeName = expr.description.components(separatedBy: "(").first ?? "View"
        return "\(structName)_\(typeName)_\(index)"
    }
}

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

@main
struct QuarkMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TrackPerformanceMacro.self
    ]
}

// Add the ViewModifier for tracking recomputations
public struct TrackRecomputationsModifier: ViewModifier {
    let id: String
    let file: String
    let line: Int
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                print("View recomputation tracked - ID: \(id), File: \(file), Line: \(line)")
            }
    }
}

public extension View {
    func trackRecomputations(id: String, file: String, line: Int) -> some View {
        modifier(TrackRecomputationsModifier(id: id, file: file, line: line))
    }
}
