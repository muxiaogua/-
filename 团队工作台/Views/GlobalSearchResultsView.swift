//
//  GlobalSearchResultsView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct GlobalSearchResultsView: View {
    @EnvironmentObject var store: WorkbenchStore
    
    enum SearchFilterTab: String, CaseIterable, Identifiable {
        case all = "全部结果"
        case announcements = "团队公告"
        case news = "重要邮件"
        case faq = "FAQ知识库"
        
        var id: String { rawValue }
    }
    
    @State private var selectedTab: SearchFilterTab = .all
    @State private var expandedResultIDs: Set<UUID> = []
    @State private var copiedItemID: UUID? = nil
    
    private var query: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var queryTokens: [String] {
        query.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
    }
    
    // Matched Announcements (Matches all tokens across title, content, author, tags)
    private var matchedAnnouncements: [Announcement] {
        let tokens = queryTokens
        guard !tokens.isEmpty else { return [] }
        return store.announcements.filter { item in
            let combinedText = "\(item.title) \(item.content) \(item.author) \(item.tags.joined(separator: " "))"
            return tokens.allSatisfy { token in
                combinedText.localizedCaseInsensitiveContains(token)
            }
        }
    }
    
    // Matched News Articles (Matches all tokens across title, content, summary, tags, category)
    private var matchedNews: [NewsArticle] {
        let tokens = queryTokens
        guard !tokens.isEmpty else { return [] }
        return store.newsArticles.filter { article in
            let combinedText = "\(article.title) \(article.content) \(article.summary) \(article.tags.joined(separator: " ")) \(article.category.rawValue)"
            return tokens.allSatisfy { token in
                combinedText.localizedCaseInsensitiveContains(token)
            }
        }
    }
    
    // Matched FAQ Items (Matches all tokens across question, answer, tags, category, relatedArticleId)
    private var matchedFAQs: [FAQItem] {
        let tokens = queryTokens
        guard !tokens.isEmpty else { return [] }
        return store.faqItems.filter { item in
            let combinedText = "\(item.question) \(item.answer) \(item.tags.joined(separator: " ")) \(item.category) \(item.relatedArticleId ?? "")"
            return tokens.allSatisfy { token in
                combinedText.localizedCaseInsensitiveContains(token)
            }
        }
    }
    
    private var totalCount: Int {
        matchedAnnouncements.count + matchedNews.count + matchedFAQs.count
    }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Top Header Bar
                headerSection
                
                // Tabs Bar
                tabsSection
                
                // Results Content
                if totalCount == 0 {
                    emptyResultsSection
                } else {
                    resultsListSection
                }
            }
            .padding(28)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("全局搜索")
                        .font(.system(size: 20, weight: .bold))
                    Text("「\(query)」")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                Text("共找到 \(totalCount) 条相关内容，点击卡片即可就地展开查看完整详情")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                store.searchText = ""
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text("退出搜索")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Tabs
    
    private var tabsSection: some View {
        HStack(spacing: 8) {
            tabPill(title: "全部结果", count: totalCount, tab: .all)
            tabPill(title: "团队公告", count: matchedAnnouncements.count, tab: .announcements)
            tabPill(title: "重要邮件", count: matchedNews.count, tab: .news)
            tabPill(title: "FAQ知识库", count: matchedFAQs.count, tab: .faq)
            
            Spacer()
        }
    }
    
    private func tabPill(title: String, count: Int, tab: SearchFilterTab) -> some View {
        let isSelected = (selectedTab == tab)
        
        return Button(action: {
            selectedTab = tab
        }) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .bold))
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 1.5)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Results List
    
    private var resultsListSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 1. Announcements Group
            if (selectedTab == .all || selectedTab == .announcements) && !matchedAnnouncements.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "团队公告", icon: "megaphone.fill", count: matchedAnnouncements.count, color: .orange)
                    
                    VStack(spacing: 10) {
                        ForEach(matchedAnnouncements) { item in
                            announcementResultCard(item)
                        }
                    }
                }
            }
            
            // 2. News / Green Email Group
            if (selectedTab == .all || selectedTab == .news) && !matchedNews.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "重要邮件", icon: "envelope.fill", count: matchedNews.count, color: .green)
                    
                    VStack(spacing: 10) {
                        ForEach(matchedNews) { article in
                            newsResultCard(article)
                        }
                    }
                }
            }
            
            // 3. FAQ Knowledge Base Group
            if (selectedTab == .all || selectedTab == .faq) && !matchedFAQs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "FAQ 知识库", icon: "questionmark.bubble.fill", count: matchedFAQs.count, color: .blue)
                    
                    VStack(spacing: 10) {
                        ForEach(matchedFAQs) { item in
                            faqResultCard(item)
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(title: String, icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Text("\(count) 条")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .foregroundColor(color)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - In-place Accordion Cards
    
    private func announcementResultCard(_ item: Announcement) -> some View {
        let isExpanded = expandedResultIDs.contains(item.id)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Clickable Header
            Button(action: {
                toggleExpansion(for: item.id)
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        PriorityBadge(priority: item.priority)
                        
                        Text(highlightedAttributedString(for: item.title, query: query))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)
                        
                        Spacer()
                        
                        Text("发布人: \(item.author)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(item.publishDate))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    if !isExpanded {
                        Text(highlightedAttributedString(for: item.content, query: query))
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Expanded Details
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(highlightedAttributedString(for: item.content, query: query, isMarkdown: true))
                        .font(.system(size: 13.5))
                        .lineSpacing(5)
                        .foregroundColor(.primary.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    HStack {
                        if item.requiresAcknowledgment {
                            let isUserAcked = item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
                            if isUserAcked {
                                Label("已确认阅读", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.green)
                            } else {
                                Button(action: {
                                    store.acknowledgeAnnouncement(id: item.id)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                        Text("确认已读")
                                    }
                                    .font(.system(size: 11.5, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            store.selectedAnnouncementID = item.id
                            store.searchText = ""
                            store.selectedNavigation = .announcements
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("前往公告板")
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.02))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isExpanded ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
    
    private func newsResultCard(_ article: NewsArticle) -> some View {
        let isExpanded = expandedResultIDs.contains(article.id)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Clickable Header
            Button(action: {
                toggleExpansion(for: article.id)
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        CategoryTag(category: article.category)
                        
                        Text(highlightedAttributedString(for: article.title, query: query))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)
                        
                        Spacer()
                        
                        if article.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                        
                        Text(formatDate(article.publishDate))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    if !isExpanded {
                        Text(highlightedAttributedString(for: article.content, query: query))
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    if let html = article.htmlContent, !html.isEmpty {
                        HTMLMailView(htmlContent: html)
                            .frame(minHeight: 260, maxHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ScrollView {
                            GreenEmailContentView(content: article.content)
                                .padding(12)
                        }
                        .frame(maxHeight: 320)
                    }
                    
                    Divider()
                    
                    HStack {
                        Button(action: {
                            store.toggleBookmark(id: article.id)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                Text(article.isBookmarked ? "已收藏" : "收藏")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(article.isBookmarked ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            store.selectedNewsArticleID = article.id
                            store.searchText = ""
                            store.selectedNavigation = .news
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("前往完整邮件阅读器")
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.02))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isExpanded ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
    
    private func faqResultCard(_ item: FAQItem) -> some View {
        let isExpanded = expandedResultIDs.contains(item.id)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Clickable Header
            Button(action: {
                toggleExpansion(for: item.id)
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.category)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        if let subCat = item.tags.first(where: { $0 != item.category && $0 != "RCC" && $0 != "RCC 常见场景" }) {
                            Text(subCat)
                                .font(.system(size: 10.5, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.08))
                                .foregroundColor(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Text(highlightedAttributedString(for: item.question, query: query))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Expanded Answer Details
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlightedAttributedString(for: item.answer, query: query, isMarkdown: true))
                        .font(.system(size: 13.5))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        if let articleId = item.relatedArticleId, !articleId.isEmpty {
                            Button(action: {
                                if let url = URL(string: "core://articleId=\(articleId)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text("Core \(articleId)")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.answer, forType: .string)
                            copiedItemID = item.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if copiedItemID == item.id { copiedItemID = nil }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedItemID == item.id ? "checkmark" : "doc.on.doc")
                                Text(copiedItemID == item.id ? "已复制" : "复制解答")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(Color.secondary.opacity(0.02))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isExpanded ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
    
    // MARK: - Toggle Expansion
    
    private func toggleExpansion(for id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedResultIDs.contains(id) {
                expandedResultIDs.remove(id)
            } else {
                expandedResultIDs.insert(id)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyResultsSection: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("未找到包含「\(query)」的相关内容")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("请尝试更换关键词、案例号、文章编号或人员姓名重新搜索")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
            
            Button("清空搜索词") {
                store.searchText = ""
            }
            .font(.system(size: 12.5))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
    
    // MARK: - Highlight & Link Helper
    
    private func highlightedAttributedString(for text: String, query: String, isMarkdown: Bool = false) -> AttributedString {
        let tokens = query.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        let baseString = isMarkdown ? formatLinks(in: text) : text
        
        var attrString: AttributedString
        if isMarkdown, let markdownAttr = try? AttributedString(markdown: baseString, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            attrString = markdownAttr
        } else {
            attrString = AttributedString(baseString)
        }
        
        for token in tokens {
            var searchStartIndex = attrString.startIndex
            while searchStartIndex < attrString.endIndex,
                  let matchRange = attrString[searchStartIndex..<attrString.endIndex].range(of: token, options: .caseInsensitive) {
                attrString[matchRange].backgroundColor = Color.yellow.opacity(0.38)
                attrString[matchRange].inlinePresentationIntent = .stronglyEmphasized
                if matchRange.upperBound >= attrString.endIndex { break }
                searchStartIndex = matchRange.upperBound
            }
        }
        
        return attrString
    }
    
    private func formatLinks(in text: String) -> String {
        var formatted = text
        let kbPattern = #"(?<=\b)(10\d{4}|20\d{4}|30\d{4}|\d{6})(?=\b)"#
        if let regex = try? NSRegularExpression(pattern: kbPattern) {
            let nsString = formatted as NSString
            let matches = regex.matches(in: formatted, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let matchedNumber = nsString.substring(with: match.range)
                let linkMarkdown = "[\(matchedNumber)](core://articleId=\(matchedNumber))"
                formatted = (formatted as NSString).replacingCharacters(in: match.range, with: linkMarkdown)
            }
        }
        return formatted
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
