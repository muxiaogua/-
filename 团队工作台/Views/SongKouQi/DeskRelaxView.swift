//
//  DeskRelaxView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct DeskRelaxView: View {
    @State private var selectedPart: DeskBodyPart = .all
    @State private var currentIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var remainingSeconds: Int = 20
    @State private var timer: Timer? = nil
    @State private var isFinishSheetOpen: Bool = false
    
    // 当前部位过滤后的动作列表
    private var filteredExercises: [DeskExercise] {
        if selectedPart == .all {
            return DeskExercise.allExercises
        } else {
            return DeskExercise.allExercises.filter { $0.part == selectedPart }
        }
    }
    
    private var currentExercise: DeskExercise {
        if currentIndex >= filteredExercises.count {
            return filteredExercises.first ?? DeskExercise.allExercises[0]
        }
        return filteredExercises[currentIndex]
    }
    
    @ObservedObject var themeManager = AppThemeManager.shared
    
    var body: some View {
        ZStack {
            // 背景沉浸渐变（跟随全局主题）
            LinearGradient(
                colors: themeManager.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 顶部标题与部位快速选择
                topBar
                
                // 主工作区：左侧动作动态姿势图示，右侧倒计时与要领引导
                HStack(spacing: 14) {
                    // 左侧：动作动态示范与呼吸光环
                    exerciseVisualCard
                        .frame(maxWidth: .infinity)
                    
                    // 右侧：倒计时呼吸环、动作步骤要领与控制
                    exerciseGuideCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)
        }
        .onAppear {
            setupInitialExercise()
        }
        .onDisappear {
            pauseTimer()
        }
        .sheet(isPresented: $isFinishSheetOpen) {
            exerciseCompletionSheet
        }
    }
    
    // MARK: - 顶部导航与部位选择
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(t("拯救低头族"))
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
                    
                    Text(t("・ 工位肩颈身体放松操"))
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                
                Text(t("无需器械，在工位椅子上跟着做：护眼・松肩颈・活动手腕・舒展双腿"))
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(themeManager.textSecondary)
            }
            
            Spacer()
            
            // 部位过滤标签
            HStack(spacing: 8) {
                ForEach(DeskBodyPart.allCases) { part in
                    let isSelected = (selectedPart == part)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPart = part
                            currentIndex = 0
                            setupInitialExercise()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: part.icon)
                                .font(.system(size: 13))
                            Text(part.localizedName)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .serif))
                        }
                        .foregroundColor(isSelected ? part.themeColor : themeManager.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? part.themeColor.opacity(0.18) : themeManager.secondaryCardBackground)
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? part.themeColor.opacity(0.65) : themeManager.borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 左侧：动作动态姿势示范图
    private var exerciseVisualCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // 呼吸扩散光环（纯视觉跟随呼吸节律微缩放大）
                BreathingAuraRing(color: currentExercise.part.themeColor)
                
                // 动作精准动态矢量示范
                ExerciseVisualIllustration(type: currentExercise.visualType, color: currentExercise.part.themeColor)
                    .frame(width: 200, height: 200)
            }
            .frame(height: 220)
            
            // 呼吸调息建议条
            HStack(spacing: 7) {
                Image(systemName: "wind")
                    .font(.system(size: 14))
                    .foregroundColor(currentExercise.part.themeColor)
                Text(currentExercise.localizedBreathingTip)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(themeManager.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(currentExercise.part.themeColor.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(currentExercise.part.themeColor.opacity(0.35), lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.borderColor, lineWidth: 1)
                )
        )
    }
    
    // MARK: - 右侧：动作要领与倒计时控制
    private var exerciseGuideCard: some View {
        VStack(spacing: 12) {
            // 顶部进度指示与动作标题
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(format: "%02d / %02d", currentIndex + 1, filteredExercises.count))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(currentExercise.part.themeColor)
                        
                        Text("【\(currentExercise.part.localizedName)】")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(themeManager.textSecondary)
                    }
                    
                    Text(currentExercise.localizedName)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.textPrimary)
                    
                    Text(currentExercise.localizedSubtitle)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                
                Spacer()
                
                // 倒计时环形进度小窗口
                countdownProgressRing
            }
            
            Divider()
                .background(themeManager.borderColor.opacity(0.4))
            
            // 动作要领 3 步列表
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(currentExercise.localizedSteps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(currentExercise.part.themeColor.opacity(0.2))
                                .frame(width: 22, height: 22)
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(currentExercise.part.themeColor)
                        }
                        .padding(.top, 1)
                        
                        Text(step)
                            .font(.system(size: 14.5, design: .serif))
                            .foregroundColor(themeManager.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Spacer()
            
            // 下方控制按钮行 (上一个、开始/暂停跟练、下一个)
            controlButtonsRow
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.borderColor, lineWidth: 1)
                )
        )
    }
    
    // 倒计时环形进度
    private var countdownProgressRing: some View {
        let total = Double(currentExercise.duration)
        let current = Double(remainingSeconds)
        let progress = max(0.0, min(1.0, current / (total > 0 ? total : 20.0)))
        
        return ZStack {
            Circle()
                .stroke(themeManager.borderColor, lineWidth: 4)
                .frame(width: 58, height: 58)
            
            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(currentExercise.part.themeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 58, height: 58)
                .animation(.linear(duration: 1.0), value: progress)
            
            Text("\(remainingSeconds)s")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.textPrimary)
        }
    }
    
    // 控制按钮行
    private var controlButtonsRow: some View {
        HStack(spacing: 14) {
            // 上一个
            Button {
                previousExercise()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
                    .foregroundColor(themeManager.textPrimary)
                    .padding(10)
                    .background(themeManager.secondaryCardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(themeManager.borderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)
            
            // 播放 / 暂停
            Button {
                togglePlay()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                    Text(isPlaying ? t("暂停练习") : t("开始跟练"))
                        .font(.system(size: 15, weight: .bold, design: .serif))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [
                            currentExercise.part.themeColor,
                            currentExercise.part.themeColor.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: currentExercise.part.themeColor.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            
            // 下一个
            Button {
                nextExercise()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
                    .foregroundColor(themeManager.textPrimary)
                    .padding(10)
                    .background(themeManager.secondaryCardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(themeManager.borderColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 动作流控制逻辑 (纯静音)
    private func setupInitialExercise() {
        remainingSeconds = currentExercise.duration
        isPlaying = false
    }
    
    private func togglePlay() {
        if isPlaying {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 1 {
                remainingSeconds -= 1
            } else {
                advanceToNext()
            }
        }
    }
    
    private func pauseTimer() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    private func advanceToNext() {
        if currentIndex + 1 < filteredExercises.count {
            currentIndex += 1
            remainingSeconds = currentExercise.duration
        } else {
            pauseTimer()
            remainingSeconds = 0
            isFinishSheetOpen = true
        }
    }
    
    private func nextExercise() {
        if currentIndex + 1 < filteredExercises.count {
            currentIndex += 1
            remainingSeconds = currentExercise.duration
        } else {
            currentIndex = 0
            remainingSeconds = currentExercise.duration
        }
    }
    
    private func previousExercise() {
        if currentIndex > 0 {
            currentIndex -= 1
            remainingSeconds = currentExercise.duration
        }
    }
    
    // MARK: - 放松完成弹窗
    private var exerciseCompletionSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46))
                .foregroundColor(.green)
                .padding(.top, 10)
            
            Text(t("工位放松打卡完成！"))
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(themeManager.textPrimary)
            
            Text(t("肩颈微热，眼目清明，手脚舒展。\n回到工作时，请记得保持坐姿挺拔，定时休息。"))
                .font(.system(size: 15.5, design: .serif))
                .foregroundColor(themeManager.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 16)
            
            Button(t("神清气爽・完成打卡")) {
                isFinishSheetOpen = false
                currentIndex = 0
                setupInitialExercise()
            }
            .font(.system(size: 15, weight: .bold, design: .serif))
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 6)
        }
        .padding(26)
        .frame(width: 380, height: 280)
    }
}

// MARK: - 呼吸扩散光环
struct BreathingAuraRing: View {
    let color: Color
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let breathe = 0.88 + 0.12 * sin(time * 1.5)
            
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 2)
                .scaleEffect(breathe)
                .frame(width: 200, height: 200)
        }
    }
}

