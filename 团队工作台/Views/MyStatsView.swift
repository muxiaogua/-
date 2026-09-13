//
//  MyStatsView.swift
//  团队工作台
//

import SwiftUI
import AppKit

// MARK: - 时间段选择枚举

public enum StatsTimeRange: String, CaseIterable, Identifiable {
    case all = "全部时间"
    case thisWeek = "本周"
    case thisMonth = "本月"
    case last30Days = "近 30 天"
    case last90Days = "近 90 天"
    case custom = "自定义范围"
    
    public var id: String { rawValue }
    
    public func dateInterval(customStart: Date, customEnd: Date) -> (start: Date?, end: Date?) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 周一为一周起始
        cal.minimumDaysInFirstWeek = 4
        let now = Date()
        
        switch self {
        case .all:
            return (nil, nil)
        case .thisWeek:
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2
            let monday = cal.date(from: comps) ?? now
            let nextMonday = cal.date(byAdding: .day, value: 7, to: monday) ?? now
            return (cal.startOfDay(for: monday), nextMonday)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? now
            let nextMonth = cal.date(byAdding: .month, value: 1, to: start) ?? now
            return (start, nextMonth)
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = cal.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .custom:
            let start = cal.startOfDay(for: customStart)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEnd)) ?? customEnd
            return (start, end)
        }
    }
    
    public func contains(date: Date, customStart: Date, customEnd: Date) -> Bool {
        let (s, e) = dateInterval(customStart: customStart, customEnd: customEnd)
        if let start = s, date < start { return false }
        if let end = e, date >= end { return false }
        return true
    }
}

// MARK: - 主视图：个人中心 - 数据统计

