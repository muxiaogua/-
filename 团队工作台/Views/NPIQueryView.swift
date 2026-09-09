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
        .sheet(isPresented: $showImportSheet) {
            importMailSheetView
        }
        .sheet(item: $selectedItem) { item in
            issueDetailModal(for: item)
        }
    }
    
    // MARK: - 1. Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.teal)
                    
                    Text("NPI 检索")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("NPI 重点议题追踪")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("源自 fy26_gc_npicomms@apple.com 及 [FY26 GC NPI] 重点推送的已知问题与 RTA 追踪")
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
                            Text(mailSyncService.isSyncing ? "同步中..." : "同步最新邮件")
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
            
            metricBadge(title: "当前显示议题", count: "\(total)", color: .primary, icon: "tray.full.fill")
            metricBadge(title: "需提交 RTA", count: "\(needRTA)", color: .red, icon: "exclamationmark.octagon.fill")
            metricBadge(title: "无需 RTA", count: "\(noRTA)", color: .green, icon: "checkmark.circle.fill")
            metricBadge(title: "积极投票", count: "\(vote)", color: .blue, icon: "hand.thumbsup.fill")
            
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
                Toggle(isOn: $onlyShowLatest) {
                    Text("隐藏已更替旧版本 (只看最新)")
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
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(npiItems.isEmpty ? "暂无 NPI 议题数据，可点击右上角导入最新邮件内容" : "未找到匹配的议题")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            issueCardRow(item)
                                .onTapGesture {
                                    selectedItem = item
                                }
                        }
                    }
                    .padding(18)
                }
            }
        }
    }
    
    private func issueCardRow(_ item: NpiIssueItem) -> some View {
        let isLatest = (item.date == latestDateMap[item.id])
        let isArchived = !isLatest
        
        return VStack(alignment: .leading, spacing: 8) {
            // Header Row: Issue ID + Date + Product Tag + Status Badge
            HStack(alignment: .center, spacing: 8) {
                // Linkable ID button
                Button(action: {
                    openIssueLink(id: item.id)
                }) {
                    HStack(spacing: 3) {
                        Text(item.id)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("在浏览器中打开此 Issue 对应链接")
                
                Text(item.date)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                if isArchived {
                    Text("[已更替]")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                
                // Product Tag
                Text(item.productType)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(productColor(item.productType).opacity(0.12))
                    .foregroundColor(productColor(item.productType))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Status Badge
                statusBadge(item.status)
            }
            
            // Title
            Text(item.title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Description
            if !item.desc.isEmpty && item.desc != item.title {
                Text("问题描述: \(item.desc)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Guidance Box
            HStack(alignment: .top, spacing: 6) {
                Text("💡")
                    .font(.system(size: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("应对措施: \(item.guidance)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isArchived {
                        Text("⚠️ 此为历史应对方案，请参考最新日期的更新")
                            .font(.system(size: 10.5))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    let text = "\(item.id) | \(item.title)\n应对措施：\(item.guidance) (\(item.status))"
                    copyToClipboard(text)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制该议题应对措施")
            }
            .padding(8)
            .background(isArchived ? Color.secondary.opacity(0.06) : Color.teal.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isArchived ? Color.secondary.opacity(0.1) : Color.teal.opacity(0.2), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 18) {
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
                    Text(item.id)
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
                    .font(.system(size: 16, weight: .bold))
                
                Text("现象描述：")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(item.desc)
                    .font(.system(size: 13.5))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("应对方案与指导：")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(item.guidance)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.teal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                if !item.emailSubject.isEmpty {
                    Text("来源邮件：\(item.emailSubject)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Button("在新标签打开 IssueTracker / KB") {
                    openIssueLink(id: item.id)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("复制完整方案") {
                    let text = "\(item.id) | \(item.title)\n描述：\(item.desc)\n应对方案：\(item.guidance) (\(item.status))"
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
            
            tell inbox
                try
                    set msgs to (messages whose (sender contains targetSender and subject contains targetSubject))
                    repeat with msg in msgs
                        set msgSubj to subject of msg
                        set msgDate to date received of msg
                        set y to (year of msgDate as integer) as string
                        set m to (month of msgDate as integer) as string
                        if length of m is 1 then set m to "0" & m
                        set d to (day of msgDate as integer) as string
                        if length of d is 1 then set d to "0" & d
                        set formattedDate to y & "-" & m & "-" & d
                        set msgPlain to (content of msg)
                        set end of npiRecords to {msgSubj, formattedDate, msgPlain}
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
            
            guard let descriptor = descriptor, descriptor.numberOfItems > 0 else {
                return
            }
            
            var extractedList: [NpiIssueItem] = []
            
            for i in 1...descriptor.numberOfItems {
                guard let itemDesc = descriptor.atIndex(i) else { continue }
                let subj = itemDesc.atIndex(1)?.stringValue ?? ""
                let dateVal = itemDesc.atIndex(2)?.stringValue ?? ""
                let body = itemDesc.atIndex(3)?.stringValue ?? ""
                
                let lines = body.components(separatedBy: .newlines)
                var currentStatus = "需提交RTA"
                
                for (idx, line) in lines.enumerated() {
                    let l = line.trimmingCharacters(in: .whitespaces)
                    if l.contains("需提交 RTA") || l.contains("提交 RTA") { currentStatus = "需提交RTA" }
                    else if l.contains("无需提交 RTA") || l.contains("无需 RTA") || l.contains("不需要 RTA") { currentStatus = "无需RTA" }
                    else if l.contains("积极投票") { currentStatus = "积极投票" }
                    
                    guard let regex = try? NSRegularExpression(pattern: #"(\d{5,6})\s*[-–—:]\s*([^\n\r]+)"#, options: .caseInsensitive),
                          let match = regex.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) else {
                        continue
                    }
                    
                    let numId = String(l[Range(match.range(at: 1), in: l)!])
                    let title = String(l[Range(match.range(at: 2), in: l)!]).trimmingCharacters(in: .whitespaces)
                    let prefix = (numId.count == 5 || numId.hasPrefix("10") || numId.hasPrefix("11") || numId.hasPrefix("12")) ? "KB " : "IT "
                    let fullId = prefix + numId
                    
                    var desc = title
                    for j in (idx + 1)..<min(idx + 4, lines.count) {
                        let nextL = lines[j].trimmingCharacters(in: .whitespaces)
                        if !nextL.isEmpty && !nextL.contains("Issue Tracker") && !nextL.contains("以下") {
                            desc = nextL
                            break
                        }
                    }
                    
                    var pt = "iOS 26"
                    let checkStr = (title + " " + desc).lowercased()
                    if checkStr.contains("账户") || checkStr.contains("apple id") || checkStr.contains("登录") { pt = "Apple 账户" }
                    else if checkStr.contains("airpods") || checkStr.contains("耳机") { pt = "AirPods" }
                    else if checkStr.contains("watch") || checkStr.contains("表盘") { pt = "Apple Watch" }
                    else if checkStr.contains("mac") || checkStr.contains("tahoe") || checkStr.contains("访达") { pt = "Mac / macOS" }
                    else if checkStr.contains("ipad") { pt = "iPadOS 26" }
                    else if checkStr.contains("iphone") || checkStr.contains("相机控制") || checkStr.contains("oled") { pt = "iPhone" }
                    else if checkStr.contains("rcc") || checkStr.contains("旗舰店") { pt = "零售与运营" }
                    
                    let item = NpiIssueItem(
                        id: fullId,
                        date: dateVal,
                        productType: pt,
                        title: title,
                        desc: desc,
                        guidance: "参考官方 NPI 邮件应对方案；" + (currentStatus == "需提交RTA" ? "必要时提交 RTA" : "目前无需提交 RTA"),
                        status: currentStatus,
                        emailSubject: subj
                    )
                    extractedList.append(item)
                }
            }
            
            DispatchQueue.main.async {
                var totalAdded = 0
                for item in extractedList {
                    if !self.npiItems.contains(where: { $0.id == item.id && $0.date == item.date }) {
                        self.npiItems.insert(item, at: 0)
                        totalAdded += 1
                    }
                }
                if totalAdded > 0 {
                    self.saveNpiData()
                    self.importedFeedbackToast = "🎉 成功从官方 NPI 邮件中同步 \(totalAdded) 个议题！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.importedFeedbackToast = nil
                    }
                }
            }
        }
    }
    
    private func loadNpiData() {
        if let data = UserDefaults.standard.data(forKey: npiStorageKey),
           let decoded = try? JSONDecoder().decode([NpiIssueItem].self, from: data) {
            self.npiItems = decoded
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
        let subj = importMailSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "[GC NPI] 邮件导入" : importMailSubject
        
        let lines = text.components(separatedBy: .newlines)
        var addedCount = 0
        var currentStatus = "需提交RTA"
        
        for (idx, line) in lines.enumerated() {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.contains("需提交 RTA") || l.contains("提交 RTA") { currentStatus = "需提交RTA" }
            else if l.contains("无需提交 RTA") || l.contains("无需 RTA") || l.contains("不需要 RTA") { currentStatus = "无需RTA" }
            else if l.contains("积极投票") { currentStatus = "积极投票" }
            
            // Regex match (\d{5,6})\s*[-–—:]\s*(.+)
            if let regex = try? NSRegularExpression(pattern: #"(\d{5,6})\s*[-–—:]\s*([^\n\r]+)"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)) {
                let numId = String(l[Range(match.range(at: 1), in: l)!])
                let title = String(l[Range(match.range(at: 2), in: l)!]).trimmingCharacters(in: .whitespaces)
                let prefix = (numId.count == 5 || numId.hasPrefix("10") || numId.hasPrefix("11") || numId.hasPrefix("12")) ? "KB " : "IT "
                let fullId = prefix + numId
                
                var desc = title
                for j in (idx + 1)..<min(idx + 4, lines.count) {
                    let nextL = lines[j].trimmingCharacters(in: .whitespaces)
                    if !nextL.isEmpty && !nextL.contains("Issue Tracker") && !nextL.contains("以下") {
                        desc = nextL
                        break
                    }
                }
                
                // Dynamic product classification
                var pt = "iOS 26"
                let checkStr = (title + " " + desc).lowercased()
                if checkStr.contains("账户") || checkStr.contains("apple id") || checkStr.contains("登录") { pt = "Apple 账户" }
                else if checkStr.contains("airpods") || checkStr.contains("耳机") { pt = "AirPods" }
                else if checkStr.contains("watch") || checkStr.contains("表盘") { pt = "Apple Watch" }
                else if checkStr.contains("mac") || checkStr.contains("tahoe") || checkStr.contains("访达") { pt = "Mac / macOS" }
                else if checkStr.contains("ipad") { pt = "iPadOS 26" }
                else if checkStr.contains("iphone") || checkStr.contains("相机控制") || checkStr.contains("oled") { pt = "iPhone" }
                else if checkStr.contains("rcc") || checkStr.contains("旗舰店") { pt = "零售与运营" }
                
                let item = NpiIssueItem(
                    id: fullId,
                    date: dateVal,
                    productType: pt,
                    title: title,
                    desc: desc,
                    guidance: "参考最新邮件应对方案；" + (currentStatus == "需提交RTA" ? "必要时提交 RTA" : "目前无需提交 RTA"),
                    status: currentStatus,
                    emailSubject: subj
                )
                
                // Prepend item
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
    
    private func openIssueLink(id: String) {
        let clean = id.trimmingCharacters(in: .whitespaces)
        if let itMatch = clean.range(of: #"\d{6}"#, options: .regularExpression) {
            let num = String(clean[itMatch])
            if let url = URL(string: "https://issuetracker.apple.com/issues/\(num)") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let kbMatch = clean.range(of: #"\d{5,6}"#, options: .regularExpression) {
            let num = String(clean[kbMatch])
            if let url = URL(string: "https://support.apple.com/kb/HT\(num)") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let url = URL(string: "https://chorus.apple.com/search?query=\(clean)") {
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
}

#Preview {
    NPIQueryView()
        .environmentObject(WorkbenchStore())
}
