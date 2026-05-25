// App/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: TunnelViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                statusCard
                actionCard
                detailCard
                configCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Tunnel")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
        .alert(
            viewModel.transientError?.title ?? "Error",
            isPresented: Binding(
                get: { viewModel.transientError != nil },
                set: { if !$0 { viewModel.transientError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.transientError = nil }
        } message: {
            Text(viewModel.transientError?.message ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cloudflare Tunnel")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text("One screen. One action. Full control.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        Card {
            HStack(spacing: 14) {
                StatusDot(state: viewModel.status.state)
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.status.title)
                        .font(.headline)
                    Text(viewModel.status.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var actionCard: some View {
        Card {
            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.primaryAction() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isBusy {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.primaryActionTitle)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .background(viewModel.primaryActionColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(viewModel.isBusy)

                HStack {
                    Label(viewModel.lastUpdatedText, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var detailCard: some View {
        if let info = viewModel.status.info {
            NavigationLink {
                TunnelDetailView(tunnel: info)
            } label: {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Details")
                                .font(.headline)
                            Text("Tunnel ID, health check, and recent logs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var configCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Configuration")
                        .font(.headline)
                    Spacer()
                    Button("Edit") { viewModel.isEditingConfig = true }
                        .font(.subheadline.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    ConfigRow(title: "Cloudflare API", value: viewModel.configuration.cloudflareAPIBaseURL.absoluteString)
                    ConfigRow(title: "Cloudflare Auth", value: viewModel.cloudflareAuthState.title)
                    ConfigRow(title: "Control Backend", value: viewModel.configuration.controlPlaneURL?.absoluteString ?? "—")
                    ConfigRow(title: "Control Auth", value: viewModel.controlPlaneAuthState.title)
                    ConfigRow(title: "Account", value: viewModel.configuration.accountId)
                    ConfigRow(title: "Tunnel", value: viewModel.configuration.tunnelId ?? "—")
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditingConfig) {
            ConfigEditorView(configuration: viewModel.configuration) { newConfig in
                Task { await viewModel.saveConfiguration(newConfig) }
            }
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct StatusDot: View {
    let state: TunnelState

    var body: some View {
        Circle()
            .fill(state.tint)
            .frame(width: 14, height: 14)
            .shadow(color: state.tint.opacity(0.25), radius: 8, x: 0, y: 0)
            .accessibilityHidden(true)
    }
}

private struct ConfigRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
