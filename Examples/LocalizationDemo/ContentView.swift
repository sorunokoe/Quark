import SwiftUI

@QuarkLocalize
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Quark")
                .font(.title)
            
            Text("This is a demo of the @QuarkLocalize macro")
                .font(.body)
            
            Button("Try it out") {
                // Button action
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
} 