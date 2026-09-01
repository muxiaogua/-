//
//  WorkbenchStore.swift
//  团队工作台
//

import Foundation
import Combine

@MainActor
public class WorkbenchStore: ObservableObject {
    @Published public var announcements: [Announcement] = []
    @Published public var newsArticles: [NewsArticle] = []
    @Published public var currentUser: TeamMember = TeamMember.currentUser
    @Published public var searchText: String = ""
    @Published public var selectedNavigation: AppNavigationItem? = .dashboard
    
    private let announcementsStorageKey = "workbench_announcements_v2"
    private let newsStorageKey = "workbench_news_v2"
    
    public init() {
        loadData()
    }
    
    // MARK: - Computed Properties
    
    public var urgentAnnouncements: [Announcement] {
        announcements.filter { $0.priority == .urgent && !$0.isAcknowledged }
    }
    
    public var pinnedAnnouncements: [Announcement] {
        announcements.filter { $0.isPinned }
    }
    
    public var unacknowledgedCount: Int {
        announcements.filter { $0.requiresAcknowledgment && !$0.isAcknowledged }.count
    }
    
    public var totalAnnouncementsCount: Int {
        announcements.count
    }
    
    public var bookmarkedNews: [NewsArticle] {
        newsArticles.filter { $0.isBookmarked }
    }
    
    public var latestNews: [NewsArticle] {
        Array(newsArticles.sorted { $0.publishDate > $1.publishDate }.prefix(5))
    }
    
    // MARK: - Actions: Announcements
    
    public func acknowledgeAnnouncement(id: UUID) {
        if let index = announcements.firstIndex(where: { $0.id == id }) {
            announcements[index].isAcknowledged = true
            announcements[index].acknowledgedAt = Date()
            saveData()
        }
    }
    
    public func togglePinAnnouncement(id: UUID) {
        if let index = announcements.firstIndex(where: { $0.id == id }) {
            announcements[index].isPinned.toggle()
            saveData()
        }
    }
    
    public func addAnnouncement(_ announcement: Announcement, notify: Bool = true) {
        announcements.insert(announcement, at: 0)
        saveData()
        
        if notify {
            let subtitle = announcement.priority == .urgent ? "🚨 紧急公告" : "📢 团队新公告"
            NotificationService.shared.sendLocalNotification(
                title: announcement.title,
                subtitle: subtitle,
                body: announcement.content
            )
        }
    }
    
    public func deleteAnnouncement(id: UUID) {
        announcements.removeAll { $0.id == id }
        saveData()
    }
    
    // MARK: - Actions: News
    
    public func toggleBookmark(id: UUID) {
        if let index = newsArticles.firstIndex(where: { $0.id == id }) {
            newsArticles[index].isBookmarked.toggle()
            saveData()
        }
    }
    
    public func incrementReadCount(id: UUID) {
        if let index = newsArticles.firstIndex(where: { $0.id == id }) {
            newsArticles[index].readCount += 1
            saveData()
        }
    }
    
    public func addNewsArticle(_ article: NewsArticle, notify: Bool = true) {
        newsArticles.insert(article, at: 0)
        saveData()
        
        if notify {
            NotificationService.shared.sendLocalNotification(
                title: "📰 新资讯推送: " + article.title,
                subtitle: article.category.rawValue,
                body: article.summary
            )
        }
    }
    
    public func deleteNewsArticle(id: UUID) {
        newsArticles.removeAll { $0.id == id }
        saveData()
    }
    
    // MARK: - Actions: Comments
    
    public func addComment(to articleId: UUID, comment: NewsComment) {
        if let index = newsArticles.firstIndex(where: { $0.id == articleId }) {
            newsArticles[index].comments.append(comment)
            saveData()
        }
    }
    
    public func deleteComment(articleId: UUID, commentId: UUID) {
        if let index = newsArticles.firstIndex(where: { $0.id == articleId }) {
            newsArticles[index].comments.removeAll { $0.id == commentId }
            saveData()
        }
    }
    
    // MARK: - Clean All Data
    
    public func clearAllData() {
        announcements.removeAll()
        newsArticles.removeAll()
        UserDefaults.standard.removeObject(forKey: announcementsStorageKey)
        UserDefaults.standard.removeObject(forKey: newsStorageKey)
        UserDefaults.standard.removeObject(forKey: "workbench_announcements_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_news_v1")
        saveData()
    }
    
    // MARK: - Persistence
    
    public func saveData() {
        if let encodedAnnouncements = try? JSONEncoder().encode(announcements) {
            UserDefaults.standard.set(encodedAnnouncements, forKey: announcementsStorageKey)
        }
        if let encodedNews = try? JSONEncoder().encode(newsArticles) {
            UserDefaults.standard.set(encodedNews, forKey: newsStorageKey)
        }
    }
    
    public func loadData() {
        // Clear previous v1 storage if any
        UserDefaults.standard.removeObject(forKey: "workbench_announcements_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_news_v1")
        
        if let savedAnnouncementsData = UserDefaults.standard.data(forKey: announcementsStorageKey),
           let decoded = try? JSONDecoder().decode([Announcement].self, from: savedAnnouncementsData) {
            self.announcements = decoded
        } else {
            self.announcements = []
        }
        
        if let savedNewsData = UserDefaults.standard.data(forKey: newsStorageKey),
           let decoded = try? JSONDecoder().decode([NewsArticle].self, from: savedNewsData) {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date().addingTimeInterval(-365 * 86400)
            self.newsArticles = decoded
                .filter { article in
                    // Only keep Green Email articles within 1 rolling year
                    if article.category == .greenEmail {
                        return article.publishDate >= oneYearAgo
                    }
                    return true
                }
                .map { article in
                    var mod = article
                    if let html = mod.htmlContent {
                        mod.htmlContent = MailSyncService.cleanGreenEmailHTMLContent(html)
                    }
                    return mod
                }
        } else {
            self.newsArticles = []
        }
    }
}

public enum AppNavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "工作台首页"
    case announcements = "团队公告"
    case news = "重点资讯"
    case publish = "发布中心"
    case settings = "偏好设置"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .announcements: return "megaphone.fill"
        case .news: return "newspaper.fill"
        case .publish: return "square.and.pencil"
        case .settings: return "gearshape.fill"
        }
    }
}
