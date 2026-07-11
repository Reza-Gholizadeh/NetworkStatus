import Foundation
import Combine

final class StatusModel: ObservableObject {
    @Published var status: NetworkStatus = .empty

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = NetworkInspector.fetch()
            DispatchQueue.main.async {
                self?.status = result
            }
        }
    }
}
