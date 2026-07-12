import SwiftUI

struct ContentView: View {
    @ObservedObject var model: StatusModel
    @ObservedObject var pingModel: PingModel
    @ObservedObject var proxyModel: ProxyModel

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

            proxyControls

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

            VStack(alignment: .leading, spacing: 8) {
                Text("Ping")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Host or IP", text: $pingModel.address)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { pingModel.ping() }
                    Button(pingModel.isRunning ? "…" : "Ping") {
                        pingModel.ping()
                    }
                    .disabled(pingModel.isRunning || pingModel.address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !pingModel.summary.isEmpty {
                    row(title: "Result", value: pingModel.summary, ok: pingModel.ok)
                }
            }

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
        .frame(width: 300)
    }

    @ViewBuilder
    private var proxyControls: some View {
        DisclosureGroup("Change Proxy") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $proxyModel.type) {
                    ForEach(ProxyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    TextField("Host", text: $proxyModel.host)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $proxyModel.port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                }

                HStack(spacing: 8) {
                    Button(proxyModel.isBusy ? "…" : "Apply") {
                        proxyModel.apply()
                    }
                    .disabled(proxyModel.isBusy)

                    Button("Turn Off All") {
                        proxyModel.turnOffAll()
                    }
                    .disabled(proxyModel.isBusy)
                }

                if !proxyModel.message.isEmpty {
                    Text(proxyModel.message)
                        .font(.caption)
                        .foregroundStyle(proxyModel.ok == false ? Color.red : Color.secondary)
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
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
