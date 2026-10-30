import AppKit

enum MenuBuilder {
    /// 没有主菜单就没有 Cmd+C / Cmd+V 的快捷键来源，这里补一套标准编辑菜单
    static func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于桌面待办", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出桌面待办", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: Selector(("selectAll:")), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let loginItemTag = 1001
    private var widget: WidgetController?
    private var personalWidget: WidgetController?
    private var statusItem: NSStatusItem?
    private var lastSaveErrorAt: [String: Date] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单实例：已经有同名进程就把它叫到前面，自己退出
        let bundleID = Bundle.main.bundleIdentifier ?? "local.todofloat.app"
        let allowMulti = ProcessInfo.processInfo.environment["TODO_ALLOW_MULTI"] != nil
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !allowMulti, let other = others.first {
            NSLog("[桌面待办] 已有实例在运行，本次启动退出")
            other.activate(options: [])
            NSApp.terminate(nil)
            return
        }

        TodoStore.migrateLegacyFilesIfNeeded()
        widget = WidgetController(listTitle: "工作待办")
        personalWidget = WidgetController(listTitle: "个人待办",
                                          fileBase: "personal",
                                          frameName: "TodoFloatPersonalPanel",
                                          rightInset: 28 + WidgetController.defaultSize.width)
        widget?.showOnDesktop()
        personalWidget?.showOnDesktop()
        widget?.companionPanel = { [weak self] in self?.personalWidget?.panel }
        personalWidget?.companionPanel = { [weak self] in self?.widget?.panel }
        if let work = widget, let personal = personalWidget {
            // 启动时校正历史遗留的 1px 错位，以工作待办为基准
            var frame = personal.panel.frame
            let reference = work.panel.frame
            let tolerance: CGFloat = 2
            let sideBySide = abs(frame.maxX - reference.minX) <= tolerance
                || abs(frame.minX - reference.maxX) <= tolerance
            let stacked = abs(frame.maxY - reference.minY) <= tolerance
                || abs(frame.minY - reference.maxY) <= tolerance
            if sideBySide, abs(frame.maxY - reference.maxY) <= tolerance {
                frame.origin.y = reference.maxY - frame.height
            }
            if stacked, abs(frame.minX - reference.minX) <= tolerance {
                frame.origin.x = reference.minX
            }
            if frame != personal.panel.frame {
                personal.panel.setFrame(frame, display: true)
            }
            LockCoordinator.shared.attach(work: work.panel, personal: personal.panel)
        }
        NotificationCenter.default.post(name: .todoFloatLayoutChanged, object: nil)
        setupStatusItem()
        verifyDesktopPlacement()

        NotificationCenter.default.addObserver(forName: Notification.Name("todoFloat.saveFailed"),
                                               object: nil,
                                               queue: .main) { [weak self] note in
            guard let self = self else { return }
            let error = note.userInfo?["error"] as? String ?? "未知错误"
            let file = note.userInfo?["file"] as? String ?? "数据文件"
            let now = Date()
            // 按文件分别节流：两个清单同时失败时都能各自提示
            if let last = self.lastSaveErrorAt[file], now.timeIntervalSince(last) < 60 { return }
            self.lastSaveErrorAt[file] = now
            self.widget?.showNotice("数据未保存 · \(file) \(error)", seconds: 10)
            self.personalWidget?.showNotice("数据未保存 · \(file) \(error)", seconds: 10)
        }

        // 供命令行开关登录项用（不影响日常使用）
        if let loginArg = ProcessInfo.processInfo.environment["TODO_LOGIN"] {
            do {
                try LoginItem.setEnabled(loginArg == "on")
            } catch {
                print("LOGIN error:", error.localizedDescription)
            }
            print("LOGIN status:", LoginItem.statusDescription)
            NSApp.terminate(nil)
        }

        if let path = ProcessInfo.processInfo.environment["TODO_ARCHIVE_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.widget?.showArchiveMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.widget?.writeSnapshot(to: path)
                    NSApp.terminate(nil)
                }
            }
        }

        if let path = ProcessInfo.processInfo.environment["TODO_PERSONAL_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.personalWidget?.writeSnapshot(to: path)
                NSApp.terminate(nil)
            }
        }

        if let path = ProcessInfo.processInfo.environment["TODO_BLUR_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.widget?.focusAddFieldForSnapshot()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.widget?.blurAddFieldForSnapshot()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.widget?.writeSnapshot(to: path)
                        NSApp.terminate(nil)
                    }
                }
            }
        }

        if let path = ProcessInfo.processInfo.environment["TODO_FOCUS_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.widget?.focusAddFieldForSnapshot()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.widget?.writeSnapshot(to: path)
                    NSApp.terminate(nil)
                }
            }
        }

        if let path = ProcessInfo.processInfo.environment["TODO_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.widget?.writeSnapshot(to: path)
                NSApp.terminate(nil)
            }
        }
    }

    /// 正常情况静默；只有层级跑出"壁纸之上、普通窗口之下"的范围才写日志
    private func verifyDesktopPlacement() {
        guard let level = widget?.panel.level.rawValue else { return }
        let wallpaper = Int(CGWindowLevelForKey(.desktopWindow))
        let normal = Int(CGWindowLevelForKey(.normalWindow))
        if level <= wallpaper || level >= normal {
            NSLog("[桌面待办] 窗口层级异常：%d（应在 %d 与 %d 之间）", level, wallpaper, normal)
            widget?.showNotice("窗口层级异常，请查看系统日志", seconds: 10)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "桌面待办")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular))
        }
        let menu = NSMenu()

        let login = NSMenuItem(title: "开机自动启动", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.tag = loginItemTag
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出桌面待办", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let login = menu.item(withTag: loginItemTag) else { return }
        login.state = LoginItem.isEnabled ? .on : .off
        login.title = LoginItem.needsApproval ? "开机自动启动（等待系统允许）" : "开机自动启动"
    }

    @objc func toggleLoginItem() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
            if LoginItem.needsApproval {
                let alert = NSAlert()
                alert.messageText = "已加入登录项，还差最后一步"
                alert.informativeText = "请在「系统设置 → 通用 → 登录项与扩展」里允许「桌面待办」，下次开机它会自动出现在桌面上。"
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    LoginItem.openLoginItemsSettings()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "开机自启设置失败"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
