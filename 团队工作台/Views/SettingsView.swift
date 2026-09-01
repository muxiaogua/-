//
//  SettingsView.swift
//  团队工作台
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var notificationService = NotificationService.shared
    
    @State private var showClearAlert = false
    @State private var showTestNotificationAlert = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("偏好设置与数据管理")
                        .font(.system(size: 24, weight: .bold))
                    Text("管理个人团队身份、本地系统通知以及清理存储数据")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Current User Info Card
                userProfileSection
                
                // Notifications Settings Card
                notificationSection
                
                // Data Management Section
                dataManagementSection
                
                // About App Section
                aboutSection
            }
            .padding(28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("数据已清空", isPresented: $showClearAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("所有本地公告与资讯内容均已清理完毕，工作台已恢复为空白就绪状态。")
        }
        .alert("测试通知已发送", isPresented: $showTestNotificationAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("已通过 macOS 系统通知中心发送一条测试横幅，请留意屏幕右上角。")
        }
    }
    
    // MARK: - Sections
    
    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("当前团队身份")
                .font(.system(size: 15, weight: .bold))
            
            HStack(spacing: 16) {
                Image(systemName: store.currentUser.avatarSymbol)
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(store.currentUser.name)
                            .font(.system(size: 16, weight: .bold))
                        Text(store.currentUser.role)
                            .font(.system(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                    Text("所属部门: \(store.currentUser.department)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
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
                        Text("清除全部已发布的团队公告、资讯文章及签收记录")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("清空全部数据", role: .destructive) {
                        store.clearAllData()
                        showClearAlert = true
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
