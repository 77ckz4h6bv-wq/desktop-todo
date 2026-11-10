import AppKit
import QuartzCore

extension Notification.Name {
    static let todoFloatThemeChanged = Notification.Name("todoFloat.themeChanged")
    static let todoFloatLayoutChanged = Notification.Name("todoFloat.layoutChanged")
}

final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class PassthroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

enum Theme: String {
    case clear
    case dark

}

/// 两套外观：透明玻璃（无底板，只有边缘毛玻璃）/ 黑玻璃（深底浅字）
struct Palette {
    let appearanceName: NSAppearance.Name
    let cardFill: NSColor
    let cardBorder: NSColor
    let title: NSColor
    let count: NSColor
    let hint: NSColor
    let menuTint: NSColor
    let divider: NSColor
    let separator: NSColor
    let addBoxFill: NSColor
    let addText: NSColor
    let placeholder: NSColor
    let emptyText: NSColor
    let addBoxBorder: NSColor
    let rowText: NSColor
    let rowDoneText: NSColor
    let checkTint: NSColor
    let deleteTint: NSColor
    let editFill: NSColor
    let editText: NSColor
    let hoverFill: NSColor
    let doingFill: NSColor
    let gripStroke: NSColor
    let textShadow: NSShadow?
    let gripHoverOnly: Bool
    let cardBorderWidth: CGFloat
    let frostsEdge: Bool

    static func make(_ theme: Theme) -> Palette {
        switch theme {
        case .clear:
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
            shadow.shadowBlurRadius = 2.5
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            return Palette(
                appearanceName: .darkAqua,
                cardFill: .clear,
                cardBorder: NSColor.white.withAlphaComponent(0.38),
                title: NSColor.white.withAlphaComponent(0.8),
                count: NSColor.white.withAlphaComponent(0.6),
                hint: NSColor.white.withAlphaComponent(0.5),
                menuTint: NSColor.white.withAlphaComponent(0.8),
                divider: .clear,
                separator: NSColor.white.withAlphaComponent(0.12),
                addBoxFill: .clear,
                addText: NSColor.white,
                placeholder: NSColor.white.withAlphaComponent(0.68),
                emptyText: NSColor.white.withAlphaComponent(0.6),
                addBoxBorder: NSColor.white.withAlphaComponent(0.34),
                rowText: NSColor.white.withAlphaComponent(0.98),
                rowDoneText: NSColor.white.withAlphaComponent(0.45),
                checkTint: NSColor.white.withAlphaComponent(0.72),
                deleteTint: NSColor.white.withAlphaComponent(0.8),
                editFill: NSColor(white: 0.12, alpha: 0.9),
                editText: NSColor.white,
                hoverFill: .clear,
                doingFill: NSColor.white.withAlphaComponent(0.09),
                gripStroke: NSColor.white.withAlphaComponent(0.4),
                textShadow: shadow,
                gripHoverOnly: true,
                cardBorderWidth: 0,
                frostsEdge: true
            )
        case .dark:
            return Palette(
                appearanceName: .darkAqua,
                cardFill: NSColor.black.withAlphaComponent(0.20),
                cardBorder: NSColor.white.withAlphaComponent(0.26),
                title: NSColor.white.withAlphaComponent(0.85),
                count: NSColor.white.withAlphaComponent(0.62),
                hint: NSColor.white.withAlphaComponent(0.55),
                menuTint: NSColor.white.withAlphaComponent(0.7),
                divider: NSColor.white.withAlphaComponent(0.16),
                separator: NSColor.white.withAlphaComponent(0.10),
                addBoxFill: .clear,
                addText: NSColor.white,
                placeholder: NSColor.white.withAlphaComponent(0.55),
                emptyText: NSColor.white.withAlphaComponent(0.62),
                addBoxBorder: NSColor.white.withAlphaComponent(0.3),
                rowText: NSColor.white.withAlphaComponent(0.97),
                rowDoneText: NSColor.white.withAlphaComponent(0.52),
                checkTint: NSColor.white.withAlphaComponent(0.6),
                deleteTint: NSColor.white.withAlphaComponent(0.7),
                editFill: NSColor(calibratedWhite: 0.14, alpha: 0.95),
                editText: NSColor.white,
                hoverFill: NSColor.white.withAlphaComponent(0.08),
                doingFill: NSColor.white.withAlphaComponent(0.12),
                gripStroke: NSColor.white.withAlphaComponent(0.2),
                textShadow: nil,
                gripHoverOnly: false,
                cardBorderWidth: 1.5,
                frostsEdge: false
            )
        }
    }
}

final class ResizeGrip: NSView {
    var strokeColor: NSColor = NSColor.black.withAlphaComponent(0.18) {
        didSet { needsDisplay = true }
    }
    var hoverOnly: Bool = false {
        didSet { needsDisplay = true }
    }
    private var hovering = false
    private var tracking: NSTrackingArea?
    private var startFrame: NSRect = .zero
    private var startMouse: NSPoint = .zero

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if hoverOnly && !hovering { return }
        strokeColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        for i in 0..<3 {
            let offset = CGFloat(i) * 3.0 + 2.0
            path.move(to: NSPoint(x: bounds.maxX - offset, y: bounds.minY + 0.5))
            path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY + offset))
        }
        path.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let p = NSEvent.mouseLocation
        let w = max(WidgetController.minSize.width,
                    min(WidgetController.maxSize.width, startFrame.width + (p.x - startMouse.x)))
        let h = max(WidgetController.minSize.height,
                    min(WidgetController.maxSize.height, startFrame.height - (p.y - startMouse.y)))
        let frame = NSRect(x: startFrame.origin.x, y: startFrame.maxY - h, width: w, height: h)
        window.setFrame(frame, display: true)
    }
}

