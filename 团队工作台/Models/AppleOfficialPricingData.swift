//
//  AppleOfficialPricingData.swift
//  团队工作台
//
//  Apple 官方全系产品服务与维修估价数据库
//  自包含纯 Swift 数据仓库（不依赖外部 HTML 文件，完全脱机独立运行）
//  支持后续从更新的 HTML / JSON 文件一键动态加载与比对变动
//

import Foundation
import SwiftUI
import Combine

// MARK: - Product Category

public enum OfficialCategory: String, CaseIterable, Identifiable, Codable {
    case iphone = "iPhone"
    case ipad = "iPad"
    case mac = "Mac"
    case watch = "Apple Watch"
    case airpods = "AirPods"
    case other = "其他产品"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .iphone: return "iphone"
        case .ipad: return "ipad"
        case .mac: return "laptopcomputer"
        case .watch: return "applewatch"
        case .airpods: return "airpods.pro"
        case .other: return "display.2"
        }
    }
}

// MARK: - Pricing Models

public struct OfficialPartItem: Identifiable, Codable, Hashable {
    public var id: String { partName }
    public var partName: String              // 部件 / 故障类型名称
    public var officialOOWPrice: String       // 官网保外预估价格 (如 "2,698" 或 "由技术人员诊断后报价")
    public var isExactPrice: Bool             // 是否为明码标价
    public var officialACPrice: String        // 官网 AppleCare+ 权益价格 (如 "188", "799", "0 (免费)")
    public var note: String                   // 官网对应说明
    public var iconName: String
    public var colorName: String
    
    public init(
        partName: String,
        officialOOWPrice: String,
        isExactPrice: Bool = true,
        officialACPrice: String,
        note: String,
        iconName: String,
        colorName: String = "blue"
    ) {
        self.partName = partName
        self.officialOOWPrice = officialOOWPrice
        self.isExactPrice = isExactPrice
        self.officialACPrice = officialACPrice
        self.note = note
        self.iconName = iconName
        self.colorName = colorName
    }
}

public struct OfficialProductModel: Identifiable, Codable, Hashable {
    public var id: String { modelName }
    public var category: OfficialCategory
    public var seriesName: String
    public var modelName: String
    public var parts: [OfficialPartItem]
    
    public init(category: OfficialCategory, seriesName: String = "", modelName: String, parts: [OfficialPartItem]) {
        self.category = category
        self.seriesName = seriesName
        self.modelName = modelName
        self.parts = parts
    }
}

// MARK: - AppleCare+ 购买价格模型

public struct AppleCarePurchaseItem: Identifiable, Codable, Hashable {
    public var id: String { modelName }
    public var category: OfficialCategory
    public var seriesName: String
    public var modelName: String
    public var termYears: Int           // 保障年限（2 年或 3 年）
    public var priceAmount: Int         // 价格数值
    public var priceDisplay: String     // 格式化价格，如 "RMB 1,199"
    public var features: [String]       // 核心权益点
    public var note: String
    
    public init(
        category: OfficialCategory,
        seriesName: String = "",
        modelName: String,
        termYears: Int,
        priceAmount: Int,
        priceDisplay: String,
        features: [String] = [],
        note: String = "全额付款购买官方保障"
    ) {
        self.category = category
        self.seriesName = seriesName
        self.modelName = modelName
        self.termYears = termYears
        self.priceAmount = priceAmount
        self.priceDisplay = priceDisplay
        self.features = features
        self.note = note
    }
}

// MARK: - Price Diff Item (价格变动比对项)

public struct PriceDiffRecord: Identifiable, Hashable {
    public var id = UUID()
    public var modelName: String
    public var category: OfficialCategory
    public var partName: String
    public var oldPrice: String
    public var newPrice: String
    public var diffAmount: Int?
    public var statusDescription: String
}

// MARK: - Database Manager

public class AppleOfficialPricingData: ObservableObject {
    public static let shared = AppleOfficialPricingData()
    
    @Published public var lastUpdated: String = "2026-09-08"
    @Published public var iphoneList: [OfficialProductModel] = []
    @Published public var ipadList: [OfficialProductModel] = []
    @Published public var macList: [OfficialProductModel] = []
    @Published public var watchList: [OfficialProductModel] = []
    @Published public var airpodsList: [OfficialProductModel] = []
    @Published public var otherList: [OfficialProductModel] = []
    
    // AppleCare+ 购买价格列表
    @Published public var appleCarePurchaseList: [AppleCarePurchaseItem] = []
    
    // 最近一次比对结果
    @Published public var recentDiffRecords: [PriceDiffRecord] = []
    @Published public var isLiveSyncing: Bool = false
    @Published public var liveSyncProgressText: String = ""
    @Published public var isAutoMonitoringEnabled: Bool = true
    @Published public var lastAutoCheckTime: Date? = nil
    
    private let userDefaultsKey = "CustomImportedApplePricingDatabase_v1"
    private let autoMonitorKey = "ApplePricingAutoMonitorEnabled_v1"
    private let lastCheckKey = "ApplePricingLastAutoCheckTime_v1"
    private var timer: Timer? = nil
    
    public init() {
        self.isAutoMonitoringEnabled = UserDefaults.standard.object(forKey: autoMonitorKey) as? Bool ?? true
        if let ts = UserDefaults.standard.object(forKey: lastCheckKey) as? Double {
            self.lastAutoCheckTime = Date(timeIntervalSince1970: ts)
        }
        loadInitialDatabase()
        startPeriodicMonitorTimer()
    }
    
    public func products(for category: OfficialCategory) -> [OfficialProductModel] {
        switch category {
        case .iphone: return iphoneList
        case .ipad: return ipadList
        case .mac: return macList
        case .watch: return watchList
        case .airpods: return airpodsList
        case .other: return otherList
        }
    }
    
