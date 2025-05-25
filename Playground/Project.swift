import ProjectDescription

let project = Project(
    name: "QuarkPlayground",
    options: .options(
        automaticSchemesOptions: .disabled
    ),
    packages: [
        .package(path: "../")
    ],
    targets: [
        .target(
            name: "QuarkPlayground",
            destinations: .iOS,
            product: .app,
            bundleId: "com.salgara.QuarkPlayground",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UIMainStoryboardFile": "",
                "UILaunchStoryboardName": "LaunchScreen"
            ]),
            sources: ["Sources/**"],
            resources: [],
            scripts: [],
            dependencies: [
                .package(product: "Quark")
            ]
        ),
        .target(
            name: "QuarkPlaygroundTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.salgara.QuarkPlaygroundTests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "QuarkPlayground")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "QuarkPlayground",
            shared: true,
            buildAction: .buildAction(targets: ["QuarkPlayground"]),
            testAction: .targets([
                .testableTarget(target: "QuarkPlaygroundTests")
            ]),
            runAction: .runAction(configuration: "Debug", executable: "QuarkPlayground"),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(configuration: "Debug", executable: "QuarkPlayground"),
            analyzeAction: .analyzeAction(configuration: "Release")
        )
    ],
    additionalFiles: [
        "../Project.swift"
    ]
)
