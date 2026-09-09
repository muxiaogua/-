//
//  ShiftsSyncService.swift
//  团队工作台
//
//

import Foundation
import Combine
import WebKit
import AppKit

// MARK: - Official Apple Shifts API Models

public struct ShiftsAPIResponse: Codable {
    public var scheduleInfoResponse: [ShiftsAPIDayItem]?
}

public struct ShiftsAPIDayItem: Codable {
    public var date: String?
    public var dateString: String?
    public var isOffDay: Bool?
    public var totalShiftRange: String?
    public var segments: [ShiftsAPISegmentItem]?
}

public struct ShiftsAPISegmentItem: Codable {
    public var segmentCategory: String?
    public var segmentCode: String?
    public var segmentDescription: String?
    public var startTime: String?
    public var endTime: String?
    public var memo: String?
}

public class ShiftsSyncService: NSObject, ObservableObject, WKNavigationDelegate {
    public static let shared = ShiftsSyncService()
    
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String = ""
    @Published public var showWebSyncSheet: Bool = false
    
    public static let userAgentString = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5.2 Safari/605.1.15"
    
    // JS Injection script that hooks XMLHttpRequest and window.fetch for real-time JSON capture
    public static let networkHookScript = """
    (function() {
        var origOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            this.addEventListener('load', function() {
                if (typeof url === 'string' && (url.includes('/schedules') || url.includes('/monthly') || url.includes('/weekly') || url.includes('/shift') || url.includes('/daily') || url.includes('/schedule'))) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shiftsLiveContinuousBridge) {
                        window.webkit.messageHandlers.shiftsLiveContinuousBridge.postMessage({ data: this.responseText });
                    }
                }
            });
            return origOpen.apply(this, arguments);
        };
        
        var origFetch = window.fetch;
        if (origFetch) {
            window.fetch = async function() {
                var response = await origFetch.apply(this, arguments);
                try {
                    var clone = response.clone();
                    var url = (typeof arguments[0] === 'string') ? arguments[0] : (arguments[0] ? arguments[0].url : '');
                    if (url && (url.includes('/schedules') || url.includes('/monthly') || url.includes('/weekly') || url.includes('/shift') || url.includes('/daily') || url.includes('/schedule'))) {
                        clone.text().then(function(text) {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shiftsLiveContinuousBridge) {
                                window.webkit.messageHandlers.shiftsLiveContinuousBridge.postMessage({ data: text });
                            }
                        });
                    }
                } catch(e) {}
                return response;
            };
        }
        
        // Auto-click list tab if found
        function tryClickList() {
            const listButtons = Array.from(document.querySelectorAll('button, a, [role="tab"], [role="button"], mat-button-toggle, li, div'));
            for (const el of listButtons) {
                const t = (el.innerText || el.getAttribute('aria-label') || el.getAttribute('title') || '').trim().toLowerCase();
                if (t === 'list' || t === '列表' || t.includes('list view') || t.includes('列表视图')) {
                    try { el.click(); } catch(e) {}
                    break;
                }
            }
        }
        setInterval(tryClickList, 1000);
    })();
    """
    
    override private init() {
        super.init()
    }
    
    // MARK: - 1. JSON Response Parser (Direct From Apple Shifts Network Bridge)
    
