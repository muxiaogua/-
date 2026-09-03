//
//  PublishView.swift
//  团队工作台
//

import SwiftUI

public struct PublishView: View {
    @EnvironmentObject var store: WorkbenchStore
    
    // Announcement Form States
    @State private var announcementTitle: String = ""
    @State private var announcementContent: String = ""
    @State private var announcementPriority: AnnouncementPriority = .important
    @State private var announcementIsPinned: Bool = false
    @State private var announcementRequiresAck: Bool = true
    @State private var announcementTags: String = "产研协同, 版本通知"
    @State private var announcementExternalLink: String = ""
    @State private var sendAnnouncementNotification: Bool = true
    
    // Feedback
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("发布团队公告")
                        .font(.system(size: 24, weight: .bold))
                    Text("起草并向团队全员分发重点公告，支持阅读确认追踪与全员 iCloud 实时协同")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                if store.canCurrentUserPublishAnnouncements {
                    announcementForm
                } else {
                    noPermissionView
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
    
    // MARK: - No Permission View
    
    private var noPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("暂无公告发布权限")
                .font(.system(size: 18, weight: .bold))
            
            Text("您当前的身份为「普通成员」，仅支持查阅公告、确认已读及发表讨论。\n如需在团队工作台起草并向全员分发公告，请联系管理员（Jason 或 Beauty）为您开通权限。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
            
            HStack(spacing: 12) {
                Label("管理员: Jason / Beauty", systemImage: "crown.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
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
                    Text("发布人")
                        .font(.system(size: 13, weight: .semibold))
                    Text(store.currentUser.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
            }
            
            HStack(spacing: 20) {
                Toggle("要求全员阅读并确认已读", isOn: $announcementRequiresAck)
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
                    .frame(minHeight: 160)
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
    
    // MARK: - Actions
    
    private func submitAnnouncement() {
        let tags = announcementTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let newAnnouncement = Announcement(
            title: announcementTitle.trimmingCharacters(in: .whitespaces),
            content: announcementContent.trimmingCharacters(in: .whitespaces),
            author: store.currentUser.name,
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
}

#Preview {
    PublishView()
        .environmentObject(WorkbenchStore())
}
