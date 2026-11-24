import Foundation
import UIKit

struct Credential { let user: String; let pass: String }
struct CameraHit: Identifiable {
    let id = UUID()
    let ip: String
    let user: String
    let pass: String
    let rtspURL: String
}

enum Wordlist {
    static func load(_ name: String) -> [String] {
        guard let path = Bundle.main.path(forResource: name, ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
    static func loadCreds() -> [Credential] {
        var out: [Credential] = []
        for line in load("passwords") {
            if let idx = line.firstIndex(of: ":") {
                let u = String(line[..<idx])
                let p = String(line[line.index(after: idx)...])
                if !u.isEmpty { out.append(Credential(user: u, pass: p)) }
            }
        }
        return out
    }
}
