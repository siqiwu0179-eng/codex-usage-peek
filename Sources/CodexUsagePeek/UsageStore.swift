import AppKit
import Combine
import Foundation
#if canImport(CodexUsageCore)
import CodexUsageCore
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let provider = CodexAppServerProvider()
    private var refreshTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var sessionObserver: NSObjectProtocol?
    private let refreshInterval: TimeInterval = 5 * 60

    init() {
        snapshot = UsageSnapshotStore.load()
    }

    var statusText: String {
        if isRefreshing { return "正在更新…" }
        if errorMessage != nil { return snapshot == nil ? "连接失败" : "显示上次数据" }
        guard let snapshot else { return "等待连接" }
        return snapshot.isStale() ? "数据可能已过期" : "已同步"
    }

    func start() {
        guard refreshTask == nil else { return }
        installActivityObservers()
        refreshTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    func refreshIfNeeded(maxAge: TimeInterval? = nil) async {
        let allowedAge = maxAge ?? refreshInterval
        if errorMessage != nil || snapshot == nil {
            await refresh()
            return
        }
        guard let fetchedAt = snapshot?.fetchedAt,
              Date().timeIntervalSince(fetchedAt) >= allowedAge
        else { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let updated = try await provider.fetch()
            try UsageSnapshotStore.save(updated)
            snapshot = updated
            errorMessage = nil
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installActivityObservers() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        sessionObserver = center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshIfNeeded()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        if let sessionObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sessionObserver)
        }
    }
}
