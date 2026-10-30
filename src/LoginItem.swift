import AppKit
import ServiceManagement

/// 开机自启：用 macOS 13+ 的 SMAppService 注册主 App，
/// 这样它在「系统设置 → 通用 → 登录项」里是一条正常的 App 登录项，跟着 App 走、不怕改路径。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "已开启"
        case .requiresApproval: return "已在登录项中，等待系统允许"
        case .notRegistered: return "未开启"
        case .notFound: return "未找到 App"
        @unknown default: return "未知状态"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            // 已在登录项里、只等系统允许时，再注册会抛错
            guard service.status != .enabled, service.status != .requiresApproval else { return }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
    }

    static func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
