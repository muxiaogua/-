//
//  DeskRelaxModels.swift
//  放松
//
//  Created by apple on 2026/9/8.
//

import Foundation
import SwiftUI

// MARK: - 身体放松部位
enum DeskBodyPart: String, CaseIterable, Identifiable {
    case all = "全部循环"
    case eyes = "眼睛"
    case neck = "肩颈"
    case wrists = "手腕"
    case legs = "腿部"
    
    var id: String { rawValue }
    
    var localizedName: String {
        rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .all: return "figure.cooldown"
        case .eyes: return "eye.fill"
        case .neck: return "figure.mind.and.body"
        case .wrists: return "hand.raised.fill"
        case .legs: return "figure.walk"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .all: return Color(red: 0.35, green: 0.75, blue: 0.95)
        case .eyes: return Color(red: 0.35, green: 0.85, blue: 0.55)
        case .neck: return Color(red: 0.95, green: 0.65, blue: 0.25)
        case .wrists: return Color(red: 0.85, green: 0.45, blue: 0.85)
        case .legs: return Color(red: 0.45, green: 0.60, blue: 0.95)
        }
    }
}

// MARK: - 工位放松动作定义
struct DeskExercise: Identifiable, Equatable {
    let id: Int
    let part: DeskBodyPart
    let name: String
    let subtitle: String
    let duration: Int // 秒数
    let steps: [String]
    let breathingTip: String
    let iconName: String
    let visualType: ExerciseVisualType
    
    var localizedName: String { name.localized }
    var localizedSubtitle: String { subtitle.localized }
    var localizedSteps: [String] { steps.map { $0.localized } }
    var localizedBreathingTip: String { breathingTip.localized }
    
