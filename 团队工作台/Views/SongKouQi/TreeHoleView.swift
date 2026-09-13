//
//  TreeHoleView.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import SwiftUI

struct TreeHoleView: View {
    @State private var textInput: String = ""
    @State private var selectedMood: TreeHoleMood = .tired
    @State private var selectedTreeStyle: TreeHoleStyle = .ancientOak
    @State private var secrets: [TreeHoleSecret] = []
    
    // 心情打卡统计管理器
    @ObservedObject var statsManager = TreeHoleMoodStatsManager.shared
    @ObservedObject var themeManager = AppThemeManager.shared
    
    // 随机心灵鸡汤
    @State private var currentSoulSoup: String = TreeHoleSoulSoup.randomQuote()
    
    // 动效状态
    @State private var isDepositing: Bool = false
    @State private var isDissolving: Bool = false
    @State private var dissolveLeaves: [DissolveLeaf] = []
    
    // 点击小方块产生的心情粒子特效
    @State private var lastClickedMood: TreeHoleQuickMood? = nil
    @State private var moodParticles: [MoodFlyParticle] = []
    @State private var clickedButtonScale: [String: CGFloat] = [:]
    
    // 弹窗状态
    @State private var activeWarmthType: WarmthFeedbackType? = nil
    @State private var activeWarmthQuote: String = ""
    @State private var isWarmthPresented: Bool = false
    @State private var isArchiveSheetOpen: Bool = false
    @State private var isStatsSheetOpen: Bool = false
    @State private var isPlanetCosmosOpen: Bool = false
    
    var body: some View {
        ZStack {
            // 背景深邃渐变（跟随全局主题）
            LinearGradient(
                colors: themeManager.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 森林微光与树影背景 (随所选树洞图案呼应)
            ForestGlowBackground(themeColor: selectedTreeStyle.themeColor)
                .opacity(0.35)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 顶部标题栏与快捷入口（统计、心事年轮）
                headerBar
                
                // 核心工作区：左侧（古树神秘树洞主框 + 正下方心情框），右侧（写心事信笺与解压交互）
                HStack(alignment: .top, spacing: 14) {
                    // 左侧：古树神秘树洞主框 + 正下方当下心情框
                    VStack(spacing: 10) {
                        treeVisualSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        quickMoodSection
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 右侧：写心事信笺与操作按钮
                    letterPadSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)
            
            // 随风消散的落叶粒子特效
            if isDissolving {
                ForEach(dissolveLeaves) { leaf in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: leaf.size))
                        .foregroundColor(leaf.color)
                        .offset(x: leaf.x, y: leaf.y)
                        .rotationEffect(.degrees(leaf.rotation))
                        .opacity(leaf.opacity)
                }
            }
        }
        .sheet(isPresented: $isWarmthPresented) {
            if let warmth = activeWarmthType {
                TreeWarmthSheet(warmthType: warmth, quote: activeWarmthQuote) {
                    isWarmthPresented = false
                }
            }
        }
        .sheet(isPresented: $isArchiveSheetOpen) {
            TreeHoleArchiveSheet(statsManager: statsManager)
        }
        .sheet(isPresented: $isStatsSheetOpen) {
            TreeHoleMoodStatsSheet(statsManager: statsManager)
        }
        .sheet(isPresented: $isPlanetCosmosOpen) {
            TreeHolePlanetCosmosSheet(statsManager: statsManager)
        }
    }
    
    // MARK: - 顶部标题栏
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(t("古树秘境・树洞"))
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
                    