    public func parseShiftsJSONData(_ jsonString: String, targetMonday: Date? = nil) -> [DayShift] {
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        // 1. First try direct official model decoding
        if let apiResponse = try? JSONDecoder().decode(ShiftsAPIResponse.self, from: data),
           let days = apiResponse.scheduleInfoResponse, !days.isEmpty {
            
            var parsedDays: [DayShift] = []
            
            for dayItem in days {
                let dateStr = String((dayItem.dateString ?? dayItem.date ?? "").prefix(10))
                guard !dateStr.isEmpty else { continue }
                
                let isOff = dayItem.isOffDay ?? (dayItem.segments == nil || dayItem.segments!.isEmpty)
                var rawSegments: [ShiftSegment] = []
                
                if let segs = dayItem.segments {
                    for s in segs {
                        let desc = s.segmentDescription ?? s.segmentCategory ?? s.segmentCode ?? ""
                        let segType = detectSegmentType(from: desc)
                        
                        let start24 = normalizeISOorTimeString(s.startTime ?? "")
                        let end24 = normalizeISOorTimeString(s.endTime ?? "")
                        
                        if !start24.isEmpty && !end24.isEmpty {
                            rawSegments.append(ShiftSegment(
                                dateStr: dateStr,
                                startTime: start24,
                                endTime: end24,
                                type: segType,
                                title: detectSegmentTitle(type: segType, line: desc),
                                details: desc
                            ))
                        }
                    }
                }
                
                let resolved = resolveOverlappingWorkSegments(rawSegments, dateStr: dateStr)
                let workStart = rawSegments.first?.startTime ?? "09:00"
                let workEnd = rawSegments.first?.endTime ?? "18:00"
                
                parsedDays.append(DayShift(
                    dateStr: dateStr,
                    isOff: isOff,
                    workStart: workStart,
                    workEnd: workEnd,
                    segments: isOff ? [] : resolved
                ))
            }
            
            if !parsedDays.isEmpty {
                return padAndSortDays(parsedDays, targetMonday: targetMonday)
            }
        }
        
        // 2. Fallback dynamic recursive dictionary parser
        if let rootObj = try? JSONSerialization.jsonObject(with: data) {
            var segmentsByDate: [String: [ShiftSegment]] = [:]
            
            func processDict(_ dict: [String: Any]) {
                var dateStr = ""
                if let d = dict["dateString"] as? String ?? dict["date"] as? String ?? dict["scheduleDate"] as? String {
                    dateStr = String(d.prefix(10))
                }
                
                var startTimeStr = ""
                var endTimeStr = ""
                
                if let startRaw = dict["startTime"] as? String ?? dict["startDateTime"] as? String {
                    startTimeStr = normalizeISOorTimeString(startRaw)
                }
                if let endRaw = dict["endTime"] as? String ?? dict["endDateTime"] as? String {
                    endTimeStr = normalizeISOorTimeString(endRaw)
                }
                
                let desc = dict["segmentDescription"] as? String ?? dict["segmentCategory"] as? String ?? dict["segmentCode"] as? String ?? dict["activityName"] as? String ?? dict["title"] as? String ?? ""
                
                if !dateStr.isEmpty && !startTimeStr.isEmpty && !endTimeStr.isEmpty {
                    let segType = detectSegmentType(from: desc)
                    let seg = ShiftSegment(
                        dateStr: dateStr,
                        startTime: startTimeStr,
                        endTime: endTimeStr,
                        type: segType,
                        title: detectSegmentTitle(type: segType, line: desc),
                        details: desc
                    )
                    segmentsByDate[dateStr, default: []].append(seg)
                }
                
                for (_, val) in dict {
                    if let nestedDict = val as? [String: Any] {
                        processDict(nestedDict)
                    } else if let nestedArr = val as? [[String: Any]] {
                        for item in nestedArr {
                            processDict(item)
                        }
                    }
                }
            }
            
            if let dict = rootObj as? [String: Any] {
                processDict(dict)
            } else if let arr = rootObj as? [[String: Any]] {
                for item in arr {
                    processDict(item)
                }
            }
            
            if !segmentsByDate.isEmpty {
                var parsedDays: [DayShift] = []
                for (dateStr, rawSegs) in segmentsByDate {
                    let resolved = resolveOverlappingWorkSegments(rawSegs, dateStr: dateStr)
                    let isOff = resolved.isEmpty
                    let workStart = rawSegs.first?.startTime ?? "09:00"
                    let workEnd = rawSegs.first?.endTime ?? "18:00"
                    
                    parsedDays.append(DayShift(
                        dateStr: dateStr,
                        isOff: isOff,
                        workStart: workStart,
                        workEnd: workEnd,
                        segments: isOff ? [] : resolved
                    ))
                }
                return padAndSortDays(parsedDays, targetMonday: targetMonday)
            }
        }
        
        return []
    }
    
    // MARK: - 2. DOM Extraction (Fallback)
    
