//
//  DashboardView.swift
//  团队工作台
//

import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var store: WorkbenchStore
    @State private var showingAcknowledgeSuccessAlert = false
    @State private var acknowledgedTitle = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Welcome
                headerSection
                
                // Urgent Announcements Banner (If any)
                if !store.urgentAnnouncements.isEmpty {
                    urgentBannerSection
                }
                
                // Stats Overview Cards
                statsGridSection
                
                // Pinned & Latest Announcements Preview
                announcementsSection
                
                // Latest News Highlights
                newsHighlightsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("签收成功", isPresented: $showingAcknowledgeSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您已成功签收通知「\(acknowledgedTitle)」，系统已记录您的签收状态。")
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("团队工作台")
                    .font(.system(size: 26, weight: .bold))
                Text("欢迎回来，\(store.currentUser.name) · \(store.currentUser.department)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    store.selectedNavigation = .publish
                }) {
                    Label("发布内容", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }
    
    private var urgentBannerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16, weight: .bold))
                Text("紧急公告待处理 (\(store.urgentAnnouncements.count))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.red)
                Spacer()
            }
            
            ForEach(store.urgentAnnouncements) { announcement in
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(announcement.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(announcement.content)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    if announcement.requiresAcknowledgment && !announcement.isAcknowledged {
                        Button("一键签收") {
                            store.acknowledgeAnnouncement(id: announcement.id)
                            acknowledgedTitle = announcement.title
                            showingAcknowledgeSuccessAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private var statsGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            statCard(
                title: "待签收公告",
                value: "\(store.unacknowledgedCount)",
                icon: "bell.badge.fill",
                color: store.unacknowledgedCount > 0 ? .orange : .green,
                subtitle: store.unacknowledgedCount > 0 ? "需尽快签收" : "已全部处理",
                action: { store.selectedNavigation = .announcements }
            )
            
            statCard(
                title: "置顶公告",
                value: "\(store.pinnedAnnouncements.count)",
                icon: "pin.fill",
                color: .blue,
                subtitle: "重点团队事宜",
                action: { store.selectedNavigation = .announcements }
            )
            
            statCard(
                title: "Green Email",
                value: "\(store.newsArticles.count)",
                icon: "envelope.fill",
                color: .green,
                subtitle: "重点资讯通报",
                action: { store.selectedNavigation = .news }
            )
            
            statCard(
                title: "我的收藏",
                value: "\(store.bookmarkedNews.count)",
                icon: "bookmark.fill",
                color: .yellow,
                subtitle: "精选参考文章",
                action: { store.selectedNavigation = .news }
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                        .padding(8)
                        .background(color.opacity(0.12))
                        .clipShape(Circle())
                    Spacer()
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("团队公告速览", systemImage: "megaphone.fill")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if !store.announcements.isEmpty {
                    Button("查看全部 (\(store.announcements.count))") {
                        store.selectedNavigation = .announcements
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.link)
                }
            }
            
            if store.announcements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无团队公告")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Button("去发布第一条公告") {
                            store.selectedNavigation = .publish
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(24)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(store.announcements.prefix(3)) { item in
                        HStack(spacing: 12) {
                            PriorityBadge(priority: item.priority)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(item.author) · \(item.department) · \(formatDate(item.publishDate))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if item.requiresAcknowledgment {
                                if item.isAcknowledged {
                                    Label("已签收", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                } else {
                                    Button("签收") {
                                        store.acknowledgeAnnouncement(id: item.id)
                                        acknowledgedTitle = item.title
                                        showingAcknowledgeSuccessAlert = true
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
    
    private var newsHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Green Email 重点资讯", systemImage: "envelope.fill")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if !store.newsArticles.isEmpty {
                    Button("进入资讯中心") {
                        store.selectedNavigation = .news
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.link)
                }
            }
            
            if store.newsArticles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无 Green Email 重点资讯")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Button("去发布 Green Email") {
                            store.selectedNavigation = .publish
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(24)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.latestNews.prefix(4)) { article in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                CategoryTag(category: article.category)
                                Spacer()
                                Text("\(article.estimatedReadMinutes) 分钟阅读")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(article.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("\(article.author) · \(article.source)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    store.toggleBookmark(id: article.id)
                                }) {
                                    Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                                        .foregroundColor(article.isBookmarked ? .yellow : .secondary)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
