import AppKit
import SwiftUI

@MainActor
final class AppServices {
    static let shared = AppServices()
    let store = UsageStore()
    let settings = AppSettings()
    private var panelController: EdgePanelController?

    func start() {
        guard panelController == nil else { return }
        let controller = EdgePanelController(store: store, settings: settings)
        panelController = controller
        controller.start()
        store.start()
    }

    func revealCard() {
        panelController?.reveal()
    }

}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppServices.shared.start()
    }
}

@main
struct CodexUsagePeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let services = AppServices.shared

    var body: some Scene {
        MenuBarExtra("Codex 周用量", systemImage: "gauge.medium") {
            MenuContent(store: services.store)
        }
        Settings {
            SettingsView(store: services.store, settings: services.settings)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        if let snapshot = store.snapshot {
            Text("本周剩余 \(snapshot.remainingPercent)%")
            if let resetAt = snapshot.resetAt {
                Text("\(resetAt.formatted(.dateTime.month().day().hour().minute())) 重置")
            }
        } else {
            Text("尚未读取用量")
        }
        Divider()
        Button("显示 Card") { AppServices.shared.revealCard() }
        Button("立即更新") { Task { await store.refresh() } }
            .disabled(store.isRefreshing)
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("设置…")
            }
        } else {
            Button("设置…") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.sendAction(
                    Selector(("showPreferencesWindow:")),
                    to: nil,
                    from: nil
                )
            }
        }
        Divider()
        Button("退出") { NSApplication.shared.terminate(nil) }
    }
}
