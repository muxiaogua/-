//
//  JingYiQiuJingEditorSheet.swift
//  团队工作台
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 精益求精群组邮件分发引擎

public enum JingYiQiuJingMailHelper {
    public static let targetGroupEmail = "NJ-JD-Team@group.apple.com"
    
    public static func composeGroupMail(for article: SharedKnowledgeArticle) {
        let recipient = targetGroupEmail
        let caseSuffix = article.caseId.isEmpty ? "" : " - (Case: \(article.caseId))"
        let subject = "[精益求精] [\(article.category.rawValue)] \(article.title)\(caseSuffix)"
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let timeStr = df.string(from: article.createdAt)
        
        let tipsText = article.keyTips.isEmpty ? "" : "\n\n【四、经验心得 / 避坑要点】：\n" + article.keyTips.map { "• \($0)" }.joined(separator: "\n")
        let deviceText = article.deviceAndOS.isEmpty ? "" : "涉及机型：\(article.deviceAndOS)\n"
        let caseText = article.caseId.isEmpty ? "" : "案例编号：\(article.caseId)\n"
        
        // 纯文本参考文章格式 (备用)
        let plainRefText: String
        if article.referenceArticles.isEmpty {
            plainRefText = ""
        } else {
            plainRefText = "\n\n【参考文章】：\n" + article.referenceArticles.map { ref in
                if ref.isCoreProtocol {
                    let coreId = ref.coreArticleId ?? ref.urlOrCoreId
                    if !ref.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return "• \(coreId) \(ref.title)"
                    } else {
                        return "• \(coreId)"
                    }
                } else {
                    return "• \(ref.displayTitle)"
                }
            }.joined(separator: "\n")
        }
        
        let beforeRefPlainText = """
        各位伙伴好，
        
        分享一篇「精益求精」业务排查案例，供大家业务参考复盘：
        
        【案例基础信息】
        案例标题：\(article.title)
        所属品类：\(article.category.rawValue)
        \(caseText)\(deviceText)分享人员：\(article.author)
        分享时间：\(timeStr)
        
        【一、故障背景】：
        \(article.faultBackground.isEmpty ? article.summary : article.faultBackground)
        
        【二、排查思路】：
        \(article.troubleshootingLogic.isEmpty ? "（详见解决方案规程）" : article.troubleshootingLogic)
        
        【三、解决方案】：
        \(article.solution)\(tipsText)
        """
        
        let afterRefPlainText = """
        
        
        * 本案例已同步归档至「团队工作台 ➔ 共享知识库 ➔ 精益求精」专区，附带 \(article.screenshotsBase64.count) 张相关截图，欢迎查阅与讨论交流。
        """
        
        // 生成临时截图文件以便作为附件插入邮件
        var tempAttachmentPaths: [String] = []
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JingYiQiuJingMail_\(article.id.uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        for (idx, b64) in article.screenshotsBase64.enumerated() {
            if let data = Data(base64Encoded: b64) {
                let imgPath = tempDir.appendingPathComponent("相关截图_\(idx + 1).jpg")
                try? data.write(to: imgPath)
                tempAttachmentPaths.append(imgPath.path)
            }
        }
        
        // 构造富文本邮件 (Core 文章显示为蓝色数字 ID 点击唤起 Core + 正文标题，网页外链显示为蓝色下划线标题)
        let baseFont = NSFont.systemFont(ofSize: 13.5)
        let richBody = NSMutableAttributedString(string: beforeRefPlainText, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.textColor
        ])
        
        if !article.referenceArticles.isEmpty {
            richBody.append(NSAttributedString(string: "\n\n【参考文章】：\n", attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.textColor
            ]))
            
