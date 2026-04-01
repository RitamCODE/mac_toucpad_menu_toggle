import Foundation

struct ProcessOutput {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

struct ProcessRunner {
    func run(executablePath: String, arguments: [String]) throws -> ProcessOutput {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessOutput(
            terminationStatus: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            standardError: String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
