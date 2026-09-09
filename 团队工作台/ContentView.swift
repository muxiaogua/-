//
//  ContentView.swift
//  团队工作台
//

import SwiftUI
import AppKit
import RelaxKit

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
            
            // 2. Primary Dropdown Navigation Menu Bar
            primaryDropdownMenuBar
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            
            Divider()
            
            // 3. Main Content View Area
            mainContentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .navigationTitle("")
        .onChange(of: store.selectedNavigation) { _, newNav in
            if let nav = newNav, let cat = nav.category {
                if store.selectedCategory != cat {
                    store.selectedCategory = cat
                }
            }
        }
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
                
                // Publish Button (Only visible for members with announcement publishing permission)
                if store.canCurrentUserPublishAnnouncements {
                    Button {
                        store.selectedNavigation = .publish
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("发布公告")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("起草并向全员发布团队公告")
                }
            }
        }
    }
    
    // MARK: - 2. Primary Navigation Dropdown Menu Bar
    
    private var primaryDropdownMenuBar: some View {
        HStack(spacing: 8) {
            // Dashboard Direct Button
            dashboardButton
            
            // Dropdown Menus for Categories
            ForEach(AppNavigationCategory.allCases.filter { $0 != .dashboard }) { cat in
                categoryDropdownMenu(for: cat)
            }
            
            if store.canCurrentUserPublishAnnouncements && store.selectedNavigation == .publish {
                tabButton(title: "发布中心", icon: "square.and.pencil", item: .publish)
            }
            
            if store.selectedNavigation == .settings {
                tabButton(title: "偏好设置", icon: "gearshape.fill", item: .settings)
            }
            
            Spacer()
            
            // Right Side Cloud Status indicator
            if store.selectedCategory.isTeamSynced {
                HStack(spacing: 4) {
                    Text(sharedFolderSync.isConnected ? "全员云端同步中" : "单机模式")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(sharedFolderSync.isConnected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("个人本地私有")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var dashboardButton: some View {
        let isSelected = (store.selectedNavigation == .dashboard)
        
        return Button(action: {
            store.selectedCategory = .dashboard
            store.selectedNavigation = .dashboard
        }) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                
                Text("首页概览")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isSelected ? Color.blue.opacity(0.14) : Color.clear)
            .foregroundColor(isSelected ? Color.blue : Color.primary.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func categoryDropdownMenu(for cat: AppNavigationCategory) -> some View {
        let isSelected = (store.selectedCategory == cat)
        let badge = badgeCountForCategory(cat)
        
        return ZStack(alignment: .topTrailing) {
            Menu {
                ForEach(cat.subItems, id: \.self) { (subItem: AppNavigationItem) in
                    let subBadge = badgeCountForSubItem(subItem)
                    
                    Button(action: {
                        store.selectedCategory = cat
                        store.selectedNavigation = subItem
                    }) {
                        if let count = subBadge, count > 0 {
                            Text("\(subItem.rawValue) (\(count)条未读)")
                        } else {
                            Text(subItem.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: cat.iconName)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    
                    Text(cat.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(isSelected ? Color.blue : Color.secondary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(isSelected ? Color.blue.opacity(0.14) : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? Color.blue : Color.primary.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            
            // 独立的浮层角标，不受 NSMenu 按钮自身裁切影响
            if let count = badge, count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                    .offset(x: 5, y: -4)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func badgeCountForCategory(_ cat: AppNavigationCategory) -> Int? {
        switch cat {
        case .teamShare:
            return store.unreadAnnouncementsCount > 0 ? store.unreadAnnouncementsCount : nil
        case .queryCenter:
            return store.unreadNewsCount > 0 ? store.unreadNewsCount : nil
        default:
            return nil
        }
    }
    
    private func badgeCountForSubItem(_ item: AppNavigationItem) -> Int? {
        switch item {
        case .announcements:
            return store.unreadAnnouncementsCount > 0 ? store.unreadAnnouncementsCount : nil
        case .news:
            return store.unreadNewsCount > 0 ? store.unreadNewsCount : nil
        default:
            return nil
        }
    }
    
    private func tabButton(
        title: String,
        icon: String,
        item: AppNavigationItem
    ) -> some View {
        let isSelected = (store.selectedNavigation == item)
        
        return Button(action: {
            store.selectedNavigation = item
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Text(title)
                    .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background(isSelected ? Color.blue.opacity(0.14) : Color.clear)
            .foregroundColor(isSelected ? Color.blue : Color.primary.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 4. Main Content View Area
    
    private var mainContentArea: some View {
        Group {
            if !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                GlobalSearchResultsView()
            } else {
                switch store.selectedNavigation {
                case .dashboard, .none:
                    DashboardView()
                    
                // 团队共享
                case .announcements:
                    AnnouncementsView()
                case .teamShifts:
                    TeamShiftsView()
                    
                // 个人中心
                case .shifts:
                    ShiftsView()
                case .leaveRequest:
                    PlaceholderReservedView(title: "我要请假", icon: "airplane.departure", subtitle: "个人假期申请与请假进度追踪功能正在规划中，即将上线！")
                case .myStats:
                    PlaceholderReservedView(title: "数据统计", icon: "chart.bar.xaxis", subtitle: "个人业务指标与工作数据分析看板正在建设中，即将上线！")
                    
                // 查询中心
                case .news:
                    NewsView()
                case .npiQuery:
                    NPIQueryView()
                case .faq:
                    FAQView()
                case .priceQuery:
                    PriceQueryView()
                    
                // 互帮互助
                case .caseAssistance:
                    PlaceholderReservedView(title: "案例协助", icon: "bubble.left.and.exclamationmark.bubble.right.fill", subtitle: "疑难案例团队求助与协同讨论专区正在建设中，即将上线！")
                case .sharedKnowledge:
                    PlaceholderReservedView(title: "共享知识库", icon: "books.vertical.fill", subtitle: "团队沉淀知识库与经验总结专区正在规划中，即将上线！")
                    
                // 小工具
                case .luckyWheel:
                    LuckyWheelView()
                case .dateCalculator:
                    DateCalculatorView()
                case .mindRetreat:
                    RelaxMainView()
                    
                // 特殊页面
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
