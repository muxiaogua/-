//
//  RCCNPIFAQView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct RCCNPIFAQGroup: Identifiable {
    public let subCategory: String
    public let items: [FAQItem]
    public var id: String { subCategory }
}

public struct RCCNPIFAQView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var chorusSync = ChorusFAQSyncService.shared
    
    @State private var selectedSubCategory: String = "全部"
    @State private var searchQuery: String = ""
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var showSyncAlert = false
    @State private var copiedItemID: UUID? = nil
    
    private let availableSubCategories = [
        "全部",
        "新品发布",
        "售前咨询",
        "订单管理",
        "Apple Trade In",
        "其它",
        "联系与规范"
    ]
    
    public init() {}
    
    // Total items in RCC FAQ_NPI
    private var allRCCNPIItems: [FAQItem] {
        store.faqItems.filter { $0.category == "RCC FAQ_NPI" }
    }
    
    // Grouped items according to subcategory and search
    private var groupedFAQs: [RCCNPIFAQGroup] {
        let items = allRCCNPIItems
        
        // 1. Search Query Filter
        let tokens = searchQuery.split(whereSeparator: { $0.isWhitespace || $0 == "+" || $0 == "," }).map(String.init).filter { !$0.isEmpty }
        let filteredBySearch: [FAQItem]
        if tokens.isEmpty {
            filteredBySearch = items
        } else {
            filteredBySearch = items.filter { item in
                let combinedText = "\(item.question) \(item.answer) \(item.tags.joined(separator: " ")) \(item.relatedArticleId ?? "")"
                return tokens.allSatisfy { token in
                    combinedText.localizedCaseInsensitiveContains(token)
                }
            }
        }
        
        // 2. Specific Sub-category Filter
        if selectedSubCategory != "全部" {
            let matching = filteredBySearch.filter { item in
                item.tags.contains(selectedSubCategory) || item.question.contains(selectedSubCategory)
            }
            return [RCCNPIFAQGroup(subCategory: selectedSubCategory, items: matching)]
        }
        
        // 3. Group by subCategory under "全部"
        var groupsMap: [String: [FAQItem]] = [:]
        var orderedSubCats: [String] = []
        
        for item in filteredBySearch {
            let subCat = item.tags.first(where: { $0 != "RCC FAQ_NPI" }) ?? "常规指引"
            if groupsMap[subCat] == nil {
                orderedSubCats.append(subCat)
                groupsMap[subCat] = [item]
            } else {
                groupsMap[subCat]?.append(item)
            }
        }
        
        return orderedSubCats.map { subCat in
            RCCNPIFAQGroup(subCategory: subCat, items: groupsMap[subCat] ?? [])
        }
    }
    
    public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Top Header Banner & Sync Action
                    topHeaderBanner
                    
                    // 2. Search Box
                    searchBarSection
                    
                    // 3. Sub-category Pills & Bulk Controls
                    subCategoryPillsAndControls
                    
                    // 4. FAQ Cards List
                    faqCardsListSection
                }
                .padding(24)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .alert("Chorus 同步结果", isPresented: $showSyncAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            if let msg = chorusSync.lastSyncResult {
                Text(msg)
            }
        }
        .onAppear {
            if allRCCNPIItems.isEmpty {
                _ = chorusSync.syncChorusCategory("RCC FAQ_NPI", into: store)
            }
        }
    }
    
    // MARK: - 1. Top Header Banner
    
    private var topHeaderBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("RCC FAQ_NPI 专区")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        if let url = URL(string: "https://chorus.apple.com/page/8077018") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "arrow.up.forward.square.fill")
                                .font(.system(size: 9.5))
                            Text("Chorus 8077018")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("在浏览器中打开 Chorus 原文章 (https://chorus.apple.com/page/8077018)")
                }
                
                Text("Apple 2026 NPI 期间针对 RCC 订单管理、售前售后、年年焕新与 Trade In 的最新处理标准")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Total items badge
            Text("共 \(allRCCNPIItems.count) 条指引")
                .font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .clipShape(Capsule())
            
            // Sync Button
            Button(action: {
                _ = chorusSync.syncChorusCategory("RCC FAQ_NPI", into: store)
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
                    Text("刷新知识库")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(chorusSync.isSyncing)
            .help("从 Chorus 页面 8077018 校验并更新最新问答内容")
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Search Bar
    
    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            TextField("在 RCC FAQ_NPI 中搜索问题、场景、关键词（如：Trade In、年年焕新、取消订单、发票）...", text: $searchQuery)
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
    
    // MARK: - 3. Sub-category Pills & Bulk Controls
    
    private var subCategoryPillsAndControls: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableSubCategories, id: \.self) { cat in
                        let isSelected = (selectedSubCategory == cat)
                        Button(action: {
                            selectedSubCategory = cat
                        }) {
                            Text(cat)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
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
                }
                .padding(.vertical, 2)
            }
            
            Spacer()
            
            // Expand/Collapse All
            HStack(spacing: 6) {
                Button(action: {
                    let allIDs = groupedFAQs.flatMap { $0.items.map { $0.id } }
                    expandedItemIDs = Set(allIDs)
                }) {
                    Text("全部展开")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("·")
                    .foregroundColor(.secondary)
                
                Button(action: {
                    expandedItemIDs.removeAll()
                }) {
                    Text("全部收起")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 4. FAQ Cards List
    
    private var faqCardsListSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if groupedFAQs.allSatisfy({ $0.items.isEmpty }) {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchQuery.isEmpty ? "暂无该分类下的问答" : "未找到包含「\(searchQuery)」的相关指引")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(groupedFAQs) { group in
                    if !group.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            if selectedSubCategory == "全部" {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Text(group.subCategory)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("\(group.items.count)")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            
                            VStack(spacing: 10) {
                                ForEach(group.items) { item in
                                    faqCard(for: item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func faqCard(for item: FAQItem) -> some View {
        let isExpanded = expandedItemIDs.contains(item.id)
        let tag = item.tags.first(where: { $0 != "RCC FAQ_NPI" }) ?? "指引"
        
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if expandedItemIDs.contains(item.id) {
                    expandedItemIDs.remove(item.id)
                } else {
                    expandedItemIDs.insert(item.id)
                }
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(tag)
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    
                    Text(highlightedAttributedString(for: item.question, query: searchQuery))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(highlightedAttributedString(for: item.answer, query: searchQuery, isAnswer: true))
                        .font(.system(size: 13))
                        .lineSpacing(5)
                        .foregroundColor(.primary.opacity(0.9))
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
                .padding(14)
                .background(Color.secondary.opacity(0.02))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isExpanded ? Color.orange.opacity(0.35) : Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
    
    // MARK: - Highlight & Links
    
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
}

#Preview {
    RCCNPIFAQView()
        .environmentObject(WorkbenchStore())
}
