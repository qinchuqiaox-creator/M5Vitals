// M5Vitals —— 银豆豆给主人做的桌面硬件体检卡
// 数据源: macmon serve (http://127.0.0.1:41414/json)，无需 sudo
// 层级: 桌面层 (-1)，位于壁纸之上、所有窗口之下
import SwiftUI
import AppKit

// MARK: - 数据模型

struct Metrics: Decodable {
    struct Temp: Decodable {
        let cpu_temp_avg: Double?
        let gpu_temp_avg: Double?
    }
    struct Mem: Decodable {
        let ram_usage: Double?
        let ram_total: Double?
    }
    struct Fan: Decodable {
        let rpm: Int?
        let max_rpm: Int?
    }
    let temp: Temp?
    let cpu_usage_pct: Double?
    let gpu_usage: [Double]?
    let sys_power: Double?
    let memory: Mem?
    let fans: [Fan]?
}

final class Store: ObservableObject {
    @Published var cpuTemp: Double = .nan
    @Published var gpuTemp: Double = .nan
    @Published var cpuPct: Double = 0
    @Published var gpuPct: Double = 0
    @Published var power: Double = 0
    @Published var ramUsed: Double = 0
    @Published var ramTotal: Double = 0
    @Published var fan: Int = 0
    @Published var fanMax: Int = 0
    @Published var online = false

    var onChange: (() -> Void)?
    private var timer: Timer?

    func start() {
        tick()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func tick() {
        guard let url = URL(string: "http://127.0.0.1:41414/json") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data, let m = try? JSONDecoder().decode(Metrics.self, from: data) else {
                DispatchQueue.main.async { self.online = false }
                return
            }
            DispatchQueue.main.async { self.apply(m) }
        }.resume()
    }

    private func apply(_ m: Metrics) {
        online = true
        if let v = m.temp?.cpu_temp_avg { cpuTemp = v }
        if let v = m.temp?.gpu_temp_avg { gpuTemp = v }
        if let v = m.cpu_usage_pct { cpuPct = max(0, min(100, v * 100)) }
        if let g = m.gpu_usage, g.count > 1 { gpuPct = max(0, min(100, g[1] * 100)) }
        if let v = m.sys_power { power = v }
        if let mem = m.memory {
            if let u = mem.ram_usage { ramUsed = u / 1_073_741_824 }
            if let t = mem.ram_total { ramTotal = t / 1_073_741_824 }
        }
        if let fans = m.fans, !fans.isEmpty {
            fan = fans.compactMap { $0.rpm }.max() ?? 0
            fanMax = fans.compactMap { $0.max_rpm }.max() ?? 0
        }
        onChange?()
    }
}

// MARK: - 外观

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

func tempColor(_ t: Double) -> Color {
    if t.isNaN { return Color(white: 0.6) }
    if t >= 90 { return Color(red: 1.00, green: 0.36, blue: 0.36) }
    if t >= 80 { return Color(red: 1.00, green: 0.62, blue: 0.27) }
    if t >= 68 { return Color(red: 1.00, green: 0.82, blue: 0.40) }
    return Color(red: 0.29, green: 0.87, blue: 0.50)
}

struct Bar: View {
    var pct: Double
    var color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: max(2, geo.size.width * min(100, max(0, pct)) / 100))
            }
        }
        .frame(height: 3)
    }
}

struct TempRow: View {
    var label: String
    var temp: Double
    var pct: Double
    var online: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.45))
                Text(String(format: "%d%%", Int(pct.rounded())))
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.26))
                Spacer(minLength: 10)
                Text(temp.isNaN ? "--" : String(format: "%.1f", temp))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tempColor(temp))
                Text("°")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Bar(pct: pct, color: tempColor(temp))
        }
        .opacity(online ? 1 : 0.3)
    }
}

struct CardView: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TempRow(label: "CPU", temp: store.cpuTemp, pct: store.cpuPct, online: store.online)
            TempRow(label: "GPU", temp: store.gpuTemp, pct: store.gpuPct, online: store.online)

            HStack(spacing: 0) {
                Text(String(format: "RAM %.1f/%.0f GB", store.ramUsed, store.ramTotal))
                Spacer(minLength: 8)
                Text(store.power < 10 ? String(format: "%.1f W", store.power)
                                      : String(format: "%.0f W", store.power))
            }
            .font(.system(size: 9.5))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.32))
            .opacity(store.online ? 1 : 0.3)
        }
        .padding(.init(top: 13, leading: 15, bottom: 13, trailing: 15))
        .frame(width: 200)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// 让内容视图自己接管拖拽：SwiftUI 会吞掉 mouseDown，交给 AppKit 的 performDrag 最稳
final class DragHostingView<Content: View>: NSHostingView<Content> {
    // 未激活状态下第一下点击也直接生效（否则第一下会被当成"激活点击"吃掉）
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
        (window as? WidgetPanel)?.persistFrame()
    }
}

