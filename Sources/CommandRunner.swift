import Foundation

struct ShellCommand {
    let path: String
    var url: URL { .init(filePath: path, directoryHint: .notDirectory) }
    var name: String { url.lastPathComponent }
}

extension ShellCommand {
    static var swift: Self { .init(path: "/usr/bin/swift") }
    static var codesign: Self { .init(path: "/usr/bin/codesign") }
    static var pkgbuild: Self { .init(path: "/usr/bin/pkgbuild") }
    static var xcrun: Self { .init(path: "/usr/bin/xcrun") }
}

actor CommandRunner {
    enum OutputMode {
        case silent
        case verbose
        case recorded
    }
    
    private let outputMode: OutputMode
    
    init(outputMode: OutputMode) {
        self.outputMode = outputMode
    }
    
    func run(_ executable: URL, args: [String]) throws -> Data? {
        let process = Process()
        process.executableURL = executable
        process.arguments = args
        let stdoutPipe: Pipe?
        switch outputMode {
        case .silent:
            stdoutPipe = nil
            process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
            process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        case .verbose:
            stdoutPipe = nil
        case .recorded:
            stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        }
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(process.terminationStatus))
        }
        return try stdoutPipe?.fileHandleForReading.readToEnd()
    }
    
    func data(_ command: ShellCommand, _ args: String...) throws -> Data? {
        try run(command.url, args: args)
    }
    
    func string(_ command: ShellCommand, args: [String]) throws -> String? {
        guard let data = try run(command.url, args: args) else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
    }
    
    func string(_ command: ShellCommand, _ args: String...) throws -> String? {
        try string(command, args: args)
    }
}

protocol RunnerProtocol {
    func run(command: ShellCommand, args: [String]) async throws -> Data?
}

extension RunnerProtocol {
    @discardableResult
    func callAsFunction(_ command: ShellCommand, _ args: String...) async throws -> Data? {
        try await run(command: command, args: args)
    }
    
    @discardableResult
    func callAsFunction(_ command: ShellCommand, _ args: [String]) async throws -> Data? {
        try await run(command: command, args: args)
    }
}

extension CommandRunner: RunnerProtocol {
    func run(command: ShellCommand, args: [String]) throws -> Data? {
        print((command.name + " " + args.joined(separator: " ")).commandStyle)
        let executable = command.url
        return try run(executable, args: args)
    }
}

actor MockRunner: RunnerProtocol {
    func run(command: ShellCommand, args: [String]) -> Data? {
        print((command.name + " " + args.joined(separator: " ")).commandStyle)
        return nil
    }
}