// MARK: - 动作生动动态矢量示意图
struct ExerciseVisualIllustration: View {
    let type: ExerciseVisualType
    let color: Color
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                switch type {
                case .eyeBlink:
                    EyeBlinkVisual(time: time, color: color)
                case .eyeRoll:
                    EyeRollVisual(time: time, color: color)
                case .eyePalming:
                    EyePalmingVisual(time: time, color: color)
                case .neckSideStretch:
                    NeckSideStretchVisual(time: time, color: color)
                case .neckUpDown:
                    NeckUpDownVisual(time: time, color: color)
                case .shoulderRoll:
                    ShoulderRollVisual(time: time, color: color)
                case .neckPosturalChest:
                    NeckPosturalChestVisual(time: time, color: color)
                case .wristFlexion:
                    WristFlexionVisual(time: time, color: color)
                case .wristPrayerRotate:
                    WristPrayerRotateVisual(time: time, color: color)
                case .legLiftExtend:
                    LegLiftExtendVisual(time: time, color: color)
                case .legHeelRaise:
                    LegHeelRaiseVisual(time: time, color: color)
                case .legAnkleRoll:
                    LegAnkleRollVisual(time: time, color: color)
                }
            }
        }
    }
}

// MARK: - 1. 远眺眨眼 (远眺山景 + 眼睑轻眨动效)
struct EyeBlinkVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let blinkPhase = sin(time * 2.8)
        let eyeScaleY = blinkPhase > 0.8 ? max(0.08, (1.0 - (blinkPhase - 0.8) * 5.0)) : 1.0
        
        VStack(spacing: 12) {
            // 背景远山眺望景观
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 140, height: 60)
                
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 26))
                    .foregroundColor(color.opacity(0.5))
                    .offset(y: 8)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow.opacity(0.8))
                    .offset(x: 35, y: -12)
            }
            
            // 眨眼双眼矢量
            HStack(spacing: 24) {
                SingleEyeView(scaleY: eyeScaleY, color: color)
                SingleEyeView(scaleY: eyeScaleY, color: color)
            }
            
            Text(t("看向远方・轻柔眨眼"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

struct SingleEyeView: View {
    let scaleY: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(width: 38, height: 22)
                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
            
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
            
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 2, y: -2)
        }
        .scaleEffect(y: scaleY)
    }
}