// MARK: - App

final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func persistFrame() {
        saveFrame(usingName: "M5VitalsPanel")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store = Store()
    var panel: WidgetPanel!
    var statusItem: NSStatusItem!
    var hosting: NSHostingView<CardView>!
    private var dragMonitor: Any?
    private var floatItem: NSMenuItem?
    private var isFloating = UserDefaults.standard.bool(forKey: "FloatOnTop")

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()

        hosting = DragHostingView(rootView: CardView(store: store))
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 40 || size.height < 40 { size = NSSize(width: 200, height: 148) }
        panel = WidgetPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: -1)          // 桌面层：壁纸之上，窗口之下
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.setFrameAutosaveName("M5VitalsPanel")
        panel.isRestorable = false

        // 只有从未保存过位置、或收到 ResetPosition 指令时才摆到右上角
        let wantsReset = UserDefaults.standard.bool(forKey: "ResetPosition")
        if wantsReset { UserDefaults.standard.set(false, forKey: "ResetPosition") }
        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame M5VitalsPanel") != nil
        if wantsReset || !hasSavedFrame, let screen = NSScreen.main {
            let v = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: v.maxX - size.width - 8, y: v.maxY - 8))
            panel.saveFrame(usingName: "M5VitalsPanel")
        }
        panel.orderFrontRegardless()
        setupStatusItem()
        applyLevel()
        store.onChange = { [weak self] in self?.refreshTitle() }

        // 布局稳定后再精确贴合内容尺寸（首帧 fittingSize 可能偏小）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.hosting.layoutSubtreeIfNeeded()
            let fit = self.hosting.fittingSize
            if fit.width > 20, fit.height > 20, fit != self.panel.frame.size {
                let topLeft = NSPoint(x: self.panel.frame.minX, y: self.panel.frame.maxY)
                self.panel.setContentSize(fit)
                self.panel.setFrameTopLeftPoint(topLeft)
                self.panel.saveFrame(usingName: "M5VitalsPanel")
            }
        }
    }

    /// -1 = 贴在桌面（会被窗口盖住）；floating = 永远浮在最上层
    func applyLevel() {
        panel.level = isFloating ? .floating : NSWindow.Level(rawValue: -1)
        floatItem?.state = isFloating ? .on : .off
    }

    @objc func toggleFloat() {
        isFloating.toggle()
        UserDefaults.standard.set(isFloating, forKey: "FloatOnTop")
        applyLevel()
        panel.orderFrontRegardless()
    }

    func refreshTitle() {
        let c = store.cpuTemp.isNaN ? "--" : String(format: "%.0f", store.cpuTemp)
        let g = store.gpuTemp.isNaN ? "--" : String(format: "%.0f", store.gpuTemp)
        let s = NSString(string: "🌡 \(c)/\(g)")
        let attr = NSMutableAttributedString(string: s as String)
        let r = s.range(of: " ")
        if r.location != NSNotFound {
            attr.addAttribute(.font,
                              value: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                              range: NSRange(location: r.location + 1, length: s.length - r.location - 1))
        }
        statusItem.button?.attributedTitle = attr
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🌡"
        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Show / Hide", action: #selector(togglePanel), keyEquivalent: "h")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let posItem = NSMenuItem(title: "Move To", action: nil, keyEquivalent: "")
        let posMenu = NSMenu()
        for (title, tag) in [("Top Right", 0), ("Top Left", 1), ("Bottom Right", 2), ("Bottom Left", 3), ("Center", 4)] {
            let it = NSMenuItem(title: title, action: #selector(moveTo(_:)), keyEquivalent: "")
            it.tag = tag
            it.target = self
            posMenu.addItem(it)
        }
        posItem.submenu = posMenu
        menu.addItem(posItem)

        let floatToggle = NSMenuItem(title: "Float on Top", action: #selector(toggleFloat), keyEquivalent: "f")
        floatToggle.target = self
        floatItem = floatToggle
        menu.addItem(floatToggle)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc func moveTo(_ sender: NSMenuItem) {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let s = panel.frame.size
        let m: CGFloat = 8
        var origin = NSPoint(x: v.maxX - s.width - m, y: v.maxY - s.height - m)
        switch sender.tag {
        case 1: origin = NSPoint(x: v.minX + m, y: v.maxY - s.height - m)
        case 2: origin = NSPoint(x: v.maxX - s.width - m, y: v.minY + m)
        case 3: origin = NSPoint(x: v.minX + m, y: v.minY + m)
        case 4: origin = NSPoint(x: v.midX - s.width / 2, y: v.midY - s.height / 2)
        default: break
        }
        panel.setFrameOrigin(origin)
        panel.saveFrame(usingName: "M5VitalsPanel")
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
