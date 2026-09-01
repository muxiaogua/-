//
//  GreenEmailContentView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public enum GreenEmailBlockType {
    case scenarioHeader(String)
    case warningNote(String)
    case compactLine(String)
    case regularParagraph(String)
}

public struct GreenEmailBlock: Identifiable {
    public let id = UUID()
    public let type: GreenEmailBlockType
}

public struct GreenEmailContentView: View {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(parseBlocks(from: content)) { block in
                switch block.type {
                case .scenarioHeader(let text):
                    Text(LocalizedStringKey(formatLinks(in: text)))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                        .textSelection(.enabled)
                    
                case .warningNote(let text):
                    HStack(alignment: .top, spacing: 4) {
                        Text(LocalizedStringKey(formatLinks(in: text)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 2)
                    .textSelection(.enabled)
                    
                case .compactLine(let text):
                    Text(LocalizedStringKey(formatLinks(in: text)))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(1.5)
                        .padding(.vertical, 0)
                        .textSelection(.enabled)
                    
                case .regularParagraph(let text):
                    Text(LocalizedStringKey(formatLinks(in: text)))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .padding(.vertical, 2)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            // Handle custom schemes like core:// seamlessly on macOS
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
    
    // MARK: - Block Parser
    
    private func parseBlocks(from rawText: String) -> [GreenEmailBlock] {
        let lines = rawText.components(separatedBy: "\n")
        var blocks: [GreenEmailBlock] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                i += 1
                continue
            }
            
            // 1. Check if Scenario Header (场景一、场景二、场景三、一、二、等)
            if isScenarioHeader(trimmed) {
                blocks.append(GreenEmailBlock(type: .scenarioHeader(trimmed)))
                i += 1
                continue
            }
            
            // 2. Check if Warning / Critical Action in Red (注意：、请不要...、不需要再发起...、请安排回电等)
            if isWarningLine(trimmed) {
                blocks.append(GreenEmailBlock(type: .warningNote(trimmed)))
                i += 1
                continue
            }
            
            // 3. Check if Consecutive Short Checklist / Condition Lines
            if isCompactChecklistLine(trimmed) {
                blocks.append(GreenEmailBlock(type: .compactLine(trimmed)))
                i += 1
                continue
            }
            
            // 4. Regular Paragraph
            blocks.append(GreenEmailBlock(type: .regularParagraph(trimmed)))
            i += 1
        }
        
        return blocks
    }
    
    private func isScenarioHeader(_ text: String) -> Bool {
        let scenarioKeywords = ["场景一", "场景二", "场景三", "场景四", "场景五", "场景六", "场景七", "场景八", "场景九", "场景十", "场景 1", "场景 2", "场景 3", "场景 4", "场景 5", "场景：", "场景:"]
        for kw in scenarioKeywords {
            if text.hasPrefix(kw) || text.contains(kw) {
                return true
            }
        }
        if text.hasPrefix("【") && text.contains("】") {
            return true
        }
        if text.range(of: #"^[一二三四五六七八九十]、"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
    
    private func isWarningLine(_ text: String) -> Bool {
        let warningKeywords = [
            "注意：", "注意:", "【注意】", "⚠️", "重要：", "重要:", "重要提醒：", "重要提醒:", "请注意：", "请注意:",
            "不需要再发起直接的呼出电话",
            "请安排回电",
            "安排回电",
            "SCB",
            "请不要在线上等待",
            "不要在线上等待",
            "严禁", "切勿", "禁止"
        ]
        for kw in warningKeywords {
            if text.contains(kw) { return true }
        }
        return false
    }
    
    private func isCompactChecklistLine(_ text: String) -> Bool {
        if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("·") || text.hasPrefix("*") {
            return true
        }
        if text.range(of: #"^\d+[\.、\)]"#, options: .regularExpression) != nil {
            return true
        }
        // Sub-condition lines like "快速开始卡片不会在源设备（旧设备）上显示"
        if text.contains("不会在") || text.contains("无法在") || text.contains("未在") || text.contains("显示") {
            return true
        }
        return false
    }
    
    // MARK: - Core Link Formatter
    
    /// Converts article numbers like '102659' and raw URLs into clickable Core hyperlinks: core://articleId=102659
    private func formatLinks(in text: String) -> String {
        var formatted = text
        
        // 1. Format 5-6 digit Apple Knowledge Base article numbers into native Core URLs: core://articleId=102659
        let kbPattern = #"(?<=\b)(10\d{4}|20\d{4}|30\d{4}|\d{6})(?=\b)"#
        if let regex = try? NSRegularExpression(pattern: kbPattern) {
            let nsString = formatted as NSString
            let matches = regex.matches(in: formatted, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let matchedNumber = nsString.substring(with: match.range)
                let linkMarkdown = "[\(matchedNumber)](core://articleId=\(matchedNumber))"
                formatted = (formatted as NSString).replacingCharacters(in: match.range, with: linkMarkdown)
            }
        }
        
        // 2. Format HT-prefixed articles like HT201269 into native Core URLs: core://articleId=HT201269
        let htPattern = #"(?<=\b)(HT\d{6})(?=\b)"#
        if let regex = try? NSRegularExpression(pattern: htPattern) {
            let nsString = formatted as NSString
            let matches = regex.matches(in: formatted, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let matchedID = nsString.substring(with: match.range)
                let linkMarkdown = "[\(matchedID)](core://articleId=\(matchedID))"
                formatted = (formatted as NSString).replacingCharacters(in: match.range, with: linkMarkdown)
            }
        }
        
        return formatted
    }
}
