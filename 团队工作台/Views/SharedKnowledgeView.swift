//
//  SharedKnowledgeView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct SharedKnowledgeView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    // 两大主专区独立分开查阅 (知识点 vs 精益求精)
    @State private var activeSection: KnowledgeArticleKind = .standardSOP
    @State private var selectedCategory: KnowledgeCategory = .all
    @State private var searchText: String = ""
    @State private var onlyBookmarked: Bool = false
    @State private var sortOption: KnowledgeSortOption = .newest
    
    @State private var showCreateSopSheet: Bool = false
    @State private var showCreateJingYiSheet: Bool = false
    @State private var articleToEdit: SharedKnowledgeArticle? = nil
    @State private var articleToDelete: SharedKnowledgeArticle? = nil
    @State private var showDeleteConfirmAlert: Bool = false
    @State private var zoomScreenshotData: ZoomableImageData? = nil
    
    @State private var newCommentText: String = ""
    
    public init() {}
    
    private enum KnowledgeSortOption: String, CaseIterable, Identifiable {
        case newest = "最新发布"
        case mostHelpful = "最多获赞"
        case mostDiscussed = "最多讨论"
        
        var id: String { rawValue }
    }
    
    // 知识点数量与精益求精数量统计
    private var knowledgePointsCount: Int {
        store.knowledgeArticles.filter { $0.kind == .standardSOP }.count
    }
    
    private var jingYiCount: Int {
        store.knowledgeArticles.filter { $0.kind == .jingYiQiuJing }.count
    }
    
    // MARK: - Computed Filtered Articles (严格按所选专区彻底分开查阅)
    
    private var filteredArticles: [SharedKnowledgeArticle] {
        // 1. 严格锁定当前所选专区 (知识点 或 精益求精)
        var list = store.knowledgeArticles.filter { $0.kind == activeSection }
        
        // 2. 品类分类筛选 (全部 / iOS / Mac / Watch / AirPods / 辅助功能 / 通用经验)
        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }
        
        // 3. 仅看收藏筛选
        if onlyBookmarked {
            list = list.filter { store.bookmarkedKnowledgeIDs.contains($0.id) }
        }
        
        // 4. 搜索关键词
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { article in
                if article.title.lowercased().contains(query) { return true }
                if article.summary.lowercased().contains(query) { return true }
                if article.solution.lowercased().contains(query) { return true }
                if article.faultBackground.lowercased().contains(query) { return true }
                if article.troubleshootingLogic.lowercased().contains(query) { return true }
                if article.caseId.lowercased().contains(query) { return true }
                if article.deviceAndOS.lowercased().contains(query) { return true }
                if article.author.lowercased().contains(query) { return true }
                if article.tags.contains(where: { $0.lowercased().contains(query) }) { return true }
                if article.keyTips.contains(where: { $0.lowercased().contains(query) }) { return true }
                if article.referenceArticles.contains(where: { $0.title.lowercased().contains(query) || $0.urlOrCoreId.lowercased().contains(query) }) { return true }
                return false
            }
        }
        
        // 5. 排序规则 (置顶文章始终排在最前面)
        return list.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }
            switch sortOption {
            case .newest:
                return first.createdAt > second.createdAt
            case .mostHelpful:
                if first.helpfulUserNames.count != second.helpfulUserNames.count {
                    return first.helpfulUserNames.count > second.helpfulUserNames.count
                }
                return first.createdAt > second.createdAt
            case .mostDiscussed:
                if first.comments.count != second.comments.count {
                    return first.comments.count > second.comments.count
                }
                return first.createdAt > second.createdAt
            }
        }
    }
    
    private var selectedArticle: SharedKnowledgeArticle? {
        if let id = store.selectedKnowledgeArticleID {
            return filteredArticles.first(where: { $0.id == id }) ?? filteredArticles.first
        }
        return filteredArticles.first
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Bar (带知识点与精益求精两大专区主切换 Tab)
            topHeaderBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 2. Category Filter Pills Bar (固定品类标签与排序)
            categoryFilterBar
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            
            Divider()
            
            // 3. Master-Detail Split Area
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    // Left Column: Articles List (width ~370)
                    leftArticleListView
                        .frame(width: max(340, min(420, proxy.size.width * 0.35)))
                    
                    Divider()
                    
                    // Right Column: Article Detail Reading Pane
                    rightArticleDetailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showCreateSopSheet) {
            KnowledgeArticleEditorSheet(articleToEdit: nil)
        }
        .sheet(isPresented: $showCreateJingYiSheet) {
            JingYiQiuJingEditorSheet(articleToEdit: nil)
        }
        .sheet(item: $articleToEdit) { article in
            if article.kind == .jingYiQiuJing {
                JingYiQiuJingEditorSheet(articleToEdit: article)
            } else {
                KnowledgeArticleEditorSheet(articleToEdit: article)
            }
        }
        .sheet(item: $zoomScreenshotData) { wrapper in
            ScreenshotZoomModal(data: wrapper.data)
        }
        .alert("确认删除该知识文章？", isPresented: $showDeleteConfirmAlert) {
            Button("删除", role: .destructive) {
                if let target = articleToDelete {
                    store.deleteKnowledgeArticle(id: target.id)
                    if store.selectedKnowledgeArticleID == target.id {
                        store.selectedKnowledgeArticleID = filteredArticles.first?.id
                    }
                    articleToDelete = nil
                }
            }
            Button("取消", role: .cancel) {
                articleToDelete = nil
            }
        } message: {
            Text("文章删除后将从本地及团队共享空间中彻底移除，该操作无法撤销。")
        }
        .onAppear {
            if store.selectedKnowledgeArticleID == nil {
                store.selectedKnowledgeArticleID = filteredArticles.first?.id
            }
        }
    }
    
    // MARK: - 1. 顶部栏 (两大专区切换 Tab + 搜索 + 专属新建按钮)
    
    private var topHeaderBar: some View {
        HStack(spacing: 14) {
            // 左侧：两大专区主切换 Tab (知识点 vs 精益求精)
            HStack(spacing: 4) {
                // 1. 知识点 Tab
                let isSopSelected = (activeSection == .standardSOP)
                Button {
                    activeSection = .standardSOP
                    store.selectedKnowledgeArticleID = filteredArticles.first?.id
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 12))
                        Text("知识点")
                            .font(.system(size: 13, weight: isSopSelected ? .bold : .medium))
                        Text("(\(knowledgePointsCount))")
                            .font(.system(size: 11))
                            .foregroundColor(isSopSelected ? .blue : .secondary.opacity(0.8))
                    }
                    .foregroundColor(isSopSelected ? .blue : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSopSelected ? Color.blue.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // 2. 精益求精 Tab
                let isJingYiSelected = (activeSection == .jingYiQiuJing)
                Button {
                    activeSection = .jingYiQiuJing
                    store.selectedKnowledgeArticleID = filteredArticles.first?.id
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("精益求精")
                            .font(.system(size: 13, weight: isJingYiSelected ? .bold : .medium))
                        Text("(\(jingYiCount))")
                            .font(.system(size: 11))
                            .foregroundColor(isJingYiSelected ? .orange : .secondary.opacity(0.8))
                    }
                    .foregroundColor(isJingYiSelected ? .orange : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isJingYiSelected ? Color.orange.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            
            // Subtitle hint
            Text(activeSection == .standardSOP ? "实操指引、排查要点与规程沉淀" : "深度案例复盘，直发群组邮件 (\(JingYiQiuJingMailHelper.targetGroupEmail))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Search Input Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField(activeSection == .standardSOP ? "搜索知识点标题、方案、标签..." : "搜索案例标题、背景、思路、Case号...", text: $searchText)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .frame(width: 250)
            
            // 对应专区专属新建按钮
            if activeSection == .standardSOP {
                Button(action: {
                    showCreateSopSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("新建知识点")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("发布常规业务排查规程、客服步骤与避坑要点")
            } else {
                Button(action: {
                    showCreateJingYiSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("编写精益求精")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.red.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: Color.orange.opacity(0.3), radius: 3, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
                .help("沉淀深度案例（含背景、思路、方案与截图），并可一键分发群组邮件")
            }
        }
    }
    
    // MARK: - 2. 品类标签过滤条
    private var categoryFilterBar: some View {
        HStack(spacing: 8) {
            // “全部” 勾选项：自由决定隐藏/显示全部
            let isAllSelected = (selectedCategory == .all)
            let allCount = filteredCountForCategory(.all)
            
            Toggle(isOn: Binding(
                get: { selectedCategory == .all },
                set: { isChecked in
                    if isChecked {
                        selectedCategory = .all
                    } else {
                        // 取消勾选时隐藏全部，自动聚焦至首个具体分类 (iOS)
                        selectedCategory = .iOS
                    }
                }
            )) {
                HStack(spacing: 3) {
                    Text("全部")
                        .font(.system(size: 12, weight: isAllSelected ? .bold : .medium))
                    Text("(\(allCount))")
                        .font(.system(size: 10.5))
                        .foregroundColor(isAllSelected ? .blue : .secondary)
                }
            }
            .toggleStyle(.checkbox)
            .help("勾选以显示全部文章，取消勾选以隐藏全部并按具体品类查阅")
            .padding(.trailing, 2)
            
            Divider()
                .frame(height: 14)
            
            // 具体品类标签按钮 (iOS / Mac / Watch / AirPods / 辅助功能 / 通用经验)
            ForEach(KnowledgeCategory.selectableCases) { cat in
                let isSelected = (selectedCategory == cat)
                let count = filteredCountForCategory(cat)
                Button {
                    selectedCategory = cat
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 10))
                        Text(cat.rawValue)
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                        Text("\(count)")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? cat.themeColor : .secondary.opacity(0.7))
                    }
                    .foregroundColor(isSelected ? cat.themeColor : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isSelected ? cat.themeColor.opacity(0.12) : Color.secondary.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(isSelected ? cat.themeColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Toggle(isOn: $onlyBookmarked) {
                HStack(spacing: 3) {
                    Image(systemName: onlyBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(onlyBookmarked ? .orange : .secondary)
                    Text("只看收藏")
                        .font(.system(size: 11))
                        .foregroundColor(onlyBookmarked ? .orange : .secondary)
                }
            }
            .toggleStyle(.checkbox)
            
            Divider()
                .frame(height: 14)
            
            Menu {
                ForEach(KnowledgeSortOption.allCases) { opt in
                    Button {
                        sortOption = opt
                    } label: {
                        HStack {
                            Text(opt.rawValue)
                            if sortOption == opt { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9.5))
                    Text(sortOption.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func filteredCountForCategory(_ cat: KnowledgeCategory) -> Int {
        let base = store.knowledgeArticles.filter { $0.kind == activeSection }
        if cat == .all {
            return base.count
        }
        return base.filter { $0.category == cat }.count
    }
    
    // MARK: - 3. 左侧文章列表
    
    private var leftArticleListView: some View {
        Group {
            if store.knowledgeArticles.filter({ $0.kind == activeSection }).isEmpty {
                // 对应专区纯空引导状态
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: activeSection == .standardSOP ? "book.fill" : "flame.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(activeSection == .standardSOP ? .blue.opacity(0.35) : .orange.opacity(0.45))
                    
                    Text(activeSection == .standardSOP ? "暂无沉淀的知识点文章" : "暂无沉淀的精益求精案例")
                        .font(.system(size: 15, weight: .bold))
                    
                    Text(activeSection == .standardSOP ? "知识点用于沉淀客服实操指引、排查要点与规程步骤。\n点击右上角「新建知识点」发布第一篇实操经验吧！" : "精益求精用于沉淀带有故障背景、思路、方案与截图的深度案例。\n点击右上角「编写精益求精」开启第一篇案例复盘吧！")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                    
                    Button(action: {
                        if activeSection == .standardSOP {
                            showCreateSopSheet = true
                        } else {
                            showCreateJingYiSheet = true
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: activeSection == .standardSOP ? "plus.circle.fill" : "flame.fill")
                            Text(activeSection == .standardSOP ? "发布第一篇知识点" : "编写第一篇精益求精")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(activeSection == .standardSOP ? Color.blue : Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredArticles.isEmpty {
                // 搜索/过滤无结果
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("未找到匹配的知识文章")
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("请尝试更换搜索词或切换品类标签")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredArticles) { article in
                            articleCardRow(for: article)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
    
    // MARK: - 单个文章卡片行
    
    private func articleCardRow(for article: SharedKnowledgeArticle) -> some View {
        let isSelected = (selectedArticle?.id == article.id)
        let isBookmarked = store.bookmarkedKnowledgeIDs.contains(article.id)
        let isJingYi = (article.kind == .jingYiQiuJing)
        
        return Button {
            store.selectedKnowledgeArticleID = article.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Top Meta: Category Badge + Pinned + Date
                HStack(spacing: 5) {
                    if isJingYi {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8.5))
                            Text("精益求精")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    // 品类标签
                    HStack(spacing: 3.5) {
                        Image(systemName: article.category.icon)
                            .font(.system(size: 9))
                        Text(article.category.rawValue)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(article.category.themeColor)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(article.category.themeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if article.isPinned {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("置顶")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(formatRelativeDate(article.createdAt))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                
                // Title
                Text(article.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Preview Text (知识点按要求仅显示标题不显示内容，内容通过右侧查阅；精益求精案例保留预览)
                if isJingYi {
                    let previewText = article.summary.isEmpty ? (article.faultBackground.isEmpty ? article.solution : article.faultBackground) : article.summary
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // 精益求精专属微型指示器 (Case号、机型、截图、已发群信)
                if isJingYi {
                    HStack(spacing: 6) {
                        if !article.caseId.isEmpty {
                            Text(article.caseId)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        
                        if !article.screenshotsBase64.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 8))
                                Text("\(article.screenshotsBase64.count)图")
                                    .font(.system(size: 9.5))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if article.hasSentGroupMail {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 8))
                                Text("已发群信")
                                    .font(.system(size: 9.5))
                            }
                            .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 1)
                }
                
                // Bottom Meta: Author + Likes + Comments + Bookmark
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                        Text(article.author)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if !article.helpfulUserNames.isEmpty {
                            HStack(spacing: 2.5) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.system(size: 9))
                                Text("\(article.helpfulUserNames.count)")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(.blue)
                        }
                        
                        if !article.comments.isEmpty {
                            HStack(spacing: 2.5) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 9))
                                Text("\(article.comments.count)")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Button {
                            store.toggleKnowledgeBookmark(id: article.id)
                        } label: {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 11))
                                .foregroundColor(isBookmarked ? .orange : .secondary.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            .padding(11)
            .background(isSelected ? Color.blue.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 4. 右侧文章详情阅读区
    
    private var rightArticleDetailView: some View {
        Group {
            if let article = selectedArticle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 顶部操作条 (品类、标签、群组邮件按钮、编辑与删除)
                        detailHeaderSection(for: article)
                        
                        // 2. 标题
                        Text(article.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // 3. 基础信息条
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.blue)
                                Text("贡献者：\(article.author)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            
                            Text("·")
                                .foregroundColor(.secondary)
                            
                            Text("发布于 \(formatExactDate(article.createdAt))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            if !article.deviceAndOS.isEmpty {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("机型：\(article.deviceAndOS)")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            if !article.caseId.isEmpty {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("案例号：\(article.caseId)")
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // 4. 精益求精深度架构展现 vs 知识点SOP展现
                        if article.kind == .jingYiQiuJing {
                            jingYiQiuJingCards(for: article)
                        } else {
                            standardSOPCards(for: article)
                        }
                        
                        // 5. 避坑要点卡片 (若有)
                        if !article.keyTips.isEmpty {
                            tipsCard(for: article)
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // 6. 觉得有帮助 (👍) 互动按钮
                        helpfulActionButton(for: article)
                        
                        // 7. 团队讨论与补充经验
                        commentsSection(for: article)
                    }
                    .padding(26)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text(activeSection == .standardSOP ? "请从左侧选择一篇知识点开始查阅" : "请从左侧选择一篇精益求精案例开始查阅")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - 精益求精专属深度卡片组 (故障背景 + 排查思路 + 解决方案 + 截图佐证)
    
    private func jingYiQiuJingCards(for article: SharedKnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 一、故障背景卡片
            if !article.faultBackground.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed.fill")
                            .foregroundColor(.orange)
                        Text("一、故障背景 (Background)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text(article.faultBackground)
                        .font(.system(size: 13))
                        .lineSpacing(5)
                        .foregroundColor(.primary.opacity(0.92))
                        .textSelection(.enabled)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.orange.opacity(0.2), lineWidth: 1))
            }
            
            // 二、排查思路与推导
            if !article.troubleshootingLogic.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.max.fill")
                            .foregroundColor(.purple)
                        Text("二、排查思路")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    
                    Text(article.troubleshootingLogic)
                        .font(.system(size: 13))
                        .lineSpacing(5)
                        .foregroundColor(.primary.opacity(0.92))
                        .textSelection(.enabled)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.purple.opacity(0.18), lineWidth: 1))
            }
            
            // 三、解决方案卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                    Text("三、解决方案")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                Text(article.solution)
                    .font(.system(size: 13.5))
                    .lineSpacing(6)
                    .foregroundColor(.primary.opacity(0.94))
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.blue.opacity(0.25), lineWidth: 1))
            
            // 四、相关截图 (点击放大查阅)
            if !article.screenshotsBase64.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack.fill")
                            .foregroundColor(.teal)
                        Text("四、相关截图 (\(article.screenshotsBase64.count) 张)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.teal)
                        Spacer()
                        Text("点击任意图片可查看高清大图")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(article.screenshotsBase64.enumerated()), id: \.offset) { idx, b64 in
                                if let data = Data(base64Encoded: b64), let nsImg = NSImage(data: data) {
                                    Button {
                                        zoomScreenshotData = ZoomableImageData(data: data)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(nsImage: nsImg)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 160, height: 105)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                                            
                                            Text("截图 \(idx + 1)")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
            }
            
            // 五、参考文章 (Reference Articles)
            if !article.referenceArticles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.indigo)
                        Text("五、参考文章 (\(article.referenceArticles.count) 篇)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.indigo)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(article.referenceArticles) { ref in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if ref.isCoreProtocol {
                                    // 形式 1: 蓝色数字 ID (点击直接唤起 Core) + 黑色/标准标题
                                    let coreId = ref.coreArticleId ?? ref.urlOrCoreId
                                    Button {
                                        if let url = URL(string: ref.urlOrCoreId) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } label: {
                                        Text(coreId)
                                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { inside in
                                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                    .help("点击唤起 Core 知识库 (\(ref.urlOrCoreId))")
                                    
                                    if !ref.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(ref.title)
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.primary)
                                            .textSelection(.enabled)
                                    }
                                } else {
                                    // 形式 2: 蓝色下划线标题 (点击直接访问网页链接)
                                    Button {
                                        if let url = URL(string: ref.urlOrCoreId) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } label: {
                                        Text(ref.displayTitle)
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { inside in
                                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                    .help("点击访问网页: \(ref.urlOrCoreId)")
                                }
                                
                                Spacer()
                                
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(ref.urlOrCoreId, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("复制链接/Core协议标识")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.indigo.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    // MARK: - 常规知识点卡片组
    
    private func standardSOPCards(for article: SharedKnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 适用场景摘要
            if !article.summary.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("适用场景 / 核心摘要")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.orange)
                        Text(article.summary)
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
            }
            
            // 解决方案
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 15))
                    Text("解决方案")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Text(article.solution)
                    .font(.system(size: 13.5))
                    .foregroundColor(.primary.opacity(0.92))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 避坑贴士卡片
    
    private func tipsCard(for article: SharedKnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 13.5))
                Text("关键避坑贴士与客服注意要点")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(article.keyTips.enumerated()), id: \.offset) { tIdx, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                        Text(tip)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }
    
    // MARK: - 详情顶部操作条
    
    private func detailHeaderSection(for article: SharedKnowledgeArticle) -> some View {
        let isBookmarked = store.bookmarkedKnowledgeIDs.contains(article.id)
        let canEdit = (article.author == store.currentUser.name) || store.isCurrentUserAdmin
        let isPinned = article.isPinned
        let isJingYi = (article.kind == .jingYiQiuJing)
        
        return HStack(spacing: 8) {
            // 专区徽章
            HStack(spacing: 4) {
                Image(systemName: article.kind.icon)
                    .font(.system(size: 10))
                Text(article.kind.rawValue)
                    .font(.system(size: 11.5, weight: .bold))
            }
            .foregroundColor(article.kind.themeColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(article.kind.themeColor.opacity(0.14))
            .clipShape(Capsule())
            
            // 品类徽章
            HStack(spacing: 4) {
                Image(systemName: article.category.icon)
                    .font(.system(size: 10.5))
                Text(article.category.rawValue)
                    .font(.system(size: 11.5, weight: .bold))
            }
            .foregroundColor(article.category.themeColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(article.category.themeColor.opacity(0.12))
            .clipShape(Capsule())
            
            // Tags
            ForEach(article.tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // 精益求精专属：一键生成/发送群组邮件按钮
            if isJingYi {
                Button {
                    JingYiQiuJingMailHelper.composeGroupMail(for: article)
                    if !article.hasSentGroupMail {
                        var updated = article
                        updated.hasSentGroupMail = true
                        store.updateKnowledgeArticle(updated)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                        Text(article.hasSentGroupMail ? "重新发送群信" : "发送群组邮件")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("自动格式化排版并唤起 Mail.app 发送至群组邮箱 \(JingYiQiuJingMailHelper.targetGroupEmail)")
            }
            
            // 置顶开关 (管理员可用)
            if store.canCurrentUserPublishAnnouncements || store.isCurrentUserAdmin {
                Button {
                    store.toggleKnowledgePin(id: article.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                            .font(.system(size: 11))
                        Text(isPinned ? "取消置顶" : "置顶")
                            .font(.system(size: 11.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(isPinned ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.08))
                    .foregroundColor(isPinned ? .orange : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            // 收藏按钮
            Button {
                store.toggleKnowledgeBookmark(id: article.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11))
                    Text(isBookmarked ? "已收藏" : "收藏")
                        .font(.system(size: 11.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(isBookmarked ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.08))
                .foregroundColor(isBookmarked ? .orange : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            
            // 编辑与删除 (作者或管理员)
            if canEdit {
                Button {
                    articleToEdit = article
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("编辑")
                            .font(.system(size: 11.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button {
                    articleToDelete = article
                    showDeleteConfirmAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(5.5)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("删除该知识文章")
            }
        }
    }
    
    // MARK: - 点赞 / 有用 互动卡片
    
    private func helpfulActionButton(for article: SharedKnowledgeArticle) -> some View {
        let isHelpful = article.helpfulUserNames.contains(store.currentUser.name)
        let count = article.helpfulUserNames.count
        
        return HStack {
            Button(action: {
                store.toggleKnowledgeHelpful(id: article.id)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 13))
                    Text(isHelpful ? "已觉得有帮助 (\(count))" : "觉得有帮助 (\(count))")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isHelpful ? Color.blue : Color.blue.opacity(0.1))
                .foregroundColor(isHelpful ? .white : .blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            if !article.helpfulUserNames.isEmpty {
                Text(article.helpfulUserNames.joined(separator: "、 ") + " 觉得有帮助")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 团队讨论与补充经验
    
    private func commentsSection(for article: SharedKnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("团队经验补充与讨论 (\(article.comments.count))")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            
            // Comment Input Box
            HStack(spacing: 10) {
                TextField("在此写下您的实操补充或不同案例经验...", text: $newCommentText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        submitComment(for: article)
                    }
                
                Button("提交讨论") {
                    submitComment(for: article)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Existing Comments List
            if !article.comments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(article.comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue.opacity(0.8))
                                .padding(.top, 1)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(comment.author)
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text(formatRelativeDate(comment.createdAt))
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(comment.content)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.primary.opacity(0.9))
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助操作
    
    private func submitComment(for article: SharedKnowledgeArticle) {
        let clean = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.addKnowledgeComment(articleID: article.id, content: clean)
        newCommentText = ""
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return "今天 \(df.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return "昨天 \(df.string(from: date))"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM-dd"
            return df.string(from: date)
        }
    }
    
    private func formatExactDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 图片大图预览数据封装与弹窗

public struct ZoomableImageData: Identifiable {
    public var id = UUID()
    public let data: Data
}

public struct ScreenshotZoomModal: View {
    public let data: Data
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.blue)
                    Text("排查佐证原图查看")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if let nsImg = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                }
            } else {
                Text("无法解码图片内容")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, idealWidth: 880, minHeight: 540, idealHeight: 680)
    }
}
