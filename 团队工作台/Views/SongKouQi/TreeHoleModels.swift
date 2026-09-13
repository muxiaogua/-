//
//  TreeHoleModels.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import Foundation
import SwiftUI
import Combine

// MARK: - 树洞图案与意境样式
enum TreeHoleStyle: String, CaseIterable, Identifiable, Codable {
    case ancientOak = "千年古树"
    case moonlitWillow = "月夜灵树"
    case goldenGinkgo = "金秋银杏"
    case sakuraDream = "绯樱祈愿"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .ancientOak: return "tree.fill"
        case .moonlitWillow: return "moon.stars.fill"
        case .goldenGinkgo: return "sun.max.fill"
        case .sakuraDream: return "heart.fill"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .ancientOak: return Color(red: 0.35, green: 0.78, blue: 0.45)
        case .moonlitWillow: return Color(red: 0.55, green: 0.70, blue: 0.98)
        case .goldenGinkgo: return Color(red: 0.98, green: 0.75, blue: 0.25)
        case .sakuraDream: return Color(red: 0.98, green: 0.60, blue: 0.75)
        }
    }
    
    var canopyColors: [Color] {
        switch self {
        case .ancientOak:
            // 完美复刻参考图中的莫兰迪温润浅绿与墨绿底色
            return [
                Color(red: 0.72, green: 0.80, blue: 0.74),
                Color(red: 0.54, green: 0.65, blue: 0.56),
                Color(red: 0.40, green: 0.50, blue: 0.42)
            ]
        case .moonlitWillow:
            return [
                Color(red: 0.42, green: 0.55, blue: 0.80),
                Color(red: 0.22, green: 0.28, blue: 0.50),
                Color(red: 0.12, green: 0.15, blue: 0.32)
            ]
        case .goldenGinkgo:
            return [
                Color(red: 0.98, green: 0.82, blue: 0.32),
                Color(red: 0.90, green: 0.62, blue: 0.18),
                Color(red: 0.75, green: 0.40, blue: 0.10)
            ]
        case .sakuraDream:
            return [
                Color(red: 1.0, green: 0.78, blue: 0.86),
                Color(red: 0.94, green: 0.58, blue: 0.70),
                Color(red: 0.78, green: 0.34, blue: 0.50)
            ]
        }
    }
    
    var trunkColors: [Color] {
        switch self {
        case .ancientOak:
            // 参考图中温暖质朴的浅棕木色
            return [
                Color(red: 0.76, green: 0.64, blue: 0.54),
                Color(red: 0.60, green: 0.48, blue: 0.38),
                Color(red: 0.42, green: 0.32, blue: 0.24)
            ]
        case .moonlitWillow:
            return [
                Color(red: 0.38, green: 0.40, blue: 0.52),
                Color(red: 0.24, green: 0.25, blue: 0.36),
                Color(red: 0.15, green: 0.15, blue: 0.22)
            ]
        case .goldenGinkgo:
            return [
                Color(red: 0.68, green: 0.48, blue: 0.28),
                Color(red: 0.50, green: 0.32, blue: 0.16),
                Color(red: 0.32, green: 0.18, blue: 0.08)
            ]
        case .sakuraDream:
            return [
                Color(red: 0.58, green: 0.42, blue: 0.42),
                Color(red: 0.42, green: 0.28, blue: 0.28),
                Color(red: 0.26, green: 0.15, blue: 0.15)
            ]
        }
    }
    
    var glowColors: [Color] {
        switch self {
        case .ancientOak:
            return [Color(red: 0.4, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.4, blue: 0.3)]
        case .moonlitWillow:
            return [Color(red: 0.55, green: 0.80, blue: 1.0), Color(red: 0.2, green: 0.3, blue: 0.7)]
        case .goldenGinkgo:
            return [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 0.65, green: 0.38, blue: 0.1)]
        case .sakuraDream:
            return [Color(red: 1.0, green: 0.72, blue: 0.86), Color(red: 0.65, green: 0.22, blue: 0.45)]
        }
    }
    
    var description: String {
        switch self {
        case .ancientOak: return t("苍翠古木・沉稳庇护")
        case .moonlitWillow: return t("月光如水・星辉祈愿")
        case .goldenGinkgo: return t("金叶暖阳・抚平内耗")
        case .sakuraDream: return t("绯樱落英・温柔治愈")
        }
    }
}

