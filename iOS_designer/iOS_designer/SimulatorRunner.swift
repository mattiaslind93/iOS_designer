import Foundation
import DesignModel
import CodeExport

/// Exports the current design as a SwiftUI app, builds it with xcodebuild,
/// and launches it in the iOS Simulator.
enum SimulatorRunner {

    enum RunError: LocalizedError {
        case noXcode
        case buildFailed(String)
        case simulatorFailed(String)
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noXcode:
                return "Xcode command line tools not found. Install Xcode."
            case .buildFailed(let msg):
                return "Build failed:\n\(msg.prefix(500))"
            case .simulatorFailed(let msg):
                return "Simulator launch failed:\n\(msg.prefix(500))"
            case .exportFailed(let msg):
                return "Export failed:\n\(msg)"
            }
        }
    }

    /// Main entry point — export, build, install, launch.
    @MainActor
    static func run(document: DesignDocument) async throws {
        // 1. Create temp directory
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iOSDesigner_SimRun_\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // 2. Export project
        let generator = ProjectGenerator()
        do {
            try generator.write(document: document, to: tmpDir)
        } catch {
            throw RunError.exportFailed(error.localizedDescription)
        }

        let projectName = document.exportConfig.projectName.isEmpty
            ? "GeneratedApp" : document.exportConfig.projectName
        let projectDir = tmpDir.appendingPathComponent(projectName)

        // 3. Create a minimal Xcode project (Package.swift based)
        try createXcodeProject(at: projectDir, name: projectName, document: document)

        // 4. Find a booted simulator or boot one
        let deviceID = try await findOrBootSimulator()

        // 5. Build for simulator
        let buildOutput = try await shell(
            "/usr/bin/xcodebuild",
            args: [
                "-project", projectDir.appendingPathComponent("\(projectName).xcodeproj").path,
                "-scheme", projectName,
                "-sdk", "iphonesimulator",
                "-destination", "id=\(deviceID)",
                "-configuration", "Debug",
                "build",
                "-quiet"
            ],
            timeout: 120
        )
        if buildOutput.exitCode != 0 {
            throw RunError.buildFailed(buildOutput.stderr)
        }

        // 6. Find the built .app
        let derivedData = try await findDerivedDataApp(projectName: projectName)

        // 7. Install and launch
        let installResult = try await shell(
            "/usr/bin/xcrun",
            args: ["simctl", "install", deviceID, derivedData],
            timeout: 30
        )
        if installResult.exitCode != 0 {
            throw RunError.simulatorFailed("Install: \(installResult.stderr)")
        }

        let bundleID = document.exportConfig.bundleIdentifier.isEmpty
            ? "com.iosdesigner.\(projectName)" : document.exportConfig.bundleIdentifier

        let launchResult = try await shell(
            "/usr/bin/xcrun",
            args: ["simctl", "launch", deviceID, bundleID],
            timeout: 15
        )
        if launchResult.exitCode != 0 {
            throw RunError.simulatorFailed("Launch: \(launchResult.stderr)")
        }

        // 8. Bring Simulator to front
        _ = try? await shell("/usr/bin/open", args: ["-a", "Simulator"], timeout: 5)
    }

    // MARK: - Xcode Project Creation

    private static func createXcodeProject(at dir: URL, name: String, document: DesignDocument) throws {
        // Create a simple Package.swift based project that xcodebuild can handle
        // Actually, we'll create a proper xcodeproj since Package.swift iOS apps need Xcode 16+

        let bundleID = document.exportConfig.bundleIdentifier.isEmpty
            ? "com.iosdesigner.\(name)" : document.exportConfig.bundleIdentifier
        let target = document.exportConfig.deploymentTarget.isEmpty
            ? "26.0" : document.exportConfig.deploymentTarget

        // Create xcodeproj directory
        let projDir = dir.appendingPathComponent("\(name).xcodeproj")
        try FileManager.default.createDirectory(at: projDir, withIntermediateDirectories: true)

        // Generate a minimal pbxproj
        let pbxproj = generatePbxproj(name: name, bundleID: bundleID, target: target)
        try pbxproj.write(to: projDir.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)

        // Create Info.plist
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSRequiresIPhoneOS</key>
            <true/>
            <key>UILaunchScreen</key>
            <dict/>
            <key>UIRequiredDeviceCapabilities</key>
            <array><string>armv7</string></array>
            <key>UISupportedInterfaceOrientations</key>
            <array>
                <string>UIInterfaceOrientationPortrait</string>
            </array>
        </dict>
        </plist>
        """

        let srcDir = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try infoPlist.write(to: srcDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
    }

    private static func generatePbxproj(name: String, bundleID: String, target: String) -> String {
        // Minimal Xcode project that builds an iOS app from Swift sources
        let mainGroupID     = "AA000000000000000001"
        let srcGroupID      = "AA000000000000000002"
        let projectID       = "AA000000000000000003"
        let targetID        = "AA000000000000000004"
        let buildConfigListID = "AA000000000000000005"
        let debugConfigID   = "AA000000000000000006"
        let targetConfigListID = "AA000000000000000007"
        let targetDebugID   = "AA000000000000000008"
        let sourcesPhaseID  = "AA000000000000000009"
        let productRefID    = "AA000000000000000010"
        let productsGroupID = "AA000000000000000011"

        return """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {};
            objectVersion = 56;
            objects = {
                \(mainGroupID) = { isa = PBXGroup; children = (\(srcGroupID), \(productsGroupID)); sourceTree = "<group>"; };
                \(srcGroupID) = { isa = PBXGroup; children = (); name = \(name); path = \(name); sourceTree = "<group>"; };
                \(productsGroupID) = { isa = PBXGroup; children = (\(productRefID)); name = Products; sourceTree = "<group>"; };
                \(productRefID) = { isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "\(name).app"; sourceTree = BUILT_PRODUCTS_DIR; };
                \(sourcesPhaseID) = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
                \(targetID) = {
                    isa = PBXNativeTarget;
                    buildConfigurationList = \(targetConfigListID);
                    buildPhases = (\(sourcesPhaseID));
                    buildRules = ();
                    dependencies = ();
                    name = \(name);
                    productName = \(name);
                    productReference = \(productRefID);
                    productType = "com.apple.product-type.application";
                };
                \(projectID) = {
                    isa = PBXProject;
                    buildConfigurationList = \(buildConfigListID);
                    compatibilityVersion = "Xcode 14.0";
                    developmentRegion = en;
                    hasScannedForEncodings = 0;
                    knownRegions = (en, Base);
                    mainGroup = \(mainGroupID);
                    productRefGroup = \(productsGroupID);
                    projectDirPath = "";
                    projectRoot = "";
                    targets = (\(targetID));
                };
                \(buildConfigListID) = { isa = XCConfigurationList; buildConfigurations = (\(debugConfigID)); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
                \(debugConfigID) = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ALWAYS_SEARCH_USER_PATHS = NO;
                        CLANG_ENABLE_MODULES = YES;
                        SWIFT_VERSION = 6.0;
                        SDKROOT = iphoneos;
                    };
                    name = Debug;
                };
                \(targetConfigListID) = { isa = XCConfigurationList; buildConfigurations = (\(targetDebugID)); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
                \(targetDebugID) = {
                    isa = XCBuildConfiguration;
                    buildSettings = {
                        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                        CODE_SIGN_STYLE = Automatic;
                        INFOPLIST_FILE = "\(name)/Info.plist";
                        IPHONEOS_DEPLOYMENT_TARGET = \(target);
                        PRODUCT_BUNDLE_IDENTIFIER = "\(bundleID)";
                        PRODUCT_NAME = "$(TARGET_NAME)";
                        SWIFT_VERSION = 6.0;
                        TARGETED_DEVICE_FAMILY = 1;
                        GENERATE_INFOPLIST_FILE = NO;
                    };
                    name = Debug;
                };
            };
            rootObject = \(projectID);
        }
        """
    }

    // MARK: - Simulator

    private static func findOrBootSimulator() async throws -> String {
        // List available simulators
        let result = try await shell(
            "/usr/bin/xcrun",
            args: ["simctl", "list", "devices", "available", "-j"],
            timeout: 10
        )

        // Parse JSON to find a booted iPhone or boot one
        if let data = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let devices = json["devices"] as? [String: [[String: Any]]] {

            // First, find already booted iPhone
            for (runtime, deviceList) in devices where runtime.contains("iOS") {
                for device in deviceList {
                    if let state = device["state"] as? String,
                       state == "Booted",
                       let udid = device["udid"] as? String {
                        return udid
                    }
                }
            }

            // No booted device, find an iPhone to boot
            // Prefer iPhone 16 Pro
            for (runtime, deviceList) in devices.sorted(by: { $0.key > $1.key }) where runtime.contains("iOS") {
                for device in deviceList {
                    if let name = device["name"] as? String,
                       let udid = device["udid"] as? String,
                       let isAvailable = device["isAvailable"] as? Bool,
                       isAvailable,
                       name.contains("iPhone") {
                        // Boot this simulator
                        _ = try? await shell("/usr/bin/xcrun", args: ["simctl", "boot", udid], timeout: 30)
                        _ = try? await shell("/usr/bin/open", args: ["-a", "Simulator"], timeout: 5)
                        // Wait for boot
                        try await Task.sleep(for: .seconds(3))
                        return udid
                    }
                }
            }
        }

        throw RunError.simulatorFailed("No iPhone simulator found. Install one via Xcode.")
    }

    private static func findDerivedDataApp(projectName: String) async throws -> String {
        // Look in DerivedData for the built .app
        let derivedData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        let result = try await shell(
            "/usr/bin/find",
            args: [derivedData.path, "-name", "\(projectName).app", "-path", "*/Debug-iphonesimulator/*", "-maxdepth", "6"],
            timeout: 10
        )

        let paths = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .split(separator: "\n")
            .map(String.init)
            .sorted()  // Most recent last

        guard let appPath = paths.last else {
            throw RunError.buildFailed("Could not find built \(projectName).app in DerivedData")
        }
        return appPath
    }

    // MARK: - Shell Helper

    struct ShellResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private static func shell(
        _ executable: String,
        args: [String],
        timeout: TimeInterval
    ) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Timeout
                let deadline = DispatchTime.now() + timeout
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }

                process.waitUntilExit()

                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                continuation.resume(returning: ShellResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: process.terminationStatus
                ))
            }
        }
    }
}
