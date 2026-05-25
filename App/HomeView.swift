// App/HomeView.swift
// Main screen – shows tunnel status and primary connect/disconnect button

import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var viewModel: TunnelViewModel
    @State private var showSettings = false
    @State private var isPerformingAction = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── Tunnel name ───────────────────────────────────────────
                Text(viewModel.tunnelDisplayName)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                // ── Status indicator ──────────────────────────────────────
                statusIndicator

                // ── Error message ─────────────────────────────────────────
                if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Spacer()

                // ── Primary action button ─────────────────────────────────
                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // ── Last refreshed timestamp ──────────────────────────────
                lastRefreshedLabel
                    .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            viewModel.reloadConfig()
        }) {
            ConfigEditorView()
                .environmentObject(viewModel)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusIndicator: some View {
        let display = viewModel.statusDisplay
        HStack(spacing: 10) {
            if viewModel.state.isBusy {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(display.tint)
                    .scaleEffect(0.9)
            } else {
                Circle()
                    .fill(display.tint)
                    .frame(width: 14, height: 14)
                    .shadow(color: display.tint.opacity(0.6), radius: 4)
            }

            Text(display.text)
                .font(.headline)
                .foregroundStyle(display.tint)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        Button {
            guard !isPerformingAction else { return }
            isPerformingAction = true
            Task {
                defer { isPerformingAction = false }
                // Determine correct action based on state
                switch viewModel.state {
                case .disconnected:          await viewModel.perform(.start)
                case .connected:             await viewModel.perform(.stop)
                case .failure:               await viewModel.perform(.retry)
                case .connecting,
                     .disconnecting:         break   // Button is disabled
                }
            }
        } label: {
            Text(viewModel.primaryButtonLabel)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonBackground)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(viewModel.state.isBusy || isPerformingAction)
        .opacity(viewModel.state.isBusy ? 0.6 : 1.0)
    }

    private var buttonBackground: Color {
        switch viewModel.state {
        case .disconnected:         return .blue
        case .connecting:           return .blue.opacity(0.7)
        case .connected:            return .red
        case .disconnecting:        return .red.opacity(0.7)
        case .failure:              return .orange
        }
    }

    @ViewBuilder
    private var lastRefreshedLabel: some View {
        if let date = viewModel.lastRefreshed {
            Text("Last refreshed \(date, style: .relative) ago")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Not yet refreshed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(TunnelViewModel())
}
