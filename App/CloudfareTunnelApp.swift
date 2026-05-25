// App/CloudfareTunnelApp.swift
// Application entry point

import SwiftUI

@main
struct CloudfareTunnelApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = TunnelViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(viewModel)
            .onReceive(
                NotificationCenter.default.publisher(for: .openTunnelDetailFromNotification)
            ) { note in
                // TODO: navigate to tunnel detail for note.object as? String
                _ = note.object as? String
            }
        }
    }
}
