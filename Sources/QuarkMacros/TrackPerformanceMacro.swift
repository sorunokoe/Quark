//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//


import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import Foundation

// MARK: - TrackPerformanceMacro
public struct TrackPerformanceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate view structure
        let structDecl = try validateViewStructure(declaration)
        
        // Extract view components
        let (bodyDecl, bodyAccessor) = try extractBodyProperty(structDecl)
        let dependencies = extractDependencies(structDecl)
        
        // Transform view
        let (transformedBody, metadata) = try transformView(
            bodyAccessor,
            structName: structDecl.name.text,
            dependencies: dependencies,
            context: context
        )
        
        // Generate metadata and dependencies declarations
        let metadataDecl = try generateMetadataDeclaration(metadata)
        let dependenciesDecl = try generateDependenciesDeclaration(dependencies)
        
        // Return only metadata and dependencies
        return [DeclSyntax(metadataDecl), DeclSyntax(dependenciesDecl)]
    }
}

// MARK: - View Structure Validation
private extension TrackPerformanceMacro {
    static func validateViewStructure(_ declaration: some DeclGroupSyntax) throws -> StructDeclSyntax {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAView
        }
        
        // Check if the struct conforms to View
        let conformsToView = structDecl.inheritanceClause?.inheritedTypes.contains { type in
            type.type.trimmedDescription == "View"
        } ?? false
        
        guard conformsToView else {
            throw MacroError.notAView
        }
        
        return structDecl
    }
}

// MARK: - Body Property Extraction
private extension TrackPerformanceMacro {
    static func extractBodyProperty(_ structDecl: StructDeclSyntax) throws -> (VariableDeclSyntax, CodeBlockSyntax) {
        print("DEBUG: Analyzing struct: \(structDecl.name.text)")
        
        // Find the body property
        let members = structDecl.memberBlock.members
        print("DEBUG: Found \(members.count) members")
        
        for member in members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       pattern.identifier.text == "body" {
                        print("DEBUG: Found body property")
                        print("DEBUG: Type annotation: \(binding.typeAnnotation?.type.description ?? "none")")
                        
                        if let accessorBlock = binding.accessorBlock {
                            print("DEBUG: Accessor block: \(accessorBlock.description)")
                            
                            // Create a code block from the accessor block's content
                            let statements = CodeBlockItemListSyntax {
                                for statement in accessorBlock.accessors.children(viewMode: .sourceAccurate) {
                                    if let item = statement.as(CodeBlockItemSyntax.self) {
                                        item
                                    }
                                }
                            }
                            let codeBlock = CodeBlockSyntax(statements: statements)
                            return (varDecl, codeBlock)
                        }
                    }
                }
            }
        }
        
        throw MacroError.noBodyFound
    }
}

// MARK: - Dependency Extraction
private extension TrackPerformanceMacro {
    static func extractDependencies(_ structDecl: StructDeclSyntax) -> [(name: String, type: String, wrapper: String)] {
        var dependencies: [(name: String, type: String, wrapper: String)] = []
        
        for member in structDecl.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                       let typeAnnotation = binding.typeAnnotation?.type,
                       let wrapper = extractPropertyWrapper(varDecl)
                    {
                        dependencies.append((
                            name: pattern.identifier.text,
                            type: typeAnnotation.description,
                            wrapper: wrapper
                        ))
                    }
                }
            }
        }
        
        return dependencies
    }
    
    static func extractPropertyWrapper(_ varDecl: VariableDeclSyntax) -> String? {
        varDecl.attributes.first(where: { attr in
            attr.description.contains("@State") ||
            attr.description.contains("@Binding") ||
            attr.description.contains("@ObservedObject") ||
            attr.description.contains("@Environment") ||
            attr.description.contains("@EnvironmentObject")
        })?.description
    }
}

