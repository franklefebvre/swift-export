import Foundation

actor Logger {
    enum Level: Int, Comparable {
        case info
        case error

        static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    var level: Level
    
    init(level: Level) {
        self.level = level
    }
    
    func info(_ message: @autoclosure () -> String) {
        guard level <= .info else { return }
        print(message().messageStyle)
    }
}
