//
//  FAQItem.swift
//  团队工作台
//

import Foundation

public struct FAQItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var question: String
    public var answer: String
    public var category: String
    public var tags: [String]
    public var relatedArticleId: String?
    public var author: String
    public var updatedAt: Date
    public var isBookmarked: Bool
    
    public init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        category: String = "常见业务",
        tags: [String] = [],
        relatedArticleId: String? = nil,
        author: String = "团队",
        updatedAt: Date = Date(),
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.category = category
        self.tags = tags
        self.relatedArticleId = relatedArticleId
        self.author = author
        self.updatedAt = updatedAt
        self.isBookmarked = isBookmarked
    }
    
    public static let sampleFAQs: [FAQItem] = []
}