    static let allExercises: [DeskExercise] = [
        // 眼睛
        DeskExercise(
            id: 1,
            part: .eyes,
            name: "远眺深呼吸眨眼",
            subtitle: "缓解屏幕蓝光视疲劳",
            duration: 20,
            steps: [
                "将视线移开电脑屏幕，看向至少 6 米以外的窗外或远处",
                "保持匀速深呼吸，连续轻柔眨眼 10 次",
                "感受眼周睫状肌逐渐放松，干涩感减轻"
            ],
            breathingTip: "吸气时望向远方，呼气时轻柔眨眼",
            iconName: "eye.fill",
            visualType: .eyeBlink
        ),
        DeskExercise(
            id: 2,
            part: .eyes,
            name: "眼球米字环视",
            subtitle: "拉伸眼外肌，消除酸胀",
            duration: 25,
            steps: [
                "头部保持不动，双眼顺时针缓慢画大圆 3 圈",
                "接着逆时针缓慢画大圆 3 圈",
                "然后分别向左、右、上、下四个极端方向轻柔拉伸视线"
            ],
            breathingTip: "转动眼球时保持平稳呼吸，不要憋气",
            iconName: "circle.dashed",
            visualType: .eyeRoll
        ),
        DeskExercise(
            id: 3,
            part: .eyes,
            name: "掌心温敷闭目",
            subtitle: "促进眼部血液微循环",
            duration: 25,
            steps: [
                "双手用力快速对搓，直到掌心发热发烫",
                "将温热的掌心轻轻空心覆在双眼上（不要压迫眼球）",
                "在掌心的温暖与黑暗中彻底放松眼周肌肉"
            ],
            breathingTip: "感受掌心温热渗透眼眶，做 3 次缓慢深呼吸",
            iconName: "hands.sparkles.fill",
            visualType: .eyePalming
        ),
        
        // 肩颈
        DeskExercise(
            id: 4,
            part: .neck,
            name: "颈部左右侧向拉伸",
            subtitle: "松解斜方肌与颈侧紧绷",
            duration: 30,
            steps: [
                "端坐椅上，右手越过头顶轻放于左耳上方",
                "头部缓缓向右侧倾斜，感受左侧颈部舒适拉伸，保持15秒",
                "换左手放于右耳上方，反向拉伸右侧颈部15秒"
            ],
            breathingTip: "呼气时加深侧向伸展，避免耸肩或用力过度",
            iconName: "arrow.left.and.right",
            visualType: .neckSideStretch
        ),
        DeskExercise(
            id: 5,
            part: .neck,
            name: "低头含胸与后仰展颈",
            subtitle: "拯救前倾富贵包",
            duration: 25,
            steps: [
                "呼气时下巴向胸口靠近，拉伸后颈与上背部，保持5秒",
                "吸气时头部缓慢后仰，下巴朝向天花板，拉伸颈部前侧",
                "来回缓慢交替重复 4-5 次"
            ],
            breathingTip: "动作极其缓慢轻柔，切勿猛甩颈部",
            iconName: "arrow.up.and.down",
            visualType: .neckUpDown
        ),
        DeskExercise(
            id: 6,
            part: .neck,
            name: "沉肩双向大绕环",
            subtitle: "激活肩胛骨，告别圆肩",
            duration: 25,
            steps: [
                "双臂自然下垂，双肩用力向上耸起贴近耳朵",
                "自前向后大幅度画圆绕动 5 圈，感受肩胛骨向中间靠拢",
                "再由后向前逆向画圆绕动 5 圈"
            ],
            breathingTip: "耸肩时深吸气，绕环下沉时深呼气",
            iconName: "arrow.triangle.2.circlepath",
            visualType: .shoulderRoll
        ),
        DeskExercise(
            id: 7,
            part: .neck,
            name: "后脑抱头仰颈扩胸",
            subtitle: "打开胸椎，改善驼背",
            duration: 30,
            steps: [
                "双手十指交叉，托住后脑勺，手肘向两侧尽量打开",
                "头部微微向后用力顶手掌，手掌给予适度前推阻力",
                "胸口上提挺拔，感受后颈肌群发力与胸腔舒展"
            ],
            breathingTip: "保持背部挺直，深长匀速呼吸",
            iconName: "figure.mind.and.body",
            visualType: .neckPosturalChest
        ),
        
        // 手腕
        DeskExercise(
            id: 8,
            part: .wrists,
            name: "键盘手腕上下屈伸",
            subtitle: "预防腱鞘酸胀与鼠标手",
            duration: 25,
            steps: [
                "伸出右臂，手掌立起指尖朝上，左手轻拉右手指尖向身体靠拢",
                "保持10秒后，换指尖朝下，轻拉手背向内折叠拉伸10秒",
                "换左手臂重复上述屈伸动作"
            ],
            breathingTip: "保持手肘伸直，手腕感受温和牵拉感",
            iconName: "hand.raised.fill",
            visualType: .wristFlexion
        ),
        DeskExercise(
            id: 9,
            part: .wrists,
            name: "祈祷式反压与手腕绕圈",
            subtitle: "释放掌横韧带压力",
            duration: 25,
            steps: [
                "双手胸前合十如祈祷式，掌根紧贴并缓缓下压至手腕水平",
                "保持5秒后，双手十指交叉，进行“无限符号∞”顺逆旋转绕环",
                "最后快速用力张开手指弹动 10 次"
            ],
            breathingTip: "下压时呼气，旋转时保持自然呼吸",
            iconName: "hands.clap.fill",
            visualType: .wristPrayerRotate
        ),
        
        // 腿部
        DeskExercise(
            id: 10,
            part: .legs,
            name: "坐姿单腿抬升回勾",
            subtitle: "消水肿，紧致大腿肌群",
            duration: 30,
            steps: [
                "端坐在椅子前 1/3 处，后背挺直不靠椅背",
                "将右腿缓慢向前抬起至与地面平行，脚尖用力向身体回勾",
                "保持大腿发力紧绷 10 秒后放下，换左腿重复"
            ],
            breathingTip: "抬腿时呼气紧绷核心，放下时吸气",
            iconName: "figure.walk",
            visualType: .legLiftExtend
        ),
        DeskExercise(
            id: 11,
            part: .legs,
            name: "隐形提踵踮脚尖",
            subtitle: "工位小腿泵，加速下肢血流",
            duration: 25,
            steps: [
                "双脚平放地面，膝关节呈90度",
                "双脚后脚跟用力向上抬起，以前脚掌着地踮起最高点，保持2秒",
                "脚跟落地，迅速将脚尖向上勾起，连续交替循环 15 次"
            ],
            breathingTip: "节奏轻快稳定，感受小腿肌肉收缩与舒张",
            iconName: "arrow.up.circle.fill",
            visualType: .legHeelRaise
        ),
        DeskExercise(
            id: 12,
            part: .legs,
            name: "脚踝顺逆时针大画圆",
            subtitle: "松解久坐僵硬脚踝",
            duration: 25,
            steps: [
                "右脚稍微悬空，以脚踝为轴心，脚尖在空中画大圆",
                "顺时针旋转 8 圈，逆时针旋转 8 圈",
                "换左脚脚踝重复顺逆时针画圆"
            ],
            breathingTip: "动作幅度尽量做大，感受踝关节充分活动",
            iconName: "circle.circle",
            visualType: .legAnkleRoll
        )
    ]
}

enum ExerciseVisualType {
    case eyeBlink
    case eyeRoll
    case eyePalming
    case neckSideStretch
    case neckUpDown
    case shoulderRoll
    case neckPosturalChest
    case wristFlexion
    case wristPrayerRotate
    case legLiftExtend
    case legHeelRaise
    case legAnkleRoll
}