// MARK: - 心境标签
enum TreeHoleMood: String, CaseIterable, Identifiable, Codable {
    case upset = "委屈难过"
    case tired = "疲惫心累"
    case anxious = "焦虑内耗"
    case secret = "秘密心事"
    case venting = "日常吐槽"
    case wish = "微小愿望"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .upset: return "cloud.rain.fill"
        case .tired: return "battery.25"
        case .anxious: return "tornado"
        case .secret: return "lock.fill"
        case .venting: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .wish: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .upset: return Color(red: 0.35, green: 0.55, blue: 0.85)
        case .tired: return Color(red: 0.65, green: 0.60, blue: 0.75)
        case .anxious: return Color(red: 0.90, green: 0.55, blue: 0.25)
        case .secret: return Color(red: 0.55, green: 0.40, blue: 0.80)
        case .venting: return Color(red: 0.85, green: 0.35, blue: 0.30)
        case .wish: return Color(red: 0.95, green: 0.75, blue: 0.20)
        }
    }
}

// MARK: - 树下当下心情快速小方块选项
enum TreeHoleQuickMood: String, CaseIterable, Identifiable, Codable {
    case peaceful = "平常"
    case happy = "开心"
    case sad = "难过"
    case anxious = "焦虑"
    case panicked = "恐慌"
    case angry = "生气"
    case complex = "复杂"
    case depressed = "抑郁"
    case helpless = "无奈"
    case breakdown = "崩溃"
    case furious = "愤怒"
    case speechless = "无语"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var emoji: String {
        switch self {
        case .peaceful: return "🍃"
        case .happy: return "😊"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .panicked: return "😱"
        case .angry: return "😠"
        case .complex: return "🌀"
        case .depressed: return "🌧️"
        case .helpless: return "😮‍💨"
        case .breakdown: return "💥"
        case .furious: return "🔥"
        case .speechless: return "😶"
        }
    }
    
    var color: Color {
        switch self {
        case .peaceful: return Color(red: 0.35, green: 0.72, blue: 0.55) // 平常：草木浅绿
        case .happy: return Color(red: 0.98, green: 0.75, blue: 0.20)    // 开心：明朗金黄
        case .sad: return Color(red: 0.30, green: 0.55, blue: 0.85)      // 难过：忧郁天蓝
        case .anxious: return Color(red: 0.95, green: 0.55, blue: 0.20)  // 焦虑：焦躁橘橙
        case .panicked: return Color(red: 0.75, green: 0.35, blue: 0.85) // 恐慌：震颤深紫
        case .angry: return Color(red: 0.90, green: 0.35, blue: 0.30)    // 生气：暖红
        case .complex: return Color(red: 0.50, green: 0.55, blue: 0.72)  // 复杂：迷雾灰蓝
        case .depressed: return Color(red: 0.38, green: 0.42, blue: 0.52)// 抑郁：阴霾深灰
        case .helpless: return Color(red: 0.75, green: 0.65, blue: 0.48) // 无奈：风沙驼色
        case .breakdown: return Color(red: 0.85, green: 0.20, blue: 0.45)// 崩溃：碎裂玫红
        case .furious: return Color(red: 0.95, green: 0.15, blue: 0.15)  // 愤怒：赤烈火红
        case .speechless: return Color(red: 0.58, green: 0.60, blue: 0.65)// 无语：静默冷灰
        }
    }
    
