//
//  SettingsView.swift
//  团队工作台
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var notificationService = NotificationService.shared
    @ObservedObject var sharedFolderSync = SharedFolderSyncService.shared
    
    @State private var showConfirmClearAlert = false
    @State private var showClearSuccessAlert = false
    @State private var showTestNotificationAlert = false
    @State private var showEditProfileSheet = false
    
    // Edit Profile States
    @State private var editName = ""
    @State private var editAvatar = "person.crop.circle.fill.badge.checkmark"
    
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
                
                // 2. iCloud Shared Folder Sync Section
                sharedFolderSection
                
                // 3. Notifications Settings Card
                notificationSection
                
                // 4. Data Management Section
                dataManagementSection
                
                // 5. About App Section
                aboutSection
            }
            .padding(28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("确认清空工作台数据？", isPresented: $showConfirmClearAlert) {
            Button("确认清空", role: .destructive) {
                store.clearAllData()
                showClearSuccessAlert = true
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作将彻底清除本地存储的全部团队公告、资讯文章及已读确认记录。\n\n该操作无法撤销，确定要清空吗？")
        }
        .alert("数据已清空", isPresented: $showClearSuccessAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("所有本地公告与资讯内容均已清理完毕，工作台已恢复为空白就绪状态。")
        }
        .alert("测试通知已发送", isPresented: $showTestNotificationAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("已通过 macOS 系统通知中心发送一条测试横幅，请留意屏幕右上角。")
        }
        .sheet(isPresented: $showEditProfileSheet) {
            editProfileSheetView
        }
    }
    
    // MARK: - Sections
    
    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的团队身份")
                .font(.system(size: 15, weight: .bold))
            
            HStack(spacing: 16) {
                Image(systemName: store.currentUser.avatarSymbol)
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(store.currentUser.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Label("在线", systemImage: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    
                    Text("此名称将作为您在团队工作台中发布公告、确认已读及留言的唯一署名")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("修改我的显示名称与头像")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("关闭") {
                    showEditProfileSheet = false
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("我的姓名 / 称呼")
                    .font(.system(size: 12, weight: .semibold))
                TextField("请输入您的真实姓名或称谓（如：亮亮）", text: $editName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("选择头像图标")
                    .font(.system(size: 12, weight: .semibold))
                
                HStack(spacing: 12) {
                    ForEach(availableAvatars, id: \.self) { sym in
                        Button(action: {
                            editAvatar = sym
                        }) {
                            Image(systemName: sym)
                                .font(.system(size: 20))
                                .foregroundColor(editAvatar == sym ? .accentColor : .secondary)
                                .padding(8)
                                .background(editAvatar == sym ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("取消") {
                    showEditProfileSheet = false
                }
                .buttonStyle(.bordered)
                
                Button("保存修改") {
                    let name = editName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.updateCurrentUser(
                        name: name,
                        avatarSymbol: editAvatar
                    )
                    showEditProfileSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
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
                        showTestNotificationAlert = true
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
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("数据管理")
                .font(.system(size: 15, weight: .bold))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空工作台所有数据")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                        Text("清除全部已发布的团队公告、资讯文章及已读确认记录")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("清空全部数据", role: .destructive) {
                        showConfirmClearAlert = true
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
            Text("关于团队工作台")
                .font(.system(size: 15, weight: .bold))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("版本")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("1.0.0 (Build 2026.09)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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
