//
//  PureMuyuView.swift
//  放松
//
//  Created by apple on 2026/9/9.
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - 全局窗口与极简模式状态管理器
enum MiniWindowMode {
    case none
    case muyu
    case incense
}

final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var miniMode: MiniWindowMode = .none
    @Published var isAlwaysOnTop: Bool = true
    
    var isPureMuyuMode: Bool { miniMode == .muyu }
    var isPureIncenseMode: Bool { miniMode == .incense }
    var isAnyMiniMode: Bool { miniMode != .none }
    
    private var previousFrame: NSRect? = nil
    
    func enterPureMuyuMode() {
        #if os(macOS)
        resizeWindowForMiniMode(width: 320, height: 380)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            miniMode = .muyu
        }
    }
    
    func enterPureIncenseMode() {
        #if os(macOS)
        resizeWindowForMiniMode(width: 320, height: 400)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            miniMode = .incense
        }
    }
    
    func exitMiniMode() {
        #if os(macOS)
        restoreWindowFromMiniMode()
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            miniMode = .none
        }
    }
    
    func exitPureMuyuMode() { exitMiniMode() }
    func exitPureIncenseMode() { exitMiniMode() }
    
    #if os(macOS)
    private var targetWindow: NSWindow? {
        if let key = NSApplication.shared.keyWindow, key.canBecomeMain && !key.className.contains("Popover") && !key.className.contains("Menu") && !key.className.contains("Panel") {
            return key
        }
        if let main = NSApplication.shared.mainWindow, !main.className.contains("Popover") && !main.className.contains("Menu") {
            return main
        }
        return NSApplication.shared.windows.first(where: {
            $0.canBecomeMain && $0.isVisible && !($0 is NSPanel) && !$0.className.contains("Popover") && !$0.className.contains("Menu")
        })
    }
    
    private func resizeWindowForMiniMode(width: CGFloat, height: CGFloat) {
        guard let window = self.targetWindow else { return }
        
        if self.previousFrame == nil && window.frame.width >= 600 && window.frame.height >= 400 {
            self.previousFrame = window.frame
        }
        
        let oldOrigin = window.frame.origin
        let oldHeight = window.frame.size.height
        let newY = oldOrigin.y + (oldHeight - height)
        let newFrame = NSRect(x: oldOrigin.x, y: newY, width: width, height: height)
        
        window.setFrame(newFrame, display: true, animate: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = self.isAlwaysOnTop ? .floating : .normal
    }
    
    private func restoreWindowFromMiniMode() {
        guard let window = self.targetWindow else { return }
        
        let defaultW: CGFloat = 969
        let defaultH: CGFloat = 652
        
        // 恢复窗口 frame
        var targetFrame: NSRect
        if let prev = self.previousFrame, prev.width >= 700 && prev.height >= 400 && prev.width < 2500 && prev.height < 1800 {
            targetFrame = prev
        } else {
            let oldOrigin = window.frame.origin
            let oldHeight = window.frame.size.height
            let newY = oldOrigin.y + (oldHeight - defaultH)
            targetFrame = NSRect(x: oldOrigin.x, y: newY, width: defaultW, height: defaultH)
        }
        
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if targetFrame.maxX > visible.maxX { targetFrame.origin.x = visible.maxX - targetFrame.width }
            if targetFrame.minX < visible.minX { targetFrame.origin.x = visible.minX }
            if targetFrame.maxY > visible.maxY { targetFrame.origin.y = visible.maxY - targetFrame.height }
            if targetFrame.minY < visible.minY { targetFrame.origin.y = visible.minY }
        }
        
        window.setFrame(targetFrame, display: true, animate: false)
        
        // 恢复窗口材质与层级
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.level = .normal
        
        self.previousFrame = nil
    }
    
    func setAlwaysOnTop(_ onTop: Bool) {
        self.isAlwaysOnTop = onTop
        if let window = self.targetWindow {
            window.level = onTop ? .floating : .normal
        }
    }
    #endif
    
    private init() {}
}

