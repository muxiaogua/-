//
//  TeamMember.swift
//  团队工作台
//

import Foundation

public struct TeamMember: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var role: String
    public var department: String
    public var avatarSymbol: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        role: String,
        department: String,
        avatarSymbol: String = "person.crop.circle.fill"
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.department = department
        self.avatarSymbol = avatarSymbol
    }
    
    public static let currentUser = TeamMember(
        name: "亮亮",
        role: "核心成员 / 架构设计",
        department: "产研创新中心",
        avatarSymbol: "person.crop.circle.fill.badge.checkmark"
    )
}
