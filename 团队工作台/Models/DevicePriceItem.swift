//
//  DevicePriceItem.swift
//  团队工作台
//
//  设备报价数据模型 - 严格支持 REST API 接口实时拉取与标准格式解析
//

import Foundation

public struct DeviceRepairPartPrice: Identifiable, Codable, Hashable {
    public var id: String { "\(partName)_\(outOfWarrantyPrice)" }
    public var partName: String              // 部件名称（如：屏幕、电池、背面玻璃、主板等）
    public var outOfWarrantyPrice: String     // 保外维修预估价格（RMB / 格式化文本）
    public var appleCarePrice: String?        // AppleCare+ 权益价格（如有）
    public var note: String?                  // 备注说明
    
    public init(partName: String, outOfWarrantyPrice: String, appleCarePrice: String? = nil, note: String? = nil) {
        self.partName = partName
        self.outOfWarrantyPrice = outOfWarrantyPrice
        self.appleCarePrice = appleCarePrice
        self.note = note
    }
}

public struct DevicePriceItem: Identifiable, Codable, Hashable {
    public var id: String { modelName }
    public var category: String               // 设备品类 (iPhone, iPad, Mac, Watch, AirPods, Other)
    public var modelName: String              // 完整机型名称
    public var parts: [DeviceRepairPartPrice] // 各部件具体报价清单
    public var lastUpdated: Date?             // 同步更新时间
    
    public init(category: String, modelName: String, parts: [DeviceRepairPartPrice] = [], lastUpdated: Date? = Date()) {
        self.category = category
        self.modelName = modelName
        self.parts = parts
        self.lastUpdated = lastUpdated
    }
}

// REST API 统一响应封装
public struct PriceApiResponse: Codable {
    public var code: Int?
    public var message: String?
    public var data: [DevicePriceItem]?
    
    public init(code: Int? = nil, message: String? = nil, data: [DevicePriceItem]? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}
