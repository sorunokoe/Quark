//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 25/05/2025.
//

import Foundation

struct SnapshotTestGenerator: TestGenerator {
    
    var directory: String
    
    func generateTests(for viewInfo: ViewInfo, target: String) -> String {
        """
        //
        //  \(viewInfo.name)SnapshotTests.swift
        //  \(target)
        //
        //  Created by Quark on \(Date())
        //

        import Foundation
        @testable import \(target)
        import SwiftUI
        import SnapshotTesting
        import XCTest
        import Quark

        @MainActor
        final class Quark\(viewInfo.name)SnapshotTests: XCTestCase {

            private var filePath: String { 
                return "\(directory)/__Snapshots__/\(viewInfo.name)"
            }
        
            func test\(viewInfo.name)Snapshot() {
                let sut = \(viewInfo.initialization)
                
                // Test in light mode
                var failure = verifySnapshot(
                    of: sut,
                    as: .image(layout: .device(config: .iPhone13)),
                    named: "light",
                    snapshotDirectory: filePath,
                    testName: "\(viewInfo.name)_snapshot"
                )
                guard let message = failure else { return }
                XCTFail(message)

                // Test in dark mode
                
                let darkSut = NavigationView { sut }.environment(\\.colorScheme, .dark)
        
                failure = verifySnapshot(
                    of: darkSut,
                    as: .image(layout: .device(config: .iPhone13)),
                    named: "dark",
                    snapshotDirectory: filePath,
                    testName: "\(viewInfo.name)_snapshot"
                )
                guard let message = failure else { return }
                XCTFail(message)
            }
        }
        """
    }
}
