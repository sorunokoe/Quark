import Testing
import SwiftUI
@testable import Quark

struct TestView: View {
    let name: String
    let age: Int
    
    var body: some View {
        VStack {
            Text("Hello \(name)")
            Text("Age: \(age)")
        }
    }
}

@Test func testQuarkMacro() async throws {
    // Test that the Quark macro works correctly
    let view = #Quark([.localize, .snapshot]) {
        TestView(name: "Test", age: 25)
    }
    
    // The macro should return the view expression unchanged
    #expect(view is TestView)
}

@Test func testQuarkMacroWithLocalization() async throws {
    // Test that the Quark macro works with localization parameter
    let view = #Quark([.localize]) {
        TestView(name: "Localized", age: 30)
    }
    
    #expect(view is TestView)
}

@Test func testQuarkMacroWithSnapshot() async throws {
    // Test that the Quark macro works with snapshot parameter
    let view = #Quark([.snapshot]) {
        TestView(name: "Snapshot", age: 35)
    }
    
    #expect(view is TestView)
}
