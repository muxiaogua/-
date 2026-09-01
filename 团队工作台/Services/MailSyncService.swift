//
//  MailSyncService.swift
//  团队工作台
//

import Foundation
import Combine
import AppKit

public struct ExtractedMailItem {
    public var id: String
    public var title: String
    public var sender: String
    public var date: Date
    public var plainContent: String
    public var htmlContent: String?
}

@MainActor
public class MailSyncService: ObservableObject {
    public static let shared = MailSyncService()
    
    private let lastSyncTimeStorageKey = "workbench_last_mail_sync_date"
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncResult: String?
    @Published public var errorMessage: String?
    @Published public var needsPrivacySettingsGuide: Bool = false
    @Published public var lastSyncTime: Date? {
        didSet {
            if let date = lastSyncTime {
                UserDefaults.standard.set(date, forKey: lastSyncTimeStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSyncTimeStorageKey)
            }
        }
    }
    
    public init() {
        self.lastSyncTime = UserDefaults.standard.object(forKey: lastSyncTimeStorageKey) as? Date
    }
    
    public func openAutomationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Simplifies redundant prefix patterns such as ' Green Email - 近期重要内容 - ' into clean titles
    nonisolated public static func cleanGreenEmailTitle(_ rawTitle: String) -> String {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let prefixesToStrip = [
            " Green Email - 近期重要内容 - ",
            " Green Email - 近期重要内容 – ",
            " Green Email - 近期重要内容 — ",
            " Green Email – 近期重要内容 – ",
            " Green Email — 近期重要内容 — ",
            " Green Email - 近期重要内容",
            " Green Email – 近期重要内容",
            " Green Email — 近期重要内容",
            "Green Email - 近期重要内容 - ",
            "Green Email - 近期重要内容 – ",
            "Green Email - 近期重要内容 — ",
            "Green Email – 近期重要内容 – ",
            "Green Email — 近期重要内容 — ",
            "Green Email - 近期重要内容",
            "Green Email – 近期重要内容",
            "Green Email — 近期重要内容",
            " Green Email - ",
            " Green Email – ",
            " Green Email — ",
            " Green Email: ",
            " Green Email：",
            " Green Email",
            "Green Email - ",
            "Green Email – ",
            "Green Email — ",
            "Green Email: ",
            "Green Email："
        ]
        
        for prefix in prefixesToStrip {
            if title.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Clean leading separators if any remain
        while title.hasPrefix("- ") || title.hasPrefix("– ") || title.hasPrefix("— ") || title.hasPrefix(":") || title.hasPrefix("：") {
            if title.hasPrefix("- ") || title.hasPrefix("– ") || title.hasPrefix("— ") {
                title = String(title.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = String(title.dropFirst(1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return title.isEmpty ? rawTitle : title
    }
    
    /// Cleans HTML content:
    /// 1. Drops top decorative green banner boxes and '▲ 简体版本' bar
    /// 2. Drops Traditional Chinese section below divider/marker
    /// 3. Normalizes Core article links to core://articleId=...
    nonisolated public static func cleanGreenEmailHTMLContent(_ rawHTML: String) -> String {
        var html = rawHTML
        
        // 1. Truncate Traditional Chinese version below divider / marker
        let traditionalMarkers = [
            "▲ 繁体版本", "▲ 繁體版本", "▲ 繁体中文", "▲ 繁體中文",
            "▲ 繁体", "▲ 繁體", "▲繁体版本", "▲繁體版本",
            "▲繁体", "▲繁體", "繁體版本 - 適用", "繁体版本 - 适用",
            "繁体版本", "繁體版本"
        ]
        
        for marker in traditionalMarkers {
            if let range = html.range(of: marker) {
                let beforeMarker = String(html[..<range.lowerBound])
                if let hrRange = beforeMarker.range(of: "<hr", options: .backwards),
                   beforeMarker.distance(from: hrRange.lowerBound, to: beforeMarker.endIndex) < 300 {
                    html = String(beforeMarker[..<hrRange.lowerBound])
                } else if let tableRange = beforeMarker.range(of: "<table", options: .backwards),
                          beforeMarker.distance(from: tableRange.lowerBound, to: beforeMarker.endIndex) < 400 {
                    html = String(beforeMarker[..<tableRange.lowerBound])
                } else {
                    html = beforeMarker
                }
                break
            }
        }
        
        // 2. Strip Top Header Boxes:
        // Find where the real content begins (after the '▲ 简体版本' banner or top green header table)
        let simplifiedVersionMarkers = [
            "▲ 简体版本", "▲ 簡體版本", "▲简体版本", "▲簡體版本", "ADVISOR（技术顾问）", "ADVISOR (技术顾问)", "ADVISOR"
        ]
        
        for marker in simplifiedVersionMarkers {
            if let range = html.range(of: marker) {
                let afterMarker = String(html[range.upperBound...])
                // Find the first <td> where the main content begins
                if let contentStart = afterMarker.range(of: "<td", options: .caseInsensitive) {
                    html = "<table width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr>" + String(afterMarker[contentStart.lowerBound...])
                    break
                } else if let contentStart = afterMarker.range(of: "<div", options: .caseInsensitive) {
                    html = String(afterMarker[contentStart.lowerBound...])
                    break
                }
            }
        }
        
        // Strip any remaining top or bottom green banner tables with background-image or background-color rgb(58, 122, 86) or #3a7a56
        if let greenTableRegex = try? NSRegularExpression(pattern: #"(?i)<table[^>]*(?:background-color:\s*(?:rgb\(58,\s*122,\s*86\)|#3a7a56|#3A7A56)|bgcolor=["']?(?:#3a7a56|#3A7A56|rgb\(58,\s*122,\s*86\))["']?)[^>]*>[\s\S]*?</table>"#) {
            html = greenTableRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "")
        }
        
        // Strip any remaining <hr> divider lines
        if let hrRegex = try? NSRegularExpression(pattern: #"(?i)<hr[^>]*>"#) {
            html = hrRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "")
        }
        
        // 3. Ensure Core article links use direct core:// schema
        html = html.replacingOccurrences(of: "https://support.apple.com/zh-cn/HT", with: "core://articleId=")
        html = html.replacingOccurrences(of: "https://support.apple.com/kb/HT", with: "core://articleId=")
        html = html.replacingOccurrences(of: "https://core.apple.com/article/", with: "core://articleId=")
        html = html.replacingOccurrences(of: "https://core.apple.com/kb/", with: "core://articleId=")
        
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Cleans Plain Text content: drops Traditional Chinese version below divider/marker, and strips header boilerplate
    nonisolated public static func cleanGreenEmailPlainText(_ rawPlain: String) -> String {
        var text = rawPlain.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        // 1. Truncate Traditional Chinese version below divider / marker
        let traditionalMarkers = [
            "▲ 繁体版本",
            "▲ 繁體版本",
            "▲ 繁体中文",
            "▲ 繁体",
            "▲ 繁體",
            "▲繁体版本",
            "▲繁体",
            "▲繁體版本",
            "▲繁體",
            "繁體版本 - 適用",
            "繁体版本 - 适用",
            "繁体版本",
            "繁體版本"
        ]
        
        for marker in traditionalMarkers {
            if let range = text.range(of: marker) {
                text = String(text[..<range.lowerBound])
                break
            }
        }
        
        // 2. Filter lines: remove header boilerplate and excess whitespace
        let lines = text.components(separatedBy: "\n")
        var cleanedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if cleanedLines.last != "" {
                    cleanedLines.append("")
                }
                continue
            }
            
            let lower = trimmed.lowercased()
            if lower.contains("green email") && (lower.contains("🌿") || lower.contains("🍃") || lower == "green email") {
                continue
            }
            if trimmed.contains("以下是今日关键信息") || trimmed.contains("以下是今日關鍵信息") {
                continue
            }
            if trimmed.contains("▲ 简体版本") || trimmed.contains("▲ 簡體版本") || trimmed.contains("▲简体版本") || trimmed.contains("▲簡体版本") {
                continue
            }
            if cleanedLines.count < 4 && trimmed.range(of: #"^\d{4}[-/.]\d{2}[-/.]\d{2}$"#, options: .regularExpression) != nil {
                continue
            }
            
            cleanedLines.append(line)
        }
        
        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Syncs Green Email messages from Apple Mail.app.
    /// - If `forceFullSync` is false and a previous sync time exists, performs an incremental sync from that timestamp.
    /// - Enforces a rolling 1-year retention policy: messages older than 1 year are automatically pruned.
    /// - Directly retrieves each message's complete in-memory MIME source to obtain 100% true HTML formatting (red text, bold, Core links).
    public func syncGreenEmailsFromMail(into store: WorkbenchStore, forceFullSync: Bool = false) async -> Int {
        isSyncing = true
        errorMessage = nil
        lastSyncResult = nil
        needsPrivacySettingsGuide = false
        
        let cal = Calendar.current
        let oneYearAgo = cal.date(byAdding: .year, value: -1, to: Date()) ?? Date().addingTimeInterval(-365 * 86400)
        
        // Determine whether to do incremental sync based on last sync time
        let hasExistingEmails = !store.newsArticles.filter({ $0.category == .greenEmail }).isEmpty
        let isIncremental = !forceFullSync && (lastSyncTime != nil) && hasExistingEmails
        
        let cutoffDate: Date
        if isIncremental, let last = lastSyncTime {
            cutoffDate = max(last.addingTimeInterval(-60), oneYearAgo) // 1 minute safety buffer, bounded by 1 year
        } else {
            cutoffDate = oneYearAgo
        }
        
        let cutoffYear = cal.component(.year, from: cutoffDate)
        let cutoffMonth = cal.component(.month, from: cutoffDate)
        let cutoffDay = cal.component(.day, from: cutoffDate)
        let cutoffHour = cal.component(.hour, from: cutoffDate)
        let cutoffMin = cal.component(.minute, from: cutoffDate)
        let cutoffSec = cal.component(.second, from: cutoffDate)
        let cutoffTimeInSeconds = cutoffHour * 3600 + cutoffMin * 60 + cutoffSec
        
        // Step 1: Query Mail.app and return structured list of message records including full raw MIME source
        let scriptSource = """
        tell application "Mail"
            set matchData to {}
            set targetSender to "ic_gc_aha_sacs@apple.com"
            set targetSubjectKeyword to "近期重要内容"
            set targetSubjectKeyword2 to "Green Email"
            
            -- Construct locale-independent date for cutoff
            set cutoffDate to (current date)
            set year of cutoffDate to \(cutoffYear)
            set month of cutoffDate to \(cutoffMonth)
            set day of cutoffDate to \(cutoffDay)
            set time of cutoffDate to \(cutoffTimeInSeconds)
            
            repeat with acc in accounts
                try
                    repeat with mb in mailboxes of acc
                        try
                            set msgs to (messages of mb whose (subject contains targetSubjectKeyword or subject contains targetSubjectKeyword2) and date received ≥ cutoffDate)
                            repeat with msg in msgs
                                set msgSender to sender of msg
                                set msgSubj to subject of msg
                                
                                -- Strict sender check
                                if msgSender contains targetSender then
                                    -- Strict exclusion for Re: / Fwd: / 回复 / 转发
                                    set isExcluded to false
                                    if msgSubj starts with "Re:" or msgSubj starts with "RE:" or msgSubj starts with "re:" or msgSubj starts with "re：" or msgSubj starts with "RE：" or msgSubj starts with "Re：" then
                                        set isExcluded to true
                                    else if msgSubj starts with "Fwd:" or msgSubj starts with "FWD:" or msgSubj starts with "fwd:" or msgSubj starts with "Fw:" or msgSubj starts with "FW:" or msgSubj starts with "fw:" or msgSubj starts with "fwd：" or msgSubj starts with "FWD：" or msgSubj starts with "fw：" or msgSubj starts with "FW：" then
                                        set isExcluded to true
                                    else if msgSubj starts with "回复:" or msgSubj starts with "回复：" or msgSubj starts with "回覆:" or msgSubj starts with "回覆：" or msgSubj starts with "转发:" or msgSubj starts with "转发：" or msgSubj starts with "轉寄:" or msgSubj starts with "轉寄：" then
                                        set isExcluded to true
                                    end if
                                    
                                    if not isExcluded then
                                        -- Format date to standard ISO 8601 (YYYY-MM-DDTHH:MM:SS)
                                        set msgD to date received of msg
                                        set y to (year of msgD as integer) as string
                                        set m to (month of msgD as integer) as string
                                        if length of m is 1 then set m to "0" & m
                                        set d to (day of msgD as integer) as string
                                        if length of d is 1 then set d to "0" & d
                                        set t to time of msgD
                                        set hrs to (t div 3600) as string
                                        if length of hrs is 1 then set hrs to "0" & hrs
                                        set mins to ((t mod 3600) div 60) as string
                                        if length of mins is 1 then set mins to "0" & mins
                                        set secs to (t mod 60) as string
                                        if length of secs is 1 then set secs to "0" & secs
                                        set msgDate to y & "-" & m & "-" & d & "T" & hrs & ":" & mins & ":" & secs
                                        
                                        set msgID to (id of msg as string)
                                        set msgPlain to (content of msg)
                                        
                                        set rawSrc to ""
                                        try
                                            set rawSrc to (source of msg)
                                        end try
                                        
                                        set end of matchData to {msgID, msgSubj, msgSender, msgDate, msgPlain, rawSrc}
                                    end if
                                end if
                            end repeat
                        end try
                    end repeat
                end try
            end repeat
            
            return matchData
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var errorDict: NSDictionary?
                let script = NSAppleScript(source: scriptSource)
                let descriptor = script?.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        let errStr = error[NSAppleScript.errorMessage] as? String ?? "未知 AppleScript 错误"
                        let errNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
                        
                        if errNumber == -1743 || errStr.localizedCaseInsensitiveContains("not authorized") {
                            self?.needsPrivacySettingsGuide = true
                            self?.errorMessage = "尚未授予邮件访问权限。macOS 要求允许「团队工作台」控制「邮件」App。\n\n如已弹出系统提示请点击「允许」；或点击下方「打开系统设置」前往「隐私与安全性 -> 自动化」，勾选「团队工作台」下的「邮件」。"
                        } else {
                            self?.errorMessage = "访问邮件应用遇到问题: \(errStr)"
                        }
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                guard let descriptor = descriptor else {
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        self?.lastSyncTime = Date()
                        self?.lastSyncResult = "工作台已是最新状态，未发现新邮件。"
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                let count = descriptor.numberOfItems
                guard count > 0 else {
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        self?.lastSyncTime = Date()
                        self?.lastSyncResult = isIncremental ? "工作台已是最新状态，未发现新邮件。" : "未在邮件 App 中检索到今年1月以来的符合条件的 Green Email 邮件。"
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                var newlyImportedCount = 0
                var updatedCount = 0
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                df.locale = Locale(identifier: "en_US_POSIX")
                
                for i in 1...count {
                    guard let itemDesc = descriptor.atIndex(i) else { continue }
                    // Descriptor list items are 1-indexed in AppleEvents: {msgID, msgSubj, msgSender, msgDate, msgPlain, rawSrc}
                    let rawTitle = itemDesc.atIndex(2)?.stringValue ?? ""
                    let sender = itemDesc.atIndex(3)?.stringValue ?? ""
                    let dateString = itemDesc.atIndex(4)?.stringValue ?? ""
                    let rawPlain = itemDesc.atIndex(5)?.stringValue ?? ""
                    let rawMIMESource = itemDesc.atIndex(6)?.stringValue ?? ""
                    
                    // Strict validation
                    let lowerTitle = rawTitle.lowercased()
                    let excludedPrefixes = ["re:", "re：", "fwd:", "fwd：", "fw:", "fw：", "回复:", "回复：", "回覆:", "回覆：", "转发:", "转发：", "轉寄:", "轉寄："]
                    var isExcluded = false
                    for p in excludedPrefixes {
                        if lowerTitle.hasPrefix(p) {
                            isExcluded = true
                            break
                        }
                    }
                    if isExcluded { continue }
                    
                    if !sender.lowercased().contains("ic_gc_aha_sacs@apple.com") {
                        continue
                    }
                    
                    // Clean title and plain text content
                    let cleanTitle = Self.cleanGreenEmailTitle(rawTitle)
                    let cleanedPlain = Self.cleanGreenEmailPlainText(rawPlain)
                    
                    // Extract high-fidelity HTML directly from the in-memory rawMIMESource
                    var extractedHTML: String? = nil
                    if !rawMIMESource.isEmpty {
                        if let parsedHTML = MIMEHTMLParser.extractHTML(from: rawMIMESource) {
                            extractedHTML = Self.cleanGreenEmailHTMLContent(parsedHTML)
                        }
                    }
                    
                    // Parse date accurately from ISO format
                    var parsedDate = Date()
                    if let date = df.date(from: dateString) {
                        parsedDate = date
                    } else if let isoDate = ISO8601DateFormatter().date(from: dateString) {
                        parsedDate = isoDate
                    }
                    
                    DispatchQueue.main.async {
                        // Check if already exists in store by cleanTitle or rawTitle
                        if let existingIndex = store.newsArticles.firstIndex(where: { $0.title == cleanTitle || $0.title == rawTitle }) {
                            store.newsArticles[existingIndex].title = cleanTitle
                            store.newsArticles[existingIndex].publishDate = parsedDate
                            store.newsArticles[existingIndex].content = cleanedPlain
                            if extractedHTML != nil {
                                store.newsArticles[existingIndex].htmlContent = extractedHTML
                            }
                            updatedCount += 1
                        } else {
                            let newArticle = NewsArticle(
                                title: cleanTitle,
                                summary: "",
                                content: cleanedPlain,
                                htmlContent: extractedHTML,
                                author: "AHA / SACS 团队",
                                source: "ic_gc_aha_sacs@apple.com",
                                publishDate: parsedDate,
                                category: .greenEmail,
                                tags: ["Green Email", "近期重要内容"],
                                isBookmarked: false,
                                readCount: 0,
                                estimatedReadMinutes: max(2, cleanedPlain.count / 300),
                                comments: []
                            )
                            store.newsArticles.append(newArticle)
                            newlyImportedCount += 1
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self?.isSyncing = false
                    self?.lastSyncTime = Date()
                    
                    // Prune Green Email messages older than 1 year
                    store.newsArticles.removeAll { article in
                        article.category == .greenEmail && article.publishDate < oneYearAgo
                    }
                    
                    store.newsArticles.sort { $0.publishDate > $1.publishDate }
                    store.saveData()
                    
                    if newlyImportedCount > 0 {
                        self?.lastSyncResult = "同步完成！已成功发现并写入 \(newlyImportedCount) 封最新 Green Email。"
                    } else if updatedCount > 0 {
                        self?.lastSyncResult = "同步完成！已刷新 \(updatedCount) 封已有邮件的高保真排版。"
                    } else {
                        self?.lastSyncResult = "工作台已是最新状态，未发现新邮件。"
                    }
                    
                    continuation.resume(returning: newlyImportedCount)
                }
            }
        }
    }
}
