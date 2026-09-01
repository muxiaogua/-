//
//  NotificationService.swift
//  团队工作台
//

import Foundation
import Combine
import UserNotifications

@MainActor
public class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()
    
    @Published public var isAuthorized: Bool = false
    @Published public var lastNotificationTitle: String?
    
    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }
    
    public func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    public func sendLocalNotification(
        title: String,
        subtitle: String? = nil,
        body: String,
        badgeCount: Int? = nil,
        categoryIdentifier: String? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle, !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        content.body = body
        content.sound = .default
        if let count = badgeCount {
            content.badge = NSNumber(value: count)
        }
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.lastNotificationTitle = title
                }
            }
        }
    }
    
    // Support showing notifications even when the app is in the foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
