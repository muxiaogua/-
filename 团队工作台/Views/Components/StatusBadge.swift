//
//  StatusBadge.swift
//  团队工作台
//

import SwiftUI

public struct PriorityBadge: View {
    public let priority: AnnouncementPriority
    
    public init(priority: AnnouncementPriority) {
        self.priority = priority
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(priority.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var badgeColor: Color {
        switch priority {
        case .urgent: return .red
        case .important: return .orange
        case .normal: return .blue
        }
    }
}

public struct CategoryTag: View {
    public let category: NewsCategory
    
    public init(category: NewsCategory) {
        self.category = category
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.iconName)
                .font(.system(size: 9))
            Text(category.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tagColor.opacity(0.12))
        .foregroundColor(tagColor)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    
    private var tagColor: Color {
        switch category {
        case .unread: return .blue
        case .greenEmail: return .green
        case .slackSupport: return .purple
        }
    }
}

public struct TagPill: View {
    public let title: String
    
    public init(title: String) {
        self.title = title
    }
    
    public var body: some View {
        Text("#\(title)")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
