//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import XCTest
@testable import Quark

@MainActor
final class SwiftUIPerformanceTrackerTests: XCTestCase, Sendable {
    func testTestContext() {
        TestContext.shared.reset()
        TestContext.shared.recordRecomputation(id: "TestView", file: "Test.swift", line: 10)
        XCTAssertEqual(TestContext.shared.recomputeCounts["TestView"]?.count, 1)
        XCTAssertEqual(TestContext.shared.recomputeCounts["TestView"]?.file, "Test.swift")
        XCTAssertEqual(TestContext.shared.recomputeCounts["TestView"]?.line, 10)
        
        // Test reset
        TestContext.shared.reset()
        XCTAssertTrue(TestContext.shared.recomputeCounts.isEmpty)
    }
}
