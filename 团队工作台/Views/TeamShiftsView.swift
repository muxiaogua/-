//
//  TeamShiftsView.swift
//  团队工作台
//
//

import SwiftUI

public struct TeamShiftsView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentWeekOffset: Int = 0
    @State private var searchMemberQuery: String = ""
    @State private var selectedFilter: TeamShiftFilter = .all
    @State private var selectedDayDetail: (memberName: String, day: DayShift)? = nil
    
    enum TeamShiftFilter: String, CaseIterable, Identifiable {
        case all = "全部成员"
        case workingToday = "今日在岗"
        case offToday = "今日休假"
        
        var id: String { rawValue }
    }
    
    public init() {}
    
    // Calculate Monday of the selected week
    private var mondayOfSelectedWeek: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Monday
        let monday = cal.date(from: comps) ?? Date()
        return cal.date(byAdding: .weekOfYear, value: currentWeekOffset, to: monday) ?? monday
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
    
    // Filtered team schedules
    private var filteredSchedules: [MemberShiftSchedule] {
        var list = store.teamShiftSchedules
        
        // Always include current user's schedule if they enabled sharing locally
        if store.currentMemberShiftSchedule.isSharedToTeam {
            if !list.contains(where: { $0.memberName == store.currentUser.name }) {
                list.append(store.currentMemberShiftSchedule)
            }
        }
        
        // Search Filter
        let q = searchMemberQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.memberName.lowercased().contains(q) }
        }
        
        // Filter by Today status
        let todayStr = store.todayDateString
        switch selectedFilter {
        case .all:
            break
        case .workingToday:
            list = list.filter { sched in
                let today = sched.days.first(where: { $0.dateStr == todayStr })
                return today != nil && !today!.isOff
            }
        case .offToday:
            list = list.filter { sched in
                let today = sched.days.first(where: { $0.dateStr == todayStr })
                return today == nil || today!.isOff
            }
        }
        
        return list.sorted { s1, s2 in
            let a1 = store.isDefaultAdmin(name: s1.memberName)
            let a2 = store.isDefaultAdmin(name: s2.memberName)
            if a1 != a2 { return a1 }
            return s1.memberName < s2.memberName
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Bar
            topHeaderBar
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // 2. Main Team Content
            if filteredSchedules.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary Stats Bar
                        teamTodaySummaryBar
                        
                        // Team Schedule Matrix Grid
                        teamScheduleMatrix
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: Binding(
            get: { selectedDayDetail != nil ? DayDetailWrapper(detail: selectedDayDetail!) : nil },
            set: { selectedDayDetail = $0?.detail }
        )) { wrapper in
            dayDetailModalView(memberName: wrapper.detail.memberName, day: wrapper.detail.day)
        }
    }
    
    // MARK: - 1. Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("团队班表协同看板")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("\(filteredSchedules.count) 人已共享")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("实时聚合已分享班表的组员作息，方便全组换班、找人与协同沟通")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("搜索成员...", text: $searchMemberQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 100)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Filter Picker
            Picker("", selection: $selectedFilter) {
                ForEach(TeamShiftFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
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
                    .padding(.horizontal, 6)
                
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
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Go to My Shifts
            Button(action: {
                store.selectedNavigation = .shifts
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    Text("我的班表")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
    
    // MARK: - 2. Summary Stats Bar
    
    private var teamTodaySummaryBar: some View {
        let todayStr = store.todayDateString
        let workingCount = filteredSchedules.filter { sched in
            let t = sched.days.first(where: { $0.dateStr == todayStr })
            return t != nil && !t!.isOff
        }.count
        let offCount = filteredSchedules.count - workingCount
        
        return HStack(spacing: 14) {
            statBadge(title: "今日在岗成员", value: "\(workingCount) 人", color: .blue, icon: "person.fill.checkmark")
            statBadge(title: "今日休假成员", value: "\(offCount) 人", color: .orange, icon: "sun.max.fill")
            statBadge(title: "已共享总人数", value: "\(filteredSchedules.count) 人", color: .green, icon: "person.2.fill")
            
            Spacer()
            
            Text("点击任意成员某一天的班次卡片，可查看该成员当天的详细小休与会议作息时间")
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
    
    // MARK: - 3. Team Schedule Matrix
    
    private var teamScheduleMatrix: some View {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = store.todayDateString
        
        return VStack(spacing: 12) {
            // Matrix Header (Members Column + 7 Weekday Columns)
            HStack(spacing: 8) {
                Text("团队成员")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
                
                ForEach(daysInSelectedWeek, id: \.self) { date in
                    let dateStr = df.string(from: date)
                    let isToday = (dateStr == todayStr)
                    let cal = Calendar.current
                    let dayNum = cal.component(.day, from: date)
                    let weekday = weekdayName(for: date)
                    
                    VStack(spacing: 2) {
                        Text(weekday)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isToday ? .blue : .secondary)
                        Text("\(dayNum)日")
                            .font(.system(size: 13, weight: isToday ? .bold : .semibold))
                            .foregroundColor(isToday ? .blue : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Member Rows
            ForEach(filteredSchedules) { schedule in
                memberScheduleRow(schedule: schedule, df: df, todayStr: todayStr)
            }
        }
    }
    
    private func memberScheduleRow(schedule: MemberShiftSchedule, df: DateFormatter, todayStr: String) -> some View {
        let isDefaultAdmin = store.isDefaultAdmin(name: schedule.memberName)
        let isMe = (schedule.memberName == store.currentUser.name)
        let avatar = store.teamMembers.first(where: { $0.name == schedule.memberName })?.avatarSymbol ?? "person.crop.circle.fill"
        
        return HStack(spacing: 8) {
            // Member Info Column
            HStack(spacing: 8) {
                Image(systemName: isDefaultAdmin ? "crown.fill" : avatar)
                    .font(.system(size: 16))
                    .foregroundColor(isDefaultAdmin ? .orange : (isMe ? .blue : .accentColor))
                    .frame(width: 28, height: 28)
                    .background((isDefaultAdmin ? Color.orange : (isMe ? Color.blue : Color.accentColor)).opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(schedule.memberName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        if isMe {
                            Text("(我)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if isDefaultAdmin {
                        Text("超级管理员")
                            .font(.system(size: 9.5))
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(width: 140, alignment: .leading)
            
            // 7 Days Shift Cells
            ForEach(daysInSelectedWeek, id: \.self) { date in
                let dateStr = df.string(from: date)
                let isToday = (dateStr == todayStr)
                let shift = schedule.days.first(where: { $0.dateStr == dateStr })
                
                memberDayCell(shift: shift, isToday: isToday) {
                    if let s = shift {
                        selectedDayDetail = (memberName: schedule.memberName, day: s)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? Color.blue.opacity(0.04) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isMe ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func memberDayCell(shift: DayShift?, isToday: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let s = shift {
                    if s.isOff {
                        HStack(spacing: 3) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 9))
                            Text("休假")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        VStack(spacing: 2) {
                            Text("\(s.workStart)-\(s.workEnd)")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.blue)
                            
                            // Key Activity Pill if any special meeting/training
                            if let special = s.segments.first(where: { $0.type == .meeting || $0.type == .training }) {
                                Text(special.title)
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundColor(special.type == .meeting ? .purple : .indigo)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } else {
                    Text("-")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 4. Day Detail Modal View
    
    private func dayDetailModalView(memberName: String, day: DayShift) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(memberName) 的日程详情")
                            .font(.system(size: 16, weight: .bold))
                        Text("\(day.dateStr) (\(day.weekdayName))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { selectedDayDetail = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if day.isOff {
                HStack(spacing: 10) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当天全天休假 (OFF)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        Text("未安排排班与工时任务")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("总工时范围：")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                        Text("\(day.workStart) - \(day.workEnd)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("作息与活动分段：")
                        .font(.system(size: 12.5, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(day.segments) { seg in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segmentColor(seg.type))
                                    .frame(width: 7, height: 7)
                                Text("\(seg.startTime) - \(seg.endTime)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                Text(seg.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(segmentColor(seg.type))
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("关闭") {
                    selectedDayDetail = nil
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash.fill")
                .font(.system(size: 46))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无成员分享团队班表")
                .font(.system(size: 17, weight: .bold))
            
            Text("当组员在「个人中心 > 我的班表」中点击「分享至团队班表」后，全员排班将自动在此汇聚同步，方便互相换班与出勤协同。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            
            Button(action: {
                store.selectedNavigation = .shifts
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("去我的班表开启分享")
                }
                .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .padding(40)
    }
    
    private func segmentColor(_ type: ShiftSegmentType) -> Color {
        switch type {
        case .work: return .blue
        case .breakFirst, .breakSecond: return .orange
        case .lunch: return .green
        case .training: return .purple
        case .meeting: return .indigo
        case .leave: return .yellow
        case .off: return .gray
        case .other: return .teal
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
}

// Wrapper for Identifiable sheet binding
struct DayDetailWrapper: Identifiable {
    var id: String { "\(detail.memberName)_\(detail.day.dateStr)" }
    var detail: (memberName: String, day: DayShift)
}
