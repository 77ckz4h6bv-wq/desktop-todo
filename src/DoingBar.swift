import AppKit

/// 窗口顶部「在办」条里的一行：排版与普通待办行一致，右侧蓝色旗子表示取消在办
final class DoingBarRow: NSView {
    private let item: TodoItem
    private let palette: Palette
    var onComplete: (() -> Void)?
    var onUnpin: (() -> Void)?

    private let check = NSButton()
    private let title = NSTextField(labelWithString: "")
    private let flag = NSButton()

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
        check.isBordered = false
        check.imagePosition = .imageOnly
        check.focusRingType = .none
        check.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "完成")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        check.contentTintColor = palette.checkTint
        check.target = self
        check.action = #selector(completeTapped)
        check.toolTip = "完成"
        check.translatesAutoresizingMaskIntoConstraints = false
        addSubview(check)

        title.stringValue = item.title
        title.font = .systemFont(ofSize: 14)
        title.textColor = palette.rowText
        title.lineBreakMode = .byWordWrapping
        title.maximumNumberOfLines = 0
        title.cell?.wraps = true
        title.cell?.isScrollable = false
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        title.setContentHuggingPriority(.defaultLow, for: .vertical)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        flag.isBordered = false
        flag.imagePosition = .imageOnly
        flag.focusRingType = .none
        flag.image = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "取消在办")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        flag.contentTintColor = .controlAccentColor
        flag.target = self
        flag.action = #selector(unpinTapped)
        flag.toolTip = "取消在办，回到列表"
        flag.translatesAutoresizingMaskIntoConstraints = false
        addSubview(flag)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 34),

            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            check.centerYAnchor.constraint(equalTo: centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 20),
            check.heightAnchor.constraint(equalToConstant: 20),

            title.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 9),
            title.trailingAnchor.constraint(equalTo: flag.leadingAnchor, constant: -6),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            flag.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            flag.centerYAnchor.constraint(equalTo: centerYAnchor),
            flag.widthAnchor.constraint(equalToConstant: 20),
            flag.heightAnchor.constraint(equalToConstant: 20)
        ])

        if let shadow = palette.textShadow {
            title.shadow = shadow
        }
    }

    override func layout() {
        super.layout()
        let width = title.frame.width
        if width > 1, abs(title.preferredMaxLayoutWidth - width) > 0.5 {
            title.preferredMaxLayoutWidth = width
        }
    }

    @objc private func completeTapped() { onComplete?() }
    @objc private func unpinTapped() { onUnpin?() }
}
