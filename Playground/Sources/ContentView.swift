//
//  ContentView.swift
//  QuarkPlayground
//
//  Created by Yeskendir Salgara on 23/05/2025.
//

import SwiftUI
import Quark

@QuarkLocalize
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to Quark")
            Text("This is a test view")
            Button("Click me") {
                // Action
            }
        }
    }
}

#Preview {
    ContentView()
}
