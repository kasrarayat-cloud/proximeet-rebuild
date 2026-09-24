import Foundation
import XCTest

/// Guards the "no side effects" rules at the source level: the domain must not persist,
/// network, locate, authenticate, read the clock, or schedule work. Comments are ignored.
final class DomainSourceGuardTests: XCTestCase {
    private static let forbiddenTokens = [
        // Persistence
        "UserDefaults", "FileManager", "SecItem", "Keychain", "Codable", "Encodable", "Decodable",
        "NSUbiquitousKeyValueStore", "CoreData", "SwiftData",
        // Network, presence, authentication
        "URLSession", "URLRequest", "import Network", "CoreLocation", "CoreBluetooth",
        "MultipeerConnectivity", "AuthenticationServices", "LocalAuthentication",
        // Clock and timing
        "Date()", "Date.now", "Date(timeIntervalSinceNow", "ProcessInfo", "DispatchQueue",
        "Timer", "Task.sleep", "Thread.sleep", "async ", "await ", "import Combine",
    ]

    private func domainSources() throws -> [(name: String, code: String)] {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ProximeetDomainTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources/ProximeetDomain")
        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try names.map { name in
            let text = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            let code = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> Substring in
                    guard let comment = line.range(of: "//") else { return line }
                    return line[..<comment.lowerBound]
                }
                .joined(separator: "\n")
            return (name, code)
        }
    }

    func testDomainSourcesHaveNoSideEffectAPIs() throws {
        let sources = try domainSources()
        XCTAssertGreaterThanOrEqual(sources.count, 8, "Expected the domain sources to be found")
        for source in sources {
            for token in Self.forbiddenTokens {
                XCTAssertFalse(source.code.contains(token), "\(source.name) uses \(token)")
            }
        }
    }

    func testDomainImportsOnlyFoundation() throws {
        for source in try domainSources() {
            let imports = source.code
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
            for line in imports {
                XCTAssertEqual(line, "import Foundation", "\(source.name) has \(line)")
            }
        }
    }
}