// MARK: - View Transformation
private extension TrackPerformanceMacro {
    static func transformView(
        _ body: CodeBlockSyntax,
        structName: String,
        dependencies: [(name: String, type: String, wrapper: String)],
        context: some MacroExpansionContext
    ) throws -> (CodeBlockSyntax, [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)]) {
        var metadata: [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)] = []
        let transformedBody = try transformBody(
            body,
            structName: structName,
            dependencies: dependencies,
            metadata: &metadata,
            context: context
        )
        return (transformedBody, metadata)
    }
    
    static func transformBody(
        _ body: CodeBlockSyntax,
        structName: String,
        dependencies: [(name: String, type: String, wrapper: String)],
        metadata: inout [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)],
        context: some MacroExpansionContext
    ) throws -> CodeBlockSyntax {
        var newStatements: [CodeBlockItemSyntax] = []
        var index = 0
        
        for item in body.statements {
            if let expr = item.item.as(ExprSyntax.self) {
                let transformedItem = try transformExpression(
                    expr,
                    structName: structName,
                    dependencies: dependencies,
                    index: index,
                    metadata: &metadata,
                    context: context
                )
                newStatements.append(transformedItem)
                index += 1
            } else if let ifStmt = item.item.as(IfExprSyntax.self) {
                let transformedIfStmt = try transformIfStatement(
                    ifStmt,
                    structName: structName,
                    dependencies: dependencies,
                    metadata: &metadata,
                    context: context
                )
                newStatements.append(CodeBlockItemSyntax(item: .expr(ExprSyntax(transformedIfStmt))))
                index += 1
            } else {
                newStatements.append(item)
            }
        }
        
        return CodeBlockSyntax(statements: CodeBlockItemListSyntax(newStatements))
    }
    
    static func transformExpression(
        _ expr: ExprSyntax,
        structName: String,
        dependencies: [(name: String, type: String, wrapper: String)],
        index: Int,
        metadata: inout [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)],
        context: some MacroExpansionContext
    ) throws -> CodeBlockItemSyntax {
        let (transformedExpr, usedDeps, viewType, isContainer) = analyzeExpression(
            expr,
            structName: structName,
            dependencies: dependencies,
            index: index,
            context: context
        )
        
        let file = context.location(of: expr)?.file.description ?? "<unknown>"
        let lineExpr = context.location(of: expr)?.line ?? ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
        let lineNumber = Int(lineExpr.description) ?? 0
        let id = generateUniqueID(expr: expr, structName: structName, index: index)
        
        metadata.append((
            id: id,
            file: file,
            line: lineNumber,
            deps: usedDeps,
            viewType: viewType,
            isContainer: isContainer
        ))
        
        return CodeBlockItemSyntax(item: .expr(transformedExpr))
    }
    
    static func transformIfStatement(
        _ ifStmt: IfExprSyntax,
        structName: String,
        dependencies: [(name: String, type: String, wrapper: String)],
        metadata: inout [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)],
        context: some MacroExpansionContext
    ) throws -> IfExprSyntax {
        try IfExprSyntax(
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
                try .codeBlock(transformBody(
                    elseBody.as(CodeBlockSyntax.self)!,
                    structName: structName,
                    dependencies: dependencies,
                    metadata: &metadata,
                    context: context
                ))
            }
        )
    }
}

// MARK: - Expression Analysis
private extension TrackPerformanceMacro {
    static func analyzeExpression(
        _ expr: ExprSyntax,
        structName: String,
        dependencies: [(name: String, type: String, wrapper: String)],
        index: Int,
        context: some MacroExpansionContext
    ) -> (ExprSyntax, [String], String, Bool) {
        let (usedDeps, viewType, isContainer) = analyzeViewStructure(expr, dependencies: dependencies)
        let id = generateUniqueID(expr: expr, structName: structName, index: index)
        let file = context.location(of: expr)?.file.description ?? "<unknown>"
        let lineExpr = context.location(of: expr)?.line ?? ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
        
        let transformed = ExprSyntax(
            """
            \(expr).trackRecomputations(id: "\(raw: id)", file: "\(raw: file)", line: \(lineExpr))
            """
        )
        
        return (transformed, usedDeps, viewType, isContainer)
    }
    
    static func analyzeViewStructure(
        _ expr: ExprSyntax,
        dependencies: [(name: String, type: String, wrapper: String)]
    ) -> ([String], String, Bool) {
        var usedDependencies: [String] = []
        var viewType = "Unknown"
        var isContainer = false
        
        func findDependencies(_ syntax: Syntax) {
            if let ident = syntax.as(IdentifierExprSyntax.self),
               dependencies.contains(where: { $0.name == ident.identifier.text })
            {
                usedDependencies.append(ident.identifier.text)
            }
            
            if let functionCall = syntax.as(FunctionCallExprSyntax.self) {
                let name = functionCall.calledExpression.description
                if ["VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "List", "ForEach"].contains(name) {
                    isContainer = true
                }
                viewType = name
            }
            
            for child in syntax.children(viewMode: .sourceAccurate) {
                findDependencies(child)
            }
        }
        
        findDependencies(Syntax(expr))
        return (Array(Set(usedDependencies)), viewType, isContainer)
    }
}