enum RoundedPath {
    static let allCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                           .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    /// 允许每个角单独决定圆角还是直角
    static func make(rect: CGRect, radius: CGFloat, corners: CACornerMask) -> CGPath {
        let p = CGMutablePath()
        let r = max(0, min(radius, min(rect.width, rect.height) / 2))
        let bl = corners.contains(.layerMinXMinYCorner)
        let br = corners.contains(.layerMaxXMinYCorner)
        let tl = corners.contains(.layerMinXMaxYCorner)
        let tr = corners.contains(.layerMaxXMaxYCorner)

        p.move(to: CGPoint(x: rect.minX + (bl ? r : 0), y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - (br ? r : 0), y: rect.minY))
        if br {
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - (tr ? r : 0)))
        if tr {
            p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        }
        p.addLine(to: CGPoint(x: rect.minX + (tl ? r : 0), y: rect.maxY))
        if tl {
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + (bl ? r : 0)))
        if bl {
            p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        }
        p.closeSubpath()
        return p
    }
}

/// 用 CG 阴影生成一圈平滑的内发光（没有同心圆环纹）
enum RimGlow {
    static func draw(path: CGPath, band: CGFloat, color: NSColor, context: CGContext) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setShadow(offset: .zero, blur: band * 0.85, color: color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}

/// 边缘磨砂：只让贴着边框的一圈做 behind-window 模糊，向内渐隐，中间完全透明
final class EdgeFrostView: NSVisualEffectView {
    var rimRadius: CGFloat = 16
    var rimBand: CGFloat = 34
    var cornerMask: CACornerMask = RoundedPath.allCorners {
        didSet { maskImage = nil; needsLayout = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .underWindowBackground
        blendingMode = .behindWindow
        state = .active
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        maskImage = EdgeFrostView.rimMask(size: bounds.size, radius: rimRadius, band: rimBand, corners: cornerMask)
    }

    private static func rimMask(size: CGSize, radius: CGFloat, band: CGFloat, corners: CACornerMask) -> NSImage {
        guard size.width > 1, size.height > 1 else { return NSImage() }
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return NSImage() }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        if let context = NSGraphicsContext.current?.cgContext {
            let path = RoundedPath.make(rect: NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5),
                                        radius: radius,
                                        corners: corners)
            RimGlow.draw(path: path, band: band, color: NSColor.black.withAlphaComponent(0.95), context: context)
        }
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}

/// 一层很淡的白色雾，给磨砂边缘兜底：系统毛玻璃不生效时，边缘也还有柔和的痕迹
final class EdgeHazeView: NSView {
    var rimRadius: CGFloat = 16
    var rimBand: CGFloat = 27
    var strength: CGFloat = 0.14
    var cornerMask: CACornerMask = RoundedPath.allCorners {
        didSet { needsDisplay = true }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let path = RoundedPath.make(rect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                    radius: rimRadius,
                                    corners: cornerMask)
        RimGlow.draw(path: path, band: rimBand, color: NSColor.white.withAlphaComponent(strength), context: context)
    }
}

/// 拖动吸附：靠近屏幕边缘、另一个窗口或它的边缘时对齐
enum SnapEngine {
    static func snap(origin: NSPoint,
                     size: NSSize,
                     screen: NSRect,
                     other: NSRect?,
                     threshold: CGFloat = 12,
                     gap: CGFloat = 0) -> NSPoint {
        var x = origin.x
        var y = origin.y

        var xs: [CGFloat] = [screen.minX, screen.maxX - size.width]
        var ys: [CGFloat] = [screen.minY, screen.maxY - size.height]
        if let other = other {
            xs += [other.minX, other.maxX - size.width, other.maxX + gap, other.minX - gap - size.width]
            ys += [other.minY, other.maxY - size.height, other.maxY + gap, other.minY - gap - size.height]
        }

        if let nearestX = xs.min(by: { abs($0 - origin.x) < abs($1 - origin.x) }),
           abs(nearestX - origin.x) <= threshold {
            x = nearestX
        }
        if let nearestY = ys.min(by: { abs($0 - origin.y) < abs($1 - origin.y) }),
           abs(nearestY - origin.y) <= threshold {
            y = nearestY
        }
        return NSPoint(x: x, y: y)
    }
}

enum PanelMode {
    case todos
    case archive
}

protocol HoverHighlighting: AnyObject {
    func setHovered(_ hovered: Bool)
}

final class WidgetController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let panel: DesktopPanel
    private let store: TodoStore
    private let listTitle: String
    private let frameName: String
    private let rightInset: CGFloat

    private let content = NSView()
    private let titleLabel = NSTextField(labelWithString: "待办清单")
    private let countLabel = NSTextField(labelWithString: "")
    private let hintLabel = PassthroughLabel(labelWithString: "双击文字可以改内容")
    private let toggleButton = NSButton()
    private let appearanceButton = NSButton()
    private let divider = NSView()
    private let scrollView = NSScrollView()
    private let frost = EdgeFrostView(frame: .zero)
    private let haze = EdgeHazeView(frame: .zero)
    private let grip = ResizeGrip()
    private let docView = FlippedView()
    private let stack = NSStackView()
    private let emptyLabel = PassthroughLabel(labelWithString: "桌面上还没有待办\n在下面输入，按回车添加")
    private let doingCaption = NSTextField(labelWithString: "在办")
    private let doingSeparator = NSView()
    private let doingStack = NSStackView()
    private var doingRows: [DoingBarRow] = []
    private var scrollTopToDivider: NSLayoutConstraint!
    private var scrollTopToDoing: NSLayoutConstraint!
    var onRequestDoing: ((UUID, Bool) -> Bool)?
    var onDoingDataChanged: (() -> Void)?
    private let addBox = NSView()
    private let addField = NSTextField()
    private let placeholderLabel = PassthroughLabel(labelWithString: "添加待办…")
    private var rows: [NSView] = []
    private var scrollBottomToAddBox: NSLayoutConstraint!
    private var scrollBottomToContent: NSLayoutConstraint!
    private var mode: PanelMode = .todos
    private var isAddFieldFocused = false
    private var mouseMonitor: Any?
    private var dragStartFrame: NSRect?
    private var lastDragOrigin: NSPoint = .zero
    private var lockedDragActive = false
    private var lockedDragStartMouse: NSPoint = .zero
    private var lockedDragStartFrame: NSRect = .zero
    private var lockedCompanionStartFrame: NSRect = .zero
    private weak var lockedCompanion: NSWindow?
    private var dragMonitor: Any?
    private var snapTimer: Timer?
    private var snapStartedAt: CFTimeInterval = 0
    private var snapStartFrame: NSRect = .zero
    private var snapTargetFrame: NSRect = .zero
    private var seamCorners: CACornerMask?
    private weak var hoveredRow: HoverHighlighting?
    private var scrollObserver: NSObjectProtocol?
    private var noticeText: String?
    private var noticeToken = 0
    private var mouseUpMonitor: Any?
    var companionPanel: (() -> NSWindow?)?
    private var theme: Theme
    private var palette: Palette

