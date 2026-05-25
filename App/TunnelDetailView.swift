// App/TunnelDetailView.swift
// Detail screen for a single Cloudflare Tunnel — shows ID, status, dates, and recent logs.

import SwiftUI

// MARK: - TunnelDetailView

struct TunnelDetailView: View {

    // Accept the TunnelInfo directly so the view is self-contained and preview-friendly.
    let tunnel: TunnelInfo

    /// Called when the user taps the toolbar Refresh button.
    var onRefresh: (() async -> Void)?

    @State private var isRefreshing = false
    @State private var showCopiedToast = false
    @State private var lastRefreshed: Date = Date()

    // MARK: - Body

    var body: some View {
        List {
            identitySection
            statusSection
            datesSection
            logsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tunnel 详情")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { refreshButton }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
    }

    // MARK: - Sections

    /// Tunnel ID with copy-on-tap affordance.
    private var identitySection: some View {
        Section {
            Button {
                UIPasteboard.general.string = tunnel.id
                triggerCopiedToast()
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tunnel ID")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(tunnel.id)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    } icon: {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    Image(systemName: "doc.on.doc")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            LabeledContent {
                Text(tunnel.name)
                    .foregroundStyle(.primary)
            } label: {
                Label("名称", systemImage: "tag")
            }
        } header: {
            Text("身份")
        }
    }

    /// Health indicator (green/red dot) + optional health summary.
    private var statusSection: some View {
        Section {
            HStack {
                Label {
                    Text("状态")
                } icon: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.blue)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(tunnel.healthcheck == true ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(
                            color: (tunnel.healthcheck == true ? Color.green : Color.red).opacity(0.5),
                            radius: 3
                        )

                    Text(tunnel.status.capitalized)
                        .foregroundStyle(tunnel.healthcheck == true ? .green : .red)
                        .fontWeight(.medium)
                }
            }

            if let summary = tunnel.healthSummary, !summary.isEmpty {
                Label {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("运行状态")
        }
    }

    /// Created-at and last-refreshed timestamps.
    private var datesSection: some View {
        Section {
            if let createdAt = tunnel.createdAt {
                LabeledContent {
                    Text(createdAt, style: .date)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("创建时间", systemImage: "clock.badge.checkmark")
                }
            }

            LabeledContent {
                Text(lastRefreshed, style: .relative) + Text(" 前")
            } label: {
                Label("上次刷新", systemImage: "clock.arrow.circlepath")
            }
            .foregroundStyle(.secondary)
        } header: {
            Text("时间")
        }
    }

    /// Scrollable log lines, or an empty-state placeholder.
    private var logsSection: some View {
        Section {
            if tunnel.logLines.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.quaternary)
                        Text("暂无日志")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(tunnel.logLines) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Label("最近日志", systemImage: "doc.text")
        }
    }

    // MARK: - Toolbar

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.85)
            } else {
                Button {
                    guard let onRefresh else { return }
                    isRefreshing = true
                    Task {
                        await onRefresh()
                        lastRefreshed = Date()
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.medium)
                }
                .accessibilityLabel("刷新")
                .disabled(onRefresh == nil)
            }
        }
    }

    // MARK: - Copy toast

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text("Tunnel ID 已复制")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75), in: Capsule())
    }

    private func triggerCopiedToast() {
        showCopiedToast = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { showCopiedToast = false }
        }
    }
}

// MARK: - Preview

#Preview("Detail – Connected") {
    NavigationStack {
        TunnelDetailView(
            tunnel: TunnelInfo(
                id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                name: "prod-tunnel",
                status: "healthy",
                createdAt: Date(timeIntervalSinceNow: -86400 * 7),
                healthcheck: true,
                healthSummary: "All connectors healthy",
                logLines: [
                    TunnelLogEntry(timestamp: Date(timeIntervalSinceNow: -120), message: "Connector reconnected to edge (region: apac)"),
                    TunnelLogEntry(timestamp: Date(timeIntervalSinceNow: -60),  message: "Heartbeat OK"),
                    TunnelLogEntry(timestamp: Date(timeIntervalSinceNow: -10),  message: "Config reloaded successfully")
                ]
            )
        )
    }
}

#Preview("Detail – No Logs") {
    NavigationStack {
        TunnelDetailView(
            tunnel: TunnelInfo(
                id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                name: "staging-tunnel",
                status: "down",
                healthcheck: false
            )
        )
    }
}