// MARK: - Declaration Generation
private extension TrackPerformanceMacro {
    static func generateDeclarations(
        transformedBody: CodeBlockSyntax,
        metadata: [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)],
        dependencies: [(name: String, type: String, wrapper: String)]
    ) throws -> [DeclSyntax] {
        let bodyDecl = try generateBodyDeclaration(transformedBody)
        let metadataDecl = try generateMetadataDeclaration(metadata)
        let dependenciesDecl = try generateDependenciesDeclaration(dependencies)
        let triggerDecls = try generateDependencyTriggers(dependencies)
        
        return [DeclSyntax(bodyDecl), DeclSyntax(metadataDecl), DeclSyntax(dependenciesDecl)] + triggerDecls
    }
    
    static func generateBodyDeclaration(_ transformedBody: CodeBlockSyntax) throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
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
    }
    
    static func generateMetadataDeclaration(_ metadata: [(id: String, file: String, line: Int, deps: [String], viewType: String, isContainer: Bool)]) throws -> VariableDeclSyntax {
        var metadataElements: [DictionaryElementSyntax] = []
        
        for entry in metadata {
            let depsArray = ArrayExprSyntax(elements: ArrayElementListSyntax {
                for dep in entry.deps {
                    ArrayElementSyntax(expression: StringLiteralExprSyntax(content: dep))
                }
            })
            
            let innerDict = DictionaryExprSyntax {
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: "dependencies"),
                    value: depsArray
                )
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: "viewType"),
                    value: StringLiteralExprSyntax(content: entry.viewType)
                )
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: "isContainer"),
                    value: BooleanLiteralExprSyntax(literal: .keyword(entry.isContainer ? .true : .false))
                )
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: "file"),
                    value: StringLiteralExprSyntax(content: entry.file)
                )
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: "line"),
                    value: IntegerLiteralExprSyntax(literal: .integerLiteral(String(entry.line)))
                )
            }
            
            metadataElements.append(
                DictionaryElementSyntax(
                    key: StringLiteralExprSyntax(content: entry.id),
                    value: innerDict
                )
            )
        }
        
        let metadataDict = DictionaryExprSyntax {
            for element in metadataElements {
                element
            }
        }
        
        return try VariableDeclSyntax(
            "static let performanceMetadata: [String: [String: Any]] = \(metadataDict)"
        )
    }
    
    static func generateDependenciesDeclaration(_ dependencies: [(name: String, type: String, wrapper: String)]) throws -> VariableDeclSyntax {
        var dependencyElements: [ArrayElementSyntax] = []
        
        for dep in dependencies {
            let tupleExpr = TupleExprSyntax {
                LabeledExprSyntax(
                    label: "name",
                    expression: StringLiteralExprSyntax(content: dep.name)
                )
                LabeledExprSyntax(
                    label: "type",
                    expression: StringLiteralExprSyntax(content: dep.type)
                )
                LabeledExprSyntax(
                    label: "wrapper",
                    expression: StringLiteralExprSyntax(content: dep.wrapper)
                )
            }
            dependencyElements.append(ArrayElementSyntax(expression: tupleExpr))
        }
        
        let dependenciesArray = ArrayExprSyntax(elements: ArrayElementListSyntax {
            for element in dependencyElements {
                element
            }
        })
        
        return try VariableDeclSyntax(
            "static let trackedDependencies: [(name: String, type: String, wrapper: String)] = \(dependenciesArray)"
        )
    }
    
    static func generateDependencyTriggers(_ dependencies: [(name: String, type: String, wrapper: String)]) throws -> [DeclSyntax] {
        var triggerDecls: [DeclSyntax] = []
        
        for dep in dependencies {
            let triggerName = "trigger\(dep.name.prefix(1).uppercased() + dep.name.dropFirst())"
            let triggerFunc = try FunctionDeclSyntax(
                """
                func \(raw: triggerName)() {
                    // Reset test context before triggering
                    TestContext.shared.reset()
                    
                    // Trigger the dependency based on its type
                    switch "\(raw: dep.type)" {
                    case "Int":
                        if var value = self.\(raw: dep.name) as? Int {
                            value += 1
                            self.\(raw: dep.name) = value
                        }
                    case "Bool":
                        if var value = self.\(raw: dep.name) as? Bool {
                            value.toggle()
                            self.\(raw: dep.name) = value
                        }
                    case "String":
                        if var value = self.\(raw: dep.name) as? String {
                            value += "_modified"
                            self.\(raw: dep.name) = value
                        }
                    default:
                        print("Unsupported dependency type: \(raw: dep.type)")
                    }
                    
                    // Wait for UI update
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                """
            )
            triggerDecls.append(DeclSyntax(triggerFunc))
        }
        
        return triggerDecls
    }
}

// MARK: - Utilities
private extension TrackPerformanceMacro {
    static func generateUniqueID(expr: ExprSyntax, structName: String, index: Int) -> String {
        let typeName = expr.description.components(separatedBy: "(").first ?? "View"
        let sanitizedTypeName = typeName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return "\(structName)_\(sanitizedTypeName)_\(index)"
    }
}

// MARK: - Errors
enum MacroError: Error, CustomStringConvertible {
    case notAView
    case noBodyFound
    case invalidViewStructure
    
    var description: String {
        switch self {
        case .notAView: return "Macro can only be applied to structs conforming to View"
        case .noBodyFound: return "View must have a body property"
        case .invalidViewStructure: return "Invalid view structure detected"
        }
    }
}
