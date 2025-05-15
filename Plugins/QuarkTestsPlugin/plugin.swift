//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import PackagePlugin
import Foundation

@main
struct QuarkTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }
        
        let outputDir = context.pluginWorkDirectory.appending("GeneratedTests")
        try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
        
        var commands: [Command] = []
        
        for file in sourceTarget.sourceFiles(withSuffix: ".swift") {
            let content = try String(contentsOfFile: file.path.string)
            guard content.contains("@TrackPerformance") else { continue }
            
            let viewName = file.path.stem
            let testFilePath = outputDir.appending("\(viewName)PerformanceTests.swift")
            let testContent = generateTestContent(for: viewName)
            
            try testContent.write(toFile: testFilePath.string, atomically: true, encoding: .utf8)
            
            commands.append(.buildCommand(
                displayName: "Generating performance tests for \(viewName)",
                executable: try context.tool(named: "echo").path,
                arguments: ["Generated tests for \(viewName)"],
                outputFiles: [testFilePath]
            ))
        }
        
        return commands
    }
    
    func generateTestContent(for viewName: String) -> String {
        """
        import XCTest
        import SwiftUI
        import SwiftUIPerformanceTracker
        
        class \(viewName)PerformanceTests: XCTestCase {
            func test\(viewName)Performance() throws {
                let view = \(viewName)()
                let hostingController = UIHostingController(rootView: view)
                _ = hostingController.view // Force view load
                
                // Access metadata
                let metadata = \(viewName).performanceMetadata
                
                // Use reflection to find properties
                let mirror = Mirror(reflecting: view)
                for child in mirror.children {
                    guard let label = child.label,
                          metadata.values.contains(where: { $0.contains(label) }) else { continue }
                    
                    TestContext.shared.reset()
                    
                    // Simulate dependency change
                    // Note: Simplified; real implementation needs safer state modification
                    let propertyWrapper = mirror.children.first { $0.label == label }
                    if let value = propertyWrapper?.value {
                        if value is Bool {
                            // Use dynamic member lookup or KVO (simplified)
                            let keyPath = \\\\.\\(label)
                            let currentValue = view[keyPath: keyPath] as! Bool
                            view[keyPath: keyPath] = !currentValue
                        } else if value is Int {
                            let keyPath = \\\\.\\(label)
                            let currentValue = view[keyPath: keyPath] as! Int
                            view[keyPath: keyPath] = currentValue + 1
                        }
                    }
                    
                    // Wait for UI update
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                    
                    // Check recomputations
                    let recomputedViews = TestContext.shared.recomputeCounts
                    for (viewId, info) in recomputedViews {
                        let expectedDeps = metadata[viewId] ?? []
                        if !expectedDeps.contains(label) {
                            XCTFail("View '\\(viewId)' at \\(info.file):\\(info.line) recomputed unnecessarily when '\\(label)' changed")
                        }
                    }
                }
            }
        }
        """
    }
}
