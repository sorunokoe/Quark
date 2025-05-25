//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 25/05/2025.
//

import Foundation

struct SnapshotTestGenerator: TestGenerator {
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
            func testSnapshot() {
                let sut = \(viewInfo.initialization)

                // Test in light mode
                assertSnapshot(
                    matching: sut,
                    as: .image(layout: .device(config: .iPhone13))
                )

                // Test in dark mode
                assertSnapshot(
                    matching: sut
                        .preferredColorScheme(.dark),
                    as: .image(layout: .device(config: .iPhone13))
                )
            }
        }
        """
    }
}
