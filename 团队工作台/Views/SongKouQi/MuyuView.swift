//
//  MuyuView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct MuyuView: View {
    @ObservedObject var themeManager = AppThemeManager.shared
    @ObservedObject var soundManager = SoundManager.shared
    
    // 木鱼设置与状态
    @AppStorage("muyu_total_count") private var totalMerit: Int = 0
    @AppStorage("muyu_today_count") private var todayMerit: Int = 0
    @AppStorage("muyu_last_date") private var lastDateString: String = ""
    
    @State private var material: MuyuMaterial = .redSandalwood
    @State private var tapCount: Int = 0 // 记录当前连续敲击次数，显示在木鱼上方
    @State private var isAutoTapping: Bool = false
    @State private var autoTapInterval: Double = 1.0
    @State private var autoTapTimer: Timer? = nil
    
    // 敲击、木鱼槌与上方数字晃动动效 (棍尾固定，棍头大幅度上下挥击敲打)
    @State private var malletAngle: Double = -38.0 // 待命状态：棍头高高扬起
    @State private var scale: CGFloat = 1.0
    @State private var muyuYOffset: CGFloat = 0.0 // 受击下震
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.0
    
    // 卡通木鱼吐泡泡粒子系统
    @State private var bubbles: [MuyuBubble] = []
    
    // 木鱼上方 "+数字" 专用晃动动效
    @State private var numberScale: CGFloat = 1.0
    @State private var numberWobble: Double = 0.0
    @State private var numberYOffset: CGFloat = 0.0
    
    @State private var isStatsOpen: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片标题栏
            cardHeader
            
            // 顶部功德计数栏
            meritCounterHeader
            
            Spacer(minLength: 4)
            
            // 木鱼与木鱼槌敲击交互核心区域
            ZStack {
                // 敲击光波扩散
                Circle()
                    .stroke(material.highlightColor.opacity(rippleOpacity), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .frame(width: 170, height: 170)
                
                // 卡通木鱼吐出的梦幻彩虹泡泡
                if material == .cartoonMuyu {
                    ForEach(bubbles) { bubble in
                        FishBubbleView(size: bubble.size, hue: bubble.hue)
                            .scaleEffect(bubble.scale)
                            .opacity(bubble.opacity)
                            .offset(x: bubble.x, y: bubble.y)
                            .allowsHitTesting(false)
                    }
                }
                
                // 木鱼本体（内嵌固定“+功德”字样）
                muyuGraphic
                    .scaleEffect(scale)
                    .offset(x: -12, y: 10 + muyuYOffset)
                    .onTapGesture {
                        tapMuyu()
                    }
                
                // 木鱼棍 (棍尾固定于右侧，棍头上下大幅度敲击木鱼)
                malletGraphic
                    .offset(x: 22, y: -40)
                    .allowsHitTesting(false)
                
                // 木鱼上方唯一固定位置的“祝词+数字”（如 好运+1 / 功德+1），敲击时就地晃动弹跳
                Text("\(material.blessingPrefix)+\(tapCount)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.accentColor, themeManager.textPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: themeManager.glowColor, radius: 8, x: 0, y: 0)
                    .scaleEffect(numberScale)
                    .rotationEffect(.degrees(numberWobble))
                    .offset(x: -12, y: -74 + numberYOffset)
                    .allowsHitTesting(false)
            }
            .frame(height: 160)
            
            Spacer(minLength: 4)
            
            // 控制面板（材质选择与自动敲击）
            controlBar
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
        .onAppear {
            checkTodayReset()
            tapCount = todayMerit
        }
        .onDisappear {
            stopAutoTap()
        }
        .sheet(isPresented: $isStatsOpen) {
            muyuStatsSheet
        }
    }
    
    // MARK: - 卡片标题栏
    private var cardHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "circle.circle.fill")
                    .foregroundColor(themeManager.accentColor)
                Text(t("敲木鱼"))
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
            }
            
            Spacer()
            
            // 声音开关 (一键切换静音与木鱼敲击声)
            Button {
                soundManager.isMuyuMuted.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: soundManager.isMuyuMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                    Text(soundManager.isMuyuMuted ? t("静音") : t("有声"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                }
                .foregroundColor(soundManager.isMuyuMuted ? themeManager.textSecondary : themeManager.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(soundManager.isMuyuMuted ? themeManager.secondaryCardBackground : themeManager.accentColor.opacity(0.18))
                )
                .overlay(
                    Capsule().stroke(soundManager.isMuyuMuted ? themeManager.borderColor : themeManager.accentColor.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(soundManager.isMuyuMuted ? t("点击开启木鱼敲击音效") : t("点击关闭声音(开启静音)"))
            
            // 极简纯净模式 (隐藏软件页面，只留木鱼与敲击动画)
            Button {
                AppStateManager.shared.enterPureMuyuMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 11, weight: .semibold))
                    Text(t("只看木鱼"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                }
                .foregroundColor(themeManager.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(themeManager.secondaryCardBackground)
                )
                .overlay(
                    Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(t("隐藏软件页面，只保留木鱼与敲击动画窗口"))
        }
    }
    
    // MARK: - 顶部功德栏
    private var meritCounterHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("今日功德"))
                    .font(.caption2)
                    .foregroundColor(themeManager.textSecondary)
                Text("\(todayMerit)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.accentColor)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(t("累积功德"))
                    .font(.caption2)
                    .foregroundColor(themeManager.textSecondary)
                Text("\(totalMerit)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.textPrimary)
            }
            
            Button {
                isStatsOpen = true
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.textSecondary)
                    .padding(6)
                    .background(themeManager.secondaryCardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.secondaryCardBackground)
        )
    }
    
    // MARK: - 木鱼图形 (卡通木鱼与传统实木雕刻两种精美形态)
    private var muyuGraphic: some View {
        ZStack {
            // 1. 地面环境光遮蔽与接触阴影 (Ambient Occlusion & Contact Shadow)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: 175, height: 44)
                .offset(x: 2, y: 64)
            
            // 2. 木鱼主体视图
            if material == .cartoonMuyu {
                // 卡通木鱼专属图案 (Q版木质小鱼，大萌眼、木纹与腮红)
                Image("MuyuCartoon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 135)
                    .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 6)
            } else if material == .emeraldJade {
                // 参考实物图专属：极品翡翠雕刻双鱼木鱼 + 棉麻流苏禅垫
                EmeraldJadeMuyuView()
            } else if material == .whiteJade {
                // 参考实物图专属：极品羊脂白玉锦鲤木鱼 + 双层莲花雕花红木底座
                WhiteJadeMuyuView()
            } else {
                // 传统实木雕刻立体光影木鱼 (紫檀)
                ZStack {
                    // 2.1 木身基础形体 (底色 + 多重真实光影着色)
                    MuyuAuthenticShape()
                        .fill(
                            LinearGradient(
                                colors: material.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 7)
                    
                    // 2.2 顶部柔和聚光反射高光
                    MuyuAuthenticShape()
                        .fill(
                            RadialGradient(
                                colors: [
                                    material.highlightColor.opacity(0.75),
                                    material.highlightColor.opacity(0.25),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.44, y: 0.28),
                                startRadius: 4,
                                endRadius: 65
                            )
                        )
                        .blendMode(.screen)
                    
                    // 2.3 边缘微弱环境光与木质质感微倒角
                    MuyuAuthenticShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    material.highlightColor.opacity(0.7),
                                    material.rimLightColor,
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // 2.4 参考图标志性特征：中空音槽与深邃共鸣通孔系统
                    MuyuAuthenticCavityView(material: material)
                }
                .frame(width: 165, height: 130)
            }
        }
        .contentShape(Rectangle())
        .cursorHand()
    }
    
    // MARK: - 水平木鱼棍组件 (位于木鱼上方，水平横置，向下敲打木鱼)
    private var malletGraphic: some View {
        ZStack(alignment: .trailing) {
            if material == .emeraldJade {
                // 参考实物图：老红木手柄 + 雕花翡翠圆柱玉棰头
                HStack(spacing: 0) {
                    // 翡翠雕花圆柱玉棰头 (带如意花草雕纹与玻璃莹光)
                    ZStack {
                        // 翡翠玉石底色
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.26, green: 0.72, blue: 0.42),
                                        Color(red: 0.12, green: 0.48, blue: 0.26),
                                        Color(red: 0.05, green: 0.25, blue: 0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 20)
                            .shadow(color: Color.black.opacity(0.45), radius: 4, x: -1, y: 2)
                        
                        // 翡翠雕花白绿纹饰
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.85), Color(red: 0.60, green: 0.98, blue: 0.75).opacity(0.7), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: 28, height: 20)
                        
                        // 棰头精细雕花线条
                        VStack(spacing: 2) {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 16, height: 1.5)
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 20, height: 1.5)
                        }
                    }
                    .offset(x: 2)
                    
                    // 红木束腰连接卡环
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.48, green: 0.22, blue: 0.15), Color(red: 0.22, green: 0.08, blue: 0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 12)
                    
                    // 老红木/黑酸枝细腻红木长手柄
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.24, blue: 0.16),
                                    Color(red: 0.32, green: 0.15, blue: 0.10),
                                    Color(red: 0.16, green: 0.06, blue: 0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 82, height: 7)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
                }
            } else if material == .whiteJade {
                // 参考实物图专属：老红木长手柄 + 羊脂白玉细柄 + 雕花白玉圆球棰头
                HStack(spacing: 0) {
                    // 羊脂白玉雕花球头
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.99, green: 0.99, blue: 0.98),
                                        Color(red: 0.90, green: 0.91, blue: 0.89),
                                        Color(red: 0.72, green: 0.75, blue: 0.72)
                                    ],
                                    center: UnitPoint(x: 0.35, y: 0.3),
                                    startRadius: 2,
                                    endRadius: 14
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: -1, y: 2)
                        
                        // 浮雕莲花如意花纹
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                            .frame(width: 24, height: 24)
                        
                        // 球头高光点
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 6, height: 6)
                            .offset(x: -3, y: -3)
                    }
                    .offset(x: 2)
                    
                    // 羊脂白玉纤细圆润颈柄
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.98, blue: 0.96),
                                    Color(red: 0.88, green: 0.89, blue: 0.86)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 26, height: 5)
                    
                    // 老红木/黑酸枝细腻红木长手柄
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.24, blue: 0.16),
                                    Color(red: 0.32, green: 0.15, blue: 0.10),
                                    Color(red: 0.16, green: 0.06, blue: 0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 62, height: 7)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
                }
            } else {
                // 传统实木木槌
                // 木槌长细横柄 (水平向右延伸)
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.84, blue: 0.60),
                                Color(red: 0.82, green: 0.65, blue: 0.40),
                                Color(red: 0.52, green: 0.35, blue: 0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 90, height: 7)
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
                
                // 木槌圆形球头 (在棍子左端，精准敲打木鱼背部)
                ZStack {
                    // 球头底色与立体渐变
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    material.highlightColor,
                                    material.gradientColors[0],
                                    material.gradientColors[min(1, material.gradientColors.count - 1)]
                                ],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 2,
                                endRadius: 15
                            )
                        )
                        .frame(width: 25, height: 25)
                        .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 3)
                    
                    // 球头聚光亮点
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.9), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 6
                            )
                        )
                        .frame(width: 8, height: 8)
                        .offset(x: -3, y: -3)
                }
                .offset(x: -76, y: 0)
            }
        }
        .frame(width: 115, height: 28)
        .rotationEffect(.degrees(malletAngle), anchor: .trailing)
    }
    
    // MARK: - 底部控制区
    private var controlBar: some View {
        VStack(spacing: 10) {
            // 材质切换栏
            HStack(spacing: 8) {
                ForEach(MuyuMaterial.allCases) { mat in
                    let isSelected = (material == mat)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            material = mat
                        }
                    } label: {
                        Text(mat.localizedName)
                            .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .serif))
                            .foregroundColor(isSelected ? .white : themeManager.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? mat.gradientColors[0] : themeManager.secondaryCardBackground)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? mat.highlightColor.opacity(0.8) : themeManager.borderColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 自动敲击与频率控制
            HStack(spacing: 10) {
                Button {
                    toggleAutoTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isAutoTapping ? "pause.fill" : "play.fill")
                            .font(.caption2)
                        Text(isAutoTapping ? t("停止自动") : t("自动敲击"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isAutoTapping ? .orange : themeManager.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isAutoTapping ? Color.orange.opacity(0.18) : themeManager.secondaryCardBackground)
                    )
                    .overlay(
                        Capsule()
                            .stroke(isAutoTapping ? Color.orange.opacity(0.5) : themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                if isAutoTapping {
                    HStack(spacing: 4) {
                        Slider(value: $autoTapInterval, in: 0.4...2.0, step: 0.1)
                            .frame(width: 70)
                        Text(String(format: "%.1fs", autoTapInterval))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textSecondary)
                    }
                    .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - 敲击动作逻辑 (棍尾固定，棍头大幅度上下挥击敲打、吐泡泡、文字晃动)
    private func tapMuyu() {
        // 播放专属材质真实声效 (若未静音)
        soundManager.playMuyuSound(material: material)
        
        // 增加计数
        totalMerit += 1
        todayMerit += 1
        tapCount += 1
        
        // 1. 卡通木鱼吐泡泡动画 (从右侧鱼嘴冒出并升腾)
        emitCartoonBubbles()
        
        // 2. 水平木鱼棍敲打动画 (棍尾固定不动，棍头大幅度向下砸打木鱼背部: -38° -> +18°)
        withAnimation(.easeIn(duration: 0.06)) {
            malletAngle = 18.0
        }
        
        // 3. 木鱼上方 "+数字" 原地晃动放大与弹跳
        withAnimation(.spring(response: 0.14, dampingFraction: 0.35, blendDuration: 0)) {
            numberScale = 1.35
            numberWobble = Double.random(in: -10...10)
            numberYOffset = -6.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            // 4. 木鱼本体受击明显下震与光波扩散
            withAnimation(.easeOut(duration: 0.07)) {
                scale = 0.86
                muyuYOffset = 6.0
                rippleScale = 0.8
                rippleOpacity = 0.85
            }
            
            // 5. 木鱼棍棍头强力反弹扬起，复位至上方待命高角度 (-38°)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.44, blendDuration: 0)) {
                malletAngle = -38.0
                scale = 1.0
                muyuYOffset = 0.0
            }
            
            withAnimation(.easeOut(duration: 0.45)) {
                rippleScale = 1.45
                rippleOpacity = 0.0
            }
        }
        
        // 6. "+数字" 弹性恢复正常大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.6, blendDuration: 0)) {
                numberScale = 1.0
                numberWobble = 0.0
                numberYOffset = 0.0
            }
        }
    }
    
    // MARK: - 卡通木鱼吐泡泡生成器 (再往右移动1厘米精准对准鱼嘴)
    private func emitCartoonBubbles() {
        guard material == .cartoonMuyu else { return }
        let count = Int.random(in: 3...5)
        for i in 0..<count {
            let bubble = MuyuBubble(
                id: UUID(),
                x: 60 + CGFloat.random(in: -5...5), // 再往右平移1厘米 (约30pt)
                y: 18 + CGFloat.random(in: -5...5),
                size: CGFloat.random(in: 11...24),
                hue: Double.random(in: 0.48...0.88),
                opacity: 0.95,
                scale: 0.35
            )
            bubbles.append(bubble)
            
            let bubbleId = bubble.id
            let targetX = 78 + CGFloat.random(in: -5...35) // 向右上方与上方升腾飘浮
            let targetY = -45 - CGFloat(i * 20) - CGFloat.random(in: 15...35)
            
            withAnimation(.easeOut(duration: 0.85 + Double(i) * 0.15)) {
                if let index = bubbles.firstIndex(where: { $0.id == bubbleId }) {
                    bubbles[index].x = targetX
                    bubbles[index].y = targetY
                    bubbles[index].scale = 1.2
                    bubbles[index].opacity = 0.0
                }
            }
        }
        
        // 清理消散完成的泡泡
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            bubbles.removeAll(where: { $0.opacity <= 0.05 })
        }
    }
    
    private func toggleAutoTap() {
        isAutoTapping.toggle()
        if isAutoTapping {
            startAutoTap()
        } else {
            stopAutoTap()
        }
    }
    
    private func startAutoTap() {
        stopAutoTap()
        autoTapTimer = Timer.scheduledTimer(withTimeInterval: autoTapInterval, repeats: true) { _ in
            tapMuyu()
        }
    }
    
    private func stopAutoTap() {
        autoTapTimer?.invalidate()
        autoTapTimer = nil
    }
    
    private func checkTodayReset() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        if lastDateString != today {
            todayMerit = 0
            tapCount = 0
            lastDateString = today
        }
    }
    
    // MARK: - 统计信息面板
    private var muyuStatsSheet: some View {
        VStack(spacing: 20) {
            Text(t("功德芳名录"))
                .font(.system(size: 18, weight: .bold, design: .serif))
            
            VStack(spacing: 12) {
                HStack {
                    Text(t("今日念诵计数"))
                    Spacer()
                    Text("\(todayMerit) " + t("次"))
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                }
                HStack {
                    Text(t("历年总积功德"))
                    Spacer()
                    Text("\(totalMerit) " + t("次"))
                        .foregroundColor(.yellow)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            
            HStack {
                Button(t("清零今日计数"), role: .destructive) {
                    todayMerit = 0
                    tapCount = 0
                }
                Spacer()
                Button(t("完成")) {
                    isStatsOpen = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320, height: 220)
    }
}

// MARK: - 高度还原实物参考图的木鱼三维轮廓与中空音槽系统
struct MuyuAuthenticShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 1. 从左侧饱满腹部中线开始
        path.move(to: CGPoint(x: w * 0.06, y: h * 0.58))
        
        // 2. 向上饱满隆起到左上方最高点 (参考图经典的左高右低弧顶)
        path.addCurve(
            to: CGPoint(x: w * 0.44, y: h * 0.04),
            control1: CGPoint(x: w * 0.06, y: h * 0.22),
            control2: CGPoint(x: w * 0.20, y: h * 0.04)
        )
        
        // 3. 从最高点顺畅延展向右下方过渡到右肩
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.62),
            control1: CGPoint(x: w * 0.64, y: h * 0.04),
            control2: CGPoint(x: w * 0.78, y: h * 0.38)
        )
        
        // 4. 连接到右下尾柄雕刻 (尾部紧凑微翘结构)
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.74),
            control1: CGPoint(x: w * 0.86, y: h * 0.68),
            control2: CGPoint(x: w * 0.91, y: h * 0.70)
        )
        path.addLine(to: CGPoint(x: w * 0.96, y: h * 0.81))
        path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.87))
        
        // 5. 底部平缓贴地大弧度
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.95),
            control1: CGPoint(x: w * 0.82, y: h * 0.90),
            control2: CGPoint(x: w * 0.68, y: h * 0.95)
        )
        
        // 6. 从底部平稳过渡回左下腹部
        path.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.85),
            control1: CGPoint(x: w * 0.36, y: h * 0.95),
            control2: CGPoint(x: w * 0.22, y: h * 0.92)
        )
        
        // 7. 回到起始点闭合
        path.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.58),
            control1: CGPoint(x: w * 0.06, y: h * 0.78),
            control2: CGPoint(x: w * 0.06, y: h * 0.68)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - 参考图标志性特征：中空音槽与水滴共鸣孔 (带真实木壁切面厚度与深邃内膛)
