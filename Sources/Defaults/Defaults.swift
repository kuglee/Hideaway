import Foundation
import os.log

enum DefaultsError: Error, LocalizedError {
  case readError(message: String)
  case writeError(message: String)
  case deleteError(message: String)

  var errorDescription: String {
    switch self {
    case let .readError(message): return message
    case let .writeError(message): return message
    case let .deleteError(message): return message
    }
  }
}

// modify defaults using the defaults command because user defaults of system apps can't be
// modified even with sandboxing turned off
public struct Defaults {
  private static let defaultsExecutable = URL(filePath: "/usr/bin/defaults")

  private static func read(key: Defaults.Keys, bundleIdentifier: String) throws -> Bool? {
    do {
      let output = try run(
        command: defaultsExecutable,
        with: ["read", bundleIdentifier, key.rawValue]
      )

      return output == "1\n" ? true : false
    } catch {
      if !error.localizedDescription.contains(
        "\(bundleIdentifier), \(key.rawValue)) does not exist"
      ) {
        throw DefaultsError.readError(
          message: "Unable to read the value for key \"\(key.rawValue)\" of \"\(bundleIdentifier)\""
        )
      }

      return nil
    }
  }

  private static func writeBool(key: Defaults.Keys, value: Bool, bundleIdentifier: String) throws {
    do {
      _ = try run(
        command: defaultsExecutable,
        with: ["write", bundleIdentifier, key.rawValue, "-int", value ? "1" : "0"]
      )
    } catch {
      throw DefaultsError.writeError(
        message: "Unable to write value \"\(value)\" for key \"\(key)\" of \"\(bundleIdentifier)\""
      )
    }
  }

  private static func delete(key: Defaults.Keys, bundleIdentifier: String) throws {
    do {
      _ = try run(command: defaultsExecutable, with: ["delete", bundleIdentifier, key.rawValue])
    } catch {
      if !error.localizedDescription.contains("\(bundleIdentifier)) not found.") {
        throw DefaultsError.deleteError(
          message: "Unable to delete key \"\(key)\" of \"\(bundleIdentifier)\""
        )
      }
    }
  }

  public static func get(key: Defaults.Keys, bundleIdentifier: String) throws -> Bool? {
    do { return try self.read(key: key, bundleIdentifier: bundleIdentifier) } catch { throw error }
  }

  public static func set(key: Defaults.Keys, value: Bool?, bundleIdentifier: String) throws {
    do {
      if let value {
        try Defaults.writeBool(key: key, value: value, bundleIdentifier: bundleIdentifier)
      } else {
        try Defaults.delete(key: key, bundleIdentifier: bundleIdentifier)
      }
    } catch { throw error }
  }
}

extension Defaults {
  public struct Keys: Hashable, Equatable, RawRepresentable {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
  }
}

enum CommandError: Error, LocalizedError {
  case runError(message: String)
  case commandError(command: String, errorMessage: String?, exitStatus: Int)

  var errorDescription: String? {
    switch self {
    case .runError(let message): return message
    case .commandError(let command, let errorMessage, let exitStatus):
      var description = "Error: \(command) failed with exit status \(exitStatus)."

      if let errorMessage = errorMessage { description += " Error message: \(errorMessage)" }

      return description
    }
  }
}

func run(command lauchPath: URL, with arguments: [String] = []) throws -> String? {
  let process = Process()
  process.executableURL = lauchPath
  process.arguments = arguments

  let standardOutput = Pipe()
  let standardError = Pipe()
  process.standardOutput = standardOutput
  process.standardError = standardError

  do { try process.run() } catch (let error) {
    throw CommandError.runError(message: error.localizedDescription)
  }

  let standardOutputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: standardOutputData, encoding: .utf8)
  let standardErrorData = standardError.fileHandleForReading.readDataToEndOfFile()
  let errorMessage = String(data: standardErrorData, encoding: .utf8)

  process.waitUntilExit()

  if process.terminationStatus != 0 {
    throw CommandError.commandError(
      command: process.executableURL!.lastPathComponent,
      errorMessage: errorMessage,
      exitStatus: Int(process.terminationStatus)
    )
  }

  return output
}
