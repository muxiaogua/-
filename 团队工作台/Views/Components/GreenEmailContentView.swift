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
    case markdownTable(headers: [String], rows: [[String]])
    case actionNoticeCard(title: String, items: [String])
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
                        
                case .actionNoticeCard(let title, let items):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 6)
                                    Text(LocalizedStringKey(formatLinks(in: item)))
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.vertical, 6)
                    
                case .markdownTable(let headers, let rows):
                    VStack(alignment: .leading, spacing: 0) {
                        // Table Header
                        HStack(spacing: 8) {
                            ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                                Text(header)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        // Table Rows
                        ForEach(Array(rows.enumerated()), id: \.offset) { rIdx, row in
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(Array(row.enumerated()), id: \.offset) { cIdx, cell in
                                    Text(LocalizedStringKey(formatLinks(in: cell)))
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(rIdx % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                            
                            if rIdx < rows.count - 1 {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.vertical, 8)
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
            
            // A. Check if Markdown Table Header line (starts with | and has at least two | separators)
            if trimmed.hasPrefix("|") && trimmed.filter({ $0 == "|" }).count >= 2 {
                // Check next line for | :--- | separator
                if i + 1 < lines.count {
                    let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix("|") && (nextTrimmed.contains("---") || nextTrimmed.contains("-|-")) {
                        let headerCells = trimmed.split(separator: "|", omittingEmptySubsequences: true).map { String($0).trimmingCharacters(in: .whitespaces) }
                        var rowData: [[String]] = []
                        i += 2 // skip header and divider
                        
                        while i < lines.count {
                            let tableLine = lines[i].trimmingCharacters(in: .whitespaces)
                            if !tableLine.hasPrefix("|") || tableLine.isEmpty {
                                break
                            }
                            let cells = tableLine.split(separator: "|", omittingEmptySubsequences: true).map { String($0).trimmingCharacters(in: .whitespaces) }
                            if !cells.isEmpty {
                                rowData.append(cells)
                            }
                            i += 1
                        }
                        
                        blocks.append(GreenEmailBlock(type: .markdownTable(headers: headerCells, rows: rowData)))
                        continue
                    }
                }
            }
            
            // B. Check if Section Header (### 📌 业务操作与流程提醒 或 ### 📋 Records 记录)
            if trimmed.hasPrefix("### ") {
                let headerTitle = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                
                // If it's Actionable Notice Header, look ahead for bullet points and nested lines
                if headerTitle.contains("业务操作") || headerTitle.contains("流程提醒") || headerTitle.contains("注意事项") {
                    var items: [String] = []
                    i += 1
                    var currentItemLines: [String] = []
                    
                    while i < lines.count {
                        let nextL = lines[i]
                        let nextTrimmed = nextL.trimmingCharacters(in: .whitespaces)
                        if nextTrimmed.isEmpty {
                            if !currentItemLines.isEmpty {
                                items.append(currentItemLines.joined(separator: "\n"))
                                currentItemLines.removeAll()
                            }
                            i += 1
                            continue
                        }
                        if nextTrimmed.hasPrefix("### ") || nextTrimmed.hasPrefix("|") {
                            break
                        }
                        if nextTrimmed.hasPrefix("- ") || nextTrimmed.hasPrefix("• ") || nextTrimmed.hasPrefix("* ") {
                            if !currentItemLines.isEmpty {
                                items.append(currentItemLines.joined(separator: "\n"))
                                currentItemLines.removeAll()
                            }
                            let itemText = String(nextTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                            currentItemLines.append(itemText)
                        } else {
                            // Sub-lines (e.g. 1. 2. or details)
                            if !currentItemLines.isEmpty {
                                currentItemLines.append(nextTrimmed)
                            } else {
                                currentItemLines.append(nextTrimmed)
                            }
                        }
                        i += 1
                    }
                    if !currentItemLines.isEmpty {
                        items.append(currentItemLines.joined(separator: "\n"))
                    }
                    
                    if !items.isEmpty {
                        blocks.append(GreenEmailBlock(type: .actionNoticeCard(title: headerTitle, items: items)))
                    } else {
                        blocks.append(GreenEmailBlock(type: .scenarioHeader(headerTitle)))
                    }
                    continue
                } else {
                    blocks.append(GreenEmailBlock(type: .scenarioHeader(headerTitle)))
                    i += 1
                    continue
                }
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
