//
//  NewsArticle.swift
//  团队工作台
//

import Foundation

public enum NewsCategory: String, Codable, CaseIterable, Identifiable {
    case all = "全部资讯"
    case greenEmail = "Green Email"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "newspaper.fill"
        case .greenEmail: return "envelope.fill"
        }
    }
}

public struct NewsComment: Identifiable, Codable, Hashable {
    public var id: UUID
    public var author: String
    public var department: String
    public var content: String
    public var createdAt: Date
    public var avatarSymbol: String
    
    public init(
        id: UUID = UUID(),
        author: String,
        department: String,
        content: String,
        createdAt: Date = Date(),
        avatarSymbol: String = "person.crop.circle.fill"
    ) {
        self.id = id
        self.author = author
        self.department = department
        self.content = content
        self.createdAt = createdAt
        self.avatarSymbol = avatarSymbol
    }
}

public struct NewsArticle: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var content: String
    public var htmlContent: String?
    public var author: String
    public var source: String
    public var publishDate: Date
    public var category: NewsCategory
    public var tags: [String]
    public var isBookmarked: Bool
    public var readCount: Int
    public var estimatedReadMinutes: Int
    public var originalURL: String?
    public var comments: [NewsComment]
    
    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        content: String,
        htmlContent: String? = nil,
        author: String,
        source: String,
        publishDate: Date = Date(),
        category: NewsCategory = .greenEmail,
        tags: [String] = [],
        isBookmarked: Bool = false,
        readCount: Int = 0,
        estimatedReadMinutes: Int = 3,
        originalURL: String? = nil,
        comments: [NewsComment] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.htmlContent = htmlContent
        self.author = author
        self.source = source
        self.publishDate = publishDate
        self.category = category
        self.tags = tags
        self.isBookmarked = isBookmarked
        self.readCount = readCount
        self.estimatedReadMinutes = estimatedReadMinutes
        self.originalURL = originalURL
        self.comments = comments
    }
}
