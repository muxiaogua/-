//
//  ShiftItem.swift
//  团队工作台
//
//

import Foundation
import AppKit

public enum ShiftSegmentType: String, Codable, CaseIterable, Identifiable {
    case work = "上班"
    case breakFirst = "第一小休"
    case lunch = "午餐"
    case breakSecond = "第二小休"
    case training = "培训"
    case meeting = "组会"
    case leave = "请假"
    case off = "休假"
    case other = "其他安排"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .work: return "briefcase.fill"
        case .breakFirst, .breakSecond: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .training: return "book.fill"
        case .meeting: return "person.3.fill"
        case .leave: return "airplane.departure"
        case .off: return "sun.max.fill"
        case .other: return "clock.fill"
        }
    }
    
    public var standardColorName: String {
        switch self {
        case .work: return "blue"
        case .breakFirst, .breakSecond: return "orange"
        case .lunch: return "green"
        case .training: return "purple"
        case .meeting: return "indigo"
        case .leave: return "yellow"
        case .off: return "gray"
        case .other: return "teal"
        }
    }
}

public struct ShiftSegment: Identifiable, Codable, Hashable {
    public var id: UUID
    public var dateStr: String       // e.g. "2026-09-01"
    public var startTime: String     // e.g. "09:00"
    public var endTime: String       // e.g. "18:00"
    public var type: ShiftSegmentType
    public var title: String
    public var details: String
    
    // 统一转换为纯英文官方标准排班名称
    public var displayTitle: String {
        let raw = title.trimmingCharacters(in: .whitespaces)
        let lower = raw.lowercased()
        
        // 1. Break / 小休（优先级提升，包含 break 绝不能被 1:1 覆盖）
        if lower.contains("break") || lower.contains("小休") || lower.contains("brk") {
            return "Break"
        }
        
        // 2. Lunch / 午餐
        if lower.contains("lunch") || lower.contains("午餐") || lower.contains("meal") || lower.contains("dinner") {
            return "Lunch"
        }
        
        // 3. COMMTG
        if lower.contains("commtg") {
            return "COMMTG"
        }
        
        // 4. Team Meeting / 组会
        if lower.contains("team meeting") || lower.contains("teammtg") || lower.contains("组会") || lower.contains("团队会议") || lower.contains("例会") {
            return "Team Meeting"
        }
        
        // 5. 1:1 / Coaching (排除时间数字误判，如 11:15、1:10)
        let pattern1on1 = #"(?<!\d)(?:1\s*[:：\-]\s*1)(?!\d)"#
        let has1on1Token = (try? NSRegularExpression(pattern: pattern1on1, options: .caseInsensitive))?.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil
        if lower.contains("coaching") || lower.contains("辅导") || lower.contains("1 on 1") || has1on1Token {
            return "1:1 Coaching"
        }
        
        // 6. SGT / 自学培训
        if lower.contains("sgt") {
            return "SGT"
        }
        
        // 7. Time Off / 请假
        if lower.contains("time off") || lower.contains("time away") || lower.contains("special") || lower.contains("pto") || lower.contains("vto") || lower.contains("vacation") || lower.contains("sick") || lower.contains("leave") || lower.contains("请假") || lower.contains("年假") || lower.contains("病假") || lower.contains("事假") {
            return "Time Off"
        }
        if lower.contains("break") || lower.contains("小休") || lower.contains("brk") {
            return "Break"
        }
        
        // 8. Work / 上班工时
        if lower.contains("work") || lower.contains("工时") || lower.contains("上班") {
            return "Work"
        }
        
        // 9. Training / 培训
        if lower.contains("training") || lower.contains("培训") {
            return "Training"
        }
        
        // 10. OFF / 休假
        if lower.contains("off") || lower.contains("休假") || lower.contains("轮休") {
            return "Time Off"
        }
        
        // 兜底按枚举类型返回标准英文
        switch type {
        case .work: return "Work"
        case .breakFirst, .breakSecond: return "Break"
        case .lunch: return "Lunch"
        case .training: return "Training"
        case .meeting: return "COMMTG"
        case .leave, .off: return "Time Off"
        case .other:
            if !raw.isEmpty && raw != "其他安排" {
                return raw
            }
            return "Work"
        }
    }
    