// MARK: - 极简纯净木鱼视图 (隐藏所有软件页面，只保留木鱼和敲击动画)
struct PureMuyuView: View {
    @ObservedObject var appState = AppStateManager.shared
    @ObservedObject var themeManager = AppThemeManager.shared
    @ObservedObject var soundManager = SoundManager.shared
    
    // 木鱼设置与状态
    @AppStorage("muyu_total_count") private var totalMerit: Int = 0
    @AppStorage("muyu_today_count") private var todayMerit: Int = 0
    @AppStorage("muyu_last_date") private var lastDateString: String = ""
    
    @State private var material: MuyuMaterial = .redSandalwood
    @State private var tapCount: Int = 0
    @State private var isAutoTapping: Bool = false
    @State private var autoTapInterval: Double = 1.0
    @State private var autoTapTimer: Timer? = nil
    
    // 敲击、木鱼槌与上方数字晃动动效 (棍尾固定，棍头大幅度上下挥击敲打)
    @State private var malletAngle: Double = -38.0 // 待命状态：棍头高高扬起
    @State private var scale: CGFloat = 1.0
    @State private var muyuYOffset: CGFloat = 0.0 // 受击下震
    @State private var rippleScale: CGFloat = 0.8
    @State private var rippleOpacity: Double = 0.0
    
    // 卡通木鱼吐泡泡粒子
    @State private var bubbles: [MuyuBubble] = []
    
    // 木鱼上方 "+数字" 专用晃动动效
    @State private var numberScale: CGFloat = 1.0
    @State private var numberWobble: Double = 0.0
    @State private var numberYOffset: CGFloat = 0.0
    
    @State private var isHoveringControl: Bool = false
    
