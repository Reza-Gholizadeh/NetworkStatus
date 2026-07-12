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

    /// Finds the physical (Wi-Fi/Ethernet) hardware port that currently holds an IP address.
    ///
    /// Deliberately does NOT use `route get default`: once a VPN connects, the default route
    /// points at its `utunN` tunnel interface, which isn't a "hardware port" networksetup knows
    /// about. Scanning hardware ports directly keeps the reported network/proxy/DNS info tied to
    /// the real physical connection regardless of whether a VPN has taken over routing.
    private static func activePhysicalPort() -> (device: String, serviceName: String, isWiFi: Bool)? {
        let output = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.split(separator: "\n")
            guard let deviceLine = lines.first(where: { $0.hasPrefix("Device:") }),
                  let portLine = lines.first(where: { $0.hasPrefix("Hardware Port:") })
            else { continue }

            let device = deviceLine
                .replacingOccurrences(of: "Device:", with: "")
                .trimmingCharacters(in: .whitespaces)
            let portName = portLine
                .replacingOccurrences(of: "Hardware Port:", with: "")
                .trimmingCharacters(in: .whitespaces)

            let ip = Shell.run("/usr/sbin/ipconfig", ["getifaddr", device])
            guard !ip.isEmpty else { continue }

            return (device, portName, portName.localizedCaseInsensitiveContains("wi-fi"))
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
        // Computed unconditionally: a VPN can be active regardless of whether we can resolve
        // the underlying physical network below (see activePhysicalPort's doc comment).
        let vpn = vpnStatus()

        guard let port = activePhysicalPort() else {
            return NetworkStatus(
                proxyEnabled: false, proxyDetails: [],
                dnsSet: false, dnsServers: [],
                vpnActive: vpn.isOn, vpnName: vpn.name,
                networkName: "Not connected", interface: "-"
            )
        }

        let proxy = proxyStatus(service: port.serviceName)
        let dns = dnsStatus(service: port.serviceName)
        let networkName = port.isWiFi ? wifiNetworkName(device: port.device) : port.serviceName

        return NetworkStatus(
            proxyEnabled: proxy.enabled,
            proxyDetails: proxy.details,
            dnsSet: dns.isSet,
            dnsServers: dns.servers,
            vpnActive: vpn.isOn,
            vpnName: vpn.name,
            networkName: networkName,
            interface: port.device
        )
    }
}
