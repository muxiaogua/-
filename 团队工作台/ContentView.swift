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
    @ObservedObject var updateService = AppUpdateService.shared
    
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
            
            // 3. Sub-Navigation Bar (分类含有多个子菜单时自动呈现横向子导航切换栏)
            if store.selectedCategory.subItems.count > 1 {
                subNavigationBar
                Divider()
            }
            
            // 4. Main Content View Area
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
        .sheet(isPresented: $updateService.showUpdateSheet) {
            AppUpdateSheetView()
        }
        .sheet(item: $store.masterSyncResult) { result in
            MasterSyncReportSheet(result: result)
        }
        .onAppear {
            updateService.checkForUpdates(isUserInitiated: false)
        }
    }
    
    // MARK: - 1. Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 16) {
            // Left: Logo + Title + Subtitle
            HStack(spacing: 10) {
                // Logo Icon
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                
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
                    Text("云端连接正常")
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
            
            // Master Check Updates Button (一键检查全部更新) - 仅限有同步权限的成员可见
            if store.canCurrentUserSyncData {
                HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await store.performMasterSync()
                        }
                    }) {
                        HStack(spacing: 5) {
                            if store.isMasterSyncing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 13, height: 13)
                                Text("全模块检查中...")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                                Text("检查更新")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isMasterSyncing)
                    .help("一键检查全部板块更新：NPI邮件、NPI议题、RCC FAQ、重要邮件、Chorus知识库、官网最新价格以及团队共享数据")
                    
                    if let info = store.latestUpdateDisplayInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(store.formatLatestSyncTime(info.time, syncedBy: info.by))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .help("最近更新时间：\(store.formatFullDateTime(info.time))\(info.by.isEmpty ? "" : "，执行人: \(info.by)")")
                    }
                }
            } else if sharedFolderSync.isConnected {
                HStack(spacing: 8) {
                    // 普通成员仅展示轻量从云端共享文件夹刷新
                    Button(action: {
                        isRefreshing = true
                        store.loadDataFromSharedFolder()
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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("从团队共享文件夹拉取最新的公告、排班与云端数据")
                    
                    if let info = store.latestUpdateDisplayInfo {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(store.formatLatestSyncTime(info.time, syncedBy: info.by))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .help("最近更新时间：\(store.formatFullDateTime(info.time))\(info.by.isEmpty ? "" : "，执行人: \(info.by)")")
                    }
                }
            }
            
            Spacer()
            
            // Center Global Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("全局搜索知识库、SOP、公告、邮件、问答...", text: $store.searchText)
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
            ForEach(AppNavigationCategory.allCases.filter { $0 != .dashboard && $0 != .songKouQi }) { cat in
                categoryDropdownMenu(for: cat)
            }
            
            // 松口气独立顶级菜单按钮
            relaxButton
            
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
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selectedCategory = .dashboard
                store.selectedNavigation = .dashboard
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                
                Text("首页概览")
                    .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                ? AnyView(
                    LinearGradient(colors: [Color.blue, Color.blue.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.3), radius: 3, y: 1.5)
                )
                : AnyView(
                    Color(NSColor.controlBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
            )
            .foregroundColor(isSelected ? .white : .primary.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
    
    private var relaxButton: some View {
        let isSelected = (store.selectedNavigation == .relax)
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selectedCategory = .songKouQi
                store.selectedNavigation = .relax
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                
                Text("松口气")
                    .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                ? AnyView(
                    LinearGradient(colors: [Color.teal, Color.teal.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: Color.teal.opacity(0.3), radius: 3, y: 1.5)
                )
                : AnyView(
                    Color(NSColor.controlBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
            )
            .foregroundColor(isSelected ? .white : .primary.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
    
    private func categoryDropdownMenu(for cat: AppNavigationCategory) -> some View {
        let isSelected = (store.selectedNavigation?.category == cat || store.selectedCategory == cat)
        let badge = badgeCountForCategory(cat)
        let themeColor = cat.themeColor
        
        return ZStack(alignment: .topTrailing) {
            Menu {
                ForEach(cat.subItems, id: \.self) { (subItem: AppNavigationItem) in
                    let subBadge = badgeCountForSubItem(subItem)
                    let isSubSelected = (store.selectedNavigation == subItem)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.selectedCategory = cat
                            store.selectedNavigation = subItem
                        }
                    }) {
                        HStack {
                            if isSubSelected {
                                Text("✓  \(subItem.rawValue)")
                            } else {
                                Text("    \(subItem.rawValue)")
                            }
                            if let count = subBadge, count > 0 {
                                Text(" (\(count)条未读)")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: cat.iconName)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : themeColor)
                    
                    Text(cat.rawValue)
                        .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                    ? AnyView(
                        LinearGradient(colors: [themeColor, themeColor.opacity(0.86)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: themeColor.opacity(0.32), radius: 3, y: 1.5)
                    )
                    : AnyView(
                        Color(NSColor.controlBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    )
                )
                .foregroundColor(isSelected ? .white : .primary.opacity(0.85))
            }
            .buttonStyle(.plain)
            
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
    
    // MARK: - 3. Secondary Sub-Navigation Bar
    
    private var subNavigationBar: some View {
        let currentCat = store.selectedCategory
        let catColor = currentCat.themeColor
        
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: currentCat.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(catColor)
                Text(currentCat.rawValue)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(catColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(catColor.opacity(0.6))
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            
            ForEach(currentCat.subItems, id: \.self) { item in
                let isCurrent = (store.selectedNavigation == item)
                let badge = badgeCountForSubItem(item)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.selectedNavigation = item
                    }
                }) {
                    HStack(spacing: 4.5) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 10.5, weight: isCurrent ? .bold : .medium))
                        
                        Text(item.rawValue)
                            .font(.system(size: 11.5, weight: isCurrent ? .bold : .medium))
                        
                        if let count = badge, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 0.5)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(isCurrent ? catColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(isCurrent ? Color.white : Color.primary.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: isCurrent ? catColor.opacity(0.3) : Color.clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }
    
    private func badgeCountForCategory(_ cat: AppNavigationCategory) -> Int? {
        switch cat {
        case .teamShare:
            return store.unreadAnnouncementsCount > 0 ? store.unreadAnnouncementsCount : nil
        case .npiFocus:
            return store.unreadNpiEmailsCount > 0 ? store.unreadNpiEmailsCount : nil
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
        case .npiEmails:
            return store.unreadNpiEmailsCount > 0 ? store.unreadNpiEmailsCount : nil
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
                    MyStatsView()
                    
                // NPI专题
                case .npiEmails:
                    NPIMailsView()
                case .npiQuery:
                    NPIQueryView()
                case .rccFaqNpi:
                    RCCNPIFAQView()
                    
                // 查询中心
                case .news:
                    NewsView()
                case .faq:
                    FAQView()
                case .priceQuery:
                    PriceQueryView()
                    
                // 互帮互助
                case .caseAssistance:
                    PlaceholderReservedView(title: "案例协助", icon: "bubble.left.and.exclamationmark.bubble.right.fill", subtitle: "疑难案例团队求助与协同讨论专区正在建设中，即将上线！")
                case .sharedKnowledge:
                    SharedKnowledgeView()
                    
                // 小工具
                case .luckyWheel:
                    LuckyWheelView()
                case .dateCalculator:
                    DateCalculatorView()
                case .relax:
                    SongKouQiMainView()
                    
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

// MARK: - Master Sync Report Sheet (全模块检查更新审计看板)

struct MasterSyncReportSheet: View {
    let result: MasterSyncResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("全模块检查更新完成")
                        .font(.system(size: 16, weight: .bold))
                    Text("检查执行人：\(result.syncedBy) · \(formatTime(result.timestamp))")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                resultRow(icon: "envelope.fill", color: .green, title: "重要邮件 (绿邮 / Slack)", detail: "当前共收录 \(result.greenEmailCount) 封\(result.greenEmailNew > 0 ? "（新发现 \(result.greenEmailNew) 封）" : "（已是最新）")")
                resultRow(icon: "flame.fill", color: .orange, title: "NPI 重点邮件与议题", detail: "当前共收录 \(result.npiEmailCount) 封\(result.npiEmailNew > 0 ? "（新收录 \(result.npiEmailNew) 封）" : "（已是最新）")")
                resultRow(icon: "questionmark.bubble.fill", color: .teal, title: "Chorus 问答知识库", detail: "共校验 \(result.faqCount) 条（已包含 RCC FAQ_NPI 专项）")
                resultRow(icon: "tag.fill", color: .indigo, title: "Apple 官网公示价格", detail: result.priceDiffCount > 0 ? "检测到 \(result.priceDiffCount) 处价格或机型变动" : "全系列官方公示维修价格一致")
                resultRow(icon: "icloud.fill", color: .blue, title: "团队共享数据", detail: "公告、排班、花名册与权限已对齐云端")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            
            HStack {
                Spacer()
                Button("知道了") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(width: 450)
    }
    
    private func resultRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13.5))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
