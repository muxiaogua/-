//
//  NPIMailsView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct NPIMailsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var npiSyncService = NPIMailSyncService.shared
    
    @State private var selectedEmailID: UUID?
    @State private var selectedFilter: String = "未读"
    @State private var onlyBookmarked: Bool = false
    @State private var searchText: String = ""
    @State private var showSyncAlert: Bool = false
    
    private let availableFilters = ["未读", "全部"]
    
    public init() {}
    
    private var filteredEmails: [NewsArticle] {
        let tokens = searchText.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        
        return store.npiEmails.filter { article in
            if selectedFilter == "未读" {
                // 未读过滤：未读或当前选中的邮件保留
                if store.readNpiEmailIDs.contains(article.id) && article.id != selectedEmailID {
                    return false
                }
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
            // Left: Compact NPI Emails List
            VStack(spacing: 0) {
                mailSearchAndFilterSection
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                compactEmailListSection
            }
            .frame(minWidth: 320, idealWidth: 370, maxWidth: 430)
            
            // Right: Reader Section
            emailReaderSection
                .frame(minWidth: 460, maxWidth: .infinity)
        }
        .alert("NPI 邮件同步结果", isPresented: $showSyncAlert) {
            if npiSyncService.needsPrivacySettingsGuide {
                Button("打开系统设置") {
                    npiSyncService.openAutomationPrivacySettings()
                }
                Button("稍后设置", role: .cancel) { }
            } else {
                Button("确定", role: .cancel) { }
            }
        } message: {
            if let error = npiSyncService.errorMessage {
                Text(error)
            } else if let result = npiSyncService.lastSyncResult {
                Text(result)
            }
        }
        .onAppear {
            handleInitialSelection()
        }
        .onChange(of: selectedFilter) { _, newFilter in
            if newFilter == "未读" && store.unreadNpiEmailsCount == 0 {
                selectedEmailID = nil
            } else if selectedEmailID == nil || !filteredEmails.contains(where: { $0.id == selectedEmailID }) {
                selectedEmailID = filteredEmails.first?.id
                if let firstID = selectedEmailID {
                    store.markNpiEmailAsRead(id: firstID)
                }
            }
        }
        .onChange(of: selectedEmailID) { _, newID in
            if let id = newID {
                store.markNpiEmailAsRead(id: id)
            }
        }
    }
    
    private func handleInitialSelection() {
        if selectedFilter == "未读" {
            if store.unreadNpiEmailsCount > 0 {
                selectedEmailID = filteredEmails.first?.id
                if let firstID = selectedEmailID {
                    store.markNpiEmailAsRead(id: firstID)
                }
            } else {
                selectedEmailID = nil
            }
        } else if selectedEmailID == nil {
            selectedEmailID = filteredEmails.first?.id
            if let firstID = selectedEmailID {
                store.markNpiEmailAsRead(id: firstID)
            }
        }
    }
    
    private func triggerSync() {
        Task {
            _ = await npiSyncService.syncNPIMailsFromMail(into: store)
            showSyncAlert = true
            handleInitialSelection()
        }
    }
    
    // MARK: - Left Search & Filter Header
    
    private var mailSearchAndFilterSection: some View {
        VStack(spacing: 8) {
            // 1. Search Bar + Sync Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    
                    TextField("搜索 NPI 邮件标题、内容...", text: $searchText)
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
                
                if store.canCurrentUserSyncData {
                    Button(action: { triggerSync() }) {
                        HStack(spacing: 4) {
                            if npiSyncService.isSyncing {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10.5))
                            }
                            Text(npiSyncService.isSyncing ? "检查中..." : "检查更新")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5.5)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(npiSyncService.isSyncing)
                    .help("检查 Apple Mail 中是否有最新 NPI 重点邮件更新")
                }
            }
            
            // 2. Filter Pills
            HStack(spacing: 6) {
                ForEach(availableFilters, id: \.self) { filter in
                    let isSelected = (selectedFilter == filter)
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: filter == "未读" ? "envelope.badge.fill" : "tray.full.fill")
                                .font(.system(size: 9.5))
                            Text(filter)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            
                            if filter == "未读" && store.unreadNpiEmailsCount > 0 {
                                Text("\(store.unreadNpiEmailsCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.white.opacity(0.3) : Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isSelected ? Color.orange : Color(NSColor.controlBackgroundColor))
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
            
            // 3. Sub Controls & Count
            HStack(spacing: 8) {
                Toggle(isOn: $onlyBookmarked) {
                    Label("只看收藏", systemImage: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundColor(onlyBookmarked ? .yellow : .secondary)
                }
                .toggleStyle(.checkbox)
                
                if store.unreadNpiEmailsCount > 0 {
                    Button(action: {
                        store.markAllNpiEmailsAsRead()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("全部已读")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if let lastSync = npiSyncService.lastSyncTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                        Text(npiSyncService.lastSyncedBy != nil && !npiSyncService.lastSyncedBy!.isEmpty ? "\(formatSyncTime(lastSync)) (\(npiSyncService.lastSyncedBy!))" : formatSyncTime(lastSync))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .help("上次同步时间：\(formatSyncTime(lastSync))\(npiSyncService.lastSyncedBy != nil ? " 由 \(npiSyncService.lastSyncedBy!) 同步" : "")")
                } else {
                    Text("尚未同步")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Text("· 共 \(filteredEmails.count) 封")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Left Email List
    
    private var compactEmailListSection: some View {
        Group {
            if selectedFilter == "未读" && filteredEmails.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.orange)
                    }
                    Text("暂无未读 NPI 邮件")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text("所有来自 fy26_gc_npicomms@apple.com 的 [FY26 GC NPI] 邮件均已阅读完成。\n可在上方切换至「全部」查看历史通报。")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                    
                    Button("从邮件 App 检查新邮件") {
                        triggerSync()
                    }
                    .font(.system(size: 11.5))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEmails.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "flame.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchText.isEmpty ? "暂无符合条件的 NPI 邮件" : "未找到匹配的 NPI 邮件")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("仅收录发件人为 fy26_gc_npicomms@apple.com\n且标题含 [FY26 GC NPI] 的官方通报")
                        .font(.system(size: 11.5))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button("从邮件 App 提取最新") {
                        triggerSync()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEmails, selection: $selectedEmailID) { article in
                    let isUnread = !store.readNpiEmailIDs.contains(article.id)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 6) {
                            if isUnread {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 4)
                            }
                            
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(.orange)
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
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundColor(.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            
                            if article.isBookmarked {
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 9))
                            }
                        }
                        
                        HStack {
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
    
    // MARK: - Right Reader Section
    
    private var emailReaderSection: some View {
        Group {
            if selectedFilter == "未读" && filteredEmails.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("暂无未读 NPI 邮件")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("当前没有待阅读的 NPI 重点通报，界面保持清爽")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else if let id = selectedEmailID,
               let article = store.npiEmails.first(where: { $0.id == id }) {
                VStack(spacing: 0) {
                    // Header Bar
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                            
                            HStack(spacing: 8) {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 10.5))
                                    Text(article.source)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.orange)
                                
                                Text("·")
                                    .foregroundColor(.secondary)
                                
                                Text(formatFullDate(article.publishDate))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            store.toggleNpiEmailBookmark(id: article.id)
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
                    
                    // Body
                    if let html = article.htmlContent, !html.isEmpty && !isHTMLBlank(html) {
                        HTMLMailView(htmlContent: html)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            Text(article.content)
                                .font(.system(size: 13.5))
                                .lineSpacing(5)
                                .padding(24)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("请在左侧选择一封 NPI 邮件进行阅读")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: date)
    }
    
    private func isHTMLBlank(_ html: String) -> Bool {
        if html.contains("<img") || html.contains("data:image/") {
            return false
        }
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty
    }
}

#Preview {
    NPIMailsView()
        .environmentObject(WorkbenchStore())
}
