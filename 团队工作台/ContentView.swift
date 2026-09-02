//
//  ContentView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct ContentView: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject var sharedFolderSync = SharedFolderSyncService.shared
    @ObservedObject var notificationService = NotificationService.shared
    
    @State private var isRefreshing = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Bar
            topHeaderBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 2. Horizontal Navigation Tabs Bar
            horizontalTabsBar
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            
            Divider()
            
            // 3. Main Content View Area
            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 700)
    }
    
    // MARK: - 1. Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 16) {
            // Left: Logo + Title + Subtitle
            HStack(spacing: 10) {
                // Logo Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    
                    Text("JT")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jason Team")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("欢迎回来，\(store.currentUser.name)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }
            
            // Cloud Sync Status Capsule
            if sharedFolderSync.isConnected {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("云端连接正常 (10s 自动轮询)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
            } else {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("本地单机模式 (未绑定共享文件夹)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Refresh Button
            Button(action: {
                isRefreshing = true
                store.forceSyncAllWithSharedFolder()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isRefreshing = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .rotationEffect(isRefreshing ? .degrees(360) : .zero)
                        .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    Text("刷新")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("立即执行全员数据双向对齐与云端拉取")
            
            Spacer()
            
            // Center Global Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("全局搜索案例号、公告、邮件、问答...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                
                if !store.searchText.isEmpty {
                    Button(action: { store.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 320)
            .background(Color(NSColor.textBackgroundColor).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
            
            // Right Side Action Icons
            HStack(spacing: 12) {
                // Test Notification sound button
                Button(action: {
                    notificationService.sendLocalNotification(
                        title: "🔔 团队工作台通知测试",
                        subtitle: "系统提醒",
                        body: "团队协同通知运行正常！"
                    )
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("测试系统通知声音与横幅")
                
                // Settings button
                Button(action: {
                    store.selectedNavigation = .settings
                }) {
                    Image(systemName: store.selectedNavigation == .settings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(store.selectedNavigation == .settings ? .accentColor : .secondary)
                        .padding(6)
                        .background(store.selectedNavigation == .settings ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("偏好设置与云端同步管理")
                
                // Publish Dropdown Menu Button
                Menu {
                    Button {
                        store.selectedNavigation = .publish
                    } label: {
                        Label("发布团队公告", systemImage: "megaphone.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        store.selectedNavigation = .faq
                    } label: {
                        Label("新增 FAQ 问答", systemImage: "questionmark.bubble.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("我要发布")
                            .font(.system(size: 12.5, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 2. Horizontal Navigation Tabs Bar
    
    private var horizontalTabsBar: some View {
        HStack(spacing: 8) {
            // Main Tabs
            tabButton(title: "首页概览", icon: "square.grid.2x2.fill", item: .dashboard)
            
            tabButton(
                title: "团队公告板",
                icon: "megaphone.fill",
                item: .announcements,
                badgeCount: store.unacknowledgedCount > 0 ? store.unacknowledgedCount : nil,
                badgeColor: .red
            )
            
            tabButton(
                title: "重要邮件与资讯",
                icon: "envelope.fill",
                item: .news,
                badgeCount: store.newsArticles.count > 0 ? store.newsArticles.count : nil,
                badgeColor: .green
            )
            
            tabButton(
                title: "常见知识FAQ",
                icon: "questionmark.bubble.fill",
                item: .faq,
                badgeCount: store.faqItems.count > 0 ? store.faqItems.count : nil,
                badgeColor: .blue
            )
            
            if store.selectedNavigation == .publish {
                tabButton(title: "发布中心", icon: "square.and.pencil", item: .publish)
            }
            
            if store.selectedNavigation == .settings {
                tabButton(title: "偏好设置", icon: "gearshape.fill", item: .settings)
            }
            
            Spacer()
            
            // Right Side Cloud Status indicator
            HStack(spacing: 4) {
                Text(sharedFolderSync.isConnected ? "云端多端同步中" : "单机模式")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(sharedFolderSync.isConnected ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private func tabButton(
        title: String,
        icon: String,
        item: AppNavigationItem,
        badgeCount: Int? = nil,
        badgeColor: Color = .gray
    ) -> some View {
        let isSelected = (store.selectedNavigation == item)
        
        return Button(action: {
            store.selectedNavigation = item
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                
                if let count = badgeCount {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(isSelected ? (badgeColor == .red ? Color.red : Color.accentColor) : Color.secondary.opacity(0.15))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
            .foregroundColor(isSelected ? Color.blue : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. Main Content View Area
    
    private var mainContentArea: some View {
        Group {
            if !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                GlobalSearchResultsView()
            } else {
                switch store.selectedNavigation {
                case .dashboard, .none:
                    DashboardView()
                case .announcements:
                    AnnouncementsView()
                case .news:
                    NewsView()
                case .faq:
                    FAQView()
                case .publish:
                    PublishView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkbenchStore())
}