// MARK: - 2. 眼球米字环视 (双眼眼球沿圆周与米字轨迹转动)
struct EyeRollVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let angle = time * 2.2
        let pupilX = cos(angle) * 7.0
        let pupilY = sin(angle) * 5.0
        
        VStack(spacing: 12) {
            // 米字辅助轨迹线
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 130, height: 60)
                
                HStack(spacing: 24) {
                    TrackedEyeView(pupilX: pupilX, pupilY: pupilY, color: color)
                    TrackedEyeView(pupilX: pupilX, pupilY: pupilY, color: color)
                }
            }
            
            Text(t("眼球画圆・顺逆时针慢转"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

struct TrackedEyeView: View {
    let pupilX: CGFloat
    let pupilY: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(width: 40, height: 24)
                .overlay(Capsule().stroke(Color.gray.opacity(0.35), lineWidth: 1))
            
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .offset(x: pupilX, y: pupilY)
            
            Circle()
                .fill(Color.black)
                .frame(width: 9, height: 9)
                .offset(x: pupilX, y: pupilY)
            
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: pupilX + 2, y: pupilY - 2)
        }
    }
}

// MARK: - 3. 掌心温敷闭目 (双手捂眼 + 温热微光波动)
struct EyePalmingVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let heatPulse = 0.7 + 0.3 * sin(time * 3.0)
        
        VStack(spacing: 10) {
            ZStack {
                // 面部与紧闭安详双眼
                Circle()
                    .fill(Color(red: 0.2, green: 0.22, blue: 0.25))
                    .frame(width: 90, height: 90)
                
                // 闭眼弧线
                HStack(spacing: 20) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .offset(y: -5)
                
                // 温热光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.5 * heatPulse), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                
                // 覆在眼上的双手
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 38))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(-18))
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 38))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(18))
                }
                .offset(y: -4)
            }
            .frame(height: 120)
            
            Text(t("搓热掌心・空心覆眼"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 4. 颈部左右侧向拉伸 (手扶头部侧拉伸脖子)
struct NeckSideStretchVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        // 缓慢左右摆动拉伸
        let tilt = sin(time * 1.5) * 28.0
        let isLeft = tilt < 0
        
        VStack(spacing: 10) {
            ZStack {
                // 躯干肩膀基底
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 110, height: 48)
                    .offset(y: 45)
                
                // 头部与手臂拉伸结构
                VStack(spacing: 0) {
                    // 头顶手掌辅助拉伸
                    Image(systemName: isLeft ? "hand.point.left.fill" : "hand.point.right.fill")
                        .font(.system(size: 16))
                        .foregroundColor(color)
                        .offset(y: 6)
                    
                    // 头部
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    // 颈部
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.8))
                        .frame(width: 14, height: 16)
                }
                .rotationEffect(.degrees(tilt), anchor: .bottom)
                .offset(y: 10)
                
                // 侧颈拉伸弧形指示箭头
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(y: -35)
            }
            .frame(height: 130)
            
            Text(t("手搭头顶・侧向拉伸颈侧"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 5. 低头后仰展颈 (低头贴胸与抬头后仰)
struct NeckUpDownVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let nodAngle = sin(time * 1.6) * 32.0 // 正为仰，负为低头
        
        VStack(spacing: 10) {
            ZStack {
                // 肩部基底
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 100, height: 44)
                    .offset(y: 45)
                
                // 侧脸剪影做低头抬头
                VStack(spacing: 0) {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            // 鼻尖朝向指示
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .offset(x: 18, y: 0)
                        )
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.8))
                        .frame(width: 14, height: 16)
                }
                .rotationEffect(.degrees(nodAngle), anchor: .bottom)
                .offset(y: 10)
                
                // 上下箭头
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(x: 45, y: -5)
            }
            .frame(height: 130)
            
            Text(nodAngle > 0 ? t("下巴朝天・拉伸颈前") : t("下巴贴胸・拉伸后颈"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 6. 沉肩双向大绕环 (双肩耸起向后大画圆)
struct ShoulderRollVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let rollAngle = time * 2.8
        let shoulderOffsetX = cos(rollAngle) * 8.0
        let shoulderOffsetY = sin(rollAngle) * 10.0
        
        VStack(spacing: 10) {
            ZStack {
                // 头部
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .offset(y: -25)
                
                // 左右肩膀旋转
                HStack(spacing: 40) {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .offset(x: -shoulderOffsetX, y: shoulderOffsetY + 15)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .offset(x: shoulderOffsetX, y: shoulderOffsetY + 15)
                }
                
                // 旋转虚线轨迹圈
                HStack(spacing: 40) {
                    Circle()
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 32, height: 32)
                        .offset(y: 15)
                    Circle()
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 32, height: 32)
                        .offset(y: 15)
                }
            }
            .frame(height: 120)
            
            Text(t("双肩耸起・前后大幅度画圆"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 7. 后脑抱头仰颈扩胸 (十指交叉抱头 + 手肘大开挺胸)
struct NeckPosturalChestVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let expand = 1.0 + 0.08 * sin(time * 2.0)
        
        VStack(spacing: 10) {
            ZStack {
                // 挺拔胸腔与躯干
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.6))
                    .frame(width: 60, height: 65)
                    .offset(y: 28)
                    .scaleEffect(x: expand, y: 1.0)
                
                // 头部
                Circle()
                    .fill(color)
                    .frame(width: 42, height: 42)
                    .offset(y: -18)
                
                // 两侧大大展开的手肘
                HStack(spacing: 38) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 14, height: 38)
                        .rotationEffect(.degrees(-35))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 14, height: 38)
                        .rotationEffect(.degrees(35))
                }
                .offset(y: -15)
                .scaleEffect(expand)
                
                // 双手交叉抱头标记
                Image(systemName: "hands.sparkles.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(y: -42)
            }
            .frame(height: 120)
            
            Text(t("十指抱头・肘部打开・挺胸后仰"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 8. 键盘手腕上下屈伸 (手掌立起下压与折叠拉伸)
struct WristFlexionVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let flexPhase = sin(time * 2.2)
        let isUp = flexPhase > 0
        let wristAngle = isUp ? -40.0 : 40.0
        
        VStack(spacing: 10) {
            ZStack {
                // 前臂
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 75, height: 18)
                    .offset(x: -30, y: 0)
                
                // 手掌与手指（屈伸动作）
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 45, height: 18)
                    .offset(x: 22, y: 0)
                    .rotationEffect(.degrees(wristAngle), anchor: .leading)
                
                // 另一只手的辅助拉伸箭头
                Image(systemName: isUp ? "arrow.left" : "arrow.down")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(x: 45, y: isUp ? -20 : 20)
            }
            .frame(height: 120)
            
            Text(isUp ? t("手指朝上・轻拉指尖向内") : t("指尖朝下・轻压手背折叠"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 9. 祈祷式反压与手腕绕圈 (双手合十下压 + 旋转)
struct WristPrayerRotateVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let yShift = sin(time * 2.5) * 12.0
        
        VStack(spacing: 10) {
            ZStack {
                // 双手合十祈祷姿势
                HStack(spacing: 2) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundColor(color)
                        .scaleEffect(x: -1, y: 1)
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundColor(color)
                }
                .offset(y: yShift)
                
                // 下压反向箭头
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(y: 35)
            }
            .frame(height: 120)
            
            Text(t("双手合十下压・手腕充分受力"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 10. 坐姿单腿抬升回勾 (工位单腿平举伸直 + 脚尖回勾)
struct LegLiftExtendVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let legLiftAngle = max(0.0, sin(time * 2.0)) * -45.0 // 腿部向前抬平
        
        VStack(spacing: 10) {
            ZStack {
                // 椅子简图
                Path { p in
                    p.move(to: CGPoint(x: 40, y: 30))
                    p.addLine(to: CGPoint(x: 40, y: 80))
                    p.addLine(to: CGPoint(x: 80, y: 80))
                    p.addLine(to: CGPoint(x: 80, y: 120))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
                
                // 坐着的人躯干与大腿
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 22, height: 22)
                    .offset(x: -15, y: -25)
                
                // 躯干
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 14, height: 35)
                    .offset(x: -15, y: 8)
                
                // 抬起伸展的小腿与回勾脚尖
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 42, height: 10)
                    
                    // 回勾脚掌
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 14)
                        .offset(y: -2)
                }
                .rotationEffect(.degrees(legLiftAngle), anchor: .leading)
                .offset(x: 5, y: 25)
            }
            .frame(height: 120)
            
            Text(t("单腿平举伸直・脚尖用力回勾"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 11. 隐形提踵踮脚尖 (脚后跟高高踮起 + 脚尖上勾)
struct LegHeelRaiseVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let pump = sin(time * 3.5)
        let isHeelUp = pump > 0
        let footAngle = isHeelUp ? -28.0 : 18.0
        let calfHeightShift = isHeelUp ? -12.0 : 0.0
        
        VStack(spacing: 10) {
            ZStack {
                // 地面基准线
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 2)
                    .offset(y: 45)
                
                // 小腿肌肉（带提踵收缩动效）
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 16, height: 65)
                    .offset(x: -10, y: calfHeightShift)
                
                // 脚掌（以脚尖为轴踮起脚后跟）
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 38, height: 10)
                    .rotationEffect(.degrees(footAngle), anchor: .leading)
                    .offset(x: 5, y: 40 + (isHeelUp ? -6 : 0))
                
                // 提踵上升箭头
                Image(systemName: isHeelUp ? "arrow.up" : "arrow.down")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(x: -35, y: calfHeightShift)
            }
            .frame(height: 120)
            
            Text(isHeelUp ? t("后跟用力踮起・小腿肌肉收缩") : t("脚跟着地・脚尖向上勾起"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}

// MARK: - 12. 脚踝顺逆时针大画圆 (悬空脚掌以踝关节为中心画大圆)
struct LegAnkleRollVisual: View {
    let time: Double
    let color: Color
    
    var body: some View {
        let ankleAngle = time * 3.0
        let toeX = cos(ankleAngle) * 16.0
        let toeY = sin(ankleAngle) * 12.0
        
        VStack(spacing: 10) {
            ZStack {
                // 悬空下垂的小腿
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.8))
                    .frame(width: 16, height: 50)
                    .offset(y: -20)
                
                // 脚踝圆周运动虚线轨迹
                Circle()
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 48, height: 38)
                    .offset(y: 20)
                
                // 旋转的脚掌与脚尖
                ZStack {
                    Capsule()
                        .fill(color)
                        .frame(width: 34, height: 12)
                    
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .offset(x: 12)
                }
                .offset(x: toeX, y: 20 + toeY)
            }
            .frame(height: 120)
            
            Text(t("悬空脚尖・顺逆时针大画圆"))
                .font(.system(size: 13.5, weight: .medium, design: .serif))
                .foregroundColor(AppThemeManager.shared.textPrimary)
        }
    }
}
