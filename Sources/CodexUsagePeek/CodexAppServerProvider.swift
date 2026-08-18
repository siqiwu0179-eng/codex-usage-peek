import Foundation
#if canImport(CodexUsageCore)
import CodexUsageCore
#endif

enum UsageProviderError: LocalizedError {
    case codexNotFound
    case serverEnded
    case timedOut
    case invalidHandshake

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "没有找到 Codex。请先安装并登录 ChatGPT/Codex Mac 应用。"
        case .serverEnded:
            return "Codex 数据服务意外结束。"
        case .timedOut:
            return "读取 Codex 用量超时，请稍后重试。"
        case .invalidHandshake:
            return "无法与当前版本的 Codex 建立数据连接。"
        }
    }
}

actor CodexAppServerProvider {
    private let timeoutNanoseconds: UInt64 = 12_000_000_000

    func fetch() async throws -> UsageSnapshot {
        guard let executableURL = Self.findCodexExecutable() else {
            throw UsageProviderError.codexNotFound
        }

        return try await withThrowingTaskGroup(of: UsageSnapshot.self) { group in
            group.addTask {
                try await Self.runSession(executableURL: executableURL)
            }
            group.addTask { [timeoutNanoseconds] in
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw UsageProviderError.timedOut
            }
            guard let first = try await group.next() else {
                throw UsageProviderError.serverEnded
            }
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func runSession(executableURL: URL) async throws -> UsageSnapshot {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        defer {
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        try sendInitialize(to: inputPipe.fileHandleForWriting)

        for try await line in outputPipe.fileHandleForReading.bytes.lines {
            try Task.checkCancellation()
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if (object["id"] as? Int) == 1 {
                guard object["result"] != nil else { throw UsageProviderError.invalidHandshake }
                try sendInitializedAndRead(to: inputPipe.fileHandleForWriting)
                continue
            }
            if (object["id"] as? Int) == 2 {
                return try CodexRateLimitParser.parseResponseLine(data)
            }
        }
        throw UsageProviderError.serverEnded
    }

    private nonisolated static func sendInitialize(to handle: FileHandle) throws {
        let request: [String: Any] = [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codex-usage-peek",
                    "title": "Codex Usage Peek",
                    "version": "0.1.0",
                ],
                "capabilities": ["experimentalApi": true],
            ],
        ]
        try write(request, to: handle)
    }

    private nonisolated static func sendInitializedAndRead(to handle: FileHandle) throws {
        try write(["method": "initialized"], to: handle)
        try write(["id": 2, "method": "account/rateLimits/read", "params": NSNull()], to: handle)
    }

    private nonisolated static func write(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private nonisolated static func findCodexExecutable() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
        ]
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
