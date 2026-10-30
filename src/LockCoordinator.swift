import AppKit

/// 接缝上的小锁链：把两个窗口捆在一起拖动（内容各自独立）
final class ChainPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ChainButton: NSButton {
    var acceptsFirstMouseOverride = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        acceptsFirstMouseOverride
    }
}

final class LockCoordinator: NSObject {
    static let shared = LockCoordinator()

    private let defaultsKey = "windowsLocked"
    private let chainPanel: ChainPanel
    private let button = ChainButton()
    private weak var workWindow: NSWindow?
    private weak var personalWindow: NSWindow?

    private(set) var isLocked: Bool

    override init() {
        isLocked = UserDefaults.standard.bool(forKey: defaultsKey)
        chainPanel = ChainPanel(contentRect: NSRect(x: 0, y: 0, width: 34, height: 34),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false)
        super.init()
        configurePanel()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(layoutChanged),
                                               name: .todoFloatLayoutChanged,
                                               object: nil)
    }

    func attach(work: NSWindow, personal: NSWindow) {
        workWindow = work
        personalWindow = personal
        refresh()
    }

    private func configurePanel() {
        chainPanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 3)
        chainPanel.isOpaque = false
        chainPanel.backgroundColor = .clear
        chainPanel.hasShadow = false
        chainPanel.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenNone]
        chainPanel.isReleasedWhenClosed = false
        chainPanel.appearance = NSAppearance(named: .darkAqua)
        chainPanel.animationBehavior = .none

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        chainPanel.contentView = content

        button.acceptsFirstMouseOverride = true
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.target = self
        button.action = #selector(toggle)
        button.wantsLayer = true
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.5
        button.layer?.shadowRadius = 2
        button.layer?.shadowOffset = CGSize(width: 0, height: -1)
        button.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 34),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        button.image = NSImage(systemSymbolName: isLocked ? "lock.fill" : "lock.open",
                               accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        button.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        button.toolTip = isLocked
            ? "已锁定：拖一个窗口，两个一起动（点击解开）"
            : "锁定两个窗口，拖动时一起移动"
    }

    @objc private func toggle() {
        isLocked.toggle()
        UserDefaults.standard.set(isLocked, forKey: defaultsKey)
        updateAppearance()
    }

    @objc private func layoutChanged() {
        refresh()
    }

    /// 只有对齐并贴住（左右或上下）时才出现锁；错开或交叠一律收起
    func refresh() {
        guard let a = workWindow?.frame, let b = personalWindow?.frame else {
            hideChain()
            return
        }
        let tolerance: CGFloat = 2
        let topsAligned = abs(a.maxY - b.maxY) <= tolerance
        let leftsAligned = abs(a.minX - b.minX) <= tolerance

        if topsAligned,
           abs(a.maxX - b.minX) <= tolerance || abs(b.maxX - a.minX) <= tolerance,
           min(a.maxY, b.maxY) - max(a.minY, b.minY) > 44 {
            let seamX = abs(a.maxX - b.minX) <= tolerance ? a.maxX : b.maxX
            show(at: NSPoint(x: seamX, y: min(a.maxY, b.maxY) - 22))
            return
        }
        if leftsAligned,
           abs(a.maxY - b.minY) <= tolerance || abs(b.maxY - a.minY) <= tolerance,
           min(a.maxX, b.maxX) - max(a.minX, b.minX) > 44 {
            let seamY = abs(a.maxY - b.minY) <= tolerance ? a.maxY : b.maxY
            let left = max(a.minX, b.minX)
            let right = min(a.maxX, b.maxX)
            show(at: NSPoint(x: (left + right) / 2, y: seamY))
            return
        }
        hideChain()
    }

    /// 收起锁链；同时把锁定状态复位，避免“图标没了但还联动”
    private func hideChain() {
        chainPanel.orderOut(nil)
        if isLocked {
            isLocked = false
            UserDefaults.standard.set(false, forKey: defaultsKey)
            updateAppearance()
        }
    }

    private func show(at center: NSPoint) {
        let size = chainPanel.frame.size
        chainPanel.setFrameOrigin(NSPoint(x: center.x - size.width / 2,
                                          y: center.y - size.height / 2))
        chainPanel.orderFrontRegardless()
    }
}