// WiFiViewController — scan list, tap to connect, status line.
// STATUS: real source, NOT compiled or run. Needs the SweetWiFi driver (see ../driver-contract.md).
// The app only controls Wi-Fi; once connected, all apps use the internet via the Ethernet data path.

import UIKit

final class WiFiViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let client = SweetWiFiClient()
    private let table = UITableView(frame: .zero, style: .plain)
    private let statusLabel = UILabel()
    private var networks: [SweetWiFiClient.Network] = []
    private var pollTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SweetWiFi"
        view.backgroundColor = .systemBackground

        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "net")
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.text = "—"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(rescan))

        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard client.open() else { statusLabel.text = "SweetWiFi driver not found"; return }
        rescan()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pollTimer?.invalidate(); pollTimer = nil
    }

    @objc private func rescan() {
        networks = client.scan().sorted { $0.rssi > $1.rssi }
        table.reloadData()
        refreshStatus()
    }

    private func refreshStatus() {
        let s = client.status()
        switch s.state {
        case .connected:   statusLabel.text = "connected · \(s.ip)"
        case .associating: statusLabel.text = "associating…"
        case .scanning:    statusLabel.text = "scanning…"
        case .failed:      statusLabel.text = "connection failed"
        case .down:        statusLabel.text = "off"
        }
    }

    // MARK: table

    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { networks.count }

    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = t.dequeueReusableCell(withIdentifier: "net", for: ip)
        let n = networks[ip.row]
        cell.textLabel?.text = n.ssid
        cell.detailTextLabel?.text = "\(n.rssi) dBm"
        cell.accessoryType = n.secured ? .detailButton : .none
        var cfg = cell.defaultContentConfiguration()
        cfg.text = n.ssid
        cfg.secondaryText = "\(n.rssi) dBm" + (n.secured ? " · secured" : "")
        cell.contentConfiguration = cfg
        return cell
    }

    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        t.deselectRow(at: ip, animated: true)
        let n = networks[ip.row]
        guard n.secured else { _ = client.connect(ssid: n.ssid, psk: ""); refreshStatus(); return }
        let a = UIAlertController(title: n.ssid, message: "Password", preferredStyle: .alert)
        a.addTextField { $0.isSecureTextEntry = true }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Join", style: .default) { [weak self] _ in
            let psk = a.textFields?.first?.text ?? ""
            _ = self?.client.connect(ssid: n.ssid, psk: psk)
            self?.refreshStatus()
        })
        present(a, animated: true)
    }
}
