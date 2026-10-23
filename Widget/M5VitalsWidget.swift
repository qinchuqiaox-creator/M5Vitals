import WidgetKit
import SwiftUI

struct VitalsEntry: TimelineEntry {
    var date: Date
    var cpuTemp: Double
    var gpuTemp: Double
    var cpuPct: Double
    var gpuPct: Double
    var ramUsed: Double
    var ramTotal: Double
    var watts: Double
}

extension VitalsEntry {
    static let sample = VitalsEntry(date: Date(), cpuTemp: 27.5, gpuTemp: 27.4,
                                    cpuPct: 2, gpuPct: 0, ramUsed: 12.9, ramTotal: 256, watts: 0.9)

    static func load() -> VitalsEntry {
        guard let url = URL(string: "http://127.0.0.1:41414/json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VitalsEntry(date: Date(), cpuTemp: .nan, gpuTemp: .nan, cpuPct: 0, gpuPct: 0,
                               ramUsed: 0, ramTotal: 0, watts: 0)
        }
        let temp = root["temp"] as? [String: Any] ?? [:]
        let mem = root["memory"] as? [String: Any] ?? [:]
        let gpu = root["gpu_usage"] as? [Double] ?? []
        return VitalsEntry(
            date: Date(),
            cpuTemp: (temp["cpu_temp_avg"] as? Double) ?? .nan,
            gpuTemp: (temp["gpu_temp_avg"] as? Double) ?? .nan,
            cpuPct: ((root["cpu_usage_pct"] as? Double) ?? 0) * 100,
            gpuPct: (gpu.count > 1 ? gpu[1] : 0) * 100,
            ramUsed: ((mem["ram_usage"] as? Double) ?? 0) / 1_073_741_824,
            ramTotal: ((mem["ram_total"] as? Double) ?? 0) / 1_073_741_824,
            watts: (root["sys_power"] as? Double) ?? 0
        )
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VitalsEntry { .sample }
    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) { completion(.sample) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let entry = VitalsEntry.load()
        // WidgetKit 的时间线由系统调度，这里请求 5 分钟后再刷新（实际由系统决定）
        let next = Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private func tempColor(_ t: Double) -> Color {
    if t.isNaN { return .secondary }
    if t >= 90 { return Color(red: 1.00, green: 0.36, blue: 0.36) }
    if t >= 80 { return Color(red: 1.00, green: 0.62, blue: 0.27) }
    if t >= 68 { return Color(red: 1.00, green: 0.82, blue: 0.40) }
    return Color(red: 0.29, green: 0.87, blue: 0.50)
}

/// 一行：小标签 + 百分比 / 大温度 / 细进度条
struct VitalsRow: View {
    var label: String
    var pct: Double
    var temp: Double
    var tempSize: CGFloat
    var barHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(Int(pct.rounded()))%")
                    .font(.system(size: 8.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(temp.isNaN ? "--" : String(format: "%.1f", temp))
                    .font(.system(size: tempSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tempColor(temp))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("°")
                    .font(.system(size: tempSize * 0.42, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(tempColor(temp).opacity(0.85))
                        .frame(width: max(2, geo.size.width * min(100, max(0, pct)) / 100))
                }
            }
            .frame(height: barHeight)
        }
    }
}

struct VitalsWidgetView: View {
    var entry: VitalsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .containerBackground(.thinMaterial, for: .widget)
    }

    // 正方形：两行大温度 + 底部一行小字
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            VitalsRow(label: "CPU", pct: entry.cpuPct, temp: entry.cpuTemp, tempSize: 34, barHeight: 3)
            VitalsRow(label: "GPU", pct: entry.gpuPct, temp: entry.gpuTemp, tempSize: 34, barHeight: 3)
            footer
        }
    }

    // 长方形：左右两列，温度更大
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 16) {
                VitalsRow(label: "CPU", pct: entry.cpuPct, temp: entry.cpuTemp, tempSize: 40, barHeight: 3.5)
                VitalsRow(label: "GPU", pct: entry.gpuPct, temp: entry.gpuTemp, tempSize: 40, barHeight: 3.5)
            }
            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text(String(format: "RAM %.1f/%.0f GB", entry.ramUsed, entry.ramTotal))
            Spacer(minLength: 4)
            Text(String(format: "%.1f W", entry.watts))
        }
        .font(.system(size: 8.5))
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
}

struct M5VitalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "M5VitalsWidget", provider: Provider()) { entry in
            VitalsWidgetView(entry: entry)
        }
        .configurationDisplayName("M5Vitals")
        .description("CPU / GPU temperature, memory and package power.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct M5VitalsWidgetBundle: WidgetBundle {
    var body: some Widget {
        M5VitalsWidget()
    }
}
