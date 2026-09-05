//
//  LuckyWheelView.swift
//  团队工作台
//
//

import SwiftUI
import AppKit

public struct LuckyWheelView: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.colorScheme) var colorScheme
    
    // Candidates state
    @State private var candidates: [String] = []
    @State private var newCandidateText: String = ""
    @State private var batchInputText: String = ""
    @State private var showBatchInputSheet: Bool = false
    
    // Extraction Settings
    enum ExtractionMode: String, CaseIterable, Identifiable {
        case single = "单一抽取 (1人)"
        case multiple = "多项抽取 (N人)"
        var id: String { rawValue }
    }
    
    @State private var extractionMode: ExtractionMode = .single
    @State private var pickCount: Int = 2
    @State private var pickCountText: String = "2"
    @State private var allowRepeat: Bool = false
    
    // Spinning Animation State
    @State private var isSpinning: Bool = false
    @State private var rotationAngle: Double = 0.0
    @State private var selectedIndex: Int = 0
    @State private var recentResults: [String] = []
    @State private var showResultModal: Bool = false
    
    // History
    struct ExtractionHistoryRecord: Identifiable, Hashable {
        let id = UUID()
        let timestamp: Date
        let winners: [String]
        let totalCandidates: Int
    }
    @State private var historyRecords: [ExtractionHistoryRecord] = []
    
    // Feedback
    @State private var copiedFeedback: String? = nil
    
    // Palette for wheel slices
    private let sliceColors: [Color] = [
        Color(red: 0.95, green: 0.35, blue: 0.35),
        Color(red: 0.98, green: 0.65, blue: 0.25),
        Color(red: 0.98, green: 0.85, blue: 0.25),
        Color(red: 0.35, green: 0.80, blue: 0.55),
        Color(red: 0.25, green: 0.75, blue: 0.95),
        Color(red: 0.45, green: 0.55, blue: 0.98),
        Color(red: 0.70, green: 0.45, blue: 0.95),
        Color(red: 0.95, green: 0.45, blue: 0.75)
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
                .opacity(0.4)
            
            // Main Dashboard (Left Wheel + Right Candidate & Settings Management)
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    // Left Column: Interactive Wheel & Draw Action
                    wheelStageCard
                        .frame(maxWidth: .infinity)
                    
                    // Right Column: Candidate List, Mode Config & Draw History
                    controlPanelCard
                        .frame(width: 380)
                }
                .padding(28)
                .frame(maxWidth: 1120)
            }
            .frame(maxWidth: .infinity)
        }
        .background(pageBackgroundView)
        .sheet(isPresented: $showBatchInputSheet) {
            batchInputModal
        }
        .sheet(isPresented: $showResultModal) {
            resultPresentationModal
        }
    }
    
    // MARK: - Page Background
    
    private var pageBackgroundView: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(NSColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1.0)),
                        Color(NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(NSColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)),
                        Color(NSColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1.0))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("幸运大转盘")
                        .font(.system(size: 22, weight: .bold))
                }
                
                Text("团队团建抽奖、会议发言顺序、任务随机分派，支持单一结果与批量多结果抽选")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let copied = copiedFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已复制: \(copied)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Left: Wheel Stage Card
    
    private var wheelStageCard: some View {
        VStack(spacing: 24) {
            // Extraction Mode Bar Indicator
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: extractionMode == .single ? "person.fill" : "person.3.fill")
                        .foregroundColor(.orange)
                    Text(extractionMode == .single ? "当前模式：单一抽选 (1人)" : "当前模式：多项抽选 (同时抽取 \(pickCount) 人)")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                Text("候选池: \(candidates.count) 人")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
            
            // Visual Wheel Area
            ZStack {
                if candidates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("候选池暂无成员")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text("请在右侧添加成员，或从团队成员名单一键导入")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(width: 320, height: 320)
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                } else {
                    // Custom Canvas Wheel
                    WheelCanvasView(
                        candidates: candidates,
                        colors: sliceColors,
                        rotationAngle: rotationAngle
                    )
                    .frame(width: 320, height: 320)
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
                    
                    // Center Hub Button
                    Button(action: {
                        startLuckyDraw()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: isSpinning
                                            ? [Color.gray, Color.secondary]
                                            : [Color.orange, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 68, height: 68)
                                .shadow(color: isSpinning ? Color.clear : Color.orange.opacity(0.4), radius: 6, y: 3)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.6), lineWidth: 2.5)
                                )
                            
                            Text(isSpinning ? "抽选中" : "GO")
                                .font(.system(size: isSpinning ? 13 : 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSpinning || candidates.isEmpty)
                    
                    // Top Pointer
                    VStack {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.red, Color.pink],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 3, y: 2)
                        Spacer()
                    }
                    .frame(width: 320, height: 340)
                }
            }
            .frame(height: 340)
            
            // Bottom Action Bar
            HStack(spacing: 16) {
                Button(action: {
                    startLuckyDraw()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isSpinning ? "arrow.triangle.2.circlepath" : "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text(isSpinning ? "正在抽取中..." : (extractionMode == .single ? "开始抽取幸运儿" : "开始批量抽取 (\(pickCount)人)"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        candidates.isEmpty || isSpinning
                            ? AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                            : AnyShapeStyle(LinearGradient(colors: [Color.orange, Color.pink], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(
                        candidates.isEmpty || isSpinning
                            ? Color.secondary.opacity(0.8)
                            : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(candidates.isEmpty || isSpinning ? Color.secondary.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
                    .shadow(color: candidates.isEmpty || isSpinning ? Color.clear : Color.orange.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(candidates.isEmpty || isSpinning)
            }
            
            // Recent Winners Banner (if any)
            if !recentResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text(recentResults.count == 1 ? "最新中奖者：" : "本轮抽出 (\(recentResults.count)人)：")
                            .font(.system(size: 13, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                recentResults.removeAll()
                            }
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清除横幅")
                        
                        Button("查看详情") {
                            showResultModal = true
                        }
                        .font(.system(size: 11.5))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentResults, id: \.self) { winner in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                    Text(winner)
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(14)
                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(22)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // MARK: - Right: Control Panel Card
    
    private var controlPanelCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. 抽取规则与模式配置
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.orange)
                    Text("抽取规则设置")
                        .font(.system(size: 14, weight: .bold))
                }
                
                // 单选 / 多选 切换
                Picker("抽取模式", selection: $extractionMode) {
                    ForEach(ExtractionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: extractionMode) { _, _ in
                    withAnimation {
                        candidates.removeAll()
                        recentResults.removeAll()
                        rotationAngle = 0.0
                    }
                }
                
                if extractionMode == .multiple {
                    multipleCountControl
                }
                
                Toggle("允许同一轮内重复中奖", isOn: $allowRepeat)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .disabled(extractionMode == .single)
            }
            .padding(14)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // 2. 候选池管理
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.cyan)
                        Text("候选成员列表 (\(candidates.count))")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    
                    Spacer()
                    
                    if !candidates.isEmpty {
                        Button(role: .destructive, action: {
                            withAnimation {
                                candidates.removeAll()
                                recentResults.removeAll()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                Text("一键清空")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Menu {
                        Button("从团队成员一键导入") {
                            importTeamMembers()
                        }
                        Button("批量粘贴添加...") {
                            batchInputText = ""
                            showBatchInputSheet = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("快速导入")
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // Add Candidate Input (Auto split multiple names)
                HStack(spacing: 6) {
                    TextField("输入/粘贴单个或多个姓名 (空格/逗号分隔)", text: $newCandidateText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit {
                            addCandidatesFromInput()
                        }
                    
                    Button("添加") {
                        addCandidatesFromInput()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newCandidateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Candidate Chips List
                if candidates.isEmpty {
                    Text("暂无成员，点击右上角快速导入或在上方添加")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(candidates.enumerated()), id: \.offset) { index, member in
                                HStack {
                                    Circle()
                                        .fill(sliceColors[index % sliceColors.count])
                                        .frame(width: 8, height: 8)
                                    
                                    Text(member)
                                        .font(.system(size: 12.5, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        candidates.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // 3. 抽选历史记录
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text("抽取历史 (\(historyRecords.count))")
                            .font(.system(size: 13, weight: .bold))
                    }
                    
                    Spacer()
                    
                    if !historyRecords.isEmpty {
                        Button("清空历史") {
                            historyRecords.removeAll()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                }
                
                if historyRecords.isEmpty {
                    Text("暂无抽取历史记录")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(historyRecords) { rec in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rec.winners.joined(separator: "、"))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text("\(formatTime(rec.timestamp)) · \(rec.winners.count)人中奖 / \(rec.totalCandidates)人参与")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        let text = "中奖名单：\(rec.winners.joined(separator: "、")) (共\(rec.winners.count)人)"
                                        copyToClipboard(text)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .background(modernCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 8, y: 3)
    }
    
    // MARK: - Multiple Pick Count Control
    
    private var multipleCountControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("抽取人数")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 直接可输入的数字文本框
                HStack(spacing: 4) {
                    TextField("2", text: $pickCountText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: pickCountText) { _, newVal in
                            let filtered = newVal.filter { "0123456789".contains($0) }
                            if let val = Int(filtered), val > 0 {
                                pickCount = val
                            } else if filtered.isEmpty {
                                pickCount = 1
                            }
                        }
                    
                    Text("人")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Stepper("", onIncrement: {
                        let maxLimit = max(1, candidates.count > 0 ? candidates.count : 100)
                        if pickCount < maxLimit {
                            pickCount += 1
                            pickCountText = String(pickCount)
                        }
                    }, onDecrement: {
                        if pickCount > 1 {
                            pickCount -= 1
                            pickCountText = String(pickCount)
                        }
                    })
                    .labelsHidden()
                }
            }
            
            // 快捷人数胶囊按钮
            HStack(spacing: 6) {
                Text("快捷选择:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                quickCountButton(2)
                quickCountButton(3)
                quickCountButton(5)
                quickCountButton(10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func quickCountButton(_ count: Int) -> some View {
        let isSelected = (pickCount == count)
        return Button(action: {
            pickCount = count
            pickCountText = String(count)
        }) {
            Text("\(count)人")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? Color.orange.opacity(0.2) : Color.black.opacity(0.08))
                .foregroundColor(isSelected ? .orange : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // Batch Input Modal
    private var batchInputModal: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("批量导入候选名单")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("关闭") {
                    showBatchInputSheet = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("支持通过逗号、空格、分号或换行分隔多个成员姓名：")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            TextEditor(text: $batchInputText)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .frame(height: 160)
            
            HStack {
                Button("清空输入") {
                    batchInputText = ""
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("确定并追加到列表") {
                    processBatchCandidates()
                    showBatchInputSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(batchInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
    
    // Result Presentation Modal (Celebration Banner)
    private var resultPresentationModal: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom))
                .padding(.top, 10)
            
            Text(recentResults.count == 1 ? "🎉 恭喜幸运儿 🎉" : "🎉 恭喜以下 \(recentResults.count) 位中奖者 🎉")
                .font(.system(size: 18, weight: .heavy))
            
            VStack(spacing: 10) {
                ForEach(recentResults, id: \.self) { winner in
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text(winner)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            .frame(maxHeight: 240)
            
            HStack(spacing: 12) {
                Button(action: {
                    let text = "🎉 抽奖结果：\(recentResults.joined(separator: "、"))"
                    copyToClipboard(text)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("复制中奖名单")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                // 一键移出中奖者（方便进行下一轮抽选）
                Button(action: {
                    withAnimation {
                        for winner in recentResults {
                            candidates.removeAll { $0 == winner }
                        }
                        showResultModal = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.badge.minus")
                        Text("移出中奖者并继续")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                Button("完成") {
                    showResultModal = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 400)
    }
    
    // MARK: - Actions & Logics
    
    private func addCandidatesFromInput() {
        let text = newCandidateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let separators = CharacterSet(charactersIn: ",，、;；/| \n\t")
        let names = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var addedCount = 0
        for name in names {
            if !candidates.contains(name) {
                candidates.append(name)
                addedCount += 1
            }
        }
        
        newCandidateText = ""
    }
    
    private func processBatchCandidates() {
        let separators = CharacterSet(charactersIn: ",，、;； \n\t")
        let names = batchInputText.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for name in names {
            if !candidates.contains(name) {
                candidates.append(name)
            }
        }
    }
    
    private func importTeamMembers() {
        let names = store.teamMembers.map { $0.name }
        for name in names {
            if !candidates.contains(name) {
                candidates.append(name)
            }
        }
    }
    
    private func startLuckyDraw() {
        guard !candidates.isEmpty && !isSpinning else { return }
        
        isSpinning = true
        NSSound(named: "Ping")?.play()
        
        // Calculate Winners
        var winners: [String] = []
        if extractionMode == .single {
            let targetIdx = Int.random(in: 0..<candidates.count)
            selectedIndex = targetIdx
            winners = [candidates[targetIdx]]
        } else {
            let count = min(pickCount, candidates.count)
            if allowRepeat {
                for _ in 0..<count {
                    if let picked = candidates.randomElement() {
                        winners.append(picked)
                    }
                }
            } else {
                winners = Array(candidates.shuffled().prefix(count))
            }
            if let firstWinner = winners.first, let idx = candidates.firstIndex(of: firstWinner) {
                selectedIndex = idx
            }
        }
        
        // Spin Wheel animation angle: Target degree calculation
        let n = Double(candidates.count)
        let sliceDegree = 360.0 / n
        
        // 目标扇区中心在未旋转状态下的角度 (0度在3点钟方向，顺时针增长)
        let targetSliceCenter = Double(selectedIndex) * sliceDegree + (sliceDegree / 2.0)
        
        // 顶部指针位于 12 点钟方向 (270度)。
        // 要使 (targetSliceCenter + targetWheelAngle) % 360 == 270:
        // targetWheelAngle = 270 - targetSliceCenter (modulo 360)
        let desiredAngleMod360 = (270.0 - targetSliceCenter).truncatingRemainder(dividingBy: 360.0)
        let normalizedDesiredAngle = desiredAngleMod360 >= 0 ? desiredAngleMod360 : (desiredAngleMod360 + 360.0)
        
        // 基于当前 rotationAngle，保证永远顺时针加速多圈后精准停靠
        let currentMod360 = rotationAngle.truncatingRemainder(dividingBy: 360.0)
        let normalizedCurrent = currentMod360 >= 0 ? currentMod360 : (currentMod360 + 360.0)
        
        var forwardDelta = normalizedDesiredAngle - normalizedCurrent
        if forwardDelta <= 0 {
            forwardDelta += 360.0
        }
        
        let extraSpins = Double(Int.random(in: 5...8)) * 360.0
        let totalDelta = extraSpins + forwardDelta
        
        withAnimation(.easeOut(duration: 3.5)) {
            rotationAngle += totalDelta
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            isSpinning = false
            recentResults = winners
            historyRecords.insert(
                ExtractionHistoryRecord(
                    timestamp: Date(),
                    winners: winners,
                    totalCandidates: candidates.count
                ),
                at: 0
            )
            NSSound(named: "Glass")?.play()
            showResultModal = true
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df.string(from: date)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedFeedback = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            copiedFeedback = nil
        }
    }
    
    // MARK: - Modern Styling Colors
    
    private var modernCardBackground: Color {
        if colorScheme == .dark {
            return Color(NSColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 0.95))
        } else {
            return Color.white
        }
    }
    
    private var cardBorderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08)
        } else {
            return Color.black.opacity(0.06)
        }
    }
    
    private var cardShadowColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.3)
        } else {
            return Color.black.opacity(0.04)
        }
    }
}

// MARK: - Wheel Canvas View

struct WheelCanvasView: View {
    let candidates: [String]
    let colors: [Color]
    let rotationAngle: Double
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let sliceAngle = 360.0 / Double(max(1, candidates.count))
            
            ZStack {
                // Slices
                ForEach(0..<candidates.count, id: \.self) { i in
                    let startAngle = Double(i) * sliceAngle
                    let endAngle = startAngle + sliceAngle
                    let midAngle = (startAngle + endAngle) / 2.0
                    
                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(colors[i % colors.count])
                    
                    // Slice Text
                    let textRadius = radius * 0.65
                    let radians = midAngle * .pi / 180.0
                    let x = center.x + textRadius * CGFloat(cos(radians))
                    let y = center.y + textRadius * CGFloat(sin(radians))
                    
                    Text(candidates[i])
                        .font(.system(size: candidates.count > 12 ? 10 : 13, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                        .rotationEffect(.degrees(midAngle + 90))
                        .position(x: x, y: y)
                }
                
                // Outer Ring Border
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 4)
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
            }
            .rotationEffect(.degrees(rotationAngle))
        }
    }
}

#Preview {
    LuckyWheelView()
        .environmentObject(WorkbenchStore())
}
