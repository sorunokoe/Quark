//
//  QuarkParser.swift
//  Quark
//
//  Created by Yeskendir Salgara on 23/07/2025.
//

import Foundation

struct ViewInfo: Equatable {
    let name: String
    let initialization: String
    let parameters: [QuarkParameters]
}

enum QuarkParameters: String, CaseIterable, Equatable {
    case localize
    case snapshot
}

extension ViewInfo: CustomDebugStringConvertible {
    var debugDescription: String {
        "ViewInfo(name: \(name), initialization: \(initialization), parameters: \(parameters))"
    }
}

final class QuarkParser {
    func extractViewInfo(from content: String) -> [ViewInfo] {
        let lines = content.components(separatedBy: .newlines)
        let structDefinitions = parseStructDefinitions(from: lines)
        return parseMacroUsages(from: lines, structDefinitions: structDefinitions)
    }

    /// Parses all struct definitions conforming to View
    internal func parseStructDefinitions(from lines: [String]) -> [(name: String, lineIndex: Int)] {
        lines.enumerated().compactMap { (index, line) in
            guard line.contains("struct"), line.contains(": View") else { return nil }
            let components = line.components(separatedBy: "struct")
            guard components.count > 1 else { return nil }
            if let nameComponent = components[1].components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) {
                return (name: nameComponent, lineIndex: index)
            } else {
                return nil
            }
        }
    }

    /// Parses all #Quark macro usages and extracts ViewInfo
    internal func parseMacroUsages(from lines: [String], structDefinitions: [(name: String, lineIndex: Int)]) -> [ViewInfo] {
        let content = lines.joined(separator: "\n")
        var viewInfos: [ViewInfo] = []
        let regex = try! NSRegularExpression(pattern: "#Quark\\s*\\(([^)]*)\\)\\s*\\{", options: [])
        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        for match in matches {
            let paramsRange = match.range(at: 1)
            let paramsString = nsContent.substring(with: paramsRange)
            let parameters = extractMacroParameters(from: "[\(paramsString)]")
            // Find the opening brace
            let braceStart = match.range.location + match.range.length - 1
            // Find the matching closing brace and extract content
            if let (macroContent, _) = extractBracedContent(from: content, start: braceStart) {
                if let info = makeViewInfo(from: macroContent, parameters: parameters, structDefinitions: structDefinitions) {
                    viewInfos.append(info)
                }
            }
        }
        return viewInfos
    }

    /// Extracts the content between the first `{` at start and its matching `}` (handles nested braces)
    internal func extractBracedContent(from content: String, start: Int) -> (String, Int)? {
        var depth = 0
        let chars = Array(content)
        var contentStart: Int?
        for idx in start..<chars.count {
            if chars[idx] == "{" {
                depth += 1
                if contentStart == nil { contentStart = idx + 1 }
            } else if chars[idx] == "}" {
                depth -= 1
                if depth == 0, let startIdx = contentStart {
                    let macroContent = String(chars[startIdx..<idx])
                    return (macroContent, idx)
                }
            }
        }
        return nil
    }

    /// Creates a ViewInfo if the macro content matches a struct definition
    internal func makeViewInfo(from macroContent: String, parameters: [QuarkParameters], structDefinitions: [(name: String, lineIndex: Int)]) -> ViewInfo? {
        let initialization = normalizeInitialization(macroContent)
        guard let viewName = getViewName(from: initialization),
              let structDef = structDefinitions.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == viewName }) else {
            return nil
        }
        return ViewInfo(name: structDef.name, initialization: initialization, parameters: parameters)
    }

    /// Extracts the view name from an initialization string
    internal func getViewName(from initialization: String) -> String? {
        initialization.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces)
    }

    /// Extracts macro parameters from a #Quark macro line
    internal func extractMacroParameters(from line: String) -> [QuarkParameters] {
        guard let paramsRange = line.range(of: "\\[.*?\\]", options: .regularExpression) else { return [] }
        let paramsText = String(line[paramsRange])
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespaces)
        return paramsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { value in
                QuarkParameters.allCases.first(where: { quarkParam in
                    value == ".\(quarkParam)"
                })
            }
    }

    /// Normalizes the initialization string (trims, removes newlines, joins lines)
    internal func normalizeInitialization(_ initialization: String) -> String {
        initialization
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined()
    }
}