    static let themeDefaultsKey = "cardAppearance"
    static let defaultSize = NSSize(width: 320, height: 420)
    static let minSize = NSSize(width: 260, height: 240)
    static let maxSize = NSSize(width: 640, height: 1000)

    /// 桌面图标层之上：清单可点击，图标不会被清单挡住
    private var desktopLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    init(listTitle: String = "工作待办",
         fileBase: String = "work",
         frameName: String = "TodoFloatPanel",
         rightInset: CGFloat = 28) {
        self.listTitle = listTitle
        self.frameName = frameName
        self.rightInset = rightInset
        store = TodoStore(fileBase: fileBase)
        let savedTheme = Theme(rawValue: UserDefaults.standard.string(forKey: WidgetController.themeDefaultsKey) ?? "")
        theme = savedTheme ?? .clear
        palette = Palette.make(theme)
        panel = DesktopPanel(contentRect: NSRect(origin: .zero, size: WidgetController.defaultSize),
                             styleMask: [.borderless, .nonactivatingPanel, .resizable],
                             backing: .buffered,
                             defer: false)
        super.init()
        configureWindow()
        panel.delegate = self
        buildUI()
        applyPalette()
        reload()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChangeExternally),
                                               name: .todoFloatThemeChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(layoutChangedExternally),
                                               name: .todoFloatLayoutChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowResignedKey),
                                               name: NSWindow.didResignKeyNotification,
                                               object: panel)
        // 点窗口其它地方（不是输入框）时结束编辑
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self, event.window === self.panel else { return event }
            // 点在正在编辑的输入框内部：让它自己定位光标，不结束编辑
            if let editor = self.panel.firstResponder as? NSTextView,
               editor !== self.addField.currentEditor() {
                let local = editor.convert(event.locationInWindow, from: nil)
                if editor.bounds.contains(local) { return event }
            }
            self.dragStartFrame = self.panel.frame
            self.lastDragOrigin = self.panel.frame.origin
            let point = self.content.convert(event.locationInWindow, from: nil)
            let inBox = self.addBox.isHidden ? false
                : self.addBox.bounds.contains(self.addBox.convert(point, from: self.content))
            self.handleClick(inAddBox: inBox)

            let hit = self.content.hitTest(point)
            let isInteractive = hit is NSButton
                || hit is NSTextView
                || hit is NSTextField
                || hit is TodoRowView
                || hit is ArchiveRowView
                || hit is ResizeGrip
            if LockCoordinator.shared.isLocked,
               !self.lockedDragActive,
               !inBox,
               !isInteractive,
               let other = self.companionPanel?() {
                self.lockedDragActive = true
                self.lockedDragStartMouse = NSEvent.mouseLocation
                self.lockedDragStartFrame = self.panel.frame
                self.lockedCompanionStartFrame = other.frame
                self.lockedCompanion = other
                self.panel.isMovableByWindowBackground = false
            }
            return event
        }

        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self, self.lockedDragActive else { return event }
            if NSEvent.pressedMouseButtons == 0 {
                self.finishLockedDrag()
                return event
            }
            self.updateLockedDrag()
            return event
        }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return event }
            if self.lockedDragActive || event.window === self.panel {
                self.handleMouseUp(event)
            }
            return event
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = dragMonitor { NSEvent.removeMonitor(monitor) }
        if let observer = scrollObserver { NotificationCenter.default.removeObserver(observer) }
        snapTimer?.invalidate()
    }

    /// 松手时把 1px 级别的错位吸成完全对齐，避免接缝出现台阶
    private func alignToCompanionIfClose() {
        guard let other = companionPanel?()?.frame else { return }
        var frame = panel.frame
        let tolerance: CGFloat = 2
        let sideBySide = abs(frame.maxX - other.minX) <= tolerance || abs(frame.minX - other.maxX) <= tolerance
        let stacked = abs(frame.maxY - other.minY) <= tolerance || abs(frame.minY - other.maxY) <= tolerance
        if sideBySide, abs(frame.maxY - other.maxY) <= tolerance {
            frame.origin.y = other.maxY - frame.height
        }
        if stacked, abs(frame.minX - other.minX) <= tolerance {
            frame.origin.x = other.minX
        }
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        updateSeamStyling()
        NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
    }

    private func finishLockedDrag() {
        guard lockedDragActive else { return }
        lockedDragActive = false
        lockedCompanion = nil
        panel.isMovableByWindowBackground = true
        dragStartFrame = nil
        alignToCompanionIfClose()
        updateSeamStyling()
        NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
    }

    private func updateLockedDrag() {
        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - lockedDragStartMouse.x,
                            y: current.y - lockedDragStartMouse.y)
        panel.setFrameOrigin(NSPoint(x: lockedDragStartFrame.minX + delta.x,
                                     y: lockedDragStartFrame.minY + delta.y))
        if let other = lockedCompanion {
            other.setFrameOrigin(NSPoint(x: lockedCompanionStartFrame.minX + delta.x,
                                         y: lockedCompanionStartFrame.minY + delta.y))
        }
        // 两个窗口都移动完，再刷新接缝和锁链
        updateSeamStyling()
        NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
    }

    @objc private func handleMouseUp(_ event: NSEvent) {
        if lockedDragActive {
            finishLockedDrag()
            return
        }
        defer { dragStartFrame = nil }
        guard let start = dragStartFrame else { return }
        let now = panel.frame
        guard abs(start.width - now.width) < 0.5, abs(start.height - now.height) < 0.5 else { return }
        guard abs(start.origin.x - now.origin.x) > 0.5 || abs(start.origin.y - now.origin.y) > 0.5 else { return }
        alignToCompanionIfClose()
        guard !LockCoordinator.shared.isLocked else { return }
        animateSnap()
    }

    @objc private func layoutChangedExternally() {
        updateSeamStyling()
    }

    @objc private func windowResignedKey() {
        handleClick(inAddBox: false)
    }

    private func handleClick(inAddBox: Bool) {
        if inAddBox {
            isAddFieldFocused = true
        } else {
            isAddFieldFocused = false
            panel.makeFirstResponder(nil)
        }
        updatePlaceholderVisibility()
    }

    /// 和另一个窗口贴住的那条边抹平圆角，接缝才不会出现两个圆角缺口
    func updateSeamStyling() {
        var corners: CACornerMask = RoundedPath.allCorners
        if let other = companionPanel?()?.frame {
            let f = panel.frame
            let tolerance: CGFloat = 1.5
            let topsAligned = abs(f.maxY - other.maxY) <= tolerance
            let bottomsAligned = abs(f.minY - other.minY) <= tolerance
            let leftsAligned = abs(f.minX - other.minX) <= tolerance
            let rightsAligned = abs(f.maxX - other.maxX) <= tolerance
            // 只抹掉“确实被另一边盖住”的角，高度/宽度不一致时不会抹错
            if abs(f.maxX - other.minX) <= tolerance {       // 我贴它左侧
                if topsAligned { corners.remove(.layerMaxXMaxYCorner) }
                if bottomsAligned { corners.remove(.layerMaxXMinYCorner) }
            }
            if abs(f.minX - other.maxX) <= tolerance {       // 我贴它右侧
                if topsAligned { corners.remove(.layerMinXMaxYCorner) }
                if bottomsAligned { corners.remove(.layerMinXMinYCorner) }
            }
            if abs(f.maxY - other.minY) <= tolerance {       // 我贴它下方
                if leftsAligned { corners.remove(.layerMinXMaxYCorner) }
                if rightsAligned { corners.remove(.layerMaxXMaxYCorner) }
            }
            if abs(f.minY - other.maxY) <= tolerance {       // 我贴它上方
                if leftsAligned { corners.remove(.layerMinXMinYCorner) }
                if rightsAligned { corners.remove(.layerMaxXMinYCorner) }
            }
        }
        guard corners != seamCorners else { return }
        seamCorners = corners
        content.layer?.maskedCorners = corners
        frost.cornerMask = corners
        haze.cornerMask = corners
    }

    func windowDidResize(_ notification: Notification) {
        updateSeamStyling()
        NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
    }

    func windowDidMove(_ notification: Notification) {
        lastDragOrigin = panel.frame.origin
        updateSeamStyling()
        // 锁定拖拽时，两个窗口是分两步移动的；中途刷新会被误判为“没对齐”
        if !lockedDragActive {
            NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
        }
    }

    /// 松手后按 60Hz 插值滑到吸附位（ease-out），拖动过程中不跳
    private func animateSnap() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let current = panel.frame
        let snapped = SnapEngine.snap(origin: current.origin,
                                      size: current.size,
                                      screen: screen.visibleFrame,
                                      other: companionPanel?()?.frame)
        guard abs(snapped.x - current.origin.x) > 0.5 || abs(snapped.y - current.origin.y) > 0.5 else { return }

        var target = current
        target.origin = snapped

        snapStartFrame = current
        snapTargetFrame = target
        snapStartedAt = CACurrentMediaTime()
        snapTimer?.invalidate()

        let duration: CFTimeInterval = 0.22
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let progress = min(1.0, (CACurrentMediaTime() - self.snapStartedAt) / duration)
            let eased = 1 - pow(1 - progress, 3)
            var frame = self.snapStartFrame
            frame.origin.x = self.snapStartFrame.origin.x
                + (self.snapTargetFrame.origin.x - self.snapStartFrame.origin.x) * eased
            frame.origin.y = self.snapStartFrame.origin.y
                + (self.snapTargetFrame.origin.y - self.snapStartFrame.origin.y) * eased
            self.panel.setFrame(frame, display: false)
            if progress >= 1 {
                timer.invalidate()
                self.snapTimer = nil
                self.panel.setFrame(self.snapTargetFrame, display: true)
                self.updateSeamStyling()
                NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
            }
        }
        snapTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Window

    private func configureWindow() {
        panel.level = desktopLevel
        // 不参与 Mission Control / ⌘Tab / 随空间切换移动，像壁纸一样钉在桌面上
        panel.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenNone]
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.appearance = NSAppearance(named: .aqua)
        panel.minSize = WidgetController.minSize
        panel.maxSize = WidgetController.maxSize
        panel.animationBehavior = .none
        panel.title = listTitle

        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame \(frameName)") != nil
        panel.setFrameAutosaveName(frameName)
        if !hasSavedFrame {
            positionDefault()
        }
        // 之前默认 360x480 的窗口，自动缩到新的默认尺寸，保持顶部位置
        if abs(panel.frame.width - 360) < 1, abs(panel.frame.height - 480) < 1 {
            let top = panel.frame.maxY
            panel.setContentSize(NSSize(width: 320, height: 420))
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
        }
    }

    private func positionDefault() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let x = max(visible.minX + 12, visible.maxX - size.width - rightInset)
        panel.setFrameOrigin(NSPoint(x: x, y: visible.maxY - size.height - 28))
    }

    // MARK: - UI

    private func buildUI() {
        content.wantsLayer = true
        content.layer?.cornerRadius = 16
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1.5
        panel.contentView = content
        panel.initialFirstResponder = content

        frost.translatesAutoresizingMaskIntoConstraints = false
        frost.isHidden = true
        content.addSubview(frost)

        haze.translatesAutoresizingMaskIntoConstraints = false
        haze.isHidden = true
        content.addSubview(haze)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(countLabel)

        hintLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hintLabel)

        appearanceButton.isBordered = false
        appearanceButton.imagePosition = .imageOnly
        appearanceButton.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "外观")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        appearanceButton.focusRingType = .none
        appearanceButton.target = self
        appearanceButton.action = #selector(toggleAppearance)
        appearanceButton.toolTip = "切换外观"
        appearanceButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(appearanceButton)

        toggleButton.isBordered = false
        toggleButton.imagePosition = .imageOnly
        toggleButton.focusRingType = .none
        toggleButton.target = self
        toggleButton.action = #selector(toggleMode)
        toggleButton.toolTip = "已完成收录"
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toggleButton)

        divider.wantsLayer = true
        divider.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(divider)

        doingCaption.font = .systemFont(ofSize: 10.5, weight: .regular)
        doingCaption.textColor = palette.hint
        doingCaption.isHidden = true
        doingCaption.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doingCaption)

        doingStack.orientation = .vertical
        doingStack.spacing = 2
        doingStack.isHidden = true
        doingStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doingStack)

        doingSeparator.wantsLayer = true
        doingSeparator.isHidden = true
        doingSeparator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doingSeparator)

        scrollView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.hoveredRow?.setHovered(false)
            self.hoveredRow = nil
        }
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)

        docView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = docView

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(stack)

        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: 12.5)
        emptyLabel.maximumNumberOfLines = 2
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        addBox.wantsLayer = true
        addBox.layer?.cornerRadius = 9
        addBox.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(addBox)

        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addBox.addSubview(placeholderLabel)

        addField.isBordered = false
        addField.drawsBackground = false
        addField.focusRingType = .none
        addField.font = .systemFont(ofSize: 13)
        addField.delegate = self
        addField.target = self
        addField.action = #selector(addTodo)
        addField.translatesAutoresizingMaskIntoConstraints = false
        addBox.addSubview(addField)

        grip.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grip)

        scrollTopToDivider = scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor)
        scrollTopToDoing = scrollView.topAnchor.constraint(equalTo: doingSeparator.bottomAnchor, constant: 8)
        scrollBottomToAddBox = scrollView.bottomAnchor.constraint(equalTo: addBox.topAnchor, constant: -10)
        scrollBottomToContent = scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)

        NSLayoutConstraint.activate([
            frost.topAnchor.constraint(equalTo: content.topAnchor),
            frost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            frost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            frost.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            haze.topAnchor.constraint(equalTo: content.topAnchor),
            haze.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            haze.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            haze.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),

            hintLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            appearanceButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            appearanceButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            appearanceButton.widthAnchor.constraint(equalToConstant: 20),
            appearanceButton.heightAnchor.constraint(equalToConstant: 20),

            toggleButton.trailingAnchor.constraint(equalTo: appearanceButton.leadingAnchor, constant: -6),
            toggleButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: 20),
            toggleButton.heightAnchor.constraint(equalToConstant: 20),

            countLabel.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            divider.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            doingCaption.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 6),
            doingCaption.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),

            doingStack.topAnchor.constraint(equalTo: doingCaption.bottomAnchor, constant: 2),
            doingStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            doingStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),

            doingSeparator.topAnchor.constraint(equalTo: doingStack.bottomAnchor, constant: 6),
            doingSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            doingSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            doingSeparator.heightAnchor.constraint(equalToConstant: 1),

            scrollTopToDivider,
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollBottomToAddBox,

            docView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            docView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            docView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stack.topAnchor.constraint(equalTo: docView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: docView.bottomAnchor, constant: -8),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -40),

            addBox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            addBox.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            addBox.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            addBox.heightAnchor.constraint(equalToConstant: 30),

            placeholderLabel.leadingAnchor.constraint(equalTo: addField.leadingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: addField.centerYAnchor),

            addField.leadingAnchor.constraint(equalTo: addBox.leadingAnchor, constant: 11),
            addField.trailingAnchor.constraint(equalTo: addBox.trailingAnchor, constant: -11),
            addField.centerYAnchor.constraint(equalTo: addBox.centerYAnchor),
            addField.heightAnchor.constraint(equalToConstant: 20),

            grip.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grip.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: 13),
            grip.heightAnchor.constraint(equalToConstant: 13)
        ])
    }

    // MARK: - 外观

    private func applyPalette() {
        panel.appearance = NSAppearance(named: palette.appearanceName)
        content.layer?.backgroundColor = palette.cardFill.cgColor
        content.layer?.borderColor = palette.cardBorder.cgColor
        content.layer?.borderWidth = palette.cardBorderWidth
        frost.isHidden = !palette.frostsEdge
        haze.isHidden = !palette.frostsEdge
        titleLabel.textColor = palette.title
        countLabel.textColor = palette.count
        hintLabel.textColor = noticeText != nil ? NSColor.white.withAlphaComponent(0.95) : palette.hint
        toggleButton.contentTintColor = palette.menuTint
        appearanceButton.contentTintColor = palette.menuTint
        divider.layer?.backgroundColor = palette.divider.cgColor
        addBox.layer?.backgroundColor = palette.addBoxFill.cgColor
        addField.textColor = palette.addText
        placeholderLabel.textColor = palette.placeholder
        addBox.layer?.borderWidth = 1
        addBox.layer?.borderColor = palette.addBoxBorder.cgColor
        emptyLabel.textColor = palette.emptyText
        grip.strokeColor = palette.gripStroke
        grip.hoverOnly = palette.gripHoverOnly

        let shadow = palette.textShadow
        titleLabel.shadow = shadow
        countLabel.shadow = shadow
        hintLabel.shadow = shadow
        addField.shadow = shadow
        placeholderLabel.shadow = shadow
        emptyLabel.shadow = shadow
        for button in [toggleButton, appearanceButton] {
            button.wantsLayer = true
            button.layer?.shadowColor = NSColor.black.cgColor
            button.layer?.shadowOpacity = shadow == nil ? 0 : 0.6
            button.layer?.shadowRadius = 2
            button.layer?.shadowOffset = CGSize(width: 0, height: -1)
        }
        reload()
    }

    func setTheme(_ newTheme: Theme) {
        guard newTheme != theme else { return }
        theme = newTheme
        palette = Palette.make(newTheme)
        UserDefaults.standard.set(newTheme.rawValue, forKey: WidgetController.themeDefaultsKey)
        applyPalette()
        NotificationCenter.default.post(name: .todoFloatThemeChanged, object: nil)
    }

    // MARK: - Data

    func reload() {
        if hoveredRow != nil { NSCursor.arrow.set() }
        hoveredRow = nil
        for row in rows {
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        rows.removeAll()

        switch mode {
        case .todos:
            buildTodoRows()
            titleLabel.stringValue = listTitle
            hintLabel.stringValue = noticeText ?? "双击文字可以改内容"
            hintLabel.textColor = noticeText != nil ? NSColor.white.withAlphaComponent(0.95) : palette.hint
            let pendingCount = store.items.filter { !$0.isDoing }.count
            countLabel.stringValue = pendingCount == 0 ? "" : "\(pendingCount) 项"
            if store.items.isEmpty {
                emptyLabel.stringValue = "桌面上还没有待办\n在下面输入，按回车添加"
            } else if pendingCount == 0 {
                emptyLabel.stringValue = "都在「在办」里\n完成或取消在办后会回到这里"
            }
            emptyLabel.isHidden = !(store.items.isEmpty || pendingCount == 0)
            addField.isHidden = false
            updatePlaceholderVisibility()
            addBox.isHidden = false
            scrollBottomToAddBox.isActive = true
            scrollBottomToContent.isActive = false
            toggleButton.image = symbol("archivebox")
            toggleButton.toolTip = "已完成收录"
        case .archive:
            buildArchiveRows()
            titleLabel.stringValue = "已完成收录"
            hintLabel.stringValue = noticeText ?? "点勾号恢复 · 悬停删除 · 30 天自动清理"
            hintLabel.textColor = noticeText != nil ? NSColor.white.withAlphaComponent(0.95) : palette.hint
            let weekCount = store.completedThisWeek
            if weekCount > 0 {
                countLabel.stringValue = "本周完成 \(weekCount) 条"
            } else {
                countLabel.stringValue = store.archive.isEmpty ? "" : "共 \(store.archive.count) 条"
            }
            emptyLabel.stringValue = "还没有收录\n勾掉的任务会自动收进这里"
            emptyLabel.isHidden = !store.archive.isEmpty
            addField.isHidden = true
            placeholderLabel.isHidden = true
            addBox.isHidden = true
            scrollBottomToAddBox.isActive = false
            scrollBottomToContent.isActive = true
            toggleButton.image = symbol("list.bullet")
            toggleButton.toolTip = "返回待办"
        }

        rebuildDoingStrip()
    }

    // MARK: - 在办

    var doingCount: Int { store.doingCount }
    func contains(_ id: UUID) -> Bool { store.contains(id: id) }
    func setDoing(_ id: UUID, _ active: Bool) { store.setDoing(id: id, active: active) }
    /// 在办状态变化后整窗重载：列表行的旗子、在办条、计数都要跟着变
    func refreshDoing() { reload() }

    private func rebuildDoingStrip() {
        for row in doingRows {
            doingStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        doingRows.removeAll()

        // 在办条只属于待办视图，归档里不显示
        let items = mode == .todos ? store.doingItems : []
        doingCaption.isHidden = items.isEmpty
        doingCaption.textColor = palette.hint
        doingCaption.shadow = palette.textShadow
        doingStack.isHidden = items.isEmpty
        doingSeparator.isHidden = items.isEmpty
        doingSeparator.layer?.backgroundColor = palette.separator.cgColor
        scrollTopToDivider?.isActive = items.isEmpty
        scrollTopToDoing?.isActive = !items.isEmpty

        for item in items {
            let row = DoingBarRow(item: item, palette: palette)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.onComplete = { [weak self] in
                guard let self = self else { return }
                self.store.complete(id: item.id)
                self.reload()
                self.onDoingDataChanged?()
            }
            row.onUnpin = { [weak self] in
                guard let self = self else { return }
                _ = self.onRequestDoing?(item.id, false)
            }
            doingStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: doingStack.widthAnchor).isActive = true
            doingRows.append(row)
        }
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
    }

    private func buildTodoRows() {
        for item in store.items where !item.isDoing {
            let row = TodoRowView(item: item, palette: palette)
            row.onHoverChange = { [weak self, weak row] entered in
                self?.hoverChanged(row, entered: entered)
            }
            row.translatesAutoresizingMaskIntoConstraints = false
            row.onToggle = { [weak self] in
                self?.store.complete(id: item.id)
                self?.reload()
            }
            row.onDelete = { [weak self] in
                self?.store.delete(id: item.id)
                self?.reload()
            }
            row.onRename = { [weak self] title in
                self?.store.rename(id: item.id, title: title)
                self?.reload()
            }
            row.onToggleDoing = { [weak self] in
                guard let self = self else { return }
                let active = !item.isDoing
                if let handler = self.onRequestDoing {
                    if !handler(item.id, active), active {
                        self.showNotice("在办最多两个，先完成一个", seconds: 4)
                    }
                }
            }
            stack.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: stack.widthAnchor),
                row.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
            ])
            rows.append(row)
        }
    }

    private func buildArchiveRows() {
        store.purgeExpiredArchive()
        for item in store.sortedArchive {
            let row = ArchiveRowView(item: item, palette: palette)
            row.onHoverChange = { [weak self, weak row] entered in
                self?.hoverChanged(row, entered: entered)
            }
            row.translatesAutoresizingMaskIntoConstraints = false
            row.onRestore = { [weak self] in
                self?.store.restore(id: item.id)
                self?.reload()
            }
            row.onDelete = { [weak self] in
                self?.store.deleteArchived(id: item.id)
                self?.reload()
            }
            stack.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: stack.widthAnchor),
                row.heightAnchor.constraint(equalToConstant: 36)
            ])
            rows.append(row)
        }
    }

    @objc private func toggleMode() {
        mode = (mode == .todos) ? .archive : .todos
        reload()
    }

    /// 用清单自己的那行小字显示问题提示，几秒后自动恢复
    /// 同一时刻只允许一行处于 hover 高亮；滚动时 mouseExited 可能不来，靠进入新行清掉旧行
    private func hoverChanged(_ row: HoverHighlighting?, entered: Bool) {
        guard let row = row else { return }
        if entered {
            if let previous = hoveredRow, previous !== row {
                previous.setHovered(false)
            }
            hoveredRow = row
        } else if hoveredRow === row {
            hoveredRow = nil
        }
    }

    func showNotice(_ text: String, seconds: Double = 10) {
        noticeText = text
        noticeToken += 1
        let token = noticeToken
        hintLabel.stringValue = text
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.95)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, self.noticeToken == token else { return }
            self.noticeText = nil
            self.reload()
        }
    }

    func showArchiveMode() {
        mode = .archive
        reload()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        isAddFieldFocused = true
        updatePlaceholderVisibility()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        isAddFieldFocused = false
        updatePlaceholderVisibility()
    }

    func controlTextDidChange(_ obj: Notification) {
        updatePlaceholderVisibility()
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = isAddFieldFocused || !addField.stringValue.isEmpty
    }

    @objc private func addTodo() {
        if store.add(title: addField.stringValue) {
            addField.stringValue = ""
            updatePlaceholderVisibility()
            reload()
            scrollToBottom()
        }
    }

    private func scrollToBottom() {
        docView.layoutSubtreeIfNeeded()
        let maxY = max(0, docView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - 显示

    func showOnDesktop() {
        if !panel.isVisible { panel.orderFront(nil) }
        panel.makeFirstResponder(nil)
        DispatchQueue.main.async { [weak self] in
            self?.panel.makeFirstResponder(nil)
        }
        panel.level = desktopLevel
        panel.hasShadow = false
        panel.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenNone]
        updateSeamStyling()
    }

    func blurAddFieldForSnapshot() {
        handleClick(inAddBox: false)
    }

    func focusAddFieldForSnapshot() {
        panel.makeKey()
        _ = panel.makeFirstResponder(addField)
        handleClick(inAddBox: true)
    }

    func writeSnapshot(to path: String) {
        panel.displayIfNeeded()
        content.layoutSubtreeIfNeeded()
        let bounds = content.bounds
        guard let rep = content.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        rep.size = bounds.size
        content.cacheDisplay(in: bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    // MARK: - 外观 / 退出

    @objc private func themeDidChangeExternally() {
        let saved = Theme(rawValue: UserDefaults.standard.string(forKey: WidgetController.themeDefaultsKey) ?? "") ?? .clear
        guard saved != theme else { return }
        theme = saved
        palette = Palette.make(saved)
        applyPalette()
    }

    @objc private func toggleAppearance() {
        setTheme(theme == .clear ? .dark : .clear)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Row

final class TodoRowView: NSView, NSTextFieldDelegate, HoverHighlighting {
    private let item: TodoItem
    private let palette: Palette
    var onToggle: (() -> Void)?
    var onDelete: (() -> Void)?
    var onRename: ((String) -> Void)?
    var onToggleDoing: (() -> Void)?

    private let check = NSButton()
    private let label = NSTextField(labelWithString: "")
    private let flag = NSButton()
    private let del = NSButton()
    private let editField = NSTextField()
    private var tracking: NSTrackingArea?
    private(set) var isEditingNow = false
    private var isHovering = false

    init(item: TodoItem, palette: Palette) {
        self.item = item
        self.palette = palette
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = NSColor.clear.cgColor
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        check.isBordered = false
        check.imagePosition = .imageOnly
        check.focusRingType = .none
        let symbol = item.done ? "checkmark.circle.fill" : "circle"
        check.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "完成")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        check.contentTintColor = item.done ? .controlAccentColor : palette.checkTint
        check.target = self
        check.action = #selector(toggleTapped)
        applyIconShadow(to: check)
        check.translatesAutoresizingMaskIntoConstraints = false
        addSubview(check)

        label.attributedStringValue = TodoRowView.attributedTitle(item, palette: palette)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        flag.isBordered = false
        flag.imagePosition = .imageOnly
        flag.focusRingType = .none
        flag.image = NSImage(systemSymbolName: item.isDoing ? "flag.fill" : "flag", accessibilityDescription: "在办")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        flag.contentTintColor = item.isDoing ? .controlAccentColor : palette.checkTint
        flag.target = self
        flag.action = #selector(toggleDoingTapped)
        flag.toolTip = item.isDoing ? "取消在办" : "设为在办"
        flag.isHidden = true
        flag.translatesAutoresizingMaskIntoConstraints = false
        addSubview(flag)

        del.isBordered = false
        del.imagePosition = .imageOnly
        del.focusRingType = .none
        del.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "删除")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        del.contentTintColor = palette.deleteTint
        del.target = self
        del.action = #selector(deleteTapped)
        applyIconShadow(to: del)
        del.isHidden = true
        del.translatesAutoresizingMaskIntoConstraints = false
        addSubview(del)

        editField.isBordered = false
        editField.drawsBackground = true
        editField.backgroundColor = palette.editFill
        editField.focusRingType = .none
        editField.font = .systemFont(ofSize: 14)
        editField.textColor = palette.editText
        editField.delegate = self
        editField.isHidden = true
        editField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(editField)

        NSLayoutConstraint.activate([
            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            check.centerYAnchor.constraint(equalTo: centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 20),
            check.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: flag.leadingAnchor, constant: -6),

            flag.trailingAnchor.constraint(equalTo: del.leadingAnchor, constant: -2),
            flag.centerYAnchor.constraint(equalTo: centerYAnchor),
            flag.widthAnchor.constraint(equalToConstant: 18),
            flag.heightAnchor.constraint(equalToConstant: 18),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            del.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            del.centerYAnchor.constraint(equalTo: centerYAnchor),
            del.widthAnchor.constraint(equalToConstant: 18),
            del.heightAnchor.constraint(equalToConstant: 18),

            editField.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -4),
            editField.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            editField.centerYAnchor.constraint(equalTo: centerYAnchor),
            editField.heightAnchor.constraint(equalToConstant: 24)
        ])

        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(beginEdit))
        doubleClick.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClick)
    }

    private func applyIconShadow(to button: NSButton) {
        guard palette.textShadow != nil else { return }
        button.wantsLayer = true
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.55
        button.layer?.shadowRadius = 2
        button.layer?.shadowOffset = CGSize(width: 0, height: -1)
    }

    private static func attributedTitle(_ item: TodoItem, palette: Palette) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14)
        let color = item.done ? palette.rowDoneText : palette.rowText
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let shadow = palette.textShadow { attributes[.shadow] = shadow }
        let text = NSMutableAttributedString(string: item.title, attributes: attributes)
        if item.done {
            let range = NSRange(location: 0, length: text.length)
            text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            text.addAttribute(.strikethroughColor, value: color, range: range)
        }
        return text
    }

    override func layout() {
        super.layout()
        let width = label.frame.width
        if width > 1, abs(label.preferredMaxLayoutWidth - width) > 0.5 {
            label.preferredMaxLayoutWidth = width
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    var onHoverChange: ((Bool) -> Void)?

    func setHovered(_ hovered: Bool) {
        del.isHidden = !hovered
        flag.isHidden = !hovered
        layer?.backgroundColor = hovered ? palette.hoverFill.cgColor : NSColor.clear.cgColor
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        setHovered(true)
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        if !isEditingNow {
            setHovered(false)
        }
        onHoverChange?(false)
    }

    @objc private func toggleTapped() { onToggle?() }
    @objc private func toggleDoingTapped() { onToggleDoing?() }
    @objc private func deleteTapped() { onDelete?() }

    @objc private func beginEdit() {
        guard !isEditingNow else { return }
        isEditingNow = true
        editField.stringValue = item.title
        editField.isHidden = false
        label.isHidden = true
        if let window = window, !window.isKeyWindow {
            window.makeKey()
        }
        window?.makeFirstResponder(editField)
        editField.currentEditor()?.selectAll(nil)
    }

    private func finishEditing(commit: Bool) {
        guard isEditingNow else { return }
        isEditingNow = false
        let text = editField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        editField.isHidden = true
        label.isHidden = false
        if !isHovering { setHovered(false) }
        window?.makeFirstResponder(nil)
        if commit, !text.isEmpty, text != item.title {
            // 延后到下一个 runloop：重载会移除本行视图
            let handler = onRename
            DispatchQueue.main.async { handler?(text) }
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard isEditingNow else { return }
        let movement = (obj.userInfo?["NSTextMovement"] as? Int) ?? 0
        if movement == 0x17 { // Esc
            finishEditing(commit: false)
        } else {
            finishEditing(commit: true)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishEditing(commit: false)
            return true
        }
        return false
    }
}

enum ArchiveDate {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}

/// 收录本里的一行：勾 + 标题 + 完成时间，点一下恢复到待办
final class ArchiveRowView: NSView, HoverHighlighting {
    private let item: TodoItem
    private let palette: Palette
    var onRestore: (() -> Void)?
    var onDelete: (() -> Void)?
    private let checkIcon = NSImageView()
    private let deleteButton = NSButton()
    private var tracking: NSTrackingArea?

    init(item: TodoItem, palette: Palette) {
        self.item = item
        self.palette = palette
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.clear.cgColor
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        checkIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular))
        checkIcon.contentTintColor = .controlAccentColor
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkIcon)

        let title = NSTextField(labelWithString: item.title)
        title.font = .systemFont(ofSize: 13.5)
        title.textColor = palette.rowDoneText
        title.lineBreakMode = .byTruncatingTail
        title.maximumNumberOfLines = 1
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        let when = NSTextField(labelWithString: ArchiveDate.formatter.string(from: item.completedAt ?? item.createdAt))
        when.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        when.textColor = palette.hint
        when.setContentCompressionResistancePriority(.required, for: .horizontal)
        when.translatesAutoresizingMaskIntoConstraints = false
        addSubview(when)

        toolTip = "点勾号可恢复到待办"

        deleteButton.isBordered = false
        deleteButton.imagePosition = .imageOnly
        deleteButton.focusRingType = .none
        deleteButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "删除")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        deleteButton.contentTintColor = palette.deleteTint
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.isHidden = true
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            checkIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            checkIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 20),
            checkIcon.heightAnchor.constraint(equalToConstant: 20),

            title.leadingAnchor.constraint(equalTo: checkIcon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),

            when.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            when.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            when.centerYAnchor.constraint(equalTo: centerYAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 18),
            deleteButton.heightAnchor.constraint(equalToConstant: 18)
        ])

        if let shadow = palette.textShadow {
            checkIcon.wantsLayer = true
            checkIcon.layer?.shadowColor = NSColor.black.cgColor
            checkIcon.layer?.shadowOpacity = 0.55
            checkIcon.layer?.shadowRadius = 2
            checkIcon.layer?.shadowOffset = CGSize(width: 0, height: -1)
            title.shadow = shadow
            when.shadow = shadow
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    var onHoverChange: ((Bool) -> Void)?

    func setHovered(_ hovered: Bool) {
        layer?.backgroundColor = hovered ? palette.hoverFill.cgColor : NSColor.clear.cgColor
        deleteButton.isHidden = !hovered
        if hovered { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        // 等 mouseUp 再恢复，避免在事件派发中途把这一行移除
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // 只有点在勾号上才恢复，点文字/空白处不动
        let hitArea = checkIcon.frame.insetBy(dx: -6, dy: -6)
        guard hitArea.contains(point), let handler = onRestore else { return }
        DispatchQueue.main.async { handler() }
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}