    var gentleSuggestion: String {
        switch self {
        case .peaceful: return t("心境安稳从容，保持这份如微风拂过湖面的平静与舒坦。")
        case .happy: return t("把这份纯粹的喜悦好好珍藏在心里，今天也是发光的一天！")
        case .sad: return t("允许自己难过一会儿，掉眼泪也是情绪在排毒，树洞一直守着你。")
        case .anxious: return t("深呼吸……把悬着的心放下来，一件一件来，你做得很好了。")
        case .panicked: return t("抱抱自己，感受当下的安全与踏实。风浪虽大，终会过去。")
        case .angry: return t("生气的能量古树替你接纳化解，别用别人的失误惩罚自己。")
        case .complex: return t("理不清情绪也没关系，多重感受是真实的，慢慢来不用着急。")
        case .depressed: return t("在情绪低谷里，什么都不做也没关系。安心休息，树洞一直在。")
        case .helpless: return t("世事多变，尽力而为便无愧于心。放下不可控的，放过自己。")
        case .breakdown: return t("停下所有运转，大哭一场或好好睡一觉吧，树洞替你撑着。")
        case .furious: return t("炽热的怒火在此释放。喝一口温水，让心绪重新回归平缓。")
        case .speechless: return t("不值得费神计较的事就一笑而过，把精力留给美好的人和事。")
        }
    }
}

// MARK: - 心情打卡记录项
struct TreeHoleMoodRecord: Identifiable, Codable {
    let id: UUID
    let moodRawValue: String
    let timestamp: Date
}

// MARK: - 心情点击与心事年轮数据管理器 (单机版持久化存储)
final class TreeHoleMoodStatsManager: ObservableObject {
    static let shared = TreeHoleMoodStatsManager()
    
    private let countsKey = "TreeHoleMoodCounts_v1"
    private let recordsKey = "TreeHoleMoodRecords_v1"
    private let secretsKey = "TreeHoleSecretsData_v1"
    
    @Published var moodCounts: [String: Int] = [:]
    @Published var records: [TreeHoleMoodRecord] = []
    @Published var secrets: [TreeHoleSecret] = []
    
    private init() {
        loadData()
    }
    
    func count(for mood: TreeHoleQuickMood) -> Int {
        return moodCounts[mood.rawValue] ?? 0
    }
    
    var totalClicks: Int {
        return records.count
    }
    
    var totalSecretsCount: Int {
        return secrets.count
    }
    
    var dominantMood: TreeHoleQuickMood? {
        guard let top = moodCounts.max(by: { $0.value < $1.value }), top.value > 0 else {
            return nil
        }
        return TreeHoleQuickMood(rawValue: top.key)
    }
    
    // 记录一次实际点击心情
    func recordClick(for mood: TreeHoleQuickMood) {
        let current = moodCounts[mood.rawValue] ?? 0
        moodCounts[mood.rawValue] = current + 1
        
        let newRecord = TreeHoleMoodRecord(id: UUID(), moodRawValue: mood.rawValue, timestamp: Date())
        records.append(newRecord)
        
        saveData()
    }
    
    // 添加一条实际心事信笺
    func addSecret(_ secret: TreeHoleSecret) {
        secrets.insert(secret, at: 0)
        saveData()
    }
    
    func removeSecret(atOffsets offsets: IndexSet) {
        secrets.remove(atOffsets: offsets)
        saveData()
    }
    
    func resetStats() {
        moodCounts.removeAll()
        records.removeAll()
        secrets.removeAll()
        UserDefaults.standard.removeObject(forKey: countsKey)
        UserDefaults.standard.removeObject(forKey: recordsKey)
        UserDefaults.standard.removeObject(forKey: secretsKey)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] {
            self.moodCounts = data
        }
        if let recordData = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([TreeHoleMoodRecord].self, from: recordData) {
            self.records = decoded
        }
        if let secretData = UserDefaults.standard.data(forKey: secretsKey),
           let decoded = try? JSONDecoder().decode([TreeHoleSecret].self, from: secretData) {
            self.secrets = decoded
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(moodCounts, forKey: countsKey)
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
        if let encoded = try? JSONEncoder().encode(secrets) {
            UserDefaults.standard.set(encoded, forKey: secretsKey)
        }
    }
}

// MARK: - 四大温暖反馈类型（抱抱、摸摸头、我懂你、静静倾听）
enum WarmthFeedbackType: String, CaseIterable, Identifiable, Codable {
    case hug = "抱抱"
    case pat = "摸摸头"
    case understand = "我懂你"
    case listen = "静静倾听"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var emoji: String {
        switch self {
        case .hug: return "🫂"
        case .pat: return "🧸"
        case .understand: return "🌿"
        case .listen: return "🕯️"
        }
    }
    
