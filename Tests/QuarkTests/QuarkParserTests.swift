@testable import Quark
@testable import QuarkHelper
import SwiftUI
import Testing
import XCTest

@Suite
struct QuarkParserTests {
    @Test
    func testSingleViewSingleMacroSingleParameter() {
        let content = """
        struct MyView: View {
            var body: some View { Text(\"Hello\") }
        }
        #Quark([.localize]) { MyView() }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [ViewInfo(name: "MyView", initialization: "MyView()", parameters: [.localize])]
        #expect(result == expected)
    }
    
    @Test
    func testSingleViewSingleMacroSingleParameterMultiline() {
        let content = """
        struct MyView: View {
            var body: some View { Text(\"Hello\") }
        }
        #Quark([.localize]) { 
            MyView() 
        }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [ViewInfo(name: "MyView", initialization: "MyView()", parameters: [.localize])]
        #expect(result == expected)
    }

    @Test
    func testSingleViewSingleMacroMultipleParameters() {
        let content = """
        struct MyView: View {
            var body: some View { Text(\"Hello\") }
        }
        #Quark([.localize, .snapshot]) { MyView() }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [ViewInfo(name: "MyView", initialization: "MyView()", parameters: [.localize, .snapshot])]
        let actual = result.map { ViewInfo(name: $0.name, initialization: $0.initialization, parameters: $0.parameters) }
        #expect(actual == expected)
    }

    @Test
    func testMultipleViewsMultipleMacros() {
        let content = """
        struct FirstView: View { var body: some View { Text(\"A\") } }
        struct SecondView: View { var body: some View { Text(\"B\") } }
        #Quark([.localize]) { FirstView() }
        #Quark([.snapshot]) { SecondView() }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [
            ViewInfo(name: "FirstView", initialization: "FirstView()", parameters: [.localize]),
            ViewInfo(name: "SecondView", initialization: "SecondView()", parameters: [.snapshot])
        ]
        let actual = result.map { ViewInfo(name: $0.name, initialization: $0.initialization, parameters: $0.parameters) }
        #expect(actual == expected)
    }

    @Test
    func testMacroWithNoParameters() {
        let content = """
        struct MyView: View { var body: some View { Text(\"Hi\") } }
        #Quark([]) { MyView() }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [ViewInfo(name: "MyView", initialization: "MyView()", parameters: [])]
        let actual = result.map { ViewInfo(name: $0.name, initialization: $0.initialization, parameters: $0.parameters) }
        #expect(actual == expected)
    }

    @Test
    func testMacroWithExtraWhitespace() {
        let content = """
        struct MyView: View { var body: some View { Text(\"Hi\") } }
        #Quark(  [  .localize  ,   .snapshot  ]  ) {   MyView()   }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [ViewInfo(name: "MyView", initialization: "MyView()", parameters: [.localize, .snapshot])]
        let actual = result.map { ViewInfo(name: $0.name, initialization: $0.initialization, parameters: $0.parameters) }
        #expect(actual == expected)
    }

    @Test
    func testMacroWithNoMatchingStruct() {
        let content = """
        #Quark([.localize]) { UnknownView() }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        #expect(result.isEmpty)
    }

    @Test
    func testNoMacrosPresent() {
        let content = """
        struct MyView: View { var body: some View { Text(\"Hi\") } }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        #expect(result.isEmpty)
    }

    @Test
    func testViewInitializationWithParameters() {
        let content = """
        struct MyView: View {
            var title: String
            var count: Int
            var body: some View { Text(title + String(count)) }
        }
        #Quark([.localize]) { MyView(title: \"Hello\", count: 3) }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [
            ViewInfo(
                name: "MyView",
                initialization: "MyView(title: \"Hello\", count: 3)",
                parameters: [.localize]
            )
        ]
        #expect(result == expected)
    }

    @Test
    func testViewInitializationWithMultipleParameterTypes() {
        let content = """
        struct ComplexView: View {
            var title: String
            var isEnabled: Bool
            var value: Double
            var body: some View { Text(title) }
        }
        #Quark([.snapshot]) { ComplexView(title: \"Test\", isEnabled: false, value: 42.5) }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [
            ViewInfo(
                name: "ComplexView",
                initialization: "ComplexView(title: \"Test\", isEnabled: false, value: 42.5)",
                parameters: [.snapshot]
            )
        ]
        #expect(result == expected)
    }

    @Test
    func testViewInitializationWithNestedViews() {
        let content = """
        struct ChildView: View {
            var label: String
            var body: some View { Text(label) }
        }
        struct ParentView: View {
            var child: ChildView
            var body: some View { child }
        }
        #Quark([.localize, .snapshot]) { ParentView(child: ChildView(label: \"Nested\")) }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [
            ViewInfo(
                name: "ParentView",
                initialization: "ParentView(child: ChildView(label: \"Nested\"))",
                parameters: [.localize, .snapshot]
            )
        ]
        #expect(result == expected)
    }

    @Test
    func testViewInitializationWithExternalVariable() {
        let content = """
        struct MyView: View {
            var a: Int
            var body: some View { Text(String(a)) }
        }

        let a = 1
        #Quark([]) {
            MyView(a: a)
        }
        """
        let parser = QuarkParser()
        let result = parser.extractViewInfo(from: content)
        let expected = [
            ViewInfo(
                name: "MyView",
                initialization: "MyView(a: a)",
                parameters: []
            )
        ]
        #expect(result == expected)
    }
}
