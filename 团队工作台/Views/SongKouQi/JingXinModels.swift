//
//  JingXinModels.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import Foundation
import SwiftUI

// MARK: - 木鱼数据模型
enum MuyuMaterial: String, CaseIterable, Identifiable {
    case redSandalwood = "紫檀"
    case cartoonMuyu = "卡通木鱼"
    case emeraldJade = "翡翠"
    case whiteJade = "白玉"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var blessingPrefix: String {
        switch self {
        case .cartoonMuyu: return t("好运")
        case .emeraldJade: return t("开心")
        case .whiteJade: return t("健康")
        case .redSandalwood: return t("功德")
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .redSandalwood:
            return [
                Color(red: 0.62, green: 0.26, blue: 0.18),
                Color(red: 0.40, green: 0.14, blue: 0.08),
                Color(red: 0.22, green: 0.06, blue: 0.03)
            ]
        case .cartoonMuyu:
            // 完美复刻实物原木温润色泽与沉香木纹
            return [
                Color(red: 0.88, green: 0.74, blue: 0.54),
                Color(red: 0.70, green: 0.52, blue: 0.32),
                Color(red: 0.42, green: 0.28, blue: 0.14)
            ]
        case .emeraldJade:
            // 参考实物图：极具水头与温润光泽的帝王绿/阳绿翡翠
            return [
                Color(red: 0.24, green: 0.70, blue: 0.40),
                Color(red: 0.10, green: 0.45, blue: 0.24),
                Color(red: 0.04, green: 0.22, blue: 0.12)
            ]
        case .whiteJade:
            return [
                Color(red: 0.98, green: 0.98, blue: 0.96),
                Color(red: 0.88, green: 0.90, blue: 0.88),
                Color(red: 0.68, green: 0.72, blue: 0.70)
            ]
        }
    }
    
    var highlightColor: Color {
        switch self {
        case .redSandalwood: return Color(red: 0.92, green: 0.55, blue: 0.42)
        case .cartoonMuyu: return Color(red: 0.98, green: 0.90, blue: 0.76) // 原图温润顶光暖白木光
        case .emeraldJade: return Color(red: 0.72, green: 0.98, blue: 0.84) // 翡翠通透莹光高光
        case .whiteJade: return Color.white
        }
    }
    
    var rimLightColor: Color {
        switch self {
        case .redSandalwood: return Color(red: 0.85, green: 0.38, blue: 0.25).opacity(0.4)
        case .cartoonMuyu: return Color(red: 0.96, green: 0.82, blue: 0.60).opacity(0.45)
        case .emeraldJade: return Color(red: 0.45, green: 0.90, blue: 0.62).opacity(0.6)
        case .whiteJade: return Color.white.opacity(0.6)
        }
    }
    
    var pitch: Float {
        switch self {
        case .redSandalwood: return 1.0
        case .cartoonMuyu: return 1.15
        case .emeraldJade: return 1.25 // 金玉交鸣、清越空灵的玉磬之音
        case .whiteJade: return 1.3
        }
    }
}

struct MuyuFloatingText: Identifiable {
    let id = UUID()
    let text: String
    var xOffset: CGFloat
    var opacity: Double = 1.0
    var yOffset: CGFloat = 0.0
    var scale: CGFloat = 0.8
}

// MARK: - 烧香数据模型
enum IncenseType: String, CaseIterable, Identifiable {
    case sandalwood = "老山檀香"
    case aloeswood = "奇楠沉香"
    case wormwood = "清心艾草"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var aromaDescription: String {
        switch self {
        case .sandalwood: return t("醇厚温润・疏肝解郁")
        case .aloeswood: return t("清雅通透・定心安神")
        case .wormwood: return t("草木清冽・辟秽舒心")
        }
    }
    
    var musicTitle: String {
        switch self {
        case .sandalwood: return t("《木音・疏肝解郁调》")
        case .aloeswood: return t("《兰亭序·角调疏肝乐》")
        case .wormwood: return t("《草木・午后微风》")
        }
    }
    
    var musicDescription: String {
        switch self {
        case .sandalwood: return t("五音疗法角调木音，古筝丝竹如春风化雨，舒畅肝气、疏解胸中郁结")
        case .aloeswood: return t("幽谷山涧清泉水声与轻柔竹笛，清心空灵")
        case .wormwood: return t("温暖日光草木微风与清澈琉璃风铃，舒缓午憩")
        }
    }
    
    var glowColor: Color {
        switch self {
        case .sandalwood: return Color(red: 1.0, green: 0.55, blue: 0.15)
        case .aloeswood: return Color(red: 1.0, green: 0.4, blue: 0.1)
        case .wormwood: return Color(red: 0.9, green: 0.65, blue: 0.2)
        }
    }
}

