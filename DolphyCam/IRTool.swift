import Foundation
import ExternalAccessory
import Combine

final class IRTool: NSObject, ObservableObject {
    @Published var adapterConnected = false
    @Published var adapterName = ""
    @Published var logs = ""
    @Published var db = IRDatabase()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(accChanged), name: .EAAccessoryDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accChanged), name: .EAAccessoryDidDisconnect, object: nil)
        EAAccessoryManager.shared().registerForLocalNotifications()
        refresh()
    }

    @objc func accChanged() { refresh() }

    func refresh() {
        let accs = EAAccessoryManager.shared().connectedAccessories
        if let ir = accs.first(where: { $0.name.lowercased().contains("ir") }) {
            adapterConnected = true; adapterName = ir.name
            logs = "Adapter: \(ir.name)\nProtocols: \(ir.protocolStrings.joined(separator: ", "))"
        } else {
            adapterConnected = false; adapterName = ""
            logs = accs.isEmpty ? "No MFi accessories" : "MFi accessories found, none is IR"
        }
    }

    func sendCommand(_ hex: String) {
        guard adapterConnected else { logs = "No adapter"; return }
        logs = "Would send \(hex) — vendor SDK required"
    }
}
