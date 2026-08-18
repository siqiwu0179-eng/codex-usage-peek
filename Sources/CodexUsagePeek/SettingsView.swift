import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Card 位置") {
                Picker("屏幕边缘", selection: $settings.edge) {
                    ForEach(AppSettings.ScreenEdge.allCases) { edge in
                        Text(edge.label).tag(edge)
                    }
                }
                Picker("自动隐藏", selection: $settings.hideDelay) {
                    Text("立即").tag(0.0)
                    Text("0.5 秒").tag(0.5)
                    Text("1 秒").tag(1.0)
                    Text("2 秒").tag(2.0)
                }
                Toggle("在所有桌面和全屏应用中显示", isOn: $settings.showsOnAllSpaces)
            }

            Section("启动") {
                Toggle(
                    "登录 Mac 时自动运行",
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }

            Section("数据") {
                LabeledContent("来源", value: store.snapshot?.source ?? "本机 Codex")
                LabeledContent("状态", value: store.statusText)
                if let fetchedAt = store.snapshot?.fetchedAt {
                    LabeledContent("最后更新", value: fetchedAt.formatted(date: .abbreviated, time: .standard))
                }
                Button("立即更新") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
            }

            Section {
                Text("应用只请求本机 Codex 的额度快照，不读取任务、prompt、代码或账户凭据。当前 App Server 协议为实验性，Codex 更新后可能需要同步适配。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 430)
        .padding()
    }
}
