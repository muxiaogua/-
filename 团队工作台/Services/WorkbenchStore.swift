//
//  WorkbenchStore.swift
//  团队工作台
//

import Foundation
import AppKit
import SwiftUI
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
    @Published public var selectedCategory: AppNavigationCategory = .dashboard
    @Published public var selectedNewsArticleID: UUID?
    @Published public var selectedAnnouncementID: UUID?
    @Published public var targetFAQItemID: UUID?
    @Published public var targetFAQCategory: String?
    @Published public var readNewsArticleIDs: Set<UUID> = []
    @Published public var readAnnouncementIDs: Set<UUID> = []
    @Published public var permissionConfig: TeamPermissionConfig = TeamPermissionConfig()
    @Published public var currentMemberShiftSchedule: MemberShiftSchedule = MemberShiftSchedule()
    @Published public var teamShiftSchedules: [MemberShiftSchedule] = []
    
    // 价格查询 (Device Price Query)
    @Published public var devicePrices: [DevicePriceItem] = []
    @Published public var priceApiUrl: String = ""
    @Published public var isSyncingPrices: Bool = false
    @Published public var priceSyncErrorMessage: String? = nil
    @Published public var lastPriceSyncTime: Date? = nil
    
    // NPI 邮件合集 (NPI Emails Collection)
    @Published public var npiEmails: [NewsArticle] = []
    @Published public var selectedNpiEmailID: UUID?
    @Published public var readNpiEmailIDs: Set<UUID> = []
    
    // 共享知识库 (Shared Knowledge Base)
    @Published public var knowledgeArticles: [SharedKnowledgeArticle] = []
    @Published public var selectedKnowledgeArticleID: UUID?
    @Published public var bookmarkedKnowledgeIDs: Set<UUID> = []
    
    // 一键总同步状态与时间
    @Published public var isMasterSyncing: Bool = false
    @Published public var masterSyncResult: MasterSyncResult?
    @Published public var lastMasterSyncTime: Date?
    @Published public var lastMasterSyncedBy: String?
    
    private let lastMasterSyncTimeKey = "workbench_last_master_sync_time"
    private let lastMasterSyncedByKey = "workbench_last_master_synced_by"
    
    private let knowledgeStorageKey = "workbench_shared_knowledge_v1"
    private let bookmarkedKnowledgeStorageKey = "workbench_bookmarked_knowledge_ids_v1"
    
    private let announcementsStorageKey = "workbench_announcements_v3"
    private let newsStorageKey = "workbench_news_v3"
    private let faqStorageKey = "workbench_faq_v3"
    private let currentUserStorageKey = "workbench_current_user_v3"
    private let teamMembersStorageKey = "workbench_team_members_v3"
    private let readNewsStorageKey = "workbench_read_news_ids_v1"
    private let readAnnouncementsStorageKey = "workbench_read_announcements_ids_v1"
    private let permissionsStorageKey = "workbench_permissions_v1"
    private let shiftsStorageKeyPrefix = "workbench_shift_schedule_v1_"
    private let devicePricesStorageKey = "workbench_device_prices_v1"
    private let priceApiUrlStorageKey = "workbench_price_api_url_v1"
    private let lastPriceSyncTimeStorageKey = "workbench_last_price_sync_time_v1"
    private let npiEmailsStorageKey = "workbench_npi_emails_v1"
    private let readNpiEmailStorageKey = "workbench_read_npi_email_ids_v1"
    
    public init() {
        loadData()
        
        // Listen for iCloud Shared Folder real-time change notifications (with debounce)
        NotificationCenter.default.addObserver(
            forName: .sharedFolderDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.triggerDebouncedSharedFolderReload()
        }
        
        // Listen for App active event to sync latest cloud changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if SharedFolderSyncService.shared.isConnected {
                self?.triggerDebouncedSharedFolderReload()
            }
        }
        
        // 启动后仅在后台静默广播一次在线名片，不与监听循环产生连锁反应
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.broadcastCurrentUserPresence()
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
    
    public var todayUnacknowledgedCount: Int {
        announcements.filter { item in
            Calendar.current.isDateInToday(item.publishDate) &&
            item.requiresAcknowledgment &&
            !item.isAcknowledged &&
            !item.acknowledgments.contains(where: { $0.memberName == currentUser.name })
        }.count
    }
    
    public var unreadAnnouncementsCount: Int {
        announcements.filter { item in
            let isAcked = item.isAcknowledged || item.acknowledgments.contains(where: { $0.memberName == currentUser.name })
            if item.requiresAcknowledgment {
                return !isAcked
            } else {
                return !readAnnouncementIDs.contains(item.id)
            }
        }.count
    }
    
    public var todayUnreadAnnouncementsCount: Int {
        announcements.filter { item in
            guard Calendar.current.isDateInToday(item.publishDate) else { return false }
            let isAcked = item.isAcknowledged || item.acknowledgments.contains(where: { $0.memberName == currentUser.name })
            if item.requiresAcknowledgment {
                return !isAcked
            } else {
                return !readAnnouncementIDs.contains(item.id)
            }
        }.count
    }
    
    public var unreadNewsCount: Int {
        newsArticles.filter { !readNewsArticleIDs.contains($0.id) }.count
    }
    
    public var unreadNpiEmailsCount: Int {
        npiEmails.filter { !readNpiEmailIDs.contains($0.id) }.count
    }
    
    public var todayUnreadNewsCount: Int {
        newsArticles.filter { article in
            Calendar.current.isDateInToday(article.publishDate) && !readNewsArticleIDs.contains(article.id)
        }.count
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
    
    // MARK: - Permissions & Role Management (RBAC)
    
    public func isDefaultAdmin(name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }
        return permissionConfig.defaultAdmins.contains { $0.lowercased() == clean }
    }
    
    public func permission(for memberName: String) -> MemberPermission {
        let name = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Default Super Admins (Jason and Beauty always have full permissions)
        if isDefaultAdmin(name: name) {
            return MemberPermission(
                memberName: name,
                isAdmin: true,
                canPublishAnnouncements: true,
                canSyncData: true,
                updatedAt: Date()
            )
        }
        
        if let custom = permissionConfig.permissions[name] {
            return custom
        }
        
        // Default regular member
        return MemberPermission(
            memberName: name,
            isAdmin: false,
            canPublishAnnouncements: false,
            canSyncData: false,
            updatedAt: Date()
        )
    }
    
    public var isCurrentUserAdmin: Bool {
        permission(for: currentUser.name).isAdmin
    }
    
    public var isCurrentUserSuperAdmin: Bool {
        isDefaultAdmin(name: currentUser.name)
    }
    
    public var canCurrentUserPublishAnnouncements: Bool {
        let perm = permission(for: currentUser.name)
        return perm.isAdmin || perm.canPublishAnnouncements
    }
    
    public var canCurrentUserSyncData: Bool {
        let perm = permission(for: currentUser.name)
        return perm.isAdmin || perm.canSyncData
    }
    
    /// 全局综合最新更新时间与更新人（优先取总同步记录，次取各子模块最新记录）
    public var latestUpdateDisplayInfo: (time: Date, by: String)? {
        if let t = lastMasterSyncTime {
            return (t, lastMasterSyncedBy ?? "")
        }
        var candidates: [(Date, String)] = []
        if let t = MailSyncService.shared.lastSyncTime {
            candidates.append((t, MailSyncService.shared.lastSyncedBy ?? ""))
        }
        if let t = NPIMailSyncService.shared.lastSyncTime {
            candidates.append((t, NPIMailSyncService.shared.lastSyncedBy ?? ""))
        }
        if let t = ChorusFAQSyncService.shared.lastSyncTime {
            candidates.append((t, ChorusFAQSyncService.shared.lastSyncedBy ?? ""))
        }
        if let best = candidates.max(by: { $0.0 < $1.0 }) {
            return (best.0, best.1)
        }
        if let t = SharedFolderSyncService.shared.lastSyncDate {
            return (t, "")
        }
        return nil
    }
    
    public func formatLatestSyncTime(_ date: Date, syncedBy: String) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        let timePart: String
        if cal.isDateInToday(date) {
            timeFormatter.dateFormat = "HH:mm"
            timePart = timeFormatter.string(from: date)
        } else {
            timeFormatter.dateFormat = "MM-dd HH:mm"
            timePart = timeFormatter.string(from: date)
        }
        if syncedBy.isEmpty {
            return "最近更新: \(timePart)"
        } else {
            return "最近更新: \(timePart) (\(syncedBy))"
        }
    }
    
    public func formatFullDateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df.string(from: date)
    }
    
    public func updatePermission(
        for memberName: String,
        isAdmin: Bool,
        canPublishAnnouncements: Bool,
        canSyncData: Bool
    ) {
        let name = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        // Prevent modifying hardcoded default super admins
        if isDefaultAdmin(name: name) {
            return
        }
        
        let newPerm = MemberPermission(
            memberName: name,
            isAdmin: isAdmin,
            canPublishAnnouncements: canPublishAnnouncements || isAdmin,
            canSyncData: canSyncData || isAdmin,
            updatedAt: Date()
        )
        
        permissionConfig.permissions[name] = newPerm
        permissionConfig.lastModifiedAt = Date()
        saveData()
    }
    
    public func deletePermission(for memberName: String) {
        let name = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isDefaultAdmin(name: name) else { return }
        permissionConfig.permissions.removeValue(forKey: name)
        permissionConfig.lastModifiedAt = Date()
        saveData()
    }
    
    // MARK: - Shift Schedule (Apple Shifts)
    
    public var todayDateString: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
    
    public var todayShift: DayShift? {
        currentMemberShiftSchedule.days.first { $0.dateStr == todayDateString }
    }
    
    public func saveShiftSchedule(_ schedule: MemberShiftSchedule) {
        var updated = schedule
        updated.updatedAt = Date()
        self.currentMemberShiftSchedule = updated
        
        // 1. Save to personal local storage
        let key = shiftsStorageKeyPrefix + currentUser.name
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        // 2. If user chose to share with team, upload to iCloud shared folder
        if updated.isSharedToTeam {
            syncMySharedScheduleToCloud(updated)
        } else {
            removeMySharedScheduleFromCloud()
        }
    }
    
    public func toggleShareScheduleToTeam(isShared: Bool) {
        var updated = currentMemberShiftSchedule
        updated.isSharedToTeam = isShared
        updated.sharedAt = isShared ? Date() : nil
        saveShiftSchedule(updated)
    }
    
    private func syncMySharedScheduleToCloud(_ schedule: MemberShiftSchedule) {
        guard let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected else { return }
        let shiftsDir = baseURL.appendingPathComponent("shifts", isDirectory: true)
        try? FileManager.default.createDirectory(at: shiftsDir, withIntermediateDirectories: true)
        let fileURL = shiftsDir.appendingPathComponent("shift_\(currentUser.name).json")
        if let data = try? JSONEncoder().encode(schedule) {
            try? data.write(to: fileURL)
        }
    }
    
    private func removeMySharedScheduleFromCloud() {
        guard let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected else { return }
        let shiftsDir = baseURL.appendingPathComponent("shifts", isDirectory: true)
        let fileURL = shiftsDir.appendingPathComponent("shift_\(currentUser.name).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    public func loadShiftSchedule(for memberName: String) {
        let clean = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        // Load from personal local storage
        let key = shiftsStorageKeyPrefix + clean
        if let data = UserDefaults.standard.data(forKey: key),
           let schedule = try? JSONDecoder().decode(MemberShiftSchedule.self, from: data) {
            self.currentMemberShiftSchedule = schedule
        } else {
            self.currentMemberShiftSchedule = MemberShiftSchedule(memberName: clean, updatedAt: Date(), days: [])
        }
    }
    
    // MARK: - Actions: Read Status Tracking
    
    public func markNewsArticleAsRead(id: UUID) {
        if !readNewsArticleIDs.contains(id) {
            readNewsArticleIDs.insert(id)
            let array = readNewsArticleIDs.map { $0.uuidString }
            UserDefaults.standard.set(array, forKey: readNewsStorageKey)
        }
    }
    
    public func markAllNewsArticlesAsRead() {
        for article in newsArticles {
            readNewsArticleIDs.insert(article.id)
        }
        let array = readNewsArticleIDs.map { $0.uuidString }
        UserDefaults.standard.set(array, forKey: readNewsStorageKey)
    }
    
    public func markNpiEmailAsRead(id: UUID) {
        if !readNpiEmailIDs.contains(id) {
            readNpiEmailIDs.insert(id)
            let array = readNpiEmailIDs.map { $0.uuidString }
            UserDefaults.standard.set(array, forKey: readNpiEmailStorageKey)
        }
    }
    
    public func markAllNpiEmailsAsRead() {
        for email in npiEmails {
            readNpiEmailIDs.insert(email.id)
        }
        let array = readNpiEmailIDs.map { $0.uuidString }
        UserDefaults.standard.set(array, forKey: readNpiEmailStorageKey)
    }
    
    public func toggleNpiEmailBookmark(id: UUID) {
        if let index = npiEmails.firstIndex(where: { $0.id == id }) {
            npiEmails[index].isBookmarked.toggle()
            saveNpiEmails()
        }
    }
    
    public func saveNpiEmails() {
        if let encoded = try? JSONEncoder().encode(npiEmails) {
            UserDefaults.standard.set(encoded, forKey: npiEmailsStorageKey)
        }
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let npiDir = baseURL.appendingPathComponent("npi_emails", isDirectory: true)
            try? FileManager.default.createDirectory(at: npiDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            for item in npiEmails {
                let fileURL = npiDir.appendingPathComponent("email_\(item.id.uuidString).json")
                if let data = try? encoder.encode(item) {
                    try? data.write(to: fileURL)
                }
            }
        }
    }
    
    // MARK: - Actions: 共享知识库 (Shared Knowledge Base)
    
    public func saveKnowledgeArticles() {
        if let encoded = try? JSONEncoder().encode(knowledgeArticles) {
            UserDefaults.standard.set(encoded, forKey: knowledgeStorageKey)
        }
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let articlesToSave = self.knowledgeArticles
            DispatchQueue.global(qos: .utility).async {
                let knowledgeDir = baseURL.appendingPathComponent("shared_knowledge", isDirectory: true)
                try? FileManager.default.createDirectory(at: knowledgeDir, withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                for article in articlesToSave {
                    let fileURL = knowledgeDir.appendingPathComponent("knowledge_\(article.id.uuidString).json")
                    if let data = try? encoder.encode(article) {
                        try? data.write(to: fileURL)
                    }
                }
            }
        }
        self.objectWillChange.send()
    }
    
    public func addKnowledgeArticle(_ article: SharedKnowledgeArticle) {
        knowledgeArticles.insert(article, at: 0)
        saveKnowledgeArticles()
    }
    
    public func updateKnowledgeArticle(_ article: SharedKnowledgeArticle) {
        if let idx = knowledgeArticles.firstIndex(where: { $0.id == article.id }) {
            var updated = article
            updated.updatedAt = Date()
            knowledgeArticles[idx] = updated
            saveKnowledgeArticles()
        }
    }
    
    public func deleteKnowledgeArticle(id: UUID) {
        knowledgeArticles.removeAll { $0.id == id }
        bookmarkedKnowledgeIDs.remove(id)
        let array = bookmarkedKnowledgeIDs.map { $0.uuidString }
        UserDefaults.standard.set(array, forKey: bookmarkedKnowledgeStorageKey)
        
        saveKnowledgeArticles()
        
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            DispatchQueue.global(qos: .utility).async {
                let fileURL = baseURL.appendingPathComponent("shared_knowledge/knowledge_\(id.uuidString).json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    public func toggleKnowledgeHelpful(id: UUID) {
        if let idx = knowledgeArticles.firstIndex(where: { $0.id == id }) {
            let userName = currentUser.name
            if knowledgeArticles[idx].helpfulUserNames.contains(userName) {
                knowledgeArticles[idx].helpfulUserNames.removeAll { $0 == userName }
            } else {
                knowledgeArticles[idx].helpfulUserNames.append(userName)
            }
            saveKnowledgeArticles()
        }
    }
    
    public func toggleKnowledgeBookmark(id: UUID) {
        if bookmarkedKnowledgeIDs.contains(id) {
            bookmarkedKnowledgeIDs.remove(id)
        } else {
            bookmarkedKnowledgeIDs.insert(id)
        }
        let array = bookmarkedKnowledgeIDs.map { $0.uuidString }
        UserDefaults.standard.set(array, forKey: bookmarkedKnowledgeStorageKey)
        self.objectWillChange.send()
    }
    
    public func toggleKnowledgePin(id: UUID) {
        guard canCurrentUserPublishAnnouncements || isCurrentUserAdmin else { return }
        if let idx = knowledgeArticles.firstIndex(where: { $0.id == id }) {
            knowledgeArticles[idx].isPinned.toggle()
            saveKnowledgeArticles()
        }
    }
    
    public func addKnowledgeComment(articleID: UUID, content: String) {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let idx = knowledgeArticles.firstIndex(where: { $0.id == articleID }) {
            let comment = KnowledgeComment(author: currentUser.name, content: clean)
            knowledgeArticles[idx].comments.append(comment)
            saveKnowledgeArticles()
        }
    }
    
    public func markAnnouncementAsRead(id: UUID) {
        if !readAnnouncementIDs.contains(id) {
            readAnnouncementIDs.insert(id)
            let array = readAnnouncementIDs.map { $0.uuidString }
            UserDefaults.standard.set(array, forKey: readAnnouncementsStorageKey)
        }
    }
    
    public func markAllAnnouncementsAsRead() {
        for item in announcements {
            readAnnouncementIDs.insert(item.id)
        }
        let array = readAnnouncementIDs.map { $0.uuidString }
        UserDefaults.standard.set(array, forKey: readAnnouncementsStorageKey)
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
    
    // MARK: - Actions: Device Price Query (REST API 实时同步引擎)
    
    public func syncPricesFromAPI(customUrl: String? = nil) async {
        let targetUrlStr = (customUrl ?? self.priceApiUrl).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: targetUrlStr), !targetUrlStr.isEmpty else {
            self.priceSyncErrorMessage = "请输入有效的 API 接口 URL (例如 https://example.com/api/prices)"
            return
        }
        
        self.isSyncingPrices = true
        self.priceSyncErrorMessage = nil
        self.priceApiUrl = targetUrlStr
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15.0
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Optimus-TeamWorkbench-Mac", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "PriceSyncError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器响应错误 (HTTP \(httpResponse.statusCode))"])
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try standard array first, then wrapped response
            var parsedPrices: [DevicePriceItem] = []
            if let directList = try? decoder.decode([DevicePriceItem].self, from: data) {
                parsedPrices = directList
            } else if let wrapped = try? decoder.decode(PriceApiResponse.self, from: data), let list = wrapped.data {
                parsedPrices = list
            } else {
                throw NSError(domain: "PriceParseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON 格式不匹配，期望 [DevicePriceItem] 数组或 { data: [DevicePriceItem] }"])
            }
            
            self.devicePrices = parsedPrices
            self.lastPriceSyncTime = Date()
            self.isSyncingPrices = false
            self.saveData()
        } catch {
            self.isSyncingPrices = false
            self.priceSyncErrorMessage = error.localizedDescription
        }
    }
    
    public func clearAllDevicePrices() {
        self.devicePrices.removeAll()
        self.lastPriceSyncTime = nil
        self.priceSyncErrorMessage = nil
        self.saveData()
    }
    
    // MARK: - Actions: User Identity
    
    public func updateCurrentUser(name: String, avatarSymbol: String) {
        let oldName = self.currentUser.name.trimmingCharacters(in: .whitespaces)
        let newName = name.trimmingCharacters(in: .whitespaces)
        
        objectWillChange.send()
        self.currentUser = TeamMember(id: self.currentUser.id, name: newName, avatarSymbol: avatarSymbol)
        
        if !oldName.isEmpty && oldName != newName {
            migrateAuthor(from: oldName, to: newName)
        }
        
        saveData()
        loadShiftSchedule(for: newName)
    }
    
    public func migrateAuthor(from oldName: String, to newName: String) {
        guard !oldName.isEmpty && !newName.isEmpty && oldName != newName else { return }
        // 切勿在切换测试身份（如 TestUser）时迁移历史真实成员签名
        guard oldName != "TestUser" && newName != "TestUser" else { return }
        
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
            // 确保签名绝无重复人员
            var uniqueMap: [String: AnnouncementAcknowledgment] = [:]
            for ack in announcements[i].acknowledgments {
                let name = ack.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                if let ex = uniqueMap[name] {
                    if ack.acknowledgedAt > ex.acknowledgedAt { uniqueMap[name] = ack }
                } else {
                    uniqueMap[name] = ack
                }
            }
            announcements[i].acknowledgments = Array(uniqueMap.values).sorted { $0.acknowledgedAt < $1.acknowledgedAt }
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
        broadcastCurrentUserPresence()
    }
    
    // MARK: - 删除无效/测试/出错的成员名片 (管理员/超管可用)
    public func removeMember(name: String) {
        guard !isDefaultAdmin(name: name) else { return }
        
        // 1. 本地移除
        teamMembers.removeAll { $0.name == name }
        permissionConfig.permissions.removeValue(forKey: name)
        
        // 2. 从云端共享文件夹的 roster/ 目录物理删除
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let rosterFile = baseURL.appendingPathComponent("roster/member_\(name).json")
            try? FileManager.default.removeItem(at: rosterFile)
        }
        
        saveData()
        self.objectWillChange.send()
    }
    
    // MARK: - 主动向团队共享文件夹报到与广播名片 (确保其他成员能即时看见)
    public func broadcastCurrentUserPresence() {
        guard let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected else {
            return
        }
        
        let usr = self.currentUser
        // 过滤空名或非法名
        guard !usr.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if Self.mockNamesBlocklist.contains(usr.name) { return }
        
        DispatchQueue.global(qos: .utility).async {
            let rosterDir = baseURL.appendingPathComponent("roster", isDirectory: true)
            try? FileManager.default.createDirectory(at: rosterDir, withIntermediateDirectories: true)
            let memberURL = rosterDir.appendingPathComponent("member_\(usr.name).json")
            if let data = try? JSONEncoder().encode(usr) {
                try? data.write(to: memberURL)
            }
        }
    }
    
    // MARK: - Clean All Data
    
    public func clearAllNewsArticles() {
        guard isDefaultAdmin(name: currentUser.name) else { return }
        
        newsArticles.removeAll()
        readNewsArticleIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: newsStorageKey)
        UserDefaults.standard.removeObject(forKey: readNewsStorageKey)
        UserDefaults.standard.removeObject(forKey: "workbench_news_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_news_v2")
        UserDefaults.standard.removeObject(forKey: "workbench_last_mail_sync_date")
        UserDefaults.standard.removeObject(forKey: "workbench_last_mail_synced_by")
        MailSyncService.shared.lastSyncTime = nil
        MailSyncService.shared.lastSyncedBy = nil
        
        // Remove news files and sync_meta from shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
            if let files = try? FileManager.default.contentsOfDirectory(at: newsDir, includingPropertiesForKeys: nil) {
                for f in files {
                    try? FileManager.default.removeItem(at: f)
                }
            }
        }
        saveData()
        self.objectWillChange.send()
    }
    
    // MARK: - 清空本地数据（所有成员可用，不影响他人与云端共享数据）
    public func clearAllLocalData() {
        announcements.removeAll()
        newsArticles.removeAll()
        npiEmails.removeAll()
        faqItems.removeAll()
        knowledgeArticles.removeAll()
        bookmarkedKnowledgeIDs.removeAll()
        readNewsArticleIDs.removeAll()
        readAnnouncementIDs.removeAll()
        readNpiEmailIDs.removeAll()
        currentMemberShiftSchedule = MemberShiftSchedule(memberName: currentUser.name, updatedAt: Date(), days: [])
        
        UserDefaults.standard.removeObject(forKey: announcementsStorageKey)
        UserDefaults.standard.removeObject(forKey: newsStorageKey)
        UserDefaults.standard.removeObject(forKey: npiEmailsStorageKey)
        UserDefaults.standard.removeObject(forKey: faqStorageKey)
        UserDefaults.standard.removeObject(forKey: knowledgeStorageKey)
        UserDefaults.standard.removeObject(forKey: bookmarkedKnowledgeStorageKey)
        UserDefaults.standard.removeObject(forKey: readNewsStorageKey)
        UserDefaults.standard.removeObject(forKey: readAnnouncementsStorageKey)
        UserDefaults.standard.removeObject(forKey: readNpiEmailStorageKey)
        UserDefaults.standard.removeObject(forKey: shiftsStorageKeyPrefix + currentUser.name)
        UserDefaults.standard.removeObject(forKey: "workbench_announcements_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_news_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_last_mail_sync_date")
        UserDefaults.standard.removeObject(forKey: "workbench_last_mail_synced_by")
        UserDefaults.standard.removeObject(forKey: "workbench_last_npi_mail_sync_date")
        UserDefaults.standard.removeObject(forKey: "workbench_last_npi_mail_synced_by")
        
        MailSyncService.shared.lastSyncTime = nil
        MailSyncService.shared.lastSyncedBy = nil
        NPIMailSyncService.shared.lastSyncTime = nil
        NPIMailSyncService.shared.lastSyncedBy = nil
        
        // 仅在本地持久化层写入空数据，严禁删除云端共享文件夹的文件
        if let encodedAnnouncements = try? JSONEncoder().encode(announcements) {
            UserDefaults.standard.set(encodedAnnouncements, forKey: announcementsStorageKey)
        }
        if let encodedNews = try? JSONEncoder().encode(newsArticles) {
            UserDefaults.standard.set(encodedNews, forKey: newsStorageKey)
        }
        if let encodedNpi = try? JSONEncoder().encode(npiEmails) {
            UserDefaults.standard.set(encodedNpi, forKey: npiEmailsStorageKey)
        }
        if let encodedFaqs = try? JSONEncoder().encode(faqItems) {
            UserDefaults.standard.set(encodedFaqs, forKey: faqStorageKey)
        }
        
        self.objectWillChange.send()
    }
    
    public func clearAllData() {
        guard isDefaultAdmin(name: currentUser.name) else { return }
        clearAllLocalData()
    }
    
    // MARK: - Persistence & Cloud Shared Folder Sync
    
    /// Incremental save specifically for News/Green Email to prevent freezing UI by re-encoding all unrelated store models
    public func saveNewsArticlesOnly() {
        if let encodedNews = try? JSONEncoder().encode(newsArticles) {
            UserDefaults.standard.set(encodedNews, forKey: newsStorageKey)
        }
        
        // Write incrementally to iCloud Shared Folder if connected in background
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let articlesToSave = self.newsArticles
            DispatchQueue.global(qos: .utility).async {
                let encoder = JSONEncoder()
                let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
                try? FileManager.default.createDirectory(at: newsDir, withIntermediateDirectories: true)
                for article in articlesToSave {
                    let fileURL = newsDir.appendingPathComponent("news_\(article.id.uuidString).json")
                    if let data = try? encoder.encode(article) {
                        try? data.write(to: fileURL)
                    }
                }
            }
        }
    }
    
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
        if let encodedPerms = try? JSONEncoder().encode(permissionConfig) {
            UserDefaults.standard.set(encodedPerms, forKey: permissionsStorageKey)
        }
        if let encodedPrices = try? JSONEncoder().encode(devicePrices) {
            UserDefaults.standard.set(encodedPrices, forKey: devicePricesStorageKey)
        }
        if let encodedKnowledge = try? JSONEncoder().encode(knowledgeArticles) {
            UserDefaults.standard.set(encodedKnowledge, forKey: knowledgeStorageKey)
        }
        UserDefaults.standard.set(priceApiUrl, forKey: priceApiUrlStorageKey)
        if let lastSync = lastPriceSyncTime {
            UserDefaults.standard.set(lastSync.timeIntervalSince1970, forKey: lastPriceSyncTimeStorageKey)
        }
        
        // 2. If connected to iCloud shared folder, write to shared storage in background to avoid freezing UI
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let currentAnn = self.announcements
            let currentNews = self.newsArticles
            let currentFaq = self.faqItems
            let currentUsr = self.currentUser
            let currentPerm = self.permissionConfig
            let currentKnowledge = self.knowledgeArticles
            
            DispatchQueue.global(qos: .utility).async {
                let encoder = JSONEncoder()
                
                // Write announcements
                let annDir = baseURL.appendingPathComponent("announcements", isDirectory: true)
                try? FileManager.default.createDirectory(at: annDir, withIntermediateDirectories: true)
                for ann in currentAnn {
                    let fileURL = annDir.appendingPathComponent("announcement_\(ann.id.uuidString).json")
                    if let data = try? encoder.encode(ann) {
                        try? data.write(to: fileURL)
                    }
                }
                
                // Write Green Email & News Articles
                let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
                try? FileManager.default.createDirectory(at: newsDir, withIntermediateDirectories: true)
                for article in currentNews {
                    let fileURL = newsDir.appendingPathComponent("news_\(article.id.uuidString).json")
                    if let data = try? encoder.encode(article) {
                        try? data.write(to: fileURL)
                    }
                }
                
                // Write FAQs
                let faqDir = baseURL.appendingPathComponent("faq", isDirectory: true)
                try? FileManager.default.createDirectory(at: faqDir, withIntermediateDirectories: true)
                for item in currentFaq {
                    let fileURL = faqDir.appendingPathComponent("faq_\(item.id.uuidString).json")
                    if let data = try? encoder.encode(item) {
                        try? data.write(to: fileURL)
                    }
                }
                
                // Write current member presence to roster
                let rosterDir = baseURL.appendingPathComponent("roster", isDirectory: true)
                try? FileManager.default.createDirectory(at: rosterDir, withIntermediateDirectories: true)
                let memberURL = rosterDir.appendingPathComponent("member_\(currentUsr.name).json")
                if let data = try? encoder.encode(currentUsr) {
                    try? data.write(to: memberURL)
                }
                
                // Write permissions config
                let permDir = baseURL.appendingPathComponent("permissions", isDirectory: true)
                try? FileManager.default.createDirectory(at: permDir, withIntermediateDirectories: true)
                let permURL = permDir.appendingPathComponent("permissions.json")
                if let data = try? encoder.encode(currentPerm) {
                    try? data.write(to: permURL)
                }
                
                // Write shared knowledge articles
                let knowledgeDir = baseURL.appendingPathComponent("shared_knowledge", isDirectory: true)
                try? FileManager.default.createDirectory(at: knowledgeDir, withIntermediateDirectories: true)
                for article in currentKnowledge {
                    let fileURL = knowledgeDir.appendingPathComponent("knowledge_\(article.id.uuidString).json")
                    if let data = try? encoder.encode(article) {
                        try? data.write(to: fileURL)
                    }
                }
            }
        }
    }
    
    // 防抖与后台互斥加载，彻底杜绝主线程卡顿与死循环
    private var isSharedFolderLoading = false
    private var pendingSharedFolderReloadTask: DispatchWorkItem? = nil
    
    public func triggerDebouncedSharedFolderReload() {
        pendingSharedFolderReloadTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.loadDataFromSharedFolder()
        }
        pendingSharedFolderReloadTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: task)
    }
    
    public func loadDataFromSharedFolder() {
        guard let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected else {
            return
        }
        
        // 如果后台正在解码加载，直接跳过，防止并发轰炸磁盘
        if isSharedFolderLoading { return }
        isSharedFolderLoading = true
        
        let currentUserName = self.currentUser.name
        let currentArticles = self.newsArticles
        let currentMembers = self.teamMembers
        
        // 彻底将磁盘扫描与 JSON 解析移至后台工作线程执行，主线程零卡顿
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
            
            for i in 0..<loadedAnnouncements.count {
                let annId = loadedAnnouncements[i].id
                var allAcks = loadedAnnouncements[i].acknowledgments
                if let acks = ackMap[annId] {
                    allAcks.append(contentsOf: acks)
                }
                
                // 严格去重：每个成员在单条公告中最多且仅有一条已读确认记录
                var uniqueMap: [String: AnnouncementAcknowledgment] = [:]
                for ack in allAcks {
                    let name = ack.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !Self.mockNamesBlocklist.contains(name), name != "TestUser" else { continue }
                    if let ex = uniqueMap[name] {
                        if ack.acknowledgedAt > ex.acknowledgedAt {
                            uniqueMap[name] = ack
                        }
                    } else {
                        uniqueMap[name] = ack
                    }
                }
                loadedAnnouncements[i].acknowledgments = Array(uniqueMap.values).sorted { $0.acknowledgedAt < $1.acknowledgedAt }
                
                let userAck = loadedAnnouncements[i].acknowledgments.first(where: { $0.memberName == currentUserName })
                if let uAck = userAck {
                    loadedAnnouncements[i].isAcknowledged = true
                    loadedAnnouncements[i].acknowledgedAt = uAck.acknowledgedAt
                } else {
                    loadedAnnouncements[i].isAcknowledged = false
                }
            }
            
            let sortedAnnouncements = loadedAnnouncements.sorted { first, second in
                if first.isPinned != second.isPinned {
                    return first.isPinned && !second.isPinned
                }
                return first.publishDate > second.publishDate
            }
            
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date().addingTimeInterval(-365 * 86400)
            
            // 3. Read Green Email & News Articles
            let newsDir = baseURL.appendingPathComponent("news", isDirectory: true)
            var loadedNews: [NewsArticle] = []
            if let files = try? fileManager.contentsOfDirectory(at: newsDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let article = try? decoder.decode(NewsArticle.self, from: data) {
                        let lowerTitle = article.title.lowercased()
                        let isTestMail = lowerTitle.contains("(test)") || lowerTitle.contains("[test]") || lowerTitle.contains(" test ") || lowerTitle.hasPrefix("test") || lowerTitle.contains("测试") || lowerTitle.contains("(practice)") || lowerTitle.contains("[practice]") || lowerTitle.contains("practice") || lowerTitle.contains("演练")
                        
                        if isTestMail || article.publishDate < oneYearAgo {
                            try? fileManager.removeItem(at: file)
                        } else {
                            loadedNews.append(article)
                        }
                    }
                }
            }
            
            var mergedNews = currentArticles.filter { $0.publishDate >= oneYearAgo }
            for newArt in loadedNews where newArt.publishDate >= oneYearAgo {
                if let existingIdx = mergedNews.firstIndex(where: { $0.title == newArt.title || $0.id == newArt.id }) {
                    mergedNews[existingIdx] = newArt
                } else {
                    mergedNews.append(newArt)
                }
            }
            let sortedNews = mergedNews.sorted { $0.publishDate > $1.publishDate }
            
            // 4. Read Comments
            let commentsDir = baseURL.appendingPathComponent("comments", isDirectory: true)
            var commentsToMerge: [SharedCommentRecord] = []
            if let files = try? fileManager.contentsOfDirectory(at: commentsDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let sharedComment = try? decoder.decode(SharedCommentRecord.self, from: data) {
                        commentsToMerge.append(sharedComment)
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
            let sortedFAQs = loadedFAQs.sorted { $0.updatedAt > $1.updatedAt }
            
            // 6. Read Roster
            let rosterDir = baseURL.appendingPathComponent("roster", isDirectory: true)
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
            
            var mergedMembers = currentMembers.filter { !Self.mockNamesBlocklist.contains($0.name) }
            for m in loadedMembers {
                if !mergedMembers.contains(where: { $0.name == m.name }) {
                    mergedMembers.append(m)
                }
            }
            
            // 7. Read Permissions
            var loadedConfig: TeamPermissionConfig? = nil
            let permURL = baseURL.appendingPathComponent("permissions/permissions.json")
            if let data = try? Data(contentsOf: permURL),
               let config = try? decoder.decode(TeamPermissionConfig.self, from: data) {
                loadedConfig = config
            }
            
            // 8. Read Shifts
            let shiftsDir = baseURL.appendingPathComponent("shifts", isDirectory: true)
            var loadedTeamShifts: [MemberShiftSchedule] = []
            if let files = try? fileManager.contentsOfDirectory(at: shiftsDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let schedule = try? decoder.decode(MemberShiftSchedule.self, from: data) {
                        if schedule.isSharedToTeam {
                            loadedTeamShifts.append(schedule)
                        }
                    }
                }
            }
            let sortedTeamShifts = loadedTeamShifts.sorted { $0.memberName < $1.memberName }
            
            // 9. Read NPI Emails
            let npiDir = baseURL.appendingPathComponent("npi_emails", isDirectory: true)
            var loadedNpiEmails: [NewsArticle] = []
            if let files = try? fileManager.contentsOfDirectory(at: npiDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let article = try? decoder.decode(NewsArticle.self, from: data) {
                        let isSenderMatch = article.source.lowercased().contains("fy26_gc_npicomms@apple.com")
                        let isTitleMatch = article.title.contains("🔥") && (article.title.contains("[FY26 GC NPI]") || article.title.lowercased().contains("fy26 gc npi"))
                        let isTest = article.title.contains("[TEST NPI]") || article.title.contains("联调测试")
                        if isTest {
                            try? fileManager.removeItem(at: file)
                        } else if isSenderMatch && isTitleMatch && article.publishDate >= oneYearAgo {
                            loadedNpiEmails.append(article)
                        } else {
                            try? fileManager.removeItem(at: file)
                        }
                    }
                }
            }
            
            // 10. Read Sync Meta for Important Emails, NPI Emails and FAQ
            let newsMetaURL = baseURL.appendingPathComponent("news/sync_meta.json")
            var loadedNewsMeta: SyncMetaRecord? = nil
            if let data = try? Data(contentsOf: newsMetaURL),
               let meta = try? decoder.decode(SyncMetaRecord.self, from: data) {
                loadedNewsMeta = meta
            }
            
            let npiMetaURL = baseURL.appendingPathComponent("npi_emails/sync_meta.json")
            var loadedNpiMeta: SyncMetaRecord? = nil
            if let data = try? Data(contentsOf: npiMetaURL),
               let meta = try? decoder.decode(SyncMetaRecord.self, from: data) {
                loadedNpiMeta = meta
            }
            
            let faqMetaURL = baseURL.appendingPathComponent("faq/sync_meta.json")
            var loadedFaqMeta: SyncMetaRecord? = nil
            if let data = try? Data(contentsOf: faqMetaURL),
               let meta = try? decoder.decode(SyncMetaRecord.self, from: data) {
                loadedFaqMeta = meta
            }
            
            let masterMetaURL = baseURL.appendingPathComponent("master_sync_meta.json")
            var loadedMasterMeta: SyncMetaRecord? = nil
            if let data = try? Data(contentsOf: masterMetaURL),
               let meta = try? decoder.decode(SyncMetaRecord.self, from: data) {
                loadedMasterMeta = meta
            }
            
            // 12. Read Shared Knowledge Base
            let kDir = baseURL.appendingPathComponent("shared_knowledge", isDirectory: true)
            var loadedKnowledge: [SharedKnowledgeArticle] = []
            if let files = try? fileManager.contentsOfDirectory(at: kDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                       let article = try? decoder.decode(SharedKnowledgeArticle.self, from: data) {
                        loadedKnowledge.append(article)
                    }
                }
            }
            
            // 回到主线程单次原子性刷新 UI，彻底消灭界面阻塞
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let meta = loadedMasterMeta {
                    if self.lastMasterSyncTime == nil || meta.lastSyncTime >= (self.lastMasterSyncTime ?? .distantPast) {
                        self.lastMasterSyncTime = meta.lastSyncTime
                        self.lastMasterSyncedBy = meta.syncedBy
                    }
                }
                
                if let meta = loadedNewsMeta {
                    if MailSyncService.shared.lastSyncTime == nil || meta.lastSyncTime >= (MailSyncService.shared.lastSyncTime ?? .distantPast) {
                        MailSyncService.shared.lastSyncTime = meta.lastSyncTime
                        MailSyncService.shared.lastSyncedBy = meta.syncedBy
                    }
                }
                if let meta = loadedNpiMeta {
                    if NPIMailSyncService.shared.lastSyncTime == nil || meta.lastSyncTime >= (NPIMailSyncService.shared.lastSyncTime ?? .distantPast) {
                        NPIMailSyncService.shared.lastSyncTime = meta.lastSyncTime
                        NPIMailSyncService.shared.lastSyncedBy = meta.syncedBy
                    }
                }
                if let meta = loadedFaqMeta {
                    if ChorusFAQSyncService.shared.lastSyncTime == nil || meta.lastSyncTime >= (ChorusFAQSyncService.shared.lastSyncTime ?? .distantPast) {
                        ChorusFAQSyncService.shared.lastSyncTime = meta.lastSyncTime
                        ChorusFAQSyncService.shared.lastSyncedBy = meta.syncedBy
                    }
                }
                SharedFolderSyncService.shared.lastSyncDate = Date()
                
                if !sortedAnnouncements.isEmpty {
                    self.announcements = sortedAnnouncements
                }
                if !sortedNews.isEmpty {
                    self.newsArticles = sortedNews
                }
                if !loadedNpiEmails.isEmpty {
                    var merged = self.npiEmails.filter { $0.publishDate >= oneYearAgo }
                    for email in loadedNpiEmails {
                        if let idx = merged.firstIndex(where: {
                            if let idA = $0.originalURL, let idB = email.originalURL, !idA.isEmpty && !idB.isEmpty {
                                if idA == idB { return true }
                            }
                            if $0.title == email.title && Calendar.current.isDate($0.publishDate, inSameDayAs: email.publishDate) {
                                let sA = $0.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                let sB = email.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !sA.isEmpty && !sB.isEmpty && (sA == sB || sA.hasPrefix(sB.prefix(60)) || sB.hasPrefix(sA.prefix(60))) {
                                    return true
                                }
                            }
                            return false
                        }) {
                            merged[idx] = email
                        } else {
                            merged.append(email)
                        }
                    }
                    self.npiEmails = merged.sorted { $0.publishDate > $1.publishDate }
                }
                for sharedComment in commentsToMerge {
                    if let idx = self.newsArticles.firstIndex(where: { $0.id == sharedComment.articleId }) {
                        if !self.newsArticles[idx].comments.contains(where: { $0.id == sharedComment.comment.id }) {
                            self.newsArticles[idx].comments.append(sharedComment.comment)
                        }
                    }
                }
                if !sortedFAQs.isEmpty {
                    self.faqItems = sortedFAQs
                }
                self.teamMembers = mergedMembers
                if !self.teamMembers.contains(where: { $0.name == self.currentUser.name }) && !Self.mockNamesBlocklist.contains(self.currentUser.name) {
                    self.teamMembers.append(self.currentUser)
                }
                if let config = loadedConfig {
                    self.permissionConfig = config
                }
                self.teamShiftSchedules = sortedTeamShifts
                
                if !loadedKnowledge.isEmpty {
                    var mergedK = self.knowledgeArticles
                    for article in loadedKnowledge {
                        if let idx = mergedK.firstIndex(where: { $0.id == article.id }) {
                            mergedK[idx] = article
                        } else {
                            mergedK.append(article)
                        }
                    }
                    self.knowledgeArticles = mergedK.sorted {
                        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                        return $0.createdAt > $1.createdAt
                    }
                }
                
                self.isSharedFolderLoading = false
                self.objectWillChange.send()
            }
        }
    }
    
    public func forceSyncAllWithSharedFolder() {
        if SharedFolderSyncService.shared.isConnected {
            saveData()
            loadDataFromSharedFolder()
            SharedFolderSyncService.shared.lastSyncDate = Date()
            SharedFolderSyncService.shared.syncMessage = "全员数据云端双向同步完成"
        }
    }
    
    /// 一键检查并全面同步所有版块（重要邮件、NPI 重点邮件、Chorus 问答知识库、Apple 官网价格、团队共享双向对齐）
    @MainActor
    public func performMasterSync() async {
        guard !isMasterSyncing else { return }
        isMasterSyncing = true
        defer { isMasterSyncing = false }
        
        var greenNewCount = 0
        var npiNewCount = 0
        var faqCount = 0
        var priceDiffCount = 0
        
        if canCurrentUserSyncData {
            // 1. 检查重要邮件 (Green Email + Slack Support)
            greenNewCount = await MailSyncService.shared.syncGreenEmailsFromMail(into: self)
            
            // 2. 检查 NPI 重点邮件
            npiNewCount = await NPIMailSyncService.shared.syncNPIMailsFromMail(into: self)
            
            // 3. 校验并更新 Chorus 知识库全量问答 (含 RCC FAQ_NPI 专项)
            faqCount = ChorusFAQSyncService.shared.syncChorusAll(into: self)
            _ = ChorusFAQSyncService.shared.syncChorusCategory("RCC FAQ_NPI", into: self)
            
            // 4. 联网检查 Apple 官网最新维修价格及机型
            let priceResult = await AppleOfficialPricingData.shared.fetchLatestFromOfficialWebsite()
            if case .success(let diff) = priceResult {
                priceDiffCount = diff
            }
        }
        
        // 5. 检查并双向对齐团队共享文件夹 (公告/排班/花名册/权限/确认/评论)
        forceSyncAllWithSharedFolder()
        
        // 6. 汇总结果
        let now = Date()
        self.lastMasterSyncTime = now
        self.lastMasterSyncedBy = currentUser.name
        UserDefaults.standard.set(now, forKey: lastMasterSyncTimeKey)
        UserDefaults.standard.set(currentUser.name, forKey: lastMasterSyncedByKey)
        
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            DispatchQueue.global(qos: .utility).async {
                let metaURL = baseURL.appendingPathComponent("master_sync_meta.json")
                let meta = SyncMetaRecord(lastSyncTime: now, syncedBy: self.currentUser.name)
                if let data = try? JSONEncoder().encode(meta) {
                    try? data.write(to: metaURL)
                }
            }
        }
        
        let result = MasterSyncResult(
            greenEmailCount: newsArticles.count,
            greenEmailNew: greenNewCount,
            npiEmailCount: npiEmails.count,
            npiEmailNew: npiNewCount,
            faqCount: faqItems.count,
            priceDiffCount: priceDiffCount,
            syncedBy: currentUser.name,
            timestamp: now
        )
        self.masterSyncResult = result
        NotificationCenter.default.post(name: .masterSyncDidComplete, object: nil)
    }
    
    public func loadData() {
        // Clear all legacy mock roster caches from UserDefaults
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v1")
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v2")
        UserDefaults.standard.removeObject(forKey: "workbench_team_members_v3")
        
        let permData = UserDefaults.standard.data(forKey: permissionsStorageKey)
        if let data = permData, let decodedPerms = try? JSONDecoder().decode(TeamPermissionConfig.self, from: data) {
            self.permissionConfig = decodedPerms
        } else {
            self.permissionConfig = TeamPermissionConfig()
        }
        
        let userData = UserDefaults.standard.data(forKey: currentUserStorageKey) ?? UserDefaults.standard.data(forKey: "workbench_current_user_v1")
        if let data = userData, let decodedUser = try? JSONDecoder().decode(TeamMember.self, from: data) {
            let lower = decodedUser.name.lowercased()
            let isInvalidLegacy = lower == "testuser" || lower == "user" || lower == "admin" || lower == "apple" || lower == "mac"
            // 如果缓存里残留的是旧测试名或无效名，自动升级为多级探测的系统真实名字
            if isInvalidLegacy {
                self.currentUser = TeamMember.defaultSystemUser
                UserDefaults.standard.removeObject(forKey: currentUserStorageKey)
            } else {
                self.currentUser = decodedUser
            }
        } else {
            self.currentUser = TeamMember.defaultSystemUser
        }
        self.loadShiftSchedule(for: self.currentUser.name)
        
        let readNewsData = UserDefaults.standard.stringArray(forKey: readNewsStorageKey) ?? []
        self.readNewsArticleIDs = Set(readNewsData.compactMap { UUID(uuidString: $0) })
        
        let readNpiData = UserDefaults.standard.stringArray(forKey: readNpiEmailStorageKey) ?? []
        self.readNpiEmailIDs = Set(readNpiData.compactMap { UUID(uuidString: $0) })
        
        let readAnnData = UserDefaults.standard.stringArray(forKey: readAnnouncementsStorageKey) ?? []
        self.readAnnouncementIDs = Set(readAnnData.compactMap { UUID(uuidString: $0) })
        
        let npiData = UserDefaults.standard.data(forKey: npiEmailsStorageKey)
        if let data = npiData, let decoded = try? JSONDecoder().decode([NewsArticle].self, from: data) {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date().addingTimeInterval(-365 * 86400)
            let filtered = decoded.filter {
                !$0.title.contains("[TEST NPI]") &&
                !$0.title.contains("联调测试") &&
                $0.publishDate >= oneYearAgo &&
                $0.source.lowercased().contains("fy26_gc_npicomms@apple.com") && $0.title.contains("🔥") && ($0.title.contains("[FY26 GC NPI]") || $0.title.lowercased().contains("fy26 gc npi"))
            }
            var deduplicated: [NewsArticle] = []
            for item in filtered {
                let isDup = deduplicated.contains(where: { ex in
                    if let idA = ex.originalURL, let idB = item.originalURL, !idA.isEmpty && !idB.isEmpty {
                        if idA == idB { return true }
                    }
                    if ex.title == item.title && Calendar.current.isDate(ex.publishDate, inSameDayAs: item.publishDate) {
                        let sA = ex.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        let sB = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sA.isEmpty && !sB.isEmpty && (sA == sB || sA.hasPrefix(sB.prefix(60)) || sB.hasPrefix(sA.prefix(60))) {
                            return true
                        }
                    }
                    return false
                })
                if !isDup {
                    deduplicated.append(item)
                }
            }
            self.npiEmails = deduplicated.sorted { $0.publishDate > $1.publishDate }
        } else {
            self.npiEmails = []
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
                mod.acknowledgments.removeAll { Self.mockNamesBlocklist.contains($0.memberName) || $0.memberName == "TestUser" }
                
                // 严格去重现有脏数据（每个真实成员仅保留一条最新的已读确认）
                var uniqueMap: [String: AnnouncementAcknowledgment] = [:]
                for ack in mod.acknowledgments {
                    let name = ack.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !Self.mockNamesBlocklist.contains(name) else { continue }
                    if let ex = uniqueMap[name] {
                        if ack.acknowledgedAt > ex.acknowledgedAt { uniqueMap[name] = ack }
                    } else {
                        uniqueMap[name] = ack
                    }
                }
                mod.acknowledgments = Array(uniqueMap.values).sorted { $0.acknowledgedAt < $1.acknowledgedAt }
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
                    let lower = article.title.lowercased()
                    if lower.contains("(test)") || lower.contains("[test]") || lower.contains(" test ") || lower.hasPrefix("test") || lower.contains("测试") || lower.contains("(practice)") || lower.contains("[practice]") || lower.contains("practice") || lower.contains("演练") {
                        return false
                    }
                    if article.category == .slackSupport {
                        return article.publishDate >= oneYearAgo
                    }
                    if article.category == .greenEmail {
                        let isSenderMatch = article.source.lowercased().contains("ic_gc_aha_sacs@apple.com") || article.source.isEmpty
                        let isKeywordMatch = article.tags.contains("近期重要内容") || article.title.contains("近期重要内容")
                        return article.publishDate >= oneYearAgo && isSenderMatch && isKeywordMatch
                    }
                    return false
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
        
        // 价格查询 (Device Prices) - 本地加载，无预设模拟数据 (初始纯空)
        let priceData = UserDefaults.standard.data(forKey: devicePricesStorageKey)
        if let data = priceData, let decoded = try? JSONDecoder().decode([DevicePriceItem].self, from: data) {
            self.devicePrices = decoded
        } else {
            self.devicePrices = []
        }
        self.priceApiUrl = UserDefaults.standard.string(forKey: priceApiUrlStorageKey) ?? ""
        let lastSyncSec = UserDefaults.standard.double(forKey: lastPriceSyncTimeStorageKey)
        if lastSyncSec > 0 {
            self.lastPriceSyncTime = Date(timeIntervalSince1970: lastSyncSec)
        }
        
        self.lastMasterSyncTime = UserDefaults.standard.object(forKey: lastMasterSyncTimeKey) as? Date
        self.lastMasterSyncedBy = UserDefaults.standard.string(forKey: lastMasterSyncedByKey)
        
        // 共享知识库 (Shared Knowledge Base) - 本地加载，纯空初始状态
        let bookmarkedKData = UserDefaults.standard.stringArray(forKey: bookmarkedKnowledgeStorageKey) ?? []
        self.bookmarkedKnowledgeIDs = Set(bookmarkedKData.compactMap { UUID(uuidString: $0) })
        
        let kData = UserDefaults.standard.data(forKey: knowledgeStorageKey)
        if let data = kData, let decoded = try? JSONDecoder().decode([SharedKnowledgeArticle].self, from: data) {
            self.knowledgeArticles = decoded.sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                return $0.createdAt > $1.createdAt
            }
        } else {
            self.knowledgeArticles = []
        }
        
        var hasNewItems = false
        
        // Normalize legacy category names if any
        for i in 0..<self.faqItems.count {
            if self.faqItems[i].category == "ARS OB 常规咨询" {
                self.faqItems[i].category = "ARS OB"
                hasNewItems = true
            }
        }
        
        // Ensure all pre-compiled Chorus Knowledge Base items are present (e.g. RCC / ARS OB / AASP OB / BTS / AA / SDA / Apple TV)
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

public enum AppNavigationCategory: String, CaseIterable, Identifiable {
    case dashboard = "首页概览"
    case teamShare = "团队共享"
    case npiFocus = "NPI专题"
    case personalCenter = "个人中心"
    case queryCenter = "查询中心"
    case mutualHelp = "互帮互助"
    case tools = "小工具"
    case songKouQi = "松口气"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .teamShare: return "person.2.fill"
        case .npiFocus: return "flame.fill"
        case .personalCenter: return "person.crop.circle.fill"
        case .queryCenter: return "magnifyingglass.circle.fill"
        case .mutualHelp: return "hands.sparkles.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .songKouQi: return "wind"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .dashboard: return .blue
        case .teamShare: return .indigo
        case .npiFocus: return .orange
        case .personalCenter: return .purple
        case .queryCenter: return .green
        case .mutualHelp: return .brown
        case .tools: return .cyan
        case .songKouQi: return .teal
        }
    }
    
    public var isTeamSynced: Bool {
        switch self {
        case .dashboard, .teamShare, .npiFocus, .queryCenter, .mutualHelp:
            return true
        case .personalCenter, .tools, .songKouQi:
            return false
        }
    }
    
    public var syncScopeBadge: String {
        isTeamSynced ? "全员共享" : "本地私有"
    }
    
    public var subItems: [AppNavigationItem] {
        switch self {
        case .dashboard:
            return [.dashboard]
        case .teamShare:
            return [.announcements, .teamShifts]
        case .npiFocus:
            return [.npiEmails, .npiQuery, .rccFaqNpi]
        case .personalCenter:
            return [.shifts, .leaveRequest, .myStats]
        case .queryCenter:
            return [.news, .faq, .priceQuery]
        case .mutualHelp:
            return [.caseAssistance, .sharedKnowledge]
        case .tools:
            return [.luckyWheel, .dateCalculator]
        case .songKouQi:
            return [.relax]
        }
    }
}

