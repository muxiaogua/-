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
    @State private var npiItems: [NpiIssueItem] = []
    
    private let npiStorageKey = "workbench_npi_issues_v1"
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. 团队公告（置顶公告 + 未读公告）
                teamAnnouncementsSection
                
                // 2. 🔥 NPI 重点（每日更新议题速查）
                npiIssuesSection
                
                // 3. 重要邮件（仅显示近一周的更新）
                importantNewsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadNpiData()
        }
        .alert("确认已读", isPresented: $showingAcknowledgeSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您已成功确认公告「\(acknowledgedTitle)」为已读。")
        }
    }
    
    // MARK: - 1. Announcements Section (置顶公告 + 未读公告)
    
    /// 过滤规则：置顶公告始终保留；非置顶公告仅显示当前用户未读/未确认的公告
    private var filteredAnnouncements: [Announcement] {
        store.announcements.filter { item in
            if item.isPinned {
                return true
            }
            let isAcked = item.isAcknowledged || item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
            if item.requiresAcknowledgment {
                return !isAcked
            } else {
                return !store.readAnnouncementIDs.contains(item.id)
            }
        }
    }
    
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
                
                Text("（置顶与未读）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    store.selectedCategory = .teamShare
                    store.selectedNavigation = .announcements
                }) {
                    HStack(spacing: 4) {
                        Text("进入团队公告")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // 3-Column Announcements Cards Grid
            if filteredAnnouncements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.green.opacity(0.6))
                        Text("太棒了！所有公告均已阅读完毕")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(28)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(filteredAnnouncements.prefix(6)) { item in
                        announcementCard(for: item)
                    }
                }
            }
        }
    }
    
    private func announcementCard(for item: Announcement) -> some View {
        let isUrgent = item.priority == .urgent || item.isPinned
        let isAcked = item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
        
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
    
    // MARK: - 2. NPI 重点 Section (每日更新)
    
    private var recentNpiItems: [NpiIssueItem] {
        // 优先展示最新录入/更新的 NPI 议题
        Array(npiItems.prefix(6))
    }
    
    private var npiIssuesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text("🔥 NPI 重点")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("（每日更新议题）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    store.selectedCategory = .npiFocus
                    store.selectedNavigation = .npiQuery
                }) {
                    HStack(spacing: 4) {
                        Text("进入 NPI 检索")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            if recentNpiItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "flame")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无 NPI 重点议题记录（可前往「NPI 检索」从邮件自动导入）")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(28)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(recentNpiItems) { item in
                        npiCard(for: item)
                    }
                }
            }
        }
    }
    
    private func npiCard(for item: NpiIssueItem) -> some View {
        Button(action: {
            store.selectedCategory = .npiFocus
            store.selectedNavigation = .npiQuery
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Top Row: Product Tag + Status Badge + Date
                HStack(spacing: 6) {
                    Text(item.productType)
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Text(item.status)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(npiStatusColor(item.status).opacity(0.12))
                        .foregroundColor(npiStatusColor(item.status))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                    
                    Text(item.date)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                
                // Issue ID & Title
                HStack(alignment: .top, spacing: 4) {
                    Text(item.id)
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                // Description Snippet
                Text(item.desc)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
                
                Spacer(minLength: 2)
                
                // Guidance Box
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text(item.guidance)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(2)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(12)
            .frame(minHeight: 145)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func npiStatusColor(_ status: String) -> Color {
        switch status {
        case "需提交RTA": return .red
        case "无需RTA": return .gray
        case "积极投票": return .orange
        case "已修复": return .green
        default: return .blue
        }
    }
    
    // MARK: - 3. Important News & Mails Section (仅显示近一周)
    
    /// 仅保留发布时间在近 7 天内的邮件
    private var pastWeekNewsArticles: [NewsArticle] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-7 * 86400)
        return store.newsArticles.filter { $0.publishDate >= sevenDaysAgo }
    }
    
    private var importantNewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("重要邮件")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("（近一周更新）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    store.selectedCategory = .queryCenter
                    store.selectedNavigation = .news
                }) {
                    HStack(spacing: 4) {
                        Text("查看全部邮件")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // 3-Column News Cards Grid
            if pastWeekNewsArticles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("近一周内暂无更新的邮件")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(28)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(pastWeekNewsArticles.prefix(6)) { article in
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
                store.selectedCategory = .queryCenter
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
    
    // MARK: - Helpers
    
    private func loadNpiData() {
        if let data = UserDefaults.standard.data(forKey: npiStorageKey),
           let decoded = try? JSONDecoder().decode([NpiIssueItem].self, from: data) {
            self.npiItems = decoded
        }
    }
    
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
