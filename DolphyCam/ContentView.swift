import SwiftUI

struct ContentView: View {
    @StateObject var net = NetworkTool()
    @StateObject var player = SnapshotPlayer()
    @StateObject var nfc = NFCTool()
    @StateObject var ble = BLEScan()
    @StateObject var chat = Chat()
    @StateObject var ir = IRTool()
    @StateObject var settings = AppSettings()

    @State private var subnet = "192.168.1"
    @State private var targetIP = "192.168.1.1"
    @State private var gateway = "192.168.1.1"

    var body: some View {
        TabView {
            CamerasView(net: net, player: player, subnet: $subnet)
                .tabItem { Label("Камеры", systemImage: "camera") }
            PortsView(net: net, ip: $targetIP)
                .tabItem { Label("Порты", systemImage: "network") }
            WifiView(net: net, gateway: $gateway)
                .tabItem { Label("WiFi", systemImage: "wifi") }
            NFCRadioView(nfc: nfc, ble: ble, chat: chat)
                .tabItem { Label("Radio", systemImage: "antenna.radiowaves.left.and.right") }
            IRView(ir: ir)
                .tabItem { Label("IR", systemImage: "av.remote") }
            SettingsView(settings: settings, net: net)
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
    }
}

struct CamerasView: View {
    @ObservedObject var net: NetworkTool
    @ObservedObject var player: SnapshotPlayer
    @Binding var subnet: String

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                HStack {
                    TextField("subnet (192.168.1)", text: $subnet)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numbersAndPunctuation)
                        .font(.system(.body, design: .monospaced))
                    Button("Scan") { net.startCameraScan(subnet: subnet) }.disabled(net.isScanning)
                }.padding(.horizontal)

                if let img = player.image {
                    VStack {
                        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).cornerRadius(8)
                        Text(player.status).font(.caption2).foregroundColor(.secondary)
                        Button("Stop") { player.stop() }.controlSize(.small)
                    }.padding(.horizontal)
                }

                if net.progress > 0 { ProgressView(value: net.progress).padding(.horizontal) }

                List(net.hits) { h in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(h.ip):\(h.proto)").font(.system(.footnote, design: .monospaced))
                            Spacer()
                            Text("\(h.user):\(h.pass)").font(.caption2).foregroundColor(.green)
                        }
                        HStack(spacing: 6) {
                            Button("View") { player.start(ip: h.ip, user: h.user, pass: h.pass, rtsp: h.rtspURL) }
                                .buttonStyle(.borderedProminent).controlSize(.small)
                            Button("Copy") { UIPasteboard.general.string = h.rtspURL }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            }.navigationTitle("Cameras").onAppear { net.clear() }
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
            }.navigationTitle("Ports").onAppear { net.clear() }
        }
    }
}

struct WifiView: View {
    @ObservedObject var net: NetworkTool
    @Binding var gateway: String
    @State private var mode = "HTTP"
    var body: some View {
        NavigationView {
            VStack {
                Picker("Mode", selection: $mode) {
                    Text("HTTP Basic").tag("HTTP")
                    Text("WPA (needs jailbreak)").tag("WPA").disabled(true)
                }.pickerStyle(.segmented).padding()

                if mode == "HTTP" {
                    Text("Router brute (HTTP Basic)").font(.caption).foregroundColor(.secondary)
                    Text("passwords: \(net.loadedWifi)").font(.caption2)
                    HStack {
                        TextField("gateway", text: $gateway).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                        Button("Brute") { net.startWifiBrute(gateway: gateway) }.disabled(net.isScanning)
                    }.padding()
                    if net.progress > 0 { ProgressView(value: net.progress).padding(.horizontal) }
                    ScrollView { Text(net.logs).font(.system(.footnote, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding() }
                } else {
                    Text("WPA/WPA2 handshake brute is not supported by iOS hardware. Root or external adapter is required.").font(.caption).padding()
                }
            }.navigationTitle("WiFi Brute").onAppear { net.clear() }
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
    @State private var search = ""
    @State private var selectedCategory = "all"
    @State private var expanded: IRRemote?

    var filtered: [IRRemote] {
        var list = ir.db.remotes
        if selectedCategory != "all" { list = list.filter { $0.category == selectedCategory } }
        if !search.isEmpty {
            list = list.filter { $0.name.lowercased().contains(search.lowercased()) || $0.brand.lowercased().contains(search.lowercased()) }
        }
        return Array(list.prefix(500))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    TextField("search (Samsung, Sony...)", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Picker("cat", selection: $selectedCategory) {
                        Text("all").tag("all")
                        ForEach(ir.db.categories.prefix(20), id: \.self) { c in Text(c).tag(c) }
                    }.pickerStyle(.menu)
                }.padding(.horizontal, 8)

                if !ir.adapterConnected {
                    Text("⚠ No IR adapter — database browsable, transmission needs MFi dongle")
                        .font(.caption2).foregroundColor(.orange).padding(6)
                } else {
                    Text("✓ Adapter: \(ir.adapterName)").font(.caption2).foregroundColor(.green).padding(6)
                }

                Text("\(ir.db.remotes.count) remotes · \(ir.db.brands.count) brands · \(ir.db.categories.count) categories")
                    .font(.caption2).foregroundColor(.secondary)

                List(filtered) { r in
                    Button { expanded = r } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.system(.footnote))
                            Text("\(r.category) / \(r.brand)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }.navigationTitle("IR Database")
            .sheet(item: $expanded) { r in
                IRCommandsView(ir: ir, remote: r)
            }
        }
    }
}

struct IRCommandsView: View {
    @ObservedObject var ir: IRTool
    let remote: IRRemote
    @State private var cmds: [String] = []

    var body: some View {
        NavigationView {
            List(cmds, id: \.self) { c in
                Button(c) { ir.sendCommand(c) }
            }
            .navigationTitle(remote.name)
            .onAppear { cmds = ir.db.commands(for: remote) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { }
                }
            }
        }
    }
}

// --- Настройки ---
final class AppSettings: ObservableObject {
    @AppStorage("theme") var theme = "dark"
    @AppStorage("fontScale") var fontScale = 1.0
    @AppStorage("confirmIr") var confirmIr = true
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var net: NetworkTool

    var body: some View {
        NavigationView {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $settings.theme) {
                        Text("Тёмная").tag("dark")
                        Text("Светлая").tag("light")
                    }
                    Slider(value: $settings.fontScale, in: 0.8...1.5) {
                        Text("Размер шрифта")
                    }
                }
                Section("Безопасность") {
                    Toggle("Подтверждать IR-команды", isOn: $settings.confirmIr)
                }
                Section("Словари") {
                    Text("Паролей для камер: \(net.loadedCreds)").font(.caption)
                    Text("Паролей для WiFi: \(net.loadedWifi)").font(.caption)
                    Button("Обновить словари") {
                        net.reloadWordlists()
                    }
                }
                Section("О приложении") {
                    Text("DolphyCam iOS — порт Dolphy-App").font(.caption)
                    Text("Версия 0.9").font(.caption2).foregroundColor(.secondary)
                }
            }.navigationTitle("Настройки")
        }
    }
}
