//
//  NPIQueryView.swift
//  团队工作台
//
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct NPIQueryView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var mailSyncService = MailSyncService.shared
    
    // Core Data state (Persisted in User Defaults + Shared folder if present)
    @State private var npiItems: [NpiIssueItem] = []
    
    // Filter States
    @State private var searchText: String = ""
    @State private var selectedProductFilter: String = "全部"
    @State private var selectedStatusFilter: String = "全部"
    @State private var onlyShowLatest: Bool = true
    
    // Manual Input / Sync Sheet
    @State private var showImportSheet: Bool = false
    @State private var importMailContent: String = ""
    @State private var importMailSubject: String = ""
    @State private var importMailDate: Date = Date()
    @State private var importedFeedbackToast: String? = nil
    
    // Detail Item selection for preview
    @State private var selectedItem: NpiIssueItem? = nil
    @State private var showConfirmClearAlert: Bool = false
    @State private var itemToDelete: NpiIssueItem? = nil
    @State private var showDeleteItemAlert: Bool = false
    
    // Dynamic available product categories extracted from existing data
    private var dynamicProductTypes: [String] {
        let unique = Array(Set(npiItems.map { $0.productType })).sorted()
        return ["全部"] + unique
    }
    
    // Available status categories
    private let statusCategories = ["全部", "需提交RTA", "无需RTA", "积极投票", "需关注更新", "已修复"]
    
    // Latest date lookup map per issue ID to identify archived vs latest
    private var latestDateMap: [String: String] {
        var map: [String: String] = [:]
        for item in npiItems {
            if let existing = map[item.id] {
                if item.date > existing {
                    map[item.id] = item.date
                }
            } else {
                map[item.id] = item.date
            }
        }
        return map
    }
    
    // Filtered & Sorted Items
    private var filteredItems: [NpiIssueItem] {
        let latestMap = self.latestDateMap
        let tokens = searchText.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        
        return npiItems.filter { item in
            let isLatest = (item.date == latestMap[item.id])
            
            // 1. Only show latest filter
            if onlyShowLatest && !isLatest {
                return false
            }
            
            // 2. Product filter
            if selectedProductFilter != "全部" && item.productType != selectedProductFilter {
                return false
            }
            
            // 3. Status filter
            if selectedStatusFilter != "全部" && item.status != selectedStatusFilter {
                return false
            }
            
            // 4. Multi-keyword search
            if !tokens.isEmpty {
                let combined = "\(item.id) \(item.title) \(item.desc) \(item.guidance) \(item.productType) \(item.emailSubject) \(item.date)"
                return tokens.allSatisfy { token in
                    combined.localizedCaseInsensitiveContains(token)
                }
            }
            return true
        }
        .sorted { first, second in
            if first.date != second.date {
                return first.date > second.date
            }
            return first.id < second.id
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
            
            Divider()
            
            // Metrics Summary Grid Bar
            metricsSummaryBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // Filter Bar (Search + Dynamic Products + Status + Only Latest Toggle)
            filterControlBar
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Issue Table List
            mainTableListView
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadNpiData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .masterSyncDidComplete)) { _ in
            syncNPIIssuesDirectlyFromMail()
        }
        .sheet(isPresented: $showImportSheet) {
            importMailSheetView
        }
        .sheet(item: $selectedItem) { item in
            issueDetailModal(for: item)
        }
        .alert("确认清空全部 NPI 议题数据？", isPresented: $showConfirmClearAlert) {
            Button("清空全部", role: .destructive) {
                clearAllData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将清除本地存储的所有已解析议题（当前共 \(npiItems.count) 条记录）。此操作仅超级管理员有权执行。")
        }
        .alert("确认删除该议题？", isPresented: $showDeleteItemAlert) {
            Button("删除", role: .destructive) {
                if let target = itemToDelete {
                    deleteItem(target)
                    if selectedItem?.id == target.id {
                        selectedItem = nil
                    }
                    itemToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            let targetId = itemToDelete.map { issueDigits(from: $0.id) } ?? ""
            Text("确认永久删除议题 \(targetId) 吗？删除后不可恢复。")
        }
    }
    
    // MARK: - 1. Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.teal)
                    
                    Text("NPI问题追踪")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("Issue Tracker & RTA")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("仅收录源自 fy26_gc_npicomms@apple.com 且含 [FY26 GC NPI] 的官方已知问题与 RTA 应对方案")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 10) {
                if store.canCurrentUserSyncData {
                    // 同步最新邮件 (触发 MailSyncService 自动同步并提取)
                    Button(action: {
                        triggerSyncFromMail()
                    }) {
                        HStack(spacing: 4) {
                            if mailSyncService.isSyncing {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(mailSyncService.isSyncing ? "检查中..." : "检查最新邮件")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.regular)
                    .disabled(mailSyncService.isSyncing)
                    
                    // 文本手动导入
                    Button(action: {
                        importMailContent = ""
                        importMailSubject = ""
                        importMailDate = Date()
                        showImportSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("文本导入")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                
                Button(action: {
                    exportToCSV()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("导出 CSV")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(npiItems.isEmpty)
                
                if store.isCurrentUserSuperAdmin && !npiItems.isEmpty {
                    Button(role: .destructive, action: {
                        showConfirmClearAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("清空数据")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }
    
    // MARK: - 2. Metrics Summary Bar
    
    private var metricsSummaryBar: some View {
        HStack(spacing: 14) {
            let total = filteredItems.count
            let needRTA = filteredItems.filter { $0.status == "需提交RTA" }.count
            let noRTA = filteredItems.filter { $0.status == "无需RTA" }.count
            let vote = filteredItems.filter { $0.status == "积极投票" }.count
            let watchUpdate = filteredItems.filter { $0.status == "需关注更新" }.count
            let latestMap = self.latestDateMap
            let archivedCount = npiItems.filter { $0.date < (latestMap[$0.id] ?? "") }.count
            
            metricBadge(title: "当前显示议题", count: "\(total)", color: .primary, icon: "tray.full.fill")
            metricBadge(title: "需提交 RTA", count: "\(needRTA)", color: .red, icon: "exclamationmark.octagon.fill")
            metricBadge(title: "无需 RTA", count: "\(noRTA)", color: .green, icon: "checkmark.circle.fill")
            if watchUpdate > 0 {
                metricBadge(title: "需关注更新", count: "\(watchUpdate)", color: .orange, icon: "arrow.triangle.2.circlepath.circle.fill")
            }
            if vote > 0 {
                metricBadge(title: "积极投票", count: "\(vote)", color: .blue, icon: "hand.thumbsup.fill")
            }
            if archivedCount > 0 {
                metricBadge(title: "历史更替", count: "\(archivedCount)", color: .secondary, icon: "clock.arrow.circlepath")
            }
            
            Spacer()
            
            if let toast = importedFeedbackToast {
                Text(toast)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
    }
    
    private func metricBadge(title: String, count: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            
            Text(count)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Filter Control Bar
    
    private var filterControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    
                    TextField("搜索 Issue ID (如 489632)、标题、描述、应对方案...", text: $searchText)
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
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .frame(width: 320)
                
                // Status Filter Menu
                Picker("状态", selection: $selectedStatusFilter) {
                    ForEach(statusCategories, id: \.self) { st in
                        Text(st).tag(st)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                
                // Toggle Only Latest
                let latestMap = self.latestDateMap
                let hiddenArchivedCount = npiItems.filter { $0.date < (latestMap[$0.id] ?? "") }.count
                Toggle(isOn: $onlyShowLatest) {
                    Text(hiddenArchivedCount > 0 && onlyShowLatest ? "隐藏历史更替版本 (已隐藏 \(hiddenArchivedCount) 条)" : "隐藏历史更替版本 (只看最新)")
                        .font(.system(size: 11.5))
                        .foregroundColor(onlyShowLatest ? .teal : .secondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                if selectedProductFilter != "全部" || selectedStatusFilter != "全部" || !searchText.isEmpty {
                    Button("重置筛选") {
                        searchText = ""
                        selectedProductFilter = "全部"
                        selectedStatusFilter = "全部"
                        onlyShowLatest = true
                    }
                    .font(.system(size: 11.5))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            
            // Dynamic Product Type Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("产品线:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ForEach(dynamicProductTypes, id: \.self) { prod in
                        let isSelected = (selectedProductFilter == prod)
                        Button(action: {
                            selectedProductFilter = prod
                        }) {
                            Text(prod)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.teal : Color.secondary.opacity(0.08))
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - 4. Main Table List View
    
    private var mainTableListView: some View {
        VStack(spacing: 0) {
            // Table Header Bar
            tableHeaderBar
            
            Divider()
            
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.teal)
                    }
                    Text(npiItems.isEmpty ? "暂无进行中的 NPI 问题追踪" : "未找到匹配的 NPI 议题")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text(npiItems.isEmpty ? "当前 NPI 刚开始，尚未记录到来自 fy26_gc_npicomms@apple.com 的阻碍议题。\n后续收到 🔥 [FY26 GC NPI] 邮件后，点击右上角「同步最新邮件」即可自动提取。" : "请调整搜索词或分类筛选条件")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.uniqueKey) { index, item in
                            tableRowView(item, index: index)
                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    private var tableHeaderBar: some View {
        HStack(spacing: 16) {
            Text("Issue / ID")
                .frame(width: 125, alignment: .leading)
            
            Text("日期")
                .frame(width: 90, alignment: .leading)
            
            Text("产品类型")
                .frame(width: 110, alignment: .leading)
            
            Text("问题描述与解决方案")
                .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            
            Text("方案指引")
                .frame(width: 170, alignment: .leading)
            
            Text("来源邮件主题")
                .frame(width: 210, alignment: .leading)
        }
        .font(.system(size: 12.5, weight: .bold))
        .foregroundColor(Color.primary.opacity(0.85))
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }
    
    private func tableRowView(_ item: NpiIssueItem, index: Int) -> some View {
        let isLatest = (item.date == latestDateMap[item.id])
        let isArchived = !isLatest
        let displayId = issueDigits(from: item.id)
        
        return HStack(alignment: .top, spacing: 16) {
            // 1. Issue / ID (关联 Core 链接: core://issueId=...)
            HStack(spacing: 4) {
                Button(action: {
                    openIssueLink(id: item.id)
                }) {
                    HStack(spacing: 3.5) {
                        Text(displayId)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .underline()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9.5))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("在 Core 中打开此议题 (core://issueId=\(displayId))")
                
                if isArchived {
                    Text("更替")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(width: 125, alignment: .leading)
            
            // 2. 日期
            Text(item.date)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
                .padding(.top, 2)
            
            // 3. 产品类型
            Text(item.productType)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(productColor(item.productType).opacity(0.12))
                .foregroundColor(productColor(item.productType))
                .clipShape(Capsule())
                .frame(width: 110, alignment: .leading)
                .padding(.top, 1)
            
            // 4. 问题描述与解决方案
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                
                if !item.desc.isEmpty && item.desc != item.title {
                    Text(item.desc)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
            
            // 5. 方案指引
            VStack(alignment: .leading, spacing: 4) {
                statusBadge(item.status)
                
                if !item.guidance.isEmpty {
                    Text(item.guidance)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            .frame(width: 170, alignment: .leading)
            
            // 6. 来源邮件主题
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .padding(.top, 2)
                
                Text(item.emailSubject.isEmpty ? "-" : item.emailSubject)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            .frame(width: 210, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(index % 2 == 0 ? Color(NSColor.controlBackgroundColor).opacity(0.35) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
        }
        .contextMenu {
            Button(action: {
                openIssueLink(id: item.id)
            }) {
                Label("在 Core 中打开 (\(displayId))", systemImage: "arrow.up.right.square")
            }
            Button(action: {
                copyToClipboard(displayId)
            }) {
                Label("复制纯数字 ID", systemImage: "doc.on.doc")
            }
            Button(action: {
                let text = "\(displayId) | \(item.title)\n描述：\(item.desc)\n应对方案：\(item.guidance) (\(item.status))"
                copyToClipboard(text)
            }) {
                Label("复制完整方案", systemImage: "doc.on.clipboard")
            }
            if store.isCurrentUserSuperAdmin {
                Divider()
                Button(role: .destructive, action: {
                    itemToDelete = item
                    showDeleteItemAlert = true
                }) {
                    Label("删除此议题", systemImage: "trash")
                }
            }
        }
    }
    
    private func statusBadge(_ status: String) -> some View {
        let (color, bg) = statusColors(status)
        return Text(status)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    private func statusColors(_ status: String) -> (Color, Color) {
        switch status {
        case "需提交RTA":
            return (.red, Color.red.opacity(0.12))
        case "无需RTA":
            return (.green, Color.green.opacity(0.12))
        case "积极投票":
            return (.blue, Color.blue.opacity(0.12))
        case "需关注更新":
            return (.orange, Color.orange.opacity(0.12))
        default:
            return (.secondary, Color.secondary.opacity(0.1))
        }
    }
    
    private func productColor(_ pt: String) -> Color {
        let lower = pt.lowercased()
        if lower.contains("ios") || lower.contains("iphone") { return .indigo }
        if lower.contains("ipad") { return .green }
        if lower.contains("mac") { return .blue }
        if lower.contains("watch") { return .purple }
        if lower.contains("airpods") { return .pink }
        if lower.contains("账户") || lower.contains("apple id") { return .teal }
        return .orange
    }
    
    // MARK: - 5. Detail Modal
    
    private func issueDetailModal(for item: NpiIssueItem) -> some View {
        let displayId = issueDigits(from: item.id)
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("NPI 议题详情")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("关闭") {
                    selectedItem = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(displayId)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Text(item.date)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(item.productType)
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(productColor(item.productType).opacity(0.12))
                        .foregroundColor(productColor(item.productType))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    statusBadge(item.status)
                }
                
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("问题描述：")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Text(item.desc)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("官方应对与解决方案：")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Text(item.guidance)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                if !item.emailSubject.isEmpty {
                    Text("来源邮件：\(item.emailSubject)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Button("在 Core 中打开此议题") {
                    openIssueLink(id: item.id)
                }
                .buttonStyle(.bordered)
                
                if store.isCurrentUserSuperAdmin {
                    Button(role: .destructive, action: {
                        itemToDelete = item
                        showDeleteItemAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("删除此议题")
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("复制完整方案") {
                    let text = "\(displayId) | \(item.title)\n描述：\(item.desc)\n应对方案：\(item.guidance) (\(item.status))"
                    copyToClipboard(text)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
    
    // MARK: - 6. Import Mail Sheet
    
    private var importMailSheetView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("文本导入新 NPI 邮件内容")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("取消") {
                    showImportSheet = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("支持直接粘贴当天收到的 NPI Green Email 正文，系统将自动正则提取 Issue 编号、产品分类与应对方案：")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("邮件主题 (选填)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    TextField("例如: [FY26 GC NPI] Green Email 20260905", text: $importMailSubject)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("邮件日期")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $importMailDate, displayedComponents: [.date])
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
            }
            
            TextEditor(text: $importMailContent)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .frame(height: 180)
            
            HStack {
                Spacer()
                Button("开始解析并入库") {
                    parseAndImportText()
                    showImportSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(importMailContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
    
    // MARK: - Data Operations & Logics
    
    private let npiStorageKey = "workbench_npi_issues_v1"
    
    private func triggerSyncFromMail() {
        Task {
            syncNPIIssuesDirectlyFromMail()
        }
    }
    
    // 直接独立通过 AppleScript 从 Mail.app 查询并提取来自 fy26_gc_npicomms@apple.com 的 [FY26 GC NPI] 邮件议题
    private func syncNPIIssuesDirectlyFromMail() {
        let script = """
        tell application "Mail"
            set npiRecords to {}
            set targetSender to "fy26_gc_npicomms@apple.com"
            set targetSubject to "[FY26 GC NPI]"
            
            -- 1. 优先检索收件箱
            tell inbox
                try
                    set msgs to (messages whose sender contains targetSender)
                    repeat with msg in msgs
                        set msgSubj to subject of msg
                        if msgSubj contains targetSubject and msgSubj does not contain "[TEST NPI]" and msgSubj does not contain "联调测试" then
                            set msgDate to date received of msg
                            set y to (year of msgDate as integer) as string
                            set m to (month of msgDate as integer) as string
                            if length of m is 1 then set m to "0" & m
                            set d to (day of msgDate as integer) as string
                            if length of d is 1 then set d to "0" & d
                            set formattedDate to y & "-" & m & "-" & d
                            set msgPlain to (content of msg)
                            set end of npiRecords to {msgSubj, formattedDate, msgPlain}
                        end if
                    end repeat
                end try
            end tell
            
            return npiRecords
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let descriptor = appleScript?.executeAndReturnError(&errorDict)
            
            if let error = errorDict {
                DispatchQueue.main.async {
                    let errStr = error["NSAppleScriptErrorMessage"] as? String ?? "权限受限或未授权访问邮件 App"
                    self.importedFeedbackToast = "⚠️ 同步失败：\(errStr)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.importedFeedbackToast = nil
                    }
                }
                return
            }
            
            guard let descriptor = descriptor, descriptor.numberOfItems > 0 else {
                DispatchQueue.main.async {
                    self.importedFeedbackToast = "未检索到匹配的 NPI 官方发布邮件"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.importedFeedbackToast = nil
                    }
                }
                return
            }
            
            var extractedList: [NpiIssueItem] = []
            
            for i in 1...descriptor.numberOfItems {
                guard let itemDesc = descriptor.atIndex(i) else { continue }
                let subj = itemDesc.atIndex(1)?.stringValue ?? ""
                let dateVal = itemDesc.atIndex(2)?.stringValue ?? ""
                let body = itemDesc.atIndex(3)?.stringValue ?? ""
                
                let parsed = self.parseNpiIssues(from: body, dateVal: dateVal, subj: subj)
                extractedList.append(contentsOf: parsed)
            }
            
            DispatchQueue.main.async {
                var totalAdded = 0
                for item in extractedList {
                    if let existingIndex = self.npiItems.firstIndex(where: { $0.id == item.id && $0.date == item.date }) {
                        // 更新旧记录为修正后的正确数据
                        self.npiItems[existingIndex] = item
                    } else {
                        self.npiItems.insert(item, at: 0)
                        totalAdded += 1
                    }
                }
                self.saveNpiData()
                if totalAdded > 0 {
                    self.importedFeedbackToast = "🎉 成功从邮件中同步 \(totalAdded) 个新议题！"
                } else if !extractedList.isEmpty {
                    self.importedFeedbackToast = "已刷新并校准 \(extractedList.count) 个议题的状态与分类！"
                } else {
                    self.importedFeedbackToast = "检索完成：未发现新议题（已同步过或无匹配格式）"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.importedFeedbackToast = nil
                }
            }
        }
    }
    
    private func loadNpiData() {
        if let data = UserDefaults.standard.data(forKey: npiStorageKey),
           let decoded = try? JSONDecoder().decode([NpiIssueItem].self, from: data) {
            // 排除历史误入的测试邮件或非官方 NPI 内容
            self.npiItems = decoded.filter { item in
                let subj = item.emailSubject.lowercased()
                return !subj.contains("[test npi]") &&
                       !subj.contains("联调测试") &&
                       !subj.contains("green email - 近期重要内容") &&
                       !subj.contains("carpe facto") &&
                       !subj.contains("针对协议相关的规程更新")
            }
        }
    }
    
    private func saveNpiData() {
        if let encoded = try? JSONEncoder().encode(npiItems) {
            UserDefaults.standard.set(encoded, forKey: npiStorageKey)
        }
    }
    
    private func parseAndImportText() {
        let text = importMailContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateVal = df.string(from: importMailDate)
        let subj = importMailSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🔥 [FY26 GC NPI] 邮件导入" : importMailSubject
        
        let parsed = parseNpiIssues(from: text, dateVal: dateVal, subj: subj)
        var addedCount = 0
        for item in parsed {
            if let existingIndex = npiItems.firstIndex(where: { $0.id == item.id && $0.date == item.date }) {
                npiItems[existingIndex] = item
            } else {
                npiItems.insert(item, at: 0)
                addedCount += 1
            }
        }
        
        saveNpiData()
        importedFeedbackToast = "🎉 成功解析并导入 \(addedCount) 个新议题！"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            importedFeedbackToast = nil
        }
    }
    
    // MARK: - Core NPI Parser & Product Classification
    
    private func detectProductType(title: String, desc: String) -> String {
        let lowerTitle = title.lowercased()
        
        // 1. 优先从自身标题的前缀和关键词精确归类（iPadOS 必须在 iOS 之前判断以防被包含）
        if lowerTitle.contains("ipados") || lowerTitle.contains("ipad") {
            return "iPadOS 26"
        }
        if lowerTitle.contains("ios") || lowerTitle.contains("iphone") {
            return "iOS 26"
        }
        if lowerTitle.contains("macos") || lowerTitle.contains("macbook") || lowerTitle.contains("imac") || lowerTitle.contains("mac mini") || lowerTitle.contains("mac pro") || lowerTitle.contains("mac studio") || lowerTitle.contains("tahoe") {
            return "Mac / macOS"
        }
        if lowerTitle.contains("watchos") || lowerTitle.contains("apple watch") || lowerTitle.contains("watch") || lowerTitle.contains("表盘") {
            return "Apple Watch"
        }
        if lowerTitle.contains("airpods") || lowerTitle.contains("耳机") {
            return "AirPods"
        }
        if lowerTitle.contains("visionos") || lowerTitle.contains("vision pro") {
            return "visionOS"
        }
        if lowerTitle.contains("账户") || lowerTitle.contains("apple id") || lowerTitle.contains("登录") || lowerTitle.contains("密码") {
            return "Apple 账户"
        }
        if lowerTitle.contains("rcc") || lowerTitle.contains("旗舰店") {
            return "零售与运营"
        }
        
        // 2. 若标题未直接命中，且存在独立的详情描述，才在描述中搜寻
        if desc != title && !desc.isEmpty {
            let lowerDesc = desc.lowercased()
            if lowerDesc.contains("ipados") || lowerDesc.contains("ipad") { return "iPadOS 26" }
            if lowerDesc.contains("ios") || lowerDesc.contains("iphone") || lowerDesc.contains("相机控制") || lowerDesc.contains("oled") { return "iOS 26" }
            if lowerDesc.contains("macos") || lowerDesc.contains("mac") || lowerDesc.contains("访达") { return "Mac / macOS" }
            if lowerDesc.contains("watch") { return "Apple Watch" }
            if lowerDesc.contains("airpods") { return "AirPods" }
            if lowerDesc.contains("rcc") || lowerDesc.contains("旗舰店") { return "零售与运营" }
        }
        
        return "iOS 26"
    }

    private func parseNpiIssues(from text: String, dateVal: String, subj: String) -> [NpiIssueItem] {
        let lines = text.components(separatedBy: .newlines)
        var items: [NpiIssueItem] = []
        var sectionStatus: String? = nil
        
        // 匹配真正 Issue 的行首正则（必须位于行首，允许有列表符号如 •、-、*，或 IT 487701）
        guard let issueRegex = try? NSRegularExpression(
            pattern: #"^\s*(?:[-•*·▪]\s*|\d+[\.、]\s*|(?:IT|Issue)\s*[:：\s]*)?(\d{5,6})\s*[-–—:：]\s*(.+)$"#,
            options: .caseInsensitive
        ) else {
            return []
        }
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1
            if line.isEmpty { continue }
            
            // 1. 检查是否为小节状态标记行
            if line.contains("无需提交 RTA") || line.contains("无需 RTA") || line.contains("不需要 RTA") || line.contains("暂不需 RTA") {
                sectionStatus = "无需RTA"
                continue
            } else if line.contains("需提交 RTA") || line.contains("提交 RTA") || line.contains("必须提交 RTA") {
                sectionStatus = "需提交RTA"
                continue
            } else if line.contains("积极投票") || line.contains("投票") {
                sectionStatus = "积极投票"
                continue
            } else if line.contains("临时应对") || line.contains("工程部需求") {
                sectionStatus = "需关注更新"
                continue
            }
            
            // 2. 严格排除引用与 KB 参考说明行（例如：“参考 (124676 - 已知问题或新出现的问题)...”）
            if line.hasPrefix("参考") || line.hasPrefix("请参考") || line.hasPrefix("参见") ||
               line.hasPrefix("(") || line.hasPrefix("（") || line.contains("KB指引") || line.contains("知识库") {
                continue
            }
            
            // 3. 匹配是否为独立 Issue 条目
            guard let match = issueRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }
            
            let numId = String(line[Range(match.range(at: 1), in: line)!])
            let title = String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces)
            let prefix = (numId.count == 5 || numId.hasPrefix("10") || numId.hasPrefix("11") || numId.hasPrefix("12")) ? "KB " : "IT "
            let fullId = prefix + numId
            
            // 4. 收集当前 Issue 后续的补充描述与方案指引行 (支持 KB 引用纳入方案说明)
            var followUpLines: [String] = []
            while i < lines.count {
                let nextL = lines[i].trimmingCharacters(in: .whitespaces)
                if nextL.isEmpty {
                    i += 1
                    continue
                }
                
                // 检查下一行是否是另一个真正的 Issue 条目（需排除“参考 (124676 - ... )”等 KB 参考行）
                let isReferenceLine = nextL.hasPrefix("参考") || nextL.hasPrefix("请参考") || nextL.hasPrefix("参见") ||
                                      nextL.hasPrefix("(") || nextL.hasPrefix("（")
                let matchesIssuePattern = (issueRegex.firstMatch(in: nextL, range: NSRange(nextL.startIndex..., in: nextL)) != nil)
                let isNextIssue = matchesIssuePattern && !isReferenceLine
                let isNextSection = nextL.contains("Issue Tracker 已被") || nextL.contains("以下 Issue Tracker")
                
                if isNextIssue || isNextSection {
                    break
                }
                
                followUpLines.append(nextL)
                i += 1
            }
            
            // 5. 精确判定该 Issue 的状态
            let combinedFollowUp = followUpLines.joined(separator: " ")
            let issueStatus: String
            if combinedFollowUp.contains("无需提交 RTA") || combinedFollowUp.contains("无需 RTA") || combinedFollowUp.contains("不需要 RTA") {
                issueStatus = "无需RTA"
            } else if combinedFollowUp.contains("需提交 RTA") || combinedFollowUp.contains("请提交 RTA") || combinedFollowUp.contains("必须提交 RTA") {
                issueStatus = "需提交RTA"
            } else if combinedFollowUp.contains("积极投票") || combinedFollowUp.contains("投票") {
                issueStatus = "积极投票"
            } else if combinedFollowUp.contains("临时应对") || combinedFollowUp.contains("工程部需求") || combinedFollowUp.contains("工程部") {
                issueStatus = "需关注更新"
            } else if let sec = sectionStatus {
                issueStatus = sec
            } else {
                // 邮件中未指明是否需要提交 RTA 时，标记为「需关注更新」
                issueStatus = "需关注更新"
            }
            
            // 6. 生成方案指引文本
            let guidanceText: String
            if !followUpLines.isEmpty {
                guidanceText = followUpLines.joined(separator: " ")
            } else if issueStatus == "无需RTA" {
                guidanceText = "参考官方 NPI 邮件应对方案；目前无需提交 RTA"
            } else if issueStatus == "积极投票" {
                guidanceText = "参考官方 NPI 邮件应对方案；请在 Issue Tracker 中积极投票"
            } else if issueStatus == "需关注更新" {
                guidanceText = "参考官方 NPI 邮件应对方案；请关注后续更新"
            } else {
                guidanceText = "参考官方 NPI 邮件应对方案；必要时提交 RTA"
            }
            
            let descText = followUpLines.first ?? title
            let pt = detectProductType(title: title, desc: descText)
            
            let item = NpiIssueItem(
                id: fullId,
                date: dateVal,
                productType: pt,
                title: title,
                desc: descText,
                guidance: guidanceText,
                status: issueStatus,
                emailSubject: subj
            )
            items.append(item)
        }
        
        return items
    }
    
    private func issueDigits(from id: String) -> String {
        let digits = id.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.isEmpty ? id.trimmingCharacters(in: .whitespaces) : digits
    }
    
    private func openIssueLink(id: String) {
        let num = issueDigits(from: id)
        if let url = URL(string: "core://issueId=\(num)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func exportToCSV() {
        var csv = "\u{FEFF}Issue ID,日期,产品类型,议题摘要,问题描述,应对措施,方案指引,原始邮件主题\n"
        for i in npiItems {
            csv += "\"\(i.id)\",\"\(i.date)\",\"\(i.productType)\",\"\(i.title.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(i.desc.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(i.guidance.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(i.status)\",\"\(i.emailSubject.replacingOccurrences(of: "\"", with: "\"\""))\"\n"
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "NPI_Issues_\(Date().formatted(.iso8601.year().month().day())).csv"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func deleteItem(_ item: NpiIssueItem) {
        guard store.isCurrentUserSuperAdmin else { return }
        npiItems.removeAll { $0.id == item.id && $0.date == item.date }
        saveNpiData()
        importedFeedbackToast = "已删除议题 \(issueDigits(from: item.id))"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            importedFeedbackToast = nil
        }
    }
    
    private func clearAllData() {
        guard store.isCurrentUserSuperAdmin else { return }
        npiItems.removeAll()
        saveNpiData()
        importedFeedbackToast = "已清空所有 NPI 议题数据"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            importedFeedbackToast = nil
        }
    }
}

#Preview {
    NPIQueryView()
        .environmentObject(WorkbenchStore())
}
