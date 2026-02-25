//
//  MoviesAppTestApp.swift
//  MoviesAppTest
//
//  Created by cristian tovar on 7/02/26.
//

import SwiftUI

@main
struct MoviesAppTestApp: App {
    private let diContainer = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: AppCoordinator(diContainer: diContainer))
        }
    }
}
