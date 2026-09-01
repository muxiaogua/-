//
//  Announcement.swift
//  团队工作台
//

import Foundation

public enum AnnouncementPriority: String, Codable, CaseIterable, Identifiable {
    case urgent = "紧急"
    case important = "重要"
    case normal = "常规"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .important: return "flag.fill"
        case .normal: return "info.circle.fill"
        }
    }
    
    public var colorName: String {
        switch self {
        case .urgent: return "red"
        case .important: return "orange"
        case .normal: return "blue"
        }
    }
}

public struct Announcement: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var content: String
    public var author: String
    public var department: String
    public var publishDate: Date
    public var priority: AnnouncementPriority
    public var isPinned: Bool
    public var requiresAcknowledgment: Bool
    public var isAcknowledged: Bool
    public var acknowledgedAt: Date?
    public var tags: [String]
    public var externalLink: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        author: String,
        department: String,
        publishDate: Date = Date(),
        priority: AnnouncementPriority = .normal,
        isPinned: Bool = false,
        requiresAcknowledgment: Bool = false,
        isAcknowledged: Bool = false,
        acknowledgedAt: Date? = nil,
        tags: [String] = [],
        externalLink: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.author = author
        self.department = department
        self.publishDate = publishDate
        self.priority = priority
        self.isPinned = isPinned
        self.requiresAcknowledgment = requiresAcknowledgment
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
        self.tags = tags
        self.externalLink = externalLink
    }
}
