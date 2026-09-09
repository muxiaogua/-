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
    
    public static var defaultSystemUser: TeamMember {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let shortName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let invalidNames = [
            "testuser", "test", "user", "admin", "administrator", "apple", "mac",
            "macbook", "macbookpro", "macbookair", "用户", "测试", "成员", "beauty"
        ]
        
        let detectedName: String
        // 1. 优先使用合法的系统全名
        if !fullName.isEmpty && !invalidNames.contains(fullName.lowercased()) {
            detectedName = fullName
        }
        // 2. 其次使用合法的系统 shortname (很多员工机器是拼音或工号，如 san_zhang)
        else if !shortName.isEmpty && !invalidNames.contains(shortName.lowercased()) {
            detectedName = shortName
        }
        // 3. 兜底提取主机名（如 "Jason-MacBook-Pro" -> "Jason"）
        else {
            let host = Host.current().localizedName ?? ""
            let cleanHost = host.replacingOccurrences(of: "的 MacBook Pro", with: "")
                .replacingOccurrences(of: "的 MacBook Air", with: "")
                .replacingOccurrences(of: "的 Mac", with: "")
                .replacingOccurrences(of: "'s MacBook Pro", with: "")
                .replacingOccurrences(of: "'s MacBook Air", with: "")
                .replacingOccurrences(of: "'s Mac", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanHost.isEmpty && !invalidNames.contains(cleanHost.lowercased()) {
                detectedName = cleanHost
            } else if !shortName.isEmpty {
                detectedName = shortName // 即使叫 mac 也加上随机特征防止撞车
            } else {
                detectedName = "成员_\(Int.random(in: 100...999))"
            }
        }
        
        return TeamMember(
            name: detectedName,
            avatarSymbol: "person.crop.circle.fill.badge.checkmark"
        )
    }
    
    public static let currentUser = TeamMember.defaultSystemUser
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarSymbol = try container.decodeIfPresent(String.self, forKey: .avatarSymbol) ?? "person.crop.circle.fill"
    }
}
