//
//  FortuneDivinationView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct FortuneDivinationView: View {
    @ObservedObject var themeManager = AppThemeManager.shared
    
    @State private var currentFortune: CustomerServiceFortune? = nil
    @State private var isDrawing: Bool = false
    @State private var isStickRising: Bool = false
    @State private var isCardRevealed: Bool = false
    
    // 签筒摇动动画参数
    @State private var cylinderAngle: Double = 0.0
    @State private var cylinderYOffset: CGFloat = 0.0
    @State private var stickJiggleOffsets: [CGFloat] = [0, 0, 0, 0, 0, 0, 0]
    @State private var luckyStickOffset: CGFloat = 0.0
    @State private var buttonText: String = "摇签祈福"
    
    @State private var shakeTimer: Timer? = nil
    @State private var shakeStep: Int = 0
    
    var body: some View {
        VStack(spacing: 10) {
            headerBar
            contentArea
            drawActionButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.borderColor, lineWidth: 1)
                )
        )
    }
    
    // MARK: - 顶部栏
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("🎋")
                    .font(.system(size: 16))
                Text(t("签签好运"))
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
            }
            Spacer()
            
            if currentFortune != nil {
                Button {
                    startShakeAndDraw()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text(t("再摇一签"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(themeManager.accentColor.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDrawing)
            }
        }
    }
    
    // MARK: - 内容展示区 (签筒摇动出签 与 灵签卡片展示)
    private var contentArea: some View {
        ZStack {
            if !isCardRevealed {
                // 签筒与摇签出签动态视图
                VStack(spacing: 0) {
                    Spacer()
                    bambooCylinderAndSticksView
                    Spacer()
                }
                .transition(.opacity)
            } else if let fortune = currentFortune {
                // 翻转展开的灵签结果卡片
                fortuneResultCard(fortune: fortune)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部操作按钮
    private var drawActionButton: some View {
        Button {
            startShakeAndDraw()
        } label: {
            HStack(spacing: 8) {
                if isDrawing {
                    ProgressView()
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: isCardRevealed ? "arrow.clockwise" : "hands.sparkles.fill")
                }
                Text(t(buttonText))
                    .font(.system(size: 13, weight: .semibold, design: .serif))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.accentColor,
                                themeManager.accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: themeManager.glowColor, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isDrawing)
    }
    
    // MARK: - 拟真竹质签筒与出签动态组件
    private var bambooCylinderAndSticksView: some View {
        ZStack(alignment: .bottom) {
            // 1. 签筒底部环境光遮蔽阴影
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 26)
                .offset(y: 12)
            
            // 2. 签筒主体与签条组合（随摇签动作倾斜与上下起伏）
            ZStack(alignment: .bottom) {
                // 2.1 筒内背景暗部（筒内空腔）
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.12, green: 0.08, blue: 0.05))
                    .frame(width: 72, height: 110)
                    .offset(y: -4)
                
                // 2.2 筒内群签（错落排布在签筒内，摇晃时上下错动跳跃）
                ZStack(alignment: .bottom) {
                    // 左侧签
                    singleBambooStick(angle: -16, width: 8, height: 125, yOffset: stickJiggleOffsets[0])
                        .offset(x: -22, y: -18)
                    singleBambooStick(angle: -10, width: 9, height: 135, yOffset: stickJiggleOffsets[1])
                        .offset(x: -12, y: -24)
                    singleBambooStick(angle: -4, width: 8.5, height: 130, yOffset: stickJiggleOffsets[2])
                        .offset(x: -5, y: -20)
                    
                    // 右侧签
                    singleBambooStick(angle: 5, width: 8.5, height: 132, yOffset: stickJiggleOffsets[3])
                        .offset(x: 6, y: -21)
                    singleBambooStick(angle: 11, width: 9, height: 138, yOffset: stickJiggleOffsets[4])
                        .offset(x: 14, y: -25)
                    singleBambooStick(angle: 18, width: 8, height: 124, yOffset: stickJiggleOffsets[5])
                        .offset(x: 23, y: -17)
                    
                    // 2.3 当选中出的【当选灵签】（摇签时最高并向外跃升出筒）
                    luckyRisingStick
                        .offset(x: 1, y: -30 + luckyStickOffset)
                }
                
                // 2.4 竹木签筒外壁 (前挡板 + 铜箍包边 + 红色福籤印章)
                cylinderFrontWall
            }
            .rotationEffect(.degrees(cylinderAngle), anchor: .bottom)
            .offset(y: cylinderYOffset)
        }
        .frame(width: 120, height: 175)
        .scaleEffect(2.0)
        .frame(width: 240, height: 350)
    }
    
    // MARK: - 单支竹签子组件
    private func singleBambooStick(angle: Double, width: CGFloat, height: CGFloat, yOffset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // 竹签本体
            RoundedRectangle(cornerRadius: 2.5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.82, blue: 0.58),
                            Color(red: 0.78, green: 0.62, blue: 0.38),
                            Color(red: 0.58, green: 0.42, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5)
                        .stroke(Color(red: 0.45, green: 0.30, blue: 0.15).opacity(0.4), lineWidth: 0.5)
                )
            
            // 签头朱砂红顶
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.90, green: 0.22, blue: 0.18), Color(red: 0.65, green: 0.12, blue: 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 14)
        }
        .rotationEffect(.degrees(angle), anchor: .bottom)
        .offset(y: yOffset)
    }
    
    // MARK: - 从签筒中跃出的当选灵签
    private var luckyRisingStick: some View {
        ZStack(alignment: .top) {
            // 灵签金光发散光晕
            if isStickRising {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.35))
                    .frame(width: 18, height: 155)
                    .blur(radius: 6)
            }
            
            // 灵签竹身
            RoundedRectangle(cornerRadius: 3.5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.90, blue: 0.70),
                            Color(red: 0.88, green: 0.72, blue: 0.48),
                            Color(red: 0.68, green: 0.48, blue: 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 11, height: 145)
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5)
                        .stroke(isStickRising ? Color.yellow : Color(red: 0.5, green: 0.35, blue: 0.18), lineWidth: 1)
                )
                .shadow(color: isStickRising ? Color.yellow.opacity(0.6) : Color.black.opacity(0.3), radius: isStickRising ? 8 : 2)
            
            // 签顶朱砂红印与金字
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.20, blue: 0.15), Color(red: 0.70, green: 0.10, blue: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 11, height: 18)
                    .overlay(
                        Text("吉")
                            .font(.system(size: 8, weight: .black, design: .serif))
                            .foregroundColor(.yellow)
                    )
                
                // 签身上的金线刻纹
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.38, blue: 0.20).opacity(0.5))
                    .frame(width: 1.5, height: 40)
            }
        }
    }
    
    // MARK: - 签筒前壁 (实木雕花 + 双铜箍 + 篆刻印章)
    private var cylinderFrontWall: some View {
        ZStack {
            // 实木签筒外壁
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.58, green: 0.36, blue: 0.20),
                            Color(red: 0.42, green: 0.24, blue: 0.12),
                            Color(red: 0.28, green: 0.14, blue: 0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 78, height: 95)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.65, blue: 0.40).opacity(0.6), Color.black.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 4)
            
            // 上铜箍金属环
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.82, blue: 0.48),
                            Color(red: 0.72, green: 0.54, blue: 0.24),
                            Color(red: 0.48, green: 0.32, blue: 0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 80, height: 7)
                .offset(y: -36)
            
            // 下铜箍金属环
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.82, blue: 0.48),
                            Color(red: 0.72, green: 0.54, blue: 0.24),
                            Color(red: 0.48, green: 0.32, blue: 0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 80, height: 7)
                .offset(y: 36)
            
            // 筒身正中央朱砂红“籤”印章
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.88, green: 0.18, blue: 0.15), Color(red: 0.60, green: 0.10, blue: 0.08)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 16
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color(red: 0.95, green: 0.75, blue: 0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
                
                Text(t("籤"))
                    .font(.system(size: 15, weight: .black, design: .serif))
                    .foregroundColor(Color(red: 1.0, green: 0.92, blue: 0.70))
            }
            .offset(y: 0)
        }
    }
    
    // MARK: - 抽签结果卡片 (文字完整放大显示，清晰醒目)
    private func fortuneResultCard(fortune: CustomerServiceFortune) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // 运势大标题 (大吉、中吉、上上签等)
                HStack(spacing: 8) {
                    Text("✨")
                        .font(.system(size: 16))
                    Text(fortune.localizedTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(fortune.color)
                        .shadow(color: fortune.color.opacity(0.55), radius: 10, x: 0, y: 0)
                        .tracking(3)
                    Text("✨")
                        .font(.system(size: 16))
                }
                .padding(.top, 4)
                
                // 宜与忌列表 (全文字完整显示)
                VStack(alignment: .leading, spacing: 10) {
                    // 【宜】
                    HStack(alignment: .top, spacing: 6) {
                        Text(t("宜："))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.25, green: 0.88, blue: 0.45))
                            .fixedSize()
                        Text(fortune.localizedGood)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // 【忌】
                    HStack(alignment: .top, spacing: 6) {
                        Text(t("忌："))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.30))
                            .fixedSize()
                        Text(fortune.localizedBad)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.vertical, 4)
                
                // 今日解签心语 (完整显示，无行数限制)
                Text(fortune.localizedDesc)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(fortune.color.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - 真实摇签与出签全套物理动效流程
    private func startShakeAndDraw() {
        guard !isDrawing else { return }
        isDrawing = true
        buttonText = "摇动签筒中..."
        
        // 1. 如果当前展示卡片，先收起并复位签筒
        withAnimation(.easeInOut(duration: 0.2)) {
            isCardRevealed = false
            isStickRising = false
            luckyStickOffset = 0.0
            currentFortune = nil
        }
        
        shakeStep = 0
        shakeTimer?.invalidate()
        
        // 2. 签筒左右韵律摇晃 + 群签在筒内上下错动跳跃动画
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { timer in
            shakeStep += 1
            
            // 签筒摇摆与上下微颤
            let direction: Double = (shakeStep % 2 == 0) ? 1.0 : -1.0
            let intensity = min(1.0, Double(shakeStep) / 6.0)
            let angle = direction * (12.0 + Double.random(in: 0...4)) * intensity
            let yJump = CGFloat.random(in: -3...1)
            
            withAnimation(.easeInOut(duration: 0.07)) {
                cylinderAngle = angle
                cylinderYOffset = yJump
                
                // 各签条随晃动错落起伏
                for i in 0..<stickJiggleOffsets.count {
                    stickJiggleOffsets[i] = CGFloat.random(in: -7...5)
                }
            }
            
            // 第 10 步起：当选灵签受惯性逐渐升出签筒
            if shakeStep >= 9 && shakeStep <= 14 {
                withAnimation(.easeOut(duration: 0.12)) {
                    luckyStickOffset -= 10.0
                }
            }
            
            // 摇晃结束，灵签完全升腾并展开
            if shakeStep >= 15 {
                timer.invalidate()
                finishShakeAndReveal()
            }
        }
    }
    
    // MARK: - 灵签跃出升腾与翻转展开
    private func finishShakeAndReveal() {
        // 签筒平稳回正
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0)) {
            cylinderAngle = 0.0
            cylinderYOffset = 0.0
            for i in 0..<stickJiggleOffsets.count {
                stickJiggleOffsets[i] = 0.0
            }
        }
        
        // 随机抽取幸运签
        let fortunes = CustomerServiceFortune.allFortunes
        let picked = fortunes.randomElement() ?? fortunes[0]
        
        // 灵签带金光高高升起跳出签筒
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6, blendDuration: 0)) {
            isStickRising = true
            luckyStickOffset = -85.0
            buttonText = "灵签现世..."
        }
        
        // 灵签在空中顺滑翻转展开为签文卡片
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                currentFortune = picked
                isCardRevealed = true
                buttonText = "再摇一签"
                isDrawing = false
            }
        }
    }
}