                    Text(t("・ 温暖倾听所"))
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                
                // 随机显示心灵鸡汤 (点击可刷新换一句)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentSoulSoup = TreeHoleSoulSoup.randomQuote()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor)
                        Text(currentSoulSoup.localized)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(themeManager.textPrimary)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 单机版隐私安全提示
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.accentColor.opacity(0.8))
                    Text(t("• 单机版，数据仅保存在您的设备中"))
                        .font(.system(size: 11.5, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
                
                // 心事年轮历史按钮
                Button {
                    isArchiveSheetOpen = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.subheadline)
                        Text(t("心事年轮") + " (\(statsManager.totalSecretsCount))")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                    }
                    .foregroundColor(themeManager.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.secondaryCardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }
    
    // MARK: - 左侧：古树神秘树洞主框 (尺寸加大，支持切换 4 种树洞图案与进入树洞星球)
    private var treeVisualSection: some View {
        VStack(spacing: 8) {
            // 1. 顶部栏：树洞样式切换选择器 + 树洞星球入口
            HStack {
                Menu {
                    ForEach(TreeHoleStyle.allCases) { style in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTreeStyle = style
                            }
                        } label: {
                            HStack {
                                Image(systemName: style.icon)
                                Text("\(style.localizedName) · \(style.description)")
                                if selectedTreeStyle == style {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedTreeStyle.icon)
                            .font(.caption2)
                            .foregroundColor(selectedTreeStyle.themeColor)
                        Text(selectedTreeStyle.localizedName)
                            .font(.system(size: 11.5, weight: .semibold, design: .serif))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedTreeStyle.themeColor.opacity(0.4), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 树洞星球专属入口胶囊按钮
                Button {
                    isPlanetCosmosOpen = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(t("树洞星球"))
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 0.8)
                    )
                    .shadow(color: Color.yellow.opacity(0.3), radius: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // 2. 调大尺寸的古树与神秘树洞图形 (可直接点击树洞穿越进入树洞星球)
            ZStack {
                // 古树根底阴影 (尺寸加大)
                Ellipse()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 230, height: 36)
                    .offset(y: 95)
                
                // 树干与树冠图形 (尺寸从 200x180 调大到 250x215)
                TreeTrunkHollowShape(style: selectedTreeStyle)
                    .frame(width: 250, height: 215)
                
                // 树洞中心幽邃萤火微光 (点击可直接进入树洞星球)
                treeHoleGlowLight
                    .onTapGesture {
                        isPlanetCosmosOpen = true
                    }
                
                // 投入树洞时的飘入微光动画
                if isDepositing {
                    Image(systemName: "scroll.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow, radius: 8)
                        .offset(x: 0, y: 12)
                        .scaleEffect(0.6)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 点击心情小方块时产生的心情粒子飘入树洞动画 (精准投送入树洞中心)
                ForEach(moodParticles) { p in
                    Text(p.emoji)
                        .font(.system(size: p.size))
                        .shadow(color: p.color.opacity(0.8), radius: 6)
                        .offset(x: p.x, y: p.y)
                        .scaleEffect(p.scale)
                        .opacity(p.opacity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedTreeStyle.themeColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 古树图片框框正下方：当下心情小方块选项栏（宽度缩小一半，分两排紧凑排列）
    private var quickMoodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Text("🌱")
                        .font(.system(size: 11))
                    Text(t("当下心情"))
                        .font(.system(size: 11.5, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.textSecondary)
                }
                
                Spacer()
                
                Button {
                    isStatsSheetOpen = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.caption2)
                        Text(t("情绪统计") + " (\(statsManager.totalClicks))")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(themeManager.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // 12 个心情小方块分 2 排紧凑展示（每排 6 个，宽度缩小一半）
            VStack(spacing: 5) {
                let allMoods = TreeHoleQuickMood.allCases
                let row1 = Array(allMoods.prefix(6))
                let row2 = Array(allMoods.suffix(6))
                
                HStack(spacing: 5) {
                    ForEach(row1) { mood in
                        compactMoodSquareButton(mood: mood)
                    }
                }
                
                HStack(spacing: 5) {
                    ForEach(row2) { mood in
                        compactMoodSquareButton(mood: mood)
                    }
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedTreeStyle.themeColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 单排小巧心情方块组件 (尺寸小巧、精致紧凑)
    private func compactMoodSquareButton(mood: TreeHoleQuickMood) -> some View {
        let count = statsManager.count(for: mood)
        let scale = clickedButtonScale[mood.rawValue] ?? 1.0
        
        return Button {
            handleMoodClick(mood: mood)
        } label: {
            VStack(spacing: 1) {
                // 顶部小 Emoji
                Text(mood.emoji)
                    .font(.system(size: 11))
                
                // 心情文字
                Text(mood.localizedName)
                    .font(.system(size: 9.5, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // 次数小标签 (有点击时高亮)
                Text("\(count)")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundColor(count > 0 ? Color.white : Color.white.opacity(0.45))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 0.5)
                    .background(count > 0 ? Color.black.opacity(0.35) : Color.clear)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [
                                mood.color.opacity(0.88),
                                mood.color.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: mood.color.opacity(count > 0 ? 0.3 : 0.08), radius: 2, x: 0, y: 1)
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 点击心情小方块逻辑 (统计+1、Q弹动效、粒子飞入)
    private func handleMoodClick(mood: TreeHoleQuickMood) {
        // 1. 记录统计数据
        statsManager.recordClick(for: mood)
        lastClickedMood = mood
        
        // 2. 按钮 Q 弹缩放动画
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            clickedButtonScale[mood.rawValue] = 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                clickedButtonScale[mood.rawValue] = 1.0
            }
        }
        
        // 3. 产生情绪光粒飞入树洞动画
        triggerMoodFlyParticle(mood: mood)
    }
    
    private func triggerMoodFlyParticle(mood: TreeHoleQuickMood) {
        let particleId = UUID()
        let initialX = CGFloat.random(in: -25...25)
        let newParticle = MoodFlyParticle(
            id: particleId,
            emoji: mood.emoji,
            color: mood.color,
            x: initialX,
            y: 85,
            size: 20,
            scale: 1.1,
            opacity: 0.95
        )
        moodParticles.append(newParticle)
        
        withAnimation(.easeOut(duration: 0.65)) {
            if let idx = moodParticles.firstIndex(where: { $0.id == particleId }) {
                moodParticles[idx].x = 0
                moodParticles[idx].y = 12 // 精准对准树洞中心
                moodParticles[idx].scale = 0.3
                moodParticles[idx].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            moodParticles.removeAll(where: { $0.id == particleId })
        }
    }
    
    private var treeHoleGlowLight: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.7 + 0.3 * sin(time * 2.0)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedTreeStyle.glowColors[0].opacity(0.45 * pulse),
                            selectedTreeStyle.glowColors[1].opacity(0.18 * pulse),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .offset(x: 1, y: 10)
        }
    }
    
    // MARK: - 右侧：倾诉信笺与解压按钮
    private var letterPadSection: some View {
        VStack(spacing: 12) {
            // 心情标签选择
            moodTagSelector
            
            // 心事信笺输入框
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.16).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                if textInput.isEmpty {
                    Text(t("在这里写下你的烦恼、委屈或不能对人说的秘密..."))
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(14)
                }
                
                TextEditor(text: $textInput)
                    .font(.system(size: 13, design: .serif))
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(4)
                    .padding(10)
            }
            .frame(maxHeight: .infinity)
            
            // 底部两大解压仪式操作按钮
            HStack(spacing: 14) {
                // 1. 随风消散
                Button {
                    dissolveTrouble()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                        Text(t("随风消散"))
                            .font(.system(size: 13, weight: .medium, design: .serif))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.09))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                // 2. 埋入树洞（随机获得“抱抱/摸摸头/我懂你/静静倾听”）
                Button {
                    depositSecret()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text(t("埋入树洞・获取温暖反馈"))
                            .font(.system(size: 13, weight: .bold, design: .serif))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.accentColor,
                                themeManager.accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: themeManager.glowColor, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDepositing)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 心情标签选择器
    private var moodTagSelector: some View {
        HStack(spacing: 8) {
            ForEach(TreeHoleMood.allCases) { mood in
                Button {
                    selectedMood = mood
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mood.icon)
                            .font(.caption2)
                        Text(mood.localizedName)
                            .font(.system(size: 11, design: .serif))
                    }
                    .foregroundColor(selectedMood == mood ? .white : .white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(selectedMood == mood ? mood.color.opacity(0.45) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(selectedMood == mood ? mood.color : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 随风消散动画
    private func dissolveTrouble() {
        guard !textInput.isEmpty else { return }
        
        dissolveLeaves = (0..<18).map { _ in
            DissolveLeaf(
                id: UUID(),
                x: CGFloat.random(in: 100...350),
                y: CGFloat.random(in: 150...350),
                size: CGFloat.random(in: 12...22),
                color: selectedMood.color.opacity(Double.random(in: 0.6...0.9)),
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
        }
        
        isDissolving = true
        withAnimation(.easeOut(duration: 0.8)) {
            textInput = ""
            for i in 0..<dissolveLeaves.count {
                dissolveLeaves[i].x += CGFloat.random(in: 60...180)
                dissolveLeaves[i].y -= CGFloat.random(in: 80...220)
                dissolveLeaves[i].rotation += Double.random(in: 90...360)
                dissolveLeaves[i].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            isDissolving = false
            dissolveLeaves.removeAll()
        }
    }
    
    // MARK: - 埋入树洞与随机反馈
    private func depositSecret() {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isDepositing = true
        
        let feedback = TreeHoleEcho.randomFeedback()
        activeWarmthType = feedback.warmth
        activeWarmthQuote = feedback.quote
        
        let newSecret = TreeHoleSecret(
            id: UUID(),
            content: textInput,
            mood: selectedMood,
            date: Date(),
            responseQuote: feedback.quote,
            warmthType: feedback.warmth
        )
        
        withAnimation(.easeInOut(duration: 0.4)) {
            statsManager.addSecret(newSecret)
            textInput = ""
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isDepositing = false
            isWarmthPresented = true
        }
    }
}

// MARK: - 心情粒子模型
struct MoodFlyParticle: Identifiable {
    let id: UUID
    let emoji: String
    let color: Color
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var scale: CGFloat
    var opacity: Double
}

// MARK: - 落叶飘散特效粒子模型
struct DissolveLeaf: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var opacity: Double
}

// MARK: - 情绪统计详情展示弹窗 (直观图表与频率分析)
struct TreeHoleMoodStatsSheet: View {
    @ObservedObject var statsManager: TreeHoleMoodStatsManager
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingResetConfirm: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 弹窗顶部栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.yellow)
                    Text(t("情绪晴雨表・心情统计"))
                        .font(.system(size: 17, weight: .bold, design: .serif))
                }
                Spacer()
                Button(t("完成")) {
                    dismiss()
                }
                .font(.system(size: 13, weight: .medium))
            }
            
            // 顶部核心数据概览 (总记录数, 今日记录, 主导情绪)
            HStack(spacing: 12) {
                statsMetricCard(
                    title: t("累计记录"),
                    value: "\(statsManager.totalClicks) " + t("次"),
                    icon: "heart.text.square.fill",
                    color: Color(red: 0.35, green: 0.75, blue: 0.95)
                )
                
                statsMetricCard(
                    title: t("当前主导心情"),
                    value: statsManager.dominantMood?.localizedName ?? t("暂无记录"),
                    icon: "sparkles",
                    color: statsManager.dominantMood?.color ?? .yellow,
                    prefixEmoji: statsManager.dominantMood?.emoji
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // 心情点击次数柱状统计图表 (按次数降序)
            ScrollView {
                VStack(spacing: 10) {
                    let total = max(1, statsManager.totalClicks)
                    let sortedMoods = TreeHoleQuickMood.allCases.sorted {
                        statsManager.count(for: $0) > statsManager.count(for: $1)
                    }
                    
                    ForEach(sortedMoods) { mood in
                        let count = statsManager.count(for: mood)
                        let percentage = Double(count) / Double(total)
                        
                        HStack(spacing: 10) {
                            // Mood Emoji + 标题
                            HStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.system(size: 14))
                                Text(mood.localizedName)
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            .frame(width: 72, alignment: .leading)
                            
                            // 进度条 (按对应心情颜色填充)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [mood.color, mood.color.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(count > 0 ? 8 : 0, geo.size.width * CGFloat(percentage)))
                                }
                            }
                            .frame(height: 14)
                            
                            // 次数与占比
                            HStack(spacing: 4) {
                                Text("\(count)" + t("次"))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(count > 0 ? mood.color : .secondary)
                                Text("(\(Int(percentage * 100))%)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 68, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(count > 0 ? mood.color.opacity(0.08) : Color.white.opacity(0.02))
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 220)
            
            // 底部操作与重置
            HStack {
                Button(role: .destructive) {
                    isShowingResetConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text(t("清空统计数据"))
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(t("每次点击都代表一次真实的情绪自我觉察 🌱"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(22)
        .frame(width: 450, height: 420)
        .alert(t("确定清空所有心情统计数据？"), isPresented: $isShowingResetConfirm) {
            Button(t("清空"), role: .destructive) {
                statsManager.resetStats()
            }
            Button(t("取消"), role: .cancel) {}
        } message: {
            Text(t("清空后所有心情的点击次数将重新从 0 开始计算。"))
        }
    }
    
    private func statsMetricCard(title: String, value: String, icon: String, color: Color, prefixEmoji: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                if let emoji = prefixEmoji {
                    Text(emoji)
                        .font(.system(size: 16))
                }
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - 4 种形态各异的树木与树洞图形绘制 (包含参考图经典云朵树款)
struct TreeTrunkHollowShape: View {
    let style: TreeHoleStyle
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            switch style {
            case .ancientOak:
                // 款式 1：完全复刻参考图【经典三叶云朵古树 + 胶囊直立木干 + 悬浮嫩叶】
                drawAncientOakReferenceStyle(context: context, w: w, h: h)
                
            case .moonlitWillow:
                // 款式 2：【月夜灵树・月牙流线伞冠 + 夜光垂藤 + 修长灵木】
                drawMoonlitWillowStyle(context: context, w: w, h: h)
                
            case .goldenGinkgo:
                // 款式 3：【金秋银杏・三层宝塔扇形叠冠 + 苍劲粗干 + 银杏落叶】
                drawGoldenGinkgoStyle(context: context, w: w, h: h)
                
            case .sakuraDream:
                // 款式 4：【绯樱祈愿・双生爱心蓬松花簇 + 柔粉木干 + 浪漫落英】
                drawSakuraDreamStyle(context: context, w: w, h: h)
            }
        }
    }
    
    // MARK: - 款式 1：参考图形状 (三叶圆润连体云朵树冠 + 直立胶囊木干 + 垂直大树洞 + 悬浮嫩叶)
    private func drawAncientOakReferenceStyle(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        // 1. 树冠底层阴影与浅灰外轮廓 (参考图特征)
        let outerLeft = CGRect(x: w * 0.05, y: h * 0.11, width: w * 0.40, height: h * 0.38)
        let outerRight = CGRect(x: w * 0.55, y: h * 0.11, width: w * 0.40, height: h * 0.38)
        let outerTop = CGRect(x: w * 0.28, y: h * 0.00, width: w * 0.44, height: h * 0.44)
        
        for r in [outerLeft, outerRight, outerTop] {
            context.fill(
                Path(ellipseIn: r),
                with: .color(Color(red: 0.50, green: 0.60, blue: 0.52).opacity(0.45))
            )
        }
        
        // 2. 树冠主绿叶群 (连体饱满三球云朵，温润浅莫兰迪绿)
        let mainLeft = CGRect(x: w * 0.07, y: h * 0.12, width: w * 0.37, height: h * 0.35)
        let mainRight = CGRect(x: w * 0.56, y: h * 0.12, width: w * 0.37, height: h * 0.35)
        let mainTop = CGRect(x: w * 0.30, y: h * 0.02, width: w * 0.40, height: h * 0.40)
        
        for r in [mainLeft, mainRight, mainTop] {
            context.fill(
                Path(ellipseIn: r),
                with: .linearGradient(
                    Gradient(colors: style.canopyColors),
                    startPoint: CGPoint(x: w * 0.5, y: 0),
                    endPoint: CGPoint(x: w * 0.5, y: h * 0.45)
                )
            )
        }
        
        // 树冠顶部浅色高光圆心
        let innerCenter = CGRect(x: w * 0.26, y: h * 0.08, width: w * 0.48, height: h * 0.30)
        context.fill(
            Path(ellipseIn: innerCenter),
            with: .color(Color.white.opacity(0.12))
        )
        
        // 3. 直立圆角胶囊树干 (顶部半圆平滑倒角，温润实木色)
        var trunk = Path()
        let trunkRect = CGRect(x: w * 0.41, y: h * 0.46, width: w * 0.18, height: h * 0.50)
        trunk.addRoundedRect(in: trunkRect, cornerSize: CGSize(width: w * 0.09, height: w * 0.09))
        
        context.fill(
            trunk,
            with: .linearGradient(
                Gradient(colors: style.trunkColors),
                startPoint: CGPoint(x: w * 0.41, y: h * 0.46),
                endPoint: CGPoint(x: w * 0.59, y: h * 0.96)
            )
        )
        
        // 树干两侧细长纵向木纹线 (参考图细节)
        var grainLeft = Path()
        grainLeft.move(to: CGPoint(x: w * 0.45, y: h * 0.52))
        grainLeft.addLine(to: CGPoint(x: w * 0.45, y: h * 0.93))
        context.stroke(grainLeft, with: .color(Color.black.opacity(0.15)), lineWidth: 1.5)
        
        var grainRight = Path()
        grainRight.move(to: CGPoint(x: w * 0.55, y: h * 0.52))
        grainRight.addLine(to: CGPoint(x: w * 0.55, y: h * 0.93))
        context.stroke(grainRight, with: .color(Color.black.opacity(0.15)), lineWidth: 1.5)
        
        // 4. 正中央垂直大椭圆树洞 (外深木厚唇 + 内全黑深膛)
        let holeOuter = CGRect(x: w * 0.43, y: h * 0.54, width: w * 0.14, height: h * 0.24)
        context.fill(Path(ellipseIn: holeOuter), with: .color(Color(red: 0.28, green: 0.18, blue: 0.12)))
        
        let holeInner = CGRect(x: w * 0.445, y: h * 0.56, width: w * 0.11, height: h * 0.20)
        context.fill(Path(ellipseIn: holeInner), with: .color(Color.black))
        
        // 5. 树干两侧悬浮的小嫩叶 (参考图左偏上、右偏下各一片)
        let leafLeft = CGRect(x: w * 0.35, y: h * 0.57, width: 14, height: 7)
        let leafLeftPath = Path(ellipseIn: leafLeft)
        context.fill(leafLeftPath, with: .color(Color(red: 0.54, green: 0.65, blue: 0.56)))
        
        let leafRight = CGRect(x: w * 0.58, y: h * 0.68, width: 13, height: 6.5)
        let leafRightPath = Path(ellipseIn: leafRight)
        context.fill(leafRightPath, with: .color(Color(red: 0.54, green: 0.65, blue: 0.56)))
    }
    
    // MARK: - 款式 2：月夜灵树 (月牙流线伞冠 + 夜光垂藤 + 修长灵木)
    private func drawMoonlitWillowStyle(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        // 月夜流线拱顶伞冠
        var canopy = Path()
        canopy.move(to: CGPoint(x: w * 0.10, y: h * 0.42))
        canopy.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.04), control1: CGPoint(x: w * 0.12, y: h * 0.10), control2: CGPoint(x: w * 0.30, y: h * 0.04))
        canopy.addCurve(to: CGPoint(x: w * 0.90, y: h * 0.42), control1: CGPoint(x: w * 0.70, y: h * 0.04), control2: CGPoint(x: w * 0.88, y: h * 0.10))
        canopy.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.36), control: CGPoint(x: w * 0.70, y: h * 0.34))
        canopy.addQuadCurve(to: CGPoint(x: w * 0.10, y: h * 0.42), control: CGPoint(x: w * 0.30, y: h * 0.34))
        canopy.closeSubpath()
        
        context.fill(
            canopy,
            with: .linearGradient(
                Gradient(colors: style.canopyColors),
                startPoint: CGPoint(x: w * 0.5, y: 0),
                endPoint: CGPoint(x: w * 0.5, y: h * 0.42)
            )
        )
        
        // 夜光垂藤 (4 条优美垂丝 + 星点)
        for x in [w * 0.22, w * 0.36, w * 0.64, w * 0.78] {
            var vine = Path()
            vine.move(to: CGPoint(x: x, y: h * 0.36))
            vine.addQuadCurve(to: CGPoint(x: x + 4, y: h * 0.55), control: CGPoint(x: x + 8, y: h * 0.46))
            context.stroke(vine, with: .color(style.glowColors[0].opacity(0.6)), lineWidth: 1.2)
            
            // 垂藤末梢发光星珠
            context.fill(Path(ellipseIn: CGRect(x: x + 2, y: h * 0.54, width: 4.5, height: 4.5)), with: .color(Color.white.opacity(0.85)))
        }
        
        // 修长灵木树干 (优雅微收腰)
        var trunk = Path()
        trunk.move(to: CGPoint(x: w * 0.42, y: h * 0.36))
        trunk.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.95), control: CGPoint(x: w * 0.44, y: h * 0.65))
        trunk.addLine(to: CGPoint(x: w * 0.62, y: h * 0.95))
        trunk.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.36), control: CGPoint(x: w * 0.56, y: h * 0.65))
        trunk.closeSubpath()
        
        context.fill(
            trunk,
            with: .linearGradient(
                Gradient(colors: style.trunkColors),
                startPoint: CGPoint(x: 0, y: h * 0.36),
                endPoint: CGPoint(x: 0, y: h * 0.95)
            )
        )
        
        // 水滴形发光灵木树洞
        var hole = Path()
        hole.move(to: CGPoint(x: w * 0.50, y: h * 0.52))
        hole.addCurve(to: CGPoint(x: w * 0.56, y: h * 0.68), control1: CGPoint(x: w * 0.55, y: h * 0.56), control2: CGPoint(x: w * 0.58, y: h * 0.64))
        hole.addCurve(to: CGPoint(x: w * 0.44, y: h * 0.68), control1: CGPoint(x: w * 0.52, y: h * 0.74), control2: CGPoint(x: w * 0.48, y: h * 0.74))
        hole.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.52), control1: CGPoint(x: w * 0.42, y: h * 0.64), control2: CGPoint(x: w * 0.45, y: h * 0.56))
        hole.closeSubpath()
        
        context.fill(hole, with: .color(Color.black))
        context.stroke(hole, with: .color(style.glowColors[0].opacity(0.8)), lineWidth: 1.5)
    }
    
    // MARK: - 款式 3：金秋银杏 (三层宝塔扇形叠冠 + 苍劲粗干 + 银杏落叶)
    private func drawGoldenGinkgoStyle(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        // 三层层叠扇形宝塔冠
        let layers = [
            (CGRect(x: w * 0.30, y: h * 0.04, width: w * 0.40, height: h * 0.20), style.canopyColors[0]),
            (CGRect(x: w * 0.20, y: h * 0.16, width: w * 0.60, height: h * 0.22), style.canopyColors[1]),
            (CGRect(x: w * 0.10, y: h * 0.28, width: w * 0.80, height: h * 0.24), style.canopyColors[min(2, style.canopyColors.count - 1)])
        ]
        
        for (rect, color) in layers {
            var layerPath = Path()
            layerPath.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            layerPath.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.3))
            layerPath.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.3))
            layerPath.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - 8))
            layerPath.closeSubpath()
            
            context.fill(layerPath, with: .color(color))
            context.stroke(layerPath, with: .color(Color.yellow.opacity(0.4)), lineWidth: 1)
        }
        
        // 敦厚苍劲老银杏树干
        var trunk = Path()
        trunk.move(to: CGPoint(x: w * 0.36, y: h * 0.46))
        trunk.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.96), control: CGPoint(x: w * 0.30, y: h * 0.72))
        trunk.addLine(to: CGPoint(x: w * 0.76, y: h * 0.96))
        trunk.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.46), control: CGPoint(x: w * 0.70, y: h * 0.72))
        trunk.closeSubpath()
        
        context.fill(
            trunk,
            with: .linearGradient(
                Gradient(colors: style.trunkColors),
                startPoint: CGPoint(x: w * 0.3, y: h * 0.46),
                endPoint: CGPoint(x: w * 0.7, y: h * 0.96)
            )
        )
        
        // 杏核状暖金大树洞
        let holeOuter = CGRect(x: w * 0.39, y: h * 0.56, width: w * 0.22, height: h * 0.22)
        context.fill(Path(ellipseIn: holeOuter), with: .color(style.trunkColors[min(1, style.trunkColors.count - 1)]))
        
        let holeInner = CGRect(x: w * 0.41, y: h * 0.58, width: w * 0.18, height: h * 0.18)
        context.fill(Path(ellipseIn: holeInner), with: .color(Color.black))
        
        // 漂浮的银杏金叶
        for offset in [CGPoint(x: w * 0.26, y: h * 0.62), CGPoint(x: w * 0.74, y: h * 0.58), CGPoint(x: w * 0.70, y: h * 0.76)] {
            context.fill(Path(ellipseIn: CGRect(x: offset.x, y: offset.y, width: 9, height: 6)), with: .color(Color(red: 1.0, green: 0.85, blue: 0.25)))
        }
    }
    
    // MARK: - 款式 4：绯樱祈愿 (双生爱心蓬松花簇 + 柔粉木干 + 浪漫落英)
    private func drawSakuraDreamStyle(context: GraphicsContext, w: CGFloat, h: CGFloat) {
        // 双生爱心花球树冠
        let leftHeart = CGRect(x: w * 0.15, y: h * 0.05, width: w * 0.42, height: h * 0.42)
        let rightHeart = CGRect(x: w * 0.43, y: h * 0.05, width: w * 0.42, height: h * 0.42)
        let centerBlossom = CGRect(x: w * 0.26, y: h * 0.16, width: w * 0.48, height: h * 0.32)
        
        for r in [leftHeart, rightHeart, centerBlossom] {
            context.fill(
                Path(ellipseIn: r),
                with: .linearGradient(
                    Gradient(colors: style.canopyColors),
                    startPoint: CGPoint(x: w * 0.5, y: 0),
                    endPoint: CGPoint(x: w * 0.5, y: h * 0.48)
                )
            )
        }
        
        // 柔和粉棕树干
        var trunk = Path()
        let trunkRect = CGRect(x: w * 0.40, y: h * 0.44, width: w * 0.20, height: h * 0.52)
        trunk.addRoundedRect(in: trunkRect, cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        
        context.fill(
            trunk,
            with: .linearGradient(
                Gradient(colors: style.trunkColors),
                startPoint: CGPoint(x: 0, y: h * 0.44),
                endPoint: CGPoint(x: 0, y: h * 0.96)
            )
        )
        
        // 柔粉微光椭圆树洞
        let holeOuter = CGRect(x: w * 0.42, y: h * 0.54, width: w * 0.16, height: h * 0.22)
        context.fill(Path(ellipseIn: holeOuter), with: .color(style.trunkColors[min(1, style.trunkColors.count - 1)]))
        
        let holeInner = CGRect(x: w * 0.435, y: h * 0.56, width: w * 0.13, height: h * 0.18)
        context.fill(Path(ellipseIn: holeInner), with: .color(Color.black))
        
        // 飘落樱花花瓣
        for offset in [CGPoint(x: w * 0.30, y: h * 0.58), CGPoint(x: w * 0.68, y: h * 0.65), CGPoint(x: w * 0.34, y: h * 0.78)] {
            context.fill(Path(ellipseIn: CGRect(x: offset.x, y: offset.y, width: 8, height: 7)), with: .color(Color(red: 1.0, green: 0.82, blue: 0.90)))
        }
    }
}

// MARK: - 森林微光背景
struct ForestGlowBackground: View {
    var themeColor: Color = Color.green
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let p1 = 0.5 + 0.5 * sin(time * 0.8)
            let p2 = 0.5 + 0.5 * cos(time * 0.6)
            
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.14 * p1))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: -180, y: -80)
                
                Circle()
                    .fill(themeColor.opacity(0.09 * p2))
                    .frame(width: 220, height: 220)
                    .blur(radius: 45)
                    .offset(x: 160, y: 100)
            }
        }
    }
}

