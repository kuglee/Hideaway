import Foundation

// modify defaults using the defaults command because user defaults of system apps can't be
// modified even with sandboxing turned off
public struct Defaults {
  private static let defaultsExecutable = URL(filePath: "/usr/bin/defaults")

  private static func read(bundleIdentifier: String, key: Defaults.Keys) -> Bool? {
    let result = run(command: defaultsExecutable, with: ["read", bundleIdentifier, key.rawValue])

    switch result {
    case .success(let output): return output == "1\n" ? true : false
    case .failure(_): return nil
    }
  }

  private static func writeBool(bundleIdentifier: String, key: Defaults.Keys, value: Bool) {
    _ = run(
      command: defaultsExecutable,
      with: ["write", bundleIdentifier, key.rawValue, "-int", value ? "1" : "0"]
    )
  }

  private static func delete(bundleIdentifier: String, key: Defaults.Keys) {
    _ = run(command: defaultsExecutable, with: ["delete", bundleIdentifier, key.rawValue])
  }

  public static subscript(key: Defaults.Keys, bundleIdentifier: String) -> Bool? {
    get { Defaults.read(bundleIdentifier: bundleIdentifier, key: key) }
    set {
      if let newValue {
        Defaults.writeBool(bundleIdentifier: bundleIdentifier, key: key, value: newValue)
      } else {
        Defaults.delete(bundleIdentifier: bundleIdentifier, key: key)
      }
    }
  }
}

extension Defaults {
  public struct Keys: Hashable, Equatable, RawRepresentable {
    public var rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
  }
}

enum CommandError: Error, LocalizedError {
  case runError(message: String)
  case commandError(command: String, errorMessage: String?, exitStatus: Int)

  var localizedDescription: String {
    switch self {
    case .runError(let error): return error
    case .commandError(let command, let errorMessage, let exitStatus):
      var description = "Error: \(command) failed with exit status \(exitStatus)."

      if let errorMessage = errorMessage { description += " Error message: \(errorMessage)" }

      return description
    }
  }
}

func run(command lauchPath: URL, with arguments: [String] = []) -> Result<String?, CommandError> {
  let process = Process()
  process.executableURL = lauchPath
  process.arguments = arguments

  let standardOutput = Pipe()
  let standardError = Pipe()
  process.standardOutput = standardOutput
  process.standardError = standardError

  do { try process.run() } catch { return .failure(.runError(message: error.localizedDescription)) }

  let standardOutputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: standardOutputData, encoding: .utf8)
  let standardErrorData = standardError.fileHandleForReading.readDataToEndOfFile()
  let errorMessage = String(data: standardErrorData, encoding: .utf8)

  process.waitUntilExit()

  if process.terminationStatus != 0 {
    return .failure(
      .commandError(
        command: process.executableURL!.lastPathComponent,
        errorMessage: errorMessage,
        exitStatus: Int(process.terminationStatus)
      )
    )
  }

  return .success(output)
}
