import Foundation
import DesignModel

/// Generates a complete Xcode-ready project folder from a DesignDocument.
/// Supports both fresh project creation (with .xcodeproj) and export into existing Xcode projects.
public struct ProjectGenerator {
    let emitter = SwiftUIEmitter()

    public init() {}

    /// Generate all files for a project and return as a dictionary of path → content.
    public func generate(document: DesignDocument) -> [String: String] {
        var files: [String: String] = [:]
        let name = projectName(from: document)

        // App entry point
        files["\(name)/\(name)App.swift"] = generateAppFile(document: document)

        // Views
        for page in document.pages {
            let viewName = sanitizeViewName(page.name)
            files["\(name)/Views/\(viewName).swift"] = emitter.emit(page: page, viewName: viewName)
        }

        // Theme
        files["\(name)/Theme/AppColors.swift"] = generateColorsFile(tokens: document.tokens)
        files["\(name)/Theme/AppSpacing.swift"] = generateSpacingFile(tokens: document.tokens)
        files["\(name)/Theme/AppFonts.swift"] = generateFontsFile()

        return files
    }

    /// Write generated files to a directory.
    /// If the directory already contains an .xcodeproj, files are placed inside
    /// the matching source group folder. Otherwise, a new Xcode project is created.
    public func write(document: DesignDocument, to directory: URL) throws {
        let fm = FileManager.default
        let name = projectName(from: document)

        // Check if there's an existing .xcodeproj in the target directory
        let existingProject = try? findExistingXcodeProject(in: directory)

        if let existingProject = existingProject {
            // Export into existing project — find the source group folder
            let sourceGroup = findSourceGroup(in: directory, xcodeproj: existingProject)
            try writeSourceFiles(document: document, sourceRoot: sourceGroup)
        } else {
            // Fresh export — create complete Xcode project structure
            let projectDir = directory.appendingPathComponent(name)
            let sourceDir = projectDir.appendingPathComponent(name)

            // Create source files
            try writeSourceFiles(document: document, sourceRoot: sourceDir)

            // Create Assets.xcassets
            try createAssetCatalog(at: sourceDir)

            // Create .xcodeproj with project.pbxproj
            let xcodeprojDir = projectDir.appendingPathComponent("\(name).xcodeproj")
            if !fm.fileExists(atPath: xcodeprojDir.path) {
                try fm.createDirectory(at: xcodeprojDir, withIntermediateDirectories: true)
            }

            let pbxproj = generatePbxproj(document: document)
            try pbxproj.write(
                to: xcodeprojDir.appendingPathComponent("project.pbxproj"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    // MARK: - Source File Writing

    /// Write source files (App, Views, Theme) into a source root directory.
    private func writeSourceFiles(document: DesignDocument, sourceRoot: URL) throws {
        let name = projectName(from: document)

        // App entry point — goes directly in source root
        let appFile = sourceRoot.appendingPathComponent("\(name)App.swift")
        let appContent = generateAppFile(document: document)
        try ensureDirectory(at: sourceRoot)
        try appContent.write(to: appFile, atomically: true, encoding: .utf8)

        // Views
        let viewsDir = sourceRoot.appendingPathComponent("Views")
        try ensureDirectory(at: viewsDir)
        for page in document.pages {
            let viewName = sanitizeViewName(page.name)
            let content = emitter.emit(page: page, viewName: viewName)
            try content.write(
                to: viewsDir.appendingPathComponent("\(viewName).swift"),
                atomically: true,
                encoding: .utf8
            )
        }

        // Theme
        let themeDir = sourceRoot.appendingPathComponent("Theme")
        try ensureDirectory(at: themeDir)
        try generateColorsFile(tokens: document.tokens)
            .write(to: themeDir.appendingPathComponent("AppColors.swift"), atomically: true, encoding: .utf8)
        try generateSpacingFile(tokens: document.tokens)
            .write(to: themeDir.appendingPathComponent("AppSpacing.swift"), atomically: true, encoding: .utf8)
        try generateFontsFile()
            .write(to: themeDir.appendingPathComponent("AppFonts.swift"), atomically: true, encoding: .utf8)
    }

    // MARK: - Existing Project Detection

    /// Find an .xcodeproj bundle in the given directory.
    private func findExistingXcodeProject(in directory: URL) throws -> URL? {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents.first { $0.pathExtension == "xcodeproj" }
    }

    /// Find the source group folder for an existing Xcode project.
    /// Looks for the PBXFileSystemSynchronizedRootGroup path in the pbxproj,
    /// or falls back to a subfolder matching the target name.
    private func findSourceGroup(in directory: URL, xcodeproj: URL) -> URL {
        let fm = FileManager.default

        // Try to read the pbxproj and find the synchronized root group path
        let pbxprojPath = xcodeproj.appendingPathComponent("project.pbxproj")
        if let pbxContent = try? String(contentsOf: pbxprojPath, encoding: .utf8) {
            // Look for: PBXFileSystemSynchronizedRootGroup ... path = FolderName;
            let pattern = #"PBXFileSystemSynchronizedRootGroup;[\s\S]*?path\s*=\s*"?([^";]+)"?\s*;"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: pbxContent, range: NSRange(pbxContent.startIndex..., in: pbxContent)),
               let range = Range(match.range(at: 1), in: pbxContent) {
                let groupPath = String(pbxContent[range])
                let groupDir = directory.appendingPathComponent(groupPath)
                if fm.fileExists(atPath: groupDir.path) {
                    return groupDir
                }
            }
        }

        // Fallback: look for a subfolder with the same name as the xcodeproj (minus extension)
        let targetName = xcodeproj.deletingPathExtension().lastPathComponent
        let targetDir = directory.appendingPathComponent(targetName)
        if fm.fileExists(atPath: targetDir.path) {
            return targetDir
        }

        // Last resort: just use the directory itself with a subfolder matching project name
        return targetDir
    }

    // MARK: - Asset Catalog

    private func createAssetCatalog(at sourceDir: URL) throws {
        let assetsDir = sourceDir.appendingPathComponent("Assets.xcassets")
        try ensureDirectory(at: assetsDir)

        // Contents.json for the asset catalog root
        let rootContents = """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try rootContents.write(
            to: assetsDir.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )

        // AccentColor
        let accentDir = assetsDir.appendingPathComponent("AccentColor.colorset")
        try ensureDirectory(at: accentDir)
        try rootContents.write(
            to: accentDir.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )

        // AppIcon
        let iconDir = assetsDir.appendingPathComponent("AppIcon.appiconset")
        try ensureDirectory(at: iconDir)
        let iconContents = """
        {
          "images" : [
            {
              "idiom" : "universal",
              "platform" : "ios",
              "size" : "1024x1024"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try iconContents.write(
            to: iconDir.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Xcode Project File Generation (pbxproj)

    /// Generate a complete project.pbxproj that uses PBXFileSystemSynchronizedRootGroup
    /// so Xcode automatically discovers all source files.
    private func generatePbxproj(document: DesignDocument) -> String {
        let name = projectName(from: document)
        let bundleID = document.exportConfig.bundleIdentifier
        let deployTarget = document.exportConfig.deploymentTarget
        // Deterministic UUIDs based on project name for consistency
        let seed = name.hashValue
        let ids = PbxIDs(seed: seed)

        return """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {
        \t};
        \tobjectVersion = 77;
        \tobjects = {

        /* Begin PBXFileReference section */
        \t\t\(ids.appRef) /* \(name).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \(name).app; sourceTree = BUILT_PRODUCTS_DIR; };
        /* End PBXFileReference section */

        /* Begin PBXFileSystemSynchronizedRootGroup section */
        \t\t\(ids.syncGroup) /* \(name) */ = {
        \t\t\tisa = PBXFileSystemSynchronizedRootGroup;
        \t\t\tpath = \(name);
        \t\t\tsourceTree = "<group>";
        \t\t};
        /* End PBXFileSystemSynchronizedRootGroup section */

        /* Begin PBXFrameworksBuildPhase section */
        \t\t\(ids.frameworksPhase) /* Frameworks */ = {
        \t\t\tisa = PBXFrameworksBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXFrameworksBuildPhase section */

        /* Begin PBXGroup section */
        \t\t\(ids.mainGroup) = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(ids.syncGroup) /* \(name) */,
        \t\t\t\t\(ids.productsGroup) /* Products */,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t\(ids.productsGroup) /* Products */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(ids.appRef) /* \(name).app */,
        \t\t\t);
        \t\t\tname = Products;
        \t\t\tsourceTree = "<group>";
        \t\t};
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
        \t\t\(ids.nativeTarget) /* \(name) */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = \(ids.targetConfigList) /* Build configuration list for PBXNativeTarget "\(name)" */;
        \t\t\tbuildPhases = (
        \t\t\t\t\(ids.sourcesPhase) /* Sources */,
        \t\t\t\t\(ids.frameworksPhase) /* Frameworks */,
        \t\t\t\t\(ids.resourcesPhase) /* Resources */,
        \t\t\t);
        \t\t\tbuildRules = (
        \t\t\t);
        \t\t\tdependencies = (
        \t\t\t);
        \t\t\tfileSystemSynchronizedGroups = (
        \t\t\t\t\(ids.syncGroup) /* \(name) */,
        \t\t\t);
        \t\t\tname = \(name);
        \t\t\tpackageProductDependencies = (
        \t\t\t);
        \t\t\tproductName = \(name);
        \t\t\tproductReference = \(ids.appRef) /* \(name).app */;
        \t\t\tproductType = "com.apple.product-type.application";
        \t\t};
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
        \t\t\(ids.project) /* Project object */ = {
        \t\t\tisa = PBXProject;
        \t\t\tattributes = {
        \t\t\t\tBuildIndependentTargetsInParallel = 1;
        \t\t\t\tLastSwiftUpdateCheck = 2640;
        \t\t\t\tLastUpgradeCheck = 2640;
        \t\t\t\tTargetAttributes = {
        \t\t\t\t\t\(ids.nativeTarget) = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 26.4;
        \t\t\t\t\t};
        \t\t\t\t};
        \t\t\t};
        \t\t\tbuildConfigurationList = \(ids.projectConfigList) /* Build configuration list for PBXProject "\(name)" */;
        \t\t\tdevelopmentRegion = en;
        \t\t\thasScannedForEncodings = 0;
        \t\t\tknownRegions = (
        \t\t\t\ten,
        \t\t\t\tBase,
        \t\t\t);
        \t\t\tmainGroup = \(ids.mainGroup);
        \t\t\tminimizedProjectReferenceProxies = 1;
        \t\t\tpreferredProjectObjectVersion = 77;
        \t\t\tproductRefGroup = \(ids.productsGroup) /* Products */;
        \t\t\tprojectDirPath = "";
        \t\t\tprojectRoot = "";
        \t\t\ttargets = (
        \t\t\t\t\(ids.nativeTarget) /* \(name) */,
        \t\t\t);
        \t\t};
        /* End PBXProject section */

        /* Begin PBXResourcesBuildPhase section */
        \t\t\(ids.resourcesPhase) /* Resources */ = {
        \t\t\tisa = PBXResourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXResourcesBuildPhase section */

        /* Begin PBXSourcesBuildPhase section */
        \t\t\(ids.sourcesPhase) /* Sources */ = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXSourcesBuildPhase section */

        /* Begin XCBuildConfiguration section */
        \t\t\(ids.debugProjectConfig) /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
        \t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
        \t\t\t\tCLANG_ANALYZER_NONNULL = YES;
        \t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
        \t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
        \t\t\t\tCLANG_ENABLE_MODULES = YES;
        \t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
        \t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
        \t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
        \t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_COMMA = YES;
        \t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
        \t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
        \t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
        \t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
        \t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
        \t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
        \t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
        \t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
        \t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
        \t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
        \t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
        \t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
        \t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
        \t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
        \t\t\t\tCOPY_PHASE_STRIP = NO;
        \t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
        \t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
        \t\t\t\tENABLE_TESTABILITY = YES;
        \t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
        \t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
        \t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
        \t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
        \t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
        \t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
        \t\t\t\t\t"DEBUG=1",
        \t\t\t\t\t"$(inherited)",
        \t\t\t\t);
        \t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
        \t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
        \t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
        \t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
        \t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
        \t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
        \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \(deployTarget);
        \t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
        \t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
        \t\t\t\tMTL_FAST_MATH = YES;
        \t\t\t\tONLY_ACTIVE_ARCH = YES;
        \t\t\t\tSDKROOT = iphoneos;
        \t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
        \t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t\(ids.releaseProjectConfig) /* Release */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
        \t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
        \t\t\t\tCLANG_ANALYZER_NONNULL = YES;
        \t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
        \t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
        \t\t\t\tCLANG_ENABLE_MODULES = YES;
        \t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
        \t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
        \t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
        \t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_COMMA = YES;
        \t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
        \t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
        \t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
        \t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
        \t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
        \t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
        \t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
        \t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
        \t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
        \t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
        \t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
        \t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
        \t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
        \t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
        \t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
        \t\t\t\tCOPY_PHASE_STRIP = NO;
        \t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
        \t\t\t\tENABLE_NS_ASSERTIONS = NO;
        \t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
        \t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
        \t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
        \t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
        \t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
        \t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
        \t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
        \t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
        \t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
        \t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
        \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = \(deployTarget);
        \t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
        \t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
        \t\t\t\tMTL_FAST_MATH = YES;
        \t\t\t\tSDKROOT = iphoneos;
        \t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
        \t\t\t\tVALIDATE_PRODUCT = YES;
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t\t\(ids.debugTargetConfig) /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        \t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        \t\t\t\tCODE_SIGN_STYLE = Automatic;
        \t\t\t\tCURRENT_PROJECT_VERSION = 1;
        \t\t\t\tENABLE_PREVIEWS = YES;
        \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
        \t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
        \t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        \t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
        \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        \t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
        \t\t\t\t\t"$(inherited)",
        \t\t\t\t\t"@executable_path/Frameworks",
        \t\t\t\t);
        \t\t\t\tMARKETING_VERSION = 1.0;
        \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(bundleID)";
        \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
        \t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;
        \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
        \t\t\t\tSWIFT_VERSION = 5.0;
        \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t\(ids.releaseTargetConfig) /* Release */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        \t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
        \t\t\t\tCODE_SIGN_STYLE = Automatic;
        \t\t\t\tCURRENT_PROJECT_VERSION = 1;
        \t\t\t\tENABLE_PREVIEWS = YES;
        \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
        \t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
        \t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        \t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
        \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        \t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
        \t\t\t\t\t"$(inherited)",
        \t\t\t\t\t"@executable_path/Frameworks",
        \t\t\t\t);
        \t\t\t\tMARKETING_VERSION = 1.0;
        \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(bundleID)";
        \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
        \t\t\t\tSTRING_CATALOG_GENERATE_SYMBOLS = YES;
        \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
        \t\t\t\tSWIFT_VERSION = 5.0;
        \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        /* End XCBuildConfiguration section */

        /* Begin XCConfigurationList section */
        \t\t\(ids.projectConfigList) /* Build configuration list for PBXProject "\(name)" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t\(ids.debugProjectConfig) /* Debug */,
        \t\t\t\t\(ids.releaseProjectConfig) /* Release */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Release;
        \t\t};
        \t\t\(ids.targetConfigList) /* Build configuration list for PBXNativeTarget "\(name)" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t\(ids.debugTargetConfig) /* Debug */,
        \t\t\t\t\(ids.releaseTargetConfig) /* Release */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Release;
        \t\t};
        /* End XCConfigurationList section */
        \t};
        \trootObject = \(ids.project) /* Project object */;
        }
        """
    }

    // MARK: - File Generators

    private func generateAppFile(document: DesignDocument) -> String {
        let name = projectName(from: document)
        let firstPage = document.pages.first.map { sanitizeViewName($0.name) } ?? "ContentView"

        return """
        import SwiftUI

        @main
        struct \(name)App: App {
            var body: some Scene {
                WindowGroup {
                    \(firstPage)()
                }
            }
        }
        """
    }

    private func generateColorsFile(tokens: DesignTokenSet) -> String {
        return """
        import SwiftUI

        enum AppColors {
            static let accent = Color.accentColor
            static let background = Color(.systemBackground)
            static let text = Color(.label)
        }
        """
    }

    private func generateSpacingFile(tokens: DesignTokenSet) -> String {
        let values = tokens.spacingScale.map { "    static let sp\(Int($0)) = CGFloat(\(Int($0)))" }
        return """
        import SwiftUI

        enum AppSpacing {
        \(values.joined(separator: "\n"))
        }
        """
    }

    private func generateFontsFile() -> String {
        return """
        import SwiftUI

        enum AppFonts {
            static let largeTitle = Font.largeTitle
            static let title = Font.title
            static let title2 = Font.title2
            static let title3 = Font.title3
            static let headline = Font.headline
            static let body = Font.body
            static let callout = Font.callout
            static let subheadline = Font.subheadline
            static let footnote = Font.footnote
            static let caption = Font.caption
            static let caption2 = Font.caption2
        }
        """
    }

    // MARK: - Helpers

    private func projectName(from document: DesignDocument) -> String {
        let name = document.exportConfig.projectName
        return name.isEmpty ? "GeneratedApp" : name
    }

    private func sanitizeViewName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let first = cleaned.prefix(1).uppercased()
        let rest = cleaned.dropFirst()
        return first + rest + "View"
    }

    private func ensureDirectory(at url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - PBX Object IDs

/// Generates deterministic 24-char hex IDs for pbxproj objects.
private struct PbxIDs {
    let project: String
    let mainGroup: String
    let productsGroup: String
    let appRef: String
    let syncGroup: String
    let nativeTarget: String
    let sourcesPhase: String
    let frameworksPhase: String
    let resourcesPhase: String
    let projectConfigList: String
    let targetConfigList: String
    let debugProjectConfig: String
    let releaseProjectConfig: String
    let debugTargetConfig: String
    let releaseTargetConfig: String

    init(seed: Int) {
        // Generate deterministic but unique-looking IDs
        func makeID(_ index: Int) -> String {
            let value = abs(seed &+ index &* 7919) // prime multiplier for spread
            return String(format: "%012X%012X", UInt64(abs(value)), UInt64(index &+ 1) &* 0xABCDEF)
        }

        project           = makeID(1)
        mainGroup         = makeID(2)
        productsGroup     = makeID(3)
        appRef            = makeID(4)
        syncGroup         = makeID(5)
        nativeTarget      = makeID(6)
        sourcesPhase      = makeID(7)
        frameworksPhase   = makeID(8)
        resourcesPhase    = makeID(9)
        projectConfigList = makeID(10)
        targetConfigList  = makeID(11)
        debugProjectConfig  = makeID(12)
        releaseProjectConfig = makeID(13)
        debugTargetConfig   = makeID(14)
        releaseTargetConfig = makeID(15)
    }
}
