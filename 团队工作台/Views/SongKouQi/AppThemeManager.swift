//
//  AppThemeManager.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI
import Combine

// MARK: - App 语言设置管理器 (仅保留简体中文和繁體中文)

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh_Hans"
    case traditionalChinese = "zh_Hant"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
    
    var locale: Locale {
        switch self {
        case .simplifiedChinese: return Locale(identifier: "zh_CN")
        case .traditionalChinese: return Locale(identifier: "zh_TW")
        }
    }
}

final class AppLanguageManager: ObservableObject {
    static let shared = AppLanguageManager()
    
    @AppStorage("selected_app_language") var currentLanguageRaw: String = AppLanguage.simplifiedChinese.rawValue
    
    var currentLanguage: AppLanguage {
        get { AppLanguage(rawValue: currentLanguageRaw) ?? .simplifiedChinese }
        set {
            currentLanguageRaw = newValue.rawValue
            cache.removeAll()
            objectWillChange.send()
        }
    }
    
    private var cache: [String: String] = [:]
    
    func localize(_ text: String) -> String {
        guard currentLanguage == .traditionalChinese else { return text }
        if let cached = cache[text] {
            return cached
        }
        let transformed = text.applyingTransform(StringTransform(rawValue: "Hans-Hant"), reverse: false) ?? text
        cache[text] = transformed
        return transformed
    }
    
    private init() {}
}

// 全局便捷多语言转换函数
@inline(__always)
func t(_ text: String) -> String {
    AppLanguageManager.shared.localize(text)
}

extension String {
    var localized: String {
        AppLanguageManager.shared.localize(self)
    }
}

