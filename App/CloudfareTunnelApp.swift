// App/CloudfareTunnelApp.swift
// Application entry point

import SwiftUI

@main
struct CloudfareTunnelApp: App {

    @StateObject private var viewModel = TunnelViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(viewModel)
        }
    }
}
