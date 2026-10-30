import Foundation

struct TodoItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var done: Bool
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String,
         done: Bool = false,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.done = done
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

final class TodoStore {
    private(set) var items: [TodoItem] = []
    private(set) var archive: [TodoItem] = []
    private let fileURL: URL
    private let archiveURL: URL
    private let seedWhenEmpty: Bool

    static func dataDirectory() -> URL {
        let fm = FileManager.default
        let dir: URL
        if let custom = ProcessInfo.processInfo.environment["TODO_DATA_DIR"] {
            dir = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TodoFloat", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 旧版本的工作待办用 todos.json / archive.json，迁移到 work.json / work-archive.json
    static func migrateLegacyFilesIfNeeded() {
        let fm = FileManager.default
        let dir = dataDirectory()
        let pairs = [("todos.json", "work.json"), ("archive.json", "work-archive.json")]
        for (from, to) in pairs {
            let src = dir.appendingPathComponent(from)
            let dst = dir.appendingPathComponent(to)
            guard fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) else { continue }
            try? fm.moveItem(at: src, to: dst)
        }
    }

    init(fileBase: String = "work") {
        seedWhenEmpty = (fileBase == "work")
        let dir = TodoStore.dataDirectory()
        fileURL = dir.appendingPathComponent("\(fileBase).json")
        archiveURL = dir.appendingPathComponent("\(fileBase)-archive.json")
        load()
    }

    var remaining: Int { items.filter { !$0.done }.count }

    // MARK: - 读写

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// 读一个列表；主文件坏了就改名留证，再尝试从 .bak 恢复
    private func readList(from url: URL, decoder: JSONDecoder) -> (items: [TodoItem]?, recovered: Bool) {
        guard let data = try? Data(contentsOf: url) else { return (nil, false) }
        if let decoded = try? decoder.decode([TodoItem].self, from: data) {
            return (decoded, false)
        }
        let stamp = Int(Date().timeIntervalSince1970)
        let badURL = url.appendingPathExtension("bad-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: badURL)
        let bakURL = url.appendingPathExtension("bak")
        if let bakData = try? Data(contentsOf: bakURL),
           let decoded = try? decoder.decode([TodoItem].self, from: bakData) {
            return (decoded, true)
        }
        return (nil, true)
    }

    private func load() {
        let decoder = makeDecoder()
        var recovered = false

        let listResult = readList(from: fileURL, decoder: decoder)
        recovered = recovered || listResult.recovered
        if let loaded = listResult.items {
            items = loaded
        } else if seedWhenEmpty {
            items = TodoStore.seed()
        } else {
            items = []
        }

        let archiveResult = readList(from: archiveURL, decoder: decoder)
        recovered = recovered || archiveResult.recovered
        if let loaded = archiveResult.items {
            archive = loaded
            purgeExpiredArchive()
        }

        // 旧数据里还留在列表里的已完成项，迁移到收录
        let legacyDone = items.filter { $0.done }
        if !legacyDone.isEmpty {
            let stamp = Date()
            archive.insert(contentsOf: legacyDone.map { item -> TodoItem in
                var copy = item
                copy.completedAt = copy.completedAt ?? stamp
                return copy
            }, at: 0)
            items.removeAll { $0.done }
            recovered = true
        }

        if recovered || seedWhenEmpty && !FileManager.default.fileExists(atPath: fileURL.path) {
            save()
        }
    }

    func save() {
        let encoder = makeEncoder()
        if let data = try? encoder.encode(items) {
            write(data, to: fileURL)
        }
        if let data = try? encoder.encode(archive) {
            write(data, to: archiveURL)
        }
    }

    /// 当前文件是否还是一份能解析的列表
    private func isValidList(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return (try? makeDecoder().decode([TodoItem].self, from: data)) != nil
    }

    /// 写入前把上一版留成 .bak（只保留一份），再原子写主文件。
    /// 只有当前文件可解析时才轮换 .bak，坏文件不会把最后一份好备份顶掉。
    private func write(_ data: Data, to url: URL) {
        let fm = FileManager.default
        let bakURL = url.appendingPathExtension("bak")
        if fm.fileExists(atPath: url.path), isValidList(at: url) {
            try? fm.removeItem(at: bakURL)
            try? fm.copyItem(at: url, to: bakURL)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[桌面待办] 写入失败 %@: %@", url.lastPathComponent, error.localizedDescription)
            NotificationCenter.default.post(name: Notification.Name("todoFloat.saveFailed"),
                                            object: nil,
                                            userInfo: ["file": url.lastPathComponent,
                                                       "error": error.localizedDescription])
        }
    }

    // MARK: - 待办

    @discardableResult
    func add(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        items.append(TodoItem(title: trimmed))
        save()
        return true
    }

    /// 勾掉即收录：从待办移入已完成收录
    func complete(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: i)
        item.done = true
        item.completedAt = Date()
        archive.insert(item, at: 0)
        save()
    }

    func rename(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].title = trimmed
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// 从收录本恢复到待办
    func restore(id: UUID) {
        guard let i = archive.firstIndex(where: { $0.id == id }) else { return }
        var item = archive.remove(at: i)
        item.done = false
        item.completedAt = nil
        item.createdAt = Date()
        items.append(item)
        save()
    }

    func deleteArchived(id: UUID) {
        archive.removeAll { $0.id == id }
        save()
    }

    /// 收录最多保留 30 天，过期自动清理
    @discardableResult
    func purgeExpiredArchive(days: Int = 30) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let before = archive.count
        archive.removeAll { ($0.completedAt ?? $0.createdAt) < cutoff }
        let removed = before - archive.count
        if removed > 0 { save() }
        return removed
    }

    /// 本周内完成并收进收录的条数
    var completedThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        return archive.filter { item in
            guard let completed = item.completedAt else { return false }
            return calendar.isDate(completed, equalTo: now, toGranularity: .weekOfYear)
        }.count
    }

    var sortedArchive: [TodoItem] {
        archive.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private static func seed() -> [TodoItem] {
        [
            TodoItem(title: "按 F11 回到桌面就能看到这张清单", done: false),
            TodoItem(title: "做完了点左边的圆圈，会自动收进已完成收录", done: false)
        ]
    }
}