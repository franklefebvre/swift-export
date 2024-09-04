import Foundation
import Yams

struct OverridableExportConfig: Codable {
    struct Executable: Codable {
        var architectures: [String]?
        var identifier: String?
        var certificate: String?
        var entitlements: String?
    }
    struct InstallExecutable: Codable {
        var source: String?
        var destination: String?
    }
    struct InstallResource: Codable {
        var source: String
        var destination: String
    }
    struct Package: Codable {
        var identifier: String?
        var version: String?
        var certificate: String?
        var executable: InstallExecutable?
        var resources: [InstallResource]?
        // TODO: preinstall/postinstall scripts
    }
    struct Notary: Codable {
        var keychainProfile: String?
        private enum CodingKeys: String, CodingKey {
            case keychainProfile = "keychain-profile"
        }
    }
    var executable: Executable?
    var package: Package?
    var notary: Notary?
}

extension OverridableExportConfig.Executable {
    init(parsedCommand: SwiftExport) {
        identifier = parsedCommand.identifier
        certificate = parsedCommand.executableCertificate
        entitlements = parsedCommand.entitlements
    }
    
    init(environment: [String : String]) {
        certificate = environment["SWIFT_EXPORT_EXECUTABLE_CERTIFICATE"]
    }
    
    func overridden(with other: OverridableExportConfig.Executable?) -> Self {
        guard let other else { return self }
        var overridden = self
        overridden.architectures = other.architectures ?? architectures
        overridden.identifier = other.identifier ?? identifier
        overridden.certificate = other.certificate ?? certificate
        overridden.entitlements = other.entitlements ?? entitlements
        return overridden
    }
}

extension OverridableExportConfig.Package {
    init(parsedCommand: SwiftExport) {
        identifier = parsedCommand.packageIdentifier
        version = parsedCommand.packageVersion
        certificate = parsedCommand.packageCertificate
    }
    
    init(environment: [String : String]) {
        certificate = environment["SWIFT_EXPORT_PACKAGE_CERTIFICATE"]
    }
    
    func overridden(with other: OverridableExportConfig.Package?) -> Self {
        guard let other else { return self }
        var overridden = self
        overridden.identifier = other.identifier ?? identifier
        overridden.version = other.version ?? version
        overridden.certificate = other.certificate ?? certificate
        overridden.executable = other.executable ?? executable
        overridden.resources = other.resources ?? resources
        return overridden
    }
}

extension OverridableExportConfig.Notary {
    init(parsedCommand: SwiftExport) {
         keychainProfile = parsedCommand.notaryProfile
    }
    
    init(environment: [String : String]) {
        keychainProfile = environment["SWIFT_EXPORT_NOTARY_PROFILE"]
    }
    
    func overridden(with other: OverridableExportConfig.Notary?) -> Self {
        guard let other else { return self }
        var overridden = self
        overridden.keychainProfile = other.keychainProfile ?? keychainProfile
        return overridden
    }
}

extension OverridableExportConfig {
    init(parsedCommand: SwiftExport) {
        self.executable = Executable(parsedCommand: parsedCommand)
        self.package = Package(parsedCommand: parsedCommand)
        self.notary = Notary(parsedCommand: parsedCommand)
    }
    
    init(environment: [String : String]) {
        self.executable = Executable(environment: environment)
        self.package = Package(environment: environment)
        self.notary = Notary(environment: environment)
    }
    
    func overridden(with other: OverridableExportConfig) -> Self {
        var overridden = self
        overridden.executable = (overridden.executable ?? .init()).overridden(with: other.executable)
        overridden.package = (overridden.package ?? .init()).overridden(with: other.package)
        overridden.notary = (overridden.notary ?? .init()).overridden(with: other.notary)
        return overridden
    }
}

struct ExportConfig {
    struct Executable {
        var architectures: [String]
        var identifier: String?
        var certificate: String
        var entitlements: String?
    }
    struct InstallExecutable {
        var source: String?
        var destination: String?
    }
    struct InstallResource {
        var source: String
        var destination: String
    }
    struct Package {
        var identifier: String?
        var version: String?
        var certificate: String
        var executable: InstallExecutable?
        var resources: [InstallResource]?
        // TODO: preinstall/postinstall scripts
    }
    struct Notary {
        var keychainProfile: String
    }
    var executable: Executable
    var package: Package
    var notary: Notary
}

extension ExportConfig {
    init(_ overridable: OverridableExportConfig) throws {
        guard let overridableExecutable = overridable.executable else { throw ExportError.missingConfigField(name: "executable") }
        guard let overridablePackage = overridable.package else { throw ExportError.missingConfigField(name: "package") }
        guard let overridableNotary = overridable.notary else { throw ExportError.missingConfigField(name: "notary") }
        self.executable = try .init(overridableExecutable)
        self.package = try .init(overridablePackage)
        self.notary = try .init(overridableNotary)
    }
}

extension ExportConfig.Executable {
    init(_ overridable: OverridableExportConfig.Executable) throws {
        guard let overridableCertificate = overridable.certificate else { throw ExportError.missingConfigField(name: "executable.certificate") }
        certificate = overridableCertificate
        architectures = overridable.architectures ?? []
        identifier = overridable.identifier
        entitlements = overridable.entitlements
    }
}

extension ExportConfig.InstallExecutable {
    init(_ overridable: OverridableExportConfig.InstallExecutable) {
        source = overridable.source
        destination = overridable.destination
    }
}

