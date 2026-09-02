//
//  TeamMember.swift
//  团队工作台
//

import Foundation

public struct TeamMember: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var avatarSymbol: String
    
    public init(
        id: UUID = UUID(),
        name: String = "成员",
        avatarSymbol: String = "person.crop.circle.fill"
    ) {
        self.id = id
        self.name = name
        self.avatarSymbol = avatarSymbol
    }
    
    public static let currentUser = TeamMember(
        name: "Beauty",
        avatarSymbol: "person.crop.circle.fill.badge.checkmark"
    )
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarSymbol = try container.decodeIfPresent(String.self, forKey: .avatarSymbol) ?? "person.crop.circle.fill"
    }
}
