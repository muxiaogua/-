//
//  NPIMailSyncService.swift
//  团队工作台
//

import Foundation
import Combine
import AppKit

@MainActor
public class NPIMailSyncService: ObservableObject {
    public static let shared = NPIMailSyncService()
    
    private let lastSyncTimeStorageKey = "workbench_last_npi_mail_sync_date"
    private let lastSyncedByStorageKey = "workbench_last_npi_mail_synced_by"
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncResult: String?
    @Published public var errorMessage: String?
    @Published public var needsPrivacySettingsGuide: Bool = false
    @Published public var lastSyncedBy: String? {
        didSet {
            if let name = lastSyncedBy {
                UserDefaults.standard.set(name, forKey: lastSyncedByStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSyncedByStorageKey)
            }
        }
    }
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
        self.lastSyncedBy = UserDefaults.standard.string(forKey: lastSyncedByStorageKey)
    }
    
    public func openAutomationPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Syncs NPI communications from Apple Mail.app.
    /// Strict conditions required:
    /// 1. Sender MUST be fy26_gc_npicomms@apple.com
    /// 2. Subject MUST contain 🔥 [FY26 GC NPI] (or [FY26 GC NPI])
    public func syncNPIMailsFromMail(into store: WorkbenchStore, forceFullSync: Bool = false) async -> Int {
        isSyncing = true
        errorMessage = nil
        lastSyncResult = nil
        needsPrivacySettingsGuide = false
        
        let scriptSource = """
        tell application "Mail"
            set matchData to {}
            set targetSender to "fy26_gc_npicomms@apple.com"
            set cutoffDate to ((current date) - (365 * days))
            
            -- 1. 优先极速检索收件箱
            tell inbox
                try
                    set msgs to (messages whose sender contains targetSender and date received ≥ cutoffDate)
                    repeat with msg in msgs
                        set msgSender to sender of msg
                        set msgSubj to subject of msg
                        
                        set isSenderMatch to (msgSender contains targetSender)
                        set isSubjMatch to (msgSubj contains "🔥" and msgSubj contains "[FY26 GC NPI]" and msgSubj does not contain "[TEST NPI]" and msgSubj does not contain "联调测试")
                        
                        if isSenderMatch and isSubjMatch then
                            -- 过滤回复与转发
                            set isExcluded to false
                            if msgSubj starts with "Re:" or msgSubj starts with "RE:" or msgSubj starts with "re:" or msgSubj starts with "re：" or msgSubj starts with "RE：" or msgSubj starts with "Re：" then
                                set isExcluded to true
                            else if msgSubj starts with "Fwd:" or msgSubj starts with "FWD:" or msgSubj starts with "fwd:" or msgSubj starts with "Fw:" or msgSubj starts with "FW:" or msgSubj starts with "fw:" then
                                set isExcluded to true
                            else if msgSubj starts with "回复:" or msgSubj starts with "回复：" or msgSubj starts with "转发:" or msgSubj starts with "转发：" then
                                set isExcluded to true
                            end if
                            
                            if not isExcluded then
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
                                
                                set msgID to ""
                                try
                                    set msgID to (message id of msg as string)
                                end try
                                if msgID is "" then
                                    set msgID to (id of msg as string)
                                end if
                                set msgPlain to (content of msg)
                                
                                set rawSrc to ""
                                try
                                    with timeout of 20 seconds
                                        set rawSrc to (source of msg)
                                    end timeout
                                end try
                                
                                set end of matchData to {msgID, msgSubj, msgSender, msgDate, msgPlain, rawSrc}
                            end if
                        end if
                    end repeat
                end try
            end tell
            
            -- 2. 若收件箱未查到，再检查主要邮箱
            if (count of matchData) is 0 then
                repeat with acc in accounts
                    try
                        repeat with mb in mailboxes of acc
                            try
                                set mbName to name of mb
                                if mbName is not "Trash" and mbName is not "Junk" and mbName is not "Drafts" and mbName is not "Sent Messages" and mbName is not "已删除" and mbName is not "已发送" and mbName is not "草稿" and mbName is not "垃圾邮件" then
                                    set msgs to (messages of mb whose sender contains targetSender and date received ≥ cutoffDate)
                                    repeat with msg in msgs
                                        set msgSender to sender of msg
                                        set msgSubj to subject of msg
                                        
                                        if (msgSender contains targetSender) and (msgSubj contains "🔥" and msgSubj contains "[FY26 GC NPI]") then
                                            set isExcluded to false
                                            if msgSubj starts with "Re:" or msgSubj starts with "RE:" or msgSubj starts with "re:" or msgSubj starts with "Fwd:" or msgSubj starts with "FWD:" or msgSubj starts with "fwd:" or msgSubj starts with "回复:" or msgSubj starts with "转发:" then
                                                set isExcluded to true
                                            end if
                                            
                                            if not isExcluded then
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
                                                
                                                set msgID to ""
                                                try
                                                    set msgID to (message id of msg as string)
                                                end try
                                                if msgID is "" then
                                                    set msgID to (id of msg as string)
                                                end if
                                                set msgPlain to (content of msg)
                                                
                                                set rawSrc to ""
                                                try
                                                    with timeout of 20 seconds
                                                        set rawSrc to (source of msg)
                                                    end timeout
                                                end try
                                                
                                                set end of matchData to {msgID, msgSubj, msgSender, msgDate, msgPlain, rawSrc}
                                            end if
                                        end if
                                    end repeat
                                end if
                            end try
                        end repeat
                    end try
                end repeat
            end if
            
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
                        self?.lastSyncResult = "未在邮件应用中检索到符合条件的 NPI 邮件。"
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                let count = descriptor.numberOfItems
                guard count > 0 else {
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        self?.lastSyncTime = Date()
                        self?.lastSyncResult = "已是最新状态，未检索到来自 fy26_gc_npicomms@apple.com 的 [FY26 GC NPI] 邮件。"
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                var newlyImportedCount = 0
                var updatedCount = 0
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                df.locale = Locale(identifier: "en_US_POSIX")
                
                var processedArticles: [NewsArticle] = []
                
                for i in 1...count {
                    guard let itemDesc = descriptor.atIndex(i) else { continue }
                    let rawMsgID = itemDesc.atIndex(1)?.stringValue ?? ""
                    let rawTitle = itemDesc.atIndex(2)?.stringValue ?? ""
                    let sender = itemDesc.atIndex(3)?.stringValue ?? ""
                    let dateString = itemDesc.atIndex(4)?.stringValue ?? ""
                    let rawPlain = itemDesc.atIndex(5)?.stringValue ?? ""
                    let rawMIMESource = itemDesc.atIndex(6)?.stringValue ?? ""
                    
                    let lowerTitle = rawTitle.lowercased()
                    let lowerSender = sender.lowercased()
                    
                    // 严格双重条件校验（正式投产：彻底剔除临时联调测试邮件）
                    if rawTitle.contains("[TEST NPI]") || rawTitle.contains("联调测试") {
                        continue
                    }
                    let isSenderMatch = lowerSender.contains("fy26_gc_npicomms@apple.com")
                    guard isSenderMatch else { continue }
                    
                    let isSubjMatch = rawTitle.contains("🔥") && (rawTitle.contains("[FY26 GC NPI]") || lowerTitle.contains("fy26 gc npi"))
                    guard isSubjMatch else { continue }
                    
                    // 排除回复与转发
                    let excludedPrefixes = ["re:", "re：", "fwd:", "fwd：", "fw:", "fw：", "回复:", "回复：", "转发:", "转发："]
                    var isExcluded = false
                    for p in excludedPrefixes {
                        if lowerTitle.hasPrefix(p) {
                            isExcluded = true
                            break
                        }
                    }
                    if isExcluded { continue }
                    
                    // 提取完整 HTML 并由 MIMEHTMLParser 进行 Quoted-Printable 还原与 Base64 图片内联 (支持纯文本与附件图片兜底)
                    var finalHTML: String? = nil
                    if !rawMIMESource.isEmpty {
                        finalHTML = MIMEHTMLParser.extractHTML(from: rawMIMESource, fallbackPlainText: rawPlain)
                        if rawTitle.contains("新品一览") && dateString.contains("10:29") {
                            try? rawMIMESource.write(toFile: "/tmp/npi_raw_1029.txt", atomically: true, encoding: .utf8)
                        }
                    }
                    
                    var parsedDate = Date()
                    if let date = df.date(from: dateString) {
                        parsedDate = date
                    } else if let isoDate = ISO8601DateFormatter().date(from: dateString) {
                        parsedDate = isoDate
                    }
                    
                    let article = NewsArticle(
                        title: rawTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        summary: String(rawPlain.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines),
                        content: rawPlain.trimmingCharacters(in: .whitespacesAndNewlines),
                        htmlContent: finalHTML,
                        author: "GC NPI Comms 团队",
                        source: "fy26_gc_npicomms@apple.com",
                        publishDate: parsedDate,
                        category: .greenEmail,
                        tags: ["NPI", "FY26 GC NPI", "重点通报"],
                        isBookmarked: false,
                        readCount: 0,
                        estimatedReadMinutes: max(2, rawPlain.count / 300),
                        originalURL: "mail://id/\(rawMsgID)",
                        comments: []
                    )
                    processedArticles.append(article)
                }
                
                DispatchQueue.main.async {
                    for article in processedArticles {
                        // 智能去重：优先匹配全局 RFC822 Message-ID，次优先匹配同一天内相同标题 + 相同正文
                        if let existingIdx = store.npiEmails.firstIndex(where: {
                            if let idA = $0.originalURL, let idB = article.originalURL, !idA.isEmpty && !idB.isEmpty {
                                if idA == idB { return true }
                            }
                            if $0.title == article.title && Calendar.current.isDate($0.publishDate, inSameDayAs: article.publishDate) {
                                let sA = $0.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                let sB = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !sA.isEmpty && !sB.isEmpty && (sA == sB || sA.hasPrefix(sB.prefix(60)) || sB.hasPrefix(sA.prefix(60))) {
                                    return true
                                }
                                if abs($0.publishDate.timeIntervalSince(article.publishDate)) < 120 {
                                    return true
                                }
                            }
                            return false
                        }) {
                            store.npiEmails[existingIdx].publishDate = article.publishDate
                            store.npiEmails[existingIdx].content = article.content
                            if article.htmlContent != nil {
                                store.npiEmails[existingIdx].htmlContent = article.htmlContent
                            }
                            store.npiEmails[existingIdx].originalURL = article.originalURL
                            updatedCount += 1
                        } else {
                            store.npiEmails.append(article)
                            newlyImportedCount += 1
                        }
                    }
                    
                    // 自动去重现有历史数据（清理同日内误存的重复项，安全保留跨日期的独立邮件）
                    var cleanedEmails: [NewsArticle] = []
                    for item in store.npiEmails {
                        let isDuplicate = cleanedEmails.contains(where: { existing in
                            if let idA = existing.originalURL, let idB = item.originalURL, !idA.isEmpty && !idB.isEmpty {
                                if idA == idB { return true }
                            }
                            if existing.title == item.title && Calendar.current.isDate(existing.publishDate, inSameDayAs: item.publishDate) {
                                let sA = existing.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                let sB = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !sA.isEmpty && !sB.isEmpty && (sA == sB || sA.hasPrefix(sB.prefix(60)) || sB.hasPrefix(sA.prefix(60))) {
                                    return true
                                }
                            }
                            return false
                        })
                        if !isDuplicate {
                            cleanedEmails.append(item)
                        }
                    }
                    
                    store.npiEmails = cleanedEmails.sorted { $0.publishDate > $1.publishDate }
                    store.saveNpiEmails()
                    
                    self?.isSyncing = false
                    let now = Date()
                    self?.lastSyncTime = now
                    self?.lastSyncedBy = store.currentUser.name
                    
                    // Save sync meta to shared folder if connected
                    if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
                        DispatchQueue.global(qos: .utility).async {
                            let metaURL = baseURL.appendingPathComponent("npi_emails/sync_meta.json")
                            let meta = SyncMetaRecord(lastSyncTime: now, syncedBy: store.currentUser.name)
                            if let data = try? JSONEncoder().encode(meta) {
                                try? data.write(to: metaURL)
                            }
                        }
                    }
                    
                    if newlyImportedCount > 0 {
                        self?.lastSyncResult = "同步完成！当前共收录 \(cleanedEmails.count) 封 NPI 重点邮件（新导入 \(newlyImportedCount) 封）。"
                    } else {
                        self?.lastSyncResult = "已成功刷新 \(cleanedEmails.count) 封 NPI 重点邮件至最新排版。"
                    }
                    
                    continuation.resume(returning: newlyImportedCount)
                }
            }
        }
    }
}