// MARK: - 温暖反馈仪式弹窗 (抱抱、摸摸头、我懂你、静静倾听)
struct TreeWarmthSheet: View {
    let warmthType: WarmthFeedbackType
    let quote: String
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            // 温暖大图标
            Text(warmthType.emoji)
                .font(.system(size: 56))
                .shadow(color: warmthType.highlightColor.opacity(0.5), radius: 10)
                .padding(.top, 8)
            
            // 仪式名称
            Text(t("古树的") + "「\(warmthType.localizedName)」")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(warmthType.highlightColor)
            
            // 温暖抚慰心语
            Text(quote.localized)
                .font(.system(size: 14, design: .serif))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 16)
            
            Text(t("心事已被古树安稳收下，在此化作泥土养分，滋养新的生机。"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Button(t("心已释然・收下温暖")) {
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .tint(warmthType.highlightColor.opacity(0.85))
            .padding(.top, 4)
        }
        .padding(26)
        .frame(width: 390, height: 300)
    }
}

// MARK: - 心事年轮历史记录弹窗
struct TreeHoleArchiveSheet: View {
    @ObservedObject var statsManager: TreeHoleMoodStatsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(t("心事年轮・树洞藏心"))
                    .font(.system(size: 18, weight: .bold, design: .serif))
                Spacer()
                Button(t("关闭")) {
                    dismiss()
                }
            }
            
            if statsManager.secrets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(t("树洞空空如也，心无挂碍，万般自在"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(statsManager.secrets) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: item.mood.icon)
                                    Text(item.mood.localizedName)
                                }
                                .font(.caption2)
                                .foregroundColor(item.mood.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(item.mood.color.opacity(0.15))
                                .clipShape(Capsule())
                                
                                HStack(spacing: 3) {
                                    Text(item.warmthType.emoji)
                                    Text(item.warmthType.localizedName)
                                }
                                .font(.caption2)
                                .foregroundColor(item.warmthType.highlightColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.warmthType.highlightColor.opacity(0.15))
                                .clipShape(Capsule())
                                
                                Spacer()
                                
                                Text(item.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(item.localizedContent)
                                .font(.system(size: 13, design: .serif))
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(alignment: .top, spacing: 4) {
                                Text(t("树洞抚慰："))
                                    .font(.caption2)
                                    .foregroundColor(item.warmthType.highlightColor)
                                Text(item.localizedResponseQuote)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { indexSet in
                        statsManager.removeSecret(atOffsets: indexSet)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 440, height: 420)
    }
}

// MARK: - 🪐 树洞星球・情绪宇宙全景弹窗 (分成「心情」和「心事」两大部分，展示真实打卡与真实心事)
struct TreeHolePlanetCosmosSheet: View {
    @ObservedObject var statsManager: TreeHoleMoodStatsManager
    @Environment(\.dismiss) private var dismiss
    
    // 视图模式：心情 / 心事
    enum CosmosTab: String, CaseIterable {
        case mood = "心情"
        case secret = "心事"
        
        var localizedName: String {
            rawValue.localized
        }
    }
    
    @State private var selectedTab: CosmosTab = .mood
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedPlanetRecord: CosmosPlanetNode? = nil
    @State private var selectedSecretRecord: CosmosSecretNode? = nil
    
    var body: some View {
        ZStack {
            // 1. 深邃暗黑宇宙背景
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
            
            // 星空背景小星辰
            CosmosStarryBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. 顶部切换与关闭栏 (药丸切换器【心情 / 心事】 + 右侧关闭)
                cosmosHeaderBar
                    .padding(.top, 14)
                    .padding(.horizontal, 18)
                
                // 3. 核心星空宇宙内容区
                ZStack {
                    if selectedTab == .mood {
                        // 情绪星球宇宙星图
                        planetCosmosCanvasView
                            .transition(.opacity)
                        
                        // 点击星球时浮现的沉浸式心情详情卡片
                        if let selected = selectedPlanetRecord {
                            planetDetailCard(planet: selected)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    } else {
                        // 心事星空星云星图
                        secretCosmosCanvasView
                            .transition(.opacity)
                        
                        // 点击心事信笺时浮现的信件详情卡片
                        if let selectedSecret = selectedSecretRecord {
                            secretDetailCard(secret: selectedSecret)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 4. 底部年份切换框与唯美心语
                cosmosBottomBar
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 520, height: 680)
    }
    
    // MARK: - 顶部导航栏
    private var cosmosHeaderBar: some View {
        HStack {
            Spacer()
            
            // 药丸切换选择器【心情 / 心事】
            HStack(spacing: 0) {
                ForEach(CosmosTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = tab
                            selectedPlanetRecord = nil
                            selectedSecretRecord = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab == .mood ? "sparkles" : "envelope.heart.fill")
                                .font(.system(size: 11))
                            Text(tab.localizedName)
                                .font(.system(size: 13, weight: .bold, design: .serif))
                        }
                        .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2.5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
            
            // 右上角关闭按钮 ✕
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 情绪星球星空星图画布 (以树洞形状小椭圆到大椭圆轨迹展示)
    private var planetCosmosCanvasView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = max(550, geo.size.height)
            let centerX = w / 2
            let centerY = h / 2
            let planets = generatedPlanets(canvasWidth: w, canvasHeight: h)
            
            if planets.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42))
                        .foregroundColor(Color.yellow.opacity(0.6))
                    Text("\(selectedYear)" + t("年 尚无心情记录"))
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                    Text(t("在古树秘境下方点击「当下心情」小方块，\n每一次真实点击都会沿树洞年轮椭圆轨迹点亮属于你的情绪星球 ✨"))
                        .font(.system(size: 12.5, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.55))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // 1. 树洞年轮发光同心椭圆轨 (小椭圆到大椭圆)
                        TreeHoleCosmosOrbitRings(centerX: centerX, centerY: centerY)
                        
                        // 2. 情绪星球沿树洞椭圆螺旋轨迹连线
                        ForEach(0..<max(0, planets.count - 1), id: \.self) { idx in
                            let p1 = planets[idx]
                            let p2 = planets[idx + 1]
                            Path { path in
                                path.move(to: CGPoint(x: p1.xRatio * w, y: p1.yRatio * h))
                                path.addLine(to: CGPoint(x: p2.xRatio * w, y: p2.yRatio * h))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        p1.color.opacity(0.35),
                                        p2.color.opacity(0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 1.0, dash: [3, 4])
                            )
                        }
                        
                        // 3. 情绪星球群
                        ForEach(planets) { planet in
                            singlePlanetNodeView(planet: planet, geoWidth: w, geoHeight: h)
                        }
                    }
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlanetRecord = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 单个情绪星球节点组件 (展示真实时间与对应心情)
    private func singlePlanetNodeView(planet: CosmosPlanetNode, geoWidth: CGFloat, geoHeight: CGFloat) -> some View {
        let posX = planet.xRatio * geoWidth
        let posY = planet.yRatio * geoHeight
        let isSelected = selectedPlanetRecord?.id == planet.id
        
        return VStack(spacing: 3) {
            // 上方真实打卡时间标签 (格式：yyyy年MM月dd日 HH:mm)
            Text(planet.dateString.localized)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black, radius: 2)
            
            // 情绪星球球体 (发光渐变微球 + 表情 Emoji)
            ZStack {
                // 外层发光光晕
                Circle()
                    .fill(planet.color.opacity(isSelected ? 0.6 : 0.3))
                    .frame(width: planet.size + (isSelected ? 14 : 6), height: planet.size + (isSelected ? 14 : 6))
                    .blur(radius: isSelected ? 8 : 4)
                
                // 星球球体
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                planet.color.opacity(0.95),
                                planet.color,
                                planet.color.opacity(0.7)
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: planet.size * 0.7
                        )
                    )
                    .frame(width: planet.size, height: planet.size)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: planet.color.opacity(0.5), radius: 4, x: 0, y: 2)
                
                // 星球内部表情
                Text(planet.emoji)
                    .font(.system(size: planet.size * 0.52))
            }
            .scaleEffect(isSelected ? 1.25 : 1.0)
            
            // 下方心情名称
            Text(planet.moodName.localized)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(planet.color.opacity(0.95))
                .shadow(color: .black, radius: 2)
        }
        .position(x: posX, y: posY)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedPlanetRecord = planet
            }
        }
    }
    
    // MARK: - 点击心情星球弹出的具体心境详情卡片 (真实打卡时间与温柔提示)
    private func planetDetailCard(planet: CosmosPlanetNode) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text(planet.emoji)
                        .font(.system(size: 20))
                    Text(planet.moodName.localized)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(planet.color)
                }
                Spacer()
                Text(planet.fullTimeString.localized)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            Text(planet.gentleQuote.localized)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(planet.color.opacity(0.5), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 6)
        )
    }
    
    // MARK: - 心事星空星云星图画布 (以树洞形状小椭圆到大椭圆轨迹展示)
    private var secretCosmosCanvasView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = max(550, geo.size.height)
            let centerX = w / 2
            let centerY = h / 2
            let secrets = generatedSecrets(canvasWidth: w, canvasHeight: h)
            
            if secrets.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 42))
                        .foregroundColor(Color(red: 0.98, green: 0.65, blue: 0.75).opacity(0.7))
                    Text("\(selectedYear)" + t("年 尚无心事信笺"))
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                    Text(t("在古树右侧写下你的烦恼、秘密或未言之语，\n埋入树洞，沿树洞椭圆年轮化作星光静静守护你 💌"))
                        .font(.system(size: 12.5, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.55))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // 1. 树洞年轮发光同心椭圆轨 (小椭圆到大椭圆)
                        TreeHoleCosmosOrbitRings(centerX: centerX, centerY: centerY)
                        
                        // 2. 心事星云星轨微弱连接线 (心绪连缀)
                        ForEach(0..<max(0, secrets.count - 1), id: \.self) { idx in
                            let s1 = secrets[idx]
                            let s2 = secrets[idx + 1]
                            Path { path in
                                path.move(to: CGPoint(x: s1.xRatio * w, y: s1.yRatio * h))
                                path.addLine(to: CGPoint(x: s2.xRatio * w, y: s2.yRatio * h))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        s1.warmthType.highlightColor.opacity(0.25),
                                        s2.warmthType.highlightColor.opacity(0.25)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 1.0, dash: [3, 4])
                            )
                        }
                        
                        // 3. 心事星光信笺群
                        ForEach(secrets) { secretNode in
                            singleSecretNodeView(secret: secretNode, geoWidth: w, geoHeight: h)
                        }
                    }
                    .frame(width: w, height: h)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSecretRecord = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 单个心事信笺星球/星囊节点 (真实输入时间与心境)
    private func singleSecretNodeView(secret: CosmosSecretNode, geoWidth: CGFloat, geoHeight: CGFloat) -> some View {
        let posX = secret.xRatio * geoWidth
        let posY = secret.yRatio * geoHeight
        let isSelected = selectedSecretRecord?.id == secret.id
        
        return VStack(spacing: 3) {
            // 上方真实输入时间标签 (格式：yyyy年MM月dd日 HH:mm)
            Text(secret.dateString.localized)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black, radius: 2)
            
            // 心事发光信笺水晶体
            ZStack {
                // 外层发光光晕
                Circle()
                    .fill(secret.warmthType.highlightColor.opacity(isSelected ? 0.65 : 0.35))
                    .frame(width: secret.size + (isSelected ? 14 : 6), height: secret.size + (isSelected ? 14 : 6))
                    .blur(radius: isSelected ? 8 : 4)
                
                // 水晶信囊球体
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                secret.warmthType.highlightColor.opacity(0.95),
                                secret.moodColor.opacity(0.85),
                                Color(red: 0.15, green: 0.18, blue: 0.28)
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: secret.size * 0.75
                        )
                    )
                    .frame(width: secret.size, height: secret.size)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: secret.warmthType.highlightColor.opacity(0.5), radius: 4, x: 0, y: 2)
                
                // 内部温暖反馈 Emoji
                Text(secret.warmthType.emoji)
                    .font(.system(size: secret.size * 0.50))
            }
            .scaleEffect(isSelected ? 1.25 : 1.0)
            
            // 下方心事标签与反馈类型
            HStack(spacing: 2) {
                Text(secret.moodName.localized)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(secret.moodColor)
                Text("·")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Text(secret.warmthType.localizedName)
                    .font(.system(size: 9.5, weight: .medium, design: .serif))
                    .foregroundColor(secret.warmthType.highlightColor)
            }
            .shadow(color: .black, radius: 2)
        }
        .position(x: posX, y: posY)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedSecretRecord = secret
            }
        }
    }
    
    // MARK: - 点击心事弹出的深邃温暖信笺详情卡片 (真实输入内容与真实输入时间)
    private func secretDetailCard(secret: CosmosSecretNode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部：心境标签 + 温暖反馈胶囊 + 真实时间
            HStack {
                HStack(spacing: 5) {
                    Text(secret.moodName.localized)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundColor(secret.moodColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(secret.moodColor.opacity(0.18))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 3) {
                        Text(secret.warmthType.emoji)
                            .font(.caption2)
                        Text(secret.warmthType.localizedName)
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundColor(secret.warmthType.highlightColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(secret.warmthType.highlightColor.opacity(0.18))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Text(secret.fullTimeString.localized)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // 真实输入心事原文
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 9))
                        .foregroundColor(secret.moodColor.opacity(0.7))
                    Text(t("心事信笺"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(secret.content.localized)
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundColor(.white.opacity(0.95))
                    .lineSpacing(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // 树洞古树抚慰回音
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("🌿")
                        .font(.system(size: 10))
                    Text(t("古树回音") + " · \(secret.warmthType.localizedName)")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundColor(secret.warmthType.highlightColor)
                }
                
                Text(secret.responseQuote.localized)
                    .font(.system(size: 11.5, design: .serif))
                    .foregroundColor(secret.warmthType.highlightColor.opacity(0.95))
                    .lineSpacing(3.5)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(secret.warmthType.highlightColor.opacity(0.08))
            .cornerRadius(8)
        }
        .padding(14)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(secret.warmthType.highlightColor.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.7), radius: 14, x: 0, y: 6)
        )
    }
    
    // MARK: - 底部年份选择与真实统计心语
    private var cosmosBottomBar: some View {
        VStack(spacing: 10) {
            // 年份切换框 ◀ 2026 ▶
            HStack(spacing: 16) {
                Button {
                    selectedYear -= 1
                    selectedPlanetRecord = nil
                    selectedSecretRecord = nil
                } label: {
                    Image(systemName: "arrowtriangle.backward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Text("\(selectedYear)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Button {
                    selectedYear += 1
                    selectedPlanetRecord = nil
                    selectedSecretRecord = nil
                } label: {
                    Image(systemName: "arrowtriangle.forward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
            )
            
            // 真实统计文案
            if selectedTab == .mood {
                let count = statsManager.records.filter {
                    Calendar.current.component(.year, from: $0.timestamp) == selectedYear
                }.count
                
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(selectedYear)" + t("年 树洞共收集了"))
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(count)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.98))
                        Text(t("个心情"))
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(t("回忆交错在小宇宙中，不再逝去"))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.white.opacity(0.55))
                }
            } else {
                let count = statsManager.secrets.filter {
                    Calendar.current.component(.year, from: $0.date) == selectedYear
                }.count
                
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(selectedYear)" + t("年 树洞共守护了"))
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(count)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.98, green: 0.65, blue: 0.75))
                        Text(t("封心事"))
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(t("所有未言之语，皆化作繁星恒久安宁"))
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
    }
    
    // MARK: - 心情星球节点数据生成 (以树洞形状从小椭圆到大椭圆轨迹排布)
    private func generatedPlanets(canvasWidth: CGFloat, canvasHeight: CGFloat) -> [CosmosPlanetNode] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        
        // 过滤选定年份的心情打卡记录
        let filteredRecords = statsManager.records.filter {
            Calendar.current.component(.year, from: $0.timestamp) == selectedYear
        }
        
        let total = filteredRecords.count
        var list: [CosmosPlanetNode] = []
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2
        
        for (idx, record) in filteredRecords.enumerated() {
            let mood = TreeHoleQuickMood(rawValue: record.moodRawValue) ?? .peaceful
            let hash = abs(record.id.hashValue)
            
            // 树洞椭圆轨迹：小椭圆(rx=55, ry=76) 到大椭圆(rx=195, ry=269)
            let progress = total == 1 ? 0.0 : Double(idx) / Double(max(1, total - 1))
            let rx = 55.0 + progress * 140.0
            let ry = rx * 1.38
            
            // 沿椭圆环顺时针黄金角/螺旋角度展开
            let angle = -Double.pi / 2.0 + Double(idx) * 1.85
            let posX = centerX + rx * cos(angle)
            let posY = centerY + ry * sin(angle)
            
            list.append(
                CosmosPlanetNode(
                    id: record.id,
                    dateString: formatter.string(from: record.timestamp),
                    fullTimeString: fullFormatter.string(from: record.timestamp),
                    moodName: mood.rawValue,
                    emoji: mood.emoji,
                    color: mood.color,
                    gentleQuote: mood.gentleSuggestion,
                    xRatio: posX / canvasWidth,
                    yRatio: posY / canvasHeight,
                    size: CGFloat(28 + (hash % 6))
                )
            )
        }
        
        return list
    }
    
    // MARK: - 心事星云数据生成 (以树洞形状从小椭圆到大椭圆轨迹排布)
    private func generatedSecrets(canvasWidth: CGFloat, canvasHeight: CGFloat) -> [CosmosSecretNode] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        
        // 过滤选定年份的心事记录
        let filteredSecrets = statsManager.secrets.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
        
        let total = filteredSecrets.count
        var list: [CosmosSecretNode] = []
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2
        
        for (idx, secret) in filteredSecrets.enumerated() {
            let hash = abs(secret.id.hashValue)
            
            // 树洞椭圆轨迹：小椭圆(rx=55, ry=76) 到大椭圆(rx=195, ry=269)
            let progress = total == 1 ? 0.0 : Double(idx) / Double(max(1, total - 1))
            let rx = 55.0 + progress * 140.0
            let ry = rx * 1.38
            
            let angle = -Double.pi / 2.0 + Double(idx) * 1.85
            let posX = centerX + rx * cos(angle)
            let posY = centerY + ry * sin(angle)
            
            list.append(
                CosmosSecretNode(
                    id: secret.id,
                    dateString: formatter.string(from: secret.date),
                    fullTimeString: fullFormatter.string(from: secret.date),
                    moodName: secret.mood.rawValue,
                    moodColor: secret.mood.color,
                    warmthType: secret.warmthType,
                    content: secret.content,
                    responseQuote: secret.responseQuote,
                    xRatio: posX / canvasWidth,
                    yRatio: posY / canvasHeight,
                    size: CGFloat(34 + (hash % 6))
                )
            )
        }
        
        return list
    }
}

