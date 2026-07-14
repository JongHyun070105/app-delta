import Darwin
import Foundation

enum SystemTool: String, Sendable {
  case codesign
  case spctl
  case hdiutil
  case pkgutil
  case tar
  case xar
  case shasum

  var executableURL: URL {
    switch self {
    case .codesign: URL(fileURLWithPath: "/usr/bin/codesign")
    case .spctl: URL(fileURLWithPath: "/usr/sbin/spctl")
    case .hdiutil: URL(fileURLWithPath: "/usr/bin/hdiutil")
    case .pkgutil: URL(fileURLWithPath: "/usr/sbin/pkgutil")
    case .tar: URL(fileURLWithPath: "/usr/bin/tar")
    case .xar: URL(fileURLWithPath: "/usr/bin/xar")
    case .shasum: URL(fileURLWithPath: "/usr/bin/shasum")
    }
  }
}

struct CommandResult: Equatable, Sendable {
  var status: Int32
  var standardOutput: Data
  var standardError: Data

  var outputString: String {
    String(decoding: standardOutput, as: UTF8.self)
  }

  var errorString: String {
    String(decoding: standardError, as: UTF8.self)
  }

  var combinedString: String {
    [outputString, errorString].filter { !$0.isEmpty }.joined(separator: "\n")
  }
}

protocol CommandRunning: Sendable {
  func run(_ tool: SystemTool, arguments: [String], budget: ScanBudget) throws -> CommandResult
}

private final class BoundedBuffer: @unchecked Sendable {
  private let lock = NSLock()
  private var data = Data()
  private var exceeded = false
  private let limit: Int

  init(limit: Int) {
    self.limit = limit
  }

  func append(_ chunk: Data) {
    guard !chunk.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    let remaining = max(0, limit - data.count)
    if chunk.count > remaining { exceeded = true }
    if remaining > 0 { data.append(chunk.prefix(remaining)) }
  }

  func snapshot() -> Data {
    lock.lock()
    defer { lock.unlock() }
    return data
  }

  var didExceedLimit: Bool {
    lock.lock()
    defer { lock.unlock() }
    return exceeded
  }
}

struct BoundedCommandRunner: CommandRunning {
  func run(_ tool: SystemTool, arguments: [String], budget: ScanBudget = .default) throws
    -> CommandResult
  {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let outputBuffer = BoundedBuffer(limit: budget.maximumToolOutputBytes)
    let errorBuffer = BoundedBuffer(limit: budget.maximumToolOutputBytes)
    let readers = DispatchGroup()

    process.executableURL = tool.executableURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.environment = sanitizedEnvironment()

    readers.enter()
    outputPipe.fileHandleForReading.readabilityHandler = { handle in
      let chunk = handle.availableData
      if chunk.isEmpty {
        handle.readabilityHandler = nil
        readers.leave()
      } else {
        outputBuffer.append(chunk)
      }
    }

    readers.enter()
    errorPipe.fileHandleForReading.readabilityHandler = { handle in
      let chunk = handle.availableData
      if chunk.isEmpty {
        handle.readabilityHandler = nil
        readers.leave()
      } else {
        errorBuffer.append(chunk)
      }
    }

    try process.run()

    let deadline = Date().addingTimeInterval(budget.commandTimeout)
    let isCleanupCommand =
      tool == .hdiutil && ["detach", "info"].contains(arguments.first)
    var timedOut = false
    var outputLimitExceeded = false
    while process.isRunning {
      if Task.isCancelled, !isCleanupCommand {
        terminate(process)
        finishReading(outputPipe: outputPipe, errorPipe: errorPipe, readers: readers)
        throw CancellationError()
      }
      if outputBuffer.didExceedLimit || errorBuffer.didExceedLimit {
        outputLimitExceeded = true
        terminate(process)
        break
      }
      if Date() >= deadline {
        timedOut = true
        terminate(process)
        break
      }
      Thread.sleep(forTimeInterval: 0.02)
    }
    process.waitUntilExit()
    finishReading(outputPipe: outputPipe, errorPipe: errorPipe, readers: readers)

    if outputLimitExceeded || outputBuffer.didExceedLimit || errorBuffer.didExceedLimit {
      throw AnalysisError.outputLimitExceeded(tool.rawValue)
    }
    if timedOut {
      throw AnalysisError.commandTimedOut(tool.rawValue)
    }
    if !isCleanupCommand {
      try Task.checkCancellation()
    }

    return CommandResult(
      status: process.terminationStatus,
      standardOutput: outputBuffer.snapshot(),
      standardError: errorBuffer.snapshot()
    )
  }

  private func terminate(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let graceDeadline = Date().addingTimeInterval(0.5)
    while process.isRunning, Date() < graceDeadline {
      Thread.sleep(forTimeInterval: 0.02)
    }
    if process.isRunning {
      Darwin.kill(process.processIdentifier, SIGKILL)
    }
  }

  private func finishReading(outputPipe: Pipe, errorPipe: Pipe, readers: DispatchGroup) {
    _ = readers.wait(timeout: .now() + 2)
    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil
    try? outputPipe.fileHandleForReading.close()
    try? errorPipe.fileHandleForReading.close()
  }

  private func sanitizedEnvironment() -> [String: String] {
    let environment = ProcessInfo.processInfo.environment
    return [
      "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
      "LANG": environment["LANG"] ?? "en_US.UTF-8",
      "LC_ALL": environment["LC_ALL"] ?? "en_US.UTF-8",
      "HOME": environment["HOME"] ?? NSHomeDirectory(),
      "TMPDIR": environment["TMPDIR"] ?? NSTemporaryDirectory(),
    ]
  }
}
