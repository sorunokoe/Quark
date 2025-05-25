# Quark

[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2016.4%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Quark is a Swift library that generates tests for you.

It's designed to make testing your Swift applications more efficient.

## Features

Generates tests based on the macros and parameters:
- **Localization tests**: Automatically test your localized strings
- **Snapshot tests**: Generate snapshot tests for your views

```
#Quark([.localize, .snapshot]) {
    ContentView()
}
```

Simple as that! ✨

## Requirements

- iOS 16.4+
- Swift 6.0+
- Xcode 15+

## Installation

### Swift Package Manager

Add Quark to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/sorunokoe/Quark.git", from: "0.1.0")
]
```

### In your SPM package
```swift
.target(
    name: "Example",
    dependencies: [
        .product(name: "Quark", package: "Quark")
    ]
),
.testTarget(
    name: "ExampleTests",
    dependencies: [
        "Example",
        .product(name: "QuarkTesting", package: "Quark")
    ],
    plugins: [
        .plugin(name: "QuarkTestsPlugin", package: "Quark")
    ]
)
```

## Usage


```swift
import SwiftUI
import Quark

struct ContentView: View {
    var body: some View {
        Text("Hello World!")
    }
}

#Preview {
    ContentView()
}

#Quark([.localize, .snapshot]) {
    ContentView()
}
```

Separate usage:

```swift
import SwiftUI
import Quark

struct ContentView: View {
    var body: some View {
        Text("Hello World!")
    }
}

#Preview {
    ContentView()
}

#Quark([.localize]) {
    ContentView()
}

#Quark([.snapshot]) {
    ContentView()
}
```


### Localization tests

Sometimes there is no need for localization. In that case, use the `.noLocalizationNeeded()` modifier. Example:

```swift

import Quark
import SwiftUI

struct MedeDiaryView: View {
    var friends: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("welcome_from_mede")
                .font(.title)
            VStack(alignment: .leading, spacing: 8) {
                Text("my_friends")
                    .bold()
                ForEach(friends, id: \.self) { friend in
                    Text(friend)
                        .noLocalizationNeeded() // <--- skip the test
                }
                Button("update") {}
            }
        }
    }
}

#Preview {
    MedeDiaryView(friends: ["Tapo", "Bird", "Mammut"])
}

#Quark([.localize]) {
    MedeDiaryView(friends: ["Tapo", "Bird", "Mammut"])
}
```

## Components

### Quark
The main library that provides macros.

> [!NOTE]  
> Add as a dependency only to a target (not testTarget).

### QuarkTesting
Additional testing utilities and helpers for writing tests.

> [!NOTE]  
> Add as a dependency only to a testTarget.

### QuarkTestsPlugin
Build tool plugin for enhanced testing capabilities.

> [!NOTE]  
> Add as a plugin only to a testTarget.

## Dependencies

- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- [ViewInspector](https://github.com/nalexn/ViewInspector)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

Yeskendir Salgara - [LinkedIn](https://www.linkedin.com/in/salgara/)

Project Link: [https://github.com/sorunokoe/Quark](https://github.com/sorunokoe/Quark) 