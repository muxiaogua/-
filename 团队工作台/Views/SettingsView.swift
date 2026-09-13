//
//  SettingsView.swift
//  团队工作台
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var notificationService = NotificationService.shared
    @ObservedObject var sharedFolderSync = SharedFolderSyncService.shared
    @ObservedObject var updateService = AppUpdateService.shared
    
    @State private var showConfirmClearNews = false
    @State private var showClearNewsSuccess = false
    @State private var showConfirmClearLocal = false
    @State private var showClearLocalSuccess = false
    @State private var showTestNotificationSent = false
    @State private var showEditProfileSheet = false
    @State private var showAddPermissionSheet = false
    @State private var showProductFeedbackSheet = false
    
    // Edit Profile States
    @State private var editName = ""
    @State private var editAvatar = "person.crop.circle.fill.badge.checkmark"
    
    // Add Member Permission States
    @State private var newMemberName = ""
    @State private var newMemberIsAdmin = false
    @State private var newMemberCanPublish = false
    @State private var newMemberCanSync = false
    
    // Permissions Search & Filter
    @State private var memberSearchText = ""
    
    private let availableAvatars = [
        "person.crop.circle.fill.badge.checkmark",
        "person.crop.circle.fill",
        "person.crop.circle.badge.plus",
        "star.circle.fill",
        "crown.fill",
        "bolt.shield.fill",
        "sparkles",
        "laptopcomputer",
        "wand.and.stars",
        "shield.lefthalf.filled"
    ]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("偏好设置与数据管理")
                        .font(.system(size: 24, weight: .bold))
                    Text("设置个人显示名称与头像、配置 iCloud 团队云端同步与系统通知")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 1. My Profile Section
                userProfileSection
                
                // 2. Team Permissions Management (RBAC)
                teamPermissionsSection
                
                // 3. iCloud Shared Folder Sync Section
                sharedFolderSection
                
                // 4. Notifications Settings Card
                notificationSection
                
                // 5. Data Management Section
                dataManagementSection
                
                // 6. About App Section
                aboutSection
            }
            .padding(28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("确认清空重要邮件数据？", isPresented: $showConfirmClearNews) {
            Button("确认清空", role: .destructive) {
                store.clearAllNewsArticles()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showClearNewsSuccess = true
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将彻底清除本地与云端已保存的全部重要邮件（Green Email）内容并重置为空白状态。\n\n该操作无法撤销，确定要清空吗？")
        }
        .alert("邮件数据已清空", isPresented: $showClearNewsSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("所有重要邮件缓存与云端同步记录已成功清空。")
        }
        .alert("确认清空本地数据？", isPresented: $showConfirmClearLocal) {
            Button("确认清空", role: .destructive) {
                store.clearAllLocalData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showClearLocalSuccess = true
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将清除当前电脑上本地缓存的全部公告、邮件与已读记录，不影响他人与云端共享文件。\n\n确定要清空吗？")
        }
        .alert("本地数据已清空", isPresented: $showClearLocalSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("当前电脑的本地缓存内容已清理完毕，重新打开或同步即可按需拉取。")
        }
        .alert("测试通知已发送", isPresented: $showTestNotificationSent) {
            Button("好", role: .cancel) {}
        } message: {
            Text("已通过 macOS 系统通知中心发送一条测试横幅，请留意屏幕右上角。")
        }
        .sheet(isPresented: $showEditProfileSheet) {
            editProfileSheetView
        }
        .sheet(isPresented: $showAddPermissionSheet) {
            addPermissionSheetView
        }
        .sheet(isPresented: $showProductFeedbackSheet) {
            ProductFeedbackSheetView(
                currentUserName: store.currentUser.name,
                appVersion: "\(updateService.currentVersion) (Build \(updateService.currentBuild))"
            )
        }
    }
    
    // MARK: - Sections
    
    private var userProfileSection: some View {
        let isDefaultAdmin = store.isDefaultAdmin(name: store.currentUser.name)
        let isAdmin = store.isCurrentUserAdmin
        let perm = store.permission(for: store.currentUser.name)
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("我的团队身份")
                .font(.system(size: 15, weight: .bold))
            
            HStack(spacing: 16) {
                Image(systemName: store.currentUser.avatarSymbol)
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(store.currentUser.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if isDefaultAdmin {
                            Label("超级管理员", systemImage: "crown.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        } else if isAdmin {
                            Label("管理员", systemImage: "shield.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color.purple)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            Label("普通成员", systemImage: "person.fill")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        Label("在线", systemImage: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    
                    if isDefaultAdmin {
                        Text("系统默认超级管理员（享有全部公告发布、数据同步与全员权限管控能力）")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    } else if isAdmin {
                        Text("团队管理员（享有全部公告发布、数据同步与成员权限分配能力）")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            Text("权限：")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            
                            Text(perm.canPublishAnnouncements ? "✓ 发布公告" : "✕ 发布公告")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(perm.canPublishAnnouncements ? .green : .secondary)
                            
                            Text("·")
                                .foregroundColor(.secondary)
                            
                            Text(perm.canSyncData ? "✓ 数据同步" : "✕ 数据同步")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(perm.canSyncData ? .green : .secondary)
                            
                            Text("·")
                                .foregroundColor(.secondary)
                            
                            Text("✓ 查看阅读 & 讨论留言")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Button(action: {
                        editName = store.currentUser.name
                        editAvatar = store.currentUser.avatarSymbol
                        showEditProfileSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("修改名称与头像")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    // 开发测试快捷身份切换
                    if isDefaultAdmin {
                        Button(action: {
                            store.updateCurrentUser(name: "TestUser", avatarSymbol: "person.circle")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.shield.checkmark")
                                Text("🧪 切换为测试普通成员 (TestUser)")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.purple)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("一键切换为无管理员权限的普通成员，用于体验普通成员界面和权限校验")
                    } else if store.currentUser.name == "TestUser" {
                        Button(action: {
                            store.updateCurrentUser(name: "Beauty", avatarSymbol: "person.crop.circle.fill.badge.checkmark")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                Text("👑 恢复为超级管理员 (Beauty)")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .help("一键恢复为超级管理员身份")
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Edit Profile Sheet
    
    private var editProfileSheetView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    Text("修改我的显示名称与头像")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Button(action: { showEditProfileSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Name Input Section
            VStack(alignment: .leading, spacing: 6) {
                Text("我的姓名 / 称呼")
                    .font(.system(size: 13, weight: .semibold))
                TextField("请输入您的姓名（如：Beauty / 亮亮）", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            
            // Avatar Selection (Grid Layout)
            VStack(alignment: .leading, spacing: 10) {
                Text("选择头像图标")
                    .font(.system(size: 13, weight: .semibold))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(availableAvatars, id: \.self) { sym in
                        Button(action: {
                            editAvatar = sym
                        }) {
                            ZStack {
                                Circle()
                                    .fill(editAvatar == sym ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: sym)
                                    .font(.system(size: 20))
                                    .foregroundColor(editAvatar == sym ? .accentColor : .primary)
                                
                                if editAvatar == sym {
                                    Circle()
                                        .stroke(Color.accentColor, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack {
                Spacer()
                Button("取消") {
                    showEditProfileSheet = false
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)
                
                Button("保存修改") {
                    let name = editName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        store.currentUser.name = name
                        store.currentUser.avatarSymbol = editAvatar
                        store.saveData()
                    }
                    showEditProfileSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 460, height: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Team Permissions Section (RBAC)
    
    private var allMembersToManage: [(name: String, avatar: String)] {
        var seen = Set<String>()
        var list: [(name: String, avatar: String)] = []
        
        // 1. Super Admins first
        for admin in store.permissionConfig.defaultAdmins {
            let clean = admin.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && !seen.contains(clean) {
                seen.insert(clean)
                let avatar = store.teamMembers.first(where: { $0.name == clean })?.avatarSymbol ?? "crown.fill"
                list.append((name: clean, avatar: avatar))
            }
        }
        
        // 2. Discovered team members
        for member in store.teamMembers {
            let clean = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && !seen.contains(clean) && !WorkbenchStore.mockNamesBlocklist.contains(clean) {
                seen.insert(clean)
                list.append((name: clean, avatar: member.avatarSymbol))
            }
        }
        
        // 3. Custom permissions configured members
        for (name, _) in store.permissionConfig.permissions {
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && !seen.contains(clean) && !WorkbenchStore.mockNamesBlocklist.contains(clean) {
                seen.insert(clean)
                list.append((name: clean, avatar: "person.crop.circle.fill"))
            }
        }
        
        // Filter by search text
        let query = memberSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { $0.name.lowercased().contains(query) }
        }
        
        return list
    }
    
    private var teamPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("全员权限管理 (RBAC)")
                            .font(.system(size: 15, weight: .bold))
                        
                        Text("iCloud 实时分发")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text("默认 Jason 和 Beauty 拥有最高权限，新加入成员默认为普通成员。管理员可在此自由分配与回收权限")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if store.isCurrentUserAdmin {
                    Button(action: {
                        newMemberName = ""
                        newMemberIsAdmin = false
                        newMemberCanPublish = true
                        newMemberCanSync = false
                        showAddPermissionSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                            Text("添加成员预设权限")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if !store.isCurrentUserAdmin {
                // Non-admin view
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("您当前为普通成员")
                            .font(.system(size: 13, weight: .semibold))
                        Text("团队管理员为 Jason / Beauty。如需开通团队公告发布或数据同步权限，请联系管理员在上方管理面板中授权。")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            } else {
                // Admin management view
                VStack(spacing: 12) {
                    // Search bar for members
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        TextField("搜索成员姓名快速配置权限...", text: $memberSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                        if !memberSearchText.isEmpty {
                            Button(action: { memberSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    
                    // Members list
                    VStack(spacing: 8) {
                        ForEach(allMembersToManage, id: \.name) { member in
                            memberPermissionRow(name: member.name, avatar: member.avatar)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }
    
    private func memberPermissionRow(name: String, avatar: String) -> some View {
        let isDefaultAdmin = store.isDefaultAdmin(name: name)
        let currentPerm = store.permission(for: name)
        
        return HStack(spacing: 12) {
            Image(systemName: isDefaultAdmin ? "crown.fill" : avatar)
                .font(.system(size: 18))
                .foregroundColor(isDefaultAdmin ? .orange : (currentPerm.isAdmin ? .purple : .accentColor))
                .frame(width: 34, height: 34)
                .background((isDefaultAdmin ? Color.orange : (currentPerm.isAdmin ? Color.purple : Color.accentColor)).opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13.5, weight: .bold))
                    
                    if name == store.currentUser.name {
                        Text("(当前登录账号)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                if isDefaultAdmin {
                    Text("系统默认最高权限，不可更改")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                } else if currentPerm.isAdmin {
                    Text("管理员权限（拥有全部管理、发布与同步能力）")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                } else {
                    HStack(spacing: 4) {
                        Text(currentPerm.canPublishAnnouncements ? "✓ 发布公告" : "✕ 发布公告")
                            .font(.system(size: 10.5))
                            .foregroundColor(currentPerm.canPublishAnnouncements ? .green : .secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(currentPerm.canSyncData ? "✓ 数据同步" : "✕ 数据同步")
                            .font(.system(size: 10.5))
                            .foregroundColor(currentPerm.canSyncData ? .green : .secondary)
                    }
                }
            }
            
            Spacer()
            
            if isDefaultAdmin {
                Label("超级管理员", systemImage: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                HStack(spacing: 10) {
                    // Quick Role Switch
                    Picker("", selection: Binding(
                        get: { currentPerm.isAdmin ? "admin" : "member" },
                        set: { newRole in
                            let isAdm = (newRole == "admin")
                            store.updatePermission(
                                for: name,
                                isAdmin: isAdm,
                                canPublishAnnouncements: isAdm || currentPerm.canPublishAnnouncements,
                                canSyncData: isAdm || currentPerm.canSyncData
                            )
                        }
                    )) {
                        Text("普通成员").tag("member")
                        Text("管理员").tag("admin")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    
                    if !currentPerm.isAdmin {
                        // Granular checkboxes for regular members
                        Toggle("发布公告", isOn: Binding(
                            get: { currentPerm.canPublishAnnouncements },
                            set: { val in
                                store.updatePermission(
                                    for: name,
                                    isAdmin: false,
                                    canPublishAnnouncements: val,
                                    canSyncData: currentPerm.canSyncData
                                )
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        
                        Toggle("数据同步", isOn: Binding(
                            get: { currentPerm.canSyncData },
                            set: { val in
                                store.updatePermission(
                                    for: name,
                                    isAdmin: false,
                                    canPublishAnnouncements: currentPerm.canPublishAnnouncements,
                                    canSyncData: val
                                )
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                    }
                    
                    // 删除成员按钮（禁止删除自己和超级管理员）
                    if name != store.currentUser.name {
                        Button(role: .destructive) {
                            store.removeMember(name: name)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                        .help("从名单及共享文件夹中移除此成员名片")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - Add Member Permission Sheet
    
    private var addPermissionSheetView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    Text("添加新成员预设权限")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Button(action: { showAddPermissionSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("成员姓名 / 称呼")
                    .font(.system(size: 13, weight: .semibold))
                TextField("请输入团队成员姓名（如：Alex）", text: $newMemberName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("角色类型")
                    .font(.system(size: 13, weight: .semibold))
                
                Picker("角色", selection: $newMemberIsAdmin) {
                    Text("普通成员 (默认仅查看/留言)").tag(false)
                    Text("管理员 (最高全权)").tag(true)
                }
                .pickerStyle(.radioGroup)
            }
            
            if !newMemberIsAdmin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("细粒度权限配置")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Toggle("允许发布团队公告", isOn: $newMemberCanPublish)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12.5))
                    
                    Toggle("允许触发邮件与知识库数据同步", isOn: $newMemberCanSync)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12.5))
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("取消") {
                    showAddPermissionSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("保存并授权") {
                    let cleanName = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { return }
                    
                    store.updatePermission(
                        for: cleanName,
                        isAdmin: newMemberIsAdmin,
                        canPublishAnnouncements: newMemberCanPublish || newMemberIsAdmin,
                        canSyncData: newMemberCanSync || newMemberIsAdmin
                    )
                    
                    showAddPermissionSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - iCloud Shared Folder Sync
    
    private var sharedFolderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud 团队云端同步 (共享文件夹)")
                        .font(.system(size: 15, weight: .bold))
                    Text("绑定 iCloud 共享文件夹后，团队公告、已读名单与讨论留言将在居家成员电脑上实时自动同步")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if sharedFolderSync.isConnected {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("已连接云端同步")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    Text("当前为单机本地模式")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 14) {
                if let path = sharedFolderSync.sharedFolderPath, sharedFolderSync.isConnected {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 30))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 14, weight: .bold))
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack(spacing: 10) {
                            if let lastSync = sharedFolderSync.lastSyncDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10))
                                    Text("最近云端同步: \(formatSyncTime(lastSync))")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("在访达中查看") {
                                sharedFolderSync.openInFinder()
                            }
                            .controlSize(.small)
                            
                            Button("立即全员双向同步") {
                                store.forceSyncAllWithSharedFolder()
                            }
                            .controlSize(.small)
                            
                            Button("更改文件夹") {
                                sharedFolderSync.selectSharedFolder { success in
                                    if success {
                                        store.loadDataFromSharedFolder()
                                    }
                                }
                            }
                            .controlSize(.small)
                            
                            Button("断开连接", role: .destructive) {
                                sharedFolderSync.disconnect()
                            }
                            .controlSize(.small)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("尚未绑定团队共享文件夹")
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text("请点击右侧按钮，选定您在 Finder 的 iCloud Drive 中创建并共享给组员的「团队工作台数据」文件夹。")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("选择团队共享文件夹...") {
                                sharedFolderSync.selectSharedFolder { success in
                                    if success {
                                        store.forceSyncAllWithSharedFolder()
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(sharedFolderSync.isConnected ? Color.green.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    private func formatSyncTime(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        if cal.isDateInToday(date) {
            return "今天 \(timeFormatter.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            return "昨天 \(timeFormatter.string(from: date))"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm"
            return df.string(from: date)
        }
    }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("系统通知与推送提醒")
                .font(.system(size: 15, weight: .bold))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS 系统通知权限")
                            .font(.system(size: 13, weight: .medium))
                        Text(notificationService.isAuthorized ? "已授权，重要公告与资讯将通过系统横幅实时提醒" : "未授权通知，建议开启以获取重要通知")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if notificationService.isAuthorized {
                        Label("已开启", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                    } else {
                        Button("开启通知权限") {
                            notificationService.requestAuthorization()
                        }
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("测试通知通道")
                        .font(.system(size: 13))
                    Spacer()
                    Button("发送测试通知") {
                        notificationService.sendLocalNotification(
                            title: "🚨 团队工作台系统测试",
                            subtitle: "通知通道测试",
                            body: "恭喜！您的 macOS 团队工作台本地通知通道运行正常。"
                        )
                        showTestNotificationSent = true
                    }
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var dataManagementSection: some View {
        let isSuperAdmin = store.isDefaultAdmin(name: store.currentUser.name)
        
        VStack(alignment: .leading, spacing: 14) {
            Text("数据管理")
                .font(.system(size: 15, weight: .bold))
            
            VStack(alignment: .leading, spacing: 12) {
                // 1. 清空重要邮件缓存 (仅超级管理员可用)
                if isSuperAdmin {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("清空重要邮件缓存")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.orange)
                                Text("超管专属")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            }
                            Text("清空所有存储存在云端的邮件内容，重置为全新状态")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("清空邮件云端数据", role: .destructive) {
                            showConfirmClearNews = true
                        }
                        .controlSize(.small)
                    }
                    
                    Divider()
                }
                
                // 2. 清空本地数据 (所有成员可用)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空本地数据")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                        Text("清空当前电脑上缓存的公告、邮件与已读记录，不影响他人与云端共享文件")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("清空本地数据", role: .destructive) {
                        showConfirmClearLocal = true
                    }
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("关于莱斯小站")
                .font(.system(size: 15, weight: .bold))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前版本")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(updateService.currentVersion) (Build \(updateService.currentBuild))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        updateService.checkForUpdates(isUserInitiated: true)
                        updateService.showUpdateSheet = true
                    }) {
                        HStack(spacing: 4) {
                            if updateService.isChecking {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10.5))
                            }
                            Text("检查更新")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Divider()
                HStack {
                    Text("架构设计")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("SwiftUI + macOS Native + Decoupled API Store")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Divider()
                HStack {
                    Text("后端云端扩展")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("已预留 RESTful / CloudKit 同步接口")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("产品反馈")
                            .font(.system(size: 12, weight: .medium))
                        Text("提出功能建议、故障反馈或使用体验，反馈将直发至 liang_wu@apple.com")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showProductFeedbackSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                                .font(.system(size: 11))
                            Text("提供反馈")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Product Feedback (产品反馈模型与交互界面)

public enum FeedbackType: String, CaseIterable, Identifiable, Codable {
    case feature = "功能建议"
    case bug = "故障反馈"
    case experience = "界面体验"
    case other = "其他吐槽"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .feature: return "lightbulb.fill"
        case .bug: return "exclamationmark.triangle.fill"
        case .experience: return "paintpalette.fill"
        case .other: return "bubble.left.and.bubble.right.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .feature: return .orange
        case .bug: return .red
        case .experience: return .blue
        case .other: return .purple
        }
    }
}

public struct ProductFeedbackItem: Identifiable, Codable {
    public var id: UUID
    public var type: FeedbackType
    public var title: String
    public var content: String
    public var submitter: String
    public var appVersion: String
    public var osVersion: String
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        type: FeedbackType = .feature,
        title: String,
        content: String,
        submitter: String,
        appVersion: String,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.submitter = submitter
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.createdAt = createdAt
    }
}

struct ProductFeedbackSheetView: View {
    let currentUserName: String
    let appVersion: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: FeedbackType = .feature
    @State private var titleInput: String = ""
    @State private var contentInput: String = ""
    @State private var includeSystemInfo: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var alertTitle: String = "反馈已发送"
    @State private var alertMessage: String = ""
    
    private var isFormValid: Bool {
        !titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("产品使用反馈")
                        .font(.system(size: 16, weight: .bold))
                    Text("感谢您帮助团队工作台变得更好！您的反馈将直接发送至负责人邮箱。")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 4)
            
            Divider()
            
            // 1. 类型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("反馈类型")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(FeedbackType.allCases) { type in
                        let isSelected = (selectedType == type)
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 11.5))
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                            }
                            .foregroundColor(isSelected ? type.color : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(isSelected ? type.color.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? type.color.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 2. 简要标题
            VStack(alignment: .leading, spacing: 6) {
                Text("反馈标题")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("一句话概括您的反馈 (例如：希望重要邮件支持按关键词高亮)", text: $titleInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5))
            }
            
            // 3. 详细描述
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("详细说明")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("支持多行")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $contentInput)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .frame(height: 120)
                    
                    if contentInput.isEmpty {
                        Text("请详细描述您遇到的问题现象、复现步骤或期望的功能效果...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            // 4. 环境信息附带
            HStack {
                Toggle(isOn: $includeSystemInfo) {
                    HStack(spacing: 4) {
                        Text("附带提交人与环境信息")
                            .font(.system(size: 11.5))
                        Text("(\(currentUserName) · \(appVersion))")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            
            Divider()
            
            // 底部操作按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    submitFeedback()
                }) {
                    HStack(spacing: 5) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11.5))
                        }
                        Text(isSubmitting ? "正在发送..." : "发送反馈邮件")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .padding(22)
        .frame(width: 480)
        .alert(alertTitle, isPresented: $showSuccessAlert) {
            Button("好的") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        let item = ProductFeedbackItem(
            type: selectedType,
            title: titleInput.trimmingCharacters(in: .whitespacesAndNewlines),
            content: contentInput.trimmingCharacters(in: .whitespacesAndNewlines),
            submitter: includeSystemInfo ? currentUserName : "匿名成员",
            appVersion: includeSystemInfo ? appVersion : "未知"
        )
        
        // 1. 本地历史存底缓存
        var localList: [ProductFeedbackItem] = []
        if let data = UserDefaults.standard.data(forKey: "workbench_local_feedback_history"),
           let decoded = try? JSONDecoder().decode([ProductFeedbackItem].self, from: data) {
            localList = decoded
        }
        localList.insert(item, at: 0)
        if let encoded = try? JSONEncoder().encode(localList) {
            UserDefaults.standard.set(encoded, forKey: "workbench_local_feedback_history")
        }
        
        // 2. 直接通过 Apple Mail 发送至 liang_wu@apple.com (无需同步共享文件夹)
        sendFeedbackEmail(item: item)
    }
    
    private func sendFeedbackEmail(item: ProductFeedbackItem) {
        let recipient = "liang_wu@apple.com"
        let emailSubject = "[团队工作台反馈] [\(item.type.rawValue)] \(item.title)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeStr = dateFormatter.string(from: item.createdAt)
        
        let emailBody = """
        【团队工作台 · 产品反馈】
        
        反馈类型：\(item.type.rawValue)
        反馈标题：\(item.title)
        提交人员：\(item.submitter)
        提交时间：\(timeStr)
        应用版本：\(item.appVersion)
        系统环境：\(item.osVersion)
        
        --------------------------------------------------
        【详细说明 / 期望效果】：
        \(item.content)
        --------------------------------------------------
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            let safeSubj = emailSubject
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let safeBody = emailBody
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            
            let scriptDirectSend = """
            tell application "Mail"
                try
                    set newMsg to make new outgoing message with properties {subject:"\(safeSubj)", content:"\(safeBody)", visible:false}
                    tell newMsg
                        make new to recipient at end of to recipients with properties {address:"\(recipient)"}
                    end tell
                    send newMsg
                    return "SENT"
                on error errMsg
                    set fallbackMsg to make new outgoing message with properties {subject:"\(safeSubj)", content:"\(safeBody)", visible:true}
                    tell fallbackMsg
                        make new to recipient at end of to recipients with properties {address:"\(recipient)"}
                    end tell
                    activate
                    return "OPENED"
                end try
            end tell
            """
            
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: scriptDirectSend)
            let resultDesc = appleScript?.executeAndReturnError(&errorDict)
            let resultStr = resultDesc?.stringValue ?? ""
            
            DispatchQueue.main.async {
                self.isSubmitting = false
                if resultStr == "SENT" {
                    self.alertTitle = "反馈已发送"
                    self.alertMessage = "非常感谢您的宝贵建议！反馈内容已直接通过邮件发送至 \(recipient)。"
                } else {
                    self.alertTitle = "邮件已就绪"
                    self.alertMessage = "已为您在邮件应用中生成反馈草稿，请在弹出的邮件窗口中点击发送至 \(recipient)。"
                }
                self.showSuccessAlert = true
            }
        }
    }
}
