//
//  PriceQueryView.swift
//  团队工作台
//
//  设备报价速查中心 - 100% 严格对齐 Apple 官网公开产品与官方维修/AppleCare+ 结构标准
//  脱机独立运作，支持外部 HTML / JSON 随时导入更新与差价对比
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct PriceQueryView: View {
    @EnvironmentObject var store: WorkbenchStore
    @StateObject private var pricingStore = AppleOfficialPricingData.shared
    
    // 查询主类型：官方维修价格 vs AC+ 购买价格
    public enum PriceQueryDomain: String, CaseIterable, Identifiable {
        case repair = "维修价格查询"
        case appleCarePurchase = "AC+ 购买价格"
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .repair: return "wrench.and.screwdriver.fill"
            case .appleCarePurchase: return "shield.lefthalf.filled.badge.checkmark"
            }
        }
    }
    
    @State private var queryDomain: PriceQueryDomain = .repair
    @State private var selectedCategory: OfficialCategory = .iphone
    @State private var selectedSeries: String = ""
    @State private var selectedModel: String = ""
    @State private var hasAppleCare: Bool = false
    @State private var searchText: String = ""
    @State private var copyToastMessage: String? = nil
    
    // 导入与变动监测状态
    @State private var showDiffSheet: Bool = false
    @State private var importAlertMessage: String? = nil
    @State private var showImportAlert: Bool = false
    
    public init() {}
    
    // MARK: - Filtered Models & Series
    
    private var currentCategoryProducts: [OfficialProductModel] {
        pricingStore.products(for: selectedCategory)
    }
    
    // 当前品类下包含的所有系列（保持原 HTML series_order 顺序，去重）
    private var availableSeries: [String] {
        var result: [String] = []
        for p in currentCategoryProducts {
            let s = p.seriesName.isEmpty ? "默认系列" : p.seriesName
            if !result.contains(s) {
                result.append(s)
            }
        }
        return result
    }
    
    // 当前选定系列或搜索匹配的机型
    private var availableModels: [String] {
        let rawQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果正在搜索，优先全局跨系列模糊匹配
        if !rawQuery.isEmpty {
            // 对输入 query 进行缩写同义词预处理（如 "16pm" -> "16 pro max"，"16p" -> "16 pro"）
            let expandedQuery = expandSearchAbbreviations(rawQuery.lowercased())
            let queryTokens = expandedQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            return currentCategoryProducts.map(\.modelName).filter { modelName in
                matchesFuzzySearch(modelName: modelName, tokens: queryTokens, rawQuery: rawQuery.lowercased())
            }
        }
        
        // 否则按选定系列过滤
        let targetSeries = selectedSeries.isEmpty ? (availableSeries.first ?? "") : selectedSeries
        return currentCategoryProducts.filter { prod in
            let s = prod.seriesName.isEmpty ? "默认系列" : prod.seriesName
            return s == targetSeries
        }.map(\.modelName)
    }
    
    // 行业全系设备常见缩写展开映射 (Mac, iPhone, iPad, Watch, AirPods 等)
    private func expandSearchAbbreviations(_ input: String) -> String {
        var text = input
        
        // --- 1. Mac 系列缩写展开 ---
        // mbp -> macbook pro, mba -> macbook air, mm -> mac mini, ms -> mac studio, mp -> mac pro
        text = text.replacingOccurrences(of: #"\bmbp\b"#, with: "macbook pro", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmba\b"#, with: "macbook air", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmacbookpro\b"#, with: "macbook pro", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmacbookair\b"#, with: "macbook air", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmacmini\b"#, with: "mac mini", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmacstudio\b"#, with: "mac studio", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bmacpro\b"#, with: "mac pro", options: .regularExpression)
        
        // --- 2. Apple Watch 系列缩写展开 ---
        // aw / s10 / s9 / u2 / u3 / se2 -> apple watch series / ultra
        text = text.replacingOccurrences(of: #"\baw\b"#, with: "apple watch", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bu(\d)\b"#, with: "ultra $1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bs(\d+)\b"#, with: "series $1", options: .regularExpression)
        
        // --- 3. AirPods 系列缩写展开 ---
        // app / apm / ap -> airpods pro / airpods max
        text = text.replacingOccurrences(of: #"\bapp2\b"#, with: "airpods pro 2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bapp\b"#, with: "airpods pro", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bapm\b"#, with: "airpods max", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bap\b"#, with: "airpods", options: .regularExpression)
        
        // --- 4. iPhone 系列合并缩写 ---
        // 16pm -> 16 pro max, 16p -> 16 pro
        text = text.replacingOccurrences(of: #"(?<=\d)\s*pm\b"#, with: " pro max", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?<=\d)\s*promax\b"#, with: " pro max", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?<=\d)\s*p\b"#, with: " pro", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?<=\d)\s*pro\b"#, with: " pro", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?<=\d)\s*plus\b"#, with: " plus", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\bpm\b"#, with: "pro max", options: .regularExpression)
        
        return text
    }
    
    // 智能多词模糊匹配（忽略括号、标点符号、全半角及“第/代”等中文字符，支持缩写与首字母匹配）
    private func matchesFuzzySearch(modelName: String, tokens: [String], rawQuery: String) -> Bool {
        let normalizedModel = normalizeForSearch(modelName)
        
        // 1. 生成模型名称的首字母缩写（例如 "iPhone 16 Pro Max" -> "16pm", "i16pm", "ip16pm"）
        let modelAcronym = generateModelAcronym(modelName)
        let compactQuery = rawQuery.replacingOccurrences(of: " ", with: "")
        if modelAcronym.contains(compactQuery) || compactQuery.contains(modelAcronym) {
            return true
        }
        
        // 2. 逐 token 模糊与同义匹配
        for token in tokens {
            let normalizedToken = normalizeForSearch(token)
            if normalizedModel.contains(normalizedToken) {
                continue
            }
            // 尝试去除常见中英文助词再次匹配
            let cleanModel = normalizedModel.replacingOccurrences(of: "第", with: "")
                .replacingOccurrences(of: "代", with: "")
                .replacingOccurrences(of: "年", with: "")
                .replacingOccurrences(of: "款", with: "")
            let cleanToken = normalizedToken.replacingOccurrences(of: "第", with: "")
                .replacingOccurrences(of: "代", with: "")
                .replacingOccurrences(of: "年", with: "")
                .replacingOccurrences(of: "款", with: "")
            
            if cleanModel.contains(cleanToken) {
                continue
            }
            
            return false
        }
        return true
    }
    
    // 提取型号的关键数字与单词首字母（如 "iPhone 16 Pro Max" 提取为 "16pm"）
    private func generateModelAcronym(_ name: String) -> String {
        let lower = name.lowercased()
        // 提取连续数字
        var digits = ""
        for c in lower where c.isNumber {
            digits.append(c)
        }
        
        var suffix = ""
        if lower.contains("pro max") {
            suffix = "pm"
        } else if lower.contains("pro") {
            suffix = "p"
        } else if lower.contains("plus") {
            suffix = "plus"
        } else if lower.contains("mini") {
            suffix = "mini"
        } else if lower.contains("ultra") {
            suffix = "ultra"
        }
        
        return digits + suffix
    }
    
    private func normalizeForSearch(_ text: String) -> String {
        var result = text.lowercased()
        // 统一全半角与标点符号
        let punctuations = ["（", "）", "(", ")", "【", "】", "[", "]", "、", "/", "-", "—", "，", ",", "・", "·"]
        for p in punctuations {
            result = result.replacingOccurrences(of: p, with: " ")
        }
        return result
    }
    
    private var activeProduct: OfficialProductModel? {
        if let match = currentCategoryProducts.first(where: { $0.modelName == selectedModel }) {
            return match
        }
        return currentCategoryProducts.first
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Global Navigation Header Bar
            topNavigationBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 2. Master-Detail Interactive Canvas
            if queryDomain == .repair {
                HStack(spacing: 0) {
                    // Left Column: Models Selector & Search Sidebar
                    leftModelsSidebar
                        .frame(width: 330)
                        .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // Right Column: High-Fidelity Repair Price Cards Grid
                    rightPricingDetailCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                }
            } else {
                // AC+ 购买价格查询预留视图
                appleCarePurchasePlaceholderView
            }
        }
        .onAppear {
            if selectedSeries.isEmpty {
                selectedSeries = availableSeries.first ?? ""
            }
            if selectedModel.isEmpty {
                selectedModel = availableModels.first ?? "iPhone 16 Pro"
            }
        }
        .onChange(of: selectedCategory) { _ in
            selectedSeries = availableSeries.first ?? ""
            selectedModel = availableModels.first ?? ""
        }
        .onChange(of: selectedSeries) { _ in
            if searchText.isEmpty {
                selectedModel = availableModels.first ?? ""
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = copyToastMessage {
                Text(toast)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showDiffSheet) {
            priceDiffSheetView
        }
        .alert("价格数据更新", isPresented: $showImportAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(importAlertMessage ?? "")
        }
    }
    
    // MARK: - 1. Top Header Bar with Segment Tabs, AC+ Toggle & Import Update
    
    private var topNavigationBar: some View {
        VStack(spacing: 10) {
            // 第一行：标题 + 顶层主类切换 (维修 vs AC+购买) + 状态 & 操作
            HStack(spacing: 12) {
                // Title & Icon
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "tag.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("价格查询")
                                .font(.system(size: 16, weight: .bold))
                            
                            Text("Apple 官方支持库")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        
                        Text("基准日期：\(pricingStore.lastUpdated)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 顶层双大类切换：【官方维修价格】 vs 【AC+ 购买价格】
                HStack(spacing: 2) {
                    ForEach(PriceQueryDomain.allCases) { domain in
                        let isSelected = (queryDomain == domain)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                queryDomain = domain
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: domain.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                Text(domain.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5.5)
                            .background(isSelected ? Color.blue : Color.clear)
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2.5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.leading, 6)
                
                Spacer()
                
                // 变动检测结果入口（如有）
                if !pricingStore.recentDiffRecords.isEmpty {
                    Button(action: {
                        showDiffSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("变动 (\(pricingStore.recentDiffRecords.count))")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5.5)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                // 数据维护菜单
                Menu {
                    Button {
                        Task {
                            await handleLiveWebsiteSync()
                        }
                    } label: {
                        Label("立即从 Apple 官网同步价格", systemImage: "network")
                    }
                    .disabled(pricingStore.isLiveSyncing)
                    
                    Divider()
                    
                    Toggle(isOn: Binding(
                        get: { pricingStore.isAutoMonitoringEnabled },
                        set: { pricingStore.setAutoMonitoring(enabled: $0) }
                    )) {
                        Label("后台自动监测 (检测变动自动通知)", systemImage: "bell.badge")
                    }
                    
                    Divider()
                    
                    Button {
                        handleImportFile()
                    } label: {
                        Label("导入外部快照文件 (HTML / JSON)...", systemImage: "doc.badge.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        pricingStore.resetToDefault()
                        selectedModel = availableModels.first ?? ""
                        importAlertMessage = "已恢复至出厂内置基准数据。"
                        showImportAlert = true
                    } label: {
                        Label("重置为出厂基准数据", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    HStack(spacing: 5) {
                        if pricingStore.isLiveSyncing {
                            ProgressView()
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                            Text("官网同步中...")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: pricingStore.isAutoMonitoringEnabled ? "shield.lefthalf.filled.badge.checkmark" : "arrow.triangle.2.circlepath")
                                .foregroundColor(pricingStore.isAutoMonitoringEnabled ? .green : .secondary)
                            Text(pricingStore.isAutoMonitoringEnabled ? "自动监测中" : "官网更新与同步")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5.5)
                    .background(pricingStore.isAutoMonitoringEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1))
                    .foregroundColor(pricingStore.isAutoMonitoringEnabled ? .green : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            
            // 第二行（仅在维修价格模式下显示）：品类标签组 (iPhone/iPad/Mac...) + AC+保外切换开关
            if queryDomain == .repair {
                HStack(spacing: 12) {
                    // 品类标签栏（单行横排，留足空间，绝不折行挤压）
                    HStack(spacing: 4) {
                        ForEach(OfficialCategory.allCases) { category in
                            let isSelected = (selectedCategory == category)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedCategory = category
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 11.5))
                                    Text(category.rawValue)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5.5)
                                .background(isSelected ? Color.blue : Color.clear)
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2.5)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Spacer()
                    
                    // 【有AC+】原生系统级开关（打开切换到 AppleCare+ 优惠价，关闭回到保外价格）
                    Toggle(isOn: $hasAppleCare.animation(.spring(response: 0.25, dampingFraction: 0.75))) {
                        HStack(spacing: 5) {
                            Image(systemName: hasAppleCare ? "checkmark.shield.fill" : "shield")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(hasAppleCare ? .green : .secondary)
                            
                            Text("有AC+")
                                .font(.system(size: 12.5, weight: hasAppleCare ? .bold : .medium))
                                .foregroundColor(hasAppleCare ? .primary : .secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - 2. Left Models List Sidebar
    
    private var leftModelsSidebar: some View {
        VStack(spacing: 0) {
            // Search Input Box
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("快速查找机型（如 16 Pro / M4 / Ultra）...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // 系列选择器（大尺寸醒目卡片下拉框，高辨识度且无需横向翻找）
            if searchText.isEmpty && availableSeries.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                        Text("所属产品系列")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("共 \(availableSeries.count) 个系列")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    
                    Menu {
                        ForEach(availableSeries, id: \.self) { s in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedSeries = s
                                    selectedModel = availableModels.first ?? ""
                                }
                            }) {
                                HStack {
                                    Text(s)
                                    if s == (selectedSeries.isEmpty ? availableSeries.first : selectedSeries) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 26, height: 26)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(selectedSeries.isEmpty ? (availableSeries.first ?? "") : selectedSeries)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("切换")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.04))
            }
            
            // Summary count
            HStack {
                if !searchText.isEmpty {
                    Text("搜索匹配到 \(availableModels.count) 款机型")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                } else {
                    let sName = selectedSeries.isEmpty ? (availableSeries.first ?? "") : selectedSeries
                    Text("\(sName) 共 \(availableModels.count) 款机型")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            
            Divider()
            
            // Models List
            if availableModels.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("未找到匹配机型")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(availableModels, id: \.self) { model in
                            let isSelected = (selectedModel == model || (selectedModel.isEmpty && model == availableModels.first))
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedModel = model
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedCategory.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(isSelected ? .white : .secondary)
                                    
                                    Text(model)
                                        .font(.system(size: 12.5, weight: isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.blue : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - 3. Right Pricing Detail Canvas
    
    private var rightPricingDetailCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let currentProduct = activeProduct {
                    // Header Banner for Selected Model
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentProduct.modelName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(hasAppleCare ? "已应用 AppleCare+ 专属优惠服务费（意外损坏或电池更换）" : "Apple 官方直营店 / AASP 授权服务商维修预估价格 (数据与官网完全对应)")
                                .font(.system(size: 12))
                                .foregroundColor(hasAppleCare ? .green : .secondary)
                        }
                        
                        Spacer()
                        
                        if hasAppleCare {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("AppleCare+ 保护中")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 4)
                    
                    // Cards Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                        ForEach(currentProduct.parts) { part in
                            partPriceCard(part: part)
                        }
                    }
                    
                    // Official Policy Guidance Footer Box
                    officialPolicyFooterBox
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无机型价格")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("请在左侧选取具体机型查看。")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(60)
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Part Price Card Component
    
    private func partPriceCard(part: OfficialPartItem) -> some View {
        let displayPrice = hasAppleCare ? part.officialACPrice : part.officialOOWPrice
        let cardColor = colorFromString(part.colorName)
        let isPriceExact = hasAppleCare || part.isExactPrice
        
        return Button(action: {
            if isPriceExact && displayPrice != "-" {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("RMB " + displayPrice, forType: .string)
                copyToastMessage = "已复制「\(part.partName)」价格: RMB \(displayPrice)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if copyToastMessage == "已复制「\(part.partName)」价格: RMB \(displayPrice)" {
                        copyToastMessage = nil
                    }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Top Row: Icon + Title
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(cardColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: part.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(cardColor)
                    }
                    
                    Text(part.partName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                Divider()
                
                // Bottom Row: Price display
                VStack(alignment: .leading, spacing: 4) {
                    if isPriceExact {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("RMB")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(hasAppleCare ? .green : .primary)
                            
                            Text(displayPrice)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(hasAppleCare ? .green : .primary)
                        }
                    } else {
                        Text(displayPrice)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text(part.note)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(hasAppleCare ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - AC+ 购买价格查询完整实装视图 (从官网爬取的官方计划价格数据驱动)
    
    @State private var acPurchaseCategory: OfficialCategory = .iphone
    @State private var acPurchaseSearchText: String = ""
    
    private var filteredAcPurchaseItems: [AppleCarePurchaseItem] {
        let list = pricingStore.appleCarePurchaseList.filter { $0.category == acPurchaseCategory }
        let query = acPurchaseSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return list }
        return list.filter {
            $0.modelName.lowercased().contains(query) ||
            $0.seriesName.lowercased().contains(query)
        }
    }
    
    private var appleCarePurchasePlaceholderView: some View {
        VStack(spacing: 0) {
            // 顶部专属品类与搜索过滤栏
            HStack(spacing: 12) {
                // 品类过滤
                HStack(spacing: 4) {
                    ForEach(OfficialCategory.allCases) { cat in
                        let isSelected = (acPurchaseCategory == cat)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                acPurchaseCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 11))
                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.blue : Color.clear)
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // 搜索过滤
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("查找 AC+ 购买机型（如 17 Pro / Air / M4）...", text: $acPurchaseSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .frame(maxWidth: 320)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 卡片展示区
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Banner
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AppleCare+ 服务计划官方购买价格")
                                .font(.system(size: 20, weight: .bold))
                            Text("数据直通 Apple 官方在线商城（全国官方零售统一定价，全款购买享受 \(acPurchaseCategory == .mac ? "3" : "2") 年意外保修与电池免费更换）")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    // Cards Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(filteredAcPurchaseItems) { item in
                            acPurchaseCard(item: item)
                        }
                    }
                    
                    // 底部购买权益说明
                    acPurchasePolicyBox
                }
                .padding(24)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
    
    private func acPurchaseCard(item: AppleCarePurchaseItem) -> some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.priceDisplay, forType: .string)
            copyToastMessage = "已复制「\(item.modelName)」AC+ 价格: \(item.priceDisplay)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if copyToastMessage == "已复制「\(item.modelName)」AC+ 价格: \(item.priceDisplay)" {
                    copyToastMessage = nil
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：所属系列 + 保障年限
                HStack {
                    Text(item.seriesName)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark")
                        Text("\(item.termYears) 年全保期")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                }
                
                // 机型名称
                Text(item.modelName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                // 核心权益点
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.features, id: \.self) { feat in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text(feat)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // 价格大字
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.priceDisplay)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text(item.note)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var acPurchasePolicyBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .foregroundColor(.blue)
                Text("AppleCare+ 购买规则与权益须知")
                    .font(.system(size: 12.5, weight: .bold))
            }
            
            Text("1. 购买期限：在购买新 Apple 产品之日起 7 天内，可通过设备上的“设置”直接购买；或在购买之日起 60 天内，前往 Apple Store 零售店（需设备检测）或致电官方支持热线 400-666-8800 购买。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            
            Text("2. 保障权益：提供不限次数的意外损坏保修服务；当电池容量低于其初始容量的 80% 时，免费更换电池；享有优先官方专家技术支持。针对 iPad 的服务计划同时涵盖一支兼容的 Apple Pencil 及原装键盘。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Footer Box
    
    private var officialPolicyFooterBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("官方维修政策与说明")
                    .font(.system(size: 12.5, weight: .bold))
            }
            
            Text("1. 以上定价 100% 对应 Apple 官方支持公开页面，包含增值税。具体需经 Apple Store 零售店或 Apple 授权服务提供商 (AASP) 技术人员最终检测为准。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            
            Text("2. AppleCare+ 服务费为全国统一标准：电池健康低于 80% 免服务费；意外损坏按照既定档位收取相应服务费。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 价格变动比对弹窗
    
    private var priceDiffSheetView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("价格变动监测报告")
                        .font(.system(size: 18, weight: .bold))
                    Text("共比对出 \(pricingStore.recentDiffRecords.count) 项与上一版本的差异")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("完成") {
                    showDiffSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            Table(pricingStore.recentDiffRecords) {
                TableColumn("品类") { r in
                    Text(r.category.rawValue)
                }
                .width(min: 80, ideal: 90)
                
                TableColumn("机型") { r in
                    Text(r.modelName).bold()
                }
                .width(min: 160, ideal: 220)
                
                TableColumn("维修项目") { r in
                    Text(r.partName)
                }
                .width(min: 120, ideal: 140)
                
                TableColumn("原价格") { r in
                    Text("RMB \(r.oldPrice)")
                        .foregroundColor(.secondary)
                }
                .width(min: 90, ideal: 100)
                
                TableColumn("新价格") { r in
                    Text("RMB \(r.newPrice)")
                        .bold()
                }
                .width(min: 90, ideal: 100)
                
                TableColumn("变动幅度") { r in
                    if let diff = r.diffAmount {
                        Text(diff > 0 ? "+RMB \(diff)" : "-RMB \(abs(diff))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(diff > 0 ? .red : .green)
                    } else {
                        Text(r.statusDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .width(min: 100, ideal: 120)
            }
        }
        .frame(minWidth: 780, minHeight: 460)
    }
    
    // MARK: - 官网实时在线同步操作
    
    private func handleLiveWebsiteSync() async {
        let result = await pricingStore.fetchLatestFromOfficialWebsite()
        switch result {
        case .success(let diffCount):
            selectedModel = availableModels.first ?? ""
            if diffCount > 0 {
                importAlertMessage = "官网数据同步完成！共检测到 \(diffCount) 处最新价格或机型变动，已为您生成比对报告。"
                showImportAlert = true
                showDiffSheet = true
            } else {
                importAlertMessage = "官网同步成功！当前所有机型价格与 Apple 官方支持最新公示完全一致，暂无变动。"
                showImportAlert = true
            }
        case .failure(let error):
            importAlertMessage = "连接官网同步失败：\(error.localizedDescription)"
            showImportAlert = true
        }
    }
    
    // MARK: - 文件导入操作
    
    private func handleImportFile() {
        let panel = NSOpenPanel()
        panel.title = "选择新版 Apple 价格数据文件 (HTML 或 JSON)"
        panel.allowedContentTypes = [UTType.html, UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let selectedUrl = panel.url {
            let result = pricingStore.importFromFile(url: selectedUrl)
            switch result {
            case .success(let diffCount):
                selectedModel = availableModels.first ?? ""
                if diffCount > 0 {
                    importAlertMessage = "导入成功！共检测到 \(diffCount) 处价格或机型变动，已为您生成比对报告。"
                    showImportAlert = true
                    showDiffSheet = true
                } else {
                    importAlertMessage = "导入成功！当前数据库已刷新，价格与所选文件一致。"
                    showImportAlert = true
                }
            case .failure(let error):
                importAlertMessage = "导入失败：\(error.localizedDescription)"
                showImportAlert = true
            }
        }
    }
    
    private func colorFromString(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "teal": return .teal
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        default: return .blue
        }
    }
}
