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

public struct AnnouncementAcknowledgment: Identifiable, Codable, Hashable {
    public var id: UUID
    public var memberName: String
    public var department: String
    public var acknowledgedAt: Date
    
    public init(
        id: UUID = UUID(),
        memberName: String,
        department: String = "",
        acknowledgedAt: Date = Date()
    ) {
        self.id = id
        self.memberName = memberName
        self.department = department
        self.acknowledgedAt = acknowledgedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        memberName = try container.decode(String.self, forKey: .memberName)
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        acknowledgedAt = try container.decode(Date.self, forKey: .acknowledgedAt)
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
    public var acknowledgments: [AnnouncementAcknowledgment]
    public var tags: [String]
    public var externalLink: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        author: String,
        department: String = "",
        publishDate: Date = Date(),
        priority: AnnouncementPriority = .normal,
        isPinned: Bool = false,
        requiresAcknowledgment: Bool = false,
        isAcknowledged: Bool = false,
        acknowledgedAt: Date? = nil,
        acknowledgments: [AnnouncementAcknowledgment] = [],
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
        self.acknowledgments = acknowledgments
        self.tags = tags
        self.externalLink = externalLink
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decode(String.self, forKey: .author)
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        publishDate = try container.decode(Date.self, forKey: .publishDate)
        priority = try container.decode(AnnouncementPriority.self, forKey: .priority)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        requiresAcknowledgment = try container.decode(Bool.self, forKey: .requiresAcknowledgment)
        isAcknowledged = try container.decode(Bool.self, forKey: .isAcknowledged)
        acknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .acknowledgedAt)
        acknowledgments = try container.decodeIfPresent([AnnouncementAcknowledgment].self, forKey: .acknowledgments) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        externalLink = try container.decodeIfPresent(String.self, forKey: .externalLink)
    }
}
