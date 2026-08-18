import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    enum ScreenEdge: String, CaseIterable, Identifiable {
        case left
        case right
        case top

        var id: String { rawValue }
        var label: String {
            switch self {
            case .left: "左侧"
            case .right: "右侧"
            case .top: "顶部"
            }
        }
    }

    private enum Key {
        static let edge = "edge"
        static let hideDelay = "hideDelay"
        static let allSpaces = "allSpaces"
        static let darkMode = "darkMode"
    }

    @Published var edge: ScreenEdge {
        didSet { defaults.set(edge.rawValue, forKey: Key.edge) }
    }
    @Published var hideDelay: Double {
        didSet { defaults.set(hideDelay, forKey: Key.hideDelay) }
    }
    @Published var showsOnAllSpaces: Bool {
        didSet { defaults.set(showsOnAllSpaces, forKey: Key.allSpaces) }
    }
    @Published var isDarkMode: Bool {
        didSet { defaults.set(isDarkMode, forKey: Key.darkMode) }
    }
    @Published private(set) var launchAtLoginEnabled = false
    @Published var launchAtLoginError: String?

    private let defaults = UserDefaults.standard

    init() {
        if defaults.object(forKey: Key.edge) == nil,
           let legacyDefaults = UserDefaults(suiteName: "com.siqi.codexusagepeek") {
            for key in [Key.edge, Key.hideDelay, Key.allSpaces, Key.darkMode] {
                if let value = legacyDefaults.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }

        edge = ScreenEdge(rawValue: defaults.string(forKey: Key.edge) ?? "right") ?? .right
        let savedDelay = defaults.object(forKey: Key.hideDelay) as? Double
        hideDelay = savedDelay ?? 0.5
        showsOnAllSpaces = defaults.object(forKey: Key.allSpaces) as? Bool ?? true
        isDarkMode = defaults.object(forKey: Key.darkMode) as? Bool ?? false
        refreshLoginItemState()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLoginItemState()
    }

    private func refreshLoginItemState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