    public func extractShiftsFromDOM(webView: WKWebView, targetMonday: Date? = nil, completion: @escaping ([DayShift]?, String, String) -> Void) {
        let jsExtractScript = """
        (function() {
            if (!document.body) {
                return JSON.stringify({ status: "loading", text: "", snippet: "" });
            }
            
            const bodyText = document.body.innerText || "";
            if (bodyText.includes("Sign In") || bodyText.includes("AppleConnect") || bodyText.includes("Enter your Apple ID") || bodyText.includes("登录")) {
                return JSON.stringify({ status: "need_login", text: bodyText.substring(0, 500), snippet: bodyText.substring(0, 150) });
            }
            
            let cleanedText = bodyText
                .replace(/\\u00a0/g, ' ')
                .replace(/[\\u2013\\u2014\\u2015]/g, '-')
                .replace(/[\\uff5e\\u301c~至到]/g, '-');
            
            const snippet = cleanedText.trim().substring(0, 400);
            return JSON.stringify({ status: "ok", text: cleanedText, snippet: snippet });
        })();
        """
        
        webView.evaluateJavaScript(jsExtractScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if let err = error {
                completion(nil, "JavaScript 执行异常: \(err.localizedDescription)", "")
                return
            }
            
            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let status = obj["status"] as? String ?? ""
                let snippet = obj["snippet"] as? String ?? ""
                
                if status == "need_login" {
                    completion(nil, "需要先在页面中完成 AppleConnect 认证", snippet)
                    return
                }
                
                if let rawText = obj["text"] as? String, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let parsedDays = self.parseShiftsRawText(rawText, targetMonday: targetMonday)
                    if !parsedDays.isEmpty {
                        completion(parsedDays, "成功提取 \(parsedDays.count) 天班表数据", snippet)
                        return
                    } else {
                        completion(nil, "页面已加载，但未匹配到班次格式。\n\n网页文本片段：\n\(snippet)", snippet)
                        return
                    }
                }
            }
            
