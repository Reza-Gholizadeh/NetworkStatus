import SwiftUI

struct ContentView: View {
    @ObservedObject var model: StatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Network Status")
                .font(.headline)

            Divider()

            row(title: "Network", value: model.status.networkName, ok: nil)

            row(
                title: "Proxy",
                value: model.status.proxyEnabled ? model.status.proxyDetails.joined(separator: ", ") : "Off",
                ok: !model.status.proxyEnabled
            )

            row(
                title: "DNS",
                value: model.status.dnsSet ? model.status.dnsServers.joined(separator: ", ") : "Default (DHCP)",
                ok: nil
            )

            row(
                title: "VPN",
                value: model.status.vpnActive ? (model.status.vpnName ?? "Active") : "Off",
                ok: !model.status.vpnActive
            )

            Divider()

            HStack {
                Button("Refresh") {
                    model.refresh()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    @ViewBuilder
    private func row(title: String, value: String, ok: Bool?) -> some View {
        HStack(alignment: .top) {
            if let ok {
                Circle()
                    .fill(ok ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.isEmpty ? "-" : value)
                    .font(.system(size: 13, weight: .medium))
                    .textSelection(.enabled)
            }
        }
    }
}
