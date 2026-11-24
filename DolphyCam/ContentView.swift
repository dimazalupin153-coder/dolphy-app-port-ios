import SwiftUI

struct ContentView: View {
    @StateObject var net = NetworkTool()
    @StateObject var vlc = VLCBox()
    @StateObject var nfc = NFCTool()
    @StateObject var ble = BLEScan()
    @StateObject var chat = Chat()
    @StateObject var ir = IRTool()

    @State private var subnet = "192.168.1"
    @State private var targetIP = "192.168.1.1"
    @State private var gateway = "192.168.1.1"

    var body: some View {
        TabView {
            CamerasView(net: net, vlc: vlc, subnet: $subnet)
                .tabItem { Label("Камеры", systemImage: "camera") }
            PortsView(net: net, ip: $targetIP)
                .tabItem { Label("Порты", systemImage: "network") }
            WifiView(net: net, gateway: $gateway)
                .tabItem { Label("WiFi", systemImage: "wifi") }
            NFCRadioView(nfc: nfc, ble: ble, chat: chat)
                .tabItem { Label("Radio", systemImage: "antenna.radiowaves.left.and.right") }
            IRView(ir: ir)
                .tabItem { Label("IR", systemImage: "av.remote") }
        }
        .preferredColorScheme(.dark)
    }
}

struct CamerasView: View {
    @ObservedObject var net: NetworkTool
    @ObservedObject var vlc: VLCBox
    @Binding var subnet: String
    @State private var playURL: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 6) {
                HStack {
                    TextField("subnet", text: $subnet)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    Button("Scan") { net.startCameraScan(subnet: subnet) }.disabled(net.isScanning)
                }.padding(.horizontal)
                Text("creds: \(net.loadedCreds)").font(.caption2)
                if !playURL.isEmpty {
                    VLCView(box: vlc, url: playURL).frame(height: 220).cornerRadius(8).padding(.horizontal)
                } else if let img = net.lastSnapshot {
                    Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 160).cornerRadius(8)
                }
                if net.progress > 0 { ProgressView(value: net.progress).padding(.horizontal) }
                List(net.hits) { h in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(h.ip)").font(.system(.footnote, design: .monospaced))
                        Text("\(h.user):\(h.pass)").font(.caption2).foregroundColor(.secondary)
                        Button("Play RTSP") { playURL = h.rtspURL }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
            }.navigationTitle("DolphyCam")
        }
    }
}

struct PortsView: View {
    @ObservedObject var net: NetworkTool
    @Binding var ip: String
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("ip", text: $ip).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    Button("Scan") { net.startPortScan(ip: ip) }.disabled(net.isScanning)
                }.padding()
                if net.progress > 0 { ProgressView(value: net.progress).padding(.horizontal) }
                ScrollView { Text(net.logs).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding() }
            }.navigationTitle("Ports")
        }
    }
}

struct WifiView: View {
    @ObservedObject var net: NetworkTool
    @Binding var gateway: String
    var body: some View {
        NavigationView {
            VStack {
                Text("Router brute (HTTP Basic)").font(.caption).foregroundColor(.secondary)
                Text("passwords: \(net.loadedWifi)").font(.caption2)
                HStack {
                    TextField("gateway", text: $gateway).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    Button("Brute") { net.startWifiBrute(gateway: gateway) }.disabled(net.isScanning)
                }.padding()
                if net.progress > 0 { ProgressView(value: net.progress).padding(.horizontal) }
                ScrollView { Text(net.logs).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding() }
            }.navigationTitle("WiFi Brute")
        }
    }
}

struct NFCRadioView: View {
    @ObservedObject var nfc: NFCTool
    @ObservedObject var ble: BLEScan
    @ObservedObject var chat: Chat
    @State private var msg = ""
    var body: some View {
        NavigationView {
            List {
                Section("NFC") {
                    Text("available: \(nfc.available ? "yes" : "no")").font(.caption)
                    Button("Scan NFC Tag") { nfc.start() }
                    Text(nfc.logs).font(.system(.caption2, design: .monospaced))
                }
                Section("BLE Scan") {
                    if !ble.on { Text("Bluetooth off").foregroundColor(.red) }
                    ForEach(ble.devices.indices, id: \.self) { i in
                        HStack {
                            Text(ble.devices[i].0).font(.system(.footnote, design: .monospaced))
                            Spacer()
                            Text("\(ble.devices[i].1) dBm").font(.caption2)
                        }
                    }
                }
                Section("Chat (\(chat.peers) peers)") {
                    ForEach(chat.messages, id: \.self) { m in
                        Text(m).font(.system(.caption2, design: .monospaced))
                    }
                    HStack {
                        TextField("msg", text: $msg).textFieldStyle(.roundedBorder).font(.system(.caption, design: .monospaced))
                        Button("Send") { chat.send(msg); msg = "" }
                    }
                }
            }.navigationTitle("Radio")
        }
    }
}

struct IRView: View {
    @ObservedObject var ir: IRTool
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if ir.adapterConnected {
                    Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundColor(.green)
                    Text("Адаптер подключён").font(.headline)
                    Text(ir.adapterName).font(.caption).foregroundColor(.secondary)
                    Text(ir.logs).font(.system(.caption2, design: .monospaced)).padding()
                    Button("Send Test IR") { ir.sendCommand("0x20DF10EF") }
                        .buttonStyle(.borderedProminent)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                    Text("ИК-адаптер не найден").font(.headline)
                    Text("Подключите MFi-сертифицированный ИК-донгл к Lightning / USB-C порту. Обычные адаптеры с AliExpress не определяются iOS.")
                        .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding()
                    Text(ir.logs).font(.system(.caption2, design: .monospaced))
                }
            }.navigationTitle("IR").onAppear { ir.refresh() }
        }
    }
}