struct MuyuAuthenticCavityView: View {
    let material: MuyuMaterial
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            // 1. 中空内腔与音槽主孔路径 (Slit & Hole Shape)
            var cavityPath = Path()
            // 左侧起刀狭缝
            cavityPath.move(to: CGPoint(x: w * 0.11, y: h * 0.56))
            
            // 上唇切口线 (向右下微弯延伸)
            cavityPath.addQuadCurve(
                to: CGPoint(x: w * 0.58, y: h * 0.64),
                control: CGPoint(x: w * 0.34, y: h * 0.60)
            )
            
            // 右侧贯穿水滴状共鸣大孔 (通孔轮廓)
            cavityPath.addCurve(
                to: CGPoint(x: w * 0.74, y: h * 0.70),
                control1: CGPoint(x: w * 0.64, y: h * 0.62),
                control2: CGPoint(x: w * 0.73, y: h * 0.64)
            )
            cavityPath.addCurve(
                to: CGPoint(x: w * 0.70, y: h * 0.79),
                control1: CGPoint(x: w * 0.76, y: h * 0.75),
                control2: CGPoint(x: w * 0.74, y: h * 0.79)
            )
            cavityPath.addCurve(
                to: CGPoint(x: w * 0.56, y: h * 0.68),
                control1: CGPoint(x: w * 0.65, y: h * 0.79),
                control2: CGPoint(x: w * 0.59, y: h * 0.74)
            )
            