            for (idx, ref) in article.referenceArticles.enumerated() {
                richBody.append(NSAttributedString(string: "• ", attributes: [
                    .font: baseFont,
                    .foregroundColor: NSColor.textColor
                ]))
                
                if ref.isCoreProtocol {
                    // 样式 1 (截图 1): 蓝色数字 ID (点击直接唤起 Core) + 黑色/标准标题
                    let coreId = ref.coreArticleId ?? ref.urlOrCoreId
                    let coreAttr = NSAttributedString(string: coreId, attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.systemBlue,
                        .link: ref.urlOrCoreId
                    ])
                    richBody.append(coreAttr)
                    
                    if !ref.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        richBody.append(NSAttributedString(string: " \(ref.title)", attributes: [
                            .font: baseFont,
                            .foregroundColor: NSColor.textColor
                        ]))
                    }
                } else {
                    // 样式 2 (截图 2): 蓝色下划线标题 (点击直接访问网页链接)
                    let linkAttr = NSAttributedString(string: ref.displayTitle, attributes: [
                        .font: baseFont,
                        .foregroundColor: NSColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: ref.urlOrCoreId
                    ])
                    richBody.append(linkAttr)
                }
                
                if idx < article.referenceArticles.count - 1 {
                    richBody.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
                }
            }
        }
        
        richBody.append(NSAttributedString(string: afterRefPlainText, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.textColor
        ]))
        
        // 优先通过系统 NSSharingService 调起 Mail.app，以保留富文本超链接特性
        DispatchQueue.main.async {
            if let service = NSSharingService(named: .composeEmail) {
                service.subject = subject
                service.recipients = [recipient]
                
                var items: [Any] = [richBody]
                for p in tempAttachmentPaths {
                    items.append(URL(fileURLWithPath: p))
                }
                
                if service.canPerform(withItems: items) {
                    service.perform(withItems: items)
                    return
                }
            }
            
            // 兜底：若未能调起则采用 AppleScript 调起
            let fullPlainBody = beforeRefPlainText + plainRefText + afterRefPlainText
            fallbackToAppleScript(subject: subject, body: fullPlainBody, recipient: recipient, attachmentPaths: tempAttachmentPaths)
        }
    }
    
    private static func fallbackToAppleScript(subject: String, body: String, recipient: String, attachmentPaths: [String]) {
        let safeSubj = subject
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let safeBody = body
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        var attachmentLines = ""
        for p in attachmentPaths {
            let safeP = p.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            attachmentLines += "make new attachment with properties {file name:(POSIX file \"\(safeP)\")} at after the last paragraph of content of newMsg\n"
        }
        
        let script = """
        tell application "Mail"
            set newMsg to make new outgoing message with properties {subject:"\(safeSubj)", content:"\(safeBody)\\n\\n", visible:true}
            tell newMsg
                make new to recipient at end of to recipients with properties {address:"\(recipient)"}
                \(attachmentLines)
            end tell
            activate
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&errorDict)
        }
    }
}

// MARK: - 精益求精标准化录入工作台

public struct JingYiQiuJingEditorSheet: View {
    @EnvironmentObject var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss
    
    public var articleToEdit: SharedKnowledgeArticle? = nil
    
    @State private var title: String = ""
    @State private var selectedCategory: KnowledgeCategory = .iOS
    @State private var caseId: String = ""
    @State private var deviceAndOS: String = ""
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    
    // 核心四大模块
    @State private var faultBackground: String = ""
    @State private var troubleshootingLogic: String = ""
    @State private var solution: String = ""
    @State private var screenshotsBase64: [String] = []
    
    // 避坑要点与参考文章
    @State private var tipInput: String = ""
    @State private var keyTips: [String] = []
    
    // 参考文章双输入框 (默认填入 core://articleId=，粘贴外部网页自动关联标题)
    private let defaultCorePrefix = "core://articleId="
    @State private var refUrlInput: String = "core://articleId="
    @State private var refTitleInput: String = ""
    @State private var isFetchingTitle: Bool = false
    @State private var referenceArticles: [KnowledgeReferenceLink] = []
    @State private var alsoSendGroupMail: Bool = true
    @State private var isPinned: Bool = false
    
    public init(articleToEdit: SharedKnowledgeArticle? = nil) {
        self.articleToEdit = articleToEdit
    }
    
    private var isEditing: Bool {
        articleToEdit != nil
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !faultBackground.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !solution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            editorHeaderBar
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Scrollable Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 品类与案例标识 (iOS/Mac/Watch + Case号 + 机型系统)
                    baseMetadataSection
                    
                    // 2. 标题输入与细分标签
                    titleAndTagsSection
                    
                    // 3. 故障背景 (Background)
                    backgroundSection
                    
                    // 4. 排查思路
                    logicSection
                    
                    // 5. 解决方案
                    solutionSection
                    
                    // 6. 相关截图
                    screenshotsSection
                    
                    // 7. 经验心得与避坑要点 (Key Tips)
                    tipsBlock
                    
                    // 8. 参考文章 (Reference Articles)
                    referencesBlock
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Action Bar
            editorFooterBar
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 680, idealHeight: 760)
        .onAppear {
            setupInitialData()
        }
    }
    
    // MARK: - 1. 顶栏
    private var editorHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                    Text(isEditing ? "编辑「精益求精」案例" : "编写「精益求精」深度案例")
                        .font(.system(size: 16, weight: .bold))
                }
                Text("结构化沉淀故障背景、思路推导、解决方案与佐证截图，一键分发群组邮件 (\(JingYiQiuJingMailHelper.targetGroupEmail))")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - 2. 基础元数据 (品类 + 案例号 + 机型/系统)
    private var baseMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 品类标签切换
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("所属品类")
                        .font(.system(size: 13, weight: .semibold))
                    Text("必选")
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 8) {
                    ForEach(KnowledgeCategory.selectableCases) { cat in
                        let isSelected = (selectedCategory == cat)
                        Button {
                            selectedCategory = cat
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 11.5))
                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundColor(isSelected ? cat.themeColor : .secondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? cat.themeColor.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? cat.themeColor.opacity(0.6) : Color.clear, lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 案例号与涉及机型系统并列
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Case 案例编号")
                        .font(.system(size: 12.5, weight: .medium))
                    TextField("例如：102498212 (选填)", text: $caseId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("涉及机型与系统版本")
                        .font(.system(size: 12.5, weight: .medium))
                    TextField("例如：iPhone 16 Pro Max · iOS 26.0 (选填)", text: $deviceAndOS)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    // MARK: - 3. 标题与细分标签
    private var titleAndTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("案例标题")
                        .font(.system(size: 13, weight: .semibold))
                    Text("必填")
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                }
                
                TextField("一句话阐明案例核心现象与排查结果 (例如：更新系统后 iMessage 激活失败且账户设置闪退排查复盘)", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            
            // Tags
            HStack {
                TextField("输入细分标签后按回车添加 (例如：激活失败、网络代理、临时规程)...", text: $tagInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTag()
                    }
                
                Button("添加标签") {
                    addTag()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.system(size: 11.5))
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - 4. 故障背景
    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("一、故障背景 (Background)", systemImage: "text.book.closed.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text("必填")
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
                Spacer()
                Text("顾客诉求、故障初发场景与异常表现")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $faultBackground)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .frame(height: 100)
                
                if faultBackground.isEmpty {
                    Text("请简要说明故障背景：例如顾客反馈新机激活后无法启用 iMessage，电话号码一直在加载圈旋转，此前尝试过重启与还原网络均无效...")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 5. 排查思路
    private var logicSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("二、排查思路", systemImage: "lightbulb.max.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                Text("逻辑推导断点、排除的非核心因素与分析思路（选填）")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $troubleshootingLogic)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .frame(height: 100)
                
                if troubleshootingLogic.isEmpty {
                    Text("分享您的排查思路：例如先检查运营商漫游与短信推送链路，确认蜂窝网正常；再通过抓包/日志排除 Apple ID 账户封锁；最终定位为本地配置文件冲突...")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 6. 解决方案
    private var solutionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("三、解决方案", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
                Text("必填")
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
                Spacer()
                Text("切实解决问题的标准步骤与指引")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $solution)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .frame(height: 140)
                
                if solution.isEmpty {
                    Text("请分步骤输入解决方案：\n1. 引导顾客关闭 eSIM 后开启飞行模式 10 秒；\n2. 前往设置 ➔ 通用 ➔ 还原 ➔ 抹掉所有网络并重启；\n3. 重新插入实体卡即可秒级激活...")
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 7. 相关截图
    private var screenshotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("四、相关截图", systemImage: "photo.stack.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text("已选 \(screenshotsBase64.count) 张")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                Spacer()
                
                Button(action: {
                    selectScreenshots()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("选择/添加截图")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if screenshotsBase64.isEmpty {
                Button(action: {
                    selectScreenshots()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text("点击添加相关截图（支持 PNG / JPEG / HEIC，自动压缩并随云端全员同步）")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(screenshotsBase64.enumerated()), id: \.offset) { idx, b64 in
                            if let data = Data(base64Encoded: b64), let nsImage = NSImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                                    
                                    Button {
                                        screenshotsBase64.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 8. 经验心得与避坑要点
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("五、经验心得与避坑贴士 (Key Learnings)", systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
                Text("强化客服关键注意事项（选填）")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("输入关键提炼 (例如：此问题通常为网络推送延时，切勿轻率引导顾客抹掉全部内容)...", text: $tipInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTip()
                    }
                
                Button("添加心得") {
                    addTip()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(tipInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !keyTips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(keyTips.enumerated()), id: \.offset) { idx, tip in
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(tip)
                                .font(.system(size: 12))
                            Spacer()
                            Button {
                                keyTips.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
    
    // MARK: - 8. 参考文章
    private var referencesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("六、参考文章 (Reference Articles)", systemImage: "link.badge.plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.indigo)
                Spacer()
                Text("输入 Core 文章 ID 或网页外链 (填入网址将自动关联标题)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // 两个填写框并列：第一个默认为 core://articleId=，第二个填写对应文章标题
            HStack(spacing: 8) {
                // 1. 第一个填写框 (默认预填 core://articleId=)
                HStack(spacing: 5) {
                    Image(systemName: refUrlInput.lowercased().hasPrefix("core://") ? "cpu.fill" : "link")
                        .foregroundColor(refUrlInput.lowercased().hasPrefix("core://") ? .orange : .blue)
                        .font(.system(size: 11))
                    
                    TextField("链接 (默认 core://articleId=)", text: $refUrlInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: refUrlInput.lowercased().hasPrefix("core://") ? .monospaced : .default))
                        .onChange(of: refUrlInput) { _, newValue in
                            fetchTitleIfNeeded(for: newValue)
                        }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .frame(minWidth: 260)
                
                // 2. 第二个填写框 (用于填写对应文章标题，网页自动抓取关联)
                HStack(spacing: 5) {
                    if isFetchingTitle {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "text.quote")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    
                    TextField(isFetchingTitle ? "正在自动获取网页标题..." : "对应文章标题 (填入网址自动关联)", text: $refTitleInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit {
                            addReference()
                        }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                
                Button("添加文章") {
                    addReference()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(refUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || refUrlInput.trimmingCharacters(in: .whitespacesAndNewlines) == defaultCorePrefix)
            }
            
            // 已添加的参考文章清单
            if !referenceArticles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(referenceArticles.enumerated()), id: \.element.id) { idx, ref in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if ref.isCoreProtocol {
                                // 形式 1: 蓝色数字 ID (点击直接唤起 Core) + 黑色/标准标题
                                let coreId = ref.coreArticleId ?? ref.urlOrCoreId
                                Button {
                                    if let url = URL(string: ref.urlOrCoreId) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Text(coreId)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("点击可测试唤起 Core: \(ref.urlOrCoreId)")
                                
                                if !ref.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(ref.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            } else {
                                // 形式 2: 蓝色下划线标题 (点击直接访问网页链接)
                                Button {
                                    if let url = URL(string: ref.urlOrCoreId) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    Text(ref.displayTitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.blue)
                                        .underline()
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .help("点击访问网页: \(ref.urlOrCoreId)")
                            }
                            
                            Spacer()
                            
                            Button {
                                referenceArticles.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("移除此参考文章")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
                    }
                }
            }
        }
    }
    
    // MARK: - 9. 底栏操作
    private var editorFooterBar: some View {
        HStack {
            // 一并发送邮件复选框
            Toggle(isOn: $alsoSendGroupMail) {
                HStack(spacing: 5) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                    Text("保存后调起群组邮件 (\(JingYiQiuJingMailHelper.targetGroupEmail))")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .toggleStyle(.checkbox)
            
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            
            Button(action: {
                saveArticle()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(isEditing ? "保存修改" : "归档至精益求精")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!isFormValid)
        }
    }
    
    // MARK: - 辅助操作
    private func addTag() {
        let clean = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !tags.contains(clean) {
            tags.append(clean)
            tagInput = ""
        }
    }
    
    private func addTip() {
        let clean = tipInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !keyTips.contains(clean) {
            keyTips.append(clean)
            tipInput = ""
        }
    }
    
    private func addReference() {
        let cleanUrl = refUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty && cleanUrl != defaultCorePrefix else { return }
        let cleanTitle = refTitleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newLink = KnowledgeReferenceLink(urlOrCoreId: cleanUrl, title: cleanTitle)
        if !referenceArticles.contains(where: { $0.urlOrCoreId == cleanUrl }) {
            referenceArticles.append(newLink)
        }
        refUrlInput = defaultCorePrefix
        refTitleInput = ""
    }
    
    // 自动抓取外链网页标题并填充
    private func fetchTitleIfNeeded(for urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // 排除 core:// 协议及空值，仅对 http/https 尝试提取网页标题
        guard trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://"),
              let url = URL(string: trimmed) else {
            return
        }
        
        isFetchingTitle = true
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 4
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
                let (data, _) = try await URLSession.shared.data(for: request)
                if let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                    if let title = extractHTMLTitle(from: html) {
                        await MainActor.run {
                            if self.refTitleInput.isEmpty {
                                self.refTitleInput = title
                            }
                            self.isFetchingTitle = false
                        }
                        return
                    }
                }
            } catch {
                // 抓取失败由 fallback 兜底
            }
            
            await MainActor.run {
                if self.refTitleInput.isEmpty {
                    self.refTitleInput = fallbackTitle(from: url)
                }
                self.isFetchingTitle = false
            }
        }
    }
    
    private func extractHTMLTitle(from html: String) -> String? {
        let pattern = "(?i)<title[^>]*>([\\s\\S]*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > 1 else { return nil }
        let rawTitle = nsString.substring(with: match.range(at: 1))
        let cleanTitle = rawTitle
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? nil : cleanTitle
    }
    
    private func fallbackTitle(from url: URL) -> String {
        let host = url.host ?? ""
        let lastComp = url.lastPathComponent
        if !lastComp.isEmpty && lastComp != "/" {
            return "\(host) - \(lastComp)"
        }
        return host.isEmpty ? url.absoluteString : host
    }
    
    private func selectScreenshots() {
        let panel = NSOpenPanel()
        panel.title = "选择案例排查截图"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let img = NSImage(contentsOf: url),
                   let b64 = compressAndConvertImageToBase64(image: img) {
                    screenshotsBase64.append(b64)
                }
            }
        }
    }
    
    private func compressAndConvertImageToBase64(image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        
        var targetRep = bitmap
        let maxDimension: CGFloat = 1600
        if CGFloat(bitmap.pixelsWide) > maxDimension || CGFloat(bitmap.pixelsHigh) > maxDimension {
            let ratio = min(maxDimension / CGFloat(bitmap.pixelsWide), maxDimension / CGFloat(bitmap.pixelsHigh))
            let newWidth = Int(CGFloat(bitmap.pixelsWide) * ratio)
            let newHeight = Int(CGFloat(bitmap.pixelsHigh) * ratio)
            if let scaled = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: newWidth,
                pixelsHigh: newHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
                image.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight), from: .zero, operation: .copy, fraction: 1.0)
                NSGraphicsContext.restoreGraphicsState()
                targetRep = scaled
            }
        }
        
        guard let jpegData = targetRep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else { return nil }
        return jpegData.base64EncodedString()
    }
    
    private func setupInitialData() {
        if let art = articleToEdit {
            title = art.title
            selectedCategory = art.category
            caseId = art.caseId
            deviceAndOS = art.deviceAndOS
            tags = art.tags
            faultBackground = art.faultBackground.isEmpty ? art.summary : art.faultBackground
            troubleshootingLogic = art.troubleshootingLogic
            solution = art.solution
            screenshotsBase64 = art.screenshotsBase64
            keyTips = art.keyTips
            referenceArticles = art.referenceArticles
            refUrlInput = defaultCorePrefix
            refTitleInput = ""
            isPinned = art.isPinned
            alsoSendGroupMail = false
        } else {
            selectedCategory = .iOS
            referenceArticles = []
            refUrlInput = defaultCorePrefix
            refTitleInput = ""
            alsoSendGroupMail = true
        }
    }
    
    private func saveArticle() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCaseId = caseId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevice = deviceAndOS.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBg = faultBackground.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLogic = troubleshootingLogic.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSol = solution.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let targetArticle: SharedKnowledgeArticle
        
        if var existing = articleToEdit {
            existing.kind = .jingYiQiuJing
            existing.title = cleanTitle
            existing.category = selectedCategory
            existing.caseId = cleanCaseId
            existing.deviceAndOS = cleanDevice
            existing.tags = tags
            existing.summary = cleanBg
            existing.faultBackground = cleanBg
            existing.troubleshootingLogic = cleanLogic
            existing.solution = cleanSol
            existing.screenshotsBase64 = screenshotsBase64
            existing.keyTips = keyTips
            existing.referenceArticles = referenceArticles
            existing.isPinned = isPinned
            existing.updatedAt = Date()
            store.updateKnowledgeArticle(existing)
            targetArticle = existing
        } else {
            let newArticle = SharedKnowledgeArticle(
                kind: .jingYiQiuJing,
                title: cleanTitle,
                category: selectedCategory,
                tags: tags,
                summary: cleanBg,
                solution: cleanSol,
                caseId: cleanCaseId,
                deviceAndOS: cleanDevice,
                faultBackground: cleanBg,
                troubleshootingLogic: cleanLogic,
                screenshotsBase64: screenshotsBase64,
                hasSentGroupMail: alsoSendGroupMail,
                keyTips: keyTips,
                referenceArticles: referenceArticles,
                author: store.currentUser.name,
                createdAt: Date(),
                updatedAt: Date(),
                isPinned: isPinned,
                helpfulUserNames: [],
                comments: []
            )
            store.addKnowledgeArticle(newArticle)
            targetArticle = newArticle
        }
        
        // 若勾选了群发邮件，自动唤起原生 Mail.app 生成专业格式案例邮件
        if alsoSendGroupMail {
            JingYiQiuJingMailHelper.composeGroupMail(for: targetArticle)
        }
        
        dismiss()
    }
}
