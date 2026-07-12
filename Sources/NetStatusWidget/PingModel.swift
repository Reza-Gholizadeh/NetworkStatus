import Foundation
import Combine

final class PingModel: ObservableObject {
    @Published var address: String = "8.8.8.8"
    @Published var summary: String = ""
    @Published var ok: Bool?
    @Published var isRunning = false

    func ping() {
        let target = address.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, !isRunning else { return }

        isRunning = true
        summary = "Pinging…"
        ok = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = Shell.runMerged("/sbin/ping", ["-c", "4", "-t", "6", target])
            let result = Self.summarize(output)
            DispatchQueue.main.async {
                self?.summary = result.summary
                self?.ok = result.success
                self?.isRunning = false
            }
        }
    }

    private static func summarize(_ output: String) -> (summary: String, success: Bool) {
        let lines = output.split(separator: "\n").map(String.init)

        guard let lossLine = lines.first(where: { $0.contains("packet loss") }) else {
            return (lines.last ?? "Ping failed", false)
        }

        // e.g. "4 packets transmitted, 4 packets received, 0.0% packet loss"
        let receivedPart = lossLine.components(separatedBy: ", ").dropFirst().first ?? ""
        let lossPercent = lossLine.components(separatedBy: "%").first?
            .split(separator: " ").last.map(String.init) ?? "?"

        if lossPercent == "100.0" {
            return ("Unreachable (100% loss)", false)
        }

        // e.g. "round-trip min/avg/max/stddev = 72.888/95.536/128.990/23.322 ms"
        if let statsLine = lines.first(where: { $0.contains("round-trip") }),
           let eqRange = statsLine.range(of: "= "),
           let avg = statsLine[eqRange.upperBound...].split(separator: "/").dropFirst().first {
            return ("\(receivedPart) · avg \(avg)ms", true)
        }

        return ("\(receivedPart), \(lossPercent)% loss", true)
    }
}