            // 下唇切口线 (收回左端起刀口)
            cavityPath.addQuadCurve(
                to: CGPoint(x: w * 0.11, y: h * 0.56),
                control: CGPoint(x: w * 0.34, y: h * 0.62)
            )
            cavityPath.closeSubpath()
            
            // 2. 填充深邃内腔深黑底色 (中空中部全黑阴影)
            context.fill(cavityPath, with: .color(Color(red: 0.05, green: 0.04, blue: 0.03)))
            
            // 3. 上唇实木厚度阴影倒角 (Upper Lip Bevel Inner Shadow)
            var upperLipEdge = Path()
            upperLipEdge.move(to: CGPoint(x: w * 0.11, y: h * 0.56))
            upperLipEdge.addQuadCurve(
                to: CGPoint(x: w * 0.58, y: h * 0.64),
                control: CGPoint(x: w * 0.34, y: h * 0.60)
            )
            context.stroke(
                upperLipEdge,
                with: .color(Color.black.opacity(0.85)),
                lineWidth: 4
            )
            
            // 4. 下唇与右侧通孔的实木切面厚度壁 (Lower Lip & Hole Bevel Wall)
            var bevelWallPath = Path()
            bevelWallPath.move(to: CGPoint(x: w * 0.56, y: h * 0.68))
            bevelWallPath.addCurve(
                to: CGPoint(x: w * 0.70, y: h * 0.79),
                control1: CGPoint(x: w * 0.59, y: h * 0.74),
                control2: CGPoint(x: w * 0.65, y: h * 0.79)
            )
            bevelWallPath.addLine(to: CGPoint(x: w * 0.72, y: h * 0.81))
            bevelWallPath.addCurve(
                to: CGPoint(x: w * 0.56, y: h * 0.71),
                control1: CGPoint(x: w * 0.67, y: h * 0.81),
                control2: CGPoint(x: w * 0.60, y: h * 0.77)
            )
            bevelWallPath.closeSubpath()
            
