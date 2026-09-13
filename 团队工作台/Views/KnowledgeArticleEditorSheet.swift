//
//  KnowledgeArticleEditorSheet.swift
//  团队工作台
//

import SwiftUI

public struct KnowledgeArticleEditorSheet: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss
    
    public var articleToEdit: SharedKnowledgeArticle? = nil
    
    @State private var title: String = ""
    @State private var selectedCategory: KnowledgeCategory = .iOS
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @State private var summary: String = ""
    @State private var solution: String = ""
    @State private var tipInput: String = ""
    @State private var keyTips: [String] = []
    @State private var isPinned: Bool = false
    
    public init(articleToEdit: SharedKnowledgeArticle? = nil) {
        self.articleToEdit = articleToEdit
    }
    
    private var isEditing: Bool {
        articleToEdit != nil
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !solution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            editorHeaderBar
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Scrollable Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 固定品类分类选择 (iOS / Mac / Watch / AirPods / 辅助功能 / 通用经验)
                    categorySection
                    
                    // 2. 标题输入
                    titleSection
                    
                    // 3. 适用场景与核心摘要
                    summarySection
                    
                    // 4. 自定义细分业务标签 (Tags)
                    tagsSection
                    
                    // 5. 解决方案 (单一大输入框，条理分明)
                    solutionSection
                    
                    // 6. 避坑要点与重点贴士 (Key Tips)
                    tipsBlock
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Action Bar
            editorFooterBar
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 680, idealWidth: 740, minHeight: 600, idealHeight: 700)
        .onAppear {
            setupInitialData()
        }
    }
    
    // MARK: - 1. 顶栏
    private var editorHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: isEditing ? "square.and.pencil" : "plus.square.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    Text(isEditing ? "编辑知识点" : "新建知识点")
                        .font(.system(size: 16, weight: .bold))
                }
                Text("沉淀业务实操规程、排查解决方案与客服要点，形成全团队知识点库")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - 2. 固定分类选择
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("所属品类标签")
                    .font(.system(size: 13, weight: .semibold))
                Text("必选")
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 8) {
                ForEach(KnowledgeCategory.selectableCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11.5))
                            Text(cat.rawValue)
                                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundColor(isSelected ? cat.themeColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? cat.themeColor.opacity(0.12) : Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isSelected ? cat.themeColor.opacity(0.6) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 3. 标题输入
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("文章标题")
                    .font(.system(size: 13, weight: .semibold))
                Text("必填")
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
            }
            
            TextField("例如：iOS 26 账户双重认证登录闪退排查与临时操作规程", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
        }
    }
    
    // MARK: - 4. 适用场景与核心摘要
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("核心摘要 / 适用场景")
                .font(.system(size: 13, weight: .semibold))
            
            TextField("用 1~2 句话概括本篇知识适用的场景或核心排查结论（选填）", text: $summary)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }
    
    // MARK: - 5. 自定义细分标签
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("细分业务标签 (Tags)")
                .font(.system(size: 13, weight: .semibold))
            
            HStack {
                TextField("输入细分关键词后按回车添加 (如：双重认证、SOP、临时规程)...", text: $tagInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTag()
                    }
                
                Button("添加标签") {
                    addTag()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.system(size: 11.5))
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - 6. 解决方案正文 (单一大输入框)
    private var solutionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("解决方案")
                    .font(.system(size: 13, weight: .semibold))
                Text("必填")
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
                Spacer()
                Text("在此填写详细操作步骤、排查指引或官方规程（支持多段落与换行）")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $solution)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(minHeight: 180)
                
                if solution.isEmpty {
                    Text("请在此输入该知识条目的具体排查步骤、操作规程或客服官方答复（例如：\n1. 引导顾客进入设置检查...\n2. 确认相关选项已开启...\n3. 提供替代临时规程...）")
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 7. 避坑要点与重点贴士
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("重点避坑贴士 (Key Tips)")
                    .font(.system(size: 13, weight: .semibold))
                Text("高亮展示在文章底部，强化关键提醒（选填）")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("输入关键提醒 (例如：切勿建议顾客直接抹掉设备)...", text: $tipInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTip()
                    }
                
                Button("添加贴士") {
                    addTip()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(tipInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !keyTips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(keyTips.enumerated()), id: \.offset) { idx, tip in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(tip)
                                .font(.system(size: 12))
                            Spacer()
                            Button {
                                keyTips.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
    
    // MARK: - 8. 底栏操作
    private var editorFooterBar: some View {
        HStack {
            if store.canCurrentUserPublishAnnouncements || store.isCurrentUserAdmin {
                Toggle(isOn: $isPinned) {
                    Label("置顶本篇文章", systemImage: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isPinned ? .orange : .secondary)
                }
                .toggleStyle(.checkbox)
            }
            
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            
            Button(action: {
                saveArticle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(isEditing ? "保存修改" : "发布至知识点")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!isFormValid)
        }
    }
    
    // MARK: - 辅助方法
    private func addTag() {
        let clean = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !tags.contains(clean) {
            tags.append(clean)
            tagInput = ""
        }
    }
    
    private func addTip() {
        let clean = tipInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !keyTips.contains(clean) {
            keyTips.append(clean)
            tipInput = ""
        }
    }
    
    private func setupInitialData() {
        if let art = articleToEdit {
            title = art.title
            selectedCategory = art.category
            tags = art.tags
            summary = art.summary
            solution = art.solution
            keyTips = art.keyTips
            isPinned = art.isPinned
        } else {
            selectedCategory = .iOS
            solution = ""
        }
    }
    
    private func saveArticle() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSolution = solution.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if var existing = articleToEdit {
            existing.title = cleanTitle
            existing.category = selectedCategory
            existing.tags = tags
            existing.summary = cleanSummary
            existing.solution = cleanSolution
            existing.keyTips = keyTips
            existing.isPinned = isPinned
            existing.updatedAt = Date()
            store.updateKnowledgeArticle(existing)
        } else {
            let newArticle = SharedKnowledgeArticle(
                title: cleanTitle,
                category: selectedCategory,
                tags: tags,
                summary: cleanSummary,
                solution: cleanSolution,
                keyTips: keyTips,
                author: store.currentUser.name,
                createdAt: Date(),
                updatedAt: Date(),
                isPinned: isPinned,
                helpfulUserNames: [],
                comments: []
            )
            store.addKnowledgeArticle(newArticle)
        }
        
        dismiss()
    }
}
