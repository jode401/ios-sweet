// CameraViewController — live preview + shutter for SweetCam.
// STATUS: real source, NOT compiled or run. Needs the SweetCam driver (see ../driver-contract.md).
// Rendering is CPU-side (no GPU required): the BGRA shared buffer is wrapped as a CGImage.

import UIKit

final class CameraViewController: UIViewController {
    private let client = SweetCamClient()
    private let preview = UIImageView()
    private let shutter = UIButton(type: .system)
    private let status = UILabel()
    private var link: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        preview.contentMode = .scaleAspectFit
        preview.frame = view.bounds
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(preview)

        shutter.setTitle("\u{25CF}", for: .normal)            // ●
        shutter.titleLabel?.font = .systemFont(ofSize: 64)
        shutter.tintColor = .white
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.addTarget(self, action: #selector(capture), for: .touchUpInside)
        view.addSubview(shutter)

        status.textColor = .white
        status.textAlignment = .center
        status.font = .systemFont(ofSize: 14)
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)

        NSLayoutConstraint.activate([
            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard client.open() else { status.text = "SweetCam driver not found"; return }
        guard client.start(width: 1280, height: 720) else { status.text = "camera start failed"; return }
        status.text = "live"
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.preferredFramesPerSecond = 15
        l.add(to: .main, forMode: .default)
        link = l
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        link?.invalidate(); link = nil
        client.stop()
    }

    @objc private func tick() {
        guard let f = client.latestFrame(), let img = image(from: f) else { return }
        preview.image = img
    }

    @objc private func capture() {
        guard let f = client.latestFrame(), let img = image(from: f) else { status.text = "no frame"; return }
        guard let jpeg = img.jpegData(compressionQuality: 0.9) else { status.text = "encode failed"; return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sweetcam-\(Int(Date().timeIntervalSince1970)).jpg")
        do {
            try jpeg.write(to: url)
            status.text = "saved \(url.lastPathComponent)"
        } catch {
            status.text = "save failed: \(error.localizedDescription)"
        }
    }

    /// Wrap the BGRA8888 shared buffer as a UIImage on the CPU (no GPU needed).
    private func image(from f: SweetCamClient.Frame) -> UIImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        let info: CGBitmapInfo = [.byteOrder32Little,
                                  CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)]
        guard let provider = CGDataProvider(dataInfo: nil, data: f.base,
                                            size: f.bytesPerRow * f.height,
                                            releaseData: { _, _, _ in }) else { return nil }
        guard let cg = CGImage(width: f.width, height: f.height,
                               bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: f.bytesPerRow,
                               space: space, bitmapInfo: info, provider: provider,
                               decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