            context.fill(
                bevelWallPath,
                with: .color(material.highlightColor.opacity(0.45))
            )
            
            // 5. 切槽下边缘的高光反光线 (给下唇边缘一道微妙的立体木质亮线)
            var lowerLipHighlight = Path()
            lowerLipHighlight.move(to: CGPoint(x: w * 0.12, y: h * 0.57))
            lowerLipHighlight.addQuadCurve(
                to: CGPoint(x: w * 0.56, y: h * 0.68),
                control: CGPoint(x: w * 0.34, y: h * 0.63)
            )
            context.stroke(
                lowerLipHighlight,
                with: .color(material.highlightColor.opacity(0.65)),
                lineWidth: 1.2
            )
            
            // 6. 右下尾柄细部分界雕纹 (Tail accent line)
            var tailAccent = Path()
            tailAccent.move(to: CGPoint(x: w * 0.83, y: h * 0.65))
            tailAccent.addQuadCurve(
                to: CGPoint(x: w * 0.89, y: h * 0.86),
                control: CGPoint(x: w * 0.85, y: h * 0.76)
            )
            context.stroke(
                tailAccent,
                with: .color(Color.black.opacity(0.45)),
                lineWidth: 1.5
            )
        }
    }
}

// MARK: - 卡通木鱼吐泡泡数据结构与视图
struct MuyuBubble: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var hue: Double
    var opacity: Double
    var scale: CGFloat
}

