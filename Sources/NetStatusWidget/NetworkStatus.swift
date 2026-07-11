import Foundation
import AppKit

struct NetworkStatus {
    var proxyEnabled: Bool
    var proxyDetails: [String]
    var dnsSet: Bool
    var dnsServers: [String]
    var vpnActive: Bool
    var vpnName: String?
    var networkName: String
    var interface: String

    static let empty = NetworkStatus(
        proxyEnabled: false, proxyDetails: [],
        dnsSet: false, dnsServers: [],
        vpnActive: false, vpnName: nil,
        networkName: "Unknown", interface: "-"
    )
}

enum NetworkInspector {

    // MARK: - Primary service/interface resolution

    private static func primaryInterface() -> String? {
        let output = Shell.run("/sbin/route", ["get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed
                    .replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Maps a BSD device name (en0, en1, ...) to its (Hardware Port / networksetup service name, isWiFi)
    private static func hardwarePortInfo(for device: String) -> (serviceName: String, isWiFi: Bool)? {
        let output = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks {
            guard block.contains("Device: \(device)") else { continue }
            for line in block.split(separator: "\n") {
                if line.hasPrefix("Hardware Port:") {
                    let name = line
                        .replacingOccurrences(of: "Hardware Port:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    return (name, name.localizedCaseInsensitiveContains("wi-fi"))
                }
            }
        }
        return nil
    }

    // MARK: - Proxy

    private static func proxyStatus(service: String) -> (enabled: Bool, details: [String]) {
        var details: [String] = []
        var enabled = false

        let checks: [(String, String)] = [
            ("-getwebproxy", "HTTP"),
            ("-getsecurewebproxy", "HTTPS"),
            ("-getsocksfirewallproxy", "SOCKS"),
        ]

        for (flag, label) in checks {
            let output = Shell.run("/usr/sbin/networksetup", [flag, service])
            if output.contains("Enabled: Yes") {
                enabled = true
                if let server = output
                    .split(separator: "\n")
                    .first(where: { $0.hasPrefix("Server:") })?
                    .replacingOccurrences(of: "Server:", with: "")
                    .trimmingCharacters(in: .whitespaces), !server.isEmpty {
                    details.append("\(label): \(server)")
                } else {
                    details.append(label)
                }
            }
        }

        let pac = Shell.run("/usr/sbin/networksetup", ["-getautoproxyurl", service])
        if pac.contains("Enabled: Yes") {
            enabled = true
            details.append("Auto Proxy (PAC)")
        }

        return (enabled, details)
    }

    // MARK: - DNS

    private static func dnsStatus(service: String) -> (isSet: Bool, servers: [String]) {
        let output = Shell.run("/usr/sbin/networksetup", ["-getdnsservers", service])
        if output.lowercased().contains("there aren't any dns servers set") || output.isEmpty {
            return (false, [])
        }
        let servers = output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        return (true, servers)
    }

    // MARK: - VPN

    private static let knownVPNApps: [(bundleSubstring: String, displayName: String)] = [
        ("tailscale", "Tailscale"),
        ("nordvpn", "NordVPN"),
        ("expressvpn", "ExpressVPN"),
        ("protonvpn", "ProtonVPN"),
        ("surfshark", "Surfshark"),
        ("wireguard", "WireGuard"),
        ("openvpn", "OpenVPN"),
        ("cloudflarewarp", "Cloudflare WARP"),
        ("warp", "Cloudflare WARP"),
        ("forticlient", "FortiClient"),
        ("globalprotect", "GlobalProtect"),
        ("anyconnect", "Cisco AnyConnect"),
        ("cisco", "Cisco VPN"),
        ("mullvad", "Mullvad"),
        ("hidemyass", "HMA VPN"),
        ("privateinternetaccess", "Private Internet Access"),
    ]

    private static func systemVPNStatus() -> (isOn: Bool, name: String?) {
        let output = Shell.run("/usr/sbin/scutil", ["--nc", "list"])
        for line in output.split(separator: "\n") {
            guard line.contains("(Connected)") else { continue }
            if let start = line.firstIndex(of: "\""),
               let end = line.lastIndex(of: "\""), start != end {
                let name = String(line[line.index(after: start)..<end])
                return (true, name)
            }
            return (true, nil)
        }
        return (false, nil)
    }

    /// Detects VPN-like tunnel interfaces (utunN with an assigned IP) created by third-party
    /// VPN apps that don't register as a "system" VPN service in scutil --nc.
    private static func tunnelInterfaceActive() -> Bool {
        let output = Shell.run("/sbin/ifconfig", [])
        var currentIsUtun = false
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") {
                currentIsUtun = line.hasPrefix("utun")
                continue
            }
            if currentIsUtun && line.trimmingCharacters(in: .whitespaces).hasPrefix("inet ") {
                return true
            }
        }
        return false
    }

    private static func runningVPNAppName() -> String? {
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier?.lowercased() else { continue }
            for (substring, displayName) in knownVPNApps where bundleId.contains(substring) {
                return displayName
            }
        }
        return nil
    }

    private static func vpnStatus() -> (isOn: Bool, name: String?) {
        let system = systemVPNStatus()
        if system.isOn {
            return system
        }
        if tunnelInterfaceActive() {
            return (true, runningVPNAppName() ?? "Unknown VPN")
        }
        return (false, nil)
    }

    // MARK: - Network / SSID name

    private static func wifiNetworkName(device: String) -> String {
        let output = Shell.run("/usr/sbin/networksetup", ["-getairportnetwork", device])
        if let range = output.range(of: "Current Wi-Fi Network: ") {
            return String(output[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return "Not connected"
    }

    // MARK: - Public entry point

    static func fetch() -> NetworkStatus {
        guard let device = primaryInterface() else {
            return .empty
        }
        guard let port = hardwarePortInfo(for: device) else {
            return NetworkStatus(
                proxyEnabled: false, proxyDetails: [],
                dnsSet: false, dnsServers: [],
                vpnActive: false, vpnName: nil,
                networkName: device, interface: device
            )
        }

        let proxy = proxyStatus(service: port.serviceName)
        let dns = dnsStatus(service: port.serviceName)
        let vpn = vpnStatus()
        let networkName = port.isWiFi ? wifiNetworkName(device: device) : port.serviceName

        return NetworkStatus(
            proxyEnabled: proxy.enabled,
            proxyDetails: proxy.details,
            dnsSet: dns.isSet,
            dnsServers: dns.servers,
            vpnActive: vpn.isOn,
            vpnName: vpn.name,
            networkName: networkName,
            interface: device
        )
    }
}