    var highlightColor: Color {
        switch self {
        case .hug: return Color(red: 1.0, green: 0.50, blue: 0.50)
        case .pat: return Color(red: 1.0, green: 0.75, blue: 0.35)
        case .understand: return Color(red: 0.45, green: 0.85, blue: 0.65)
        case .listen: return Color(red: 0.55, green: 0.70, blue: 0.95)
        }
    }
    
    var comfortQuotes: [String] {
        switch self {
        case .hug:
            return [
                t("给你一个大大的隔空拥抱，今天辛苦了。卸下所有防备与铠甲，安心歇会儿吧。"),
                t("抱抱你，那些难受和委屈古树都替你接住了。你不需要时时刻刻假装坚强。"),
                t("紧紧抱住你。无论今天世界如何喧闹，现在的你都被森林的温柔妥帖包裹着。")
            ]
        case .pat:
            return [
                t("温柔地摸摸你的头，你已经做得很好了，不要对自己太苛刻。"),
                t("摸摸头，受了委屈不用憋着。在古树这里，你可以随时做回那个被呵护的孩子。"),
                t("轻轻摸摸头，把眉头的疲惫都抚平。深呼吸，今晚的世界只属于你自己。")
            ]
        case .understand:
            return [
                t("我懂你的不容易。那些没法对别人解释的苦衷与酸涩，我都完全理解。"),
                t("不用怀疑自己，你的每一个情绪都是真实且合理的。无论何时我都站在你这边。"),
                t("我懂你的心累。在这个世界上，总有这样一个树洞，毫无保留地接纳真实的你。")
            ]
        case .listen:
            return [
                t("古树不讲大道理，不做任何评判，只是静静地在这里陪伴你、听你说完每一个字。"),
                t("想说什么就说什么，不想说话也没关系。我就在这里，默默陪着你。"),
                t("这里没有对错，没有考核，没有说教。只有落叶的微风和属于你内心的安宁。")
            ]
        }
    }
    
    func randomQuote() -> String {
        return comfortQuotes.randomElement() ?? comfortQuotes[0]
    }
}

// MARK: - 心灵鸡汤库（古树秘境随机治愈语录）
struct TreeHoleSoulSoup {
    static let quotes: [String] = [
        "生活不一定要比别人过得好，但一定要比以前过得更舒心。",
        "万物皆有裂痕，那是光照进来的地方。",
        "允许一切发生，生活不是用来赶路的，而是用来感受路上的风景。",
        "别把所有心事都压在心头，风吹过树梢，自会把烦恼带向远方。",
        "慢慢来，谁不是翻山越岭去寻找属于自己的光芒与平静。",
        "哪怕生活偶尔有些阴霾，也别忘了给自己一个温柔的深呼吸。",
        "你不需要成为无懈可击的大人，在这里，你可以做最真实的自己。",
        "今天所有的疲惫与波折，都会成为明天更从容笃定的铺垫。",
        "心宽一寸，路宽一丈；若无闲事挂心头，便是人间好时节。",
        "照顾好自己的情绪，世界才会因为你的从容而变得温和舒畅。",
        "每一个平凡的日子里，都藏着不期而遇的温柔与微光。",
        "放下对未知的担忧，安住当下，把时间分给睡眠、美食和快乐。"
    ]
    
    static func randomQuote() -> String {
        let q = quotes.randomElement() ?? quotes[0]
        return q.localized
    }
}

// MARK: - 心事条目记录
struct TreeHoleSecret: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let mood: TreeHoleMood
    let date: Date
    let responseQuote: String
    let warmthType: WarmthFeedbackType
    
    var localizedContent: String { content.localized }
    var localizedResponseQuote: String { responseQuote.localized }
}

// MARK: - 树洞随机温暖反馈引擎 (纯接纳，降低评判)
struct TreeHoleEcho {
    static func randomFeedback() -> (warmth: WarmthFeedbackType, quote: String) {
        let picked = WarmthFeedbackType.allCases.randomElement() ?? .hug
        return (picked, picked.randomQuote())
    }
}
