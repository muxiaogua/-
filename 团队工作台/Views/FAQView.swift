//
//  FAQView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public enum FAQDatabase: String, CaseIterable, Identifiable {
    case rcc = "RCC 常见场景"
    case arsob = "ARS OB 常规咨询"
    case bts = "BTS 返校季"
    case aa = "AA FAQ"
    case sda = "SDA"
    case appleTV = "Apple TV"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .rcc: return "phone.fill"
        case .arsob: return "wrench.and.screwdriver.fill"
        case .bts: return "graduationcap.fill"
        case .aa: return "doc.text.fill"
        case .sda: return "shield.lefthalf.filled"
        case .appleTV: return "appletv.fill"
        }
    }
}

public struct FAQGroup: Identifiable {
    public let subCategory: String
    public let items: [FAQItem]
    public var id: String { subCategory }
}

public struct FAQView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var chorusSync = ChorusFAQSyncService.shared
    
    @State private var selectedDatabase: FAQDatabase = .rcc
    @State private var selectedSubCategory: String = "全部"
    @State private var searchQuery: String = ""
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var showSyncAlert = false
    @State private var copiedItemID: UUID? = nil
    @State private var isNavigatingProgrammatically: Bool = false
    
    public init() {}
    
    // Total items in currently selected knowledge base
    private var itemsInCurrentDB: [FAQItem] {
        store.faqItems.filter {
            $0.category == selectedDatabase.rawValue || ($0.category == "RCC" && selectedDatabase == .rcc)
        }
    }
    
    // Dynamically retrieve all subcategories under selected database
    private var subCategoryList: [String] {
        let items = itemsInCurrentDB
        var orderedNames: [String] = []
        
        for item in items {
            let subCat = item.tags.first(where: { $0 != item.category && $0 != "RCC" && $0 != "RCC 常见场景" }) ?? "常规问答"
            if !orderedNames.contains(subCat) {
                orderedNames.append(subCat)
            }
        }
        
        return ["全部"] + orderedNames
    }
    
    // Whether we should show the empty guidance prompt (when "全部" is selected and no search keyword)
    private var isBrowsingAllWithoutSearch: Bool {
        selectedSubCategory == "全部" && searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Grouped FAQ list based on database, subcategory, and search query
    private var groupedFAQs: [FAQGroup] {
        if isBrowsingAllWithoutSearch {
            return []
        }
        
        let items = itemsInCurrentDB
        
        // 1. Filter by Search Query (Multi-token fuzzy matching)
        let filteredBySearch: [FAQItem]
        let tokens = searchQuery.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        if tokens.isEmpty {
            filteredBySearch = items
        } else {
            filteredBySearch = items.filter { item in
                let combinedText = "\(item.question) \(item.answer) \(item.tags.joined(separator: " ")) \(item.category) \(item.relatedArticleId ?? "")"
                return tokens.allSatisfy { token in
                    combinedText.localizedCaseInsensitiveContains(token)
                }
            }
        }
        
        // 2. If a specific subcategory is selected (and not "全部")
        if selectedSubCategory != "全部" {
            let matchingItems = filteredBySearch.filter { item in
                item.tags.contains(selectedSubCategory)
            }
            if !matchingItems.isEmpty {
                return [FAQGroup(subCategory: selectedSubCategory, items: matchingItems)]
            }
        }
        
        // 3. When search is active in "全部" tab, group matching items neatly by subCategory
        var groupsMap: [String: [FAQItem]] = [:]
        var orderedSubCats: [String] = []
        
        for item in filteredBySearch {
            let subCat = item.tags.first(where: { $0 != item.category && $0 != "RCC" && $0 != "RCC 常见场景" }) ?? "常规问答"
            if groupsMap[subCat] == nil {
                orderedSubCats.append(subCat)
                groupsMap[subCat] = [item]
            } else {
                groupsMap[subCat]?.append(item)
            }
        }
        
        return orderedSubCats.map { subCat in
            FAQGroup(subCategory: subCat, items: groupsMap[subCat] ?? [])
        }
    }
    
    public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Top Knowledge Base Selector & Sync Bar
                    topKnowledgeBaseBar
                    
                    // 2. Full-width Search Input
                    searchInputSection
                    
                    // 3. Sub-category Filter Pills
                    subCategoryFilterPills
                    
                    // 4. Accordion Cards List or Guidance Prompt
                    faqAccordionListSection
                }
                .padding(24)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .onChange(of: expandedItemIDs) { _, newSet in
                if let targetID = newSet.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scrollProxy.scrollTo(targetID, anchor: .center)
                        }
                    }
                }
            }
        }
        .alert("Chorus 同步结果", isPresented: $showSyncAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            if let msg = chorusSync.lastSyncResult {
                Text(msg)
            }
        }
        .onAppear {
            if store.faqItems.isEmpty {
                _ = chorusSync.syncChorusAll(into: store)
            }
            handleTargetFAQNavigation()
        }
        .onChange(of: store.targetFAQItemID) { _, newID in
            if newID != nil {
                handleTargetFAQNavigation()
            }
        }
        .onChange(of: selectedDatabase) { _, _ in
            if !isNavigatingProgrammatically && store.targetFAQItemID == nil {
                selectedSubCategory = "全部"
                expandedItemIDs.removeAll()
            }
        }
        .onChange(of: selectedSubCategory) { _, _ in
            if !isNavigatingProgrammatically && store.targetFAQItemID == nil {
                expandedItemIDs.removeAll()
            }
        }
    }
    
    private func handleTargetFAQNavigation() {
        guard let targetID = store.targetFAQItemID,
              let item = store.faqItems.first(where: { $0.id == targetID }) else { return }
        
        isNavigatingProgrammatically = true
        
        let targetDB: FAQDatabase
        if item.category == "SDA" {
            targetDB = .sda
        } else if item.category == "Apple TV" {
            targetDB = .appleTV
        } else if item.category == "ARS OB 常规咨询" {
            targetDB = .arsob
        } else if item.category == "BTS 返校季" {
            targetDB = .bts
        } else if item.category == "AA FAQ" {
            targetDB = .aa
        } else {
            targetDB = .rcc
        }
        
        let subCat = item.tags.first(where: { $0 != item.category && $0 != "RCC" && $0 != "RCC 常见场景" }) ?? "全部"
        
        selectedDatabase = targetDB
        selectedSubCategory = subCat
        expandedItemIDs = [item.id]
        searchQuery = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isNavigatingProgrammatically = false
            store.targetFAQItemID = nil
        }
    }
    
    // MARK: - 1. Top Knowledge Base Selector & Sync Bar
    
    private var topKnowledgeBaseBar: some View {
        HStack(spacing: 12) {
            // Segmented Knowledge Base Tabs
            HStack(spacing: 4) {
                ForEach(FAQDatabase.allCases) { db in
                    Button(action: {
                        selectedDatabase = db
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: db.iconName)
                                .font(.system(size: 11))
                            Text(db.rawValue)
                                .font(.system(size: 12.5, weight: selectedDatabase == db ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedDatabase == db ? Color(NSColor.controlBackgroundColor) : Color.clear)
                        .foregroundColor(selectedDatabase == db ? .primary : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: selectedDatabase == db ? Color.black.opacity(0.06) : Color.clear, radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(red: 0.84, green: 0.90, blue: 0.88).opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Spacer()
            
            // Sync Status Badge
            if let lastSync = chorusSync.lastSyncTime {
                HStack(spacing: 4) {
                    Text("已同步: \(formatSyncTime(lastSync))")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
            } else {
                Text("已同步: Chorus 知识库 (\(store.faqItems.count)条)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Sync Button
            Button(action: {
                _ = chorusSync.syncChorusAll(into: store)
                showSyncAlert = true
            }) {
                HStack(spacing: 5) {
                    if chorusSync.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("同步最新 Chorus")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(chorusSync.isSyncing)
            .help("从 Chorus 知识库 (RCC:5530436 / ARS:7345748 / BTS:8034582 / AA:7982276 / SDA:7861236 / Apple TV:7550958) 提取并刷新最新问答")
        }
    }
    
    // MARK: - 2. Full-width Search Input
    
    private var searchInputSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            TextField("在 \(selectedDatabase.rawValue) 中搜索问题、场景、关键词或 Core 编号...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
            
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - 3. Sub-category Filter Pills
    
    private var subCategoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subCategoryList, id: \.self) { catName in
                    let isSelected = (selectedSubCategory == catName)
                    
                    Button(action: {
                        selectedSubCategory = catName
                    }) {
                        Text(catName)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color(NSColor.labelColor) : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(isSelected ? Color(NSColor.windowBackgroundColor) : Color.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - 4. Accordion Cards List or Guidance Prompt
    
    private var faqAccordionListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isBrowsingAllWithoutSearch {
                VStack(spacing: 12) {
                    Text("请输入关键词或选择上方分类查看内容")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding(.bottom, 80)
            } else if groupedFAQs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchQuery.isEmpty ? "暂无该分类下的问答指引" : "未找到匹配「\(searchQuery)」的问答内容")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(groupedFAQs) { group in
                    groupSectionView(group: group)
                }
            }
        }
    }
    
    private func groupSectionView(group: FAQGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Group Header Row (only show section header when searching across multiple groups in "全部" tab)
            if selectedSubCategory == "全部" && !searchQuery.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    
                    Text(group.subCategory)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(group.items.count) 条")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
            
            // Cards in this group
            VStack(spacing: 10) {
                ForEach(group.items) { item in
                    faqAccordionCard(for: item)
                        .id(item.id)
                }
            }
        }
    }
    
    private func faqAccordionCard(for item: FAQItem) -> some View {
        let isExpanded = expandedItemIDs.contains(item.id)
        let tag = item.tags.first(where: { $0 != item.category && $0 != "RCC" && $0 != "RCC 常见场景" }) ?? item.category
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header Row (Question + Tag + Chevron)
            Button(action: {
                if expandedItemIDs.contains(item.id) {
                    expandedItemIDs.remove(item.id)
                } else {
                    expandedItemIDs.insert(item.id)
                }
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        // Sub-category badge
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        // Expand/Collapse Chevron
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    
                    // Question text with keyword highlight
                    Text(highlightedAttributedString(for: item.question, query: searchQuery))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Expanded Content (Answer)
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlightedAttributedString(for: item.answer, query: searchQuery, isAnswer: true))
                        .font(.system(size: 13.5))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Bottom Card Tools (Copy & Article link)
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
    
    // MARK: - Keyword Highlighting & Link Formatting
    
    private func highlightedAttributedString(for text: String, query: String, isAnswer: Bool = false) -> AttributedString {
        let tokens = query.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        let baseString = isAnswer ? formatLinks(in: text) : text
        
        var attrString: AttributedString
        if let markdownAttr = try? AttributedString(markdown: baseString, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
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
    
    // MARK: - Link Formatter
    
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
    
    private func formatSyncTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: date)
    }
}

#Preview {
    FAQView()
        .environmentObject(WorkbenchStore())
}
