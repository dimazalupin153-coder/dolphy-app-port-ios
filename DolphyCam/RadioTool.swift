import Foundation
import CoreBluetooth
import MultipeerConnectivity
import UIKit

final class BLEScan: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [(String, Int)] = []
    @Published var on = false
    private var central: CBCentralManager!
    override init() { super.init(); central = CBCentralManager(delegate: self, queue: .global()) }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        DispatchQueue.main.async { self.on = c.state == .poweredOn }
        if c.state == .poweredOn {
            c.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }
    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name ?? "unknown"
        DispatchQueue.main.async {
            if let idx = self.devices.firstIndex(where: { $0.0 == name }) {
                self.devices[idx] = (name, RSSI.intValue)
            } else {
                self.devices.append((name, RSSI.intValue))
            }
        }
    }
}

final class Chat: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [String] = []
    @Published var peers: Int = 0
    private var session: MCSession!
    private var adv: MCNearbyServiceAdvertiser!
    private var brow: MCNearbyServiceBrowser!

    override init() {
        super.init()
        session = MCSession(peer: MCPeerID(displayName: UIDevice.current.name), securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        adv = MCNearbyServiceAdvertiser(peer: session.myPeerID, discoveryInfo: nil, serviceType: "dolphy-chat")
        adv.delegate = self; adv.startAdvertisingPeer()
        brow = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: "dolphy-chat")
        brow.delegate = self; brow.startBrowsingForPeers()
    }

    func send(_ text: String) {
        guard !session.connectedPeers.isEmpty else { return }
        if let d = text.data(using: .utf8) { try? session.send(d, toPeers: session.connectedPeers, with: .reliable) }
        messages.append("[me] \(text)")
    }
    func session(_ s: MCSession, didReceive data: Data, fromPeer p: MCPeerID) {
        if let t = String(data: data, encoding: .utf8) { DispatchQueue.main.async { self.messages.append("[\(p.displayName)] \(t)") } }
    }
    func session(_ s: MCSession, peer p: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.peers = s.connectedPeers.count }
    }
    func session(_ s: MCSession, didReceive st: InputStream, withName n: String, fromPeer p: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer p: MCPeerID, with prog: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer p: MCPeerID, at u: URL?, withError e: Error?) {}
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer p: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer p: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(p, to: session, withContext: nil, timeout: 10) }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer p: MCPeerID) {}
}