public enum AppNavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "首页概览"
    
    // 团队共享
    case announcements = "团队公告"
    case teamShifts = "团队班表"
    
    // NPI专题
    case npiEmails = "NPI邮件合集"
    case npiQuery = "NPI问题追踪"
    case rccFaqNpi = "RCC FAQ_NPI"
    
    // 个人中心
    case shifts = "我的班表"
    case leaveRequest = "我要请假"
    case myStats = "数据统计"
    
    // 查询中心
    case news = "重要邮件"
    case faq = "FAQ查询"
    case priceQuery = "价格查询"
    
    // 互帮互助
    case caseAssistance = "案例协助"
    case sharedKnowledge = "共享知识库"
    
    // 小工具
    case luckyWheel = "幸运大转盘"
    case dateCalculator = "日期计算器"
    case relax = "松口气"
    
    // System Special
    case publish = "发布中心"
    case settings = "偏好设置"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .announcements: return "megaphone.fill"
        case .teamShifts: return "person.3.sequence.fill"
        case .shifts: return "calendar.badge.clock"
        case .leaveRequest: return "airplane.departure"
        case .myStats: return "chart.bar.xaxis"
        case .news: return "envelope.fill"
        case .npiEmails: return "envelope.badge.shield.half.filled"
        case .npiQuery: return "doc.text.magnifyingglass"
        case .rccFaqNpi: return "questionmark.folder.fill"
        case .faq: return "questionmark.bubble.fill"
        case .priceQuery: return "tag.fill"
        case .caseAssistance: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .sharedKnowledge: return "books.vertical.fill"
        case .luckyWheel: return "gift.fill"
        case .dateCalculator: return "calendar.badge.plus"
        case .relax: return "wind"
        case .publish: return "square.and.pencil"
        case .settings: return "gearshape.fill"
        }
    }
    
    public var category: AppNavigationCategory? {
        for cat in AppNavigationCategory.allCases {
            if cat.subItems.contains(self) {
                return cat
            }
        }
        return nil
    }
}

// MARK: - Master Sync Result Model

public struct MasterSyncResult: Identifiable {
    public var id = UUID()
    public var greenEmailCount: Int
    public var greenEmailNew: Int
    public var npiEmailCount: Int
    public var npiEmailNew: Int
    public var faqCount: Int
    public var priceDiffCount: Int
    public var syncedBy: String
    public var timestamp: Date
    
    public init(
        greenEmailCount: Int,
        greenEmailNew: Int,
        npiEmailCount: Int,
        npiEmailNew: Int,
        faqCount: Int,
        priceDiffCount: Int = 0,
        syncedBy: String,
        timestamp: Date = Date()
    ) {
        self.greenEmailCount = greenEmailCount
        self.greenEmailNew = greenEmailNew
        self.npiEmailCount = npiEmailCount
        self.npiEmailNew = npiEmailNew
        self.faqCount = faqCount
        self.priceDiffCount = priceDiffCount
        self.syncedBy = syncedBy
        self.timestamp = timestamp
    }
}

public extension Notification.Name {
    static let masterSyncDidComplete = Notification.Name("workbench_master_sync_did_complete")
}
