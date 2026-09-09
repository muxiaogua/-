//
//  NpiIssueItem.swift
//  团队工作台
//
//

import Foundation

public struct NpiIssueItem: Identifiable, Codable, Hashable {
    public var id: String           // 例如 "IT 489632" 或 "KB 124676"
    public var date: String         // 发布日期，如 "2026-09-05"
    public var productType: String  // 动态产品类别，如 "iOS 26", "iPhone", "Apple 账户", "macOS", "Apple Watch" 等
    public var category: String     // 业务分类
    public var title: String        // 议题标题 / 简述
    public var desc: String         // 问题现象详细描述
    public var guidance: String     // 官方建议/应对措施/临时方案
    public var status: String       // 应对状态："需提交RTA" | "无需RTA" | "积极投票" | "需关注更新" | "已修复"
    public var emailSubject: String // 来源邮件主题
    
    public init(
        id: String,
        date: String,
        productType: String,
        category: String? = nil,
        title: String,
        desc: String,
        guidance: String,
        status: String = "需提交RTA",
        emailSubject: String = ""
    ) {
        self.id = id
        self.date = date
        self.productType = productType
        self.category = category ?? productType
        self.title = title
        self.desc = desc
        self.guidance = guidance
        self.status = status
        self.emailSubject = emailSubject
    }
}
