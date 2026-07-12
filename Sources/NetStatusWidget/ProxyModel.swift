import Foundation
import Combine

enum ProxyType: String, CaseIterable, Identifiable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks = "SOCKS"

    var id: String { rawValue }

    fileprivate var setFlag: String {
        switch self {
        case .http: return "-setwebproxy"
        case .https: return "-setsecurewebproxy"
        case .socks: return "-setsocksfirewallproxy"
        }
    }

    fileprivate var stateFlag: String {
        switch self {
        case .http: return "-setwebproxystate"
        case .https: return "-setsecurewebproxystate"
        case .socks: return "-setsocksfirewallproxystate"
        }
    }
}

/// Writes proxy configuration via `networksetup`. Unlike the rest of the app (read-only),
/// this actually changes the user's live network settings when `apply()`/`turnOffAll()` run.
final class ProxyModel: ObservableObject {
    @Published var type: ProxyType = .http
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var isBusy = false
    @Published var message: String = ""
    @Published var ok: Bool?

    private let serviceName: () -> String?
    private let onChange: () -> Void

    init(serviceName: @escaping () -> String?, onChange: @escaping () -> Void) {
        self.serviceName = serviceName
        self.onChange = onChange
    }

    func apply() {
        guard !isBusy else { return }
        guard let service = serviceName() else {
            message = "No active network"
            ok = false
            return
        }
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else {
            message = "Enter a host"
            ok = false
            return
        }
        guard let portNumber = Int(port.trimmingCharacters(in: .whitespaces)),
              (1...65535).contains(portNumber) else {
            message = "Enter a valid port (1-65535)"
            ok = false
            return
        }

        let type = self.type
        isBusy = true
        message = "Applying…"
        ok = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Shell.run("/usr/sbin/networksetup", [type.setFlag, service, trimmedHost, String(portNumber)])
            DispatchQueue.main.async {
                self?.message = "\(type.rawValue) proxy set to \(trimmedHost):\(portNumber)"
                self?.ok = true
                self?.isBusy = false
                self?.onChange()
            }
        }
    }

    func turnOffAll() {
        guard !isBusy else { return }
        guard let service = serviceName() else {
            message = "No active network"
            ok = false
            return
        }

        isBusy = true
        message = "Turning off…"
        ok = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for proxyType in ProxyType.allCases {
                Shell.run("/usr/sbin/networksetup", [proxyType.stateFlag, service, "off"])
            }
            DispatchQueue.main.async {
                self?.message = "Proxy turned off"
                self?.ok = true
                self?.isBusy = false
                self?.onChange()
            }
        }
    }
}
