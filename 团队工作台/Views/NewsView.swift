//
//  NewsView.swift
//  团队工作台
//

import SwiftUI

public struct NewsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var mailSyncService = MailSyncService.shared
    
    @State private var selectedArticleID: UUID?
    @State private var selectedCategory: NewsCategory = .all
    @State private var onlyUnread: Bool = false
    @State private var onlyBookmarked: Bool = false
    @State private var searchText: String = ""
    
    // Comment input state
    @State private var newCommentText: String = ""
    @State private var showCommentSuccessToast: Bool = false
    @State private var showSyncAlert: Bool = false
    @State private var showDiscussionSection: Bool = true
    @State private var showConfirmClearNewsAlert: Bool = false
    @State private var showClearNewsSuccessAlert: Bool = false
    
    public init() {}
    
    private var isBrowsingAllWithoutSearch: Bool {
        selectedCategory == .all && searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var filteredArticles: [NewsArticle] {
        if isBrowsingAllWithoutSearch {
            return []
        }
        
        let tokens = searchText.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        
        return store.newsArticles.filter { article in
            if selectedCategory != .all && article.category != selectedCategory {
                return false
            }
            if onlyUnread && store.readNewsArticleIDs.contains(article.id) {
                return false
            }
            if onlyBookmarked && !article.isBookmarked {
                return false
            }
            if !tokens.isEmpty {
                let combinedText = "\(article.title) \(article.content) \(article.summary) \(article.tags.joined(separator: " "))"
                return tokens.allSatisfy { token in
                    combinedText.localizedCaseInsensitiveContains(token)
                }
            }
            return true
        }
        .sorted { $0.publishDate > $1.publishDate }
    }
    
    public var body: some View {
        HSplitView {
            // Left: Compact News List
            VStack(spacing: 0) {
                mailSearchAndFilterSection
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                compactNewsListSection
            }
            .frame(minWidth: 300, idealWidth: 350, maxWidth: 420)
            
            // Right: Article Reader & Discussion
            articleReaderSection
                .frame(minWidth: 460, maxWidth: .infinity)
        }
        .alert("确认清空所有重要邮件缓存？", isPresented: $showConfirmClearNewsAlert) {
            Button("确认清空", role: .destructive) {
                store.clearAllNewsArticles()
                showClearNewsSuccessAlert = true
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作将彻底清除本地与云端存储的所有 Green Email 邮件内容并重置为空白状态。\n\n该操作无法撤销，确定要清空吗？")
        }
        .alert("邮件数据已清空", isPresented: $showClearNewsSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("所有重要邮件缓存已成功清空。")
        }
        .alert("邮件同步结果", isPresented: $showSyncAlert) {
            if mailSyncService.needsPrivacySettingsGuide {
                Button("打开系统设置") {
                    mailSyncService.openAutomationPrivacySettings()
                }
                Button("稍后设置", role: .cancel) { }
            } else {
                Button("确定", role: .cancel) { }
            }
        } message: {
            if let error = mailSyncService.errorMessage {
                Text(error)
            } else if let result = mailSyncService.lastSyncResult {
                Text(result)
            }
        }
        .onAppear {
            if let targetID = store.selectedNewsArticleID,
               let article = store.newsArticles.first(where: { $0.id == targetID }) {
                selectedCategory = article.category
                selectedArticleID = article.id
                store.markNewsArticleAsRead(id: article.id)
            } else if selectedCategory != .all {
                selectedArticleID = filteredArticles.first?.id
                if let firstID = selectedArticleID {
                    store.markNewsArticleAsRead(id: firstID)
                }
            }
        }
        .onChange(of: store.selectedNewsArticleID) { _, newID in
            if let targetID = newID,
               let article = store.newsArticles.first(where: { $0.id == targetID }) {
                selectedCategory = article.category
                selectedArticleID = article.id
                store.markNewsArticleAsRead(id: article.id)
            }
        }
        .onChange(of: selectedCategory) { _, newCat in
            if newCat == .all && searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                selectedArticleID = nil
            } else if selectedArticleID == nil || !filteredArticles.contains(where: { $0.id == selectedArticleID }) {
                selectedArticleID = filteredArticles.first?.id
                if let firstID = selectedArticleID {
                    store.markNewsArticleAsRead(id: firstID)
                }
            }
        }
        .onChange(of: selectedArticleID) { _, newID in
            if let id = newID {
                if store.selectedNewsArticleID != id {
                    store.selectedNewsArticleID = id
                }
                store.markNewsArticleAsRead(id: id)
            }
        }
    }
    
    // MARK: - Search & Category Filter Header (Left Panel)
    
    private var mailSearchAndFilterSection: some View {
        VStack(spacing: 8) {
            // 1. Inline Search Bar + Sync Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    
                    TextField("搜索邮件标题、内容...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                
                Button(action: { triggerMailSync(forceFullSync: false) }) {
                    HStack(spacing: 4) {
                        if mailSyncService.isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10.5))
                        }
                        Text("同步")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5.5)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(mailSyncService.isSyncing)
                .help(mailSyncService.lastSyncTime != nil ? "增量同步：检索 \(formatSyncTime(mailSyncService.lastSyncTime!)) 后的新邮件（右键可全量重新同步）" : "从邮件应用同步发件人为 ic_gc_aha_sacs@apple.com 的 Green Email")
                .contextMenu {
                    Button("增量同步（检查新邮件）") {
                        triggerMailSync(forceFullSync: false)
                    }
                    Button("全量重新同步（提取今年全部）") {
                        triggerMailSync(forceFullSync: true)
                    }
                    if store.isDefaultAdmin(name: store.currentUser.name) {
                        Divider()
                        Button("清空所有邮件缓存", role: .destructive) {
                            showConfirmClearNewsAlert = true
                        }
                    }
                }
            }
            
            // 2. Category Filter Pills (Only actual configured categories)
            HStack(spacing: 6) {
                ForEach(NewsCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button(action: {
                        selectedCategory = cat
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 9.5))
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isSelected ? (cat == .greenEmail ? Color.green : Color(NSColor.labelColor)) : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(isSelected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.vertical, 1)
            
            // 3. Only Unread / Bookmarked Toggle + Mark All as Read + Total Count
            HStack(spacing: 8) {
                Toggle(isOn: $onlyUnread) {
                    Text("只看未读")
                        .font(.system(size: 11))
                        .foregroundColor(onlyUnread ? .blue : .secondary)
                }
                .toggleStyle(.checkbox)
                
                Toggle(isOn: $onlyBookmarked) {
                    Label("只看收藏", systemImage: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundColor(onlyBookmarked ? .yellow : .secondary)
                }
                .toggleStyle(.checkbox)
                
                if store.unreadNewsCount > 0 {
                    Button(action: {
                        store.markAllNewsArticlesAsRead()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("全部已读")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("将当前所有未读邮件一键标记为已读")
                }
                
                Spacer()
                
                if let lastSync = mailSyncService.lastSyncTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                        Text(formatSyncTime(lastSync))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .help("上次同步时间：\(formatSyncTime(lastSync))")
                } else {
                    Text("尚未同步")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Text(isBrowsingAllWithoutSearch ? "· 共 \(store.newsArticles.count) 封" : "· 共 \(filteredArticles.count) 封")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Compact News List
    
    private var compactNewsListSection: some View {
        Group {
            if isBrowsingAllWithoutSearch {
                VStack(spacing: 12) {
                    Spacer()
                    Text("请输入关键词或选择上方分类查看内容")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredArticles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "暂无该分类下的邮件" : "未找到匹配的邮件")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if store.canCurrentUserSyncData {
                        Button("从邮件 App 提取最新") {
                            triggerMailSync()
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredArticles, selection: $selectedArticleID) { article in
                    let isUnread = !store.readNewsArticleIDs.contains(article.id)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 6) {
                            if isUnread {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 4)
                            }
                            
                            Image(systemName: article.category == .greenEmail ? "envelope.fill" : article.category.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(article.category == .greenEmail ? .green : .accentColor)
                                .padding(.top, isUnread ? 3 : 2)
                            
                            Text(article.title)
                                .font(.system(size: 12.5, weight: isUnread ? .bold : .medium))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if isUnread {
                                Text("未读")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            
                            if article.isBookmarked {
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 9))
                                    .padding(.top, 2)
                            }
                        }
                        
                        HStack {
                            if !article.comments.isEmpty {
                                Label("\(article.comments.count)", systemImage: "bubble.left.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.accentColor)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(article.publishDate))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(article.id)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    // MARK: - Article Reader & Discussion
    
    private var articleReaderSection: some View {
        Group {
            if isBrowsingAllWithoutSearch {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("请输入关键词或在左侧选择分类查看邮件")
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else if let id = selectedArticleID,
               let article = store.newsArticles.first(where: { $0.id == id }) {
                VStack(spacing: 0) {
                    // Top Title Header Bar
                    HStack(alignment: .center, spacing: 12) {
                        Text(article.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: {
                            showDiscussionSection.toggle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 11))
                                Text("讨论 (\(article.comments.count))")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showDiscussionSection ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                            .foregroundColor(showDiscussionSection ? .accentColor : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(showDiscussionSection ? "收起讨论区" : "展开讨论区")
                        
                        Button(action: {
                            store.toggleBookmark(id: article.id)
                        }) {
                            Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 14))
                                .foregroundColor(article.isBookmarked ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(article.isBookmarked ? "取消收藏" : "收藏此邮件")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Main Content: Full-frame native WKWebView with 120Hz smooth momentum scrolling & Retina vector text
                    if let html = article.htmlContent, !html.isEmpty {
                        HTMLMailView(htmlContent: html)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            GreenEmailContentView(content: article.content)
                                .padding(24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Bottom discussion panel (expandable)
                    if showDiscussionSection {
                        Divider()
                        discussionSection(for: article)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("请在左侧选择一封邮件进行阅读")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    // MARK: - Discussion & Comments
    
    private func discussionSection(for article: NewsArticle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Existing Comments List
            if !article.comments.isEmpty {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(article.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: comment.avatarSymbol)
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 12))
                                    
                                    Text(comment.author)
                                        .font(.system(size: 11.5, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Text(formatDate(comment.createdAt))
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                    
                                    if comment.author == store.currentUser.name {
                                        Button(action: {
                                            store.deleteComment(articleId: article.id, commentId: comment.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 9.5))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("删除我的讨论内容")
                                    }
                                }
                                
                                Text(comment.content)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            
            // New Comment Input Box
            HStack(spacing: 8) {
                TextField("写下您的讨论观点或处理备注...", text: $newCommentText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                
                Button(action: {
                    submitComment(for: article)
                }) {
                    Text("发送")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    // MARK: - Actions
    
    private func triggerMailSync(forceFullSync: Bool = false) {
        Task {
            _ = await mailSyncService.syncGreenEmailsFromMail(into: store, forceFullSync: forceFullSync)
            showSyncAlert = true
            if selectedCategory != .all && selectedArticleID == nil {
                selectedArticleID = filteredArticles.first?.id
            }
        }
    }
    
    private func submitComment(for article: NewsArticle) {
        let content = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        
        let comment = NewsComment(
            author: store.currentUser.name,
            content: content,
            createdAt: Date(),
            avatarSymbol: store.currentUser.avatarSymbol
        )
        
        store.addComment(to: article.id, comment: comment)
        newCommentText = ""
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        if cal.isDateInToday(date) {
            return "今天 \(timeFormatter.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            return "昨天 \(timeFormatter.string(from: date))"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm"
            return df.string(from: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NewsView()
        .environmentObject(WorkbenchStore())
}
