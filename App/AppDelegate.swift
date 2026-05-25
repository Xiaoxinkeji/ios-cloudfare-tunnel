// App/AppDelegate.swift
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 前台时也展示 banner + 播放声音
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier

        // degraded 在前台降级处理：只更新 badge，不弹横幅
        if identifier.hasPrefix(LocalNotificationEvent.tunnelDegraded.rawValue) {
            return [.badge]
        }
        return [.banner, .sound, .badge]
    }

    /// 用户点击通知后路由到对应 Tunnel 详情页
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let tunnelID = userInfo["tunnel_id"] as? String else { return }

        NotificationCenter.default.post(
            name: .openTunnelDetailFromNotification,
            object: tunnelID
        )
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    static let openTunnelDetailFromNotification =
        Notification.Name("openTunnelDetailFromNotification")
}
