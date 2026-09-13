//
//  JingXinPavilionView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct JingXinPavilionView: View {
    @ObservedObject var themeManager = AppThemeManager.shared
    
    var body: some View {
        ZStack {
            // 背景深邃水墨渐变（跟随全局主题色）
            LinearGradient(
                colors: themeManager.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 东方水墨远山淡影
            ZenMountainBackground()
                .opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 顶部标题横幅
                pavilionHeader
                
                // 单页核心展示区：三栏并列（敲木鱼、烧香、求签）
                HStack(alignment: .top, spacing: 14) {
                    // 第一个模块：敲木鱼
                    MuyuView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 第二个模块：烧香
                    IncenseView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 第三个模块：签签好运
                    FortuneDivinationView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)
        }
    }
    
    // MARK: - 顶部导航
    private var pavilionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(t("静心阁"))
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.textPrimary,
                                    themeManager.accentColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(t("・ 禅心所"))
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                
                Text(t("敲木鱼积德解压 ｜ 烧清香祈福许愿 ｜ 签签好运"))
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(themeManager.textSecondary)
            }
            
            Spacer()
            
            // 静心标语徽章
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(themeManager.accentColor)
                Text(t("心若止水・万虑自消"))
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(themeManager.secondaryCardBackground)
                    .overlay(
                        Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - 水墨远山背景
struct ZenMountainBackground: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            var p1 = Path()
            p1.move(to: CGPoint(x: 0, y: h * 0.75))
            p1.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.55),
                        control1: CGPoint(x: w * 0.15, y: h * 0.58),
                        control2: CGPoint(x: w * 0.30, y: h * 0.52))
            p1.addCurve(to: CGPoint(x: w, y: h * 0.78),
                        control1: CGPoint(x: w * 0.65, y: h * 0.60),
                        control2: CGPoint(x: w * 0.85, y: h * 0.72))
            p1.addLine(to: CGPoint(x: w, y: h))
            p1.addLine(to: CGPoint(x: 0, y: h))
            p1.closeSubpath()
            context.fill(p1, with: .color(Color.primary.opacity(0.04)))
            
            var p2 = Path()
            p2.move(to: CGPoint(x: 0, y: h * 0.88))
            p2.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.70),
                        control1: CGPoint(x: w * 0.25, y: h * 0.72),
                        control2: CGPoint(x: w * 0.45, y: h * 0.66))
            p2.addCurve(to: CGPoint(x: w, y: h * 0.90),
                        control1: CGPoint(x: w * 0.75, y: h * 0.74),
                        control2: CGPoint(x: w * 0.90, y: h * 0.84))
            p2.addLine(to: CGPoint(x: w, y: h))
            p2.addLine(to: CGPoint(x: 0, y: h))
            p2.closeSubpath()
            context.fill(p2, with: .color(Color.primary.opacity(0.07)))
        }
    }
}