struct FishBubbleView: View {
    let size: CGFloat
    let hue: Double
    
    var body: some View {
        ZStack {
            // 泡泡外圈彩虹渐变与柔和发光
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.65, brightness: 1.0).opacity(0.85),
                            Color(hue: (hue + 0.25).truncatingRemainder(dividingBy: 1.0), saturation: 0.7, brightness: 1.0).opacity(0.65),
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.2, size * 0.08)
                )
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color(hue: hue, saturation: 0.35, brightness: 1.0).opacity(0.18),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.5
                            )
                        )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(hue: hue, saturation: 0.6, brightness: 1.0).opacity(0.4), radius: 3)
            
            // 泡泡左上方主要高光弧光
            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: -size * 0.22, y: -size * 0.22)
            
            // 泡泡右下方微弱反光小亮点
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.2, y: size * 0.2)
        }
    }
}

// MARK: - 高度还原实物参考图的「翡翠双鱼木鱼」与「米白流苏禅垫」
struct EmeraldJadeMuyuView: View {
    var body: some View {
        ZStack {
            // 1. 米白色棉麻刺绣流苏禅垫 (Meditation Cushion with fringes)
            ZStack {
                // 垫子底部深邃投影
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.48))
                    .frame(width: 176, height: 38)
                    .offset(y: 54)
                
                // 禅垫本体 (米白色带棉麻织物微渐变)
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.95, blue: 0.91),
                                Color(red: 0.88, green: 0.86, blue: 0.80),
                                Color(red: 0.76, green: 0.73, blue: 0.66)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 172, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 3)
                    .offset(y: 50)
                
                // 禅垫四周细密白色流苏穗 (Fringes)
                HStack(spacing: 3) {
                    ForEach(0..<25) { _ in
                        Rectangle()
                            .fill(Color(red: 0.92, green: 0.90, blue: 0.84).opacity(0.9))
                            .frame(width: 1.5, height: 9)
                    }
                }
                .offset(x: -2, y: 68)
            }
            
            // 2. 翡翠玉石立体木鱼主体
            ZStack {
                // 2.1 翡翠底色与温润水头立体渐变
                MuyuAuthenticShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.70, blue: 0.40),
                                Color(red: 0.10, green: 0.45, blue: 0.24),
                                Color(red: 0.04, green: 0.22, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 6)
                
                // 2.2 翡翠通透莹光与水种扩散光
                MuyuAuthenticShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.48, green: 0.95, blue: 0.64).opacity(0.8),
                                Color(red: 0.16, green: 0.62, blue: 0.32).opacity(0.35),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.45, y: 0.26),
                            startRadius: 5,
                            endRadius: 68
                        )
                    )
                    .blendMode(.screen)
                
                // 2.3 翡翠双鱼/龙鱼浮雕雕纹系统 (鱼鳞纹、鱼眼、鱼鳃、卷云波浪尾)
                EmeraldJadeCarvingsOverlay()
                
                // 2.4 翡翠发声口腔 (深邃通透的右侧鱼嘴开口)
                MuyuAuthenticCavityView(material: .emeraldJade)
                
                // 2.5 翡翠玉石表面玻璃种反光高光
                MuyuAuthenticShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.88),
                                Color(red: 0.60, green: 0.98, blue: 0.75).opacity(0.7),
                                Color.black.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: 165, height: 130)
        }
    }
}