            completion(nil, "页面内容为空，请等待页面加载或刷新重试", "")
        }
    }
    
    // MARK: - 3. Smart Raw Text Parser
    
    public func parseShiftsRawText(_ text: String, targetMonday: Date? = nil) -> [DayShift] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var parsedDays: [DayShift] = []
        var currentDateStr = ""
        var currentSegments: [ShiftSegment] = []
        var currentIsOff = false
        
        let currentYear = Calendar.current.component(.year, from: Date())
        
        func finishCurrentDay() {
            guard !currentDateStr.isEmpty else { return }
            
            var isFullDayLeave = false
            for seg in currentSegments {
                if seg.type == .leave {
                    if seg.startTime == "00:00" && (seg.endTime == "23:59" || seg.endTime == "24:00") {
                        isFullDayLeave = true
                        break
                    }
                    if seg.details.localizedCaseInsensitiveContains("Full Day") || seg.details.localizedCaseInsensitiveContains("Full") {
                        isFullDayLeave = true
                        break
                    }
                }
            }
            
            if isFullDayLeave {
                let day = DayShift(
                    dateStr: currentDateStr,
                    isOff: true,
                    workStart: "09:00",
                    workEnd: "18:00",
                    segments: [],
                    note: "全天请假 (Time Off)"
                )
                parsedDays.append(day)
                currentDateStr = ""
                currentSegments = []
                currentIsOff = false
                return
            }
            
            let segments = resolveOverlappingWorkSegments(currentSegments, dateStr: currentDateStr)
            let workSegs = segments.filter { $0.type == .work }
            let hasWork = !workSegs.isEmpty
            let isDayOff = (!hasWork && segments.isEmpty) || currentIsOff
            
            let workStart = workSegs.first?.startTime ?? (currentSegments.first?.startTime ?? "09:00")
            let workEnd = workSegs.last?.endTime ?? (currentSegments.first?.endTime ?? "18:00")
            
            let day = DayShift(
                dateStr: currentDateStr,
                isOff: isDayOff && segments.isEmpty,
                workStart: workStart,
                workEnd: workEnd,
                segments: (isDayOff && segments.isEmpty) ? [] : segments
            )
            parsedDays.append(day)
            
            currentDateStr = ""
            currentSegments = []
            currentIsOff = false
        }
        
        let monthMap: [String: Int] = [
            "jan": 1, "january": 1,
            "feb": 2, "february": 2,
            "mar": 3, "march": 3,
            "apr": 4, "april": 4,
            "may": 5,
            "jun": 6, "june": 6,
            "jul": 7, "july": 7,
            "aug": 8, "august": 8,
            "sep": 9, "september": 9,
            "oct": 10, "october": 10,
            "nov": 11, "november": 11,
            "dec": 12, "december": 12
        ]
        
        let datePatternDayFirst = #"(?:^|\b)(\d{1,2})\s+([A-Za-z]{3,})(?:,\s*(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday))?"#
        let datePatternMonthFirst = #"(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s*)?([A-Za-z]{3,})\s+(\d{1,2})(?:,\s*(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday))?"#
        let datePatternChinese = #"(\d{1,2})月(\d{1,2})日"#
        let datePatternISO = #"(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})"#
        
        let timePattern = #"(\d{1,2}:\d{2}\s*(?:[AaPp][Mm])?)\s*[-~至到–—]\s*(\d{1,2}:\d{2}\s*(?:[AaPp][Mm])?)"#
        
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            let prevLine = index > 0 ? lines[index - 1] : ""
            
            // 1. Check if line is a Time entry
            var isTimeLine = false
            if let timeRegex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
               let timeMatch = timeRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                
                isTimeLine = true
                
                if !currentDateStr.isEmpty {
                    let rawStart = String(line[Range(timeMatch.range(at: 1), in: line)!])
                    let rawEnd = String(line[Range(timeMatch.range(at: 2), in: line)!])
                    
                    let start24 = normalizeTo24Hour(rawStart)
                    let end24 = normalizeTo24Hour(rawEnd)
                    
                    // Check line first, then fallback to preceding line for event type (e.g. "Partial Day Planned Time Away")
                    var segmentType = detectSegmentType(from: line)
                    var titleCandidate = line
                    if segmentType == .work && !line.localizedCaseInsensitiveContains("Work") && !prevLine.isEmpty {
                        let prevType = detectSegmentType(from: prevLine)
                        if prevType != .work {
                            segmentType = prevType
                            titleCandidate = prevLine
                        }
                    }
                    
                    let seg = ShiftSegment(
                        dateStr: currentDateStr,
                        startTime: start24,
                        endTime: end24,
                        type: segmentType,
                        title: detectSegmentTitle(type: segmentType, line: titleCandidate),
                        details: "\(titleCandidate) \(line)"
                    )
                    currentSegments.append(seg)
                }
            }
            
            if isTimeLine {
                continue
            }
            
            // Ignore summary metadata lines
            if lower.contains("summary") || lower.contains("hours:") || (lower.contains("hours") && !lower.contains("away")) || lower.contains("total") {
                continue
            }
            
            // 2. Match Dates
            var matchedDateStr: String?
            
            // A. "31 Aug, Mon" or "1 Sep, Tue"
            if let regex = try? NSRegularExpression(pattern: datePatternDayFirst, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let dayNum = Int(String(line[Range(match.range(at: 1), in: line)!])) ?? 1
                let monthStr = String(line[Range(match.range(at: 2), in: line)!]).lowercased()
                if let monthNum = monthMap[monthStr] {
                    matchedDateStr = String(format: "%04d-%02d-%02d", currentYear, monthNum, dayNum)
                }
            }
            
            // B. "Monday, Aug 31"
            if matchedDateStr == nil {
                if let regex = try? NSRegularExpression(pattern: datePatternMonthFirst, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    let monthStr = String(line[Range(match.range(at: 1), in: line)!]).lowercased()
                    let dayNum = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 1
                    if let monthNum = monthMap[monthStr] {
                        matchedDateStr = String(format: "%04d-%02d-%02d", currentYear, monthNum, dayNum)
                    }
                }
            }
            
            // C. Chinese "8月31日"
            if matchedDateStr == nil {
                if let regex = try? NSRegularExpression(pattern: datePatternChinese, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    let m = Int(String(line[Range(match.range(at: 1), in: line)!])) ?? 1
                    let d = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 1
                    matchedDateStr = String(format: "%04d-%02d-%02d", currentYear, m, d)
                }
            }
            
            // D. ISO "2026-08-31"
            if matchedDateStr == nil {
                if let regex = try? NSRegularExpression(pattern: datePatternISO, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    let y = Int(String(line[Range(match.range(at: 1), in: line)!])) ?? currentYear
                    let m = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 1
                    let d = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 1
                    matchedDateStr = String(format: "%04d-%02d-%02d", y, m, d)
                }
            }
            
            if let newDate = matchedDateStr {
                if !currentDateStr.isEmpty && currentDateStr != newDate {
                    finishCurrentDay()
                }
                currentDateStr = newDate
                continue
            }
            
            // Check explicit OFF
            let cleanLine = line.trimmingCharacters(in: .whitespaces)
            if cleanLine == "OFF" || cleanLine == "休假" || cleanLine.localizedCaseInsensitiveContains("Day Off") || cleanLine == "轮休" {
                currentIsOff = true
            }
        }
        
        finishCurrentDay()
        return padAndSortDays(parsedDays, targetMonday: targetMonday)
    }
    
    // MARK: - Helper Methods
    
    private func padAndSortDays(_ parsedDays: [DayShift], targetMonday: Date?) -> [DayShift] {
        let hasRealShifts = parsedDays.contains { !$0.segments.isEmpty }
        guard hasRealShifts else {
            return []
        }
        
        var days = parsedDays
        if let monday = targetMonday {
            let cal = Calendar.current
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: i, to: monday) {
                    let dStr = df.string(from: d)
                    if !days.contains(where: { $0.dateStr == dStr }) {
                        days.append(DayShift(dateStr: dStr, isOff: true, workStart: "09:00", workEnd: "18:00", segments: []))
                    }
                }
            }
        }
        return days.sorted { $0.dateStr < $1.dateStr }
    }
    
    private func resolveOverlappingWorkSegments(_ rawSegments: [ShiftSegment], dateStr: String) -> [ShiftSegment] {
        let workSegments = rawSegments.filter { $0.type == .work }
        let leaveSegments = rawSegments.filter { $0.type == .leave }
        let otherNonWork = rawSegments.filter { $0.type != .work && $0.type != .leave && $0.type != .off }
        
        // 1. Any meeting, break, or lunch that falls completely inside a Planned Time Away window is cancelled/overridden by leave
        let filteredOtherNonWork = otherNonWork.filter { ev in
            !leaveSegments.contains { lv in
                ev.startTime >= lv.startTime && ev.endTime <= lv.endTime
            }
        }
        
        let allNonWorkSegments = (leaveSegments + filteredOtherNonWork)
            .sorted { $0.startTime < $1.startTime }
        
        guard let mainWork = workSegments.max(by: { $0.endTime < $1.endTime }), !allNonWorkSegments.isEmpty else {
            return rawSegments
        }
        
        var result: [ShiftSegment] = []
        var currentCursor = mainWork.startTime
        
        for breakSeg in allNonWorkSegments {
            if currentCursor < breakSeg.startTime {
                result.append(ShiftSegment(
                    dateStr: dateStr,
                    startTime: currentCursor,
                    endTime: breakSeg.startTime,
                    type: .work,
                    title: "工时 (Work)",
                    details: mainWork.details
                ))
            }
            result.append(breakSeg)
            currentCursor = max(currentCursor, breakSeg.endTime)
        }
        
        if currentCursor < mainWork.endTime {
            result.append(ShiftSegment(
                dateStr: dateStr,
                startTime: currentCursor,
                endTime: mainWork.endTime,
                type: .work,
                title: "工时 (Work)",
                details: mainWork.details
            ))
        }
        
        return result.sorted { $0.startTime < $1.startTime }
    }
    
    private func detectSegmentType(from line: String) -> ShiftSegmentType {
        let lower = line.lowercased()
        if lower.contains("special") || lower.contains("time off") || lower.contains("planned time away") || lower.contains("time away") || lower.contains("pto") || lower.contains("vto") || lower.contains("vacation") || lower.contains("sick") || lower.contains("leave") || lower.contains("请假") || lower.contains("年假") || lower.contains("病假") || lower.contains("事假") {
            return .leave
        }
        if lower.contains("break") || lower.contains("小休") || lower.contains("brk") {
            if lower.contains("first") || lower.contains("1") || lower.contains("一") || lower.contains("am break") {
                return .breakFirst
            } else {
                return .breakSecond
            }
        }
        if lower.contains("lunch") || lower.contains("午餐") || lower.contains("meal") || lower.contains("dinner") {
            return .lunch
        }
        if lower.contains("training") || lower.contains("培训") || lower.contains("sgt") || lower.contains("dev") || lower.contains("workshop") || lower.contains("learn") {
            return .training
        }
        if lower.contains("commtg") {
            return .meeting
        }
        if lower.contains("team meeting") || lower.contains("teammtg") || lower.contains("组会") || lower.contains("例会") || lower.contains("huddle") {
            return .meeting
        }
        // 精准匹配 1:1 辅导，严防误伤带有 1:10 / 11:15 等时间数字
        if isOneOnOneCoaching(line: line) {
            return .meeting
        }
        if lower.contains("off") || lower.contains("休假") {
            return .off
        }
        return .work
    }
    
    private func detectSegmentTitle(type: ShiftSegmentType, line: String) -> String {
        let clean = line.trimmingCharacters(in: .whitespaces)
        let lower = clean.lowercased()
        
        if lower.contains("special") || lower.contains("time off") || lower.contains("planned time away") || lower.contains("time away") || lower.contains("pto") || lower.contains("vto") || lower.contains("vacation") || lower.contains("sick") || lower.contains("leave") || lower.contains("请假") || lower.contains("年假") || lower.contains("病假") || lower.contains("事假") {
            return "Time Off"
        }
        if lower.contains("commtg") {
            return "COMMTG"
        }
        if lower.contains("team meeting") || lower.contains("teammtg") || lower.contains("组会") || lower.contains("例会") {
            return "Team Meeting"
        }
        if isOneOnOneCoaching(line: clean) {
            return "1:1 Coaching"
        }
        if lower.contains("sgt") {
            return "SGT"
        }
        if lower.contains("break") || lower.contains("小休") || lower.contains("brk") {
            return "Break"
        }
        if lower.contains("lunch") || lower.contains("午餐") || lower.contains("meal") || lower.contains("dinner") {
            return "Lunch"
        }
        if lower.contains("training") || lower.contains("培训") {
            return "Training"
        }
        if lower.contains("off") || lower.contains("休假") {
            return "Time Off"
        }
        
        switch type {
        case .work:
            return "Work"
        case .breakFirst, .breakSecond:
            return "Break"
        case .lunch:
            return "Lunch"
        case .training:
            return "Training"
        case .meeting:
            return "COMMTG"
        case .leave, .off:
            return "Time Off"
        case .other:
            return "Work"
        }
    }
    
    // 严格判断是否为 1:1 Coaching 辅导，避免包含 11:15、1:10 等时间数字时的误判
    private func isOneOnOneCoaching(line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("coaching") || lower.contains("辅导") {
            return true
        }
        if lower.contains("1 on 1") {
            return true
        }
        // 使用正则确保 1:1 或 1-1 作为独立单词出现（前后为单词边界，而非 11:15）
        let pattern = #"(?<!\d)(?:1\s*[:：\-]\s*1)(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let _ = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            // 如果这行文字里明确包含 break 或 lunch 或 work，即使有 1:1 也不能算作 coaching
            if lower.contains("break") || lower.contains("lunch") || lower.contains("work") {
                return false
            }
            return true
        }
        return false
    }
    
    private func normalizeISOorTimeString(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespaces)
        if clean.contains("T") {
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            isoFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = isoFormatter.date(from: clean) {
                let outDF = DateFormatter()
                outDF.dateFormat = "HH:mm"
                return outDF.string(from: date)
            }
        }
        return normalizeTo24Hour(clean)
    }
    
    private func normalizeTo24Hour(_ timeStr: String) -> String {
        let clean = timeStr.trimmingCharacters(in: .whitespaces).lowercased()
        let isPM = clean.contains("pm")
        let isAM = clean.contains("am")
        let stripped = clean.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "").trimmingCharacters(in: .whitespaces)
        let parts = stripped.components(separatedBy: ":")
        if parts.count == 2, var h = Int(parts[0]), let m = Int(parts[1]) {
            if isPM && h < 12 {
                h += 12
            } else if isAM && h == 12 {
                h = 0
            }
            return String(format: "%02d:%02d", h, m)
        }
        return timeStr
    }
}
