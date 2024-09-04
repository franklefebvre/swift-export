import Foundation

extension URL {
    var filePath: String {
        standardizedFileURL.path(percentEncoded: false)
    }
}
