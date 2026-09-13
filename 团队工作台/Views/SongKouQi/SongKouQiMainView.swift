//
//  SongKouQiMainView.swift
//  团队工作台
//

import SwiftUI

enum MainAppModule: String, CaseIterable, Identifiable {
    case jingxin = "静心阁"
    case treeHole = "树洞"
    case deskRelax = "拯救低头族"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .jingxin: return "sparkles"
        case .treeHole: return "tree.fill"
        case .deskRelax: return "figure.mind.and.body"
        }
    }
    
    var title: String {
        rawValue.localized
    }
    
    var subtitle: String {
        switch self {
        case .jingxin: return t("木鱼・烧香・抽签")
        case .treeHole: return t("倾诉・消散・回响")
        case .deskRelax: return t("眼・颈・腕・腿")
        }
    }
}

public struct SongKouQiMainView: View {
    @ObservedObject var appState = AppStateManager.shared
    @ObservedObject var themeManager = AppThemeManager.shared
    @ObservedObject var languageManager = AppLanguageManager.shared
    @State private var currentModule: MainAppModule = .jingxin
    @State private var isThemeSheetOpen: Bool = false
    
    public init() {}
    
    public var body: some View {
        Group {
            switch appState.miniMode {
            case .muyu:
                PureMuyuView()
            case .incense:
                PureIncenseView()
            case .none:
                fullMainView
            }
        }
        .id(languageManager.currentLanguageRaw + themeManager.currentPresetRaw)
        .sheet(isPresented: $isThemeSheetOpen) {
            AppThemeSettingsSheet()
        }
    }
    
    // MARK: - 完整主界面
    private var fullMainView: some View {
        ZStack(alignment: .top) {
            // 全局主题背景渐变 (浅色自适应)
            LinearGradient(
                colors: themeManager.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部三大模块全局切换栏
                topModuleNavigation
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                // 模块主界面展示
                ZStack(alignment: .top) {
                    switch currentModule {
                    case .jingxin:
                        JingXinPavilionView()
                            .transition(.opacity)
                    case .treeHole:
                        TreeHoleView()
                            .transition(.opacity)
                    case .deskRelax:
                        DeskRelaxView()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 顶部三大模块切换栏
    private var topModuleNavigation: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(MainAppModule.allCases) { module in
                    let isSelected = (currentModule == module)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentModule = module
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: module.icon)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            Text(module.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            Text("(\(module.subtitle))")
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? themeManager.accentColor : themeManager.textSecondary.opacity(0.7))
                        }
                        .foregroundColor(isSelected ? themeManager.accentColor : themeManager.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? themeManager.accentColor.opacity(0.14) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(themeManager.secondaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(themeManager.borderColor, lineWidth: 1)
            )
            
            Spacer()
            
            // 语言切换菜单 (简体中文 / 繁體中文)
            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        languageManager.currentLanguage = lang
                    } label: {
                        HStack {
                            Text(lang.displayName)
                            if languageManager.currentLanguage == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.accentColor)
                    Text(languageManager.currentLanguage.displayName)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(themeManager.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeManager.secondaryCardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // 全局主题配色切换按钮
            Button {
                isThemeSheetOpen = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.accentColor)
                    Text(themeManager.currentPreset.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(themeManager.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.secondaryCardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(themeManager.accentColor.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(t("切换经典禅意预设色系"))
        }
    }
}

// MARK: - 全局主题调色盘弹窗
struct AppThemeSettingsSheet: View {
    @ObservedObject var themeManager = AppThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.accentColor)
                    Text(t("软件主题配色"))
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.textPrimary)
                }
                Spacer()
                Button(t("完成")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.accentColor)
            }
            
            Divider()
                .background(themeManager.borderColor.opacity(0.4))
            
            // 经典禅意五大整套预设色系
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("经典禅意预设色系 (整套配色联动)"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.textSecondary)
                    
                    Spacer()
                    
                    Text(t("背景・主色调・高对比字体全面换肤"))
                        .font(.caption2)
                        .foregroundColor(themeManager.textTertiary)
                }
                
                VStack(spacing: 9) {
                    ForEach(AppThemePreset.allCases) { preset in
                        let isSelected = (themeManager.currentPreset == preset)
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                themeManager.currentPreset = preset
                            }
                        } label: {
                            HStack(spacing: 14) {
                                // 色彩徽章组合预览
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(preset.primaryAccent)
                                        .frame(width: 16, height: 16)
                                        .shadow(color: preset.primaryAccent.opacity(0.6), radius: 3)
                                    Circle()
                                        .fill(preset.secondaryAccent)
                                        .frame(width: 12, height: 12)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(preset.cardBackground)
                                        .frame(width: 14, height: 14)
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(preset.textPrimary.opacity(0.4), lineWidth: 1))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.25)))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.displayName)
                                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .serif))
                                        .foregroundColor(preset.textPrimary)
                                    
                                    Text(preset.subtitle)
                                        .font(.caption2)
                                        .foregroundColor(preset.textSecondary)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(preset.primaryAccent)
                                        Text(t("当前生效"))
                                            .font(.system(size: 11, weight: .bold, design: .serif))
                                            .foregroundColor(preset.primaryAccent)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(preset.primaryAccent.opacity(0.18)))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: preset.backgroundGradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? preset.primaryAccent : preset.borderColor.opacity(0.4), lineWidth: isSelected ? 1.8 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(
            LinearGradient(
                colors: themeManager.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview {
    SongKouQiMainView()
}