// MARK: - 翡翠木鱼专属双鱼龙鱼浮雕纹理 (鱼鳞纹、立体鱼眼、鱼鳃、波浪鳍)
struct EmeraldJadeCarvingsOverlay: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            let shadowStroke = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            let hlColor = Color(red: 0.72, green: 0.98, blue: 0.84).opacity(0.75)
            let shColor = Color(red: 0.02, green: 0.16, blue: 0.08).opacity(0.7)
            
            // 1. 头部立体鱼眼 (圆润凸起浮雕圈)
            let eyeCenter = CGPoint(x: w * 0.73, y: h * 0.32)
            var eyePath = Path()
            eyePath.addArc(center: eyeCenter, radius: 6.5, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(eyePath, with: .color(shColor), style: shadowStroke)
            context.stroke(eyePath, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.0))
            
            // 鱼眼中心高光点
            var eyeCore = Path()
            eyeCore.addArc(center: CGPoint(x: eyeCenter.x - 1, y: eyeCenter.y - 1), radius: 2.2, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.fill(eyeCore, with: .color(Color.white.opacity(0.9)))
            
            // 2. 头部鱼鳃弧线 (双层流线型浮雕)
            var gillPath1 = Path()
            gillPath1.move(to: CGPoint(x: w * 0.63, y: h * 0.16))
            gillPath1.addCurve(
                to: CGPoint(x: w * 0.65, y: h * 0.52),
                control1: CGPoint(x: w * 0.69, y: h * 0.28),
                control2: CGPoint(x: w * 0.70, y: h * 0.42)
            )
            context.stroke(gillPath1, with: .color(shColor), style: shadowStroke)
            context.stroke(gillPath1, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.2))
            
            var gillPath2 = Path()
            gillPath2.move(to: CGPoint(x: w * 0.59, y: h * 0.22))
            gillPath2.addCurve(
                to: CGPoint(x: w * 0.60, y: h * 0.48),
                control1: CGPoint(x: w * 0.64, y: h * 0.30),
                control2: CGPoint(x: w * 0.64, y: h * 0.42)
            )
            context.stroke(gillPath2, with: .color(shColor), style: shadowStroke)
            context.stroke(gillPath2, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.0))
            
            // 3. 背部多排细密立体鱼鳞纹 (Scales)
            let scaleRows: [(y: CGFloat, count: Int, startX: CGFloat, stepX: CGFloat, r: CGFloat)] = [
                (y: h * 0.20, count: 4, startX: w * 0.28, stepX: w * 0.08, r: 7.5),
                (y: h * 0.28, count: 5, startX: w * 0.24, stepX: w * 0.08, r: 8.0),
                (y: h * 0.36, count: 5, startX: w * 0.22, stepX: w * 0.08, r: 8.5),
                (y: h * 0.44, count: 4, startX: w * 0.25, stepX: w * 0.08, r: 8.5)
            ]
            
            for row in scaleRows {
                for i in 0..<row.count {
                    let cx = row.startX + CGFloat(i) * row.stepX
                    var scalePath = Path()
                    scalePath.addArc(
                        center: CGPoint(x: cx, y: row.y),
                        radius: row.r,
                        startAngle: .degrees(30),
                        endAngle: .degrees(160),
                        clockwise: false
                    )
                    context.stroke(scalePath, with: .color(shColor), style: shadowStroke)
                    context.stroke(scalePath, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.1))
                }
            }
            
            // 4. 鱼腹与侧面卷云鱼鳍浮雕 (Fins)
            var finPath1 = Path()
            finPath1.move(to: CGPoint(x: w * 0.42, y: h * 0.50))
            finPath1.addCurve(
                to: CGPoint(x: w * 0.30, y: h * 0.72),
                control1: CGPoint(x: w * 0.45, y: h * 0.62),
                control2: CGPoint(x: w * 0.38, y: h * 0.70)
            )
            context.stroke(finPath1, with: .color(shColor), style: shadowStroke)
            context.stroke(finPath1, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.2))
            
            var finPath2 = Path()
            finPath2.move(to: CGPoint(x: w * 0.46, y: h * 0.54))
            finPath2.addCurve(
                to: CGPoint(x: w * 0.36, y: h * 0.74),
                control1: CGPoint(x: w * 0.48, y: h * 0.64),
                control2: CGPoint(x: w * 0.42, y: h * 0.72)
            )
            context.stroke(finPath2, with: .color(shColor), style: shadowStroke)
            context.stroke(finPath2, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.0))
            
            // 5. 左侧波浪多瓣扇形鱼尾雕纹 (Tail waves)
            let tailLines: [(p1: CGPoint, p2: CGPoint, cp: CGPoint)] = [
                (CGPoint(x: w * 0.16, y: h * 0.52), CGPoint(x: w * 0.08, y: h * 0.68), CGPoint(x: w * 0.11, y: h * 0.58)),
                (CGPoint(x: w * 0.19, y: h * 0.58), CGPoint(x: w * 0.10, y: h * 0.78), CGPoint(x: w * 0.13, y: h * 0.68)),
                (CGPoint(x: w * 0.23, y: h * 0.65), CGPoint(x: w * 0.14, y: h * 0.85), CGPoint(x: w * 0.17, y: h * 0.75))
            ]
            
            for line in tailLines {
                var tp = Path()
                tp.move(to: line.p1)
                tp.addQuadCurve(to: line.p2, control: line.cp)
                context.stroke(tp, with: .color(shColor), style: shadowStroke)
                context.stroke(tp, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.2))
            }
        }
    }
}

