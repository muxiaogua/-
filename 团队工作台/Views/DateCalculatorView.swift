//
//  DateCalculatorView.swift
//  团队工作台
//
//

import SwiftUI
import AppKit

public struct DateCalculatorView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Core parameters
    @State private var basePurchaseDate: Date = Date()
    @State private var iphonePriceText: String = ""
    @State private var customPrice: Double = 0.0
    
    // Auxiliary tab selection for advanced tools if needed
    enum CalculatorMode: String, CaseIterable, Identifiable {
        case appleCareAndTradeIn = "AC+与年年焕新"
        case customOffset = "自由日期推算"
        case businessDays = "工作日计算"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .appleCareAndTradeIn: return "apple.logo"
            case .customOffset: return "calendar.badge.plus"
            case .businessDays: return "briefcase.fill"
            }
        }
    }
    
    @State private var selectedMode: CalculatorMode = .appleCareAndTradeIn
    
    // Extra states for advanced modes
    @State private var offsetAmount: Int = 30
    @State private var offsetDirectionFuture: Bool = true
    @State private var businessDaysCount: Int = 7
    @State private var excludeWeekends: Bool = true
    
    @State private var copiedFeedback: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header
            headerBar
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            // Mode Segmented Switcher Bar
            modeSwitcherBar
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    colorScheme == .dark
                        ? Color(NSColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 0.8))
                        : Color(NSColor.controlBackgroundColor).opacity(0.8)
                )
            
            Divider()
                .opacity(0.4)
            
            // Main Content Area
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedMode {
                    case .appleCareAndTradeIn:
                        appleCareAndTradeInDashboard
                    case .customOffset:
                        customOffsetSection
                    case .businessDays:
                        businessDaysSection
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: 960)
            }
            .frame(maxWidth: .infinity)
        }
        .background(pageBackgroundView)
    }
    
    // MARK: - Dynamic Background
    
    private var pageBackgroundView: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)),
                        Color(NSColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1.0))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)),
                        Color(NSColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("日期计算器")
                        .font(.system(size: 22, weight: .bold))
                }
                
                Text("实时推算 AC+ 加购期限、退款时间窗口、iPhone 年年焕新计划及折抵残值保障")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let copied = copiedFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已复制: \(copied)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    // MARK: - Mode Switcher Bar
    
    private var modeSwitcherBar: some View {
        HStack(spacing: 12) {
            ForEach(CalculatorMode.allCases) { mode in
                let isSelected = (selectedMode == mode)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.7))
                    )
                    .foregroundColor(isSelected ? .white : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: isSelected ? Color.green.opacity(0.3) : Color.clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 1. AppleCare+ & 年年焕新专用看板 (对齐用户UI设计)
    
    private var appleCareAndTradeInDashboard: some View {
        VStack(spacing: 18) {
            // 1. 核心参数配置卡片
            coreConfigCard
            
            // 2. AppleCare+ 加购期限
            appleCareSectionCard
            
            // 3. Applecare+ 退款期限
            refundSectionCard
            
            // 4. iPhone 年年焕新计划
            upgradeProgramSectionCard
        }
    }
    
    // 1. 核心参数配置
    private var coreConfigCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Text("核心参数配置")
                    .font(.system(size: 14, weight: .bold))
            }
            
            HStack(alignment: .top, spacing: 24) {
                // 左侧：购买日/生效日（醒目重构）
                VStack(alignment: .leading, spacing: 10) {
                    Text("设备原始购买日 / AC+ 生效日")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // 醒目的高对比度日期选择控制条
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                        
                        DatePicker("", selection: $basePurchaseDate, displayedComponents: [.date])
                            .datePickerStyle(.field)
                            .labelsHidden()
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        
                        Text(weekdayName(for: basePurchaseDate))
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.18))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        colorScheme == .dark
                            ? Color(NSColor(red: 0.12, green: 0.18, blue: 0.15, alpha: 1.0))
                            : Color.green.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1.2)
                    )
                    
                    // 快捷按钮：今天、昨天、7天前、30天前
                    HStack(spacing: 8) {
                        quickDateButton(title: "今天", daysAgo: 0)
                        quickDateButton(title: "昨天", daysAgo: 1)
                        quickDateButton(title: "7天前", daysAgo: 7)
                        quickDateButton(title: "30天前", daysAgo: 30)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右侧：iPhone 原始购买价格
                VStack(alignment: .leading, spacing: 10) {
                    Text("iPhone 原始购买价格 (¥)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("¥")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.green)
                        
                        TextField("请输入原始售价 (如 7999)", text: $iphonePriceText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .onChange(of: iphonePriceText) { _, newVal in
                                let filtered = newVal.filter { "0123456789.".contains($0) }
                                if let val = Double(filtered) {
                                    customPrice = val
                                } else if filtered.isEmpty {
                                    customPrice = 0
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8.5)
                    .background(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    
                    // 辅助说明
                    Text("输入设备原价，自动计算年年焕新计划保障的 50% 折抵保底残值")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // 2. AppleCare+ 加购期限卡片
    private var appleCareSectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Text("AppleCare+ 加购期限")
                    .font(.system(size: 14, weight: .bold))
            }
            
            let online7Days = calculateDate(from: basePurchaseDate, addDays: 7)
            let standard60Days = calculateDate(from: basePurchaseDate, addDays: 60)
            
            HStack(spacing: 16) {
                // 7天内线上加购
                dualMetricSubcard(
                    subtitle: "7天内线上加购截至",
                    dateString: formatDate(online7Days),
                    note: "购买日 + 7天 (\(weekdayName(for: online7Days)))",
                    accentColor: .green,
                    copyText: "AppleCare+ 7天线上加购截止日：\(formatDate(online7Days)) (\(weekdayName(for: online7Days)))"
                )
                
                // 60天标准加购
                dualMetricSubcard(
                    subtitle: "60天标准加购期截至",
                    dateString: formatDate(standard60Days),
                    note: "购买日 + 60天 (\(weekdayName(for: standard60Days)))",
                    accentColor: .green,
                    copyText: "AppleCare+ 60天标准加购截止日：\(formatDate(standard60Days)) (\(weekdayName(for: standard60Days)))"
                )
            }
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // 3. Applecare+ 退款期限卡片
    private var refundSectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                Text("Applecare+ 退款期限")
                    .font(.system(size: 14, weight: .bold))
            }
            
            let contactAARefundDate = calculateDate(from: basePurchaseDate, addDays: 16)
            let acRefund30Days = calculateDate(from: basePurchaseDate, addDays: 30)
            
            HStack(spacing: 16) {
                // 联系AA退款时间（购买之日起已过15天，即第16天起）
                dualMetricSubcard(
                    subtitle: "联系AA退款时间",
                    dateString: formatDate(contactAARefundDate),
                    note: "购买之日起已过 15 天 (第16天起 / \(weekdayName(for: contactAARefundDate)))",
                    accentColor: .orange,
                    copyText: "联系AA退款起始时间：\(formatDate(contactAARefundDate)) (自购买日起已过15天，第16天起)"
                )
                
                // 30天AC+全额退订
                dualMetricSubcard(
                    subtitle: "30天AC+全额退订截至",
                    dateString: formatDate(acRefund30Days),
                    note: "生效日 + 30天 (\(weekdayName(for: acRefund30Days)))",
                    accentColor: .orange,
                    copyText: "30天AC+全额退订截止日：\(formatDate(acRefund30Days)) (\(weekdayName(for: acRefund30Days)))"
                )
            }
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // 4. iPhone 年年焕新计划卡片
    private var upgradeProgramSectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.capsulepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                Text("iPhone 年年焕新计划")
                    .font(.system(size: 14, weight: .bold))
            }
            
            let startUpgradeDate = calculateDate(from: basePurchaseDate, addMonths: 3)
            let endUpgradeDate = calculateDate(from: basePurchaseDate, addMonths: 15)
            let guaranteedValue = max(0, customPrice * 0.5)
            let statusTuple = getUpgradeStatus(start: startUpgradeDate, end: endUpgradeDate)
            
            HStack(spacing: 16) {
                // 左侧：焕新资格时间窗口
                VStack(alignment: .leading, spacing: 8) {
                    Text("焕新资格时间窗口 (第3-15个月)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formatDate(startUpgradeDate))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                        
                        Text("至")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(endUpgradeDate))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: statusTuple.icon)
                            .foregroundColor(statusTuple.color)
                        Text(statusTuple.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusTuple.color)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(subcardInnerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
                )
                
                // 右侧：折抵残值保障
                VStack(alignment: .leading, spacing: 8) {
                    Text("设备折抵残值保障 (至少50%)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if customPrice > 0 {
                        Text(formatCurrency(guaranteedValue))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("用于抵扣新款 iPhone")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("上方输入售价后自动计算")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let valueStr = customPrice > 0 ? formatCurrency(guaranteedValue) : "以实际售价50%为准"
                        let text = "iPhone年年焕新：资格窗口 \(formatDate(startUpgradeDate)) 至 \(formatDate(endUpgradeDate))，保底折抵价值 \(valueStr)"
                        copyToClipboard(text)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("复制方案明细")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(subcardInnerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.18), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // MARK: - Modern Color Theme
    
    private var modernCardBackground: Color {
        if colorScheme == .dark {
            return Color(NSColor(red: 0.12, green: 0.15, blue: 0.17, alpha: 0.95))
        } else {
            return Color.white
        }
    }
    
    private var subcardInnerBackground: Color {
        if colorScheme == .dark {
            return Color(NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 0.75))
        } else {
            return Color(NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0))
        }
    }
    
    private var cardBorderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08)
        } else {
            return Color.black.opacity(0.06)
        }
    }
    
    private var cardShadowColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.3)
        } else {
            return Color.black.opacity(0.04)
        }
    }
    
    private func quickDateButton(title: String, daysAgo: Int) -> some View {
        Button(action: {
            withAnimation {
                if daysAgo == 0 {
                    basePurchaseDate = Date()
                } else {
                    basePurchaseDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                }
            }
        }) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 4.5)
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.07)
                        : Color.black.opacity(0.04)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func dualMetricSubcard(subtitle: String, dateString: String, note: String, accentColor: Color, copyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(dateString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
            
            HStack {
                Text(note)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard(copyText)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(subcardInnerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - 2. 自由日期推算 (Mode 2)
    
    private var customOffsetSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("自由日期增减推算")
                .font(.system(size: 14, weight: .bold))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("基准日期")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $basePurchaseDate, displayedComponents: [.date])
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("推算天数")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("天数", value: $offsetAmount, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("推算方向")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Picker("", selection: $offsetDirectionFuture) {
                        Text("往后推算 (将来)").tag(true)
                        Text("往前倒推 (过去)").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            
            HStack(spacing: 8) {
                Text("快捷天数:")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                ForEach([7, 14, 15, 30, 60, 90, 180, 365], id: \.self) { days in
                    Button("+\(days)天") {
                        offsetAmount = days
                        offsetDirectionFuture = true
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            let result = calculateDate(from: basePurchaseDate, addDays: offsetDirectionFuture ? offsetAmount : -offsetAmount)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("推算目标日期")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(formatDate(result))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("基准日 \(formatDate(basePurchaseDate)) \(offsetDirectionFuture ? "往后" : "往前") \(offsetAmount) 天 (\(weekdayName(for: result)))")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("一键复制结果") {
                    copyToClipboard("推算结果：\(formatDate(result)) (\(weekdayName(for: result)))")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(subcardInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // MARK: - 3. 工作日计算 (Mode 3)
    
    private var businessDaysSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("排除周末的工作日时效计算 (如退款处理、返厂维修)")
                .font(.system(size: 14, weight: .bold))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("起始日期")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $basePurchaseDate, displayedComponents: [.date])
                        .datePickerStyle(.field)
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("工作日数量")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Stepper("\(businessDaysCount) 个工作日", value: $businessDaysCount, in: 1...60)
                }
                
                Toggle("自动跳过周六日", isOn: $excludeWeekends)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .padding(.top, 16)
            }
            
            let result = calculateBusinessDays(from: basePurchaseDate, count: businessDaysCount, skipWeekends: excludeWeekends)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预计送达/完成日期")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(formatDate(result))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("从 \(formatDate(basePurchaseDate)) 顺延 \(businessDaysCount) 个工作日 (\(weekdayName(for: result)))")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("复制结果") {
                    copyToClipboard("预计完成日期：\(formatDate(result)) (\(weekdayName(for: result)))")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(subcardInnerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // MARK: - Logic Calculations
    
    private func calculateDate(from base: Date, addDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: addDays, to: base) ?? base
    }
    
    private func calculateDate(from base: Date, addMonths: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: addMonths, to: base) ?? base
    }
    
    private func calculateBusinessDays(from base: Date, count: Int, skipWeekends: Bool) -> Date {
        let cal = Calendar.current
        var current = cal.startOfDay(for: base)
        var added = 0
        while added < count {
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            if skipWeekends {
                let wd = cal.component(.weekday, from: current)
                if wd != 1 && wd != 7 {
                    added += 1
                }
            } else {
                added += 1
            }
        }
        return current
    }
    
    private func getUpgradeStatus(start: Date, end: Date) -> (text: String, icon: String, color: Color) {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let startDate = cal.startOfDay(for: start)
        let endDate = cal.startOfDay(for: end)
        
        if today < startDate {
            return ("未到期：尚未进入焕新资格期", "hourglass.badge.plus", .orange)
        } else if today <= endDate {
            return ("正当时：当前处于年年焕新资格期内", "checkmark.seal.fill", .green)
        } else {
            return ("已过期：已超出年年焕新资格时间窗口", "xmark.octagon.fill", .red)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    
    private func weekdayName(for date: Date) -> String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return ""
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        return String(format: "¥%.2f", value)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedFeedback = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            copiedFeedback = nil
        }
    }
}

#Preview {
    DateCalculatorView()
}
