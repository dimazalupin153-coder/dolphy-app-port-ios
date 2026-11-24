import Foundation
import CoreNFC

final class NFCTool: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var logs = ""
    @Published var available = NFCNDEFReaderSession.readingAvailable
    private var session: NFCNDEFReaderSession?

    func start() {
        guard available else { log("NFC not available on this device"); return }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold iPhone near NFC tag"
        session?.begin()
    }

    func log(_ t: String) { DispatchQueue.main.async { self.logs += t + "\n" } }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        log("session end: \(error.localizedDescription)")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for msg in messages {
            for rec in msg.records {
                let payload = String(data: rec.payload, encoding: .utf8) ?? "<binary>"
                log("[+] \(rec.typeName): \(payload)")
            }
        }
    }
}
