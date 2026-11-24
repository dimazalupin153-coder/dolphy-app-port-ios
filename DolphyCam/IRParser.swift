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
    @Published var status = "init"

    private var manifest: [String: String] = [:]
    private var commandCache: [String: [String]] = [:]

    init() { load() }

    func load() {
        status = "loading Assets.json..."
        guard let url = Bundle.main.url(forResource: "Assets", withExtension: "json") else {
            status = "Assets.json not in bundle"
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let raw = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] ?? [:]
                self.manifest = raw

                var found: [IRRemote] = []
                for (path, _) in raw {
                    guard path.lowercased().hasSuffix(".ir") else { continue }
                    let parts = path.split(separator: "/").map(String.init)
                    guard parts.count >= 2 else { continue }
                    let category = parts.first ?? "misc"
                    let brand = parts.count >= 3 ? parts[1] : "unknown"
                    let name = parts.last?.replacingOccurrences(of: ".ir", with: "") ?? path
                    found.append(IRRemote(name: name, path: path, brand: brand, category: category))
                }

                let sorted = found.sorted { $0.name < $1.name }
                let cats = Array(Set(found.map { $0.category })).sorted()
                let brs = Array(Set(found.map { $0.brand })).sorted()

                DispatchQueue.main.async {
                    self.remotes = sorted
                    self.categories = cats
                    self.brands = brs
                    self.loaded = true
                    self.status = "\(sorted.count) remotes"
                    print("[IR] \(sorted.count) remotes loaded")
                }
            } catch {
                DispatchQueue.main.async { self.status = "json fail: \(error.localizedDescription)" }
            }
        }
    }

    func commands(for remote: IRRemote) -> [String] {
        if let cached = commandCache[remote.path] { return cached }
        guard let content = manifest[remote.path] else { return [] }
        var cmds: [String] = []
        for line in content.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("name:") {
                cmds.append(String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        commandCache[remote.path] = cmds
        return cmds
    }
}
