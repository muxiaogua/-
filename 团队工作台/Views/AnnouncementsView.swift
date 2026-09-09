//
//  AnnouncementsView.swift
//  团队工作台
//
//

import SwiftUI
import AppKit

public struct AnnouncementsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    enum ViewLayoutMode: String, CaseIterable, Identifiable {
        case splitList = "列表"
        case cardGrid = "卡片"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .splitList: return "list.bullet"
            case .cardGrid: return "square.grid.2x2.fill"
            }
        }
    }
    
    @State private var viewMode: ViewLayoutMode = .splitList
    @State private var selectedAnnouncementID: UUID?
    @State private var searchText: String = ""
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Announcement? = nil
    @State private var showRemindSuccessAlert = false
    @State private var reminderAlertMessage = ""
    
    // Modal state for card grid view detail
    @State private var modalSelectedAnnouncement: Announcement? = nil
    
    public init() {}
    
    // Strict Sorting Rule: Pinned items ALWAYS on top, then newest to oldest by publishDate
    private var sortedAnnouncements: [Announcement] {
        let list = store.announcements.filter { item in
            let tokens = searchText.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
            if !tokens.isEmpty {
                let combinedText = "\(item.title) \(item.content) \(item.author) \(item.tags.joined(separator: " "))"
                return tokens.allSatisfy { token in
                    combinedText.localizedCaseInsensitiveContains(token)
                }
            }
            return true
        }
        
        return list.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }
            return first.publishDate > second.publishDate
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar (Search Bar + View Switcher + Quick Actions)
            topToolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content Area based on ViewLayoutMode
            if viewMode == .splitList {
                splitListView
            } else {
                cardGridView
            }
        }
        .alert("确认删除公告", isPresented: $showingDeleteAlert) {
            Button("确认删除", role: .destructive) {
                if let toDelete = itemToDelete {
                    store.deleteAnnouncement(id: toDelete.id)
                    if selectedAnnouncementID == toDelete.id {
                        selectedAnnouncementID = sortedAnnouncements.first?.id
                    }
                    itemToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let toDelete = itemToDelete {
                Text("确定要删除由您发布的公告「\(toDelete.title)」吗？删除后团队成员将无法再查看，此操作无法撤销。")
            }
        }
        .alert("催签提醒已发送", isPresented: $showRemindSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(reminderAlertMessage)
        }
        .sheet(item: $modalSelectedAnnouncement) { item in
            cardDetailModal(for: item)
        }
        .onAppear {
            if let targetID = store.selectedAnnouncementID {
                selectedAnnouncementID = targetID
                store.markAnnouncementAsRead(id: targetID)
            } else if selectedAnnouncementID == nil {
                selectedAnnouncementID = sortedAnnouncements.first?.id
                store.selectedAnnouncementID = selectedAnnouncementID
                if let firstID = selectedAnnouncementID {
                    store.markAnnouncementAsRead(id: firstID)
                }
            }
        }
        .onChange(of: store.selectedAnnouncementID) { _, newID in
            if let id = newID, selectedAnnouncementID != id {
                selectedAnnouncementID = id
                store.markAnnouncementAsRead(id: id)
            }
        }
        .onChange(of: selectedAnnouncementID) { _, newID in
            if let id = newID {
                if store.selectedAnnouncementID != id {
                    store.selectedAnnouncementID = id
                }
                store.markAnnouncementAsRead(id: id)
            }
        }
    }
    
    // MARK: - Top Toolbar
    
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Inline Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                
                TextField("搜索公告标题、内容、发布人...", text: $searchText)
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
            .padding(.vertical, 5.5)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .frame(maxWidth: 320)
            
            Text("· 共 \(sortedAnnouncements.count) 篇公告")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // View Mode Switcher (Icon Only: List vs Card Grid)
            Picker("", selection: $viewMode) {
                ForEach(ViewLayoutMode.allCases) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 76)
            
            // Quick Publish Action
            if store.canCurrentUserPublishAnnouncements {
                Button(action: {
                    store.selectedNavigation = .publish
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text("起草公告")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - 1. Split List View Layout
    
    private var splitListView: some View {
        HSplitView {
            // Left: List
            announcementsSidebarList
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 450)
            
            // Right: Detail View
            detailContentView
                .frame(minWidth: 400, maxWidth: .infinity)
        }
    }
    
    private var announcementsSidebarList: some View {
        Group {
            if sortedAnnouncements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "megaphone")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "暂无团队公告" : "未找到匹配的公告")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if searchText.isEmpty && store.canCurrentUserPublishAnnouncements {
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
                List(sortedAnnouncements, selection: $selectedAnnouncementID) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 6) {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("置顶")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            
                            PriorityBadge(priority: item.priority)
                            
                            Spacer()
                            
                            if item.requiresAcknowledgment {
                                let isUserAcked = item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
                                if isUserAcked {
                                    Text("已读")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("未读")
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
                            Text(item.author)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(item.publishDate))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(item.id)
                    .contextMenu {
                        if item.author == store.currentUser.name || store.isCurrentUserAdmin {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingDeleteAlert = true
                            } label: {
                                Label("删除此公告", systemImage: "trash")
                            }
                            Divider()
                        }
                        if store.canCurrentUserPublishAnnouncements || store.isCurrentUserAdmin {
                            Button {
                                store.togglePinAnnouncement(id: item.id)
                            } label: {
                                Label(item.isPinned ? "取消置顶" : "置顶公告", systemImage: item.isPinned ? "pin.slash" : "pin")
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    // MARK: - 2. Card Grid View Layout
    
    private var cardGridView: some View {
        ScrollView {
            if sortedAnnouncements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 60)
                    Text(searchText.isEmpty ? "暂无团队公告" : "未找到匹配的公告")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 18)], spacing: 18) {
                    ForEach(sortedAnnouncements) { item in
                        announcementCard(for: item)
                            .onTapGesture {
                                modalSelectedAnnouncement = item
                                store.markAnnouncementAsRead(id: item.id)
                            }
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func announcementCard(for item: Announcement) -> some View {
        let isUserAcked = item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header Tags
            HStack(alignment: .center, spacing: 6) {
                if item.isPinned {
                    HStack(spacing: 3) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                        Text("置顶")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                PriorityBadge(priority: item.priority)
                
                Spacer()
                
                if item.requiresAcknowledgment {
                    if isUserAcked {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已确认")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.green)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text("待确认")
                        }
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.red)
                    }
                }
            }
            
            // Title
            Text(item.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Content Preview
            Text(item.content)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .lineSpacing(3)
            
            Spacer(minLength: 4)
            
            Divider()
            
            // Footer: Author & Date
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 11))
                    Text(item.author)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(item.publishDate))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(item.isPinned ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: item.isPinned ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
    
    // MARK: - Detail View (Split Mode)
    
    private var detailContentView: some View {
        Group {
            if let id = selectedAnnouncementID,
               let item = store.announcements.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title & Meta
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                if item.isPinned {
                                    Label("已置顶", systemImage: "pin.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                PriorityBadge(priority: item.priority)
                                
                                Spacer()
                                
                                if store.canCurrentUserPublishAnnouncements || store.isCurrentUserAdmin {
                                    Button(action: {
                                        store.togglePinAnnouncement(id: item.id)
                                    }) {
                                        Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                                    }
                                    .buttonStyle(.plain)
                                    .help(item.isPinned ? "取消置顶" : "置顶公告")
                                }
                                
                                if item.author == store.currentUser.name || store.isCurrentUserAdmin {
                                    Button(action: {
                                        itemToDelete = item
                                        showingDeleteAlert = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                            Text("删除")
                                        }
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                    .help("删除此公告")
                                }
                            }
                            
                            Text(item.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                Label(item.author, systemImage: "person.circle")
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
                        
                        // Acknowledgment Card & Sign-off Tracker
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
    
    // MARK: - Card Detail Modal (For Card Grid Mode)
    
    private func cardDetailModal(for item: Announcement) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(item.title)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("关闭") {
                    modalSelectedAnnouncement = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 12) {
                if item.isPinned {
                    Label("已置顶", systemImage: "pin.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                }
                PriorityBadge(priority: item.priority)
                Label(item.author, systemImage: "person.circle")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Label(formatFullDate(item.publishDate), systemImage: "clock")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.content)
                        .font(.system(size: 13.5))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                    
                    if let link = item.externalLink, let url = URL(string: link) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("查看相关参考链接或附件文档")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12.5))
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if item.requiresAcknowledgment {
                        acknowledgmentCard(for: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(width: 580, height: 500)
    }
    
    // MARK: - Acknowledgment Card (Strict Role-Based Security)
    
    private func acknowledgmentCard(for item: Announcement) -> some View {
        let totalMembers = max(store.allDiscoveredTeamMembers.count, item.acknowledgments.count)
        let ackedCount = item.acknowledgments.count
        let unackedMembers = store.unacknowledgedMembers(for: item)
        let progress = totalMembers > 0 ? Double(ackedCount) / Double(totalMembers) : 0.0
        let isAuthor = (item.author == store.currentUser.name)
        let canViewTracker = isAuthor || store.canCurrentUserPublishAnnouncements || store.isCurrentUserAdmin
        let currentUserAcked = item.acknowledgments.contains(where: { $0.memberName == store.currentUser.name })
        
        return VStack(alignment: .leading, spacing: 14) {
            // 1. Personal Action for Current Reader (Everyone sees this)
            if !currentUserAcked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📢 此公告需全员确认，请在仔细阅读后点击确认：")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        store.acknowledgeAnnouncement(id: item.id)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("本人已仔细阅读并确认已读")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    Text("您已确认已读")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                    if let ackDate = item.acknowledgedAt {
                        Text("(\(formatFullDate(ackDate)))")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // 2. Full Tracker Dashboard (Only visible for Admins / Announcement Author)
            if canViewTracker {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header with statistics and progress
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("全员已读跟踪看板 (仅管理员/发布者可见)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text("已读 \(ackedCount) / \(totalMembers) 人 (\(Int(progress * 100))%)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(unackedMembers.isEmpty ? .green : .orange)
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 7)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(unackedMembers.isEmpty ? Color.green : Color.orange)
                                .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 7)
                        }
                    }
                    .frame(height: 7)
                    
                    // Unread Members Section
                    if !unackedMembers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("未读人员 (\(unackedMembers.count) 人):", systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                if isAuthor || store.isCurrentUserAdmin {
                                    Button(action: {
                                        store.sendAcknowledgmentReminder(for: item)
                                        reminderAlertMessage = "已向 \(unackedMembers.count) 位未读成员（\(unackedMembers.map { $0.name }.joined(separator: "、"))）发送提醒通知！"
                                        showRemindSuccessAlert = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bell.badge.fill")
                                            Text("一键提醒未读成员")
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.small)
                                }
                            }
                            
                            // Unread member badges
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(unackedMembers) { member in
                                        HStack(spacing: 4) {
                                            Image(systemName: member.avatarSymbol)
                                                .font(.system(size: 9))
                                            Text(member.name)
                                                .font(.system(size: 11, weight: .medium))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("🎉 团队全员已 100% 确认已读！")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Acknowledged Details List
                    if !item.acknowledgments.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已确认已读成员 (\(item.acknowledgments.count) 人)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(item.acknowledgments) { ack in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 11))
                                    Text(ack.memberName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(formatFullDate(ack.acknowledgedAt))
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
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

#Preview {
    AnnouncementsView()
        .environmentObject(WorkbenchStore())
}