    public init(
        id: UUID = UUID(),
        dateStr: String = "",
        startTime: String = "",
        endTime: String = "",
        type: ShiftSegmentType = .work,
        title: String = "",
        details: String = ""
    ) {
        self.id = id
        self.dateStr = dateStr
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.title = title.isEmpty ? type.rawValue : title
        self.details = details
    }
}

public struct DayShift: Identifiable, Codable, Hashable {
    public var id: String { dateStr }
    public var dateStr: String       // e.g. "2026-09-01"
    public var isOff: Bool
    public var workStart: String     // e.g. "09:00"
    public var workEnd: String       // e.g. "18:00"
    public var segments: [ShiftSegment]
    public var note: String
    
    public init(
        dateStr: String,
        isOff: Bool = false,
        workStart: String = "09:00",
        workEnd: String = "18:00",
        segments: [ShiftSegment] = [],
        note: String = ""
    ) {
        self.dateStr = dateStr
        self.isOff = isOff
        self.workStart = workStart
        self.workEnd = workEnd
        self.segments = segments
        self.note = note
    }
    
    public var date: Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: dateStr) ?? Date()
    }
    
    public var weekdayName: String {
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

public struct MemberShiftSchedule: Codable, Identifiable {
    public var id: String { memberName }
    public var memberName: String
    public var updatedAt: Date
    public var isSharedToTeam: Bool
    public var sharedAt: Date?
    public var days: [DayShift]
    
    public init(
        memberName: String = "",
        updatedAt: Date = Date(),
        isSharedToTeam: Bool = false,
        sharedAt: Date? = nil,
        days: [DayShift] = []
    ) {
        self.memberName = memberName
        self.updatedAt = updatedAt
        self.isSharedToTeam = isSharedToTeam
        self.sharedAt = sharedAt
        self.days = days
    }
    
    // MARK: - ICS Calendar Generator
    
    public func generateICSContent() -> String {
        var ics = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Apple Inc//Team Workbench Shifts//CN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:我的班表 (\(memberName))",
            "X-WR-TIMEZONE:Asia/Shanghai",
            "BEGIN:VTIMEZONE",
            "TZID:Asia/Shanghai",
            "X-LIC-LOCATION:Asia/Shanghai",
            "BEGIN:STANDARD",
            "TZOFFSETFROM:+0800",
            "TZOFFSETTO:+0800",
            "TZNAME:CST",
            "DTSTART:19700101T000000",
            "END:STANDARD",
            "END:VTIMEZONE"
        ]
        
        for day in days {
            if day.isOff {
                continue
            }
            
            for seg in day.segments {
                let dtStart = formatICSTimestamp(dateStr: seg.dateStr, timeStr: seg.startTime)
                let dtEnd = formatICSTimestamp(dateStr: seg.dateStr, timeStr: seg.endTime)
                guard let start = dtStart, let end = dtEnd else { continue }
                
                ics.append("BEGIN:VEVENT")
                ics.append("UID:\(seg.id.uuidString)@teamworkbench.apple.com")
                ics.append("DTSTAMP:\(formatUTCNow())")
                ics.append("DTSTART;TZID=Asia/Shanghai:\(start)")
                ics.append("DTEND;TZID=Asia/Shanghai:\(end)")
                ics.append("SUMMARY:\(seg.title)")
                if !seg.details.isEmpty {
                    ics.append("DESCRIPTION:\(seg.details)")
                }
                ics.append("STATUS:CONFIRMED")
                ics.append("END:VEVENT")
            }
        }
        
        ics.append("END:VCALENDAR")
        return ics.joined(separator: "\r\n")
    }
    
    public func exportToCalendarApp() -> Bool {
        let content = generateICSContent()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Shifts_\(memberName).ics")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(fileURL)
            return true
        } catch {
            return false
        }
    }
    
    private func formatICSTimestamp(dateStr: String, timeStr: String) -> String? {
        let cleanDate = dateStr.replacingOccurrences(of: "-", with: "")
        let cleanTime = timeStr.replacingOccurrences(of: ":", with: "")
        if cleanDate.count == 8 && cleanTime.count >= 4 {
            let paddedTime = cleanTime.count == 4 ? cleanTime + "00" : cleanTime
            return "\(cleanDate)T\(paddedTime)"
        }
        return nil
    }
    
    private func formatUTCNow() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.string(from: Date())
    }
}