public struct MyStatsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    // 1. 知识点统计时间范围
    @State private var sopTimeRange: StatsTimeRange = .all
    @State private var sopCustomStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var sopCustomEndDate: Date = Date()
    @State private var showSopCustomDatePicker: Bool = false
    @State private var showSopDetailSheet: Bool = false
    
    // 2. 精益求精深度案例统计时间范围
    @State private var jingYiTimeRange: StatsTimeRange = .all
    @State private var jingYiCustomStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var jingYiCustomEndDate: Date = Date()
    @State private var showJingYiCustomDatePicker: Bool = false
    @State private var showJingYiDetailSheet: Bool = false
    
    // 详细信息弹窗与查看
    @State private var showScoreRulesSheet: Bool = false
    
    public init() {}
    
    // 当前登录用户创建的「知识点」文章
    private var allMySOPArticles: [SharedKnowledgeArticle] {
        let currentUserName = store.currentUser.name
        return store.knowledgeArticles.filter { $0.author == currentUserName && $0.kind == .standardSOP }
    }
    
    private var filteredMySOPArticles: [SharedKnowledgeArticle] {
        let range = sopTimeRange
        let start = sopCustomStartDate
        let end = sopCustomEndDate
        return allMySOPArticles.filter { article in
            range.contains(date: article.createdAt, customStart: start, customEnd: end)
        }
    }
    
    // 当前登录用户创建的「精益求精」深度案例
    private var allMyJingYiArticles: [SharedKnowledgeArticle] {
        let currentUserName = store.currentUser.name
        return store.knowledgeArticles.filter { $0.author == currentUserName && $0.kind == .jingYiQiuJing }
    }
    
    private var filteredMyJingYiArticles: [SharedKnowledgeArticle] {
        let range = jingYiTimeRange
        let start = jingYiCustomStartDate
        let end = jingYiCustomEndDate
        return allMyJingYiArticles.filter { article in
            range.contains(date: article.createdAt, customStart: start, customEnd: end)
        }
    }
    
    private var sopRangeDescriptionText: String {
        rangeDescription(range: sopTimeRange, customStart: sopCustomStartDate, customEnd: sopCustomEndDate)
    }
    
    private var jingYiRangeDescriptionText: String {
        rangeDescription(range: jingYiTimeRange, customStart: jingYiCustomStartDate, customEnd: jingYiCustomEndDate)
    }
    
    private func rangeDescription(range: StatsTimeRange, customStart: Date, customEnd: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        switch range {
        case .all:
            return "全部历史周期"
        case .thisWeek:
            return "本周（周一至周日）"
        case .thisMonth:
            return "本自然月"
        case .last30Days:
            return "近 30 天"
        case .last90Days:
            return "近 90 天"
        case .custom:
            return "\(df.string(from: customStart)) 至 \(df.string(from: customEnd))"
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏信息与身份
            topHeaderBar
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 内容网格滚动画布
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // ==========================================
                    // 第一区域：个人贡献看板
                    // ==========================================
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("个人贡献看板")
                                    .font(.system(size: 15, weight: .bold))
                                Text("追踪统计您在工作台中的知识沉淀、协同互助与日常履约指标")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        // 自适应网格布局：每列最小 370pt，支持多列与等高 240pt 卡片
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 370), spacing: 18)
                        ], spacing: 18) {
                            // 1. 我分享的知识点
                            myKnowledgeStatsCard
                            
                            // 2. 我分享的精益求精
                            myJingYiStatsCard
                            
                            // 3. 案例协助统计 (预留卡片，后续迭代)
                            caseAssistancePlaceholderCard
                        }
                    }
                    
                    // ==========================================
                    // 第二区域：影响力指数
                    // ==========================================
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 14, weight: .bold))
                                    Text("影响力指数")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Text("基于知识点沉淀、精益求精案例赋能与团队协同互助综合测算个人影响力与荣誉等级")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        // 知识影响力与互助指数横向舒展卡片
                        influenceAndMutualHelpCard
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSopDetailSheet) {
            KnowledgeStatsDetailSheet(
                articles: filteredMySOPArticles,
                timeRangeDescription: sopRangeDescriptionText
            )
        }
        .sheet(isPresented: $showJingYiDetailSheet) {
            JingYiStatsDetailSheet(
                articles: filteredMyJingYiArticles,
                timeRangeDescription: jingYiRangeDescriptionText
            )
        }
        .sheet(isPresented: $showSopCustomDatePicker) {
            CustomDateRangePickerModal(
                title: "选择知识点自定义统计时间范围",
                startDate: $sopCustomStartDate,
                endDate: $sopCustomEndDate,
                isPresented: $showSopCustomDatePicker
            )
        }
        .sheet(isPresented: $showJingYiCustomDatePicker) {
            CustomDateRangePickerModal(
                title: "选择精益求精自定义统计时间范围",
                startDate: $jingYiCustomStartDate,
                endDate: $jingYiCustomEndDate,
                isPresented: $showJingYiCustomDatePicker
            )
        }
        .sheet(isPresented: $showScoreRulesSheet) {
            ScoreRulesSheet()
        }
    }
    
    // MARK: - 1. 顶栏
    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("数据统计")
                    .font(.system(size: 17, weight: .bold))
                Text("当前成员：\(store.currentUser.name) · 实时数据分析")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 2. 「我分享的知识点」统计卡片 (固定 240pt 高度)
    private var myKnowledgeStatsCard: some View {
        let totalCount: Int = filteredMySOPArticles.count
        var totalHelpful: Int = 0
        for art in filteredMySOPArticles {
            totalHelpful += art.helpfulUserNames.count
        }
        var totalComments: Int = 0
        for art in filteredMySOPArticles {
            totalComments += art.comments.count
        }
        let pinnedCount: Int = filteredMySOPArticles.filter { $0.isPinned }.count
        
        return VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "book.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("我分享的知识点")
                            .font(.system(size: 14, weight: .bold))
                        Text(sopRangeDescriptionText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 时间段筛选下拉菜单
                Menu {
                    ForEach(StatsTimeRange.allCases) { range in
                        Button {
                            sopTimeRange = range
                            if range == .custom {
                                showSopCustomDatePicker = true
                            }
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if sopTimeRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10.5))
                        Text(sopTimeRange.rawValue)
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.blue.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical, 1)
            
            // 核心统计指标区
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(totalCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("篇知识点")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 辅助数据徽章
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.orange)
                        Text("获赞 \(totalHelpful)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.teal)
                        Text("讨论 \(totalComments)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if pinnedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("置顶 \(pinnedCount)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // 品类细分分布标签
            sopCategoryBreakdownPills
            
            Spacer(minLength: 6)
            
            Divider()
                .padding(.vertical, 1)
            
            // 底栏：“详细信息” 按钮与引导
            HStack {
                Text(totalCount > 0 ? "查看此时间段内沉淀的知识点清单与明细" : "暂未在该时间段内沉淀知识点")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showSopDetailSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("详细信息")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(height: 240)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 知识点品类分布胶囊列表
    private var sopCategoryBreakdownPills: some View {
        let categories = KnowledgeCategory.selectableCases
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { cat in
                    let count = filteredMySOPArticles.filter { $0.category == cat }.count
                    if count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 9))
                            Text(cat.rawValue)
                                .font(.system(size: 10.5, weight: .medium))
                            Text("\(count)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(cat.themeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(cat.themeColor.opacity(0.10))
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }
    
    // MARK: - 3. 「我分享的精益求精」全新统计卡片 (固定 240pt 高度)
    private var myJingYiStatsCard: some View {
        let totalCount: Int = filteredMyJingYiArticles.count
        var totalHelpful: Int = 0
        for art in filteredMyJingYiArticles {
            totalHelpful += art.helpfulUserNames.count
        }
        var totalComments: Int = 0
        for art in filteredMyJingYiArticles {
            totalComments += art.comments.count
        }
        let mailedCount: Int = filteredMyJingYiArticles.filter { $0.hasSentGroupMail }.count
        let pinnedCount: Int = filteredMyJingYiArticles.filter { $0.isPinned }.count
        
        return VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                            .frame(width: 32, height: 32)
                        Image(systemName: "flame.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("我分享的精益求精")
                                .font(.system(size: 14, weight: .bold))
                            Text("深度案例")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Text(jingYiRangeDescriptionText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 时间段筛选下拉菜单
                Menu {
                    ForEach(StatsTimeRange.allCases) { range in
                        Button {
                            jingYiTimeRange = range
                            if range == .custom {
                                showJingYiCustomDatePicker = true
                            }
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if jingYiTimeRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10.5))
                        Text(jingYiTimeRange.rawValue)
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical, 1)
            
            // 核心统计指标区
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(totalCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("篇深度案例")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 辅助数据徽章
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.orange)
                        Text("获赞 \(totalHelpful)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.teal)
                        Text("讨论 \(totalComments)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if mailedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("已发邮件 \(mailedCount)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if pinnedCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("置顶 \(pinnedCount)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // 品类细分分布标签
            jingYiCategoryBreakdownPills
            
            Spacer(minLength: 6)
            
            Divider()
                .padding(.vertical, 1)
            
            // 底栏：“详细信息” 按钮与引导
            HStack {
                Text(totalCount > 0 ? "查看此时间段内沉淀的精益求精深度排查案例明细" : "暂未在该时间段内沉淀精益求精案例")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    showJingYiDetailSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("详细信息")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.14))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(height: 240)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 精益求精品类分布胶囊列表
    private var jingYiCategoryBreakdownPills: some View {
        let categories = KnowledgeCategory.selectableCases
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { cat in
                    let count = filteredMyJingYiArticles.filter { $0.category == cat }.count
                    if count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 9))
                            Text(cat.rawValue)
                                .font(.system(size: 10.5, weight: .medium))
                            Text("\(count)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(cat.themeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(cat.themeColor.opacity(0.10))
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }
    
    // MARK: - 4. 预留卡片：案例协助统计 (后续开发)
    private var caseAssistancePlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.teal.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.teal)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("案例协助统计")
                            .font(.system(size: 14, weight: .bold))
                        Text("即将上线 · 疑难案例团队求助与协同统计")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("规划中")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.teal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.teal.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Divider()
                .padding(.vertical, 1)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("0")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("后续案例协助版块上线后，将在此自动汇总统筹您发起的求助、协同协助排查及采纳率指标。")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            
            Spacer(minLength: 6)
            
            Divider()
                .padding(.vertical, 1)
            
            HStack {
                Text("待案例协助模块投产后自动激活")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
            }
        }
        .padding(18)
        .frame(height: 240)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 5. 核心卡片：知识影响力与互助指数实时看板 (横向舒展大卡片)
    private var influenceAndMutualHelpCard: some View {
        let myName = store.currentUser.name
        let mySOPArticles = store.knowledgeArticles.filter { $0.author == myName && $0.kind == .standardSOP }
        let myJingYiArticles = store.knowledgeArticles.filter { $0.author == myName && $0.kind == .jingYiQiuJing }
        let myAllArticles = mySOPArticles + myJingYiArticles
        
        var helpfulLikesReceived: Int = 0
        for art in myAllArticles {
            helpfulLikesReceived += art.helpfulUserNames.count
        }
        var commentsReceived: Int = 0
        for art in myAllArticles {
            commentsReceived += art.comments.count
        }
        let pinnedCount: Int = myAllArticles.filter { $0.isPinned }.count
        
        // 互助协同：在他人知识点或精益求精下发表经验补充（+5分/条）、给同事点赞认可（+2分/次）
        var commentsGiven: Int = 0
        for art in store.knowledgeArticles where art.author != myName {
            let count = art.comments.filter { $0.author == myName }.count
            commentsGiven += count
        }
        var helpfulGiven: Int = 0
        for art in store.knowledgeArticles where art.author != myName {
            if art.helpfulUserNames.contains(myName) {
                helpfulGiven += 1
            }
        }
        
        // 综合积分计算：
        // 影响力得分 = (知识点×5) + (精益求精×15) + (置顶×10) + (点赞×3) + (讨论×1)
        let sopPoints: Int = mySOPArticles.count * 5
        let jingYiPoints: Int = myJingYiArticles.count * 15
        let pinPoints: Int = pinnedCount * 10
        let likePoints: Int = helpfulLikesReceived * 3
        let commentPoints: Int = commentsReceived * 1
        let influenceScore: Int = sopPoints + jingYiPoints + pinPoints + likePoints + commentPoints
        
        let mutualCommentPoints: Int = commentsGiven * 5
        let mutualLikePoints: Int = helpfulGiven * 2
        let mutualHelpScore: Int = mutualCommentPoints + mutualLikePoints
        let totalScore: Int = influenceScore + mutualHelpScore
        
        let (badgeTitle, badgeIcon, badgeColor): (String, String, Color) = {
            if totalScore >= 1200 {
                return ("知识导师", "crown.fill", .purple)
            } else if totalScore >= 600 {
                return ("业务骨干", "star.fill", .orange)
            } else if totalScore >= 200 {
                return ("经验伙伴", "hands.sparkles.fill", .blue)
            } else {
                return ("团队新锐", "leaf.fill", .green)
            }
        }()
        
        let (currentBase, targetPoints): (Int, Int) = {
            if totalScore < 200 {
                return (0, 200)
            } else if totalScore < 600 {
                return (200, 600)
            } else if totalScore < 1200 {
                return (600, 1200)
            } else {
                return (1200, 1200)
            }
        }()
        
        let progress: Double = {
            if targetPoints == currentBase { return 1.0 }
            let span = Double(targetPoints - currentBase)
            let curr = Double(max(0, totalScore - currentBase))
            return min(1.0, max(0.0, curr / span))
        }()
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(badgeColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15))
                            .foregroundColor(badgeColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("知识影响力与互助指数")
                            .font(.system(size: 14, weight: .bold))
                        Text("基于知识点沉淀、精益求精案例赋能、跨组互助与团队响应度综合测算个人影响力与荣誉成长")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 等级徽章
                HStack(spacing: 5) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 11))
                    Text(badgeTitle)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())
                
                Button(action: {
                    showScoreRulesSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                        Text("计算规则")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical, 1)
            
            // Content Row (Left: Big Score + Progress; Middle: Sub-scores; Right: 5 Metric Badges)
            HStack(spacing: 16) {
                // Left Block: 综合积分 + 晋级提示 + 进度条
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(totalScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("综合积分")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(upgradeHintText(totalScore: totalScore))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.14))
                                .frame(height: 5)
                            Capsule()
                                .fill(LinearGradient(colors: [badgeColor.opacity(0.7), badgeColor], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(5, geo.size.width * CGFloat(progress)), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(width: 195, alignment: .leading)
                
                Divider()
                    .frame(height: 52)
                
                // Middle Block: 两个维度的分值拆解
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("影响力得分")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Text("\(influenceScore)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                        }
                        Text("知识点+精益求精+获赞+置顶")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("互助度得分")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Text("\(mutualHelpScore)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        Text("讨论补充+认同点赞")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer(minLength: 8)
                
                // Right Block: 指标卡片 (自适应单行/双行排布，绝不纵向变形拉伸)
                ViewThatFits(in: .horizontal) {
                    // 1. 全屏宽屏模式：单行 5 个徽章并排展示
                    HStack(spacing: 6) {
                        metricBadgeCard(icon: "book.fill", color: .blue, title: "知识点", value: "\(mySOPArticles.count) 篇")
                        metricBadgeCard(icon: "flame.circle.fill", color: .orange, title: "精益求精", value: "\(myJingYiArticles.count) 篇")
                        metricBadgeCard(icon: "pin.fill", color: .red, title: "精品置顶", value: "\(pinnedCount) 篇")
                        metricBadgeCard(icon: "hand.thumbsup.fill", color: .yellow, title: "获赞认可", value: "\(helpfulLikesReceived) 次")
                        metricBadgeCard(icon: "bubble.left.and.bubble.right.fill", color: .teal, title: "参与讨论", value: "\(commentsReceived + commentsGiven) 次")
                    }
                    
                    // 2. 非全屏/收窄模式：紧凑双行右对齐展示 (行1: 原创沉淀; 行2: 互动互助)
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 6) {
                            metricBadgeCard(icon: "book.fill", color: .blue, title: "知识点", value: "\(mySOPArticles.count) 篇")
                            metricBadgeCard(icon: "flame.circle.fill", color: .orange, title: "精益求精", value: "\(myJingYiArticles.count) 篇")
                            metricBadgeCard(icon: "pin.fill", color: .red, title: "精品置顶", value: "\(pinnedCount) 篇")
                        }
                        HStack(spacing: 6) {
                            metricBadgeCard(icon: "hand.thumbsup.fill", color: .yellow, title: "获赞认可", value: "\(helpfulLikesReceived) 次")
                            metricBadgeCard(icon: "bubble.left.and.bubble.right.fill", color: .teal, title: "参与讨论", value: "\(commentsReceived + commentsGiven) 次")
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func metricBadgeCard(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11.5))
            }
            
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private func upgradeHintText(totalScore: Int) -> String {
        if totalScore < 200 {
            return "距离晋升「经验伙伴」还需 \(200 - totalScore) 积分"
        } else if totalScore < 600 {
            return "距离晋升「业务骨干」还需 \(600 - totalScore) 积分"
        } else if totalScore < 1200 {
            return "距离荣登「知识导师」还需 \(1200 - totalScore) 积分"
        } else {
            return "🎉 您已荣膺团队最高荣誉「知识导师」称号！"
        }
    }
}

// MARK: - 自定义时间范围弹窗模态窗

public struct CustomDateRangePickerModal: View {
    public let title: String
    @Binding public var startDate: Date
    @Binding public var endDate: Date
    @Binding public var isPresented: Bool
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("完成") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Divider()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("起始日期")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("结束日期")
                        .font(.system(size: 12, weight: .medium))
                    DatePicker("", selection: $endDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }
        }
        .padding(20)
        .frame(width: 580)
    }
}

// MARK: - 「详细信息」知识点明细弹窗清单

public struct KnowledgeStatsDetailSheet: View {
    public let articles: [SharedKnowledgeArticle]
    public let timeRangeDescription: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var filterQuery: String = ""
    @State private var viewingArticle: SharedKnowledgeArticle? = nil
    
    private var displayArticles: [SharedKnowledgeArticle] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return articles }
        return articles.filter {
            $0.title.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }
    
    public var body: some View {
        Group {
            if let article = viewingArticle {
                KnowledgeArticleDetailContainerView(
                    article: article,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewingArticle = nil
                        }
                    },
                    onClose: {
                        dismiss()
                    }
                )
            } else {
                listView
            }
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 480, idealHeight: 540)
    }
    
    private var listView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        Text("我分享的知识点清单 (\(articles.count) 篇)")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("统计时间范围：\(timeRangeDescription)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search / Filter inside modal
            if articles.count > 4 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("在此列表中过滤标题或标签...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !filterQuery.isEmpty {
                        Button { filterQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // List Content
            if articles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "book.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("该时间范围内暂未分享任何知识点")
                        .font(.system(size: 14, weight: .medium))
                    Text("可在「互帮互助 > 共享知识库 > 知识点」右上角点击新建文章发布您的实操经验。")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(displayArticles.enumerated()), id: \.element.id) { index, article in
                            HStack(alignment: .center, spacing: 12) {
                                // Index Number
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                // Category Badge
                                HStack(spacing: 4) {
                                    Image(systemName: article.category.icon)
                                        .font(.system(size: 9))
                                    Text(article.category.rawValue)
                                        .font(.system(size: 10.5, weight: .bold))
                                }
                                .foregroundColor(article.category.themeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(article.category.themeColor.opacity(0.10))
                                .clipShape(Capsule())
                                
                                // Title & Tags
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        if article.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.orange)
                                        }
                                        Text(article.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    if !article.tags.isEmpty {
                                        Text(article.tags.map { "#\($0)" }.joined(separator: " "))
                                            .font(.system(size: 10.5))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                // Stats: Likes & Comments
                                HStack(spacing: 10) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .font(.system(size: 9))
                                        Text("\(article.helpfulUserNames.count)")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.orange)
                                    
                                    HStack(spacing: 3) {
                                        Image(systemName: "bubble.left.fill")
                                            .font(.system(size: 9))
                                        Text("\(article.comments.count)")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.teal)
                                }
                                
                                // Creation Date
                                Text(formatDate(article.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                                
                                // Preview Action (直接就地展开预览，无需先关闭当前弹窗)
                                Button("查看") {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        viewingArticle = article
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 「详细信息」精益求精深度案例明细弹窗清单

public struct JingYiStatsDetailSheet: View {
    public let articles: [SharedKnowledgeArticle]
    public let timeRangeDescription: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var filterQuery: String = ""
    @State private var viewingArticle: SharedKnowledgeArticle? = nil
    
    private var displayArticles: [SharedKnowledgeArticle] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return articles }
        return articles.filter {
            $0.title.lowercased().contains(q) ||
            $0.caseId.lowercased().contains(q) ||
            $0.deviceAndOS.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.lowercased().contains(q) }) ||
            $0.referenceArticles.contains(where: { $0.title.lowercased().contains(q) || $0.urlOrCoreId.lowercased().contains(q) })
        }
    }
    
    public var body: some View {
        Group {
            if let article = viewingArticle {
                KnowledgeArticleDetailContainerView(
                    article: article,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewingArticle = nil
                        }
                    },
                    onClose: {
                        dismiss()
                    }
                )
            } else {
                listView
            }
        }
        .frame(minWidth: 680, idealWidth: 740, minHeight: 480, idealHeight: 540)
    }
    
    private var listView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                        Text("我分享的精益求精案例清单 (\(articles.count) 篇)")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("统计时间范围：\(timeRangeDescription)")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search / Filter inside modal
            if articles.count > 4 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("在此列表中过滤案例号、机型、标题或标签...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !filterQuery.isEmpty {
                        Button { filterQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // List Content
            if articles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "flame.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text("该时间范围内暂未分享任何精益求精案例")
                        .font(.system(size: 14, weight: .medium))
                    Text("可在「互帮互助 > 共享知识库 > 精益求精」右上角点击编写深度案例。")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(displayArticles.enumerated()), id: \.element.id) { index, article in
                            HStack(alignment: .center, spacing: 12) {
                                // Index Number
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                // Category Badge
                                HStack(spacing: 4) {
                                    Image(systemName: article.category.icon)
                                        .font(.system(size: 9))
                                    Text(article.category.rawValue)
                                        .font(.system(size: 10.5, weight: .bold))
                                }
                                .foregroundColor(article.category.themeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(article.category.themeColor.opacity(0.10))
                                .clipShape(Capsule())
                                
                                // Case ID & Title & Device info
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        if !article.caseId.isEmpty {
                                            Text(article.caseId)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Color.orange.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                        
                                        if article.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Text(article.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        if !article.deviceAndOS.isEmpty {
                                            Text(article.deviceAndOS)
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        if !article.tags.isEmpty {
                                            Text(article.tags.map { "#\($0)" }.joined(separator: " "))
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Status & Badges
                                HStack(spacing: 10) {
                                    if article.hasSentGroupMail {
                                        HStack(spacing: 3) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 9.5))
                                            Text("已发群组")
                                                .font(.system(size: 10.5, weight: .medium))
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.08))
                                        .clipShape(Capsule())
                                    }
                                    
                                    if !article.screenshotsBase64.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "photo.stack.fill")
                                                .font(.system(size: 9.5))
                                            Text("\(article.screenshotsBase64.count)图")
                                                .font(.system(size: 10.5, weight: .medium))
                                        }
                                        .foregroundColor(.teal)
                                    }
                                    
                                    HStack(spacing: 3) {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .font(.system(size: 9))
                                        Text("\(article.helpfulUserNames.count)")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.orange)
                                    
                                    HStack(spacing: 3) {
                                        Image(systemName: "bubble.left.fill")
                                            .font(.system(size: 9))
                                        Text("\(article.comments.count)")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.teal)
                                }
                                
                                // Creation Date
                                Text(formatDate(article.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                                
                                // Preview Action (直接就地展开预览，无需先关闭当前弹窗)
                                Button("查看") {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        viewingArticle = article
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 知识点与精益求精深度查阅容器组件 (支持返回、就地查阅、原图高清浮层放大)

public struct KnowledgeArticleDetailContainerView: View {
    public let article: SharedKnowledgeArticle
    public let onBack: () -> Void
    public let onClose: () -> Void
    
    @State private var zoomImageData: ZoomableImageData? = nil
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("返回清单")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(article.kind.themeColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(article.kind.themeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 18)
                
                // Kind badge
                HStack(spacing: 4) {
                    Image(systemName: article.kind.icon)
                        .font(.system(size: 10))
                    Text(article.kind.rawValue)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(article.kind.themeColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(article.kind.themeColor.opacity(0.12))
                .clipShape(Capsule())
                
                // Category badge
                HStack(spacing: 4) {
                    Image(systemName: article.category.icon)
                        .font(.system(size: 10))
                    Text(article.category.rawValue)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(article.category.themeColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(article.category.themeColor.opacity(0.12))
                .clipShape(Capsule())
                
                if !article.caseId.isEmpty {
                    Text(article.caseId)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Text(article.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .lineLimit(1)
                
                Spacer()
                
                if article.hasSentGroupMail {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 9.5))
                        Text("群组已发")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(Capsule())
                }
                
                Button("关闭") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 设备机型与系统
                    if !article.deviceAndOS.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "display")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("涉及机型与系统：\(article.deviceAndOS)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // 摘要
                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.system(size: 12.5, design: .serif))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    // 精益求精专属深度字段：故障背景
                    if article.kind == .jingYiQiuJing && !article.faultBackground.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.book.closed.fill")
                                    .foregroundColor(.orange)
                                Text("一、故障背景 (Background)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            Text(article.faultBackground)
                                .font(.system(size: 12.5))
                                .lineSpacing(4)
                                .foregroundColor(.primary.opacity(0.92))
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // 精益求精专属深度字段：排查思路
                    if article.kind == .jingYiQiuJing && !article.troubleshootingLogic.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.max.fill")
                                    .foregroundColor(.purple)
                                Text("二、排查思路")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            Text(article.troubleshootingLogic)
                                .font(.system(size: 12.5))
                                .lineSpacing(4)
                                .foregroundColor(.primary.opacity(0.92))
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // 解决方案 (SOP 与 精益求精共用)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text(article.kind == .jingYiQiuJing ? "三、解决方案" : "解决方案")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Text(article.solution)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 避坑贴士
                    if !article.keyTips.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("避坑贴士")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.red)
                            ForEach(article.keyTips, id: \.self) { tip in
                                Text("• \(tip)")
                                    .font(.system(size: 12))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // 精益求精相关截图
                    if article.kind == .jingYiQiuJing && !article.screenshotsBase64.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.stack.fill")
                                    .foregroundColor(.teal)
                                Text("四、相关截图 (\(article.screenshotsBase64.count) 张)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.teal)
                                Spacer()
                                Text("点击查看高清大图")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                                ForEach(Array(article.screenshotsBase64.enumerated()), id: \.offset) { _, base64 in
                                    if let imgData = Data(base64Encoded: base64), let nsImg = NSImage(data: imgData) {
                                        Button {
                                            zoomImageData = ZoomableImageData(data: imgData)
                                        } label: {
                                            Image(nsImage: nsImg)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 80)
                                                .clipped()
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.teal.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // 参考文章
                    if !article.referenceArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.indigo)
                                Text("五、参考文章 (\(article.referenceArticles.count) 篇)")
                                    .font(.system(size: 13, weight: .bold))
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
                                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                            .onHover { inside in
                                                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                            }
                                            .help("点击唤起 Core 知识库 (\(ref.urlOrCoreId))")
                                            
                                            if !ref.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Text(ref.title)
                                                    .font(.system(size: 13))
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
                                                    .font(.system(size: 13))
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
                                        .help("复制参考文章链接")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
        }
        .overlay {
            if let zoom = zoomImageData {
                ScreenshotZoomOverlay(data: zoom.data) {
                    zoomImageData = nil
                }
            }
        }
    }
}

// MARK: - 截图原图高清放大覆盖层 (无需依赖额外弹窗，就地无缝查看)

public struct ScreenshotZoomOverlay: View {
    public let data: Data
    public let onClose: () -> Void
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.white)
                        Text("排查佐证原图查看")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                
                if let nsImg = NSImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                    }
                }
            }
        }
    }
}

// MARK: - 知识点与精益求精快速查阅弹窗 (兼容独立调起)

public struct KnowledgeArticlePreviewModal: View {
    public let article: SharedKnowledgeArticle
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        KnowledgeArticleDetailContainerView(
            article: article,
            onBack: {
                dismiss()
            },
            onClose: {
                dismiss()
            }
        )
        .frame(minWidth: 640, idealWidth: 700, minHeight: 480, idealHeight: 540)
    }
}

// MARK: - 知识影响力与互助评分规则弹窗

public struct ScoreRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("知识影响力与互助指数计算规则")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .padding(.top, 4)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. 维度一
                    VStack(alignment: .leading, spacing: 8) {
                        Text("一、知识影响力（沉淀价值）")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.purple)
                        
                        ruleRow(title: "原创知识点沉淀", points: "+5 分 / 条", desc: "在「共享知识库」中成功发布一篇原创常规知识点规程")
                        ruleRow(title: "精益求精深度案例", points: "+15 分 / 篇", desc: "在「共享知识库」中成功沉淀包含故障背景、排查思路、方案、截图与参考文章的深度案例")
                        ruleRow(title: "精品置顶加权", points: "+10 分 / 篇", desc: "文章被管理员置顶为全组推荐知识")
                        ruleRow(title: "同事点赞认可", points: "+3 分 / 人次", desc: "组员在您的知识点或精益求精案例下点击「觉得有帮助」")
                        ruleRow(title: "引发团队讨论", points: "+1 分 / 条", desc: "您的知识文章下收到组员留下的实操经验补充与探讨")
                    }
                    .padding(14)
                    .background(Color.purple.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 2. 维度二
                    VStack(alignment: .leading, spacing: 8) {
                        Text("二、互助参与度（协同贡献）")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ruleRow(title: "补充他人经验", points: "+5 分 / 条", desc: "在其他组员分享的知识文章下发表实战补充建议")
                        ruleRow(title: "认同肯定同伴", points: "+2 分 / 次", desc: "为其他同事优质的知识文章送出「觉得有帮助」点赞")
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 3. 等级对照
                    VStack(alignment: .leading, spacing: 8) {
                        Text("三、团队荣誉称号等级")
                            .font(.system(size: 13.5, weight: .bold))
                        
                        HStack(spacing: 8) {
                            rankPill(title: "团队新锐", range: "0 ~ 199分", color: .green, icon: "leaf.fill")
                            rankPill(title: "经验伙伴", range: "200 ~ 599分", color: .blue, icon: "hands.sparkles.fill")
                            rankPill(title: "业务骨干", range: "600 ~ 1199分", color: .orange, icon: "star.fill")
                            rankPill(title: "知识导师", range: "1200分以上", color: .purple, icon: "crown.fill")
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(22)
        .frame(width: 540, height: 500)
    }
    
    private func ruleRow(title: String, points: String, desc: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(points)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private func rankPill(title: String, range: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
            Text(range)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
