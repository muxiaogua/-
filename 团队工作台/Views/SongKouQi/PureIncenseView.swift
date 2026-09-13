//
//  PureIncenseView.swift
//  放松
//
//  Created by apple on 2026/9/9.
//

import SwiftUI
import Combine

// MARK: - 极简纯净烧香视图 (隐藏所有软件页面，只保留烧香动画与袅袅青烟)
struct PureIncenseView: View {
    @ObservedObject var appState = AppStateManager.shared
    @ObservedObject var themeManager = AppThemeManager.shared
    @ObservedObject var soundManager = SoundManager.shared
    
    // 烧香状态
    @State private var isLit: Bool = true // 极简模式下默认点燃或持续燃烧
    @State private var incenseType: IncenseType = .sandalwood
    @State private var censerStyle: CenserStyle = .bronze
    @State private var selectedDuration: IncenseDuration = .min14_30
    @State private var remainingSeconds: Int = 870
    @State private var totalSeconds: Int = 870
    @State private var burnProgress: Double = 0.0
    
    // 许愿与心愿
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
        ZStack {
            // 完全透明背景 (悬浮于桌面)
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 6) {
                // 顶部极简快捷控制栏 (返回主界面、心愿牌、置顶、声音)
                miniTopBar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                
                // 心愿条幅
                wishBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                
                Spacer(minLength: 4)
                
                // 核心烧香与袅袅香烟动画展示区
                ZStack {
                    // 香烟缭绕上升粒子动画
                    if isLit {
                        SmokeParticlesView(glowColor: incenseType.glowColor)
                            .frame(width: 220, height: 170)
                            .offset(y: -75 + (burnProgress * 45))
                    }
                    
                    // 三炷香与香炉
                    censerAndSticksGraphic
                        .offset(y: 35)
                }
                .frame(height: 190)
                
                Spacer(minLength: 4)
                
                // 底部控制 (香型切换、香炉选择、燃香主控)
                miniBottomBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 320, height: 400)
        .background(Color.clear)
        .onAppear {
            startBurning()
        }
        .onDisappear {
            stopBurning()
        }
        .sheet(isPresented: $isWishSheetOpen) {
            wishPickerSheet
        }
    }
    
    // MARK: - 顶部极简控制栏
    private var miniTopBar: some View {
        HStack {
            // 返回完整界面
            Button {
                appState.exitMiniMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(t("完整界面"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(t("返回完整功能界面"))
            
            Spacer()
            
            // 香型提示
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isLit ? incenseType.glowColor : .yellow)
                Text(incenseType.localizedName)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(
                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
            
            // 置顶切换按钮
            Button {
                appState.setAlwaysOnTop(!appState.isAlwaysOnTop)
            } label: {
                Image(systemName: appState.isAlwaysOnTop ? "pin.fill" : "pin.slash")
                    .font(.system(size: 11))
                    .foregroundColor(appState.isAlwaysOnTop ? .yellow : .white.opacity(0.7))
                    .padding(6)
                    .background(
                        Circle().fill(Color.black.opacity(0.55))
                    )
                    .overlay(
                        Circle().stroke(appState.isAlwaysOnTop ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(appState.isAlwaysOnTop ? t("窗口已置顶桌面最前(点击取消)") : t("点击将烧香窗口置顶"))
            
            // 声音/音乐开关
            Button {
                soundManager.isIncenseMuted.toggle()
                if !soundManager.isIncenseMuted && isLit {
                    soundManager.playIncenseBGM(type: incenseType)
                } else if soundManager.isIncenseMuted {
                    soundManager.stopIncenseBGM()
                }
            } label: {
                Image(systemName: soundManager.isIncenseMuted ? "speaker.slash.fill" : "music.note")
                    .font(.system(size: 11))
                    .foregroundColor(soundManager.isIncenseMuted ? .white.opacity(0.6) : .yellow)
                    .padding(6)
                    .background(
                        Circle().fill(Color.black.opacity(0.55))
                    )
                    .overlay(
                        Circle().stroke(soundManager.isIncenseMuted ? Color.white.opacity(0.2) : Color.yellow.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(soundManager.isIncenseMuted ? t("点击开启午间放松音乐") : t("点击静音"))
        }
    }
    
    // MARK: - 心愿条幅
    private var wishBanner: some View {
        Button {
            isWishSheetOpen = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "scroll.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                Text(t(currentWish))
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 香炉与三炷香
    private var censerAndSticksGraphic: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.5))
                .frame(width: 160, height: 30)
                .offset(y: 45)
            
            HStack(spacing: 14) {
                incenseStick(angle: -3.0, heightRatio: 0.95)
                incenseStick(angle: 0.0, heightRatio: 1.0)
                incenseStick(angle: 3.0, heightRatio: 0.95)
            }
            .offset(y: -30)
            
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
    
    // MARK: - 底部控制栏
    private var miniBottomBar: some View {
        VStack(spacing: 7) {
            // 香型选择胶囊
            HStack(spacing: 6) {
                ForEach(IncenseType.allCases) { type in
                    let isSelected = (incenseType == type)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            incenseType = type
                            if isLit {
                                soundManager.switchIncenseBGM(to: type)
                            }
                        }
                    } label: {
                        Text(type.localizedName)
                            .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .serif))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? type.glowColor.opacity(0.4) : Color.black.opacity(0.55))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? type.glowColor.opacity(0.9) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 燃香与计时状态
            HStack(spacing: 8) {
                Button {
                    toggleLighting()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLit ? "flame.slash.fill" : "flame.fill")
                            .font(.system(size: 10))
                        Text(isLit ? t("熄灭香火") : t("燃香静心"))
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(isLit ? .red.opacity(0.9) : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isLit ? Color.red.opacity(0.25) : Color(red: 0.85, green: 0.35, blue: 0.2))
                    )
                    .overlay(
                        Capsule().stroke(isLit ? Color.red.opacity(0.6) : Color.yellow.opacity(0.7), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                if isLit && selectedDuration.rawValue > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text(formatTime(remainingSeconds))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - 燃香逻辑
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
                                Text(t(wish))
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
