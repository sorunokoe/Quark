//
//  File.swift
//  Quark
//
//  Created by Yeskendir Salgara on 25/05/2025.
//

import Foundation

struct LocalizationTestGenerator: TestGenerator {
    func generateTests(for viewInfo: ViewInfo, target: String) -> String {
        """
        //
        //  \(viewInfo.name)Tests.swift
        //  \(target)
        //
        //  Created by Yeskendir Salgara on 25/05/2025.
        //

        import Foundation
        @testable import \(target)
        import SwiftUI
        import ViewInspector
        import XCTest
        import Quark

        @MainActor
        final class Quark\(viewInfo.name)L10nTests: XCTestCase {
            func testTranslations() {
                var bundle: Bundle = Bundle.allBundles.first { $0.bundlePath.contains("Build/Products") && !$0.bundlePath.contains("AccessibilityUITests-Runner") && $0.bundleURL.lastPathComponent.contains(".app") } ?? Bundle.main
                let path = Bundle(for: Quark\(viewInfo.name)L10nTests.self).bundleURL.appending(path: "\(target)_\(target).bundle")
                if let moduleBundle = Bundle(path: path.relativePath) {
                    bundle = moduleBundle
                }

                let supportedLocales = bundle.localizations
                let sut = \(viewInfo.initialization)

                do {
                    let parent = try sut.inspect().implicitAnyView()
                    let textElements = parent.findAll(ViewType.Text.self) { view in
                        guard (try? view.modifier(NoLocalizationNeeded.self)) == nil else { return false }
                        var view = try? view.parent()
                        var noModifiers = (try? view?.modifier(NoLocalizationNeeded.self)) == nil
                        while let parentView = try? view?.parent(), noModifiers {
                            noModifiers = (try? parentView.modifier(NoLocalizationNeeded.self)) == nil
                            view = parentView
                        }
                        return noModifiers
                    }
                    for locale in supportedLocales {
                        let stringsPath = bundle.path(forResource: "Localizable",
                                                      ofType: "strings",
                                                      inDirectory: nil,
                                                      forLocalization: locale)
                        let dictionary = NSDictionary(contentsOfFile: stringsPath ?? "")

                        for textElement in textElements {
                            let string = try textElement.string(locale: Locale(identifier: locale))
                            guard let value = dictionary?.first(where: { ($0.key as? String ?? "") == string })?.value as? String else {
                                XCTFail("No translation found for \\(locale) - value: \\(string)")
                                return
                            }

                            XCTAssertEqual(string, value)
                        }
                    }
                } catch {
                    XCTFail("Test failed: \\(String(describing: error))")
                }
            }
        }
        """
    }
}
