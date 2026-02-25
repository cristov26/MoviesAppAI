import SwiftUI

struct RootView: View {
    @State var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.view(for: .movieList)
                .navigationDestination(for: AppCoordinator.Route.self) { route in
                    coordinator.view(for: route)
                }
        }
        .sheet(item: $coordinator.sheet) { route in
            coordinator.view(for: route)
        }
    }
}
