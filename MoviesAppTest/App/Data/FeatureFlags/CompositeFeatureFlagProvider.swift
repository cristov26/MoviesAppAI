import Foundation

final class CompositeFeatureFlagProvider: FeatureFlagProviderProtocol {
    private let remote: FeatureFlagProviderProtocol?
    private let local: FeatureFlagProviderProtocol

    init(remote: FeatureFlagProviderProtocol?, local: FeatureFlagProviderProtocol) {
        self.remote = remote
        self.local = local
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if let remote, let remoteValue = remote.value(for: flag, type: Bool.self) {
            return remoteValue
        }
        return local.isEnabled(flag)
    }

    func value<T>(for flag: FeatureFlag, type: T.Type) -> T? where T: Sendable {
        remote?.value(for: flag, type: type) ?? local.value(for: flag, type: type)
    }

    func refresh() async {
        await remote?.refresh()
    }
}
