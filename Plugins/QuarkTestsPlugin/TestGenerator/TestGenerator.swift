import Foundation

protocol TestGenerator {
    func generateTests(for viewInfo: ViewInfo, target: String) -> String
}