    // MARK: - 加载数据优先级：用户持久化缓存 > Bundle 内置 JSON > 纯代码内嵌种子
    public func loadInitialDatabase() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey) {
            if parseAndApplyDatabase(from: savedData, recordDiff: false) {
                return
            }
        }
        
        // 尝试从 App Bundle 中加载 AppleRepairPriceDatabase.json
        if let bundleUrl = Bundle.main.url(forResource: "AppleRepairPriceDatabase", withExtension: "json"),
           let data = try? Data(contentsOf: bundleUrl) {
            if parseAndApplyDatabase(from: data, recordDiff: false) {
                return
            }
        }
        
        // 兜底直接构建基础 iPhone / Mac 数据
        buildFallbackData()
    }
    
    // MARK: - 动态导入更新 (支持从新导出的 JSON 或 HTML 文件中更新)
    @discardableResult
    public func importFromFile(url: URL) -> Result<Int, Error> {
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            var jsonData: Data?
            
            if url.pathExtension.lowercased() == "json" {
                jsonData = fileContent.data(using: .utf8)
            } else {
                // 如果用户提供的是新的 HTML 文件，提取内嵌各品类 JSON
                if let extracted = extractJsonFromHtml(fileContent) {
                    jsonData = extracted
                }
            }
            
            guard let validData = jsonData else {
                return .failure(NSError(domain: "ApplePricingData", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法识别文件内容为有效的 Apple 价格数据"]))
            }
            
            let success = parseAndApplyDatabase(from: validData, recordDiff: true)
            if success {
                UserDefaults.standard.set(validData, forKey: userDefaultsKey)
                return .success(recentDiffRecords.count)
            } else {
                return .failure(NSError(domain: "ApplePricingData", code: 2, userInfo: [NSLocalizedDescriptionKey: "价格数据解析格式不匹配"]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - 实时在线从 Apple 官网爬取最新维修价格并生成差价报告
    @MainActor
    public func fetchLatestFromOfficialWebsite() async -> Result<Int, Error> {
        isLiveSyncing = true
        liveSyncProgressText = "正在连接 Apple 官方维修支持服务器..."
        
        let categoriesToFetch: [(key: String, tag: String, ref: String, label: String)] = [
            ("iphone", "TAG_1754518739895", "https://support.apple.com/zh-cn/iphone/repair", "iPhone"),
            ("ipad", "TAG_1750382034263", "https://support.apple.com/zh-cn/ipad/repair", "iPad"),
            ("mac", "TAG_1753920674365", "https://support.apple.com/zh-cn/mac-laptops/repair", "Mac 笔记本与台式机"),
            ("watch", "TAG_1755238435489", "https://support.apple.com/zh-cn/watch/repair", "Apple Watch"),
            ("airpods", "TAG_1749056323568", "https://support.apple.com/zh-cn/airpods/repair", "AirPods")
        ]
        
        var fetchedDatabase: [String: Any] = [:]
        
        // 保留现有基准作为合并底座
        if let currentSaved = UserDefaults.standard.data(forKey: userDefaultsKey),
           let dict = try? JSONSerialization.jsonObject(with: currentSaved) as? [String: Any] {
            fetchedDatabase = dict
        } else if let bundleUrl = Bundle.main.url(forResource: "AppleRepairPriceDatabase", withExtension: "json"),
                  let bundleData = try? Data(contentsOf: bundleUrl),
                  let dict = try? JSONSerialization.jsonObject(with: bundleData) as? [String: Any] {
            fetchedDatabase = dict
        }
        
        let session = URLSession(configuration: .ephemeral)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        for item in categoriesToFetch {
            liveSyncProgressText = "正在提取最新 \(item.label) 官网公示价格..."
            let urlString = "https://support.apple.com/ols/api/pricing/products/services/pricing-estimate?locale=zh-cn&pricing_type=OOW&parent_tag_id=\(item.tag)"
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("https://support.apple.com/zh-cn/", forHTTPHeaderField: "Referer")
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await session.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let products = json["products"] as? [[String: Any]], !products.isEmpty {
                    
                    // 将官网实时返回的数据结构清洗并挂载回数据库
                    let cleanedCategory = convertOfficialApiProducts(item.key, products: products, date: todayStr)
                    fetchedDatabase[item.key] = cleanedCategory
                }
            } catch {
                print("Failed to live fetch for \(item.label): \(error)")
            }
        }
        
        // 同步提取并更新 AppleCare+ 官方零售购买价格
        liveSyncProgressText = "正在同步 AppleCare+ 官方购买计划最新售价..."
        await fetchLatestAppleCarePurchasePrices(session: session)
        
        liveSyncProgressText = "正在执行新旧数据比对并生成报告..."
        guard let finalData = try? JSONSerialization.data(withJSONObject: fetchedDatabase, options: [.prettyPrinted]) else {
            isLiveSyncing = false
            return .failure(NSError(domain: "ApplePricingData", code: 3, userInfo: [NSLocalizedDescriptionKey: "生成最终数据库失败"]))
        }
        
        let success = parseAndApplyDatabase(from: finalData, recordDiff: true)
        if success {
            UserDefaults.standard.set(finalData, forKey: userDefaultsKey)
            self.lastAutoCheckTime = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
            
            // 如果发现了真实价格或机型变动，自动通过系统通知向用户发送通知提示
            if !recentDiffRecords.isEmpty {
                NotificationService.shared.sendLocalNotification(
                    title: "Apple 官方维修价格发生变动",
                    subtitle: "监测引擎自动检测到 \(recentDiffRecords.count) 项价格调整",
                    body: "点击查看详细变动报告与机型调整明细。"
                )
            }
            
            isLiveSyncing = false
            return .success(recentDiffRecords.count)
        } else {
            isLiveSyncing = false
            return .failure(NSError(domain: "ApplePricingData", code: 4, userInfo: [NSLocalizedDescriptionKey: "解析官网最新数据结构失败"]))
        }
    }
    
    // MARK: - 自动定时后台静默监测 (每 12 小时自动探测一次，有变动才弹系统通知)
    public func setAutoMonitoring(enabled: Bool) {
        self.isAutoMonitoringEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: autoMonitorKey)
        if enabled {
            startPeriodicMonitorTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startPeriodicMonitorTimer() {
        guard isAutoMonitoringEnabled else { return }
        timer?.invalidate()
        
        // 启动 10 秒后执行首次静默检查（若距上次检查已超过 12 小时）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, self.isAutoMonitoringEnabled else { return }
            if let last = self.lastAutoCheckTime {
                if Date().timeIntervalSince(last) > 12 * 3600 {
                    Task {
                        await self.fetchLatestFromOfficialWebsite()
                    }
                }
            } else {
                Task {
                    await self.fetchLatestFromOfficialWebsite()
                }
            }
        }
        
        // 后续每 6 小时自动唤醒检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            guard let self = self, self.isAutoMonitoringEnabled else { return }
            Task {
                await self.fetchLatestFromOfficialWebsite()
            }
        }
    }
    
    // 清洗官方接口 JSON 返回为统一的标准模型格式
    private func convertOfficialApiProducts(_ categoryKey: String, products: [[String: Any]], date: String) -> [String: Any] {
        var categoryDict: [String: Any] = [
            "last_updated": date,
            "category": categoryKey
        ]
        
        if categoryKey == "iphone" {
            var modelsDict: [String: [String: Any]] = [:]
            var seriesOrder: [String] = []
            
            for p in products {
                let pTitle = p["product_loc_title"] as? String ?? ""
                if !pTitle.isEmpty && !seriesOrder.contains(pTitle) {
                    seriesOrder.append(pTitle)
                }
                
                let children = p["childrenProducts"] as? [[String: Any]] ?? [p]
                for c in children {
                    let mName = c["product_loc_title"] as? String ?? ""
                    if mName.isEmpty { continue }
                    var serviceMap: [String: Int] = [:]
                    
                    let services = c["services"] as? [[String: Any]] ?? []
                    for s in services {
                        let label = s["serviceLabel"] as? String ?? ""
                        let priceStr = s["price"] as? String ?? ""
                        let cleanPrice = priceStr.replacingOccurrences(of: "RMB", with: "")
                            .replacingOccurrences(of: ",", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if let intVal = Int(cleanPrice) {
                            if label.contains("电池") { serviceMap["battery"] = intVal }
                            else if label.contains("背面玻璃") && !label.contains("屏幕和") { serviceMap["back_glass"] = intVal }
                            else if label.contains("屏幕和背面") { serviceMap["screen_and_back_glass"] = intVal }
                            else if label.contains("后置相机") { serviceMap["rear_camera"] = intVal }
                            else if label.contains("屏幕") { serviceMap["screen"] = intVal }
                            else if label.contains("其他") { serviceMap["other"] = intVal }
                        }
                    }
                    if !serviceMap.isEmpty {
                        modelsDict[mName] = serviceMap
                    }
                }
            }
            categoryDict["models"] = modelsDict
            categoryDict["series_order"] = seriesOrder
        } else {
            // Mac, iPad, Watch, AirPods 映射为 series 格式
            var seriesDict: [String: [String: Any]] = [:]
            var seriesOrder: [String] = []
            
            for p in products {
                let sTitle = p["product_loc_title"] as? String ?? ""
                if !sTitle.isEmpty && !seriesOrder.contains(sTitle) {
                    seriesOrder.append(sTitle)
                }
                
                var modelsInSeries: [String: [String: Any]] = [:]
                let children = p["childrenProducts"] as? [[String: Any]] ?? [p]
                for c in children {
                    let mName = c["product_loc_title"] as? String ?? ""
                    if mName.isEmpty { continue }
                    
                    var oowMap: [String: Any] = [:]
                    var acMap: [String: Any] = [:]
                    
                    let services = c["services"] as? [[String: Any]] ?? []
                    for s in services {
                        let label = s["serviceLabel"] as? String ?? ""
                        let priceStr = s["price"] as? String ?? ""
                        let cleanPrice = priceStr.replacingOccurrences(of: "RMB", with: "")
                            .replacingOccurrences(of: ",", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        
                        if let intVal = Int(cleanPrice) {
                            if label.contains("电池") {
                                oowMap["battery"] = intVal
                                acMap["battery"] = 0
                            } else if label.contains("其他") {
                                oowMap["other"] = intVal
                            } else {
                                oowMap[label] = intVal
                            }
                        } else if !cleanPrice.isEmpty {
                            oowMap["other_text"] = cleanPrice
                        }
                    }
                    
                    modelsInSeries[mName] = [
                        "oow": oowMap,
                        "ac": acMap
                    ]
                }
                if !modelsInSeries.isEmpty {
                    seriesDict[sTitle] = modelsInSeries
                }
            }
            categoryDict["series"] = seriesDict
            categoryDict["series_order"] = seriesOrder
        }
        
        return categoryDict
    }
    
    // 爬取并更新 AppleCare+ 购买价格
    private func fetchLatestAppleCarePurchasePrices(session: URLSession) async {
        let parts = [
            "SCYX3", "SWYK2", "SNHD2", "SWYM2",
            "SGA93", "SGCF3", "SR0N2", "SD0W3", "SUW62", "SUW72", "SXKK2CH/A", "SR0L2",
            "SD283", "SD1F3",
            "SUY32", "SCVE3", "SCVF3", "SXQK2", "SXQM2",
            "SXHK2", "SXF92", "SXFC2", "SNMT2", "SNMN2",
            "SLG32CH/A",
            "S9075", "SYM02", "S9083",
            "S9039CH/A", "S6442"
        ]
        
        let urlString = "https://www.apple.com.cn/shop/mcm/product-price?parts=" + parts.joined(separator: ",")
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("https://www.apple.com.cn/applecare/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [String: [String: Any]] {
                
                // 将获取到的最新价格同步回 appleCarePurchaseList
                var updated = self.appleCarePurchaseList
                for (idx, existing) in updated.enumerated() {
                    // 找到对应的 part
                    for (_, itemDetails) in items {
                        let name = itemDetails["name"] as? String ?? ""
                        if name.contains(existing.modelName) || existing.modelName.contains(name) {
                            if let priceDict = itemDetails["price"] as? [String: Any],
                               let display = priceDict["display"] as? [String: Any],
                               let smart = display["smart"] as? String,
                               let val = priceDict["value"] as? Double {
                                updated[idx].priceAmount = Int(val)
                                updated[idx].priceDisplay = smart
                            }
                        }
                    }
                }
                self.appleCarePurchaseList = updated
            }
        } catch {
            print("Failed to live fetch AppleCare purchase prices: \(error)")
        }
    }
    
    // 从 HTML 中提取数据
    private func extractJsonFromHtml(_ html: String) -> Data? {
        let vars = ["iphone": "iphoneBaseData", "ipad": "ipadBaseData", "mac": "macBaseData", "watch": "watchBaseData", "airpods": "airpodsBaseData", "other": "otherBaseData"]
        var merged: [String: Any] = [:]
        
        for (catKey, varName) in vars {
            let pattern = "const\\s+" + varName + "\\s*=\\s*(\\{[\\s\\S]*?\\n\\});"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                var jsonStr = String(html[range])
                // 去除可能存在的末尾逗号
                let commaPattern = ",(\\s*[}\\]])"
                if let commaRegex = try? NSRegularExpression(pattern: commaPattern, options: []) {
                    jsonStr = commaRegex.stringByReplacingMatches(in: jsonStr, range: NSRange(jsonStr.startIndex..., in: jsonStr), withTemplate: "$1")
                }
                if let d = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    merged[catKey] = dict
                }
            }
        }
        
        if merged.isEmpty { return nil }
        return try? JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted])
    }
    
    // 解析总 JSON 并生成各分类 Model
    private func parseAndApplyDatabase(from data: Data, recordDiff: Bool) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        var newIPhoneList: [OfficialProductModel] = []
        var newIPadList: [OfficialProductModel] = []
        var newMacList: [OfficialProductModel] = []
        var newWatchList: [OfficialProductModel] = []
        var newAirpodsList: [OfficialProductModel] = []
        var newOtherList: [OfficialProductModel] = []
        var latestDate = self.lastUpdated
        
        // 1. iPhone
        if let iphoneDict = root["iphone"] as? [String: Any] {
            if let date = iphoneDict["last_updated"] as? String { latestDate = date }
            let models = iphoneDict["models"] as? [String: [String: Any]] ?? [:]
            let order = iphoneDict["series_order"] as? [String] ?? []
            
            // 按照官方 series_order 顺序排列
            var sortedModels: [String] = []
            for s in order {
                let matched = models.keys.filter { $0.contains(s) }.sorted { $0.count > $1.count }
                for m in matched where !sortedModels.contains(m) {
                    sortedModels.append(m)
                }
            }
            for m in models.keys where !sortedModels.contains(m) {
                sortedModels.append(m)
            }
            
            for mName in sortedModels {
                guard let pDict = models[mName] else { continue }
                var parts: [OfficialPartItem] = []
                
                if let screen = pDict["screen"] as? Int {
                    parts.append(OfficialPartItem(partName: "屏幕更换 (正面)", officialOOWPrice: "\(screen.formattedWithSeparator)", isExactPrice: true, officialACPrice: "188", note: "官网确定预估服务费", iconName: "iphone.gen3.slash", colorName: "blue"))
                }
                if let back = pDict["back_glass"] as? Int {
                    parts.append(OfficialPartItem(partName: "背面玻璃损坏", officialOOWPrice: "\(back.formattedWithSeparator)", isExactPrice: true, officialACPrice: "188", note: "官网确定预估服务费", iconName: "square.split.diagonal.2x2", colorName: "indigo"))
                }
                if let both = pDict["screen_and_back_glass"] as? Int {
                    parts.append(OfficialPartItem(partName: "屏幕和背面玻璃", officialOOWPrice: "\(both.formattedWithSeparator)", isExactPrice: true, officialACPrice: "376", note: "双面破裂组合服务", iconName: "macbook.and.iphone", colorName: "purple"))
                }
                if let cam = pDict["rear_camera"] as? Int {
                    parts.append(OfficialPartItem(partName: "后置相机更换", officialOOWPrice: "\(cam.formattedWithSeparator)", isExactPrice: true, officialACPrice: "628", note: "镜头模组更换服务", iconName: "iphone.rear.camera", colorName: "teal"))
                }
                if let bat = pDict["battery"] as? Int {
                    parts.append(OfficialPartItem(partName: "电池服务 (低于80%)", officialOOWPrice: "\(bat.formattedWithSeparator)", isExactPrice: true, officialACPrice: "0 (免费)", note: "容量 <80% AC+ 免费更换", iconName: "battery.100.bolt", colorName: "green"))
                }
                if let other = pDict["other"] as? Int {
                    parts.append(OfficialPartItem(partName: "其他损坏 (整机置换)", officialOOWPrice: "\(other.formattedWithSeparator)", isExactPrice: true, officialACPrice: "628", note: "官网确定预估服务费", iconName: "exclamationmark.triangle.fill", colorName: "red"))
                }
                
                // 自动推断 iPhone 所属系列（如 "iPhone 16"）
                let matchedSeries = order.first(where: { mName.contains($0) }) ?? "其他 iPhone"
                newIPhoneList.append(OfficialProductModel(category: .iphone, seriesName: matchedSeries, modelName: mName, parts: parts))
            }
        }
        
        // 2. iPad
        if let ipadDict = root["ipad"] as? [String: Any] {
            if let seriesDict = ipadDict["series"] as? [String: [String: Any]] {
                let order = ipadDict["series_order"] as? [String] ?? Array(seriesDict.keys)
                for sName in order {
                    guard let mDict = seriesDict[sName] else { continue }
                    for (mName, item) in mDict {
                        guard let details = item as? [String: Any] else { continue }
                        let oow = details["oow"] as? [String: Any] ?? [:]
                        let ac = details["ac"] as? [String: Any] ?? [:]
                        var parts: [OfficialPartItem] = []
                        
                        if let bat = oow["battery"] as? Int {
                            parts.append(OfficialPartItem(partName: "电池服务 (低于80%)", officialOOWPrice: "\(bat.formattedWithSeparator)", isExactPrice: true, officialACPrice: "0 (免费)", note: "容量 <80% AC+ 免费", iconName: "battery.100.bolt", colorName: "green"))
                        }
                        if let other = oow["other"] as? Int {
                            let acOther = ac["other_accidental"] as? Int ?? (ac["other"] as? Int ?? 368)
                            parts.append(OfficialPartItem(partName: "其他损坏 / 整机更换", officialOOWPrice: "\(other.formattedWithSeparator)", isExactPrice: true, officialACPrice: "\(acOther)", note: "AC+ 意外损坏专属费率", iconName: "exclamationmark.triangle.fill", colorName: "red"))
                        }
                        if let acScreen = ac["screen"] as? Int {
                            parts.append(OfficialPartItem(partName: "屏幕损坏维修", officialOOWPrice: "需送修检测估价", isExactPrice: false, officialACPrice: "\(acScreen)", note: "AC+ 专属权益 ¥\(acScreen)", iconName: "ipad.landscape", colorName: "blue"))
                        }
                        newIPadList.append(OfficialProductModel(category: .ipad, seriesName: sName, modelName: mName, parts: parts))
                    }
                }
            }
        }
        
        // 3. Mac
        if let macDict = root["mac"] as? [String: Any] {
            if let seriesDict = macDict["series"] as? [String: [String: Any]] {
                let order = macDict["series_order"] as? [String] ?? Array(seriesDict.keys)
                for sName in order {
                    guard let mDict = seriesDict[sName] else { continue }
                    for (mName, item) in mDict {
                        guard let details = item as? [String: Any] else { continue }
                        let oow = details["oow"] as? [String: Any] ?? [:]
                        let ac = details["ac"] as? [String: Any] ?? [:]
                        var parts: [OfficialPartItem] = []
                        
                        if let bat = oow["battery"] as? Int {
                            parts.append(OfficialPartItem(partName: "电池服务 (低于80%)", officialOOWPrice: "\(bat.formattedWithSeparator)", isExactPrice: true, officialACPrice: "0 (免费)", note: "官网明码标价公开项", iconName: "battery.100.bolt", colorName: "green"))
                        }
                        let acScreen = ac["screen"] as? Int ?? 799
                        parts.append(OfficialPartItem(partName: "屏幕或机身外壳损坏", officialOOWPrice: "需送修检测估价", isExactPrice: false, officialACPrice: "\(acScreen)", note: "官网保外无固定公开价 / AC+ 专属¥\(acScreen)", iconName: "display", colorName: "blue"))
                        
                        let acOther = ac["other_accidental"] as? Int ?? 2299
                        parts.append(OfficialPartItem(partName: "其他意外损坏 (主板/整机)", officialOOWPrice: "需送修检测估价", isExactPrice: false, officialACPrice: "\(acOther)", note: "官网保外无固定公开价 / AC+ 专属¥\(acOther)", iconName: "cpu.fill", colorName: "purple"))
                        
                        newMacList.append(OfficialProductModel(category: .mac, seriesName: sName, modelName: mName, parts: parts))
                    }
                }
            }
        }
        
        // 4. Watch
        if let watchDict = root["watch"] as? [String: Any] {
            if let seriesDict = watchDict["series"] as? [String: [String: Any]] {
                let order = watchDict["series_order"] as? [String] ?? Array(seriesDict.keys)
                for sName in order {
                    guard let mDict = seriesDict[sName] else { continue }
                    for (mName, item) in mDict {
                        guard let details = item as? [String: Any] else { continue }
                        let oow = details["oow"] as? [String: Any] ?? [:]
                        let ac = details["ac"] as? [String: Any] ?? [:]
                        var parts: [OfficialPartItem] = []
                        
                        if let bat = oow["battery"] as? Int {
                            parts.append(OfficialPartItem(partName: "电池服务 (低于80%)", officialOOWPrice: "\(bat.formattedWithSeparator)", isExactPrice: true, officialACPrice: "0 (免费)", note: "容量 <80% AC+ 免费", iconName: "battery.100.bolt", colorName: "green"))
                        }
                        if let other = oow["other"] as? Int {
                            let acAcc = ac["accidental"] as? Int ?? 528
                            parts.append(OfficialPartItem(partName: "整机置换 / 意外损坏", officialOOWPrice: "\(other.formattedWithSeparator)", isExactPrice: true, officialACPrice: "\(acAcc)", note: "AC+ 意外损坏服务费 ¥\(acAcc)", iconName: "applewatch.case.inset.filled", colorName: "red"))
                        }
                        newWatchList.append(OfficialProductModel(category: .watch, seriesName: sName, modelName: mName, parts: parts))
                    }
                }
            }
        }
        
        // 5. AirPods
        if let airpodsDict = root["airpods"] as? [String: Any] {
            let models = airpodsDict["models"] as? [String: [String: Any]] ?? [:]
            for (mName, details) in models {
                let oow = details["oow"] as? [String: Any] ?? [:]
                let ac = details["ac"] as? [String: Any] ?? [:]
                let series = details["series"] as? String ?? "AirPods"
                var parts: [OfficialPartItem] = []
                
                for (pName, pVal) in oow {
                    let priceStr: String
                    let isExact: Bool
                    if let intVal = pVal as? Int {
                        priceStr = "\(intVal.formattedWithSeparator)"
                        isExact = true
                    } else {
                        priceStr = "\(pVal)"
                        isExact = false
                    }
                    
                    let acPrice: String
                    if pName.contains("电池") {
                        acPrice = "0 (免费)"
                    } else if pName.contains("丢失") {
                        acPrice = priceStr + " (遗失无折)"
                    } else {
                        let acAcc = ac["意外损坏"] as? Int ?? 199
                        acPrice = "\(acAcc)"
                    }
                    
                    parts.append(OfficialPartItem(partName: pName, officialOOWPrice: priceStr, isExactPrice: isExact, officialACPrice: acPrice, note: "Apple 官方统一维修/置换标准", iconName: pName.contains("电池") ? "battery.100.bolt" : "earbuds.case.fill", colorName: pName.contains("电池") ? "green" : "blue"))
                }
                newAirpodsList.append(OfficialProductModel(category: .airpods, seriesName: series, modelName: mName, parts: parts))
            }
        }
        
        // 6. Other (Vision Pro / Display / HomePod)
        if let otherDict = root["other"] as? [String: Any] {
            if let seriesDict = otherDict["series"] as? [String: [String: Any]] {
                for (sName, mDict) in seriesDict {
                    for (mName, item) in mDict {
                        guard let details = item as? [String: Any] else { continue }
                        let oow = details["oow"] as? [String: Any] ?? [:]
                        let ac = details["ac"] as? [String: Any] ?? [:]
                        var parts: [OfficialPartItem] = []
                        
                        if let other = oow["other"] as? Int {
                            let acOther = ac["other_accidental"] as? Int ?? (ac["accidental"] as? Int ?? 299)
                            parts.append(OfficialPartItem(partName: "其他损坏维修", officialOOWPrice: "\(other.formattedWithSeparator)", isExactPrice: true, officialACPrice: "\(acOther)", note: "官方保外整机/部件置换", iconName: "exclamationmark.triangle.fill", colorName: "red"))
                        } else if let otherText = oow["other_text"] as? String {
                            let acOther = ac["other_accidental"] as? Int ?? 2299
                            parts.append(OfficialPartItem(partName: "其他意外损坏", officialOOWPrice: otherText, isExactPrice: false, officialACPrice: "\(acOther)", note: "官网保外需送修检测", iconName: "exclamationmark.triangle.fill", colorName: "orange"))
                        }
                        
                        if let glassSingle = oow["cover_glass_single"] as? Int {
                            parts.append(OfficialPartItem(partName: "正面玻璃 (单条裂纹)", officialOOWPrice: glassSingle == 0 ? "免费保修" : "\(glassSingle.formattedWithSeparator)", isExactPrice: true, officialACPrice: "0 (免费)", note: "官方工艺保障条款", iconName: "eye.fill", colorName: "blue"))
                        }
                        if let glassMulti = oow["cover_glass_multiple"] as? Int {
                            parts.append(OfficialPartItem(partName: "正面玻璃 (多条破裂)", officialOOWPrice: "\(glassMulti.formattedWithSeparator)", isExactPrice: true, officialACPrice: "2,499", note: "官方保外盖板维修", iconName: "viewfinder", colorName: "purple"))
                        }
                        
                        newOtherList.append(OfficialProductModel(category: .other, seriesName: sName, modelName: mName, parts: parts))
                    }
                }
            }
        }
        
        // 如果开启了比对记录，对比新旧价格
        if recordDiff {
            var diffs: [PriceDiffRecord] = []
            let oldDict = Dictionary(grouping: self.allProducts, by: \.modelName)
            let newAll = newIPhoneList + newIPadList + newMacList + newWatchList + newAirpodsList + newOtherList
            
            for prod in newAll {
                guard let oldProd = oldDict[prod.modelName]?.first else {
                    diffs.append(PriceDiffRecord(modelName: prod.modelName, category: prod.category, partName: "全部类目", oldPrice: "—", newPrice: "全新收录", diffAmount: nil, statusDescription: "🆕 新增机型"))
                    continue
                }
                let oldPartMap = Dictionary(uniqueKeysWithValues: oldProd.parts.map { ($0.partName, $0) })
                for p in prod.parts {
                    if let oldP = oldPartMap[p.partName] {
                        let oldClean = oldP.officialOOWPrice.replacingOccurrences(of: ",", with: "")
                        let newClean = p.officialOOWPrice.replacingOccurrences(of: ",", with: "")
                        if let oldInt = Int(oldClean), let newInt = Int(newClean), oldInt != newInt {
                            let diff = newInt - oldInt
                            diffs.append(PriceDiffRecord(
                                modelName: prod.modelName,
                                category: prod.category,
                                partName: p.partName,
                                oldPrice: oldP.officialOOWPrice,
                                newPrice: p.officialOOWPrice,
                                diffAmount: diff,
                                statusDescription: diff > 0 ? "价格上调 🔺" : "价格下调 🔻"
                            ))
                        }
                    }
                }
            }
            self.recentDiffRecords = diffs
        }
        
        self.lastUpdated = latestDate
        self.iphoneList = newIPhoneList
        self.ipadList = newIPadList
        self.macList = newMacList
        self.watchList = newWatchList
        self.airpodsList = newAirpodsList
        self.otherList = newOtherList
        
        // 自动初始化/刷新 AppleCare+ 官方零售购买价格数据表
        buildDefaultAppleCarePurchaseList()
        
        return true
    }
    
    // 初始化 Apple 官网标准 AppleCare+ 购买价格表
    private func buildDefaultAppleCarePurchaseList() {
        self.appleCarePurchaseList = [
            // iPhone 系列
            AppleCarePurchaseItem(category: .iphone, seriesName: "iPhone 17 系列", modelName: "iPhone 17 Pro / Pro Max / iPhone Air", termYears: 2, priceAmount: 1599, priceDisplay: "RMB 1,599", features: ["不限次数意外损坏保修", "电池容量<80%免费换新", "优先技术支持", "可加入年年焕新"]),
            AppleCarePurchaseItem(category: .iphone, seriesName: "iPhone 16 系列", modelName: "iPhone 16 Plus", termYears: 2, priceAmount: 1449, priceDisplay: "RMB 1,449", features: ["不限次数意外损坏保修", "电池容量<80%免费换新", "屏幕/玻璃背板专属¥188"]),
            AppleCarePurchaseItem(category: .iphone, seriesName: "iPhone 16 / 17 系列", modelName: "iPhone 17 / iPhone 16", termYears: 2, priceAmount: 1199, priceDisplay: "RMB 1,199", features: ["不限次数意外损坏保修", "电池容量<80%免费换新", "屏幕/玻璃背板专属¥188"]),
            AppleCarePurchaseItem(category: .iphone, seriesName: "iPhone 17 系列", modelName: "iPhone 17e", termYears: 2, priceAmount: 899, priceDisplay: "RMB 899", features: ["不限次数意外损坏保修", "电池容量<80%免费换新", "优先技术支持"]),
            
            // Mac 系列 (3 年期)
            AppleCarePurchaseItem(category: .mac, seriesName: "MacBook Pro", modelName: "MacBook Pro（16 英寸）", termYears: 3, priceAmount: 3449, priceDisplay: "RMB 3,449", features: ["3年全球联保与上门取送", "不限次数意外损坏", "屏幕/外壳意外专属¥799", "电池免费更换"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "MacBook Pro", modelName: "MacBook Pro（14 英寸）", termYears: 3, priceAmount: 2449, priceDisplay: "RMB 2,449", features: ["3年全球联保与上门取送", "不限次数意外损坏", "屏幕/外壳意外专属¥799", "电池免费更换"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "MacBook Air", modelName: "MacBook Air（15 英寸）", termYears: 3, priceAmount: 2049, priceDisplay: "RMB 2,049", features: ["3年全球联保与上门取送", "不限次数意外损坏", "屏幕/外壳意外专属¥799", "电池免费更换"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "MacBook Air", modelName: "MacBook Air（13 英寸）", termYears: 3, priceAmount: 1749, priceDisplay: "RMB 1,749", features: ["3年全球联保与上门取送", "不限次数意外损坏", "屏幕/外壳意外专属¥799", "电池免费更换"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "MacBook Neo", modelName: "MacBook Neo（13 英寸，A18 Pro）", termYears: 3, priceAmount: 1249, priceDisplay: "RMB 1,249", features: ["3年期官方保修保障", "意外损坏服务费 RMB 399-1199", "电池免费更换"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "台式 Mac", modelName: "iMac", termYears: 3, priceAmount: 1549, priceDisplay: "RMB 1,549", features: ["3年全球联保与技术支持", "屏幕/外壳专属¥799", "其他意外损坏¥2299"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "台式 Mac", modelName: "Mac Studio", termYears: 3, priceAmount: 1549, priceDisplay: "RMB 1,549", features: ["3年全球联保与技术支持", "机身外壳损坏专属¥799", "其他意外损坏¥2299"]),
            AppleCarePurchaseItem(category: .mac, seriesName: "台式 Mac", modelName: "Mac mini", termYears: 3, priceAmount: 799, priceDisplay: "RMB 799", features: ["3年全球联保与技术支持", "机身外壳损坏专属¥799", "其他意外损坏¥2299"]),
            
            // iPad 系列
            AppleCarePurchaseItem(category: .ipad, seriesName: "iPad Pro", modelName: "13 英寸 iPad Pro (M5 / M4)", termYears: 2, priceAmount: 1549, priceDisplay: "RMB 1,549", features: ["含 1 支 Apple Pencil 与键盘保障", "屏幕损坏专属¥188", "电池免费更换"]),
            AppleCarePurchaseItem(category: .ipad, seriesName: "iPad Pro", modelName: "11 英寸 iPad Pro (M5 / M4)", termYears: 2, priceAmount: 1399, priceDisplay: "RMB 1,399", features: ["含 1 支 Apple Pencil 与键盘保障", "屏幕损坏专属¥188", "电池免费更换"]),
            AppleCarePurchaseItem(category: .ipad, seriesName: "iPad Air", modelName: "13 英寸 iPad Air (M4 / M2)", termYears: 2, priceAmount: 899, priceDisplay: "RMB 899", features: ["含 1 支 Apple Pencil 与键盘保障", "屏幕损坏专属¥188", "电池免费更换"]),
            AppleCarePurchaseItem(category: .ipad, seriesName: "iPad Air", modelName: "11 英寸 iPad Air (M4 / M2)", termYears: 2, priceAmount: 749, priceDisplay: "RMB 749", features: ["含 1 支 Apple Pencil 与键盘保障", "屏幕损坏专属¥188", "电池免费更换"]),
            AppleCarePurchaseItem(category: .ipad, seriesName: "iPad", modelName: "iPad (A16 / 第 10 代 / mini)", termYears: 2, priceAmount: 649, priceDisplay: "RMB 649", features: ["含 1 支 Apple Pencil 保障", "意外损坏专属服务费", "电池免费更换"]),
            
            // Apple Watch 系列
            AppleCarePurchaseItem(category: .watch, seriesName: "Apple Watch Hermès", modelName: "Apple Watch Hermès / Hermès Ultra", termYears: 3, priceAmount: 1299, priceDisplay: "RMB 1,299", features: ["3年官方保修专属期", "含爱马仕运动表带保障", "意外损坏专属服务费", "电池免费置换"]),
            AppleCarePurchaseItem(category: .watch, seriesName: "Apple Watch Ultra", modelName: "Apple Watch Ultra 3 / 2", termYears: 2, priceAmount: 799, priceDisplay: "RMB 799", features: ["2年官方意外损坏保修", "专属¥588置换服务费", "电池免费置换"]),
            AppleCarePurchaseItem(category: .watch, seriesName: "Apple Watch Series", modelName: "Apple Watch Series 11 / 10", termYears: 2, priceAmount: 649, priceDisplay: "RMB 649", features: ["2年官方意外损坏保修", "专属¥528置换服务费", "电池免费置换"]),
            AppleCarePurchaseItem(category: .watch, seriesName: "Apple Watch SE", modelName: "Apple Watch SE 3 / SE 2", termYears: 2, priceAmount: 399, priceDisplay: "RMB 399", features: ["2年官方意外损坏保修", "专属¥528置换服务费", "电池免费置换"]),
            
            // 耳机 & 显示器 & Vision Pro & HomePod
            AppleCarePurchaseItem(category: .airpods, seriesName: "AirPods", modelName: "AirPods Max 2 / Max", termYears: 2, priceAmount: 549, priceDisplay: "RMB 549", features: ["意外损坏单次置换¥199", "电池免费更换", "优先专家技术支持"]),
            AppleCarePurchaseItem(category: .airpods, seriesName: "AirPods", modelName: "AirPods Pro 3 / Pro 2", termYears: 2, priceAmount: 449, priceDisplay: "RMB 449", features: ["意外损坏单次置换¥199", "单只/充电盒电池免费换", "优先技术支持"]),
            AppleCarePurchaseItem(category: .airpods, seriesName: "AirPods", modelName: "AirPods 4 / AirPods 3 / Beats", termYears: 2, priceAmount: 349, priceDisplay: "RMB 349", features: ["意外损坏单次置换¥199", "单只/充电盒电池免费换"]),
            AppleCarePurchaseItem(category: .other, seriesName: "Apple Vision Pro", modelName: "Apple Vision Pro", termYears: 2, priceAmount: 3199, priceDisplay: "RMB 3,199", features: ["意外损坏收取固定服务费", "配件更换专属¥249", "原装电池免费置换"]),
            AppleCarePurchaseItem(category: .other, seriesName: "Apple 显示器", modelName: "Studio Display XDR", termYears: 3, priceAmount: 2499, priceDisplay: "RMB 2,499", features: ["3年全球联保与上门取送", "屏幕/外壳损坏专属¥799", "其他意外损坏¥2299"]),
            AppleCarePurchaseItem(category: .other, seriesName: "Apple 显示器", modelName: "Studio Display", termYears: 3, priceAmount: 1249, priceDisplay: "RMB 1,249", features: ["3年全球联保与上门取送", "屏幕/外壳损坏专属¥799", "其他意外损坏¥2299"]),
            AppleCarePurchaseItem(category: .other, seriesName: "HomePod", modelName: "HomePod", termYears: 2, priceAmount: 299, priceDisplay: "RMB 299", features: ["意外损坏服务费 RMB 115 起", "全球维修服务", "优先技术支持"]),
            AppleCarePurchaseItem(category: .other, seriesName: "HomePod", modelName: "HomePod mini", termYears: 2, priceAmount: 119, priceDisplay: "RMB 119", features: ["意外损坏服务费 RMB 115 起", "全球维修服务", "优先技术支持"])
        ]
    }
    
    public var allProducts: [OfficialProductModel] {
        iphoneList + ipadList + macList + watchList + airpodsList + otherList
    }
    
    // 恢复默认数据
    public func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        recentDiffRecords = []
        loadInitialDatabase()
    }
    
    private func buildFallbackData() {
        self.iphoneList = [
            OfficialProductModel(category: .iphone, modelName: "iPhone 16 Pro", parts: [
                OfficialPartItem(partName: "正面屏幕", officialOOWPrice: "2,698", officialACPrice: "188", note: "官网保外确定价", iconName: "iphone.gen3.slash"),
                OfficialPartItem(partName: "电池服务", officialOOWPrice: "969", officialACPrice: "0 (免费)", note: "容量 <80% 免费", iconName: "battery.100.bolt", colorName: "green")
            ])
        ]
    }
}

// MARK: - Helper Extension

private extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
