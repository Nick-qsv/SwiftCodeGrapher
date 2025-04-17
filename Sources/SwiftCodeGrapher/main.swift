import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Main Entry Function
func main() -> Int {
    let arguments = CommandLine.arguments

    // Expect at least 2 arguments: the script name + a directory path
    guard arguments.count > 1 else {
        print("Usage: swift run SwiftCodeGrapher <path-to-swift-project>")
        return 1
    }

    let projectPath = arguments[1]
    let projectURL = URL(fileURLWithPath: projectPath)
    print("🔎 Scanning directory: \(projectURL.path)")

    do {
        // Gather .swift files recursively
        let swiftFileURLs = try gatherSwiftFiles(in: projectURL)
        if swiftFileURLs.isEmpty {
            print("No .swift files found in \(projectURL.path).")
            return 0
        }

        // Parse each .swift file
        let collector = DependencyCollector()
        for fileURL in swiftFileURLs {
            print("Parsing \(fileURL.path)")
            let source = try String(contentsOf: fileURL)
            let syntax = Parser.parse(source: source)
            collector.walk(syntax)
        }

        // Convert to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(collector.entities)

        // Write JSON
        let currentDir = FileManager.default.currentDirectoryPath
        let outputDirURL = URL(fileURLWithPath: currentDir)
        let outputURL = outputDirURL.appendingPathComponent("codegraph.json")

        try jsonData.write(to: outputURL)
        print("✅ Wrote codegraph.json to: \(outputURL.path)")
        return 0

    } catch {
        print("❌ Error: \(error.localizedDescription)")
        return 1
    }
}

// MARK: - Gather Swift Files
func gatherSwiftFiles(in directory: URL) throws -> [URL] {
    var swiftFiles: [URL] = []
    let fileManager = FileManager.default

    if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            print("Found file: \(fileURL.path)")
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }
    }
    return swiftFiles
}

// MARK: - Actual Program Start
let exitCode = main()
exit(Int32(exitCode))