// MARK: - 树洞年轮发光同心椭圆背景轨 (从小椭圆到大椭圆)
struct TreeHoleCosmosOrbitRings: View {
    let centerX: CGFloat
    let centerY: CGFloat
    
    // 5 层树洞年轮同心椭圆 (从小椭圆到大椭圆：55x76 -> 195x269)
    let ringRadii: [(rx: CGFloat, ry: CGFloat)] = [
        (55, 76),
        (90, 124),
        (125, 172),
        (160, 220),
        (195, 269)
    ]
    
    var body: some View {
        ZStack {
            // 中心树洞幽邃萤火微光
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.35, green: 0.85, blue: 0.60).opacity(0.35),
                            Color(red: 0.15, green: 0.40, blue: 0.30).opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 42
                    )
                )
                .frame(width: 84, height: 84)
                .position(x: centerX, y: centerY)
            
            // 5 层树洞发光同心年轮虚线椭圆轨
            ForEach(0..<ringRadii.count, id: \.self) { i in
                let r = ringRadii[i]
                let opacity = 0.30 - Double(i) * 0.04
                
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.85, blue: 0.65).opacity(opacity),
                                Color(red: 0.98, green: 0.80, blue: 0.35).opacity(opacity * 0.8),
                                Color(red: 0.45, green: 0.70, blue: 0.98).opacity(opacity * 0.9),
                                Color(red: 0.45, green: 0.85, blue: 0.65).opacity(opacity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 1.0, dash: [4, 6])
                    )
                    .frame(width: r.rx * 2, height: r.ry * 2)
                    .position(x: centerX, y: centerY)
            }
        }
    }
}

