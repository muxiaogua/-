//
//  AnnouncementsView.swift
//  团队工作台
//

import SwiftUI

public struct AnnouncementsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @State private var selectedAnnouncementID: UUID?
    @State private var selectedPriorityFilter: String = "全部"
    @State private var selectedStatusFilter: String = "全部"
    @State private var searchText: String = ""
    @State private var showAcknowledgeToast = false
    
    public init() {}
    
    private var filteredAnnouncements: [Announcement] {
        store.announcements.filter { item in
            // Priority Filter
            if selectedPriorityFilter != "全部" && item.priority.rawValue != selectedPriorityFilter {
                return false
            }
            // Status Filter
            if selectedStatusFilter == "待签收" && (!item.requiresAcknowledgment || item.isAcknowledged) {
                return false
            }
            if selectedStatusFilter == "已签收" && !item.isAcknowledged {
                return false
            }
            if selectedStatusFilter == "置顶" && !item.isPinned {
                return false
            }
            // Search text
            if !searchText.isEmpty {
                let matchTitle = item.title.localizedCaseInsensitiveContains(searchText)
                let matchContent = item.content.localizedCaseInsensitiveContains(searchText)
                let matchAuthor = item.author.localizedCaseInsensitiveContains(searchText)
                let matchTag = item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                return matchTitle || matchContent || matchAuthor || matchTag
            }
            return true
        }
        .sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }
            return first.publishDate > second.publishDate
        }
    }
    
    public var body: some View {
        HSplitView {
            // Left: Announcements List
            VStack(spacing: 0) {
                filterBar
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                announcementsList
            }
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 450)
            
            // Right: Detail View
            detailContentView
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .searchable(text: $searchText, prompt: "搜索公告标题、内容、发布人...")
        .onAppear {
            if selectedAnnouncementID == nil {
                selectedAnnouncementID = filteredAnnouncements.first?.id
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("重要度:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Picker("重要度", selection: $selectedPriorityFilter) {
                    Text("全部").tag("全部")
                    Text("紧急").tag("紧急")
                    Text("重要").tag("重要")
                    Text("常规").tag("常规")
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Text("状态:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Picker("状态", selection: $selectedStatusFilter) {
                    Text("全部").tag("全部")
                    Text("待签收").tag("待签收")
                    Text("已签收").tag("已签收")
                    Text("置顶").tag("置顶")
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - List
    
    private var announcementsList: some View {
        Group {
            if filteredAnnouncements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "megaphone")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "暂无团队公告" : "未找到匹配的公告")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Button("去起草公告") {
                            store.selectedNavigation = .publish
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredAnnouncements, selection: $selectedAnnouncementID) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                            PriorityBadge(priority: item.priority)
                            
                            Spacer()
                            
                            if item.requiresAcknowledgment {
                                if item.isAcknowledged {
                                    Text("已签收")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("待签收")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(item.content)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Text("\(item.author) · \(item.department)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(item.publishDate))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(item.id)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    // MARK: - Detail View
    
    private var detailContentView: some View {
        Group {
            if let id = selectedAnnouncementID,
               let item = store.announcements.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title & Meta
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                PriorityBadge(priority: item.priority)
                                if item.isPinned {
                                    Label("已置顶", systemImage: "pin.fill")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                
                                Button(action: {
                                    store.togglePinAnnouncement(id: item.id)
                                }) {
                                    Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                                }
                                .help(item.isPinned ? "取消置顶" : "置顶公告")
                            }
                            
                            Text(item.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                Label(item.author, systemImage: "person.circle")
                                Label(item.department, systemImage: "building.2")
                                Label(formatFullDate(item.publishDate), systemImage: "clock")
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 6)
                        
                        Divider()
                        
                        // Content Body
                        Text(item.content)
                            .font(.system(size: 14))
                            .lineSpacing(6)
                            .textSelection(.enabled)
                        
                        // Tags
                        if !item.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(item.tags, id: \.self) { tag in
                                    TagPill(title: tag)
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // External Link
                        if let link = item.externalLink, let url = URL(string: link) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text("查看相关参考链接或附件文档")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 13))
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Acknowledgment Card
                        if item.requiresAcknowledgment {
                            acknowledgmentCard(for: item)
                        }
                    }
                    .padding(24)
                }
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("请在左侧选择一篇公告查看详细内容")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    private func acknowledgmentCard(for item: Announcement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.isAcknowledged {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("您已完成签收确认")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                        if let ackDate = item.acknowledgedAt {
                            Text("签收时间: \(formatFullDate(ackDate)) · 签收人: \(store.currentUser.name)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("需要签收确认")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text("发布人要求团队成员必须阅读并签收此通知，请在确认了解相关事项后点击下方签收按钮。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        store.acknowledgeAnnouncement(id: item.id)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("本人已仔细阅读并确认签收")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
                .padding(16)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
