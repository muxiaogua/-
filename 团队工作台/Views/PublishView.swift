//
//  PublishView.swift
//  团队工作台
//

import SwiftUI

public struct PublishView: View {
    @EnvironmentObject var store: WorkbenchStore
    
    enum PublishType: String, CaseIterable, Identifiable {
        case announcement = "团队公告"
        case news = "Green Email"
        
        var id: String { rawValue }
    }
    
    @State private var selectedType: PublishType = .news
    
    // Announcement Form States
    @State private var announcementTitle: String = ""
    @State private var announcementContent: String = ""
    @State private var announcementPriority: AnnouncementPriority = .important
    @State private var announcementIsPinned: Bool = false
    @State private var announcementRequiresAck: Bool = true
    @State private var announcementTags: String = "产研协同, 版本通知"
    @State private var announcementExternalLink: String = ""
    @State private var sendAnnouncementNotification: Bool = true
    
    // News Form States
    @State private var newsTitle: String = ""
    @State private var newsSummary: String = ""
    @State private var newsContent: String = ""
    @State private var newsCategory: NewsCategory = .greenEmail
    @State private var newsSource: String = "Green Email 团队专栏"
    @State private var newsTags: String = "重点资讯, 团队对齐"
    @State private var newsEstimatedMinutes: Int = 3
    @State private var newsExternalLink: String = ""
    @State private var sendNewsNotification: Bool = true
    
    // Feedback
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发布中心")
                            .font(.system(size: 24, weight: .bold))
                        Text("起草并向团队全员分发重点公告或 Green Email 资讯")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("发布类型", selection: $selectedType) {
                        ForEach(PublishType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                
                Divider()
                
                if selectedType == .announcement {
                    announcementForm
                } else {
                    newsForm
                }
            }
            .padding(28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("发布成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Announcement Form
    
    private var announcementForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                Text("公告标题")
                    .font(.system(size: 13, weight: .semibold))
                TextField("请输入公告标题（简明扼要）", text: $announcementTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("重要程度")
                        .font(.system(size: 13, weight: .semibold))
                    Picker("重要程度", selection: $announcementPriority) {
                        ForEach(AnnouncementPriority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.iconName)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("发布人 / 部门")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(store.currentUser.name) (\(store.currentUser.department))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 20) {
                Toggle("要求全员签收确认", isOn: $announcementRequiresAck)
                    .toggleStyle(.checkbox)
                Toggle("在列表与首页置顶", isOn: $announcementIsPinned)
                    .toggleStyle(.checkbox)
                Toggle("发送系统本地横幅通知", isOn: $sendAnnouncementNotification)
                    .toggleStyle(.checkbox)
            }
            .font(.system(size: 12))
            
            Group {
                Text("公告正文内容")
                    .font(.system(size: 13, weight: .semibold))
                TextEditor(text: $announcementContent)
                    .font(.system(size: 13))
                    .frame(minHeight: 140)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            Group {
                Text("分类标签 (英文逗号分隔)")
                    .font(.system(size: 13, weight: .semibold))
                TextField("如：封版通知, 重点里程碑", text: $announcementTags)
                    .textFieldStyle(.roundedBorder)
            }
            
            Group {
                Text("相关参考链接 / 附件 URL (可选)")
                    .font(.system(size: 13, weight: .semibold))
                TextField("https://...", text: $announcementExternalLink)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                Button(action: submitAnnouncement) {
                    Label("立即发布公告", systemImage: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(announcementTitle.trimmingCharacters(in: .whitespaces).isEmpty || announcementContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - News Form
    
    private var newsForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                Text("Green Email 标题")
                    .font(.system(size: 13, weight: .semibold))
                TextField("请输入 Green Email 标题", text: $newsTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("资讯分类")
                        .font(.system(size: 13, weight: .semibold))
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.green)
                        Text("Green Email")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.top, 4)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("信息来源 / 专栏")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("来源出处", text: $newsSource)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("预估阅读时长 (分钟)")
                        .font(.system(size: 13, weight: .semibold))
                    Stepper("\(newsEstimatedMinutes) 分钟", value: $newsEstimatedMinutes, in: 1...30)
                }
            }
            
            Toggle("发布后发送系统本地横幅通知", isOn: $sendNewsNotification)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
            
            Group {
                Text("文章核心摘要 (用于列表速览与消息推送)")
                    .font(.system(size: 13, weight: .semibold))
                TextField("简明一两句话概括要点...", text: $newsSummary)
                    .textFieldStyle(.roundedBorder)
            }
            
            Group {
                Text("Green Email 正文 (支持 Markdown 排版)")
                    .font(.system(size: 13, weight: .semibold))
                TextEditor(text: $newsContent)
                    .font(.system(size: 13))
                    .frame(minHeight: 180)
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            Group {
                Text("标签关键词 (逗号分隔)")
                    .font(.system(size: 13, weight: .semibold))
                TextField("如：重点对齐, 业务通报", text: $newsTags)
                    .textFieldStyle(.roundedBorder)
            }
            
            Group {
                Text("原文外链 (可选)")
                    .font(.system(size: 13, weight: .semibold))
                TextField("https://...", text: $newsExternalLink)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                Button(action: submitNews) {
                    Label("立即发布 Green Email", systemImage: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(newsTitle.trimmingCharacters(in: .whitespaces).isEmpty || newsContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Actions
    
    private func submitAnnouncement() {
        let tags = announcementTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let newAnnouncement = Announcement(
            title: announcementTitle.trimmingCharacters(in: .whitespaces),
            content: announcementContent.trimmingCharacters(in: .whitespaces),
            author: store.currentUser.name,
            department: store.currentUser.department,
            publishDate: Date(),
            priority: announcementPriority,
            isPinned: announcementIsPinned,
            requiresAcknowledgment: announcementRequiresAck,
            isAcknowledged: false,
            tags: tags,
            externalLink: announcementExternalLink.isEmpty ? nil : announcementExternalLink
        )
        
        store.addAnnouncement(newAnnouncement, notify: sendAnnouncementNotification)
        alertMessage = "公告「\(newAnnouncement.title)」已成功发布并同步至团队全员列表！"
        showSuccessAlert = true
        
        // Reset
        announcementTitle = ""
        announcementContent = ""
        announcementExternalLink = ""
    }
    
    private func submitNews() {
        let tags = newsTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let summary = newsSummary.isEmpty ? String(newsContent.prefix(80)) + "..." : newsSummary
        let newArticle = NewsArticle(
            title: newsTitle.trimmingCharacters(in: .whitespaces),
            summary: summary,
            content: newsContent.trimmingCharacters(in: .whitespaces),
            author: store.currentUser.name,
            source: newsSource,
            publishDate: Date(),
            category: .greenEmail,
            tags: tags,
            isBookmarked: false,
            readCount: 0,
            estimatedReadMinutes: newsEstimatedMinutes,
            originalURL: newsExternalLink.isEmpty ? nil : newsExternalLink,
            comments: []
        )
        
        store.addNewsArticle(newArticle, notify: sendNewsNotification)
        alertMessage = "Green Email「\(newArticle.title)」已成功发布！"
        showSuccessAlert = true
        
        // Reset
        newsTitle = ""
        newsSummary = ""
        newsContent = ""
        newsExternalLink = ""
    }
}
