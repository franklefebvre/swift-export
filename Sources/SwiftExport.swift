import Foundation
import ArgumentParser

@main
struct SwiftExport: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swift export",
        abstract: "A utility to create macOS installer packages for command-line tools."
    )

    @Option(help: .init(
        "The path to the directory containing the configuration and code-signing files",
        discussion: """
            The path can be either absolute or relative to the current directory.
            By default, if a directory named `export` is found in the current directory, it is used; otherwise the current directory is used.
            """,
        valueName: "path"))
    var configDir: String?
    
    @Option(help: .init(
        "The path to the `export.yaml`, `export.yml` or `export.plist` file containing the export configuration.",
        discussion: """
            The path can be either absolute or relative to the directory specified by `--config-dir`.
            By default, files `export.yaml`, `export.yml` and `export.plist` are searched, in this order.
            """,
        valueName: "path"))
    var exportConfig: String?
    
    @Option(help: .init(
        "The identifier used to sign the executable binary.",
        discussion: """
            Same format as a bundle identifier, e.g. "com.example.MyAwesomeTool".
            This option overrides the identifier specified in `executable.identifier` in the export configuration.
            """))
    var identifier: String?
    
    @Option(help: .init(
        "The \"Developer ID Application\" certificate used to sign the executable file.",
        discussion: """
            Either the common name or the SHA-1 hash of the certificate can be provided.
            This option overrides the SWIFT_EXPORT_EXECUTABLE_CERTIFICATE environment variable and the value specified in `executable.certificate` in the export configuration.
            """,
        valueName: "identity"))
    var executableCertificate: String?
    
    @Option(help: .init(
        "The \"Developer ID Installer\" certificate used to sign the installer package.",
        discussion: """
            Either the common name or the SHA-1 hash of the certificate can be provided.
            This option overrides the SWIFT_EXPORT_PACKAGE_CERTIFICATE environment variable and the value specified in `package.certificate` in the export configuration.
            """,
        valueName: "identity"))
    var packageCertificate: String?
    
    @Option(help: .init(
        "The path to the entitlements file used for code signing.",
        discussion: """
            The path can be either absolute or relative to the directory containing the export configuration file.
            This option overrides the path specified in `executable.entitlements` in the export configuration.
            Default value: `hardened.entitlements` if this file exists. Otherwise default entitlements will be provided, with hardened runtime enabled and sandbox disabled.
            """,
        valueName: "path"))
    var entitlements: String?
    
    @Option(help: .init(
        "The output path (either pkg file or parent directory).",
        discussion: """
            The path can be either absolute or relative to the current directory.
            If a directory is provided, the name of the package will be based on the project name.
            Default value: current directory.
            """,
        valueName: "path"))
    var output: String?
    
    @Option(help: .init(
        "The identifier used to sign the installer package.",
        discussion: """
            Same format as a bundle identifier, e.g. "com.example.MyAwesomeTool".
            This option overrides the identifier specified in `package.identifier` in the export configuration.
            Default value: same as executable identifier.
            """,
        valueName: "identifier"))
    var packageIdentifier: String?
    
    @Option(help: .init(
        "The version number of the installer package.",
        discussion: """
            This option overrides the identifier specified in `package.version` in the export configuration.
            """,
        valueName: "version"))
    var packageVersion: String?
    
    @Option(help: .init(
        "The keychain profile name used to identify the developer account when submitting the package for notarization.",
        discussion: """
            This option overrides the SWIFT_EXPORT_NOTARY_PROFILE environment variable and the name specified in `notary.profile` in the export configuration.
            """,
        valueName: "name"))
    var notaryProfile: String?
    
    @Flag(help: "Print debugging and progress messages.")
    var verbose = false
    
    @Flag(help: "Print the commands to be performed, without actually performing them.")
    var dryRun = false

    mutating func run() async throws {
        let currentDirectory = URL.currentDirectory()
        let config = try Config(currentDirectory: currentDirectory, environment: ProcessInfo.processInfo.environment, parsedCommand: self)
        let shell = config.shell
        let cmd = CommandRunner(outputMode: .recorded)
        
        let logger = Logger(level: .info)
        
        var architectures = config.exportConfig.executable.architectures
        if architectures.isEmpty {
            architectures = ["arm64", "x86_64"]
        }
        let archsOptions = architectures.flatMap { ["--arch", $0] }
        
        guard let packageDescriptionData = try await cmd.data(.swift, "package", "describe", "--type", "json"),
              let packageDescriptionDict = try JSONSerialization.jsonObject(with: packageDescriptionData) as? [String: Any],
//              let firstProduct = (packageDescriptionDict["package"] as? [[String: Any]])?.first,
              let builtExecutableName = packageDescriptionDict["name"] as? String
        else { throw ExportError.missingExecutableName }
        guard let executableDirPath = try await cmd.string(.swift, args: ["build", "--configuration", "release"] + archsOptions + ["--show-bin-path"]) else { throw ExportError.cantDetectExecutablePath }
        
        let builtExecutableURL = URL(filePath: executableDirPath).appending(components: builtExecutableName, directoryHint: .notDirectory)

        await logger.info("Building executable")
        try await shell(.swift, ["build", "--configuration", "release"] + archsOptions)
        
        let pkgRoot = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        let installPath = config.exportConfig.package.executable?.destination ?? "/usr/local/bin"
        let installDirectory = pkgRoot.appending(path: installPath.trimmingPrefix("/"), directoryHint: .isDirectory)
        let installedExecutableName = config.executableName ?? builtExecutableName
        let pkgRootExecutableURL = installDirectory.appending(path: installedExecutableName, directoryHint: .notDirectory)
        let executablePath = pkgRootExecutableURL.filePath
        
        guard let codesignIdentifier = config.exportConfig.executable.identifier else {
            throw ExportError.missingConfigField(name: "executable.identifier")
        }
        
        if !dryRun {
            await logger.info("Creating root directory for installer package at \(pkgRoot.filePath)")
            try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
            // Can't defer here: this is an asynchronous context.
            await logger.info("Copying executable to \(executablePath)")
            try FileManager.default.copyItem(at: builtExecutableURL, to: pkgRootExecutableURL)
            
            for resource in config.exportConfig.package.resources ?? [] {
                let installDirectory = pkgRoot.appending(path: resource.destination.trimmingPrefix("/"), directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
                await logger.info("Copying \(resource.source) to \(installDirectory.filePath)")
                let resourceURL = currentDirectory.appending(path: resource.source)
                try FileManager.default.copyItem(at: resourceURL, to: installDirectory.appending(path: resourceURL.lastPathComponent))
            }
        }
        
        let entitlementsFile: URL
        if let configEntitlementsFile = config.entitlementsFile {
            entitlementsFile = configEntitlementsFile
        } else {
            entitlementsFile = URL.temporaryDirectory.appending(component: "entitlements", directoryHint: .notDirectory)
            if !dryRun {
                await logger.info("Creating default entitlements")
                let defaultEntitlements = ["com.apple.security.app-sandbox": false]
                let entitlementsData = try PropertyListEncoder().encode(defaultEntitlements)
                try entitlementsData.write(to: entitlementsFile)
            }
        }
        
        await logger.info("Signing executable")
        // target = .build/release/target_name
        try await shell(.codesign, "--force", "--entitlements", entitlementsFile.filePath, "--options", "runtime", "--sign", config.exportConfig.executable.certificate, "--identifier=\"\(codesignIdentifier)\"", executablePath)
        try await shell(.codesign, "--verify", "--verbose", executablePath)

        if !dryRun {
            await logger.info("Creating output directory: \(config.outputDirectory.filePath)")
            try FileManager.default.createDirectory(at: config.outputDirectory, withIntermediateDirectories: true)
        }
        let pkgName = config.pkgName ?? installedExecutableName + ".pkg"
        let pkgFile = config.outputDirectory.appending(path: pkgName, directoryHint: .notDirectory)
        
        await logger.info("Creating signed installer package at \(pkgFile.filePath)")
        let pkgIdentifier = config.exportConfig.package.identifier ?? codesignIdentifier
        try await shell(.pkgbuild, "--identifier", pkgIdentifier, "--version", config.pkgVersion, "--root", pkgRoot.filePath, "--sign", config.exportConfig.package.certificate, pkgFile.filePath)

        await logger.info("Submitting installer package for notarization")
        try await shell(.xcrun, "notarytool", "submit", pkgFile.filePath, "--keychain-profile", config.exportConfig.notary.keychainProfile, "--wait")
        await logger.info("Stapling notarization receipt to installer package")
        try await shell(.xcrun, "stapler", "staple", "-v", pkgFile.filePath)
        
        if !dryRun {
            await logger.info("Deleting temporary files")
            if config.entitlementsFile == nil {
                try? FileManager.default.removeItem(at: entitlementsFile)
            }
            try? FileManager.default.removeItem(at: installDirectory)
        }
        
        await logger.info("Done")
    }
}
