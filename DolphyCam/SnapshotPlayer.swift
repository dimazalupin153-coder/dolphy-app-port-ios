import Foundation
import SwiftUI
import UIKit

final class SnapshotPlayer: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isPlaying = false
    @Published var status = ""
    @Published var rtspURL: String = ""

    private var timer: Timer?
    private var workingPath: String?
    private var ip: String = ""
    private var user: String = ""
    private var pass: String = ""

    private let candidates = [
        "/snapshot.jpg", "/jpg/image.jpg", "/image/jpeg.cgi",
        "/cgi-bin/snapshot.cgi", "/onvif/snapshot",
        "/ISAPI/Streaming/channels/101/picture",
        "/snapshot.cgi", "/cgi-bin/snapshot", "/image.jpg",
        "/cgi-bin/viewer/video.jpg", "/axis-cgi/jpg/image.cgi"
    ]

    func start(ip: String, user: String, pass: String, rtsp: String) {
        self.ip = ip; self.user = user; self.pass = pass; self.rtspURL = rtsp
        self.workingPath = nil; self.image = nil
        self.isPlaying = true; self.status = "probe endpoints..."
        Task { await probe(0) }
    }

    private func probe(_ idx: Int) async {
        guard idx < candidates.count else {
            await MainActor.run { self.status = "no snapshot endpoint"; self.isPlaying = false }
            return
        }
        if let img = await fetch(path: candidates[idx]) {
            await MainActor.run {
                self.workingPath = candidates[idx]
                self.image = img
                self.status = "live \(self.ip)\(candidates[idx])"
                self.poll()
            }
        } else { await probe(idx + 1) }
    }

    private func poll() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self, let path = self.workingPath else { return }
            Task {
                if let img = await self.fetch(path: path) {
                    await MainActor.run { self.image = img }
                }
            }
        }
    }

    private func fetch(path: String) async -> UIImage? {
        guard let url = URL(string: "http://\(ip)\(path)") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 2
        if !user.isEmpty {
            let auth = "\(user):\(pass)".data(using: .utf8)!.base64EncodedString()
            req.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (d, r) = try await URLSession.shared.data(for: req)
            if let h = r as? HTTPURLResponse, h.statusCode == 200, d.count > 200 {
                return UIImage(data: d)
            }
        } catch {}
        return nil
    }

    func stop() {
        timer?.invalidate(); timer = nil
        isPlaying = false; status = "stopped"
    }
}
