//
//  ShiftsView.swift
//  团队工作台
//
//

import SwiftUI
import AppKit
import WebKit

public struct ShiftsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var shiftsSync = ShiftsSyncService.shared
    
    @State private var currentWeekOffset: Int = 0
    @State private var showAutoSyncWebSheet: Bool = false
    @State private var showExportSuccessAlert: Bool = false
    @State private var showSyncResultAlert: Bool = false
    @State private var syncResultAlertMessage: String = ""
    @State private var selectedDayStr: String?
    @State private var currentLiveWebView: WKWebView? = nil
    @State private var autoSyncTimer: Timer? = nil
    
    public init() {}
    
    // Calculate Monday of the selected week
    private var mondayOfSelectedWeek: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Monday
        let monday = cal.date(from: comps) ?? Date()
        return cal.date(byAdding: .weekOfYear, value: currentWeekOffset, to: monday) ?? monday
    }
    
    private var shiftsTargetURL: URL {
        let cal = Calendar.current
        let year = cal.component(.year, from: mondayOfSelectedWeek)
        let month = cal.component(.month, from: mondayOfSelectedWeek)
        let day = cal.component(.day, from: mondayOfSelectedWeek)
        return URL(string: "https://shifts.apple.com/#/LQGMZGMDA/list/\(year)/\(month)/\(day)") ?? URL(string: "https://shifts.apple.com")!
    }
    
    // Generate 7 days for the selected week
    private var daysInSelectedWeek: [Date] {
        let cal = Calendar.current
        let monday = mondayOfSelectedWeek
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }
    
    private var weekRangeTitle: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy年MM月dd日"
        let start = df.string(from: daysInSelectedWeek.first ?? Date())
        df.dateFormat = "MM月dd日"
        let end = df.string(from: daysInSelectedWeek.last ?? Date())
        return "\(start) - \(end)"
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Bar
            topHeaderBar
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // 2. Main Schedule Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Week Statistics Card
                    weekSummaryStatsBar
                    
                    // 7-Day Visual Schedule Grid
                    weekDaysGrid
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            store.loadShiftSchedule(for: store.currentUser.name)
            if selectedDayStr == nil {
                selectedDayStr = store.todayDateString
            }
        }
        .sheet(isPresented: $showAutoSyncWebSheet) {
            shiftsAutoSyncSheetView
        }
        .alert("日历导入成功", isPresented: $showExportSuccessAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("已成功生成并唤起 macOS「日历」App，您的班表与作息时间已加入系统日程。")
        }
        .alert("班表拉取结果", isPresented: $showSyncResultAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text(syncResultAlertMessage)
        }
    }
    
    // MARK: - 1. Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("我的班表日历")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(store.currentUser.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("直连 Apple Shifts (shifts.apple.com)，一键拉取个人排班并同步至 Mac 原生日历")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Week Navigator Controls
            HStack(spacing: 6) {
                Button(action: { currentWeekOffset -= 1 }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(6)
                }
                .buttonStyle(.plain)
                
                Text(weekRangeTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.horizontal, 8)
                
                Button(action: { currentWeekOffset += 1 }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(6)
                }
                .buttonStyle(.plain)
                
                if currentWeekOffset != 0 {
                    Button("本周") {
                        currentWeekOffset = 0
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Action Buttons
            Button(action: {
                showAutoSyncWebSheet = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "safari.fill")
                        .foregroundColor(.blue)
                    Text("网页拉取 Shifts")
                }
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("直连 Apple Shifts (shifts.apple.com) 自动提取本周排班")
            
            Button(action: {
                importFromClipboard()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.green)
                    Text("剪贴板一键拉取")
                }
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("在 Shifts 页面全选复制后，点击此按钮可 0.01 秒极速导入全周排班")
            
            // Share to Team Toggle Button
            let isShared = store.currentMemberShiftSchedule.isSharedToTeam
            Button(action: {
                store.toggleShareScheduleToTeam(isShared: !isShared)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isShared ? "person.2.fill" : "person.2")
                        .foregroundColor(isShared ? .green : .accentColor)
                    Text(isShared ? "已分享至团队" : "分享至团队班表")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isShared ? .green : .primary)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(isShared ? "当前排班已公开至「团队共享 > 团队班表」，点击可取消分享并恢复为个人私有" : "点击将当前本周排班分享至「团队共享 > 团队班表」，方便全组查看在岗与换班")
            
            Button(action: {
                if store.currentMemberShiftSchedule.exportToCalendarApp() {
                    showExportSuccessAlert = true
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.plus")
                    Text("同步到 Mac 日历")
                }
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    // MARK: - 2. Week Summary Statistics
    
    private var weekSummaryStatsBar: some View {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        let weekDatesStr = Set(daysInSelectedWeek.map { df.string(from: $0) })
        let weekShifts = store.currentMemberShiftSchedule.days.filter { weekDatesStr.contains($0.dateStr) }
        
        let workDays = weekShifts.filter { !$0.isOff }.count
        let offDays = 7 - workDays
        
        return HStack(spacing: 14) {
            statBadge(title: "本周出勤", value: "\(workDays) 天", color: .blue, icon: "briefcase.fill")
            statBadge(title: "本周休假", value: "\(offDays) 天", color: .orange, icon: "sun.max.fill")
            statBadge(title: "专属归属", value: store.currentUser.name, color: .purple, icon: "person.fill")
            
            Spacer()
            
            Text("提示：点击「一键拉取 Shifts」可直连提取；亦可使用「同步到 Mac 日历」将排班加入系统日程")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private func statBadge(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 3. 7-Day Visual Schedule Grid
    
    private var weekDaysGrid: some View {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = store.todayDateString
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
            ForEach(daysInSelectedWeek, id: \.self) { date in
                let dateStr = df.string(from: date)
                let isToday = (dateStr == todayStr)
                let dayShift = store.currentMemberShiftSchedule.days.first(where: { $0.dateStr == dateStr })
                
                dayCardView(date: date, dateStr: dateStr, isToday: isToday, shift: dayShift)
            }
        }
    }
    
    private func dayCardView(date: Date, dateStr: String, isToday: Bool, shift: DayShift?) -> some View {
        let cal = Calendar.current
        let dayNum = cal.component(.day, from: date)
        let weekday = weekdayName(for: date)
        let isOff = shift?.isOff ?? false
        let hasData = (shift != nil)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Card Header (Date + Weekday + Today Badge)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekday)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isToday ? .blue : .secondary)
                    
                    Text("\(dayNum)日")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isToday ? .blue : .primary)
                }
                
                Spacer()
                
                if isToday {
                    Text("今天")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            Divider()
            
            // Shift Status Banner
            if !hasData {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无班次")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else if isOff {
                VStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                    Text("Time Off")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else if let s = shift {
                VStack(alignment: .leading, spacing: 8) {
                    // Overall Work Time Pill
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("\(s.workStart) - \(s.workEnd)")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Detailed Timeline Segments
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(s.segments) { seg in
                            timelineSegmentRow(seg)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .frame(minHeight: 280)
        .background(isToday ? Color.blue.opacity(0.04) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isToday ? Color.blue : Color.secondary.opacity(0.14), lineWidth: isToday ? 2 : 1)
        )
    }
    
    private func timelineSegmentRow(_ seg: ShiftSegment) -> some View {
        let (color, icon) = segmentColorAndIcon(seg.type)
        
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                    Text(seg.displayTitle)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(color)
                
                Text("\(seg.startTime) - \(seg.endTime)")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func segmentColorAndIcon(_ type: ShiftSegmentType) -> (Color, String) {
        switch type {
        case .work: return (.blue, "briefcase.fill")
        case .breakFirst, .breakSecond: return (.orange, "cup.and.saucer.fill")
        case .lunch: return (.green, "fork.knife")
        case .training: return (.purple, "book.fill")
        case .meeting: return (.indigo, "person.3.fill")
        case .leave: return (.yellow, "airplane.departure")
        case .off: return (.gray, "sun.max.fill")
        case .other: return (.teal, "clock.fill")
        }
    }
    
    private func weekdayName(for date: Date) -> String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return ""
        }
    }
    
    // MARK: - 4. In-App WebKit Shifts Auto-Sync Sheet
    
    private var shiftsAutoSyncSheetView: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Shifts 班表自动提取器")
                            .font(.system(size: 15, weight: .bold))
                        Text("当前目标: \(weekRangeTitle)")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("在浏览器打开") {
                    NSWorkspace.shared.open(shiftsTargetURL)
                }
                .controlSize(.small)
                
                Button("立即提取当前页面") {
                    if let webView = currentLiveWebView {
                        extractShiftsManually(webView)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: { showAutoSyncWebSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Live Status Banner
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                
                Text("正在自动感知认证并切换到 List 列表视图提取排班... 完成后将自动写入并关闭窗口。")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.08))
            
            // Embedded Live WebKit View
            ShiftsWebKitContainerView(
                url: shiftsTargetURL,
                onDataReceived: { rawText in
                    self.handleAutoExtractedText(rawText)
                },
                webViewRef: $currentLiveWebView
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 920, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            startSwiftAutoPolling()
        }
        .onDisappear {
            stopSwiftAutoPolling()
        }
    }
    
    private func startSwiftAutoPolling() {
        stopSwiftAutoPolling()
        var pollCount = 0
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            pollCount += 1
            guard pollCount >= 2 else { return }
            
            if let webView = currentLiveWebView {
                shiftsSync.extractShiftsFromDOM(webView: webView, targetMonday: mondayOfSelectedWeek) { parsedDays, message, snippet in
                    if let days = parsedDays, !days.isEmpty {
                        let hasRealContent = days.contains { !$0.segments.isEmpty || $0.note.contains("请假") || $0.note.contains("Time Off") }
                        if hasRealContent {
                            stopSwiftAutoPolling()
                            var schedule = store.currentMemberShiftSchedule
                            schedule.memberName = store.currentUser.name
                            schedule.updatedAt = Date()
                            
                            var dayDict: [String: DayShift] = [:]
                            for d in schedule.days {
                                dayDict[d.dateStr] = d
                            }
                            for d in days {
                                dayDict[d.dateStr] = d
                            }
                            schedule.days = dayDict.values.sorted { $0.dateStr < $1.dateStr }
                            store.saveShiftSchedule(schedule)
                            
                            syncResultAlertMessage = "🎉 全自动拉取成功！已为您写入 \(days.count) 天班表数据。"
                            showAutoSyncWebSheet = false
                            showSyncResultAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func stopSwiftAutoPolling() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }
    
    private func extractShiftsManually(_ webView: WKWebView) {
        shiftsSync.extractShiftsFromDOM(webView: webView, targetMonday: mondayOfSelectedWeek) { parsedDays, message, snippet in
            if let days = parsedDays, !days.isEmpty {
                stopSwiftAutoPolling()
                var schedule = store.currentMemberShiftSchedule
                schedule.memberName = store.currentUser.name
                schedule.updatedAt = Date()
                
                var dayDict: [String: DayShift] = [:]
                for d in schedule.days {
                    dayDict[d.dateStr] = d
                }
                for d in days {
                    dayDict[d.dateStr] = d
                }
                schedule.days = dayDict.values.sorted { $0.dateStr < $1.dateStr }
                store.saveShiftSchedule(schedule)
                
                syncResultAlertMessage = "🎉 成功提取并写入 \(days.count) 天班表数据！"
                showAutoSyncWebSheet = false
                showSyncResultAlert = true
            } else {
                syncResultAlertMessage = message
                showSyncResultAlert = true
            }
        }
    }
    
    private func importFromClipboard() {
        if let clip = NSPasteboard.general.string(forType: .string), !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsedDays = shiftsSync.parseShiftsRawText(clip, targetMonday: mondayOfSelectedWeek)
            if !parsedDays.isEmpty {
                var schedule = store.currentMemberShiftSchedule
                schedule.memberName = store.currentUser.name
                schedule.updatedAt = Date()
                
                var dayDict: [String: DayShift] = [:]
                for d in schedule.days {
                    dayDict[d.dateStr] = d
                }
                for d in parsedDays {
                    dayDict[d.dateStr] = d
                }
                schedule.days = dayDict.values.sorted { $0.dateStr < $1.dateStr }
                store.saveShiftSchedule(schedule)
                
                if let firstDay = parsedDays.first(where: { !$0.segments.isEmpty }) {
                    adjustWeekOffsetToInclude(dateStr: firstDay.dateStr)
                }
                
                syncResultAlertMessage = "🎉 剪贴板提取成功！已为您写入 \(parsedDays.count) 天班表数据。"
                showSyncResultAlert = true
                return
            }
        }
        
        syncResultAlertMessage = "未在剪贴板中检测到有效班表。\n\n请在 Shifts 网页全选复制（Cmd+A, Cmd+C），再点击「剪贴板一键拉取」！"
        showSyncResultAlert = true
    }
    
    private func handleAutoExtractedText(_ rawData: String) {
        // 1. Try JSON parsing first (from XHR/Fetch network interceptor)
        var parsedDays = shiftsSync.parseShiftsJSONData(rawData, targetMonday: mondayOfSelectedWeek)
        
        // 2. Fallback to raw text parser
        if parsedDays.isEmpty {
            parsedDays = shiftsSync.parseShiftsRawText(rawData, targetMonday: mondayOfSelectedWeek)
        }
        
        guard !parsedDays.isEmpty else { return }
        
        var schedule = store.currentMemberShiftSchedule
        schedule.memberName = store.currentUser.name
        schedule.updatedAt = Date()
        
        var dayDict: [String: DayShift] = [:]
        for d in schedule.days {
            dayDict[d.dateStr] = d
        }
        for d in parsedDays {
            dayDict[d.dateStr] = d
        }
        schedule.days = dayDict.values.sorted { $0.dateStr < $1.dateStr }
        store.saveShiftSchedule(schedule)
        
        if let firstDay = parsedDays.first(where: { !$0.segments.isEmpty }) {
            adjustWeekOffsetToInclude(dateStr: firstDay.dateStr)
        }
        
        syncResultAlertMessage = "🎉 全自动拉取成功！已为您写入 \(parsedDays.count) 天班表数据。"
        showAutoSyncWebSheet = false
        showSyncResultAlert = true
    }
    
    private func adjustWeekOffsetToInclude(dateStr: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let targetDate = df.date(from: dateStr) else { return }
        
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2
        guard let thisMonday = cal.date(from: comps) else { return }
        
        let targetComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)
        var targetMondayComps = targetComps
        targetMondayComps.weekday = 2
        guard let targetMonday = cal.date(from: targetMondayComps) else { return }
        
        let weeksDiff = cal.dateComponents([.weekOfYear], from: thisMonday, to: targetMonday).weekOfYear ?? 0
        self.currentWeekOffset = weeksDiff
    }
}

// MARK: - WebKit Live View Helper with Automated Script Message Handler

public struct ShiftsWebKitContainerView: NSViewRepresentable {
    public let url: URL
    public let onDataReceived: (String) -> Void
    @Binding public var webViewRef: WKWebView?
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        
        let contentController = WKUserContentController()
        let networkScript = WKUserScript(source: ShiftsSyncService.networkHookScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(networkScript)
        contentController.add(context.coordinator, name: "shiftsLiveContinuousBridge")
        contentController.add(context.coordinator, name: "shiftsHandler")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        self.webViewRef = webView
        webView.load(URLRequest(url: url))
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ShiftsWebKitContainerView
        
        init(_ parent: ShiftsWebKitContainerView) {
            self.parent = parent
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "shiftsLiveContinuousBridge" {
                if let dict = message.body as? [String: Any], let jsonText = dict["data"] as? String {
                    DispatchQueue.main.async {
                        self.parent.onDataReceived(jsonText)
                    }
                } else if let jsonText = message.body as? String {
                    DispatchQueue.main.async {
                        self.parent.onDataReceived(jsonText)
                    }
                }
            } else if message.name == "shiftsHandler", let text = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.onDataReceived(text)
                }
            }
        }
    }
}