// MARK: - 预设经典禅意五大整套主题色系
enum AppThemePreset: String, CaseIterable, Identifiable {
    case obsidianGold = "玄墨金石"
    case bambooGreen = "青黛竹影"
    case forbiddenRed = "紫禁朱华"
    case mistyBlue = "苍山晴岚"
    case twilightRose = "暮夜暖胭"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.localized
    }
    
    var subtitle: String {
        switch self {
        case .obsidianGold: return t("玄墨青岩・雅金点缀")
        case .bambooGreen: return t("幽林青黛・翠竹初醒")
        case .forbiddenRed: return t("红墙落日・暖栗宫金")
        case .mistyBlue: return t("苍山晴岚・霁蓝清空")
        case .twilightRose: return t("暮色晚霞・暖胭舒缓")
        }
    }
    
    private static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        }))
    }
    
    // 1. 主强调色 (按钮、激活图标、重要高光) - 自适应系统外观
    var primaryAccent: Color {
        switch self {
        case .obsidianGold:
            return Self.dynamicColor(light: Color(hex: "#B8860B")!, dark: Color(hex: "#EBB338")!)
        case .bambooGreen:
            return Self.dynamicColor(light: Color(hex: "#059669")!, dark: Color(hex: "#45E29E")!)
        case .forbiddenRed:
            return Self.dynamicColor(light: Color(hex: "#DC2626")!, dark: Color(hex: "#FF6B57")!)
        case .mistyBlue:
            return Self.dynamicColor(light: Color(hex: "#0284C7")!, dark: Color(hex: "#4FC4FF")!)
        case .twilightRose:
            return Self.dynamicColor(light: Color(hex: "#C026D3")!, dark: Color(hex: "#F484B6")!)
        }
    }
    
    // 2. 次级强调色 (副高光、次级按钮、特殊徽章)
    var secondaryAccent: Color {
        switch self {
        case .obsidianGold:
            return Self.dynamicColor(light: Color(hex: "#D97706")!, dark: Color(hex: "#F5D076")!)
        case .bambooGreen:
            return Self.dynamicColor(light: Color(hex: "#10B981")!, dark: Color(hex: "#8BEFBF")!)
        case .forbiddenRed:
            return Self.dynamicColor(light: Color(hex: "#EA580C")!, dark: Color(hex: "#FCA268")!)
        case .mistyBlue:
            return Self.dynamicColor(light: Color(hex: "#38BDF8")!, dark: Color(hex: "#90E4FF")!)
        case .twilightRose:
            return Self.dynamicColor(light: Color(hex: "#E879F9")!, dark: Color(hex: "#FFB0D5")!)
        }
    }
    
    // 3. 全局整套背景渐变色 (浅色模式下完美融入 macOS 窗口底色，深色模式下深邃禅意)
    var backgroundGradient: [Color] {
        let bg1 = Self.dynamicColor(light: Color(NSColor.windowBackgroundColor), dark: Color(hex: "#161920")!)
        let bg2 = Self.dynamicColor(light: Color(NSColor.windowBackgroundColor), dark: Color(hex: "#1D212B")!)
        let bg3 = Self.dynamicColor(light: Color(NSColor.windowBackgroundColor), dark: Color(hex: "#252B38")!)
        return [bg1, bg2, bg3]
    }
    
    // 4. 卡片容器背景色 (浅色模式为原生纯白卡片，深色模式为沉浸暗黑卡片)
    var cardBackground: Color {
        Self.dynamicColor(
            light: Color(NSColor.controlBackgroundColor),
            dark: Color(hex: "#262C3A")!.opacity(0.85)
        )
    }
    
    // 5. 次级卡片 / 胶囊背景色
    var secondaryCardBackground: Color {
        Self.dynamicColor(
            light: Color(hex: "#F1F3F5")!,
            dark: Color(hex: "#323A4C")!.opacity(0.9)
        )
    }
    
    // 6. 主标题与正文字体颜色 (高清晰度、自动适配黑白背景)
    var textPrimary: Color {
        Self.dynamicColor(light: Color(NSColor.labelColor), dark: Color(hex: "#FAF7EE")!)
    }
    
    // 7. 副标题与次要文字颜色
    var textSecondary: Color {
        Self.dynamicColor(light: Color(NSColor.secondaryLabelColor), dark: Color(hex: "#C5BEAD")!)
    }
    
    // 8. 辅助文字与说明文字颜色
    var textTertiary: Color {
        Self.dynamicColor(light: Color(NSColor.tertiaryLabelColor), dark: Color(hex: "#968F7E")!)
    }
    
    // 9. 边框与分割线颜色
    var borderColor: Color {
        Self.dynamicColor(
            light: Color.secondary.opacity(0.15),
            dark: primaryAccent.opacity(0.35)
        )
    }
    
    // 10. 光晕与阴影氛围色
    var glowColor: Color {
        Self.dynamicColor(
            light: Color.black.opacity(0.04),
            dark: primaryAccent.opacity(0.3)
        )
    }
}

// MARK: - 全局主题管理器
final class AppThemeManager: ObservableObject {
    static let shared = AppThemeManager()
    
    @AppStorage("app_theme_preset") var currentPresetRaw: String = AppThemePreset.obsidianGold.rawValue
    
    var currentPreset: AppThemePreset {
        get { AppThemePreset(rawValue: currentPresetRaw) ?? .obsidianGold }
        set {
            currentPresetRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var accentColor: Color { currentPreset.primaryAccent }
    var secondaryAccent: Color { currentPreset.secondaryAccent }
    var backgroundColors: [Color] { currentPreset.backgroundGradient }
    var cardBackground: Color { currentPreset.cardBackground }
    var secondaryCardBackground: Color { currentPreset.secondaryCardBackground }
    var textPrimary: Color { currentPreset.textPrimary }
    var textSecondary: Color { currentPreset.textSecondary }
    var textTertiary: Color { currentPreset.textTertiary }
    var borderColor: Color { currentPreset.borderColor }
    var glowColor: Color { currentPreset.glowColor }
    
    private init() {}
}

// MARK: - Color Hex 扩展
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