// MARK: - 高度还原实物参考图的「羊脂白玉锦鲤木鱼」与「双层莲花雕花红木底座」
struct WhiteJadeMuyuView: View {
    var body: some View {
        ZStack {
            // 1. 深色实木双层莲瓣雕花底座 (Carved Lotus Wooden Pedestal)
            LotusPedestalView()
                .offset(y: 46)
            
            // 2. 羊脂白玉锦鲤木鱼主体
            ZStack {
                // 2.1 羊脂白玉温润凝脂立体渐变底色
                WhiteJadeCarpShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.99, green: 0.99, blue: 0.98),
                                Color(red: 0.92, green: 0.93, blue: 0.90),
                                Color(red: 0.76, green: 0.78, blue: 0.74)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 5)
                
                // 2.2 羊脂玉温润油脂微光与透光莹光
                WhiteJadeCarpShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color(red: 0.95, green: 0.96, blue: 0.92).opacity(0.4),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.48, y: 0.28),
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .blendMode(.screen)
                
                // 2.3 羊脂白玉专属浮雕纹理与中央水平长音槽
                WhiteJadeCarvingsOverlay()
                
                // 2.4 羊脂白玉表面细腻温润高光轮廓
                WhiteJadeCarpShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.88, green: 0.90, blue: 0.86),
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: 172, height: 110)
        }
    }
}

// MARK: - 白玉木鱼横卧锦鲤外轮廓 (鱼头在右，鱼身如意饱满，鱼尾分叉卷云)
struct WhiteJadeCarpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 1. 从左端如意分叉尾部中点开始
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.48))
        
        // 2. 向上翻卷至左上如意尾尖
        path.addCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.18),
            control1: CGPoint(x: w * 0.15, y: h * 0.35),
            control2: CGPoint(x: w * 0.04, y: h * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.24, y: h * 0.14),
            control1: CGPoint(x: w * 0.12, y: h * 0.12),
            control2: CGPoint(x: w * 0.18, y: h * 0.10)
        )
        
        // 3. 过渡到饱满隆起的锦鲤鱼背最高点
        path.addCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.04),
            control1: CGPoint(x: w * 0.32, y: h * 0.08),
            control2: CGPoint(x: w * 0.42, y: h * 0.04)
        )
        
        // 4. 顺畅延展至右侧圆润鱼头与鱼嘴
        path.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.30),
            control1: CGPoint(x: w * 0.70, y: h * 0.04),
            control2: CGPoint(x: w * 0.82, y: h * 0.16)
        )
        // 鱼嘴微翘弧度
        path.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.46),
            control1: CGPoint(x: w * 0.93, y: h * 0.38),
            control2: CGPoint(x: w * 0.96, y: h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.65),
            control1: CGPoint(x: w * 0.96, y: h * 0.52),
            control2: CGPoint(x: w * 0.94, y: h * 0.58)
        )
        
        // 5. 下腹部平缓大圆弧
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.94),
            control1: CGPoint(x: w * 0.80, y: h * 0.78),
            control2: CGPoint(x: w * 0.68, y: h * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.25, y: h * 0.86),
            control1: CGPoint(x: w * 0.40, y: h * 0.94),
            control2: CGPoint(x: w * 0.32, y: h * 0.90)
        )
        
        // 6. 左下如意尾卷云
        path.addCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.78),
            control1: CGPoint(x: w * 0.18, y: h * 0.90),
            control2: CGPoint(x: w * 0.12, y: h * 0.86)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.48),
            control1: CGPoint(x: w * 0.04, y: h * 0.70),
            control2: CGPoint(x: w * 0.15, y: h * 0.60)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - 白玉木鱼专属雕花：中央水平长音槽、立体鱼鳞浮雕、双鱼对游浮雕、鱼眼鱼鳃
