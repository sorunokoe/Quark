import Foundation

protocol TestGenerator {
    func generateTests(for viewInfo: ViewInfo, target: String) -> String
}

struct ViewInfo {
    let name: String
    let initialization: String
    let parameters: [QuarkParameters]

}

enum QuarkParameters {
    case localize
    case snapshot
}

