//
//  QuarkParser.swift
//  Quark
//
//  Created by Yeskendir Salgara on 23/07/2025.
//

import Foundation

final class QuarkParser {
    func extractViewInfo(from content: String) -> [ViewInfo] {
        var viewInfos: [ViewInfo] = []
        let lines = content.components(separatedBy: .newlines)
        
        print("[QuarkTestsPlugin] Extracting view info from content with \(lines.count) lines")
        
        // First, find all struct definitions
        var structDefinitions: [(name: String, lineIndex: Int)] = []
        for (index, line) in lines.enumerated() {
            if line.contains("struct") && line.contains(": View") {
                let components = line.components(separatedBy: "struct")
                if components.count > 1 {
                    let nameComponent = components[1].components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
                    structDefinitions.append((name: nameComponent, lineIndex: index))
                    print("[QuarkTestsPlugin] Found struct definition: \(nameComponent) at line \(index)")
                }
            }
        }
        
        // Then process macro usages
        var currentMacroContent: String = ""
        var isCollectingMacroContent = false
        var parenthesesCount = 0
        var currentParameters: [QuarkParameters] = []
        
        for (_, line) in lines.enumerated() {
            if line.contains("#Quark") {
                print("[QuarkTestsPlugin] Found Quark macro in line: \(line)")
                isCollectingMacroContent = true
                currentMacroContent = ""
                parenthesesCount = 0
                
                // Extract parameters from the first line
                if let paramsRange = line.range(of: "\\[.*?\\]", options: .regularExpression) {
                    let paramsText = String(line[paramsRange])
                    print("[QuarkTestsPlugin] Found parameters text: \(paramsText)")
                    currentParameters = extractParameters(from: paramsText)
                }
                
                // Start collecting content after the opening brace
                if let braceIndex = line.range(of: "{")?.upperBound {
                    currentMacroContent = String(line[braceIndex...]).trimmingCharacters(in: .whitespaces)
                    parenthesesCount = 1
                }
            } else if isCollectingMacroContent {
                // Count braces
                parenthesesCount += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
                currentMacroContent += "\n" + line
                
                // If we've closed all braces, process the content
                if parenthesesCount == 0 {
                    print("[QuarkTestsPlugin] Completed macro content: \(currentMacroContent)")
                    
                    // Extract the view initialization
                    let initialization = currentMacroContent
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "^\\s*|\\s*$", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\}\\s*$", with: "", options: .regularExpression) // Remove trailing closing brace
                    
                    print("[QuarkTestsPlugin] Extracted initialization: \(initialization)")
                    
                    // Extract the view name from the initialization
                    if let viewName = initialization.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) {
                        print("[QuarkTestsPlugin] Looking for struct definition for view: \(viewName)")
                        
                        // Find the matching struct definition
                        if let structDef = structDefinitions.first(where: { $0.name == viewName }) {
                            print("[QuarkTestsPlugin] Found matching struct: \(structDef.name)")
                            viewInfos.append(ViewInfo(
                                name: structDef.name,
                                initialization: initialization,
                                parameters: currentParameters
                            ))
                        } else {
                            print("[QuarkTestsPlugin] No matching struct found for view: \(viewName)")
                        }
                    }
                    
                    isCollectingMacroContent = false
                    currentParameters = []
                }
            }
        }
        
        print("[QuarkTestsPlugin] Extracted view info: \(viewInfos)")
        return viewInfos
    }
    
    private func extractParameters(from text: String) -> [QuarkParameters] {
        var parameters: [QuarkParameters] = []
        
        // Extract parameters from array syntax
        if let range = text.range(of: "\\[.*?\\]", options: .regularExpression) {
            let paramsText = String(text[range])
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            print("[QuarkTestsPlugin] Extracting parameters from: \(paramsText)")
            
            let paramStrings = paramsText.components(separatedBy: ",")
            
            for param in paramStrings {
                let trimmedParam = param.trimmingCharacters(in: .whitespaces)
                print("[QuarkTestsPlugin] Processing parameter: \(trimmedParam)")
                
                if trimmedParam.contains(".localize") {
                    parameters.append(.localize)
                    print("[QuarkTestsPlugin] Added .localize parameter")
                }
                if trimmedParam.contains(".snapshot") {
                    parameters.append(.snapshot)
                    print("[QuarkTestsPlugin] Added .snapshot parameter")
                }
            }
        }
        
        print("[QuarkTestsPlugin] Extracted parameters: \(parameters)")
        return parameters
    }
}
