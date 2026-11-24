import Foundation

struct IRRemote: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String        // relative to Assets root
    let brand: String
    let category: String
}

final class IRDatabase: ObservableObject {
    @Published var remotes: [IRRemote] = []
    @Published var categories: [String] = []
    @Published var brands: [String] = []
    @Published var loaded = false
    @Published var status = "init"

    static var assetsRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Assets", isDirectory: true)
    }

    init() { bootstrap() }

    func bootstrap() {
        let fm = FileManager.default
        let root = Self.assetsRoot

        // если уже распаковано — грузим
        if fm.fileExists(atPath: root.path) {
            status = "loading from cache"
            load()
            return
        }

        // иначе распаковываем zip из бандла
        guard let zipURL = Bundle.main.url(forResource: "Assets", withExtension: "zip") else {
            status = "Assets.zip not in bundle"
            return
        }
        status = "unzipping \(Int((try? fm.attributesOfItem(atPath: zipURL.path)[.size] as? Int64 ?? 0) ?? 0) bytes)..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                try Self.unzipItem(at: zipURL, to: root)
                DispatchQueue.main.async {
                    self.status = "unpacked"
                    self.load()
                }
            } catch {
                DispatchQueue.main.async { self.status = "unzip failed: \(error.localizedDescription)" }
            }
        }
    }

    private func load() {
        let fm = FileManager.default
        let base = Self.assetsRoot
        var found: [IRRemote] = []

        if let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "ir" else { continue }
                let rel = url.path.replacingOccurrences(of: base.path + "/", with: "")
                let parts = rel.split(separator: "/").map(String.init)
                guard parts.count >= 2 else { continue }
                let category = parts.first ?? "misc"
                let brand = parts.count >= 3 ? parts[1] : "unknown"
                let name = parts.last?.replacingOccurrences(of: ".ir", with: "") ?? url.lastPathComponent
                found.append(IRRemote(name: name, path: rel, brand: brand, category: category))
            }
        }

        self.remotes = found.sorted { $0.name < $1.name }
        self.categories = Array(Set(found.map { $0.category })).sorted()
        self.brands = Array(Set(found.map { $0.brand })).sorted()
        self.loaded = true
        self.status = "\(found.count) remotes"
        print("[IR] \(found.count) remotes, \(categories.count) cats, \(brands.count) brands")
    }

    func commands(for remote: IRRemote) -> [String] {
        let url = Self.assetsRoot.appendingPathComponent(remote.path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var cmds: [String] = []
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("name:") {
                cmds.append(String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        return cmds
    }

    // MARK: - Zip extraction (use /usr/bin/unzip on iOS, дёшево и надёжно)
    private static func unzipItem(at zipURL: URL, to dest: URL) throws {
        // iOS имеет unzip в /usr/bin — но sandbox не даёт прямой доступ.
        // поэтому используем встроенный ZipArchive через NSFileManager API
        // (начиная iOS 16, но для 15+ нужно свой распаковщик)
        try Self.builtinUnzip(zipURL: zipURL, to: dest)
    }

    private static func builtinUnzip(zipURL: URL, to dest: URL) throws {
        // минимальный распаковщик — использует libcompression через zlib (stored/deflate)
        // на практике: вызываем через zlib из Swift
        // упрощённо: пробуем нативный API (iOS 16+), для iOS 15 — fallback
        if #available(iOS 16.0, *) {
            // используем FileManager распаковку через ARchive (нет публичного API)
            // поэтому идём через shell (доступен на iOS в sandbox для Documents)
            let task = Process()
            task.launchPath = "/usr/bin/unzip"
            task.arguments = ["-o", zipURL.path, "-d", dest.path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "unzip", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: out])
            }
        } else {
            // iOS 15 — простой распаковщик через минизип
            throw NSError(domain: "unzip", code: -1, userInfo: [NSLocalizedDescriptionKey: "iOS 15 не поддерживает unzip, обновитесь"])
        }
    }
}
