//
//  SharedKnowledgeItem.swift
//  团队工作台
//

import Foundation
import SwiftUI

// MARK: - 知识文章专区类型 (知识点 vs 精益求精深度案例)

public enum KnowledgeArticleKind: String, Codable, CaseIterable, Identifiable {
    case standardSOP = "知识点"
    case jingYiQiuJing = "精益求精"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .standardSOP: return "book.fill"
        case .jingYiQiuJing: return "flame.circle.fill"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .standardSOP: return .blue
        case .jingYiQiuJing: return .orange
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "精益求精" {
            self = .jingYiQiuJing
        } else {
            self = .standardSOP
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - 知识库固定分类枚举

public enum KnowledgeCategory: String, CaseIterable, Identifiable, Codable {
    case all = "全部"
    case iOS = "iOS"
    case mac = "Mac"
    case watch = "Watch"
    case airPods = "AirPods"
    case accessibility = "辅助功能"
    case general = "通用经验"
    
    public var id: String { rawValue }
    
    public static var selectableCases: [KnowledgeCategory] {
        [.iOS, .mac, .watch, .airPods, .accessibility, .general]
    }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .iOS: return "iphone"
        case .mac: return "laptopcomputer"
        case .watch: return "applewatch"
        case .airPods: return "airpodspro"
        case .accessibility: return "accessibility"
        case .general: return "lightbulb.fill"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .all: return .primary
        case .iOS: return .blue
        case .mac: return .purple
        case .watch: return .orange
        case .airPods: return .teal
        case .accessibility: return .green
        case .general: return .indigo
        }
    }
}

// MARK: - 兼容旧版小节模型 (用于平滑解码)

public struct KnowledgeSection: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var body: String
    
    public init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

// MARK: - 知识库评论留言

public struct KnowledgeComment: Identifiable, Codable, Hashable {
    public var id: UUID
    public var author: String
    public var content: String
    public var createdAt: Date
    