extension ExportConfig.InstallResource {
    init(_ overridable: OverridableExportConfig.InstallResource) {
        source = overridable.source
        destination = overridable.destination
    }
}

extension ExportConfig.Package {
    init(_ overridable: OverridableExportConfig.Package) throws {
        guard let overridableCertificate = overridable.certificate else { throw ExportError.missingConfigField(name: "package.certificate") }
        identifier = overridable.identifier
        version = overridable.version
        certificate = overridableCertificate
        if let overridableExecutable = overridable.executable {
            executable = .init(overridableExecutable)
        } else {
            executable = nil
        }
        if let overridableResources = overridable.resources {
            resources = overridableResources.map(ExportConfig.InstallResource.init)
        } else {
            resources = nil
        }
    }
}

extension ExportConfig.Notary {
    init(_ overridable: OverridableExportConfig.Notary) throws {
        guard let overridableKeychainProfile = overridable.keychainProfile else { throw ExportError.missingConfigField(name: "notary.keychain-profile") }
        keychainProfile = overridableKeychainProfile
    }
}

struct Config {
    let currentDirectory: URL
    let configDirectory: URL
    let outputDirectory: URL
    let parsedCommand: SwiftExport
    let shell: RunnerProtocol
    let configFile: URL?
    let exportConfig: ExportConfig
    let entitlementsFile: URL?
    let executableName: String?
    let pkgName: String?
    let pkgVersion: String
    
    init(currentDirectory: URL, environment: [String: String], parsedCommand: SwiftExport) throws {
        self.currentDirectory = currentDirectory
        self.parsedCommand = parsedCommand

        if parsedCommand.dryRun {
            shell = MockRunner()
        } else {
            shell = CommandRunner(outputMode: parsedCommand.verbose ? .verbose : .silent)
        }
        
        var exportConfig = OverridableExportConfig(environment: environment)
        
        self.configFile = Self.configFile(currentDirectory: currentDirectory, parsedCommand: parsedCommand)
        if let configFile {
            let configData = try Data(contentsOf: configFile)
            switch configFile.pathExtension.lowercased() {
            case "yml", "yaml":
                exportConfig = exportConfig.overridden(with: try YAMLDecoder().decode(OverridableExportConfig.self, from: configData))
            case "plist":
                exportConfig = exportConfig.overridden(with: try PropertyListDecoder().decode(OverridableExportConfig.self, from: configData))
            default:
                throw ExportError.invalidConfigFile
            }
            self.configDirectory = configFile.deletingLastPathComponent()
        } else {
            self.configDirectory = currentDirectory
        }
        
        exportConfig = exportConfig.overridden(with: .init(parsedCommand: parsedCommand))
        self.exportConfig = try ExportConfig(exportConfig)
        
        if let output = parsedCommand.output {
            self.outputDirectory = URL(filePath: output, directoryHint: .inferFromPath, relativeTo: currentDirectory)
        } else {
            self.outputDirectory = currentDirectory
        }
        
        var entitlementsPath = parsedCommand.entitlements ?? exportConfig.executable?.entitlements
        if entitlementsPath == nil {
            let defaultEntitlementsPath = "hardened.entitlements"
            let defaultEntitlementsFile = URL(filePath: defaultEntitlementsPath, directoryHint: .notDirectory, relativeTo: configDirectory)
            if FileManager.default.fileExists(atPath: defaultEntitlementsFile.filePath) {
                entitlementsPath = defaultEntitlementsPath
            }
        }
        
        if let entitlementsPath {
            self.entitlementsFile = URL(filePath: entitlementsPath, directoryHint: .notDirectory, relativeTo: configDirectory)
        } else {
            self.entitlementsFile = nil
        }
        
        guard let packageVersion = exportConfig.package?.version else { throw ExportError.missingConfigField(name: "package.version") }
        self.executableName = exportConfig.package?.executable?.source
        self.pkgName = executableName?.appending(".pkg")
        self.pkgVersion = packageVersion
    }
    
    private static func configFile(currentDirectory: URL, parsedCommand: SwiftExport) -> URL? {
        let lookupDirectory: URL
        if let configDir = parsedCommand.configDir {
            lookupDirectory = URL(filePath: configDir, directoryHint: .isDirectory, relativeTo: currentDirectory)
        } else {
            let exportDirectory = URL(filePath: "export", directoryHint: .isDirectory, relativeTo: currentDirectory)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: exportDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue {
                lookupDirectory = exportDirectory
            } else {
                lookupDirectory = currentDirectory
            }
        }
        if let configFile = parsedCommand.exportConfig {
            return URL(filePath: configFile, directoryHint: .notDirectory, relativeTo: lookupDirectory)
        }
        let yamlConfigFile = lookupDirectory.appending(path: "export.yaml", directoryHint: .notDirectory)
        let ymlConfigFile = lookupDirectory.appending(path: "export.yml", directoryHint: .notDirectory)
        let plistConfigFile = lookupDirectory.appending(path: "export.plist", directoryHint: .notDirectory)
        if (try? Data(contentsOf: yamlConfigFile)) != nil {
            return yamlConfigFile
        }
        if (try? Data(contentsOf: ymlConfigFile)) != nil {
            return ymlConfigFile
        }
        if (try? Data(contentsOf: plistConfigFile)) != nil {
            return plistConfigFile
        }
        return nil
    }
}
