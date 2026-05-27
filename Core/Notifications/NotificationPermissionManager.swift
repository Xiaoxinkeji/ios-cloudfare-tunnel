// Core/Notifications/NotificationPermissionManager.swift
import UserNotifications
import SwiftUI

// MARK: - Permission Manager

struct NotificationPermissionManager {

    /// Returns the current authorisation status without prompting.
    func getStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Requests authorisation if not yet determined; returns true if permission is granted.
    @discardableResult
    func requestIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Opens the app's system Settings page so the user can manually enable notifications.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}

// MARK: - In-App Pre-prompt View

/// Present this before calling `requestIfNeeded()` so the user understands why
/// you need notification permission. Only show once — guard with a UserDefaults flag.
struct NotificationPrePromptView: View {

    let onContinue: () async -> Void
    let onSkip: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("接收 Tunnel 状态提醒")
                    .font(.title2.weight(.semibold))

                Text("当 Tunnel 离线、降级或凭证失效时，我们会第一时间通知你。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        await onContinue()
                        isRequesting = false
                    }
                } label: {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("继续")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting)

                Button("暂不", action: onSkip)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - UserDefaults key

extension UserDefaults {
    var hasSeenNotificationPrePrompt: Bool {
        get { bool(forKey: "hasSeenNotificationPrePrompt") }
        set { set(newValue, forKey: "hasSeenNotificationPrePrompt") }
    }
}
