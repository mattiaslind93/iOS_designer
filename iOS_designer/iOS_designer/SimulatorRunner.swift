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

        // 2. Export project (ProjectGenerator now creates .xcodeproj + source files)
        let generator = ProjectGenerator()
        do {
            try generator.write(document: document, to: tmpDir)
        } catch {
            throw RunError.exportFailed(error.localizedDescription)
        }

        let projectName = document.exportConfig.projectName.isEmpty
            ? "GeneratedApp" : document.exportConfig.projectName
        let projectDir = tmpDir.appendingPathComponent(projectName)

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
