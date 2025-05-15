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
        print("[QuarkTestsPlugin] Plugin started for target: \(target.name)")
        
        // Get the test target that's using this plugin
        guard let testTarget = target as? SourceModuleTarget else {
            print("[QuarkTestsPlugin] Target is not a source module target")
            return []
        }
        
        // Find the main target that this test target depends on
        let mainTarget = findMainTarget(in: context.package, for: testTarget)
        
        guard let mainTarget = mainTarget as? SourceModuleTarget else {
            print("[QuarkTestsPlugin] Could not find main target or it's not a source module target")
            return []
        }
        
        print("[QuarkTestsPlugin] Found main target: \(mainTarget.name), scanning for views...")
        
        let outputDir = context.pluginWorkDirectoryURL.appendingPathComponent("GeneratedTests")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var commands: [Command] = []
        
        // Scan files in the main target
        for file in mainTarget.sourceFiles(withSuffix: ".swift") {
            print("[QuarkTestsPlugin] Checking file: \(file.url.path)")
            let content = try String(contentsOfFile: file.url.path)
            
            // Look for both the macro and its expanded form
            guard content.contains("@TrackPerformance") || 
                  content.contains("performanceMetadata") else { continue }
            
            print("[QuarkTestsPlugin] Found performance tracking in: \(file.url.lastPathComponent)")
            
            let viewName = file.url.deletingPathExtension().lastPathComponent
            let testFilePath = outputDir.appendingPathComponent("\(viewName)PerformanceTests.swift")
            let testContent = generateTestContent(for: viewName)
            
            try testContent.write(to: testFilePath, atomically: true, encoding: .utf8)
            print("[QuarkTestsPlugin] Generated test: \(testFilePath.path)")
        }
        
        return commands
    }
    
    private func findMainTarget(in package: Package, for testTarget: SourceModuleTarget) -> Target? {
        // First, try to find a target that matches the test target name without "Tests" suffix
        let potentialMainTargetName = testTarget.name.replacingOccurrences(of: "Tests", with: "")
        if let mainTarget = package.targets.first(where: { $0.name == potentialMainTargetName }) {
            return mainTarget
        }
        
        // If not found, look for targets that this test target depends on
        for dependency in testTarget.dependencies {
            if case .target(let name) = dependency {
                if let mainTarget = package.targets.first(where: { $0.name == name }) {
                    return mainTarget
                }
            }
        }
        
        return nil
    }
    
    func generateTestContent(for viewName: String) -> String {
        """
        import XCTest
        import SwiftUI
        import SwiftUIPerformanceTracker
        
        final class \(viewName)PerformanceTests: XCTestCase {
            var view: \(viewName)!
            var hostingController: UIHostingController<\(viewName)>!
            
            override func setUp() {
                super.setUp()
                view = \(viewName)()
                hostingController = UIHostingController(rootView: view)
                _ = hostingController.view // Force view load
            }
            
            override func tearDown() {
                view = nil
                hostingController = nil
                super.tearDown()
            }
            
            func testViewInitialization() {
                XCTAssertNotNil(view, "View should be initialized")
                XCTAssertNotNil(hostingController, "Hosting controller should be initialized")
                XCTAssertNotNil(hostingController.view, "View should be loaded")
            }
            
            func testPerformanceMetadata() {
                // Verify that performance metadata exists
                XCTAssertFalse(view.performanceMetadata.isEmpty, "Performance metadata should not be empty")
                
                // Print metadata for debugging
                print("Performance Metadata for \(viewName):")
                for (id, info) in view.performanceMetadata {
                    print("- View ID: \\(id)")
                    print("  File: \\(info.file)")
                    print("  Line: \\(info.line)")
                    print("  Dependencies: \\(info.deps)")
                    print("  View Type: \\(info.viewType)")
                    print("  Is Container: \\(info.isContainer)")
                }
            }
            
            func testDependencyTracking() {
                // Verify that tracked dependencies exist
                XCTAssertFalse(view.trackedDependencies.isEmpty, "Tracked dependencies should not be empty")
                
                // Print dependencies for debugging
                print("Tracked Dependencies for \(viewName):")
                for dep in view.trackedDependencies {
                    print("- \\(dep)")
                }
            }
            
            func testViewRecomputation() {
                // Reset the test context
                TestContext.shared.reset()
                
                // Get initial recomputation counts
                let initialCounts = TestContext.shared.recomputeCounts
                
                // Simulate a state change that should trigger recomputation
                // This will depend on the actual properties in your view
                if let mirror = Mirror(reflecting: view).children.first(where: { $0.label == "count" }) {
                    if var count = mirror.value as? Int {
                        count += 1
                        // Use key path to update the value
                        let keyPath = \\\\.count
                        view[keyPath: keyPath] = count
                    }
                }
                
                // Wait for UI update
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                
                // Get new recomputation counts
                let newCounts = TestContext.shared.recomputeCounts
                
                // Verify that some views were recomputed
                XCTAssertFalse(newCounts.isEmpty, "Some views should have been recomputed")
                
                // Print recomputation details
                print("Recomputation Details for \(viewName):")
                for (viewId, info) in newCounts {
                    print("- View ID: \\(viewId)")
                    print("  File: \\(info.file)")
                    print("  Line: \\(info.line)")
                    print("  Count: \\(info.count)")
                }
            }
            
            func testUnnecessaryRecomputation() {
                // Reset the test context
                TestContext.shared.reset()
                
                // Get initial recomputation counts
                let initialCounts = TestContext.shared.recomputeCounts
                
                // Simulate a state change that should NOT trigger recomputation
                // This will depend on the actual properties in your view
                if let mirror = Mirror(reflecting: view).children.first(where: { $0.label == "isHidden" }) {
                    if var isHidden = mirror.value as? Bool {
                        isHidden.toggle()
                        // Use key path to update the value
                        let keyPath = \\\\.isHidden
                        view[keyPath: keyPath] = isHidden
                    }
                }
                
                // Wait for UI update
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                
                // Get new recomputation counts
                let newCounts = TestContext.shared.recomputeCounts
                
                // Verify that only views depending on isHidden were recomputed
                for (viewId, info) in newCounts {
                    let expectedDeps = view.performanceMetadata[viewId]?.deps ?? []
                    XCTAssertTrue(expectedDeps.contains("isHidden"), 
                                "View '\\(viewId)' at \\(info.file):\\(info.line) should only recompute when isHidden changes")
                }
            }
        }
        """
    }
}
