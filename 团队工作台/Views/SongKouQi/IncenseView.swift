//
//  IncenseView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct IncenseView: View {
    @ObservedObject var themeManager = AppThemeManager.shared
    @ObservedObject var soundManager = SoundManager.shared
    
    // 烧香状态
    @State private var isLit: Bool = false
    @State private var incenseType: IncenseType = .sandalwood
    @State private var censerStyle: CenserStyle = .bronze
    @State private var selectedDuration: IncenseDuration = .min14_30
    @State private var remainingSeconds: Int = 870
    @State private var totalSeconds: Int = 870
    @State private var burnProgress: Double = 0.0 // 0.0 ~ 1.0
    
    // 许愿与心愿牌
    @State private var currentWish: String = "平安顺遂，诸事皆宁"
    @State private var isWishSheetOpen: Bool = false
    @State private var customWishInput: String = ""
    
    // 计时器
    @State private var timer: Timer? = nil
    
    let defaultWishes = [
        "平安顺遂，诸事皆宁",
        "心如止水，无挂无碍",
        "准时下班，远离加班",
        "遇到天使客户，好评满满",
        "福泽绵长，阖家康泰",
        "事业通达，步步登高",
        "身心安泰，百病不侵",
        "财源广进，好运连连"
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片标题栏与心愿牌
            cardHeader
            
            // 心愿条幅
            wishBanner
            
            Spacer(minLength: 4)
            
            // 烧香与香炉核心展示区
            ZStack {
                // 香烟缭绕特效
                if isLit {
                    SmokeParticlesView(glowColor: incenseType.glowColor)
                        .frame(width: 200, height: 160)
                        .offset(y: -75 + (burnProgress * 45))
                }
                
                // 三炷香与香炉
                censerAndSticksGraphic
                    .offset(y: 26)
            }
            .frame(height: 160)
            
            Spacer(minLength: 4)
            
            // 底部控制
            bottomControls
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
        .onDisappear {
            stopBurning()
        }
        .sheet(isPresented: $isWishSheetOpen) {
            wishPickerSheet
        }
    }
    
    // MARK: - 标题
    private var cardHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundColor(isLit ? incenseType.glowColor : themeManager.accentColor)
                Text(t("烧香祈福"))
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
            }
            
            Spacer()
            
            // 声音开关 (静音按钮 - 放在只看烧香的左边)
            Button {
                soundManager.isIncenseMuted.toggle()
                if !soundManager.isIncenseMuted && isLit {
                    soundManager.playIncenseBGM(type: incenseType)
                } else if soundManager.isIncenseMuted {
                    soundManager.stopIncenseBGM()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: soundManager.isIncenseMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                    Text(soundManager.isIncenseMuted ? t("静音") : t("有声"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                }
                .foregroundColor(soundManager.isIncenseMuted ? themeManager.textSecondary : themeManager.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(soundManager.isIncenseMuted ? themeManager.secondaryCardBackground : themeManager.accentColor.opacity(0.18))
                )
                .overlay(
                    Capsule().stroke(soundManager.isIncenseMuted ? themeManager.borderColor : themeManager.accentColor.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(soundManager.isIncenseMuted ? t("点击开启伴奏音乐") : t("点击关闭声音(开启静音)"))
            
            // 极简纯净模式 (只看烧香)
            Button {
                AppStateManager.shared.enterPureIncenseMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pip.enter")
                        .font(.system(size: 11, weight: .semibold))
                    Text(t("只看烧香"))
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
            .help(t("隐藏软件页面，只保留烧香与香烟升腾动画悬浮窗"))
        }
    }
    
    // MARK: - 香型选择按钮（置于燃香静心按钮左侧）
    private var incenseSelectorButton: some View {
        Menu {
            ForEach(IncenseType.allCases) { type in
                Button {
                    incenseType = type
                    if isLit {
                        soundManager.switchIncenseBGM(to: type)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(type.localizedName) · \(type.musicTitle)")
                            Text(type.musicDescription)
                                .font(.caption2)
                        }
                        if incenseType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isLit && !soundManager.isIncenseMuted ? "waveform" : "leaf.fill")
                    .font(.caption2)
                    .foregroundColor(isLit ? incenseType.glowColor : themeManager.accentColor)
                Text(incenseType.localizedName)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(themeManager.textSecondary)
            }
            .foregroundColor(themeManager.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isLit ? incenseType.glowColor.opacity(0.22) : themeManager.secondaryCardBackground)
            )
            .overlay(
                Capsule().stroke(isLit ? incenseType.glowColor.opacity(0.45) : themeManager.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(t("点击更换香型与伴随禅音"))
    }
    
    // MARK: - 心愿条幅
    private var wishBanner: some View {
        Button {
            isWishSheetOpen = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scroll.fill")
                    .font(.caption2)
                    .foregroundColor(themeManager.accentColor)
                Text(currentWish.localized)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundColor(themeManager.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.secondaryCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 香炉与三炷香
    private var censerAndSticksGraphic: some View {
        ZStack {
            // 阴影
            Ellipse()
                .fill(Color.black.opacity(0.5))
                .frame(width: 160, height: 30)
                .offset(y: 45)
            
            // 三炷香
            HStack(spacing: 14) {
                incenseStick(angle: -3.0, heightRatio: 0.95)
                incenseStick(angle: 0.0, heightRatio: 1.0)
                incenseStick(angle: 3.0, heightRatio: 0.95)
            }
            .offset(y: -30)
            
            // 香炉
            censerGraphic
        }
    }
    
    private func incenseStick(angle: Double, heightRatio: Double) -> some View {
        let maxStickHeight: CGFloat = 85 * CGFloat(heightRatio)
        let currentHeight = max(12, maxStickHeight * CGFloat(1.0 - burnProgress * 0.75))
        
        return VStack(spacing: 0) {
            if isLit {
                IncenseSparkView(glowColor: incenseType.glowColor, angle: angle)
                    .frame(height: 8)
            } else {
                Circle()
                    .fill(Color(red: 0.45, green: 0.35, blue: 0.3))
                    .frame(width: 3, height: 3)
            }
            
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.65, green: 0.45, blue: 0.30), Color(red: 0.48, green: 0.32, blue: 0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: currentHeight)
            
            Rectangle()
                .fill(Color(red: 0.65, green: 0.15, blue: 0.15))
                .frame(width: 2, height: 18)
        }
        .rotationEffect(.degrees(angle), anchor: .bottom)
    }
    
    private var censerGraphic: some View {
        ZStack {
            CenserBodyShape()
                .fill(
                    LinearGradient(
                        colors: censerStyle.baseColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 58)
                .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 5)
            
            CenserRimShape()
                .stroke(censerStyle.trimColor, lineWidth: 2)
                .frame(width: 130, height: 58)
            
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.55), Color(white: 0.40)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 96, height: 12)
                .offset(y: -20)
            
            Text("禅")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(themeManager.accentColor.opacity(0.85))
                .offset(y: 3)
        }
    }
    
    // MARK: - 底部控制
    private var bottomControls: some View {
        VStack(spacing: 9) {
            // 午间休息放松音乐状态栏 (点击可快速切换静音/开启)
            Button {
                soundManager.isIncenseMuted.toggle()
                if !soundManager.isIncenseMuted && isLit {
                    soundManager.playIncenseBGM(type: incenseType)
                } else if soundManager.isIncenseMuted {
                    soundManager.stopIncenseBGM()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isLit && !soundManager.isIncenseMuted ? "music.note" : "speaker.slash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isLit ? (soundManager.isIncenseMuted ? .secondary : incenseType.glowColor) : .secondary)
                    Text(incenseType.musicTitle)
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(isLit ? (soundManager.isIncenseMuted ? themeManager.textSecondary : themeManager.textPrimary) : themeManager.textSecondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(isLit ? (soundManager.isIncenseMuted ? t("已静音(点击开启)") : t("午间舒缓放松中")) : t("燃香伴奏"))
                        .font(.system(size: 10))
                        .foregroundColor(isLit ? (soundManager.isIncenseMuted ? themeManager.textSecondary : incenseType.glowColor) : themeManager.textSecondary.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(themeManager.secondaryCardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 8) {
                // 香炉选择
                Menu {
                    ForEach(CenserStyle.allCases) { style in
                        Button {
                            censerStyle = style
                        } label: {
                            HStack {
                                Text(style.localizedName)
                                if censerStyle == style {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(censerStyle.localizedName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeManager.secondaryCardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // 时长选择
                Menu {
                    ForEach(IncenseDuration.allCases) { dur in
                        Button {
                            selectedDuration = dur
                            if !isLit {
                                totalSeconds = dur.rawValue
                                remainingSeconds = dur.rawValue
                            }
                        } label: {
                            HStack {
                                Text(dur.title)
                                if selectedDuration == dur {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text(selectedDuration.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(themeManager.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeManager.secondaryCardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // 燃香主控制行
            HStack(spacing: 10) {
                // 香型选择按钮（置于燃香静心按钮左侧）
                incenseSelectorButton
                
                // 燃香主按钮
                Button {
                    toggleLighting()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLit ? "flame.slash.fill" : "flame.fill")
                            .font(.caption)
                        Text(isLit ? t("熄灭香火") : t("燃香静心"))
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(isLit ? .red.opacity(0.9) : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isLit ? Color.red.opacity(0.18) : Color(red: 0.85, green: 0.35, blue: 0.2))
                    )
                    .overlay(
                        Capsule().stroke(isLit ? Color.red.opacity(0.5) : Color.yellow.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                if isLit && selectedDuration.rawValue > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(formatTime(remainingSeconds))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - 燃香逻辑 (无声音)
    private func toggleLighting() {
        if isLit {
            stopBurning()
        } else {
            startBurning()
        }
    }
    
    private func startBurning() {
        isLit = true
        let targetSec = selectedDuration.rawValue > 0 ? selectedDuration.rawValue : 870
        totalSeconds = targetSec
        remainingSeconds = targetSec
        burnProgress = 0.0
        
        // 自动开启当前香型的午间放松背景音乐
        soundManager.playIncenseBGM(type: incenseType)
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if selectedDuration.rawValue > 0 {
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                    burnProgress = Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
                } else {
                    stopBurning()
                }
            } else {
                burnProgress = (burnProgress + 0.002).truncatingRemainder(dividingBy: 1.0)
            }
        }
    }
    
    private func stopBurning() {
        isLit = false
        timer?.invalidate()
        timer = nil
        
        // 停止午间放松背景音乐
        soundManager.stopIncenseBGM()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var wishPickerSheet: some View {
        VStack(spacing: 16) {
            Text(t("供奉祈愿心愿"))
                .font(.system(size: 16, weight: .bold, design: .serif))
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(defaultWishes, id: \.self) { wish in
                        Button {
                            currentWish = wish
                            isWishSheetOpen = false
                        } label: {
                            HStack {
                                Text(wish.localized)
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundColor(.white)
                                Spacer()
                                if currentWish == wish {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(currentWish == wish ? Color.yellow.opacity(0.15) : Color.white.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 180)
            
            HStack {
                TextField(t("写下您的专属心愿..."), text: $customWishInput)
                    .textFieldStyle(.roundedBorder)
                Button(t("确定")) {
                    if !customWishInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        currentWish = customWishInput
                    }
                    isWishSheetOpen = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 340, height: 320)
    }
}

// MARK: - 袅袅青烟粒子系统
struct SmokeParticlesView: View {
    let glowColor: Color
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let width = size.width
                let height = size.height
                let origins: [CGFloat] = [width * 0.45, width * 0.5, width * 0.55]
                
                for (idx, startX) in origins.enumerated() {
                    let phaseOffset = Double(idx) * 1.8
                    var path = Path()
                    path.move(to: CGPoint(x: startX, y: height))
                    
                    let steps = 30
                    for step in 1...steps {
                        let progress = Double(step) / Double(steps)
                        let y = height * (1.0 - CGFloat(progress))
                        let wave1 = sin((time * 2.2) - (progress * 5.0) + phaseOffset) * (progress * 25.0)
                        let wave2 = cos((time * 1.5) - (progress * 7.0)) * (progress * 12.0)
                        let x = startX + CGFloat(wave1 + wave2)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    let strokeColor = Color.white.opacity(0.35 * (1.0 - Double(idx) * 0.05))
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                glowColor.opacity(0.6),
                                strokeColor,
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: CGPoint(x: startX, y: height),
                            endPoint: CGPoint(x: startX, y: 0)
                        ),
                        lineWidth: CGFloat(2.5 + Double(idx) * 0.6)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct CenserBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.15))
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.78),
            control1: CGPoint(x: w * 0.98, y: h * 0.42),
            control2: CGPoint(x: w * 0.92, y: h * 0.72)
        )
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.98))
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.78))
        path.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.15),
            control1: CGPoint(x: w * 0.08, y: h * 0.72),
            control2: CGPoint(x: w * 0.02, y: h * 0.42)
        )
        path.closeSubpath()
        return path
    }
}

struct CenserRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.06, width: w * 0.76, height: h * 0.22))
        return path
    }
}

struct IncenseSparkView: View {
    let glowColor: Color
    let angle: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let glow = 0.7 + 0.3 * sin(time * 3.5 + angle)
            
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.5 * glow))
                    .frame(width: 10, height: 10)
                    .blur(radius: 1.5)
                
                Circle()
                    .fill(Color(red: 1.0, green: 0.9, blue: 0.6))
                    .frame(width: 3, height: 3)
            }
        }
    }
}