    public init(id: UUID = UUID(), author: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.author = author
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - 精益求精参考文章与Core协议关联模型

public struct KnowledgeReferenceLink: Identifiable, Codable, Hashable {
    public var id: UUID
    public var urlOrCoreId: String  // 例如 "core://articleId=12345678" 或 "https://..."
    public var title: String        // 例如 "iPhone 无法激活疑难排查"
    
    public init(id: UUID = UUID(), urlOrCoreId: String, title: String = "") {
        self.id = id
        self.urlOrCoreId = urlOrCoreId
        self.title = title
    }
    
    public var isCoreProtocol: Bool {
        urlOrCoreId.lowercased().hasPrefix("core://")
    }
    
    public var coreArticleId: String? {
        if let range = urlOrCoreId.range(of: "core://articleId=", options: .caseInsensitive) {
            let num = String(urlOrCoreId[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return num.isEmpty ? nil : num
        }
        return nil
    }
    
    public var displayTitle: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            return cleanTitle
        }
        if let coreId = coreArticleId {
            return "Core 文章 (ID: \(coreId))"
        }
        return urlOrCoreId
    }
}

// MARK: - 知识库完整文章数据模型 (同时支持实操SOP与精益求精深度案例)

public struct SharedKnowledgeArticle: Identifiable, Codable, Hashable {
    public var id: UUID
    public var kind: KnowledgeArticleKind          // 实操SOP or 精益求精
    public var title: String
    public var category: KnowledgeCategory
    public var tags: [String]
    public var summary: String
    
    // 解决方案 (SOP 与 精益求精共用核心)
    public var solution: String
    
    // 精益求精专属深度字段
    public var caseId: String                     // 案例号，如 "Case 102488921"
    public var deviceAndOS: String                // 涉及机型/OS版本，如 "iPhone 16 Pro · iOS 26.0"
    public var faultBackground: String            // 故障背景：顾客诉求与异常现象
    public var troubleshootingLogic: String       // 排查思路：分析与逻辑推导
    public var screenshotsBase64: [String]        // 相关截图：Base64编码，支持全员云端无缝同步
    public var hasSentGroupMail: Bool             // 是否已通过邮件发送至团队群组
    
    public var keyTips: [String]
    public var referenceArticles: [KnowledgeReferenceLink] // 参考文章：支持多条知识库/HT/Core协议及文章标题
    public var author: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var helpfulUserNames: [String]
    public var comments: [KnowledgeComment]
    
    public init(
        id: UUID = UUID(),
        kind: KnowledgeArticleKind = .standardSOP,
        title: String,
        category: KnowledgeCategory,
        tags: [String] = [],
        summary: String = "",
        solution: String = "",
        caseId: String = "",
        deviceAndOS: String = "",
        faultBackground: String = "",
        troubleshootingLogic: String = "",
        screenshotsBase64: [String] = [],
        hasSentGroupMail: Bool = false,
        keyTips: [String] = [],
        referenceArticles: [KnowledgeReferenceLink] = [],
        author: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        helpfulUserNames: [String] = [],
        comments: [KnowledgeComment] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.category = category
        self.tags = tags
        self.summary = summary
        self.solution = solution
        self.caseId = caseId
        self.deviceAndOS = deviceAndOS
        self.faultBackground = faultBackground
        self.troubleshootingLogic = troubleshootingLogic
        self.screenshotsBase64 = screenshotsBase64
        self.hasSentGroupMail = hasSentGroupMail
        self.keyTips = keyTips
        self.referenceArticles = referenceArticles
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.helpfulUserNames = helpfulUserNames
        self.comments = comments
    }
    
    enum CodingKeys: String, CodingKey {
        case id, kind, title, category, tags, summary, solution, sections
        case caseId, deviceAndOS, faultBackground, troubleshootingLogic, screenshotsBase64, hasSentGroupMail
        case keyTips, referenceArticles, author, createdAt, updatedAt, isPinned, helpfulUserNames, comments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decodeIfPresent(KnowledgeArticleKind.self, forKey: .kind) ?? .standardSOP
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(KnowledgeCategory.self, forKey: .category)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        
        if let directSolution = try container.decodeIfPresent(String.self, forKey: .solution) {
            solution = directSolution
        } else if let oldSections = try container.decodeIfPresent([KnowledgeSection].self, forKey: .sections) {
            solution = oldSections.map { sec in
                sec.title.isEmpty ? sec.body : "\(sec.title)\n\(sec.body)"
            }.joined(separator: "\n\n")
        } else {
            solution = ""
        }
        
        caseId = try container.decodeIfPresent(String.self, forKey: .caseId) ?? ""
        deviceAndOS = try container.decodeIfPresent(String.self, forKey: .deviceAndOS) ?? ""
        faultBackground = try container.decodeIfPresent(String.self, forKey: .faultBackground) ?? ""
        troubleshootingLogic = try container.decodeIfPresent(String.self, forKey: .troubleshootingLogic) ?? ""
        screenshotsBase64 = try container.decodeIfPresent([String].self, forKey: .screenshotsBase64) ?? []
        hasSentGroupMail = try container.decodeIfPresent(Bool.self, forKey: .hasSentGroupMail) ?? false
        
        keyTips = try container.decodeIfPresent([String].self, forKey: .keyTips) ?? []
        
        // 兼容解码：支持新的 [KnowledgeReferenceLink] 以及旧版 [String]
        if let links = try? container.decodeIfPresent([KnowledgeReferenceLink].self, forKey: .referenceArticles) {
            referenceArticles = links
        } else if let strings = try? container.decodeIfPresent([String].self, forKey: .referenceArticles) {
            referenceArticles = strings.map { str in
                KnowledgeReferenceLink(urlOrCoreId: str, title: "")
            }
        } else {
            referenceArticles = []
        }
        
        author = try container.decode(String.self, forKey: .author)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        helpfulUserNames = try container.decodeIfPresent([String].self, forKey: .helpfulUserNames) ?? []
        comments = try container.decodeIfPresent([KnowledgeComment].self, forKey: .comments) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(summary, forKey: .summary)
        try container.encode(solution, forKey: .solution)
        try container.encode(caseId, forKey: .caseId)
        try container.encode(deviceAndOS, forKey: .deviceAndOS)
        try container.encode(faultBackground, forKey: .faultBackground)
        try container.encode(troubleshootingLogic, forKey: .troubleshootingLogic)
        try container.encode(screenshotsBase64, forKey: .screenshotsBase64)
        try container.encode(hasSentGroupMail, forKey: .hasSentGroupMail)
        try container.encode(keyTips, forKey: .keyTips)
        try container.encode(referenceArticles, forKey: .referenceArticles)
        try container.encode(author, forKey: .author)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(helpfulUserNames, forKey: .helpfulUserNames)
        try container.encode(comments, forKey: .comments)
    }
}
