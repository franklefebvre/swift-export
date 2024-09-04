import Foundation

enum ExportError: Error {
    case missingConfigFile(lookupDir: URL)
    case invalidConfigFile
    case invalidBundleIdentifier
    case missingConfigField(name: String)
    case missingExecutableName
    case cantDetectExecutablePath
}

extension ExportError: CustomStringConvertible {
    var description: String {
        switch self {
        case .missingConfigFile(lookupDir: let lookupDir):
            "Missing configuration file in \(lookupDir.filePath)."
        case .invalidConfigFile:
            "Invalid config file."
        case .invalidBundleIdentifier:
            "Invalid bundle identifier"
        case .missingConfigField(name: let name):
            "Missing config field: \(name)"
        case .missingExecutableName:
            "Missing executable name"
        case .cantDetectExecutablePath:
            "Can't detect executable path"
        }
    }
}