    var body: some View {
        ZStack {
            // 完全透明背景 (悬浮于桌面)
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // 顶部极简快捷控制栏 (返回完整界面、置顶、声音、今日功德)
                miniTopBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                
                Spacer(minLength: 4)
                
                // 核心木鱼与敲击动画区域
                ZStack {
                    // 敲击光波扩散
                    Circle()
                        .stroke(material.highlightColor.opacity(rippleOpacity), lineWidth: 2.5)
                        .scaleEffect(rippleScale)
                        .frame(width: 180, height: 180)
                    
                    // 卡通木鱼吐出的泡泡
                    if material == .cartoonMuyu {
                        ForEach(bubbles) { bubble in
                            FishBubbleView(size: bubble.size, hue: bubble.hue)
                                .scaleEffect(bubble.scale)
                                .opacity(bubble.opacity)
                                .offset(x: bubble.x, y: bubble.y)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    // 木鱼本体
                    muyuGraphic
                        .scaleEffect(scale)
                        .offset(x: -12, y: 10 + muyuYOffset)
                        .onTapGesture {
                            tapMuyu()
                        }
                    
                    // 水平木鱼棍 (棍尾固定于右侧，棍头上下大幅度敲击木鱼)
                    malletGraphic
                        .offset(x: 22, y: -40)
                        .allowsHitTesting(false)
                    
                    // 木鱼上方祝词与数字跳跃晃动 (带深色阴影适配任何桌面壁纸)
                    Text("\(material.blessingPrefix)+\(tapCount)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.85), radius: 4, x: 0, y: 2)
                        .shadow(color: themeManager.glowColor, radius: 10, x: 0, y: 0)
                        .scaleEffect(numberScale)
                        .rotationEffect(.degrees(numberWobble))
                        .offset(x: -12, y: -74 + numberYOffset)
                        .allowsHitTesting(false)
                }
                .frame(height: 190)
                
                Spacer(minLength: 4)
                
                // 底部材质切换与自动敲击控制
                miniBottomBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 320, height: 380)
        .background(Color.clear)
        .onAppear {
            checkTodayReset()
            tapCount = todayMerit
        }
        .onDisappear {
            stopAutoTap()
        }
        // 支持按空格键直接敲木鱼
        .background(
            Button("") {
                tapMuyu()
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
        )
    }
    
    // MARK: - 顶部极简控制栏
    private var miniTopBar: some View {
        HStack {
            // 退出极简模式 (返回主界面)
            Button {
                appState.exitPureMuyuMode()
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
            
            // 今日功德小胶囊
            HStack(spacing: 3) {
                Text(t("功德"))
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(.white.opacity(0.75))
                Text("\(todayMerit)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
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
            .help(appState.isAlwaysOnTop ? t("窗口已置顶桌面最前(点击取消)") : t("点击将木鱼窗口置顶"))
            
            // 声音开关
            Button {
                soundManager.isMuyuMuted.toggle()
            } label: {
                Image(systemName: soundManager.isMuyuMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(soundManager.isMuyuMuted ? .white.opacity(0.6) : .yellow)
                    .padding(6)
                    .background(
                        Circle().fill(Color.black.opacity(0.55))
                    )
                    .overlay(
                        Circle().stroke(soundManager.isMuyuMuted ? Color.white.opacity(0.2) : Color.yellow.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(soundManager.isMuyuMuted ? t("点击开启声音") : t("点击静音"))
        }
    }
    
    // MARK: - 木鱼图形
    private var muyuGraphic: some View {
        ZStack {
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
            
            if material == .cartoonMuyu {
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
                ZStack {
                    MuyuAuthenticShape()
                        .fill(
                            LinearGradient(
                                colors: material.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 7)
                    
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
    
    // MARK: - 底部材质与自动敲击控制
    private var miniBottomBar: some View {
        VStack(spacing: 8) {
            // 材质胶囊切换
            HStack(spacing: 6) {
                ForEach(MuyuMaterial.allCases) { mat in
                    let isSelected = (material == mat)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            material = mat
                        }
                    } label: {
                        Text(mat.localizedName)
                            .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .serif))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? mat.gradientColors[0] : Color.black.opacity(0.55))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? mat.highlightColor.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 自动敲击切换
            HStack(spacing: 8) {
                Button {
                    toggleAutoTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoTapping ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(isAutoTapping ? t("停止自动") : t("自动敲击"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isAutoTapping ? .yellow : .white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isAutoTapping ? Color.yellow.opacity(0.25) : Color.black.opacity(0.55))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isAutoTapping ? Color.yellow.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                if isAutoTapping {
                    HStack(spacing: 2) {
                        Slider(value: $autoTapInterval, in: 0.4...2.0, step: 0.1)
                            .frame(width: 50)
                        Text(String(format: "%.1fs", autoTapInterval))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                    }
                }
            }
        }
    }
    
    // MARK: - 敲击动作逻辑 (棍尾固定，棍头大幅度上下挥击敲打)
    private func tapMuyu() {
        soundManager.playMuyuSound(material: material)
        
        totalMerit += 1
        todayMerit += 1
        tapCount += 1
        
        // 1. 卡通木鱼吐泡泡动画 (从鱼嘴冒出)
        emitCartoonBubbles()
        
        // 2. 水平木鱼棍敲打动画 (棍尾固定不动，棍头大幅度向下猛击木鱼背部: -38° -> +18°)
        withAnimation(.easeIn(duration: 0.06)) {
            malletAngle = 18.0
        }
        
        // 3. 上方数字跳动晃动
        withAnimation(.spring(response: 0.14, dampingFraction: 0.35, blendDuration: 0)) {
            numberScale = 1.35
            numberWobble = Double.random(in: -10...10)
            numberYOffset = -6.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.07)) {
                scale = 0.86
                muyuYOffset = 6.0
                rippleScale = 0.8
                rippleOpacity = 0.85
            }
            
            // 4. 木鱼棍棍头强力反弹扬起，复位至上方待命高角度 (-38°)
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
            let targetX = 78 + CGFloat.random(in: -5...35)
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
}
