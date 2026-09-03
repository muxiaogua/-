//
//  TeamPermission.swift
//  团队工作台
//

import Foundation

public struct MemberPermission: Codable, Hashable {
    public var memberName: String
    public var isAdmin: Bool
    public var canPublishAnnouncements: Bool
    public var canSyncData: Bool
    public var updatedAt: Date
    
    public init(
        memberName: String = "",
        isAdmin: Bool = false,
        canPublishAnnouncements: Bool = false,
        canSyncData: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.memberName = memberName
        self.isAdmin = isAdmin
        self.canPublishAnnouncements = canPublishAnnouncements
        self.canSyncData = canSyncData
        self.updatedAt = updatedAt
    }
}

public struct TeamPermissionConfig: Codable {
    public var defaultAdmins: [String] = ["Jason", "Beauty"]
    public var permissions: [String: MemberPermission] = [:]
    public var lastModifiedAt: Date = Date()
    
    public init(
        defaultAdmins: [String] = ["Jason", "Beauty"],
        permissions: [String: MemberPermission] = [:],
        lastModifiedAt: Date = Date()
    ) {
        self.defaultAdmins = defaultAdmins
        self.permissions = permissions
        self.lastModifiedAt = lastModifiedAt
    }
}
