# Agents.md — iOS Project Rules & Conventions

> **Minimum deployment target: iOS 17+**
> All patterns use the `@Observable` macro, structured concurrency, and SwiftUI-first APIs.
> For full code examples and implementations, see [CodePatterns.md](CodePatterns.md).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Layer Rules](#layer-rules)
4. [MVVM Pattern](#mvvm-pattern)
5. [Coordinator Pattern (Navigation)](#coordinator-pattern-navigation)
6. [Networking](#networking)
7. [Pagination](#pagination)
8. [SwiftData — Persistence](#swiftdata--persistence)
9. [Dependency Injection](#dependency-injection)
10. [Error Handling Strategy](#error-handling-strategy)
11. [Testing — Swift Testing Framework](#testing--swift-testing-framework)
12. [Concurrency & Threading](#concurrency--threading)
13. [Naming & Code Style Conventions](#naming--code-style-conventions)
14. [Accessibility](#accessibility)
15. [Loading States & Shimmer](#loading-states--shimmer)
16. [Localization](#localization)
17. [Performance Guidelines](#performance-guidelines)
18. [Environment-Based Configuration](#environment-based-configuration)
19. [Feature Flags](#feature-flags)
20. [Image Loading & Caching](#image-loading--caching)
21. [Git & Workflow Conventions](#git--workflow-conventions)
22. [Do NOT](#do-not)

---

## Architecture Overview

This project follows **MVVM + Clean Architecture** with clear separation of concerns across layers. Every feature must respect this layered structure. Do not merge responsibilities across layers.

```
Presentation → Domain → Data
```

---

## Project Structure

```
App/
├── Application/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Configuration/               # Environment & feature flags
│   │   ├── AppConfiguration.swift
│   │   └── FeatureFlagProvider.swift
│   └── DI/                          # Dependency Injection container
│       └── AppDIContainer.swift
├── Presentation/
│   ├── Coordinators/                # Navigation coordinators
│   ├── Features/
│   │   └── <FeatureName>/
│   │       ├── View/                # SwiftUI views
│   │       ├── ViewModel/           # ViewModels (@Observable)
│   │       └── Components/          # Feature-specific reusable UI
│   └── Common/
│       ├── Components/              # Shared UI components
│       ├── ImageCache/              # Native async image loading + caching
│       ├── Modifiers/               # SwiftUI view modifiers
│       └── Extensions/              # UI-related extensions
├── Domain/
│   ├── Entities/                    # Business models (plain structs)
│   ├── UseCases/                    # Business logic (protocols + implementations)
│   ├── Repositories/               # Repository protocols (abstractions only)
│   ├── FeatureFlags/               # Feature flag enum + provider protocol
│   └── Errors/                     # Domain-specific error types
├── Data/
│   ├── Repositories/               # Repository implementations
│   ├── Network/
│   │   ├── APIClient.swift          # Generic async/await network client
│   │   ├── Endpoints/              # Endpoint definitions
│   │   ├── DTOs/                   # Data Transfer Objects (Decodable)
│   │   └── Mappers/                # DTO → Entity mappers
│   ├── Persistence/
│   │   ├── Models/                 # SwiftData @Model classes
│   │   ├── SwiftDataStore.swift    # SwiftData CRUD abstraction
│   │   └── Mappers/                # SwiftData Model ↔ Entity mappers
│   ├── FeatureFlags/               # Feature flag provider implementations
│   └── Keychain/                   # Secure storage
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.xcstrings
    └── Info.plist
```

---

## Layer Rules

### Domain Layer
- **Zero dependencies** on any framework except Foundation.
- Contains **Entities** (plain Swift structs/enums), **Use Case protocols and implementations**, and **Repository protocols**.
- Entities must NOT be `@Model` classes or DTOs. They are pure value types.
- Entities conform to `Identifiable`, `Equatable`, and `Sendable`.
- Use cases encapsulate a single business operation. Name them as actions: `FetchUserProfileUseCase`, `PlaceOrderUseCase`.

### Data Layer
- Implements repository protocols defined in Domain.
- Contains **network clients**, **DTOs**, **SwiftData models**, and **mappers**.
- DTOs and SwiftData models never leak into Domain or Presentation.
- All mapping between DTOs/persistence models and domain entities happens in dedicated `Mapper` types (static enums).
- API field names often differ from domain property names. Mappers isolate these transformations so API contract changes never ripple beyond the Data layer.

### Presentation Layer
- Contains **Views**, **ViewModels**, and **Coordinators**.
- ViewModels depend on Use Case protocols, never on repositories or data sources directly.
- Views depend only on their ViewModel.

---

## MVVM Pattern

### ViewModel Rules
- Always use the `@Observable` macro.
- Mark with `@MainActor`.
- Expose state properties directly — `@Observable` tracks access automatically; no `@Published` needed.
- Never import UIKit or SwiftUI in ViewModels. Prefer Foundation and Observation.
- Handle errors gracefully and expose user-facing error state.
- Depend on Use Case protocols, injected via initializer.

### State Pattern
- Use a `State` enum with exactly three cases: `.loading`, `.loaded(Data)`, `.error(String)`. **No `.idle` state.** ViewModels start in `.loading`.
- Expose `isLoading: Bool` as a computed property for shimmer binding.
- Expose `displayUser` / `displayItems` computed properties that return `.placeholder` data during loading so the View renders the same layout in every non-error state.
- This guarantees the shimmer skeleton is always visible on first render, avoiding blank screens.

### View Rules
- Views are lightweight. No business logic, no networking, no persistence calls.
- Observe ViewModels using `@State` for owned instances (created by the View or Coordinator). Use `@Bindable` when two-way binding is needed. With `@Observable`, SwiftUI tracks property access automatically.
- Trigger ViewModel methods on user actions and lifecycle events.
- Always use the same content view for loading and loaded states; toggle `.shimmering(active:)` instead of swapping views. Only the error state renders a different layout.

> See [CodePatterns.md → MVVM](CodePatterns.md#mvvm-pattern) for the full ViewModel, View, and placeholder implementation.

---

## Coordinator Pattern (Navigation)

### Rules
- Use the **Coordinator pattern** to manage navigation flow. Views never directly push or present other views.
- Each feature or flow has a Coordinator.
- Coordinators own child coordinators (retain cycle safe via `[weak self]`).
- Coordinators create ViewModels and Views, injecting dependencies.
- Use `NavigationStack` with a path-based approach.
- `Route` enums conform to both `Hashable` and `Identifiable` (required for `.sheet(item:)`).
- Coordinators use `@Observable` — no `ObservableObject`.

> See [CodePatterns.md → Coordinator](CodePatterns.md#coordinator-pattern) for the full AppCoordinator and RootView implementation.

---

## Networking

### Rules
- A single generic `APIClient` handles all network requests using `async/await`. No Combine, no completion handlers.
- The client provides two `request` methods: one generic `<T: Decodable>` that decodes, and one that returns raw `Data`.
- `Endpoint` structs define path, method, headers, query items, body, and base URL.
- Use `RequestInterceptor` protocol for cross-cutting concerns (auth tokens, logging).
- `NetworkError` is a data-layer enum. It never leaks into Domain — repositories map it to `DomainError`.

> See [CodePatterns.md → Networking](CodePatterns.md#networking--asyncawait--generics) for APIClient, Endpoint, NetworkError, and Interceptor code.

---

## Pagination

### Rules
- Use a generic, cursor-based pagination pattern across all layers.
- Data layer: `PaginatedResponse<T: Decodable>` wraps API responses with `items`, `nextCursor`, and `totalCount`.
- Domain layer: `PaginatedResult<T: Sendable>` wraps results with `items`, `nextCursor`, and `hasMore`. No DTOs.
- Repository protocols accept `cursor: String?` and `limit: Int` parameters.
- ViewModels manage pagination state internally (`nextCursor`, `hasMore`, `isLoadingMore`). Views trigger `loadMoreIfNeeded(currentItem:)` via `.task` on each row.
- Initial load shows shimmer skeleton. "Load more" shows a `ProgressView` footer.
- Pull-to-refresh resets to the first page.

> See [CodePatterns.md → Pagination](CodePatterns.md#pagination) for ViewModel and View implementations.

---

## SwiftData — Persistence

### Rules
- `@Model` classes live **only** in `Data/Persistence/Models/`.
- They never appear in Domain or Presentation layers.
- Always map between SwiftData models and Domain entities via Mappers.
- Use a `SwiftDataStore` abstraction to encapsulate CRUD operations.
- Configure `ModelContainer` in the DI container or App entry point.

> See [CodePatterns.md → SwiftData](CodePatterns.md#swiftdata--persistence) for Model, Mapper, and SwiftDataStore code.

---

## Dependency Injection

### Rules
- Use a **DI Container** to assemble dependencies. No third-party DI frameworks unless justified.
- The container owns the `ModelContainer`, `SwiftDataStore`, `APIClient`, and token provider.
- Factory methods create repositories and use cases. ViewModels are created in Coordinators.

### SwiftUI Previews
- Never instantiate `AppDIContainer`, `APIClient`, or `SwiftDataStore` in previews.
- Use lightweight mock use cases directly — reuse mocks from the test target or a shared `PreviewHelpers` file.
- Always create previews for all three states: loading, loaded, and error.
- Mock use cases support a configurable `delay` parameter so the loading/shimmer state can be previewed indefinitely.

> See [CodePatterns.md → Dependency Injection](CodePatterns.md#dependency-injection) for the AppDIContainer and preview examples.

---

## Error Handling Strategy

### Rules
- Define a `DomainError` enum in `Domain/Errors/` conforming to `LocalizedError` and `Equatable`.
- Cases: `notFound`, `unauthorized`, `serverError`, `noConnectivity`, `unknown(String)`.
- Repositories catch `NetworkError` and re-throw as `DomainError`. This is the **only** place where this translation happens.
- Create a `NetworkError.toDomainError()` extension in the Data layer to centralize the mapping.
- ViewModels only catch `DomainError`. They never inspect `NetworkError` or any data-layer type.
- Use `throws` with `async/await`. Avoid `Result` types for async flows.

> See [CodePatterns.md → Error Handling](CodePatterns.md#error-handling-strategy) for DomainError, NetworkError mapping, and repository implementation.

---

## Testing — Swift Testing Framework

### Rules
- Use the **Swift Testing** framework (`import Testing`). Not XCTest, unless dealing with UI tests or performance tests that require it.
- Every Use Case, ViewModel, Repository, and Mapper must have tests.
- Use protocol-based mocks. No mocking frameworks.
- Test files mirror the source structure under a `Tests/` target.
- Use `@Test` macro, `#expect`, and `#require`.
- Group related tests with `@Suite`.
- Use `throws` and `async` test functions naturally.

### Mock Conventions
- Mocks are protocol-based with `Result` for stubbing.
- Mock use cases support an optional `delay: Duration` parameter for preview and timing tests.
- Repository mocks use `shouldThrow` flag and stubbed return values.
- Mocks throw `DomainError`, never `NetworkError`.

> See [CodePatterns.md → Testing](CodePatterns.md#testing--swift-testing-framework) for test suites, mocks, and ViewModel testing examples.

---

## Concurrency & Threading

- Use **structured concurrency** (`async let`, `TaskGroup`) over unstructured `Task {}` where possible.
- Mark ViewModels `@MainActor`.
- Mark protocols with `Sendable` when values cross actor boundaries.
- Never use `DispatchQueue.main.async` in new code. Use `@MainActor` or `MainActor.run {}`.
- Avoid `Task { @MainActor in ... }` when the enclosing type is already `@MainActor`.

---

## Naming & Code Style Conventions

| Element | Convention | Example |
|---|---|---|
| Protocols | Suffix with descriptive name or `Protocol` for use case abstractions | `UserRepository`, `FetchUserProfileUseCaseProtocol` |
| Implementations | Prefix with `Default` or context-specific name | `DefaultUserRepository`, `KeychainTokenProvider` |
| ViewModels | Suffix with `ViewModel` | `UserProfileViewModel` |
| Views | Suffix with `View` | `UserProfileView` |
| DTOs | Suffix with `DTO` | `UserDTO` |
| SwiftData models | Suffix with `Model` | `UserModel` |
| Mappers | Static enum, suffix with `Mapper` | `UserDTOMapper`, `UserModelMapper` |
| Use Cases | Action-based naming, suffix with `UseCase` | `FetchUserProfileUseCase` |
| Coordinators | Suffix with `Coordinator` | `AppCoordinator` |
| Test suites | Mirror source file name + `Tests` | `FetchUserProfileUseCaseTests` |

---

## Accessibility

- Every interactive element must have an `accessibilityLabel`.
- Use `accessibilityHint` for non-obvious actions.
- **Every interactive and meaningful UI element must have an `accessibilityIdentifier`** for UI testing. Use a structured, dot-separated naming convention: `"screenName.elementName"`.
- Define all identifiers as static constants in a dedicated `AccessibilityID` enum with nested enums per screen. This prevents typos and keeps identifiers consistent between source code and tests.
- For list items, append the row index or unique identifier: `"\(AccessibilityID.UserList.userCell)_\(index)"`.
- Support Dynamic Type — avoid fixed font sizes; use `.font(.body)`, `.font(.headline)`, etc.
- Test VoiceOver navigation for every new screen.
- Use semantic SwiftUI components (`Button`, `Label`, `Toggle`) over raw gesture recognizers.

> See [CodePatterns.md → Accessibility](CodePatterns.md#accessibility) for the AccessibilityID enum example.

---

## Loading States & Shimmer

### Rules
- Every screen that fetches data must show a shimmer skeleton, not a blank screen or a centered spinner.
- The skeleton should match the layout of the loaded content as closely as possible (same heights, widths, spacing).
- Use the `.shimmering(active:)` modifier to toggle the effect based on the ViewModel's `isLoading` property.
- Use `.redacted(reason: .placeholder)` on the content view to automatically generate placeholder shapes, then layer the shimmer animation on top.
- Keep shimmer logic in a reusable `ShimmerModifier` — never re-implement the animation per screen.
- ViewModels expose `displayUser` / `displayItems` computed properties that return `.placeholder` data during loading (see [MVVM Pattern](#mvvm-pattern)).
- Every entity that appears in a shimmer skeleton needs a `static let placeholder` property.
- For lists, the ViewModel returns an array of placeholder items during loading to fill the visible area.

> See [CodePatterns.md → Shimmer](CodePatterns.md#loading-states--shimmer) for the ShimmerModifier and entity placeholder code.

---

## Localization

- Never hardcode user-facing strings. Use `String(localized:)` or `LocalizedStringKey`.
- Store all strings in `Localizable.xcstrings`.
- Use context-rich key names: `"user_profile.name_label"` not `"name"`.
- Provide comments for translators.

---

## Performance Guidelines

- Use `LazyVStack` / `LazyHStack` for long scrollable lists instead of `VStack` / `HStack`.
- Profile with Instruments before optimizing. Do not prematurely optimize.
- With `@Observable`, SwiftUI tracks property access per-view automatically. Avoid computing expensive derived properties inline in `body` — cache them as stored properties updated when state changes.
- Debounce search inputs and other rapid-fire user actions.
- Use `Equatable` conformance on state types to minimize unnecessary view redraws.

---

## Environment-Based Configuration

### Rules
- Use an `AppConfiguration` enum to centralize all environment-dependent values.
- Switch environments via Xcode schemes and `.xcconfig` files — never hardcode base URLs or keys.
- Define one `.xcconfig` file per environment. Reference values via `Info.plist` keys.
- Never commit secrets or API keys to source control. Use `.xcconfig` files excluded from git, or inject at build time via CI/CD.
- Access configuration values through `AppConfiguration`, never by reading `Info.plist` directly in feature code.

> See [CodePatterns.md → Configuration](CodePatterns.md#environment-based-configuration) for the AppConfiguration code and xcconfig example.

---

## Feature Flags

### Rules
- Use feature flags to control rollout of new features, run A/B experiments, and provide kill-switches.
- Feature flags are a **domain concept** — the provider protocol lives in Domain, implementations in Data.
- Every flag has a **default offline value** (fallback when remote provider is unreachable).
- Define all flags in a single `FeatureFlag` enum to keep them discoverable. No string-based lookups.
- Feature flags must be testable — ViewModels and Use Cases receive flag values through injection, never by calling a global provider directly.
- Flags should not be checked inside Views. ViewModels read flags and expose the resulting behavior.
- Clean up stale flags regularly. When a flag has been fully rolled out, remove it and its conditional code paths.
- Use a `CompositeFeatureFlagProvider` to layer remote over local with fallback.

> See [CodePatterns.md → Feature Flags](CodePatterns.md#feature-flags) for FeatureFlag enum, provider protocol, local/composite implementations, and testing examples.

---

## Image Loading & Caching

### Rules
- Use a native image loading solution built on `URLSession` and `NSCache`. No third-party libraries.
- The `ImageCache` actor provides two-tier caching: `NSCache` (memory) + disk (`Caches/` directory).
- In-flight requests are deduplicated — concurrent loads of the same URL share one network task.
- Use `CachedAsyncImage` (custom component) for all remote images in lists, profiles, and repeating content.
- **Never use Apple's `AsyncImage`** for cacheable content — it has no disk or memory cache and re-downloads on every appearance. Reserve `AsyncImage` only for throwaway, one-off images (e.g. a preview thumbnail shown once during an upload flow).
- Implementation lives in `Presentation/Common/ImageCache/`.

> See [CodePatterns.md → Image Loading](CodePatterns.md#image-loading--caching-native) for the ImageCache actor, CachedAsyncImage view, and usage examples.

---

## Git & Workflow Conventions

- Branch naming: `feature/<ticket-id>-short-description`, `bugfix/<ticket-id>-short-description`.
- Commit messages: imperative mood, concise. e.g. `Add user profile caching with SwiftData`.
- One feature per branch. Small, reviewable PRs.
- Run all tests before opening a PR.

---

## Agent Delivery Rules

All work MUST be delivered in small, reviewable chunks. Never implement an entire feature as a single batch.

### For the Lead Agent (ios-engineer-lead)
1. **Break the plan into steps** — each step should produce 1-3 files max.
2. **Delegate one step at a time** — launch a specialist agent for one step, return the result summary, and STOP.
3. **Wait for approval** — do NOT proceed to the next step until the user reviews and approves. End your response with a clear summary of what was done and ask: "Ready to proceed with the next step?"
4. **If the user gives feedback** — relay corrections to the same agent before moving on.
5. **Track progress** — maintain a checklist showing completed vs remaining steps.

### For Specialist Agents (ios-front-engineer, jira-ticket-implementer)
1. **One logical chunk per run** — create or modify 1-3 files, then return a summary of what was done.
2. **Summarize changes clearly** — list every file created/modified with a one-line description of what changed.
3. **Do not chain unrelated changes** — if your task involves multiple independent pieces (e.g., models + views + modifiers), implement only the first piece and describe what remains.

### Progress Format
```
Step 1/4: [description] ✅
Step 2/4: [description] ← current, awaiting review
Step 3/4: [description] — pending
Step 4/4: [description] — pending
```

---

## Do NOT

- Put business logic in Views.
- Reference `@Model` types outside the Data layer.
- Use singletons for state management.
- Use `AnyView` type erasure unless absolutely necessary.
- Force-unwrap optionals in production code (test code is acceptable).
- Use Combine for new async work — prefer async/await.
- Skip writing tests for "simple" code.
- Import SwiftUI in Domain or Data layers.
- Create god objects — split large ViewModels and Coordinators by responsibility.
- Use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject` — use `@Observable`, `@State`, and `@Bindable` instead.
- Use Apple's `AsyncImage` for content that should be cached — use `CachedAsyncImage`.
- Check feature flags inside Views — read them in ViewModels.
- Leak `NetworkError` or any data-layer error type into Domain or Presentation — map to `DomainError` in repositories.
