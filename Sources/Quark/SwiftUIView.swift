//
//  SwiftUIView.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
        }
        .onAppear {
            #Hello
        }
    }
}

#Preview {
    SwiftUIView()
}
