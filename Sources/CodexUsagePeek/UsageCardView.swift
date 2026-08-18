import AppKit
import SwiftUI
#if canImport(CodexUsageCore)
import CodexUsageCore
#endif

struct UsageCardView: View {
    @ObservedObject var store: UsageStore
    let edge: AppSettings.ScreenEdge
    let isPinned: Bool
    let isDarkMode: Bool
    let onHoverChanged: (Bool) -> Void
    let onPinToggle: () -> Void
    let onThemeToggle: () -> Void
    let onDragChanged: () -> Void
    let onDragEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            usageRow
            progress
            footer
        }
        .padding(15)
        .frame(width: 292, height: 154, alignment: .leading)
        .background(cardBackground)
        .overlay { edgeHandle }
        .contentShape(Rectangle())
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onHover(perform: onHoverChanged)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in onDragChanged() }
                .onEnded { _ in onDragEnded() }
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ChatGPTBrandLogoView()
                .frame(width: 22, height: 22)

            Text("Codex 周用量")
                .font(.system(size: 12, weight: .semibold))

            Spacer(minLength: 6)

            Button(action: onThemeToggle) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max")
                    .frame(width: 21, height: 21)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(isDarkMode ? "切换浅色模式" : "切换深色模式")

            Button(action: onPinToggle) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .frame(width: 21, height: 21)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isPinned ? Color.green : Color.secondary)
            .help(isPinned ? "取消固定" : "固定在桌面")
        }
    }

    private var usageRow: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(store.snapshot.map { "\($0.remainingPercent)%" } ?? "—")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())

            Spacer()

            if let resetAt = store.snapshot?.resetAt {
                Text("\(resetAt.formatted(.dateTime.month().day())) 重置")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progress: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(progressGradient)
                    .frame(width: proxy.size.width * CGFloat(store.snapshot?.remainingPercent ?? 0) / 100)
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.snapshot?.remainingPercent)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(store.errorMessage == nil ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(store.errorMessage == nil ? "本周剩余" : "显示上次数据")
            Spacer()
            if let fetchedAt = store.snapshot?.fetchedAt {
                Text(fetchedAt.formatted(.relative(presentation: .named)))
            } else {
                Text(store.isRefreshing ? "正在更新…" : "等待连接")
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .help("立即更新")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 21, style: .continuous)
            .fill(
                isDarkMode
                    ? Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 0.98))
                    : Color(nsColor: NSColor(calibratedWhite: 0.98, alpha: 0.99))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(isDarkMode ? 0.04 : 0.28), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(Color.white.opacity(isDarkMode ? 0.16 : 0.92), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var edgeHandle: some View {
        switch edge {
        case .left:
            HStack {
                Capsule().fill(Color.primary.opacity(0.13)).frame(width: 3, height: 44)
                Spacer()
            }
            .padding(.leading, 2)
        case .right:
            HStack {
                Spacer()
                Capsule().fill(Color.primary.opacity(0.13)).frame(width: 3, height: 44)
            }
            .padding(.trailing, 2)
        case .top:
            VStack {
                Capsule().fill(Color.primary.opacity(0.13)).frame(width: 44, height: 3)
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private var progressGradient: LinearGradient {
        let percent = store.snapshot?.remainingPercent ?? 0
        let colors: [Color]
        switch percent {
        case 51...100: colors = [.mint, .green]
        case 21...50: colors = [.yellow, .orange]
        default: colors = [.orange, .red]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}