struct WhiteJadeCarvingsOverlay: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            let shColor = Color(red: 0.48, green: 0.50, blue: 0.46).opacity(0.65)
            let hlColor = Color.white.opacity(0.85)
            let shadowStroke = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            let hlStroke = StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
            
            // 1. 中央标志性水平长椭圆音槽 (Horizontal Sound Slit)
            let slitRect = CGRect(x: w * 0.28, y: h * 0.42, width: w * 0.38, height: h * 0.14)
            let slitPath = Path(roundedRect: slitRect, cornerRadius: slitRect.height / 2)
            
            // 内部深邃黑影 (镂空共鸣腔)
            context.fill(slitPath, with: .color(Color(red: 0.08, green: 0.09, blue: 0.08)))
            
            // 音槽内壁羊脂玉倒角高光
            context.stroke(slitPath, with: .color(hlColor), style: StrokeStyle(lineWidth: 1.4))
            
            // 2. 头部立体鱼眼 (圆润双层凸起浮雕)
            let eyeCenter = CGPoint(x: w * 0.82, y: h * 0.36)
            var eyePath = Path()
            eyePath.addArc(center: eyeCenter, radius: 6.0, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(eyePath, with: .color(shColor), style: shadowStroke)
            context.stroke(eyePath, with: .color(hlColor), style: hlStroke)
            
            // 鱼眼中心高光点
            var eyeCore = Path()
            eyeCore.addArc(center: CGPoint(x: eyeCenter.x - 1, y: eyeCenter.y - 1), radius: 2.0, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.fill(eyeCore, with: .color(Color.white))
            
            // 3. 头部鱼鳃弧线与微翘鱼嘴
            var gillPath = Path()
            gillPath.move(to: CGPoint(x: w * 0.72, y: h * 0.18))
            gillPath.addCurve(
                to: CGPoint(x: w * 0.74, y: h * 0.65),
                control1: CGPoint(x: w * 0.77, y: h * 0.30),
                control2: CGPoint(x: w * 0.78, y: h * 0.52)
            )
            context.stroke(gillPath, with: .color(shColor), style: shadowStroke)
            context.stroke(gillPath, with: .color(hlColor), style: hlStroke)
            
            var mouthPath = Path()
            mouthPath.move(to: CGPoint(x: w * 0.94, y: h * 0.44))
            mouthPath.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.48), control: CGPoint(x: w * 0.90, y: h * 0.46))
            context.stroke(mouthPath, with: .color(shColor), style: shadowStroke)
            
            // 4. 音槽上方 (鱼背)：整齐密集的半月形立体鱼鳞纹浮雕 (Scales)
            let scaleRows: [(y: CGFloat, count: Int, startX: CGFloat, stepX: CGFloat, r: CGFloat)] = [
                (y: h * 0.15, count: 5, startX: w * 0.30, stepX: w * 0.075, r: 6.5),
                (y: h * 0.23, count: 6, startX: w * 0.26, stepX: w * 0.075, r: 7.0),
                (y: h * 0.31, count: 6, startX: w * 0.25, stepX: w * 0.075, r: 7.5),
                (y: h * 0.39, count: 5, startX: w * 0.28, stepX: w * 0.075, r: 7.5)
            ]
            
            for row in scaleRows {
                for i in 0..<row.count {
                    let cx = row.startX + CGFloat(i) * row.stepX
                    var scalePath = Path()
                    scalePath.addArc(
                        center: CGPoint(x: cx, y: row.y),
                        radius: row.r,
                        startAngle: .degrees(25),
                        endAngle: .degrees(165),
                        clockwise: false
                    )
                    context.stroke(scalePath, with: .color(shColor), style: shadowStroke)
                    context.stroke(scalePath, with: .color(hlColor), style: hlStroke)
                }
            }
            
            // 5. 音槽下方 (鱼腹)：精致的「双鱼对游嬉水」浮雕 (Confronting Fish Carvings)
            // 左小鱼
            var carp1 = Path()
            carp1.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.64, width: w * 0.12, height: h * 0.18))
            context.stroke(carp1, with: .color(shColor), style: shadowStroke)
            context.stroke(carp1, with: .color(hlColor), style: hlStroke)
            
            // 右小鱼 (对游)
            var carp2 = Path()
            carp2.addEllipse(in: CGRect(x: w * 0.48, y: h * 0.64, width: w * 0.12, height: h * 0.18))
            context.stroke(carp2, with: .color(shColor), style: shadowStroke)
            context.stroke(carp2, with: .color(hlColor), style: hlStroke)
            
            // 双鱼周围如意卷云水花
            var swirl = Path()
            swirl.move(to: CGPoint(x: w * 0.32, y: h * 0.82))
            swirl.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.82), control: CGPoint(x: w * 0.47, y: h * 0.88))
            context.stroke(swirl, with: .color(shColor), style: shadowStroke)
            context.stroke(swirl, with: .color(hlColor), style: hlStroke)
            
            // 6. 左侧如意卷云分叉鱼尾雕纹
            let tailCurves: [(p1: CGPoint, p2: CGPoint, cp: CGPoint)] = [
                (CGPoint(x: w * 0.22, y: h * 0.24), CGPoint(x: w * 0.10, y: h * 0.30), CGPoint(x: w * 0.15, y: h * 0.22)),
                (CGPoint(x: w * 0.20, y: h * 0.48), CGPoint(x: w * 0.08, y: h * 0.48), CGPoint(x: w * 0.14, y: h * 0.46)),
                (CGPoint(x: w * 0.22, y: h * 0.72), CGPoint(x: w * 0.10, y: h * 0.66), CGPoint(x: w * 0.15, y: h * 0.74))
            ]
            
            for tc in tailCurves {
                var p = Path()
                p.move(to: tc.p1)
                p.addQuadCurve(to: tc.p2, control: tc.cp)
                context.stroke(p, with: .color(shColor), style: shadowStroke)
                context.stroke(p, with: .color(hlColor), style: hlStroke)
            }
        }
    }
}

// MARK: - 深色老红木双层莲瓣雕花底座 (Double-Tier Lotus Wooden Pedestal)
struct LotusPedestalView: View {
    var body: some View {
        ZStack {
            // 1. 底座底部与桌面接触阴影
            Ellipse()
                .fill(Color.black.opacity(0.55))
                .frame(width: 140, height: 20)
                .offset(y: 16)
            
            // 2. 下层覆莲花瓣底足 (Base lotus petals)
            ZStack {
                // 底座本体
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.18, blue: 0.12),
                                Color(red: 0.22, green: 0.08, blue: 0.05),
                                Color(red: 0.10, green: 0.04, blue: 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 132, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.55, green: 0.28, blue: 0.18).opacity(0.5), lineWidth: 1)
                    )
                
                // 下层莲瓣雕刻线条
                HStack(spacing: 5) {
                    ForEach(0..<10) { _ in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.45, green: 0.22, blue: 0.14), Color.black.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 8, height: 16)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                }
            }
            .offset(y: 8)
            
            // 3. 中间束腰木环
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.16, green: 0.06, blue: 0.04))
                .frame(width: 112, height: 6)
                .offset(y: -3)
            
            // 4. 上层仰莲花瓣托盘 (Upper lotus petals supporting the jade carp)
            ZStack {
                // 上层圆盘
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.42, green: 0.22, blue: 0.15),
                                Color(red: 0.25, green: 0.10, blue: 0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 124, height: 16)
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: -2)
                
                // 上层仰莲花瓣雕纹
                HStack(spacing: 4) {
                    ForEach(0..<9) { _ in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.52, green: 0.28, blue: 0.18), Color(red: 0.20, green: 0.08, blue: 0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                    }
                }
                .offset(y: -4)
            }
            .offset(y: -10)
        }
        .frame(width: 140, height: 38)
    }
}

extension View {
    func cursorHand() -> some View {
        #if os(macOS)
        return self.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        return self
        #endif
    }
}
