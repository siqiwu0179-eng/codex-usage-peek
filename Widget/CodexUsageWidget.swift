import SwiftUI
import WidgetKit
#if canImport(CodexUsageCore)
import CodexUsageCore
#endif

struct UsageTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageTimelineEntry {
        UsageTimelineEntry(
            date: Date(),
            snapshot: UsageSnapshotStore.load() ?? UsageSnapshot(
                remainingPercent: 76,
                usedPercent: 24,
                resetAt: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                windowDurationMinutes: 10_080,
                fetchedAt: Date(),
                source: "预览",
                planType: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageTimelineEntry) -> Void) {
        completion(UsageTimelineEntry(date: Date(), snapshot: UsageSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageTimelineEntry>) -> Void) {
        let now = Date()
        let entry = UsageTimelineEntry(date: now, snapshot: UsageSnapshotStore.load())
        // WidgetKit still controls the exact execution time, but a short
        // fallback prevents an ignored reload request from leaving an old
        // value on the desktop for half an hour.
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CodexUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageTimelineEntry

    @ViewBuilder
    var body: some View {
        let widgetContent = Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                unavailableContent
            }
        }

        if #available(macOS 14.0, *) {
            widgetContent.containerBackground(for: .widget) {
                widgetBackground
            }
        } else {
            widgetContent.background(widgetBackground)
        }
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color.green.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func content(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 9 : 12) {
            HStack(spacing: 7) {
                ChatGPTBrandLogoView()
                    .frame(width: 22, height: 22)
                Text("Codex 周用量")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }

            Text("\(snapshot.remainingPercent)%")
                .font(.system(size: family == .systemSmall ? 34 : 40, weight: .bold, design: .rounded))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(LinearGradient(colors: [.mint, .green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * CGFloat(snapshot.remainingPercent) / 100)
                }
            }
            .frame(height: 7)

            HStack {
                Text(snapshot.isStale() ? "数据可能已过期" : "本周剩余")
                Spacer()
                if let resetAt = snapshot.resetAt {
                    Text("\(resetAt.formatted(.dateTime.month().day())) 重置")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChatGPTBrandLogoView()
                .frame(width: 28, height: 28)
            Text("Codex 周用量")
                .font(.headline)
            Text("打开主应用以读取额度")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct CodexUsageWidget: Widget {
    let kind = CodexUsageWidgetIdentity.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            CodexUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex 周用量")
        .description("显示 Codex 当前一周剩余额度和重置日期。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CodexUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexUsageWidget()
    }
}
