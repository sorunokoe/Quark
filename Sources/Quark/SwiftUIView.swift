//
//  SwiftUIView.swift
//  Quark
//
//  Created by Yeskendir Salgara on 15/05/2025.
//

import SwiftUI

@TrackPerformance
struct SwiftUIView: View {
    
    @State var count: Int = 0
    @State var isHidden: Bool = false
    
    var body: some View {
        VStack {
            if isHidden {
                Text("Hello, World!")
            }
            Text("Count: \(count)")
            VStack {
                Button {
                    count += 1
                } label: {
                    Text("Increase count: \(count)")
                }
                Button {
                    isHidden.toggle()
                } label: {
                    Text(isHidden ? "Hide" :"Show")
                }

            }
        }
        .onAppear {
            print(SwiftUIView.performanceMetadata)
            print(SwiftUIView.trackedDependencies)
        }
    }
}

#Preview {
    SwiftUIView()
}
