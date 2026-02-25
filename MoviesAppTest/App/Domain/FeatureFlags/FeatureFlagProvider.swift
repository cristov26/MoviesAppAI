import Foundation

protocol FeatureFlagProviderProtocol: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func value<T>(for flag: FeatureFlag, type: T.Type) -> T? where T: Sendable
    func refresh() async
}
