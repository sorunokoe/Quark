//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import Foundation
import PackagePlugin

@main
struct QuarkTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        print("[QuarkTestsPlugin] Plugin started for target: \(target.name)")
        
        // Get the test target that's using this plugin
        guard let testTarget = target as? SourceModuleTarget else {
            print("[QuarkTestsPlugin] Target is not a source module target")
            return []
        }
        
        // Find all targets that this test target depends on
        let testedTargets = findTestedTargets(in: context.package, for: testTarget)
        
        let targetNames = testedTargets.compactMap { $0 as? SourceModuleTarget }.map { $0.name }
        print("[QuarkTestsPlugin] Found tested targets: \(targetNames.joined(separator: ", "))")
        
        // Generate tests in the plugin's work directory
        let outputDir = context.pluginWorkDirectory.appending("GeneratedTests")
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: outputDir.string), withIntermediateDirectories: true)
        
        var commands: [Command] = []
        
        // Create a test file that will import all generated tests
        let testIndexContent = generateTestIndex(for: testedTargets)
        let testIndexPath = outputDir.appending("GeneratedTestsIndex.swift")
        try testIndexContent.write(to: URL(fileURLWithPath: testIndexPath.string), atomically: true, encoding: .utf8)
        
        // Add the index file to the output files
        commands.append(
            .buildCommand(
                displayName: "Generate tests index",
                executable: .init("/bin/echo"),
                arguments: ["Generated tests index"],
                outputFiles: [testIndexPath]
            )
        )
        
        // Keep track of which test files we generate
        var generatedTestFiles: Set<String> = []
        
        // Scan files in all tested targets
        for testedTarget in testedTargets {
            guard let sourceTarget = testedTarget as? SourceModuleTarget else { continue }
            
            print("[QuarkTestsPlugin] Scanning files in target: \(sourceTarget.name)")
            
            for file in sourceTarget.sourceFiles(withSuffix: ".swift") {
                print("[QuarkTestsPlugin] Checking file: \(file.url.path)")
                let content = try String(contentsOfFile: file.url.path)
                
                // Look for Quark macro usage
                guard content.contains("#Quark") else { continue }
                
                print("[QuarkTestsPlugin] Found Quark macro in: \(file.url.lastPathComponent)")
                
                // Extract view information and parameters
                let viewInfos = extractViewInfo(from: content)
                
                for viewInfo in viewInfos {
                    // Generate tests based on parameters
                    if viewInfo.parameters.contains(.localize) {
                        let generator = LocalizationTestGenerator()
                        let testContent = generator.generateTests(for: viewInfo, target: sourceTarget.name)
                        let testFileName = "\(viewInfo.name)L10nTests.swift"
                        let testFilePath = outputDir.appending(testFileName)
                        
                        try testContent.write(to: URL(fileURLWithPath: testFilePath.string), atomically: true, encoding: .utf8)
                        generatedTestFiles.insert(testFileName)
                        
                        commands.append(
                            .buildCommand(
                                displayName: "Generate localization tests for \(viewInfo.name)",
                                executable: .init("/bin/echo"),
                                arguments: ["Generated localization tests for \(viewInfo.name)"],
                                outputFiles: [testFilePath]
                            )
                        )
                    }
                    
                    if viewInfo.parameters.contains(.snapshot) {
                        let generator = SnapshotTestGenerator()
                        let testContent = generator.generateTests(for: viewInfo, target: sourceTarget.name)
                        let testFileName = "\(viewInfo.name)SnapshotTests.swift"
                        let testFilePath = outputDir.appending(testFileName)
                        
                        try testContent.write(to: URL(fileURLWithPath: testFilePath.string), atomically: true, encoding: .utf8)
                        generatedTestFiles.insert(testFileName)
                        
                        commands.append(
                            .buildCommand(
                                displayName: "Generate snapshot tests for \(viewInfo.name)",
                                executable: .init("/bin/echo"),
                                arguments: ["Generated snapshot tests for \(viewInfo.name)"],
                                outputFiles: [testFilePath]
                            )
                        )
                    }
                }
            }
        }
        
        return commands
    }
    
    private func generateTestIndex(for targets: [Target]) -> String {
        """
        import XCTest
        import SwiftUI
        
        // This file is automatically generated by QuarkTestsPlugin
        
        // This ensures all tests are included in the test target
        final class GeneratedTestsIndex: XCTestCase {
            func testGeneratedTestsAreIncluded() {
                XCTAssertTrue(true, "This test ensures all generated tests are included in the test target")
            }
        }
        """
    }
    
    private func findTestedTargets(in package: Package, for testTarget: SourceModuleTarget) -> [Target] {
        var testedTargets: [Target] = []
        
        // Get all dependencies of the test target
        for dependency in testTarget.dependencies {
            switch dependency {
            case .target(let target):
                // Find the target in the package
                if let target = package.targets.first(where: { $0.name == target.name }) {
                    testedTargets.append(target)
                }
            case .product(let target):
                // Find the product in the package
                if let product = package.products.first(where: { $0.name == target.name }),
                   let target = package.targets.first(where: { $0.name == product.name })
                {
                    testedTargets.append(target)
                }
            @unknown default:
                assertionFailure("Didn't expect to have dependency \(dependency)")
            }
        }
        
        return testedTargets
    }
    
    private func extractViewInfo(from content: String) -> [ViewInfo] {
        var viewInfos: [ViewInfo] = []
        let lines = content.components(separatedBy: .newlines)
        
        print("[QuarkTestsPlugin] Extracting view info from content with \(lines.count) lines")
        
        // First, find all struct definitions
        var structDefinitions: [(name: String, lineIndex: Int)] = []
        for (index, line) in lines.enumerated() {
            if line.contains("struct") && line.contains(": View") {
                let components = line.components(separatedBy: "struct")
                if components.count > 1 {
                    let nameComponent = components[1].components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
                    structDefinitions.append((name: nameComponent, lineIndex: index))
                    print("[QuarkTestsPlugin] Found struct definition: \(nameComponent) at line \(index)")
                }
            }
        }
        
        // Then process macro usages
        var currentMacroContent: String = ""
        var isCollectingMacroContent = false
        var parenthesesCount = 0
        var currentParameters: [QuarkParameters] = []
        
        for (index, line) in lines.enumerated() {
            if line.contains("#Quark") {
                print("[QuarkTestsPlugin] Found Quark macro in line: \(line)")
                isCollectingMacroContent = true
                currentMacroContent = ""
                parenthesesCount = 0
                
                // Extract parameters from the first line
                if let paramsRange = line.range(of: "\\[.*?\\]", options: .regularExpression) {
                    let paramsText = String(line[paramsRange])
                    print("[QuarkTestsPlugin] Found parameters text: \(paramsText)")
                    currentParameters = extractParameters(from: paramsText)
                }
                
                // Start collecting content after the opening brace
                if let braceIndex = line.range(of: "{")?.upperBound {
                    currentMacroContent = String(line[braceIndex...]).trimmingCharacters(in: .whitespaces)
                    parenthesesCount = 1
                }
            } else if isCollectingMacroContent {
                // Count braces
                parenthesesCount += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
                currentMacroContent += "\n" + line
                
                // If we've closed all braces, process the content
                if parenthesesCount == 0 {
                    print("[QuarkTestsPlugin] Completed macro content: \(currentMacroContent)")
                    
                    // Extract the view initialization
                    let initialization = currentMacroContent
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "^\\s*|\\s*$", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\}\\s*$", with: "", options: .regularExpression) // Remove trailing closing brace
                    
                    print("[QuarkTestsPlugin] Extracted initialization: \(initialization)")
                    
                    // Extract the view name from the initialization
                    if let viewName = initialization.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) {
                        print("[QuarkTestsPlugin] Looking for struct definition for view: \(viewName)")
                        
                        // Find the matching struct definition
                        if let structDef = structDefinitions.first(where: { $0.name == viewName }) {
                            print("[QuarkTestsPlugin] Found matching struct: \(structDef.name)")
                            viewInfos.append(ViewInfo(
                                name: structDef.name,
                                initialization: initialization,
                                parameters: currentParameters
                            ))
                        } else {
                            print("[QuarkTestsPlugin] No matching struct found for view: \(viewName)")
                        }
                    }
                    
                    isCollectingMacroContent = false
                    currentParameters = []
                }
            }
        }
        
        print("[QuarkTestsPlugin] Extracted view info: \(viewInfos)")
        return viewInfos
    }
    
    private func extractParameters(from text: String) -> [QuarkParameters] {
        var parameters: [QuarkParameters] = []
        
        // Extract parameters from array syntax
        if let range = text.range(of: "\\[.*?\\]", options: .regularExpression) {
            let paramsText = String(text[range])
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            print("[QuarkTestsPlugin] Extracting parameters from: \(paramsText)")
            
            let paramStrings = paramsText.components(separatedBy: ",")
            
            for param in paramStrings {
                let trimmedParam = param.trimmingCharacters(in: .whitespaces)
                print("[QuarkTestsPlugin] Processing parameter: \(trimmedParam)")
                
                if trimmedParam.contains(".localize") {
                    parameters.append(.localize)
                    print("[QuarkTestsPlugin] Added .localize parameter")
                }
                if trimmedParam.contains(".snapshot") {
                    parameters.append(.snapshot)
                    print("[QuarkTestsPlugin] Added .snapshot parameter")
                }
            }
        }
        
        print("[QuarkTestsPlugin] Extracted parameters: \(parameters)")
        return parameters
    }
}
