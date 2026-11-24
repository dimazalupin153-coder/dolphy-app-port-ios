import SwiftUI
import MobileVLCKit
import UIKit

final class VLCBox: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let player = VLCMediaPlayer()
    @Published var playing = false
    @Published var status = ""

    override init() {
        super.init()
        player.delegate = self
    }

    func attach(url: String, to view: UIView) {
        guard let u = URL(string: url) else { status = "bad url"; return }
        player.drawable = view
        player.media = VLCMedia(url: u)
        player.play()
        playing = true
        status = "playing"
    }

    func stop() {
        player.stop()
        playing = false
        status = "stopped"
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async {
            switch self.player.state {
            case .playing: self.status = "playing"
            case .error: self.status = "error"
            case .ended: self.status = "ended"
            case .buffering: self.status = "buffering"
            default: break
            }
        }
    }
}

struct VLCView: UIViewRepresentable {
    let box: VLCBox
    let url: String

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        box.attach(url: url, to: v)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
