//
//  DashboardView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct DashboardView: View {
    @EnvironmentObject var store: WorkbenchStore
    @State private var showingAcknowledgeSuccessAlert = false
    @State private var acknowledgedTitle = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. Top 5 Mini Summary Cards
                topSummaryCardsRow
                
                // 2. Announcements Section (置顶与最新发布规范)
                teamAnnouncementsSection
                
                // 3. Important News & Mails Section (AASP 业务资讯与工程简报)
                importantNewsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("确认已读", isPresented: $showingAcknowledgeSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您已成功确认公告「\(acknowledgedTitle)」为已读。")
        }
    }
    
    // MARK: - 1. Top 5 Mini Summary Cards
    
    private var topSummaryCardsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            miniStatCard(
                title: "今日公告",
                count: "\(store.announcements.count)",
                badge: "公告",
                color: Color.orange,
                action: { store.selectedNavigation = .announcements }
            )
            
            miniStatCard(
                title: "今日邮件",
                count: "\(store.newsArticles.count)",
                badge: "邮件",
                color: Color.green,
                action: { store.selectedNavigation = .news }
            )
            
            miniStatCard(
                title: "今日FAQ",
                count: "\(store.faqItems.count)",
                badge: "FAQ",
                color: Color.blue,
                action: { store.selectedNavigation = .faq }
            )
            
            miniStatCard(
                title: "我的收藏",
                count: "\(store.bookmarkedNews.count)",
                badge: "精益",
                color: Color(red: 0.88, green: 0.15, blue: 0.35),
                action: { store.selectedNavigation = .news }
            )
            
            miniStatCard(
                title: "今日待领",
                count: "\(store.unacknowledgedCount)",
                badge: "待领",
                color: Color(red: 0.90, green: 0.20, blue: 0.25),
                action: { store.selectedNavigation = .announcements }
            )
        }
    }
    
    private func miniStatCard(
        title: String,
        count: String,
        badge: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .foregroundColor(color)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                Text(count)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Announcements Section
    
    private var teamAnnouncementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                
                Text("团队公告")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("(置顶与最新发布规范)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    store.selectedNavigation = .announcements
                }) {
                    HStack(spacing: 4) {
                        Text("进入公告板")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // 3-Column Announcements Cards Grid
            if store.announcements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无团队公告")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(store.announcements.prefix(6)) { item in
                        announcementCard(for: item)
                    }
                }
            }
        }
    }
    
    private func announcementCard(for item: Announcement) -> some View {
        let isUrgent = item.priority == .urgent || item.isPinned
        let isAcked = item.isAcknowledged || item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top Row (Badges & Date)
            HStack(spacing: 6) {
                if item.isPinned {
                    Text("置顶")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                
                if let firstTag = item.tags.first, !firstTag.isEmpty {
                    Text(firstTag)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Text(item.priority == .urgent ? "紧急" : "常规")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                
                Spacer()
                
                Text(formatShortDate(item.publishDate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(item.title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(isUrgent ? Color.red : Color.primary)
                .lineLimit(2)
            
            // Content Summary
            Text(item.content)
                .font(.system(size: 12))
                .foregroundColor(isUrgent ? Color.red.opacity(0.85) : Color.secondary)
                .lineLimit(3)
                .lineSpacing(2)
            
            Spacer(minLength: 4)
            
            // Bottom Row (Publisher & Read Button)
            HStack(alignment: .center) {
                Text("发布: \(item.author)")
                    .font(.system(size: 11))
                    .foregroundColor(isUrgent ? Color.red.opacity(0.8) : Color.secondary)
                
                Spacer()
                
                if item.requiresAcknowledgment {
                    if isAcked {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("已读")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        Button(action: {
                            store.acknowledgeAnnouncement(id: item.id)
                            acknowledgedTitle = item.title
                            showingAcknowledgeSuccessAlert = true
                        }) {
                            Text("标记已读")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(minHeight: 145)
        .background(isUrgent ? Color.red.opacity(0.04) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isUrgent ? Color.red.opacity(0.25) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Important News & Mails Section
    
    private var importantNewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("重要邮件与资讯")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("(AASP 业务资讯与工程简报)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    store.selectedNavigation = .news
                }) {
                    HStack(spacing: 4) {
                        Text("查看全部资讯")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // 3-Column News Cards Grid
            if store.newsArticles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无重要邮件与资讯")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(store.newsArticles.prefix(6)) { article in
                        newsCard(for: article)
                    }
                }
            }
        }
    }
    
    private func newsCard(for article: NewsArticle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row (Badge & Date)
            HStack {
                Text(article.category.rawValue)
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer()
                
                Text(formatFullDateOnly(article.publishDate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(article.title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Sender / Author
            Text("发件: \(article.source.isEmpty ? article.author : article.source)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Content Snippet Box
            Text(article.content.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(3)
                .lineSpacing(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Spacer(minLength: 4)
            
            // Bottom Action Link
            Button(action: {
                store.selectedNewsArticleID = article.id
                store.selectedNavigation = .news
            }) {
                HStack(spacing: 4) {
                    Text("点击查看全文")
                        .font(.system(size: 11.5, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(minHeight: 185)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Date Formatters
    
    private func formatShortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
    
    private func formatFullDateOnly(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

#Preview {
    DashboardView()
        .environmentObject(WorkbenchStore())
}
