//
//  WorkbenchStore.swift
//  团队工作台
//

import Foundation
import AppKit
import Combine

@MainActor
public class WorkbenchStore: ObservableObject {
    @Published public var announcements: [Announcement] = []
    @Published public var newsArticles: [NewsArticle] = []
    @Published public var faqItems: [FAQItem] = []
    @Published public var teamMembers: [TeamMember] = []
    @Published public var currentUser: TeamMember = TeamMember.currentUser
    @Published public var searchText: String = ""
    @Published public var selectedNavigation: AppNavigationItem? = .dashboard
    @Published public var selectedNewsArticleID: UUID?
    @Published public var selectedAnnouncementID: UUID?
    @Published public var targetFAQItemID: UUID?
    @Published public var targetFAQCategory: String?
    
    private let announcementsStorageKey = "workbench_announcements_v3"
    private let newsStorageKey = "workbench_news_v3"
    private let faqStorageKey = "workbench_faq_v3"
    private let currentUserStorageKey = "workbench_current_user_v3"
    private let teamMembersStorageKey = "workbench_team_members_v3"
    
    public init() {
        loadData()
        
        // Listen for iCloud Shared Folder real-time change notifications
        NotificationCenter.default.addObserver(
            forName: .sharedFolderDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadDataFromSharedFolder()
        }
        
        // Listen for App active event to sync latest cloud changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if SharedFolderSyncService.shared.isConnected {
                self?.loadDataFromSharedFolder()
            }
        }
        
        // Periodic background silent sync polling (every 8 seconds when connected)
        Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            if SharedFolderSyncService.shared.isConnected {
                self?.loadDataFromSharedFolder()
            }
        }
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
            
            // Record acknowledgment record
            if !announcements[index].acknowledgments.contains(where: { $0.memberName == currentUser.name }) {
                let ack = AnnouncementAcknowledgment(
                    memberName: currentUser.name,
                    acknowledgedAt: Date()
                )
                announcements[index].acknowledgments.append(ack)
                
                // Write single ack file directly to shared folder if connected
                if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
                    let ackURL = baseURL.appendingPathComponent("acknowledgments/ack_\(id.uuidString)_\(currentUser.name).json")
                    let sharedAck = SharedAckRecord(announcementId: id, memberName: currentUser.name, acknowledgedAt: Date())
                    if let data = try? JSONEncoder().encode(sharedAck) {
                        try? data.write(to: ackURL)
                    }
                }
            }
            saveData()
        }
    }
    
    public static let mockNamesBlocklist: Set<String> = [
        "晨曦", "子轩", "晓峰", "雅婷", "浩然",
        "李明", "张伟", "王强", "陈静", "刘洋", "赵敏", "孙宇", "周杰", "吴磊",
        "团队", "系统", "AHA / SACS 团队", "AHA", "SACS", "测试用户", "亮亮"
    ]
    
    public static let presetFAQQuestionsBlocklist: Set<String> = [
        "Green Email 重点邮件的提取标准是什么？",
        "如何快速在 Core 知识库中打开对应知识文章？",
        "全员居家办公时，如何让团队电脑实时同步数据？",
        "公告发布后如何确认组员的阅读状态？"
    ]
    
    /// Dynamically aggregates all discovered team members across iCloud roster files, announcements authors, ack signatures and comments
    public var allDiscoveredTeamMembers: [TeamMember] {
        var knownNames = Set<String>()
        var list: [TeamMember] = []
        
        // 1. Current User
        let curr = currentUser.name.trimmingCharacters(in: .whitespaces)
        if !curr.isEmpty && !Self.mockNamesBlocklist.contains(curr) {
            knownNames.insert(curr)
            list.append(currentUser)
        }
        
        // 2. Explicit roster members from iCloud / local cache
        for m in teamMembers {
            let n = m.name.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty && !Self.mockNamesBlocklist.contains(n) && !knownNames.contains(n) {
                knownNames.insert(n)
                list.append(m)
            }
        }
        
        // 3. Authors and acknowledgment signers of all announcements
        for ann in announcements {
            let authorName = ann.author.trimmingCharacters(in: .whitespaces)
            if !authorName.isEmpty && !Self.mockNamesBlocklist.contains(authorName) && !knownNames.contains(authorName) {
                knownNames.insert(authorName)
                list.append(TeamMember(name: authorName))
            }
            
            for ack in ann.acknowledgments {
                let ackName = ack.memberName.trimmingCharacters(in: .whitespaces)
                if !ackName.isEmpty && !Self.mockNamesBlocklist.contains(ackName) && !knownNames.contains(ackName) {
                    knownNames.insert(ackName)
                    list.append(TeamMember(name: ackName))
                }
            }
        }
        
        // 4. Comment authors in News
        for news in newsArticles {
            for c in news.comments {
                let commentAuthor = c.author.trimmingCharacters(in: .whitespaces)
                if !commentAuthor.isEmpty && !Self.mockNamesBlocklist.contains(commentAuthor) && !knownNames.contains(commentAuthor) {
                    knownNames.insert(commentAuthor)
                    list.append(TeamMember(name: commentAuthor))
                }
            }
        }
        
        return list
    }
    
    public func unacknowledgedMembers(for announcement: Announcement) -> [TeamMember] {
        let ackNames = Set(announcement.acknowledgments.map { $0.memberName.trimmingCharacters(in: .whitespaces) })
        let allMembers = allDiscoveredTeamMembers
        return allMembers.filter { !ackNames.contains($0.name.trimmingCharacters(in: .whitespaces)) }
    }
    
    public func sendAcknowledgmentReminder(for announcement: Announcement) {
        let unacked = unacknowledgedMembers(for: announcement)
        guard !unacked.isEmpty else { return }
        let names = unacked.map { $0.name }.joined(separator: "、")
        NotificationService.shared.sendLocalNotification(
            title: "🔔 阅读提醒: " + announcement.title,
            subtitle: "已向 \(unacked.count) 位未读成员发送提醒",
            body: "未读成员: \(names)"
        )
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
        
        // Remove from shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let fileURL = baseURL.appendingPathComponent("announcements/announcement_\(id.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
        
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
        
        // Remove from shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let fileURL = baseURL.appendingPathComponent("news/news_\(id.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        saveData()
    }
    
    // MARK: - Actions: Comments
    
    public func addComment(to articleId: UUID, comment: NewsComment) {
        if let index = newsArticles.firstIndex(where: { $0.id == articleId }) {
            newsArticles[index].comments.append(comment)
            
            // Save comment record to shared folder if connected
            if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
                let commentURL = baseURL.appendingPathComponent("comments/comment_\(articleId.uuidString)_\(comment.id.uuidString).json")
                let sharedComment = SharedCommentRecord(articleId: articleId, comment: comment)
                if let data = try? JSONEncoder().encode(sharedComment) {
                    try? data.write(to: commentURL)
                }
            }
            
            saveData()
        }
    }
    
    public func deleteComment(articleId: UUID, commentId: UUID) {
        if let index = newsArticles.firstIndex(where: { $0.id == articleId }) {
            newsArticles[index].comments.removeAll { $0.id == commentId }
            
            // Delete comment file from shared folder if connected
            if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
                let commentURL = baseURL.appendingPathComponent("comments/comment_\(articleId.uuidString)_\(commentId.uuidString).json")
                try? FileManager.default.removeItem(at: commentURL)
            }
            
            saveData()
        }
    }
    
    // MARK: - Actions: FAQ
    
    public func addFAQItem(_ item: FAQItem) {
        faqItems.insert(item, at: 0)
        
        // Save to shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let faqURL = baseURL.appendingPathComponent("faq/faq_\(item.id.uuidString).json")
            if let data = try? JSONEncoder().encode(item) {
                try? data.write(to: faqURL)
            }
        }
        
        saveData()
    }
    
    public func updateFAQItem(_ item: FAQItem) {
        if let index = faqItems.firstIndex(where: { $0.id == item.id }) {
            faqItems[index] = item
            
            // Update in shared folder if connected
            if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
                let faqURL = baseURL.appendingPathComponent("faq/faq_\(item.id.uuidString).json")
                if let data = try? JSONEncoder().encode(item) {
                    try? data.write(to: faqURL)
                }
            }
            
            saveData()
        }
    }
    
    public func deleteFAQItem(id: UUID) {
        faqItems.removeAll { $0.id == id }
        
        // Remove from shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let faqURL = baseURL.appendingPathComponent("faq/faq_\(id.uuidString).json")
            try? FileManager.default.removeItem(at: faqURL)
        }
        
        saveData()
    }
    
    public func toggleBookmarkFAQ(id: UUID) {
        if let index = faqItems.firstIndex(where: { $0.id == id }) {
            faqItems[index].isBookmarked.toggle()
            saveData()
        }
    }
    
    // MARK: - Actions: User Identity
    
    public func updateCurrentUser(name: String, avatarSymbol: String) {
        let oldName = self.currentUser.name.trimmingCharacters(in: .whitespaces)
        let newName = name.trimmingCharacters(in: .whitespaces)
        self.currentUser.name = newName
        self.currentUser.avatarSymbol = avatarSymbol
        
        if !oldName.isEmpty && oldName != newName {
            migrateAuthor(from: oldName, to: newName)
        }
        
        saveData()
    }
    
    public func migrateAuthor(from oldName: String, to newName: String) {
        guard !oldName.isEmpty && !newName.isEmpty && oldName != newName else { return }
        
        // 1. Migrate announcements author & signatures
        for i in 0..<announcements.count {
            if announcements[i].author == oldName {
                announcements[i].author = newName
            }
            for j in 0..<announcements[i].acknowledgments.count {
                if announcements[i].acknowledgments[j].memberName == oldName {
                    announcements[i].acknowledgments[j].memberName = newName
                }
            }
        }
        
        // 2. Migrate news comments
        for i in 0..<newsArticles.count {
            if newsArticles[i].author == oldName {
                newsArticles[i].author = newName
            }
            for j in 0..<newsArticles[i].comments.count {
                if newsArticles[i].comments[j].author == oldName {
                    newsArticles[i].comments[j].author = newName
                }
            }
        }
        
        // 3. Migrate FAQs
        for i in 0..<faqItems.count {
            if faqItems[i].author == oldName {
                faqItems[i].author = newName
            }
        }
        
        // 4. Remove old roster file from cloud shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let oldRoster = baseURL.appendingPathComponent("roster/member_\(oldName).json")
            try? FileManager.default.removeItem(at: oldRoster)
        }
        
        teamMembers.removeAll { $0.name == oldName }
        if !teamMembers.contains(where: { $0.name == newName }) {
            teamMembers.append(currentUser)
        }
    }
    
    // MARK: - Clean All Data
    
    public func clearAllData() {
        announcements.removeAll()
        newsArticles.removeAll()
        faqItems.removeAll()
        UserDefaults.standard.removeObject(forKey: announcementsStorageKey)
        UserDefaults.standard.removeObject(forKey: newsStorageKey)
        UserDefaults.standard.removeObject(forKey: faqStorageKey)
        UserDefaults.standard.removeObject(forKey: "workbench_announcements_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_news_v1")
        saveData()
    }
    
    // MARK: - Persistence & Cloud Shared Folder Sync
    
    public func saveData() {
        // 1. Save to local fast cache
        if let encodedAnnouncements = try? JSONEncoder().encode(announcements) {
            UserDefaults.standard.set(encodedAnnouncements, forKey: announcementsStorageKey)
        }
        if let encodedNews = try? JSONEncoder().encode(newsArticles) {
            UserDefaults.standard.set(encodedNews, forKey: newsStorageKey)
        }
        if let encodedFAQ = try? JSONEncoder().encode(faqItems) {
            UserDefaults.standard.set(encodedFAQ, forKey: faqStorageKey)
        }
        if let encodedUser = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(encodedUser, forKey: currentUserStorageKey)
        }
        if let encodedMembers = try? JSONEncoder().encode(teamMembers) {
            UserDefaults.standard.set(encodedMembers, forKey: teamMembersStorageKey)
        }
        
        // 2. If connected to iCloud shared folder, write to shared storage
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            saveToSharedFolder(at: baseURL)
        }
    }
    
    private func saveToSharedFolder(at baseURL: URL) {
        let encoder = JSONEncoder()
        
        // Write announcements
        let annDir = baseURL.appendingPathComponent("announcements", isDirectory: true)
        for ann in announcements {
            let fileURL = annDir.appendingPathComponent("announcement_\(ann.id.uuidString).json")
            if let data = try? encoder.encode(ann) {
                try? data.write(to: fileURL)
            }
        }
        
        // Write Green Email & News Articles
        let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
        for article in newsArticles {
            let fileURL = newsDir.appendingPathComponent("news_\(article.id.uuidString).json")
            if let data = try? encoder.encode(article) {
                try? data.write(to: fileURL)
            }
        }
        
        // Write FAQs
        let faqDir = baseURL.appendingPathComponent("faq", isDirectory: true)
        for item in faqItems {
            let fileURL = faqDir.appendingPathComponent("faq_\(item.id.uuidString).json")
            if let data = try? encoder.encode(item) {
                try? data.write(to: fileURL)
            }
        }
        
        // Write current member presence to roster
        let rosterDir = baseURL.appendingPathComponent("roster", isDirectory: true)
        let memberURL = rosterDir.appendingPathComponent("member_\(currentUser.name).json")
        if let data = try? encoder.encode(currentUser) {
            try? data.write(to: memberURL)
        }
    }
    
    public func loadDataFromSharedFolder() {
        guard let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected else {
            return
        }
        
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        
        // 1. Read Announcements
        let annDir = baseURL.appendingPathComponent("announcements", isDirectory: true)
        var loadedAnnouncements: [Announcement] = []
        if let files = try? fileManager.contentsOfDirectory(at: annDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let ann = try? decoder.decode(Announcement.self, from: data) {
                    loadedAnnouncements.append(ann)
                }
            }
        }
        
        // 2. Read Acknowledgments
        let ackDir = baseURL.appendingPathComponent("acknowledgments", isDirectory: true)
        var ackMap: [UUID: [AnnouncementAcknowledgment]] = [:]
        if let files = try? fileManager.contentsOfDirectory(at: ackDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let ack = try? decoder.decode(SharedAckRecord.self, from: data) {
                    let record = AnnouncementAcknowledgment(
                        id: ack.id,
                        memberName: ack.memberName,
                        department: ack.department,
                        acknowledgedAt: ack.acknowledgedAt
                    )
                    ackMap[ack.announcementId, default: []].append(record)
                }
            }
        }
        
        // Attach acknowledgments and determine isAcknowledged for current user
        for i in 0..<loadedAnnouncements.count {
            let annId = loadedAnnouncements[i].id
            if let acks = ackMap[annId] {
                // Merge without duplicates
                var existingAcks = loadedAnnouncements[i].acknowledgments
                for ack in acks {
                    if !existingAcks.contains(where: { $0.memberName == ack.memberName }) {
                        existingAcks.append(ack)
                    }
                }
                loadedAnnouncements[i].acknowledgments = existingAcks
            }
            
            // Check if current user acknowledged
            let userAck = loadedAnnouncements[i].acknowledgments.first(where: { $0.memberName == currentUser.name })
            if let uAck = userAck {
                loadedAnnouncements[i].isAcknowledged = true
                loadedAnnouncements[i].acknowledgedAt = uAck.acknowledgedAt
            }
        }
        
        if !loadedAnnouncements.isEmpty {
            self.announcements = loadedAnnouncements.sorted { first, second in
                if first.isPinned != second.isPinned {
                    return first.isPinned && !second.isPinned
                }
                return first.publishDate > second.publishDate
            }
        }
        
        // 3. Read Green Email & News Articles
        let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
        var loadedNews: [NewsArticle] = []
        if let files = try? fileManager.contentsOfDirectory(at: newsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let article = try? decoder.decode(NewsArticle.self, from: data) {
                    loadedNews.append(article)
                }
            }
        }
        if !loadedNews.isEmpty {
            var mergedNews = self.newsArticles
            for newArt in loadedNews {
                if let existingIdx = mergedNews.firstIndex(where: { $0.title == newArt.title || $0.id == newArt.id }) {
                    mergedNews[existingIdx] = newArt
                } else {
                    mergedNews.append(newArt)
                }
            }
            self.newsArticles = mergedNews.sorted { $0.publishDate > $1.publishDate }
        }
        
        // 4. Read Comments
        let commentsDir = baseURL.appendingPathComponent("comments", isDirectory: true)
        if let files = try? fileManager.contentsOfDirectory(at: commentsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let sharedComment = try? decoder.decode(SharedCommentRecord.self, from: data) {
                    if let idx = self.newsArticles.firstIndex(where: { $0.id == sharedComment.articleId }) {
                        if !self.newsArticles[idx].comments.contains(where: { $0.id == sharedComment.comment.id }) {
                            self.newsArticles[idx].comments.append(sharedComment.comment)
                        }
                    }
                }
            }
        }
        
        // 5. Read FAQs
        let faqDir = baseURL.appendingPathComponent("faq", isDirectory: true)
        var loadedFAQs: [FAQItem] = []
        if let files = try? fileManager.contentsOfDirectory(at: faqDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let item = try? decoder.decode(FAQItem.self, from: data) {
                    if Self.presetFAQQuestionsBlocklist.contains(item.question) {
                        try? fileManager.removeItem(at: file)
                    } else {
                        loadedFAQs.append(item)
                    }
                }
            }
        }
        if !loadedFAQs.isEmpty {
            self.faqItems = loadedFAQs.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            self.faqItems.removeAll { Self.presetFAQQuestionsBlocklist.contains($0.question) }
        }
        
        // 6. Read Roster (All discovered active team members)
        let rosterDir = baseURL.appendingPathComponent("roster", isDirectory: true)
        
        // Purge any legacy mock member files from cloud directory
        for mock in Self.mockNamesBlocklist {
            let mockFile = rosterDir.appendingPathComponent("member_\(mock).json")
            if fileManager.fileExists(atPath: mockFile.path) {
                try? fileManager.removeItem(at: mockFile)
            }
        }
        
        var loadedMembers: [TeamMember] = []
        if let files = try? fileManager.contentsOfDirectory(at: rosterDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let member = try? decoder.decode(TeamMember.self, from: data) {
                    if !Self.mockNamesBlocklist.contains(member.name) {
                        loadedMembers.append(member)
                    }
                }
            }
        }
        if !loadedMembers.isEmpty {
            var merged = self.teamMembers.filter { !Self.mockNamesBlocklist.contains($0.name) }
            for m in loadedMembers {
                if !merged.contains(where: { $0.name == m.name }) {
                    merged.append(m)
                }
            }
            self.teamMembers = merged
        }
        if !self.teamMembers.contains(where: { $0.name == currentUser.name }) && !Self.mockNamesBlocklist.contains(currentUser.name) {
            self.teamMembers.append(currentUser)
        }
        
        // Clean any mock acks and migrate legacy author if needed
        if currentUser.name != "亮亮" {
            migrateAuthor(from: "亮亮", to: currentUser.name)
        }
        
        for i in 0..<self.announcements.count {
            self.announcements[i].acknowledgments.removeAll { Self.mockNamesBlocklist.contains($0.memberName) }
        }
        
        // Update local cache
        if let encodedAnnouncements = try? JSONEncoder().encode(announcements) {
            UserDefaults.standard.set(encodedAnnouncements, forKey: announcementsStorageKey)
        }
        if let encodedNews = try? JSONEncoder().encode(newsArticles) {
            UserDefaults.standard.set(encodedNews, forKey: newsStorageKey)
        }
        if let encodedFAQ = try? JSONEncoder().encode(faqItems) {
            UserDefaults.standard.set(encodedFAQ, forKey: faqStorageKey)
        }
        if let encodedMembers = try? JSONEncoder().encode(teamMembers) {
            UserDefaults.standard.set(encodedMembers, forKey: teamMembersStorageKey)
        }
    }
    
    public func forceSyncAllWithSharedFolder() {
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            saveToSharedFolder(at: baseURL)
            loadDataFromSharedFolder()
            SharedFolderSyncService.shared.lastSyncDate = Date()
            SharedFolderSyncService.shared.syncMessage = "全员数据云端双向同步完成"
        }
    }
    
    public func loadData() {
        // Clear all legacy mock roster caches from UserDefaults
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v2")
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v3")
        
        let userData = UserDefaults.standard.data(forKey: currentUserStorageKey) ?? UserDefaults.standard.data(forKey: "workbench_current_user_v1")
        if let data = userData, let decodedUser = try? JSONDecoder().decode(TeamMember.self, from: data) {
            self.currentUser = decodedUser
        } else {
            self.currentUser = TeamMember.currentUser
        }
        
        let membersData = UserDefaults.standard.data(forKey: teamMembersStorageKey)
        if let data = membersData, let decodedMembers = try? JSONDecoder().decode([TeamMember].self, from: data) {
            self.teamMembers = decodedMembers.filter { !Self.mockNamesBlocklist.contains($0.name) }
        } else {
            self.teamMembers = [currentUser]
        }
        
        let annData = UserDefaults.standard.data(forKey: announcementsStorageKey) ?? UserDefaults.standard.data(forKey: "workbench_announcements_v2")
        if let data = annData, let decoded = try? JSONDecoder().decode([Announcement].self, from: data) {
            self.announcements = decoded.map { ann in
                var mod = ann
                if self.currentUser.name != "亮亮" && mod.author == "亮亮" {
                    mod.author = self.currentUser.name
                }
                mod.acknowledgments.removeAll { Self.mockNamesBlocklist.contains($0.memberName) }
                return mod
            }
        } else {
            self.announcements = []
        }
        
        let newsData = UserDefaults.standard.data(forKey: newsStorageKey) ?? UserDefaults.standard.data(forKey: "workbench_news_v2")
        if let data = newsData, let decoded = try? JSONDecoder().decode([NewsArticle].self, from: data) {
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
        
        UserDefaults.standard.removeObject(forKey: "workbench_faq_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_faq_v2")
        UserDefaults.standard.removeObject(forKey: "workbench_faq_v3")
        
        let faqData = UserDefaults.standard.data(forKey: faqStorageKey)
        if let data = faqData, let decoded = try? JSONDecoder().decode([FAQItem].self, from: data) {
            self.faqItems = decoded.filter { !Self.presetFAQQuestionsBlocklist.contains($0.question) }
        } else {
            self.faqItems = []
        }
        
        // Ensure all pre-compiled Chorus Knowledge Base items are present (e.g. RCC / ARS / BTS / AA / SDA)
        var hasNewItems = false
        for entry in ChorusFAQSyncService.allEntries {
            let q = entry.question.trimmingCharacters(in: .whitespacesAndNewlines)
            if !self.faqItems.contains(where: { $0.question == q }) {
                let a = entry.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                var relatedId: String? = nil
                let pattern = #"(?<=\b)(10\d{4}|20\d{4}|30\d{4}|\d{6}|HT\d{6}|CP\d{6})(?=\b)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: a, options: [], range: NSRange(location: 0, length: a.utf16.count)),
                   let r = Range(match.range, in: a) {
                    relatedId = String(a[r])
                }
                
                var tags = [entry.category]
                if !entry.subCategory.isEmpty {
                    tags.append(entry.subCategory)
                }
                
                let item = FAQItem(
                    question: q,
                    answer: a,
                    category: entry.category,
                    tags: tags,
                    relatedArticleId: relatedId,
                    author: "Chorus 知识库",
                    updatedAt: Date()
                )
                self.faqItems.append(item)
                hasNewItems = true
            }
        }
        if hasNewItems {
            if let encodedFAQ = try? JSONEncoder().encode(self.faqItems) {
                UserDefaults.standard.set(encodedFAQ, forKey: faqStorageKey)
            }
        }
        
        // If shared folder is connected, load latest data from shared folder
        if SharedFolderSyncService.shared.isConnected {
            loadDataFromSharedFolder()
        }
    }
}

public enum AppNavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "首页概览"
    case announcements = "团队公告板"
    case news = "重要邮件与资讯"
    case faq = "常见知识FAQ"
    case publish = "发布中心"
    case settings = "偏好设置"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .announcements: return "megaphone.fill"
        case .news: return "envelope.fill"
        case .faq: return "questionmark.bubble.fill"
        case .publish: return "square.and.pencil"
        case .settings: return "gearshape.fill"
        }
    }
}
