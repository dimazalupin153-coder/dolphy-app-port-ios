import Foundation

struct IRRemote: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let brand: String
    let category: String
}

final class IRDatabase: ObservableObject {
    @Published var remotes: [IRRemote] = []
    @Published var categories: [String] = []
    @Published var brands: [String] = []
    @Published var loaded = false

    init() { load() }

    func load() {
        guard let base = Bundle.main.resourceURL?.appendingPathComponent("Assets") else { return }
        var found: [IRRemote] = []
        let fm = FileManager.default

        // ищем все .ir файлы рекурсивно
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
        print("[IR] Loaded \(found.count) remotes, \(categories.count) categories, \(brands.count) brands")
    }

    func commands(for remote: IRRemote) -> [String] {
        guard let base = Bundle.main.resourceURL?.appendingPathComponent("Assets"),
              let content = try? String(contentsOf: base.appendingPathComponent(remote.path), encoding: .utf8) else { return [] }
        var cmds: [String] = []
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("name:") {
                cmds.append(String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        return cmds
    }
}
