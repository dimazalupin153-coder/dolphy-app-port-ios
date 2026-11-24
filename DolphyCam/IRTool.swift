import Foundation
import ExternalAccessory

final class IRTool: NSObject, ObservableObject {
    @Published var adapterConnected = false
    @Published var adapterName = ""
    @Published var logs = ""

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryChanged), name: .EAAccessoryDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryChanged), name: .EAAccessoryDidDisconnect, object: nil)
        EAAccessoryManager.shared().registerForLocalNotifications()
        refresh()
    }

    @objc func accessoryChanged() { refresh() }

    func refresh() {
        let accessories = EAAccessoryManager.shared().connectedAccessories
        // Ищем любой аксессуар, который может быть ИК-адаптером (по названию или протоколу)
        if let ir = accessories.first(where: { $0.name.lowercased().contains("ir") || $0.protocolStrings.contains(where: { $0.lowercased().contains("ir") }) }) {
            adapterConnected = true
            adapterName = ir.name
            logs = "Adapter: \(ir.name)\nProtocols: \(ir.protocolStrings.joined(separator: ", "))"
        } else {
            adapterConnected = false
            adapterName = ""
            logs = accessories.isEmpty ? "No MFi accessories connected." : "Accessories found, but none look like an IR adapter."
        }
    }

    func sendCommand(_ hex: String) {
        guard adapterConnected else { logs = "No adapter."; return }
        logs = "Sending \(hex) — requires vendor-specific protocol. Check adapter SDK."
    }
}
