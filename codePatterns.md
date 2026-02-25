# CodePatterns.md — iOS Code Examples & Implementations

> This file contains the full code implementations referenced by [Agents.md](Agents.md).
> Read Agents.md first for rules and conventions. This file is the "how".

---

## Table of Contents

1. [Domain Layer — Entities, Repositories, Use Cases](#domain-layer)
2. [Data Layer — DTOs and Mappers](#data-layer--dtos-and-mappers)
3. [MVVM Pattern](#mvvm-pattern)
4. [Coordinator Pattern](#coordinator-pattern)
5. [Networking — Async/Await + Generics](#networking--asyncawait--generics)
6. [Pagination](#pagination)
7. [SwiftData — Persistence](#swiftdata--persistence)
8. [Dependency Injection](#dependency-injection)
9. [Error Handling Strategy](#error-handling-strategy)
10. [Testing — Swift Testing Framework](#testing--swift-testing-framework)
11. [Accessibility](#accessibility)
12. [Loading States & Shimmer](#loading-states--shimmer)
13. [Environment-Based Configuration](#environment-based-configuration)
14. [Feature Flags](#feature-flags)
15. [Image Loading & Caching (Native)](#image-loading--caching-native)

---

## Domain Layer

### Entity

```swift
// Domain/Entities/User.swift
struct User: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let email: String
}

extension User {
    /// Used to render the shimmer skeleton layout before real data arrives.
    static let placeholder = User(
        id: UUID(),
        name: "Placeholder Name",
        email: "placeholder@example.com"
    )
}
```

### Repository Protocol

```swift
// Domain/Repositories/UserRepository.swift
protocol UserRepository: Sendable {
    func fetchUser(id: UUID) async throws -> User
    func fetchUsers(cursor: String?, limit: Int) async throws -> PaginatedResult<User>
}

/// Domain-level pagination wrapper — no DTOs, no data-layer types.
struct PaginatedResult<T: Sendable>: Sendable {
    let items: [T]
    let nextCursor: String?
    let hasMore: Bool
}
```

### Use Case

```swift
// Domain/UseCases/FetchUserProfileUseCase.swift
protocol FetchUserProfileUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws -> User
}

final class FetchUserProfileUseCase: FetchUserProfileUseCaseProtocol {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> User {
        try await repository.fetchUser(id: id)
    }
}
```

---

## Data Layer — DTOs and Mappers

### DTO

```swift
// Data/Network/DTOs/UserDTO.swift
struct UserDTO: Decodable {
    let id: String
    let fullName: String
    let emailAddress: String
}
```

### DTO Mapper

```swift
// Data/Network/Mappers/UserDTOMapper.swift
enum UserDTOMapper {
    static func toDomain(_ dto: UserDTO) -> User {
        User(
            id: UUID(uuidString: dto.id) ?? UUID(),
            name: dto.fullName,
            email: dto.emailAddress
        )
    }
}
```

> **Why mappers exist:** API field names (`fullName`, `emailAddress`) often differ from domain property names (`name`, `email`). DTO types may also use `String` IDs where the domain uses `UUID`. Mappers isolate these transformations so that API contract changes never ripple into the Domain or Presentation layers.

---

## MVVM Pattern

### ViewModel

```swift
// Presentation/Features/UserProfile/ViewModel/UserProfileViewModel.swift
import Observation

@MainActor
@Observable
final class UserProfileViewModel {

    enum State: Equatable {
        case loading
        case loaded(User)
        case error(String)
    }

    private(set) var state: State = .loading

    /// Use for shimmer binding: `.shimmering(active: viewModel.isLoading)`
    var isLoading: Bool { state == .loading }

    /// Always returns a displayable user — placeholder during loading, real data when loaded.
    var displayUser: User {
        switch state {
        case .loaded(let user): return user
        default: return .placeholder
        }
    }

    private let fetchUserProfile: FetchUserProfileUseCaseProtocol
    private let userId: UUID

    init(userId: UUID, fetchUserProfile: FetchUserProfileUseCaseProtocol) {
        self.userId = userId
        self.fetchUserProfile = fetchUserProfile
    }

    func onAppear() async {
        state = .loading
        do {
            let user = try await fetchUserProfile.execute(id: userId)
            state = .loaded(user)
        } catch let error as DomainError {
            state = .error(error.localizedDescription)
        } catch {
            state = .error(DomainError.unknown(error.localizedDescription).localizedDescription)
        }
    }
}
```

### View

```swift
struct UserProfileView: View {
    @State var viewModel: UserProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch viewModel.state {
            case .loading, .loaded:
                UserProfileContent(user: viewModel.displayUser)
                    .shimmering(active: viewModel.isLoading)
            case .error(let message):
                ErrorView(message: message, onRetry: {
                    Task { await viewModel.onAppear() }
                })
            }
        }
        .task { await viewModel.onAppear() }
    }
}
```

---

## Coordinator Pattern

### AppCoordinator

```swift
// Presentation/Coordinators/AppCoordinator.swift
@MainActor
@Observable
final class AppCoordinator {

    enum Route: Hashable, Identifiable {
        case userList
        case userDetail(UUID)
        case settings

        var id: Self { self }
    }

    var path = NavigationPath()
    var sheet: Route?

    private let diContainer: AppDIContainer

    init(diContainer: AppDIContainer) {
        self.diContainer = diContainer
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func present(_ route: Route) {
        sheet = route
    }

    @ViewBuilder
    func view(for route: Route) -> some View {
        switch route {
        case .userList:
            makeUserListView()
        case .userDetail(let id):
            makeUserDetailView(userId: id)
        case .settings:
            makeSettingsView()
        }
    }

    // MARK: - Factory Methods

    private func makeUserListView() -> some View {
        let vm = UserListViewModel(
            fetchUsers: diContainer.makeFetchUsersUseCase(),
            onSelectUser: { [weak self] id in self?.push(.userDetail(id)) }
        )
        return UserListView(viewModel: vm)
    }

    private func makeUserDetailView(userId: UUID) -> some View {
        let vm = UserProfileViewModel(
            userId: userId,
            fetchUserProfile: diContainer.makeFetchUserProfileUseCase()
        )
        return UserProfileView(viewModel: vm)
    }
}
```

### RootView

```swift
struct RootView: View {
    @State var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.view(for: .userList)
                .navigationDestination(for: AppCoordinator.Route.self) { route in
                    coordinator.view(for: route)
                }
        }
        .sheet(item: $coordinator.sheet) { route in
            coordinator.view(for: route)
        }
    }
}
```

---

## Networking — Async/Await + Generics

### APIClient

```swift
// Data/Network/APIClient.swift
protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
}

final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let interceptors: [RequestInterceptor]

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = .apiDecoder,
        interceptors: [RequestInterceptor] = []
    ) {
        self.session = session
        self.decoder = decoder
        self.interceptors = interceptors
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await request(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func request(_ endpoint: Endpoint) async throws -> Data {
        var urlRequest = try endpoint.asURLRequest()

        for interceptor in interceptors {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
```

### Endpoint

```swift
// Data/Network/Endpoints/Endpoint.swift
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    let body: Encodable?
    let baseURL: URL

    func asURLRequest() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
```

### NetworkError

```swift
enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case noConnection
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response."
        case .httpError(let code, _): "Server error (\(code))."
        case .decodingFailed: "Failed to process server response."
        case .noConnection: "No internet connection."
        case .timeout: "Request timed out."
        }
    }
}
```

### Request Interceptor

```swift
protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

struct AuthInterceptor: RequestInterceptor {
    let tokenProvider: TokenProviderProtocol

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let token = try await tokenProvider.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

---

## Pagination

### Paginated Response (Data Layer)

```swift
// Data/Network/DTOs/PaginatedResponse.swift
struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let nextCursor: String?
    let totalCount: Int?
}
```

### ViewModel with Pagination

```swift
@MainActor
@Observable
final class UserListViewModel {

    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var users: [User] = []
    private(set) var isLoadingMore = false

    var isLoading: Bool { state == .loading }

    /// Return placeholder rows during initial load for shimmer.
    var displayUsers: [User] {
        if case .loading = state { return (0..<8).map { _ in .placeholder } }
        return users
    }

    private var nextCursor: String?
    private var hasMore = true
    private let pageSize = 20
    private let fetchUsers: FetchUsersUseCaseProtocol

    init(fetchUsers: FetchUsersUseCaseProtocol) {
        self.fetchUsers = fetchUsers
    }

    func onAppear() async {
        await loadFirstPage()
    }

    func loadMoreIfNeeded(currentItem: User) async {
        guard let lastItem = users.last,
              lastItem.id == currentItem.id,
              hasMore,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await fetchUsers.execute(cursor: nextCursor, limit: pageSize)
            users.append(contentsOf: result.items)
            nextCursor = result.nextCursor
            hasMore = result.hasMore
        } catch {
            // Silently fail on "load more" — user can scroll again to retry.
        }
    }

    func refresh() async {
        await loadFirstPage()
    }

    // MARK: - Private

    private func loadFirstPage() async {
        state = .loading
        nextCursor = nil
        do {
            let result = try await fetchUsers.execute(cursor: nil, limit: pageSize)
            users = result.items
            nextCursor = result.nextCursor
            hasMore = result.hasMore
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

### View with Infinite Scroll

```swift
struct UserListView: View {
    @State var viewModel: UserListViewModel

    var body: some View {
        List {
            ForEach(viewModel.displayUsers) { user in
                UserRow(user: user)
                    .shimmering(active: viewModel.isLoading)
                    .task { await viewModel.loadMoreIfNeeded(currentItem: user) }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.onAppear() }
    }
}
```

---

## SwiftData — Persistence

### SwiftData Model

```swift
// Data/Persistence/Models/UserModel.swift
import SwiftData

@Model
final class UserModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var lastUpdated: Date

    init(id: UUID, name: String, email: String, lastUpdated: Date = .now) {
        self.id = id
        self.name = name
        self.email = email
        self.lastUpdated = lastUpdated
    }
}
```

### SwiftData Model Mapper

```swift
// Data/Persistence/Mappers/UserModelMapper.swift
enum UserModelMapper {
    static func toDomain(_ model: UserModel) -> User {
        User(id: model.id, name: model.name, email: model.email)
    }

    static func toModel(_ entity: User) -> UserModel {
        UserModel(id: entity.id, name: entity.name, email: entity.email)
    }
}
```

### SwiftDataStore

```swift
// Data/Persistence/SwiftDataStore.swift
@MainActor
final class SwiftDataStore {
    private let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        try context.fetch(descriptor)
    }

    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    func save() throws {
        try context.save()
    }
}
```

> **Repository implementation:** See [Error Handling Strategy](#error-handling-strategy) for the full `DefaultUserRepository` which demonstrates network-first fetching with SwiftData cache fallback and proper error mapping.

---

## Dependency Injection

### AppDIContainer

```swift
// Application/DI/AppDIContainer.swift
@MainActor
final class AppDIContainer {
    private let modelContainer: ModelContainer
    private lazy var store = SwiftDataStore(container: modelContainer)
    private lazy var apiClient: APIClientProtocol = APIClient(
        interceptors: [AuthInterceptor(tokenProvider: tokenProvider)]
    )
    private lazy var tokenProvider: TokenProviderProtocol = KeychainTokenProvider()

    init() {
        self.modelContainer = try! ModelContainer(for: UserModel.self)
    }

    // MARK: - Repositories
    func makeUserRepository() -> UserRepository {
        DefaultUserRepository(apiClient: apiClient, store: store)
    }

    // MARK: - Use Cases
    func makeFetchUserProfileUseCase() -> FetchUserProfileUseCaseProtocol {
        FetchUserProfileUseCase(repository: makeUserRepository())
    }

    func makeFetchUsersUseCase() -> FetchUsersUseCaseProtocol {
        FetchUsersUseCase(repository: makeUserRepository())
    }
}
```

### SwiftUI Previews

```swift
// Presentation/Features/UserProfile/View/UserProfileView.swift
#Preview("Loaded") {
    let vm = UserProfileViewModel(
        userId: UUID(),
        fetchUserProfile: MockFetchUserProfileUseCase(
            result: .success(User(id: UUID(), name: "Alice", email: "alice@example.com"))
        )
    )
    UserProfileView(viewModel: vm)
}

#Preview("Loading") {
    let vm = UserProfileViewModel(
        userId: UUID(),
        fetchUserProfile: MockFetchUserProfileUseCase(delay: .infinity)
    )
    UserProfileView(viewModel: vm)
}

#Preview("Error") {
    let vm = UserProfileViewModel(
        userId: UUID(),
        fetchUserProfile: MockFetchUserProfileUseCase(
            result: .failure(DomainError.noConnectivity)
        )
    )
    UserProfileView(viewModel: vm)
}
```

---

## Error Handling Strategy

### Domain Error

```swift
// Domain/Errors/DomainError.swift
enum DomainError: LocalizedError, Equatable {
    case notFound
    case unauthorized
    case serverError
    case noConnectivity
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notFound:            "The requested resource was not found."
        case .unauthorized:        "Your session has expired. Please sign in again."
        case .serverError:         "Something went wrong on our end. Please try again."
        case .noConnectivity:      "No internet connection. Please check your network."
        case .unknown(let detail): detail
        }
    }
}
```

### NetworkError → DomainError Mapping

```swift
// Data/Network/NetworkError+Domain.swift
extension NetworkError {
    func toDomainError() -> DomainError {
        switch self {
        case .noConnection, .timeout:
            return .noConnectivity
        case .httpError(let statusCode, _):
            switch statusCode {
            case 401, 403: return .unauthorized
            case 404:      return .notFound
            default:       return .serverError
            }
        case .invalidResponse, .decodingFailed:
            return .serverError
        }
    }
}
```

### Repository Implementation with Error Mapping

```swift
// Data/Repositories/DefaultUserRepository.swift
final class DefaultUserRepository: UserRepository {
    private let apiClient: APIClientProtocol
    private let store: SwiftDataStore

    init(apiClient: APIClientProtocol, store: SwiftDataStore) {
        self.apiClient = apiClient
        self.store = store
    }

    func fetchUser(id: UUID) async throws -> User {
        do {
            let dto: UserDTO = try await apiClient.request(UserEndpoints.user(id: id))
            let entity = UserDTOMapper.toDomain(dto)
            await cacheUser(entity)
            return entity
        } catch let error as NetworkError {
            if case .noConnection = error, let cached = try? await cachedUser(id: id) {
                return cached
            }
            throw error.toDomainError()
        } catch {
            throw DomainError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Cache helpers

    private func cacheUser(_ user: User) async {
        await MainActor.run {
            store.insert(UserModelMapper.toModel(user))
            try? store.save()
        }
    }

    private func cachedUser(id: UUID) async throws -> User? {
        let descriptor = FetchDescriptor<UserModel>(predicate: #Predicate { $0.id == id })
        let cached = try await MainActor.run { try store.fetch(descriptor) }
        return cached.first.map(UserModelMapper.toDomain)
    }
}
```

### ViewModel Error Handling

```swift
func onAppear() async {
    state = .loading
    do {
        let user = try await fetchUserProfile.execute(id: userId)
        state = .loaded(user)
    } catch let error as DomainError {
        state = .error(error.localizedDescription)
    } catch {
        state = .error(DomainError.unknown(error.localizedDescription).localizedDescription)
    }
}
```

---

## Testing — Swift Testing Framework

### Use Case Tests

```swift
// Tests/Domain/UseCases/FetchUserProfileUseCaseTests.swift
import Testing
@testable import App

@Suite("FetchUserProfileUseCase")
struct FetchUserProfileUseCaseTests {

    let mockRepository = MockUserRepository()

    @Test("returns user from repository")
    func fetchUser() async throws {
        let expectedUser = User(id: UUID(), name: "Alice", email: "alice@test.com")
        mockRepository.stubbedUser = expectedUser

        let useCase = FetchUserProfileUseCase(repository: mockRepository)
        let result = try await useCase.execute(id: expectedUser.id)

        #expect(result == expectedUser)
    }

    @Test("throws when repository fails")
    func fetchUserThrows() async {
        mockRepository.shouldThrow = true

        let useCase = FetchUserProfileUseCase(repository: mockRepository)

        await #expect(throws: DomainError.self) {
            try await useCase.execute(id: UUID())
        }
    }
}
```

### ViewModel Tests

```swift
@Suite("UserProfileViewModel")
@MainActor
struct UserProfileViewModelTests {

    @Test("sets loaded state on success")
    func loadSuccess() async {
        let user = User(id: UUID(), name: "Bob", email: "bob@test.com")
        let mockUseCase = MockFetchUserProfileUseCase(result: .success(user))
        let vm = UserProfileViewModel(userId: user.id, fetchUserProfile: mockUseCase)

        await vm.onAppear()

        #expect(vm.state == .loaded(user))
    }

    @Test("sets error state on failure")
    func loadFailure() async {
        let mockUseCase = MockFetchUserProfileUseCase(result: .failure(DomainError.noConnectivity))
        let vm = UserProfileViewModel(userId: UUID(), fetchUserProfile: mockUseCase)

        await vm.onAppear()

        guard case .error = vm.state else {
            Issue.record("Expected error state")
            return
        }
    }
}
```

### Mock Conventions

```swift
// Tests/Mocks/MockUserRepository.swift
final class MockUserRepository: UserRepository {
    var stubbedUser: User?
    var stubbedUsers: [User] = []
    var shouldThrow = false

    func fetchUser(id: UUID) async throws -> User {
        if shouldThrow { throw DomainError.noConnectivity }
        guard let user = stubbedUser else { throw DomainError.notFound }
        return user
    }

    func fetchUsers(cursor: String?, limit: Int) async throws -> PaginatedResult<User> {
        if shouldThrow { throw DomainError.noConnectivity }
        return PaginatedResult(items: stubbedUsers, nextCursor: nil, hasMore: false)
    }
}
```

```swift
// Tests/Mocks/MockFetchUserProfileUseCase.swift
final class MockFetchUserProfileUseCase: FetchUserProfileUseCaseProtocol {
    private let result: Result<User, Error>
    private let delay: Duration

    /// - Parameters:
    ///   - result: The stubbed result to return.
    ///   - delay: Artificial delay before returning. Use `.infinity` in previews to freeze the loading state.
    init(result: Result<User, Error> = .success(.placeholder), delay: Duration = .zero) {
        self.result = result
        self.delay = delay
    }

    func execute(id: UUID) async throws -> User {
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        return try result.get()
    }
}
```

---

## Accessibility

### AccessibilityID Enum

```swift
// Presentation/Common/AccessibilityIDs.swift
enum AccessibilityID {
    enum UserProfile {
        static let nameLabel = "userProfile.nameLabel"
        static let emailLabel = "userProfile.emailLabel"
        static let editButton = "userProfile.editButton"
        static let avatarImage = "userProfile.avatarImage"
        static let deleteButton = "userProfile.deleteButton"
    }

    enum UserList {
        static let searchField = "userList.searchField"
        static let userCell = "userList.userCell"       // Append row index: "\(userCell)_\(index)"
        static let refreshButton = "userList.refreshButton"
    }

    enum Common {
        static let loadingIndicator = "common.loadingIndicator"
        static let errorView = "common.errorView"
        static let retryButton = "common.retryButton"
    }
}
```

### Usage in Views

```swift
Button("Edit") { viewModel.onEdit() }
    .accessibilityIdentifier(AccessibilityID.UserProfile.editButton)

// For list items, append the index or a unique identifier
ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
    UserRow(user: user)
        .accessibilityIdentifier("\(AccessibilityID.UserList.userCell)_\(index)")
}
```

---

## Loading States & Shimmer

### ShimmerModifier

```swift
// Presentation/Common/Modifiers/ShimmerModifier.swift
import SwiftUI

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if active {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.4),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.4)
                        .offset(x: phase * geometry.size.width)
                        .clipped()
                    }
                    .mask(content.redacted(reason: .placeholder))
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1.4
                    }
                }
                .disabled(true)
                .accessibilityLabel("Loading content")
        } else {
            content
        }
    }
}

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}
```

### Shimmer on List Items

```swift
// In ViewModel
var displayUsers: [User] {
    switch state {
    case .loading: return (0..<8).map { _ in .placeholder }
    case .loaded(let users): return users
    default: return []
    }
}
```

```swift
// In View
List {
    ForEach(viewModel.displayUsers) { user in
        UserRow(user: user)
            .shimmering(active: viewModel.isLoading)
    }
}
```

---

## Environment-Based Configuration

### AppConfiguration

```swift
// Application/Configuration/AppConfiguration.swift
enum AppConfiguration {

    enum Environment: String {
        case debug
        case staging
        case production
    }

    static var current: Environment {
        guard let value = Bundle.main.infoDictionary?["APP_ENVIRONMENT"] as? String,
              let env = Environment(rawValue: value) else {
            return .debug
        }
        return env
    }

    static var baseURL: URL {
        guard let urlString = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL not configured in Info.plist")
        }
        return url
    }

    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["API_KEY"] as? String else {
            fatalError("API_KEY not configured in Info.plist")
        }
        return key
    }
}
```

### xcconfig Example

```
# Config/Debug.xcconfig
APP_ENVIRONMENT = debug
API_BASE_URL = https://api-dev.example.com
API_KEY = $(API_KEY_DEBUG)
```

---

## Feature Flags

### Flag Definition

```swift
// Domain/FeatureFlags/FeatureFlag.swift
enum FeatureFlag: String, CaseIterable, Sendable {
    case newOnboarding = "new_onboarding"
    case premiumPaywall = "premium_paywall"
    case darkModeOverride = "dark_mode_override"
    case experimentalSearch = "experimental_search"

    /// Offline default — returned when no remote value is available.
    var defaultValue: Bool {
        switch self {
        case .newOnboarding:        return false
        case .premiumPaywall:       return false
        case .darkModeOverride:     return false
        case .experimentalSearch:   return false
        }
    }
}
```

### Provider Protocol (Domain)

```swift
// Domain/FeatureFlags/FeatureFlagProvider.swift
protocol FeatureFlagProviderProtocol: Sendable {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func value<T>(for flag: FeatureFlag, type: T.Type) -> T? where T: Sendable
    func refresh() async
}
```

### Local Implementation (Data)

```swift
// Data/FeatureFlags/LocalFeatureFlagProvider.swift
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
        // No-op for local. Remote implementations fetch from server here.
    }
}
```

### Composite Provider (Local + Remote with Fallback)

```swift
// Data/FeatureFlags/CompositeFeatureFlagProvider.swift
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
```

### Usage in ViewModels

```swift
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var showNewOnboarding: Bool

    init(featureFlags: FeatureFlagProviderProtocol) {
        self.showNewOnboarding = featureFlags.isEnabled(.newOnboarding)
    }
}
```

### Testing Feature Flags

```swift
@Suite("Onboarding with feature flags")
@MainActor
struct OnboardingViewModelTests {

    @Test("shows new onboarding when flag is enabled")
    func newOnboardingEnabled() {
        let flags = LocalFeatureFlagProvider(overrides: [.newOnboarding: true])
        let vm = OnboardingViewModel(featureFlags: flags)
        #expect(vm.showNewOnboarding == true)
    }

    @Test("shows legacy onboarding when flag is disabled")
    func newOnboardingDisabled() {
        let flags = LocalFeatureFlagProvider(overrides: [.newOnboarding: false])
        let vm = OnboardingViewModel(featureFlags: flags)
        #expect(vm.showNewOnboarding == false)
    }
}
```

---

## Image Loading & Caching (Native)

> **`CachedAsyncImage` vs `AsyncImage`:** Apple's built-in `AsyncImage` has **no disk cache and no memory cache** — it re-downloads images every time a view appears. Always use the custom `CachedAsyncImage` below for any image that appears in lists, profiles, or anywhere the same URL may be loaded more than once. Reserve `AsyncImage` only for throwaway, one-off images where caching has no benefit.

### ImageCache Actor

```swift
// Presentation/Common/ImageCache/ImageCache.swift
actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, PlatformImageWrapper>()
    private let fileManager = FileManager.default
    private var activeTasks: [URL: Task<PlatformImage, Error>] = [:]

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
    }

    init(memoryLimit: Int = 50) {
        memoryCache.countLimit = memoryLimit
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async throws -> PlatformImage {
        let key = url.absoluteString as NSString

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key) {
            return cached.image
        }

        // 2. Disk cache
        let diskPath = diskURL(for: url)
        if let data = try? Data(contentsOf: diskPath),
           let image = PlatformImage(data: data) {
            memoryCache.setObject(PlatformImageWrapper(image), forKey: key)
            return image
        }

        // 3. Deduplicate in-flight requests
        if let existingTask = activeTasks[url] {
            return try await existingTask.value
        }

        // 4. Download
        let task = Task<PlatformImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = PlatformImage(data: data) else {
                throw ImageCacheError.invalidImage
            }

            // Store to disk
            try? data.write(to: diskPath)

            // Store to memory
            memoryCache.setObject(PlatformImageWrapper(image), forKey: key)

            return image
        }

        activeTasks[url] = task
        defer { activeTasks[url] = nil }

        return try await task.value
    }

    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    func clearDisk() throws {
        try fileManager.removeItem(at: cacheDirectory)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func diskURL(for url: URL) -> URL {
        let filename = url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .prefix(64)
        return cacheDirectory.appendingPathComponent(String(filename))
    }
}

// MARK: - Helpers

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

final class PlatformImageWrapper {
    let image: PlatformImage
    init(_ image: PlatformImage) { self.image = image }
}

enum ImageCacheError: LocalizedError {
    case invalidImage
    var errorDescription: String? { "Failed to load image." }
}
```

### CachedAsyncImage View

```swift
// Presentation/Common/ImageCache/CachedAsyncImage.swift
import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: PlatformImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                #if canImport(UIKit)
                content(Image(uiImage: image))
                #elseif canImport(AppKit)
                content(Image(nsImage: image))
                #endif
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url, image == nil else { return }
            isLoading = true
            defer { isLoading = false }
            self.image = try? await ImageCache.shared.image(for: url)
        }
    }
}
```

### Usage

```swift
CachedAsyncImage(url: user.avatarURL) { image in
    image
        .resizable()
        .scaledToFill()
        .frame(width: 48, height: 48)
        .clipShape(Circle())
} placeholder: {
    Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 48, height: 48)
}
```