enum CenserStyle: String, CaseIterable, Identifiable {
    case bronze = "青铜炉"
    case purpleClay = "紫砂炉"
    case whitePorcelain = "白瓷炉"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var baseColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.35, green: 0.40, blue: 0.33), Color(red: 0.15, green: 0.20, blue: 0.16)]
        case .purpleClay:
            return [Color(red: 0.42, green: 0.24, blue: 0.18), Color(red: 0.20, green: 0.10, blue: 0.08)]
        case .whitePorcelain:
            return [Color(red: 0.92, green: 0.93, blue: 0.90), Color(red: 0.68, green: 0.72, blue: 0.70)]
        }
    }
    
    var trimColor: Color {
        switch self {
        case .bronze: return Color(red: 0.85, green: 0.72, blue: 0.40)
        case .purpleClay: return Color(red: 0.65, green: 0.40, blue: 0.25)
        case .whitePorcelain: return Color(red: 0.80, green: 0.82, blue: 0.85)
        }
    }
}

enum IncenseDuration: Int, CaseIterable, Identifiable {
    case min14_30 = 870
    case min5 = 300
    case min59 = 3540
    case continuous = 0
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .min14_30: return t("小憩 14分30秒")
        case .min5: return t("静心 5分钟")
        case .min59: return t("禅定 59分钟")
        case .continuous: return t("长明供奉")
        }
    }
}

// MARK: - 客服与打工人每日抽签数据模型
struct CustomerServiceFortune: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let good: String
    let bad: String
    let desc: String
    let color: Color
    
    var localizedTitle: String { title.localized }
    var localizedGood: String { good.localized }
    var localizedBad: String { bad.localized }
    var localizedDesc: String { desc.localized }
    
    static let allFortunes: [CustomerServiceFortune] = [
        CustomerServiceFortune(
            title: "上上签",
            good: "遇到天使客户, 准时休息下班, 一秒解决问题",
            bad: "无意义加班, 接连环夺命Call",
            desc: "运气爆棚！今天遇到的客户都超级好沟通，CSAT 满分预警，顺风顺水！",
            color: Color(red: 0.15, green: 0.78, blue: 0.35)
        ),
        CustomerServiceFortune(
            title: "大吉",
            good: "业务通畅, 见招拆招, 敏捷高效结案",
            bad: "喝水太多(没空离座), 语速过急",
            desc: "今日状态极佳！进线与咨询虽多但处理流畅自如，手感火热，成就感满满。",
            color: Color(red: 0.95, green: 0.50, blue: 0.12)
        ),
        CustomerServiceFortune(
            title: "中吉",
            good: "按时喝水吃饭, 知识库一搜即得, 同事默契配合",
            bad: "情绪过激, 独自背锅",
            desc: "平平稳稳、顺遂安稳的一天。遇到的小疑问都能在知识库里快速找到答案。",
            color: Color(red: 0.15, green: 0.65, blue: 0.95)
        ),
        CustomerServiceFortune(
            title: "小吉",
            good: "深呼吸伸懒腰, 趁空档时间多喝水放松",
            bad: "多管闲事, 焦虑内耗",
            desc: "虽有些许小波折，但总能化解顺畅。排班休息时间的咖啡与茶会格外醇香。",
            color: Color(red: 0.95, green: 0.70, blue: 0.15)
        ),
        CustomerServiceFortune(
            title: "中平",
            good: "保持专业微笑, 按部就班走标准流程",
            bad: "冲动挂线, 忘记开启静音",
            desc: "无惊无险，平稳渡过。稳扎稳打做好每一个标准动作就是今天最好的策略。",
            color: Color(red: 0.70, green: 0.72, blue: 0.75)
        ),
        CustomerServiceFortune(
            title: "逢凶化吉",
            good: "化干戈为玉帛, 获客户真诚点赞致谢",
            bad: "自我怀疑, 负面情绪蔓延",
            desc: "原本棘手的疑难升级案件在你的耐心与专业沟通下圆满化解，展现卓越专业素养！",
            color: Color(red: 0.68, green: 0.38, blue: 0.95)
        ),
        CustomerServiceFortune(
            title: "宜守平",
            good: "谨言慎行, 多喝温水, 保持平常心",
            bad: "与客户争执对线, 挑战超纲升级",
            desc: "今天可能会遇到几个刁钻疑难案件。记住：深呼吸，就事论事不内耗，下班后好好犒劳自己！",
            color: Color(red: 0.95, green: 0.32, blue: 0.28)
        )
    ]
}