// MARK: - 宇宙星球节点数据结构 (心情)
struct CosmosPlanetNode: Identifiable {
    let id: UUID
    let dateString: String
    let fullTimeString: String
    let moodName: String
    let emoji: String
    let color: Color
    let gentleQuote: String
    let xRatio: Double
    let yRatio: Double
    let size: CGFloat
}

// MARK: - 宇宙心事信笺节点数据结构 (心事)
struct CosmosSecretNode: Identifiable {
    let id: UUID
    let dateString: String
    let fullTimeString: String
    let moodName: String
    let moodColor: Color
    let warmthType: WarmthFeedbackType
    let content: String
    let responseQuote: String
    let xRatio: Double
    let yRatio: Double
    let size: CGFloat
}

// MARK: - 星空微光星尘背景
struct CosmosStarryBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                let w = size.width
                let h = size.height
                
                // 绘制 45 颗微光星子
                for i in 0..<45 {
                    let seed = Double(i * 137 % 1000)
                    let sx = (seed / 1000.0) * w
                    let sy = (Double(i * 293 % 1000) / 1000.0) * h
                    let starRadius = 0.8 + (Double(i % 3) * 0.6)
                    let twinkle = 0.35 + 0.65 * sin(time * 1.5 + seed)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: sx, y: sy, width: starRadius * 2, height: starRadius * 2)),
                        with: .color(Color.white.opacity(twinkle))
                    )
                }
            }
        }
    }
}
