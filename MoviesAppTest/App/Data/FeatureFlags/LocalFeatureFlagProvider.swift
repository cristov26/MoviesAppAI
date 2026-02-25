import Foundation

final class LocalFeatureFlagProvider: FeatureFlagProviderProtocol {
    private var overrides: [FeatureFlag: Bool]

    init(overrides: [FeatureFlag: Bool] = [:]) {
        self.overrides = overrides
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        overrides[flag] ?? flag.defaultValue
    }

    func value<T>(for flag: FeatureFlag, type: T.Type) -> T? where T: Sendable {
        overrides[flag] as? T
    }

    func refresh() async {
        // No-op for local provider.
    }
}
