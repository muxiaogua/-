//
//  ChorusFAQSyncService.swift
//  团队工作台
//

import Foundation
import Combine
import AppKit

public struct ChorusFAQEntry {
    public var pageId: String
    public var category: String
    public var subCategory: String
    public var question: String
    public var answer: String
}

@MainActor
public class ChorusFAQSyncService: NSObject, ObservableObject {
    public static let shared = ChorusFAQSyncService()
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncResult: String?
    @Published public var lastSyncTime: Date?
    
    private let lastSyncTimeKey = "workbench_chorus_faq_last_sync_time"
    
    public override init() {
        super.init()
        self.lastSyncTime = UserDefaults.standard.object(forKey: lastSyncTimeKey) as? Date
    }
    
    /// Pre-compiled Knowledge Base entries for Chorus
    public static let allEntries: [ChorusFAQEntry] = [
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "联系与转接",
            question: "如何通过 IVR 联系 RCC",
            answer: "中国大陆：4006668800 - 1（隐私协议） - 1（普通话） - 2（官网订购/订单）\n台灣：0800020021 - 3（產品訂購）；0800020021 - 4（已有訂單咨詢）\n香港：800908988 - 1（产品订购）；800908988- 4（已有订单咨询）\n\n如果需要转接客户的的电话至 RCC，请在转接 RCC 前告知顾客正确联系 RCC 的方式，以防转接时断线。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "联系与转接",
            question: "更改取货时间、更改取货人信息的请求",
            answer: "对于更改取货时间、更改取货人信息的请求，可以直接转接RCC （原则上不允许改取货人，具体咨询 RCC）"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "联系与转接",
            question: "RCC 案例记录方式",
            answer: "如果问题与售前请求有关，请使用以下分类记录案例：\n受影响的产品：非技术问题\n组件：与销售和服务相关\n问题：售前\n\n如果问题与活跃订单或售后问题有关，请使用以下分类记录案例：\n受影响的产品：非技术问题\n组件：与销售和服务相关\n问题：售后"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "我在官网已下单但还未发货，会按新价格收费吗？",
            answer: "您的订单价格以您下单时确认的价格为准，后续的价格调整不会影响您已提交的订单。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "我之前买了 MacBook，现在想退货换一台更高配的，可以按涨价前的价格退换吗？",
            answer: "关于退换货，我们会按照您原购买时的发票价格处理退款。不过，如果您希望重新购买新机型，新订单将以当前最新价格为准，我们无法保留历史售价。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "iPad 涨价是从什么时候开始的？",
            answer: "Apple 官网已对部分 iPad 产品的定价进行了调整，您可以随时在 apple.com/cn 查看当前最新价格。关于具体调价时间，建议以官网显示为准"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "为什么 iPad/Mac 要涨价？",
            answer: "目前我们暂无更多关于此次调价原因的详细说明，感谢您的理解。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "iPhone 会涨价吗？",
            answer: "目前尚未收到关于 iPhone 价格调整的官方通知，请以 apple.com/cn 的实时价格为准。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "我涨价前已经买了，之前提交了退货申请，现在想撤销退货，可以吗？",
            answer: "非常理解您的想法，退货请求一般情况下不支持撤销，但我可以尝试联系售后部门的专家， 结合您的订单状况看看如何协助您。\n-- 请提供订单号并转接 RCC 售后部门"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "我还没买，想确认一下现在的价格，还有没有其他优惠活动？其他产品也会涨价吗？",
            answer: "所有产品当前最新价格和优惠活动均已更新至 Apple 官网，您可以直接在 apple.com/cn 查看，暂无更多调价相关的官方说明。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "我涨价前在经销商买了 MacBook，还没收到货，经销商说要补差价或者取消订单，Apple 这边怎么说？",
            answer: "非常抱歉您遇到这样的情况。Apple 的价格调整针对的是 Apple 官方渠道（官网及直营店），经销商作为独立经营的合作伙伴，其与客户之间的订单约定由双方自行协商处理，Apple 无法直接介入或代为裁决。如果您希望进一步沟通，建议您优先与经销商保持联系，了解他们能提供的处理方案。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "涨价前我在经销商处已付款购买，正常情况下应该会发货吗？",
            answer: "Apple 官方价格调整不会影响经销商此前已确认的订单。建议您向经销商确认订单状态，以及发货时间承诺。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "价格变更查询",
            question: "涨价前1小时，直营店 Specialist 建议我退货后重新购买更高配的 MacBook Air，但现在价格涨了，我该怎么办？",
            answer: "非常抱歉您遇到这样的情况，也感谢您详细告知我们事情的经过。由于这笔交易发生在直营店，建议您携带相关购买凭证前往或联系当时的直营店，并与店长/主管进行沟通。直营店可以调阅您完整的购买记录，对当时的情况进行核查和判断，由他们来为您提供最合适的解决方案。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "新品发布",
            question: "购买新产品是否可以使用 Trade In 服务",
            answer: "中国大陆/台湾/香港 ：可以。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "新品发布",
            question: "顾客数量限制无法下单",
            answer: "中国大陆/台湾/香港 ：以官网的数量限制为准，或让客户联系 RCC 产品订购部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "新品发布",
            question: "咨询新产品店内何时有展示机",
            answer: "中国大陆/台湾/香港 ：店内样品一般在可售卖当日在店内展示，但是每家零售店的到货时间不一，请建议客户以到店情况为准。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "新品发布",
            question: "新品正式发售当日，能否直接前往 ARS 现场购买新品？",
            answer: "客户可使用 APU: Apple Store pickup (到店取货) 的方式购买，根据产品页面显示查看Apple Store 零售店供货情况。如果页面显示目前暂不提供 Apple Store 零售店取货服务，建议客户改日再试或选择在线订购送货上门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "咨询新品购买时间/产品配置/性能",
            answer: "中国大陆/台湾/香港： 建议客户留意官网产品页面信息。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "已下架/降价产品购买",
            answer: "中国大陆/台湾/香港： 官网已下架，可让客户联系零售店询问店内库存情况但不可保证一定有货。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "购买及支付方式咨询",
            answer: "中国大陆/台湾/香港： 以官网可见的购买支付方式为准。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "顾客咨询如何加入年年焕新计划（售前）",
            answer: "中国大陆： 只需购买指定新款 iPhone，并在同一笔交易中加购 AppleCare+ 服务计划即可。本计划在中国大陆的 Apple Store 在线商店及零售店提供（Apple Store 天猫官方旗舰店不参加）。 参照 https://www.apple.com.cn/shop/iphone/iphone-upgrade-program 。\n台湾/香港： 没有年年焕新服务。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "顾客去年在店铺购买 iPhone 的同时添加了 AC+，今年可在官网焕新吗？",
            answer: "中国大陆： 无论通过在线还是到店加入本计划，都可从两种方式里任选一种进行升级换购。\n台湾/香港： 没有年年焕新服务。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "顾客在官⽹⽆法查询到年年焕新的资格",
            answer: "中国⼤陆： 如果客户是在 Apple Store 零售店参与本计划，请客户联系零售店；如果客户在 Apple Store 在线商店参与本计划，请让客户准备好之前的订单号，随后转接 RCC 销售⽀持部门。\n台湾/⾹港： 没有年年焕新服务。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "中国大陆官网上的新款 iPhone Air 专用 MagSafe 电池 是否为 3C 认证？",
            answer: "是的，3C 认证标识会在机体上体现。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "Apple Watch SE 3 / Series 11 / Ultra 3 是否支持快充？",
            answer: "Apple W atch SE 3 约 1.5 小时最多可充至 80% 电量。\nApple Watch Series 11 约 1 小时最多可充至 80% 电量。\nApple Watch Ultra 约 2 小时最多可充至 80% 电量。\n包装内附带 符合 WPT 标准的 Apple Watch 磁力充电器转 USB-C 连接线 (1 米) ，这款充电器不具备快速充电功能。\n参阅 关于符合 WPT 标准的 Apple Watch 在中国大陆和印度尼西亚的充电 （机型待更新）"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "iPhone 17e 是否兼容 MagSafe 配件？",
            answer: "iPhone 17e 可以使用 MagSafe 配件，并支持 MagSafe 充电功能。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "售前咨询",
            question: "哪些配件与新 iPad Air（M4）兼容？",
            answer: "iPad Air（M4）兼容与前一代 iPad Air（M3）相同的配件，包括 Apple Pencil Pro、Apple Pencil USB-C、iPad Air 的 Magic Keyboard 和 Smart Folio。\n有关兼容配件的完整列表，请参见 apple.com.cn 。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "用户在 Apple 官网购买了 iPhone Air，但发现天猫、抖音平台降价 2000 元，要求给出解决方案。",
            answer: "转至 RCC 进一步协助与处理。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "由于 618 期间各大电商平台促销活动，客户致电要求退差价。",
            answer: "Apple 官网未参与此类促销活动，因此不支持比价或退差价政策， 无需 转接 RCC。\n对于天猫、抖音的 Apple 官方店铺订单，引导客户直接联系对应平台的客服获取相关服务与协助。\n针对京东等第三方平台订单，由于各销售渠道的客服与价格政策相互独立，请引导客户联系相应第三方平台的官方客服寻求解决方案。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "已取消的订单可以恢复吗？",
            answer: "不可以 - 重新下单"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "重新看发货周期",
            answer: "无需转接RCC"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "国家补贴活动订单送货规则",
            answer: "购买后，你将无法更改送货地址或发票类型。你需要配合快递员完成必要步骤，如现场开箱、激活产品及拍照存档。\n进一步了解国家补贴活动"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "顾客收到短信/邮件说明新品订单地址有问题，需要三日内确认，否则可能延迟或退回包裹，但顾客确认地址正确无误。",
            answer: "先告知客户可以按照邮件回复补充信息即可（可能之前客户对于信息完整性的填写理解和RCC系统要求有点出入），如果问题无法解决再按需转接RCC。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "下单后顾客订单查询页面显示订单未付款/未显示订单/无法自行取消订单/不显示取消订单按钮/修改订单",
            answer: "中国⼤陆/台湾/⾹港：\n在订单量较大的发售活动期间，订单会花更长时间才会显示在系统中，并且订单后续的状态需要一些时间同步，请顾客耐心等待。\n如果顾客要求修改/查询/反馈相应的订单情况，可告知顾客，由于订单量较大，查询和修改订单功能需要一些时间同步和更新。请顾客可以后续尝试访问“在线自助服务”并修改订单，或是晚些时候再联系 Apple。\n非NPI期间：\n建议顾客登录订单状态页面查询最新状态。如果顾客还有相关订单疑问，请转接至 RCC 销售支持部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "发货/订单到货时间确认/顾客催促订单发货",
            answer: "中国大陆/台湾/香港：\n在我们收到付款且系统向顾客发送订单确认电子邮件前，发货和送货日期仅为参考日期。请顾客查看官网订单查询页面，查看到的送货日期就是是下单时可交付最早的送货日期，请顾客耐心等待订单后续交付。\n我们不能帮顾客加急，准确的发货时间请以含有物流单号信息的发货邮件或 iMessage 信息消息为准。请勿揣测或评价 Apple 的发货顺序，例如: 先买先发等。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "更改产品颜色/容量/地址",
            answer: "中国大陆/台湾/香港：\n仅限订单正在处理状态下的修改，如果还未收到发货通知，可以尝试通过 订单列表 页面在线修改送货详细信息。\n修改订单会影响发货时间，在订单量较大的发售活动期间，不建议顾客针对订单修改。如果无法自助修改，请联系 RCC。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "顾客要取消订单",
            answer: "中国大陆/台湾/香港：\n可告知客户前往官网查看订单自行操作(如果订单显示还在处理中-顾客可以直接取消，订单已准备发货-顾客无法操作，订单显示已发货-顾客可以在收到货之后在订单页面中自己点击申请退货), 如果顾客表示自己在页面上无法操作，联系 RCC 销售支持部门。\n注意: 香港订单需要退货会收取15%费用。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "顾客表示自己已经取消订单，想询问退款时间",
            answer: "请顾客登录 Apple 官网查看订单页面的付款方式，并引导顾客去相应地区的以下页面，查询相应付款方式的退款时间。\n中国大陆: https://www.apple.com.cn/shop/help/returns_refund\n台湾: https://www.apple.com/tw/shop/help/returns_refund\n香港: https://www.apple.com/hk-zh/shop/help/exchange_return"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "顾客表示自己是送货上门的订单想更换成到店取货",
            answer: "我们无法协助客户更改取货方式。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "客户反馈下单之后重复提交了付款，或者发现重复扣费的情况",
            answer: "如果顾客确认其重复提交了付款，告知顾客在 Apple 处理该订单的付款后(即订单更新成正在处理状态)，退款将自动触发并处理，顾客可以根据链接中订单的付款类型了解退款时间安排。\n中国大陆: https://www.apple.com.cn/shop/help/returns_refund\n台湾: https://www.apple.com/tw/shop/help/returns_refund\n香港: https://www.apple.com/hk-zh/shop/help/exchange_return"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "发票请求 （Apple Store 在线商店购买）",
            answer: "重要\n可以参考 https://www.apple.com.cn/shop/help/invoice 提供基本信息。\n询问客户是否在下单时勾选/填写了发票。\n如果有，请建议客户在 apple.com.cn/store 上查看他们的订单历史记录，以获取过去 18 个月内的收据副本/发票。如果客户无法找到相应收据/发票，请联系销售支持部门。不要设定预期。( 124695 )。\n如果没有，请建议客户优先使用以下自助服务。若客户拒绝，请请联系销售支持部门。不要设定预期。( 124695 )\nNEW 微信 Apple 服务号：客户可使用 “向我提问” 功能，然后输入关键词 “发票”，就可以收到申请发票补开和换开相关的自助指引。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "天猫 Apple Store 官方旗舰店国家补贴活动中的发票信息",
            answer: "对于天猫 Apple Store 官方旗舰店 北京地区 销售的产品，序列号信息会印在发票上，发票销售方信息为 Apple 。\n对于天猫 Apple Store 官方旗舰店 非北京地区 销售的产品： 发票上所包含的信息，根据不同省份的要求会有所不同。 对于一些省份，序列号信息不会印在发票上。 发票销售方信息为 第三方托管公司 。 请参考产品详情页面以 查看开票服务提供公司和营业执照列表"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "订单管理",
            question: "抖音/天猫 Apple Store 官方旗舰店订单",
            answer: "抖音 Apple Store 官方旗舰店 与 天猫 Apple Store 官方旗舰店 都是我们的官方直营渠道，如果相关渠道购买产品的客户来电咨询订单相关问题，请指引客户联系相应平台客服，无需转接 RCC。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "Apple Trade In",
            question: "查询 Trade-in 状态 (申请 Trade-in 后客户询问具体状态: 上门取件时间/取件状态/物流跟踪等。)",
            answer: "请客户登录 Trade-in 订单页面跟踪以及更改基本信息和状态： https://secure.www.apple.com.cn/shop/order/list 。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "Apple Trade In",
            question: "我的设备可以折抵多少钱",
            answer: "这取决于设备及其型号、制造商和状况。你只需回答几个关于你设备的问题，我们就会给出折抵金额估价。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "Apple Trade In",
            question: "收到了经过调整的折抵金额报价",
            answer: "当你的设备状况与你的描述不符时，我们会调整折抵金额报价。如果调整后的金额低于最初的估价，你可以选择接受或拒绝新的金额。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "Apple Trade In",
            question: "我需要交回配件才能全额获得折抵优惠吗？",
            answer: "你不必交回充电器、连接线、保护壳和表带这些配件，但只要你愿意，也可以将它们交给我们，我们会进行负责任的回收处理。但是，如果之后你取消了折抵换购，这些配件将无法再退还给你。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "Apple Trade In",
            question: "14 天之内产品更换请求",
            answer: "建议客户直接联系“购买地”"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "到店取货订单要求更改取货时间、更改取货人信息",
            answer: "转接 RCC"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "ARS 能否为官网购买的配件（手机膜）等提供服务支持？",
            answer: "零售店里有两种版本的贴膜：\n和 Apple Online Store 一样的盒装版，客户可自行操作（此版本内含贴膜辅助工具）。\n零售店售卖的专有版本，需要配合店内的贴膜机一起使用。\n注意 ：如果客户有购买了前者盒装版本后想前去零售店要求协助，请告知客户可以跟随说明书自行安装，零售店无法协助贴膜"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "咨询价格保护",
            answer: "中国大陆/台湾/香港：\nApple 在客户收到产品之日起 14 个日历日内降低任何Apple 品牌产品的价格，可以联系 RCC 销售支持部门，申请退还所支付的价格和当前销售价格之间的差额，或者换取抵扣额。客户必须在价格变更后 14 个日历日内联系 RCC 销售支持部门 ，方可收到退款或抵扣额。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "已下架/降价产品的超期退换货",
            answer: "中国大陆： 参照 https://www.apple.com.cn/shop/help/returns_refund 官网退货退款政策。不支持超期退换货。\n台湾： 参照 https://www.apple.com/tw/shop/open/salespolicies 符合退货条件的产品，请于取得产品之日起十四个日历日内办理退货申请。 零售店购买的产品不支持退货。\n香港： 参照 https://www.apple.com/hk-zh/shop/open/salespolicies 所有于香港Apple Store 购买的产品均不可退货或更换。仅当货品属于问题产品，才可视为例外情况予以更换。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "顾客可以选择哪些送货方式？何时能收到商品？",
            answer: "中国大陆/台湾/香港：\n预计送达日期根据商品供应情况和你选择的送货方式估算得出。下单后，你会知道最终确认的送达日期。\n所有在线订单均可享受免费标准送货服务。根据你所在的位置，你的订单可能符合 Apple Store 零售店取货的条件。你可以在结账时直接选择前往附近的Apple Store 零售店取货。\n通过 apple.com.cn 下单订购，只能发货至购物时所在的国家或地区。请按照你希望产品送达的国家或地区，访问相应的在线商店购物。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "物流异常，产品未按时送达",
            answer: "中国大陆/台湾/香港：\n告知客户前往官网查看订单最新发货状态或联系 RCC 销售支持部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "客户反馈无法在 Apple Store App 中绑定银联卡作为 “主要付款方式”",
            answer: "此问题为预期现象，在绑定付款方式的页面中会提示接受的付款方式为 “Visa, Mastercard”，不包括 “银联”，所以可以指引客户使用 “Visa, Mastercard” 的银行卡进行绑定。\n可以提醒客户 Apple Store App 的付款方式除了绑定银行卡，还可以选择 Apple Pay、支付宝、微信支付等。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "其它",
            question: "顾客咨询到店取货需要携带哪些信息",
            answer: "请顾客查看以下链接，获取到店取货的注意事项。\n中国大陆: https://ww.apple.com.cn/shop/help/shipping_delivery\n台湾: https://www.apple.com/tw/shop/help/shipping_delivery\n香港: https://www.apple.com/hk-zh/shop/help/shipping_delivery"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "零售店 AVP 体验预约：何时可以进行预约体验？",
            answer: "中国大陆 / 香港 / 日本： 请在官网进行预约或联系 RCC 预约。\n新加坡： 请在官网进行预约或联系 RCC 预约。\n台湾 ：请在官网进行预约。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "购买蔡司镜片时是否需要提供验光处方，以及验光处方是否有特殊要求？",
            answer: "中国大陆/香港： 顾客可以在 付款 结束后 手动输入验光处方 ，不需要提供验光单。\n台湾 ：客户可以下单结帐后将有效的处方上传至蔡司。也可以在稍后收到的电子邮件中按指引上传所需的处方资料。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "购买蔡司光学插片后，何时输入处方信息？ 如何查看已添加的处方信息和插片序列号？",
            answer: "对此， Internal SS Team 为 AVP Advisor 准备了详细的图文介绍，请点击 专题：Vision Pro 蔡司光学插片购买和查询指引 查看 Slack 画板。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "不存在质量问题的情况，是否支持 14 天退换货？是否区分客户有没有定制镜片？",
            answer: "中国大陆: https://www.apple.com.cn/shop/help/returns_refund 建议顾客前往订单页面自行操作，若顾客表示无法在页面上操作，联系 RCC 销售支持部门。\n台湾 ： https://www.apple.com/tw/shop/help/returns_refund 建议顾客前往订单页面自行操作，若顾客表示无法在页面上操作，联系 RCC 销售支持部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "蔡司镜片退换货问题：蔡司镜片定制周期为 30 天，在客户生成订单后，收到镜片前能否进行镜片度数修改？如果可以修改，多少天内可以修改？",
            answer: "联系 RCC 销售支持部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "顾客是否可以针对配件进行单独的换货处理，例如：遮光垫、遮光罩等。",
            answer: "建议顾客前往订单页面自行操作，若顾客表示无法在页面上操作，联系 RCC 销售支持部门。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "AVP 的 AC+ 是否包含同步购买的蔡司镜片？",
            answer: "不包括，官网原文：“AppleCare+ 服务计划的意外损坏保修范围不含原包装之外的配件，也不含用于受保障设备的第三方配件 (包括但不限于处方镜片或其他矫正镜片)。” https://www.apple.com.cn/shop/buy-vision/apple-vision-pro"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "AVP 取货政策",
            answer: "提交订单时选择取货方案，AVP 可以选择在 ARS 取货，确认后无法更改门店，若需要更改请重新购买。\n蔡司镜片仅支持快递寄送，无法支持到店取货。"
        ),
        ChorusFAQEntry(
            pageId: "5530436",
            category: "RCC 常见场景",
            subCategory: "AVP",
            question: "Apple Vision Pro 和配件国际服务策略",
            answer: "Apple Vision Pro 和配件 : Apple Vision Pro 和配件的服务在 那些已发售此产品 的国家和地区提供。\n蔡司光学插片 : 蔡司光学插片不提供国际服务。客户必须在他们购买光学插片的同"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "常规问题的维修时间和维修方案预期，比如更换屏幕、更换电池是否需要返厂？部件供货 (库存) 情况？是否需要返场？若店内维修大约需要多久？",
            answer: "客户针对维修方案的讨论，建议都是在客户完成实际店内的诊断后，进行维修服务的同事会根据诊断的结果，提供最终的方案和维修时长的预期。无需致电零售店。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "维修期间是否可以提供备用机？有什么条件？",
            answer: "符合三包或保修范围内的出现的故障并且需要返厂，会提供备用机，具体是否符合需要在门店诊断完成确认。\n返厂维修直接寄给客户的情况，无法提供备用机。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "异地服务：外国设备能否维修，以及外国购买的 AC+ 能否使用？",
            answer: "根据当地法律法规和功能范围，需要在店内运行诊断和检测后，才能确认，若能维修，才可以使用 AC+ 服务。具体以店内检测为准。无需致电零售店咨询。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "客户想要提前确认无购买凭证是否能够维修？",
            answer: "门店会根据现场检测情况来确定，无法提前确认，无需致电零售店。（请勿完全拒绝客户）\n\n零售店会尝试先帮助客户返厂，但是有可能后续会要求补充发票。（此预期零售店也会告知客户）"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "零售店能否接受客户补开的发票？",
            answer: "可以指引客户先前往店内确认是否需要补开发票。（请勿设置过高预期）"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "零售店协助客户成功订购部件后，若客户无法按约定时间前往维修，应如何向客户设置预期？",
            answer: "若需要维修的设备在客户手中，在部件到达且零售店联系客户后 (邮件或短信)，客户有五个工作日的时间前往维修。如果客户无法在五天内前往，零售店会在重新分配之前通知客户。\n如果客户确定会错过截止日期，请向客户说明，当客户有空时，零售店可以再次帮助他们重新订购，不要因此致电零售店。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "在线预约没有合适的时间，客户咨询现场排队情况，提供怎样的预期会比较合适？",
            answer: "可以优先指引客户前往 ASP 处理，若客户坚持前往零售店排队，请告知预期：预约前往会比较有保障，如果没有预约直接前往，我们店内的同事也会根据当天的情况尽力帮你解决问题，但等待时间有可能较长，具体情况需要到店之后和店内的同事再确认。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "客户表示已经自行预约 Genius Bar 维修，但是没有收到确认信息或邮件时如何处理？",
            answer: "在 Core 中协助确认，若依然没有则协助客户重新预约即可。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "Apple Online Store 订单线下取货规则：能否更换取货人？未携带身份证能否有替代验证方案？客户未按照约定时间取货，零售店会保留几天？",
            answer: "理论上不可以更换取货人，若客户遇到特殊情况，并且有原取货人和现取货人的双方有效证件，可以尝试在店内沟通。（请勿提供确定的预期）\n未携带身份证时，可以提供其他有效证件时，可以尝试在店内沟通。（请勿提供确定的预期）\n保留时间范围无法确认，详情参考： Apple 取货政策。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "新品发售期间，零售店何时可以直接到店购买新品，是否只能到店咨询？",
            answer: "可以指引客户联系 RCC。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "咨询新产品店内何时有展示机？",
            answer: "店内样品一般在可售卖当日在店内展示，但是每家零售店的到货时间不一，请建议客户以到店情况为准。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "新品正式发售当日，能否直接前往 ARS 现场购买？",
            answer: "建议客户使用 APU: Apple Store pickup (到店取货) 的方式进行购买。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "客户常规咨询 ARS",
            question: "维修完成后，若客户无法按照约定取回设备，ARS 通常会如何处理？我们应如何建议客户？",
            answer: "建议客户尽可能在 60 天内 前往 ARS 取回设备， 无需预约，无需致电 ARS。\n如果客户在中国大陆，香港，澳门，台湾，需要送修人本人携带有效证件前往 ARS 取回设备，不能指定其他人代为取回设备。\n\n参考资源：\n如您未能在Apple通知您产品已完成检测或维修且可以领取的六十（60）天内，领回产品及支付所有费用，Apple会认为产品已被您弃置...此外，上述六十（60）天期限届满后，Apple可就被弃置产品向您收取5元/天的保管费..."
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "ARS 送修，查询维修进度。常规处理思路：",
            answer: "根据 CP400466 查看 Core 中的维修状态，向符合条件的客户提供信息。同时提醒客户后续可以通过维修状态查询链接自主查询。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "维修/订件进度咨询（返厂维修与店内维修）",
            answer: "返厂维修：根据 Core 中信息告知客户，零售店也看不到更多信息，请指引客户耐心等待并关注维修状态更新，无需致电零售店咨询。\n所有的返厂维修问题，一旦建单返厂，零售店没有控制权，无法对维修进行加速。请安抚客户并建议客户关注邮件通知，耐心等待，无需致电零售店咨询。\n\n店内维修：零售店通常会给客户设置预估的等待时间预期，可以询问客户并查看 Core 中零售店的备注信息，如果零售店看到和之前的预期不同，会主动电话联系客户，如果没有收到联系，则表示预期暂无改变，可以请客户耐心等待，无需致电零售店咨询。（如果客户错过了零售店的电话，可以建议客户耐心等待零售店的再次联系，直接回拨此号码会进入热线队列，通常在当天或第二天零售店还会再次联系客户。）"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "识别店内和返场维修：",
            answer: "方法一：可以查看维修状态详情进行区分。\n方法二：可以根据零售店的案例标题进行区分，比如 “Apple Store 商店寄送维修（退还至商店）” 这是一个返厂维修；“Apple Store 商店维修” 这是一个店内维修。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "ARS 对维修进度的处理流程： 零售店处理店内维修 / 返厂维修的问题时，会向客户设置怎样的进度预期？",
            answer: "系统默认 7~14 天，客户可以通过 Apple 支持查询，时间或维修状态如果有变化，建议关注邮件通知，如果客户在店内留下手机号（客户可选），也会有短信通知。收到维修完成通知后，可以来店里取机。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "零售店是否会分享维修进度查询链接给到客户？（比如邮件中是否已包含？）",
            answer: "请指引客户查看邮箱中是否有 Apple 发出的维修通知邮件，如果有可以直接查看，邮件中已包含查询维修状态链接，如果没有可以分享查询方法。（通常在工厂收到维修产品后发出此封邮件）"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修进度",
            question: "维修中的案例，零售店是否会主动联系客户告知维修进度？什么类型的维修会主动联系客户？联系的频率是怎样的？",
            answer: "店内维修：有任何更新或改变，客户可以关注邮件和电话。若电话没有接听到，零售店会持续尝试联系。\n返厂维修：维修结束并到店取机的情况，可能会电话联系客户，客户也可以在 Apple 支持或邮箱中查询进度。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "客户致电要求协助处理零售店维修产生的维修争议问题，Apple 支持应如何处理？",
            answer: "常规处理思路：了解事情经过，根据客户的描述和 Core 中的维修记录、零售店同事的备注信息，相信零售店同事的记录和判断，无需致电零售店对处理方案二次核实。向客户解释说明 Apple 的维修政策。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "对 CS Code 的考量",
            answer: "参考 CP400443 考量是否符合 CS Code 的条件，同时，需要参考 Core 中零售店同事的备注信息，如果零售店的维修笔记已经标注维修方案，或记录了是否需要付费的状态，请尊重零售店的判断，请勿提供 CS CODE。（如果有极端的状况请联系经理讨论）\n考量以上信息拒绝提供 CS Code 之后，如果遇到客户表述是零售店指引他来获取 CS Code，请直接拒绝，无需致电零售店核实，并将此案例编号提供给您的经理。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "如何了解零售店处理细节？",
            answer: "在 Core 中选择产品后找到对应的维修案例。 Apple Store 的备注信息会包含在维修案例中，也可能在 Advisor 创建的案例或独立的案例中。 查看所有关联案例中，查看之前 Advisor 的沟通处理记录。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "T2 开具 CS Code 后，零售店多久可以查询并开始使用 CS Code协助客户？",
            answer: "系统有显示即可使用，建议 AppleCare 同事在提供 CS Code 之后，刷新当前案例，确认客户的序列号已绑定 CS Code。（若问题不着急，也可以考虑建议客户第二天再去零售店维修）"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "当零售店处理维修争议类问题时，比如无法满足客户的维修要求，在店内的大致处理流程是怎样的？（升级路径）",
            answer: "所有的零售店执行的都是 Apple 的流程和标准，客户的维修需求只要是在相关标准范围内可达成的，零售店不会拒绝客户的要求。\n店内升级流程：接待的同事可以升级至经理（或者 Lead，不是 Store Leader）， 经理和 Lead 是有一定例外权限，但只仅限于维修金额折扣或 CS CODE（在系统允许创建的情况下），维修方式是返厂还是店内维修，需要以系统显示为准，无法提供任何特例。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "零售店是否有任何场景需要指引客户联系 400 处理硬件维修类问题？",
            answer: "通常不会，涉及维修类的问题仅当客户设备存在激活锁问题或保修期异常等情况，才可能指引客户联系 AppleCare 线上支持。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "零售店开具 CS Code 的流程是怎样的？参考标准是什么？",
            answer: "符合规程需要申请的情况：零售店会联系 CSS 申请。\n其他场景的 CS CODE，零售店会根据系统显示能否提供为准。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "维修完成后若设备外观有磕碰，是否有相关指引和建议？",
            answer: "与客户确认是返厂维修还是店内维修，是否取机，是否签字确认。同时，参考 Core 中维修记录和零售店同事的备注信息，进行核对，无需致电零售店核实。\n所有维修提取，无论是返厂还是店内维修，取机时都会邀请客户先针对设备维修结果和外观等物理状态进行确认，客户需要签字确认，需要付费的部分也会确认后付费。\n取机后若客户坚持外观损伤存在，则可以直接前往 ARS，不需要预约。\n返厂维修：现场发现问题，零售店会联系 CSS，调取维修外观照片。\n店内维修：现场发现问题，零售店会协助客户直接解决。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 常规争议",
            question: "客户提出联系服务热线解决问题",
            answer: "Retail 回应思路：“很抱歉，我们无法为通过维修中心进行的维修提供替代解决方案。”"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "为什么我的产品未经维修就被退回了?",
            answer: "回应思路：“我们会对运送到维修中心的产品进行筛查，以确定维修资格和功能状况。有关您的具体维修信息，请查看退回产品随附的产品服务摘要。”\n处理思路：查看其他团队的维修记录和之前的沟通记录。与顾客一起查看确认函，以了解此产品未经维修被退回的具体原因。没有完成硬件维修的原因可能有很多。例如，没有发现问题、问题通过软件恢复得到解决，或者产品并非正品。务必查看维修中心提供的确认函。\nApple 支持流程：如果有争议，请遵循 CP400441\nRetail 流程：如果有争议，请使用标准 RTA 上报流程进一步核实。 (中国大陆服务被拒申诉 SDA 除外)"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "如何确定我的设备中是否有非正品部件?",
            answer: "回应思路：“我们会对运送到维修中心的产品进行筛查，以确定维修资格和功能状况。有关您的具体维修信息，请查看退回产品随附的产品服务摘要。”\n处理思路：不要对超出确认函范围的详细信息妄加猜测。有时，透露更多详细信息会涉及敏感信息，而且披露 Apple 的内部筛查流程或结果可能会被 NEU 利用。这些详细信息还可能会让顾客产生误解，并引起进一步的争议。鉴于此，请仅讨论维修确认函中的内容。\nApple 支持流程：如果有争议，请遵循 CP400441\nRetail 流程：如果有争议，请使用标准 RTA 上报流程进一步核实。 (中国大陆服务被拒申诉 SDA 除外)"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "我可以请求了解关于维修被拒的更多详细信息吗?",
            answer: "店内维修：\n回应思路：“我们知道当前的维修结果可能与您预期的不同。但我们可以确信的是，Apple 经过详细排查，包括进行故障诊断和目视检查，确定该产品不符合维修条件。我们的技术人员始终会遵循所有维修指南。如果你还有其他疑问，我们很乐意为你解答。”\nApple 支持流程：如果有争议，请遵循 CP400441\n\n邮寄维修和返厂维修：\n回应思路：“维修中心在产品服务摘要中提供了有关您的维修的信息。我们无法提供更多信息。”\nApple 支持流程：如果有争议，请先遵循 CP400441。如果造成问题的原因与顾客无关，那么技术顾问可以遵循 CP400443。\n\nRetail 流程 (邮寄维修和返厂维修)：如果有争议，请使用标准 RTA 上报流程进一步核实，不要引导顾客联系其他渠道，如 Apple 支持，因为技术顾问只能获取产品服务摘要中包含的相同信息。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "关于使用第三方维修服务，是否有任何准则?",
            answer: "回应思路：“我们建议向 Apple 授权维修商寻求支持，因为他们使用正品部件并已完成 Apple 认证。对于授权维修所使用的替换部件，还提供至少 90 天的保修服务。”\n处理思路：不要对第三方维修提供商是否使用正品部件、其工艺水准或可能提供的任何保修服务妄加猜测。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "为什么过了这么久才告诉我维修被拒?",
            answer: "回应思路：“维修中心会仔细地对你的产品进行全面诊断。我们的目标始终是及时完成高质量的维修，但评估是否需要硬件维修需要一些时间。我们非常重视你的反馈，并且一直在寻找在保持维修质量的同时缩短维修周转时间的方法。”\n处理思路：不要对维修中心执行的故障排除或诊断规程妄加猜测。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 维修被拒",
            question: "如何直接与维修中心沟通?",
            answer: "回应思路：“维修中心团队接受过对 Apple 产品进行故障排除和维修方面的培训，他们已提供产品服务摘要，并说明了拒绝维修的原因。我们理解这可能不是你期望的结果，但目前我们只能提供这么多信息。”\nApple 支持流程：如果有争议，请遵循 CP400441\nRetail 流程：如果有争议，请使用标准 RTA 上报流程进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 收费相关",
            question: "我邮寄设备后，为什么需要为额外的维修付费?",
            answer: "回应思路：“我们希望确保顾客在每次维修后能继续尽情享用他们的产品。在创建维修时，我们会对产品和报告的问题进行初步评估。不过，在维修过程中，如果发现其他故障或损坏，可能需要使用与最初预期不同的部件。根据具体情况，该维修可能在保修或 AppleCare 服务计划保障范围内。如果不在保障范围内，会提供保外费用报价。如果你拒绝授权，Apple 可能会不经维修就退回您的产品。”\nRetail 流程：不要引导顾客联系其他渠道，如 Apple 支持，因为技术顾问只能获取产品服务摘要中包含的相同信息。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 收费相关",
            question: "我怎么知道额外的损坏不是你们或快递员造成的?",
            answer: "回应思路：“我们会遵循明确的流程来确保所有产品在维修和运输过程中的安全。这包括使用单独的保护性包装和采取其他措施。”\nRetail 流程：如果对物流处理有争议，请上报至 CSS。如果对设备状况有争议，请使用标准 RTA 上报流程进行进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 收费相关",
            question: "我怎么知道浸液损坏不是由制造缺陷造成的?",
            answer: "回应思路：“Apple 采用严格的生产和制造测试流程，以确保我们的产品符合质量标准。就您的情况而言，Apple 对产品进行了全面检查，确定造成所报告问题的原因是浸液损坏，并且浸液损坏是由于未按相关 IP67/IP68 等级使用造成的。”\n处理思路：与顾客分享 Apple 网页上有关防水性及其如何适用于其设备的更多信息。\nRetail 流程：请查看 https://support.apple.com/en-sg/108039 如果有争议，请使用标准 RTA 上报流程进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 邮寄维修",
            question: "为什么我的维修无法在当前维修点完成?",
            answer: "回应思路：“一些维修可能需要当前维修点没有的专业设备、专业知识或部件。在这种情况下，您的设备将被转移到专门的维修中心，那里更适合处理特定维修需求。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 邮寄维修",
            question: "为什么设备退回后的状况比我发货时更糟? (被改装或已维修)",
            answer: "被改装 回应思路：“我们知道维修结果可能不符合您的期望。对于产品在维修过程中发生的任何损坏，如果是由于 Apple 或 Apple 授权服务提供商以外的其他方进行任何未经授权改装、维修或更换造成的，Apple 概不负责。”\n\n已维修 (保内维修 / 保外维修) 回应思路：“我们知道维修结果可能不符合您的期望。我们会遵循明确的流程来确保所有产品在维修和运输过程中的安全。这包括使用单独的保护性包装和采取其他措施。”\nRetail 流程：如果有争议，请使用标准 RTA 上报流程进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 邮寄维修",
            question: "为什么维修时间比 ARS 告知的时间要长?",
            answer: "回应思路：“我们的目标始终是及时完成高质量的维修，但需要一些时间来评估和诊断问题，然后完成所需的维修。通常，维修需要 7 到 15 个日历日才能完成。然而，各种外部因素或不可预见的情况可能会影响维修时间安排。例如，发现设备有其他问题或并发故障可能会延长交付时间。我们非常重视您的反馈，并且一直在寻找在保持维修质量的同时缩短维修周转时间的方法。我们会密切关注这一维修，并将最新进展告知你。”\nRetail 流程：确保密切关注维修，并及时将最新进展告知顾客。如果有原因不明的延迟，请上报至 CSS 或按照你所在团队的指引进行调查。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 重复维修",
            question: "维修后，我的设备仍然无法正常使用。该怎么办?",
            answer: "回应思路：“如有需要，我们会帮助您进行进一步的排查，解决存在的问题。我们希望确保顾客在每次维修后能继续尽情享用他们的产品。我们需要查看之前的维修备注并重新评估产品，以便确定后续步骤。”\n处理思路：查看之前的维修备注，如有需要，请重新评估并为顾客提供维修或预约支持。\nRetail 流程：核实原始维修是否有处理不当的情况。在可能的情况下，在店内完成二次维修，以便及时提供维修结果。\n店内维修：与相关团队成员分享反馈。\n返场维修：使用 MobileGenius 和 Repair Central 的反馈功能与维修中心分享反馈。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 重复维修",
            question: "既然是重复维修，为什么不向我提供全新的替换产品?",
            answer: "回应思路：“我们希望确保顾客在每次维修后能继续尽情享用他们的产品。我们的产品由经过严格测试的耐用材料制成，同时， 我们希望使用对环境影响较小的部件提供高质量的维修。我们会为 Apple 或 Apple 授权服务提供商完成的所有维修提供保修。”\n处理思路：始终为顾客提供符合 Apple 政策和当地法律法规 (如消费者权益保护法) 的结果，例如：根据中国或其他受影响市场的消费者权益保护法，如果设备在多次维修后仍然无法正常使用，并且情况符合 CL 更换标准，员工需要为顾客提交 CRU 请求。此为标准流程。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 重复维修",
            question: "我是否可以得到时间补偿?",
            answer: "回应思路：“我们理解这与您的预期不符，同时希望确保尽快让你的产品恢复正常。我们需要评估产品，并帮助确定后续步骤。”\nApple 支持流程：没有时间补偿。无法对顾客个人时间提供补偿。如果产品满足特定标准，可能会提供 CS 代码涵盖的维修。 有关其他方案，请查看 CP401287。\nRetail 流程：如果有争议，请与经理一起评估具体情况并确定后续步骤。除非维修规程中有具体指导，否则请不要引导顾客联系其他渠道。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "为什么没有人与我直接沟通服务计划相关事宜?",
            answer: "回应思路：“我们理解这与您的预期不符，同时希望确保您的 Apple 产品可以继续正常使用。有时，出于隐私考虑，Apple 可能没有联系信息或无权使用相应联系信息联系顾客。我们很乐意分享我们网页上关于服务计划的更多信息，并且现在可以为你解答相关问题。”\n处理思路：向顾客展示其产品对应的服务计划网页。解答任何问题，并根据需要提供后续维修步骤。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "这是产品制造问题，为什么服务计划还有时间限制?",
            answer: "回应思路：“我们理解这与您的预期不符，同时希望确保您的 Apple 产品可以继续正常使用。我们很乐意分享我们网页上关于维修计划的更多信息，并且现在可以为您解答相关问题。”\n处理思路：向顾客展示其产品对应的服务计划网页。解答任何问题，并根据需要提供后续维修步骤。\n注意：不要使用 “质量问题” 或 “缺陷” “召回”等词语。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "如何确定替换产品不会有同样的问题?",
            answer: "回应思路：“我们希望确保顾客在每次维修后能继续尽情享用他们的产品。我们的产品由经过严格测试的耐用材料制成，同时， 我们希望使用对环境影响较小的部件提供高质量的维修。我们会为 Apple 或 Apple 授权服务提供商完成的所有维修提供延期保修保障。”\n处理思路：始终为顾客提供符合当地法律法规和 Apple 政策的结果。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "为什么我的设备出现故障，却不在服务计划范围内?",
            answer: "回应思路：“经过全面的故障排除和目视检查，我们确认该故障不在服务计划保障范围内。我们知道这可能不符合您的期望。请让我们介绍可行方案，并与您一起查看我们的诊断结果。我们还可以了解下计划之外的维修方案。”\n处理思路：如果对诊断结果或功能测试有争议，请通过提供基于保修的解决方案来帮助解决问题。\nRetail 流程：如果对诊断结果或功能测试有争议，请使用标准 RTA 上报流程进行进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "我在社交媒体平台上看到有人得到免费维修或更换。为什么他们可以免费，而我不行?",
            answer: "回应思路：“造成相似故障的原因可能有所不同，此类情况存在细微差别。对我们来说，谨慎对待每种情况很重要，我们会全面诊断和评估交给我们维修的每件产品。请让我为您介绍维修资格条件，并一起讨论下诊断结果。我们还可以谈谈计划之外的维修方案。”\n处理思路：指出社交媒体上有很多内容，可能并不总是完全准确或以事实为依据。根据需要协助进行故障排除评估。\nRetail 流程：始终确保通过服务计划对产品进行全面评估，以确定维修资格。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修体验 - 扩展计划",
            question: "我知道有一个维修计划，我有相同的机型。我的设备是否有维修计划涵盖的问题? Apple 是否设计了有缺陷的产品? 有什么补偿方案或纠正措施?",
            answer: "回应思路：Apple 率先采用革命性技术，旨在改善全球各地顾客的生活，并致力于遵循严格的质量保证标准。Apple 通过有限保修服务和可选的 AppleCare+ 服务计划为产品问题提供保障，并尊重当地法律法规赋予用户的权益。我很乐意与您分享 Apple 网页上关于服务计划的信息。”\n处理思路：始终确保通过服务计划对产品进行全面评估，以确定维修资格。引导顾客访问相关服务计划的网页以获取更多信息。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "如果顾客为设备购买了 AppleCare+ 服务计划，该如何响应顾客的 WUR (整机更换) 请求?",
            answer: "回应思路：“我们希望确保顾客在每次维修后能继续尽情享用他们的产品。我们的产品由经过严格测试的耐用材料制成，同时， 我们希望使用对环境影响较小的部件提供高质量的维修。Apple 会针对设备确定合适的解决方案，并确保设备符合 Apple 标准。此外，我们还会为 Apple 或 Apple 授权服务提供商完成的所有维修提供保修。”\n处理思路：引导顾客访问 AppleCare 产品的网页，并分享其特定协议的益处。根据所在地和具体情况，益处可以是延期保修、优先电话支持，或不限次数的意外损坏保修服务 (会收取一定的服务费)。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "购买 AppleCare+ 服务计划后，为什么我仍然需要支付服务费?",
            answer: "回应思路：“您似乎对服务费有疑问，我很乐意为你提供有关您的 AppleCare+ 服务计划协议的详细信息。”\n处理思路：引导顾客访问 AppleCare 产品的网页，并分享有关其保障范围的详细信息。根据需要介绍需要付费的方案。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "我在保修期内报告了问题，但在保修期到期后才将设备送修。",
            answer: "回应思路：“我理解您的疑虑。请让我查看下支持请求历史记录，以确认相关详细信息。”\n处理思路：详细查看任何联系历史记录和任何支持请求备注，并确认向 Apple 报告问题的具体时间。\nApple 支持流程：请查看 CP400443。\nRetail 流程：参考知识库中的文章 117843 来评估是否应提供保修。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "保修期到期后有宽限期吗?",
            answer: "回应思路：“每种维修情况都有其特别之处。我们会全面诊断和评估交给我们维修的每件产品，以确定正确的保修范围。为了公平对待所有顾客，我们会根据有限保修、AppleCare 协议或维修计划以及当地法律法规规定的时间范围提供保修。\n处理思路：详细查看支持请求备注，确认向 Apple 报告问题的具体时间，并遵循下面的相应指引。此外，请说明我们会尽量为购买 AppleCare+ 服务计划或其他延期保修计划的顾客着想。查看并分享任何其他可行方案。\nApple 支持流程：请查看 CP400443。\nRetail 流程：参考知识库中的文章 117843 来评估是否应提供保修。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "软件更新导致出现硬件问题，为什么不在保修范围内?",
            answer: "回应思路：“我们从您那里了解到，该故障是在安装了一项软件更新后出现的。虽然软件不会造成硬件损坏，但软件更新后可能会出现预先存在的硬件问题。由于软件更新通常会提升性能和修复错误，我们建议执行更新。请让我运行诊断程序，并进行全面评估，以确定今天我们可以提供哪些帮助。”\n处理思路：务必查看相关维修指南，获取故障排除方面的协助。\nRetail 流程：如果对诊断结果或功能测试有争议，请使用标准 RTA 上报流程进行进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "我购买了 AppleCare+ 服务计划，为什么我的设备不在保修范围内?",
            answer: "回应思路：“每种维修情况都有其特别之处，这取决于使用情况和具体是什么故障。我们的团队和维修点会全面诊断和评估交来维修的每件产品，以确定正确的保修范围。最终结果以他们的回复为准。”\nRetail 流程：如果对诊断结果或功能测试有争议，请使用标准 RTA 上报流程进行进一步核实。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "为什么我的替换设备不是未开封的全新产品?",
            answer: "回应思路：“我们希望确保顾客在每次维修后能继续尽情享用他们的产品。我们的产品由经过严格测试的耐用材料制成，同时， 我们希望使用对环境影响较小的部件提供高质量的维修。我们会为 Apple 或 Apple 授权服务提供商完成的所有维修和 更换提供保修。”\n处理思路：始终为顾客提供符合当地法律法规和 Apple 政策的结果。\n注意：在中国，所有替换产品都是新产品，但没有销售包装和配件。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "AppleCare+ 服务计划退款请求",
            answer: "回应思路：“我理解你对 AppleCare+ 服务计划协议的疑虑。我们知道，AppleCare+ 服务计划的延期保修、优先支持和意外损坏保修服务物超所值。能否告知您的具体疑虑，以便我们可以一起找到合适的解决方案?”\n处理思路：务必尝试了解顾客的疑虑是什么，以及是否可以消除这些疑虑，而不是取消协议并退款。此外，请确保核实在提供计划保障的国家 / 地区，符合条件的 AppleCare+ 服务计划支持具体有哪些。\nApple 支持流程：当需要退款时，请按照标准规程引导顾客联系 AA。(CP401187)\nAA 流程：顾问需要核实序列号、来电者是否为协议所有者以及 AppleCare+ 服务计划购买渠道，并收集 POP，以便与顾客验证原付款方式。"
        ),
        ChorusFAQEntry(
            pageId: "7345748",
            category: "ARS OB 常规咨询",
            subCategory: "维修保障 - AC+",
            question: "如果顾客在 ARS 发起更换 (仅限设备)，并声称 AppleCare+ 服务计划缺失。",
            answer: "回应思路：“谢谢您告知我这一情况，请让我查看一下详细信息，了解具体经过。”\n处理思路：查看维修历史记录，了解顾客的原产品是否附带 AppleCare+ 服务计划。如果预期的协议转移尚未完成，请按照标准规程上报至 AA。(CP401187)\nAA 流程：如果顾客发起更换 (仅限设备)，则顾客应拨打热线电话，将 AppleCare+ 服务计划转移到新设备。 AppleCare+ 服务计划不会自动转移到新设备。"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "什么是 2026 ⾼校优惠活动?",
            answer: "Apple 在线教育商店的⾼校优惠活动，符合条件的设备包括：\n- 买 MacBook Air ( 13 英寸或 15 英寸) 或 MacBook Pro ( 14 英寸或 16 英寸)，可加购 AirTag 四件装享优惠。\n  * 购买指定款 Mac 时，可选择支付额外升级费用来升级为下列促销产品: AirPods 4, AirPods 4 (支持主动降噪), AirPods Pro 3。\n- 买 iPad Air (11 英寸或 13 英寸) 或 iPad Pro (11 英寸或 13 英寸)，可加购 AirTag 四件装享优惠。\n  * 购买指定款 iPad 时，可选择支付额外升级费用来升级为下列促销产品: Apple Pencil Pro, AirPods 4, AirPods 4 (支持主动降噪), AirPods Pro 3。\n  * 每个有资格的购买人购买符合条件的产品时，仅限搭配购买一件促销产品。\n\n💡 提示 ：天猫Apple Store 官⽅旗舰店的⾼校优惠活动略有不同，可访问天猫了解更多。"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "谁能享受这个优惠?",
            answer: "可享优惠包括在中国大陆的：高校在读生，刚录取的高校新生，代表子女购买的高校学生家长，公立或私立幼儿园、小学、中学和高校的教师及教职工，硕士、博士研究生。"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "2026 ⾼校优惠活动时间?",
            answer: "2026 年 7 ⽉ 16 ⽇⾄ 2026 年 8 ⽉ 27 ⽇"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "哪些⽅式参加⾼校优惠活动？",
            answer: "访问 Apple 在线教育商店⾃助下单\n拨打 Apple 订购热线 “4006668800 - 产品订购”\n天猫 Apple Store 官⽅旗舰店\nApple Store 零售店"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "客户如何进⾏购买资格验证?",
            answer: "当你在 Apple 在线教育商店或 Apple Store 零售店选购产品时，需通过支付宝 app 进行验证。\n支付宝学生验证目前仅支持中国大陆地区普通高等学校，且学籍状态为在籍的用户进行验证，港澳台及国外学校暂不支持学生验证。\n\n学生： 在支付宝 app 搜索 “支付宝学生验证”。\n教职工：可通过 “教师资格证验证” 或 “社保/公积金验证”。当你同意 “支付宝-芝麻工作证” 的身份授权请求后，即可选择验证方式。\n即将入学的新生：可进入 “新生专属验证” 并提交本人 2026 年高考录取通知书。\n\n⚠️ 提醒 ： 不同地区的资格验证要求可能有所不同，请以官网为准。"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "在活动开始前购买了指定款 Mac 或 iPad， 能否补差价？或者补 AirPods / Apple Pencil？",
            answer: "Apple Store：在活动开始后 14 天内，请指引客户联系购买门店处理\nApple Store Online：在活动开始后 14 天内，请协助客户转接 RCC\n天猫 Apple Store 官方旗舰店：在活动开始后 14 天内，请指引客户联系店铺客服进一步确认\n其他第三方店铺：请指引客户咨询购买方\n\n⚠️ 提醒 ： 若客户在 Apple Store/Apple Store Online/天猫 Apple Store 官方旗舰店购买，但是超出了退换货时 间几天，指引客户咨询/转接购买方， 请勿 提供更多预期。 退换货政策在不同购买地区可能有所不同，请客户联系购买方后确认。"
        ),
        ChorusFAQEntry(
            pageId: "8034582",
            category: "BTS 返校季",
            subCategory: "BTS 常见问题",
            question: "参加 2026 ⾼校优惠活动时，可以同时使⽤国家补贴优惠券吗？",
            answer: "不可以 。国家补贴⽆法与此次优惠同时使⽤。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "客户来电想要购买教育优惠的 AC+， Consumer Advisor 是否可以销售？",
            answer: "如果客户在 中国大陆或韩国 ，当客户请求提供教育机构个人 (EDU) 折扣时，Advisor 可通过 “工具”>“技术解决方案” 销售协议，无需确认模版 ID，无需升级 AA。目前，中国大陆支持教育机构个人 (EDU) 折扣产品包括 iPad/Mac/Display 系列产品。\n\n如果客户在其他国家或地区，当客户请求提供教育机构个人 (EDU) 折扣时，请确认 Core “模板 ID”栏位中显示 EDU 折扣选项，并且协议中包含 EDU AppleCare+ 服务计划部件号。如果同时满足这两个条件，Consumer Advisor 可以提供折扣，无需升级 AA。\n\n额外提醒，Apple 保留“教育客户审查权”，Apple 可以取消任何其合理认为不合格的订单。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "中国大陆的客户想为搭载 M5 芯片的 Macbook Pro 添加教育优惠的 AC+，可以使用哪个部件号？",
            answer: "对于中国大陆想要为 M5 芯片 MacBook Pro 添加教育优惠 AC+ 的用户，请使用以下 EDU 部件号：\nMacBook Pro (14-inch) with M5 chip 对应使用的是 SXL22CH/A\nMacBook Pro (14-inch) with M5 Pro/ Max chip 对应使用的是 SCXE3CH/A\nMacBook Pro (16-inch) with M5 Pro/ Max chip 对应使用的是 SCXF3CH/A"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "客户在“关于本机”中看到提示可以购买 AC+，尝试购买后，出现错误信息：“请在 appleid.apple.com 输入有效的地址，以购买这项计划”。此时该怎么办？",
            answer: "Consumer Advisor 请参考 IT397742 处理。当完成其中的所有步骤后，若客户仍无法完成购买操作，请升级 AA 继续处理"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "全额预付协议（PUF）AC+ 在中国大陆地区到期后 30 天内，或在香港地区到期后 45 天内，但客户没有购买保障的选项，或者在尝试完成购买时收到错误，此时该怎么办？",
            answer: "Consumer Advisor 请参考以下两篇文章：101560 & IT489626\n同时，在 IT489626 中的一个重要步骤为：\n请通过以下路径让客户完善 Apple Account 的信息：\nApp Store - 账户 - 点击头像账户 - 管理付款方式 - 点击已经添加的付款方式 - 点击 “账单寄送地址“ 展开信息 - 点击右上角 “编辑“，更新所有信息后保存。（尤其需要填写国家/地区、具体地址和邮编）\n\n您可以使用 MZSupport 确认 AppIe Account 的信息：\n付款方式：确认绑定有效付款方式\n账单地址及电话：确认已完善\n\n若以上操作后依然无法解决，请升级 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "客户的全额预付协议 AppleCare 计划或 AC+ 到期已经超过 30 天，可以继续续订吗？",
            answer: "参考 101560 & 123309 中针对不同地区的要求说明。\n以下为中国大陆地区面向客户的说明：\n在中国大陆，你或许可以在保障结束之日起的 30 天内延续保障。\n如果你为 iPhone、iPad、Mac、Apple Watch 或 Apple Vision Pro 预先支付了 12、24 或 36 个月的保障费用，你或许可以在服务期结束后按年延续保障。如果你按年支付费用，你的年度计划会在每一年进行续订，直到你取消为止。\n你可以在与你的 Apple 账户相关联的 iPhone、iPad、Mac 或 Apple Vision Pro 上的“设置”中（前往“设置”>“通用”>“AppleCare 与保修”），检查你的产品是不是符合新的 AppleCare 保障的条件。或者，你可以在线查看你的 AppleCare 保障选项。\n\n如果中国大陆地区使用全额预付的 AC+，且已经超过 30 天，请拒绝客户，无需升级 AA 处理。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议购买",
            question: "客户想要了解 AC+ 的价格，Consumer Advisor 如何提供信息？",
            answer: "请参考下方获取价格信息：\n中国大陆 https://www.apple.com.cn/applecare/\n香港 https://www.apple.com/hk/applecare/\n新加坡 https://www.apple.com/sg/applecare/\n澳门 https://www.apple.com/mo/applecare/\n官网无 AC+ 价格信息，请建议客户联系协议销售方获取价格。\n\nNew 自 2026/6/1 起，澳门 AC+ 仅在 ARS 提供销售，所有经销商渠道（包括运营商）不再销售。其中的 ADH 由 AIG 保险公司提供支持，可参考 124076。在原有服务合同模式下的现有 AppleCare+ 顾客将继续获得支持，直至其协议到期。\n\n台湾 https://www.apple.com/tw/applecare/\n官网无 AC+ 价格信息，请联系台湾 AA 获取价格。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "客户为 iPad 购买 AC+ 后，希望将自己的主要产品和次级产品绑定，例如 iPad 和 Apple Pencil，请问该如何处理？",
            answer: "请 Consumer Advisor 先判断客户的次级产品与主要产品兼容性。\n如果不兼容，请拒绝客户的请求。\n如果兼容，请升级 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "客户通过“关于本机”购买了 AC+，但在自己的设备或 Apple 网站上没有看到 AC+ 的保障信息，此时该怎么办？",
            answer: "请根据客户购买 AC+ 的时间继续处理：\n距今不超过 72 小时：告诉客户，设备的保障信息最多可能需要 72 小时才会显示。同时告诉客户，如果 72 小时后仍然没有看到保障信息，请再次与我们联系。\n距今已满 72 小时：联系 AA。\n如果客户有额外诉求，例如急需处理设备维修，但购买距今仍不超过 72 小时，请联系 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "客户请求更改设备的购买日期，根据 125363 处理后，现在需要客户上传发票或购买凭证，但目前客户无法立即上传凭证，此时怎么办？如果客户咨询发票或购买凭证有什么要求，该如何回答？",
            answer: "建议客户先准备发票或购买凭证。等待客户成功上传，Consumer Advisor 确认单据符合要求后， 请再联系 AA。\n\n请参考 124522 了解发票或购买凭证的要求。\n同时对于从中国大陆的经销商处购买的产品，请审核购买凭证，并确认它包含以下信息：\n发票专用章（如果是发票）\n发票号或收据号\n产品名称\n产品序列号（可接受收据或发票上手写序列号）\n产品的原始购买日期\n经销商名称、地址、电话号码，以及公司印章或标志（如有可能）\n\n可接受企业提供的仅手写购买凭证，前提是详细信息与你的维修系统中的信息相匹配（例如购买日期、产品名称、机型、序列号、营销编号和配置）。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "客户请求为 AirPods Pro 3 更改购买日期，此时如何处理？",
            answer: "请先参考 125363 第一部分搜索 案例历史记录 。如果未能解决问题，请继续参考第二部分 查阅请求 。\n\n因为 AirPods Pro 3 支持首次使用日期，请先检查 Core 中是否显示了首次使用日期。\n如果 Core 显示了首次使用日期，且客户激活 AirPods 距今不到 5 个工作日，请向客户说明，购买日期最多可能需要 5 个工作日才会更改。如果购买日期在 5 个工作日后没有变化，请取消配对再重新配对。\n如果 Core 未显示首次使用日期，请取消配对 AirPods，并将 AirPods 与装有最新版本 iOS 或 iPadOS 的 iPhone 或者 iPad 配对。向客户说明，购买日期最多可能需要 5 个工作日才会更改。\n若在 5 个工作日之后依然没有更新，向客户收集购买凭证或发票，确认单据符合要求后，联系 AA。\n\n请注意：“首次使用日期”以美国太平洋时间记录，并相应地显示在 Core 中。对于其他地区的客户，由于时区差异，这可能显示为比购买日期早一个日历日。如果 Core 显示的产品激活日期早于客户声称的购买日期，请拒绝请求。如有需要，请指引客户联系经销商。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "客户购买的 Beats Studio Pro 无线头戴式耳机没有购买日期，想要更新购买日期，此时怎么办？",
            answer: "请先参考 125363 第一部分搜索 案例历史记录 。如果未能解决问题，请继续参考第二部分 查阅请求 。\n\n同时，请参考以下任一方法帮助客户修改购买日期：\n方法一\n客户可以在 checkcoverage.apple.com 上更改购买日期。最多可能需要 5 个工作日才能显示更改结果。\n方法二\nConsumer Advisor 可以在 Core 中更改购买日期。最多可能需要 24 小时才能完成。\n如果两个方式都未能解决客户问题，请确认购买日期，向客户收集购买凭证或发票，确认单据符合要求后，联系 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "保障内容和注册",
            question: "New 客户在中国大陆为自己的设备购买了 AC+，但目前去到了其他国家或地区，是否能在其他国家或地区使用 AC+ ？",
            answer: "建议客户先提前联系，例如所在地的 ARS 或 AASP 确认是否支持维修。\n如果支持维修，当客户在中国⼤陆之外的国家或地区根据本计划寻求服务，则可能需要以该国家或地区的货币⽀付服务费或当地同等费⽤，并且以该国家或地区的适⽤费率为准 – 有关更多详细信息，包括各个国家或地区的适⽤费⽤，请访问 AppleCare+ 服务计划⽀持⽹站 apple.com.cn/legal/sales-support/applecare/applecareplus/ 并选择相应的设备和寻求服务时所在的国家或地区，以查看适⽤的条款和服务事件费⽤。如有必要，请切换到当地的 Apple 官网。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "交易和定期付款",
            question: "客户想要为 AC+ 补开发票，请问该怎么办？",
            answer: "处理 AC+ 补开发票请求时，请根据客户的购买渠道提供对应的指引。在正常情况下，此流程无需升级 AA 处理：\nApple 支持购买的 AC+，Sales Support 部门（RCC）开具发票\nApple Store 在线商店购买的 AC+，让客户在 apple.com.cn/store 上查看订单历史记录，以获取过去 18 个月内的收据副本。如果客户无法找到相应收据，请联系 Sales Support 部门（RCC）\nApple Store 商店购买的 AC+，指引客户发送电子邮件至 china_fapiao@apple.com\nApple 授权经销商购买的 AC+，指引客户联系经销商\n关于本机购买的 AC+ ，客户可通过链接 https://www.fdfinvoice.com/issue/#/ 自助提交发票请求\n\n若客户通过关于本机购买 AC+，且在上述自助链接中遇到以下任一报错，请联系 AA 协助处理：\n关于本机购买的 AC+，客户在链接 https://www.fdfinvoice.com/issue/#/ 自助提交发票开具请求后失败\n关于本机购买的 AC+，客户在链接 https://www.fdfinvoice.com/issue/#/ 提交发票更改接收电子邮件地址的请求失败"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户表示此前来电申请 AC+ 退款成功，但尚未收到退款，来电咨询退款进度。",
            answer: "请 Consumer Advisor 优先参考 AA 此前的案例备注，或请客户参考退款相关邮件中的邮件了解请求退款日期，然后请考虑客户来电咨询日期和请求退款日期的时差。\n\n退款时限与客户的支付方式相关。请参考以下信息了解详情。如果仍在退款期限内，请建议客户耐心等待。如果在以下退款方式对应的退款时限内未收到退款，客户可以再次联系 Apple：\n支付宝：15 个工作日\nApple Store 电子充值卡（加拿大或美国）：5 个工作日\n支票：30 个工作日\n信用卡：15 个工作日\nEFT 或 WebPay EFT：15 个工作日\niTunes 电子充值卡：5 个工作日\n中国大陆、首信易、银联的银行卡：15 个工作日\n微信支付：15 个工作日\n原始付款方式（采用定期付款的 AppleCare+ 服务计划）：30 天或更短时间\n\n如果已经超出了退款时限，建议收集以下信息，然后联系 AA:\n设备序列号\n申请 AC+ 退款时间"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "New 客户的设备购买了 AC+，目前已经通过年年焕新升级换购了新设备。客户咨询 AC+ 退款时效。",
            answer: "对于年年焕新退款时效，需参考客户请求退款的地点：\nApple Store 商店\n如果客户请求退款的时间距今 14 天或以内，请向客户说明，客户将在 14 天内收到退款。如果客户问起，请参考以下信息来回答客户的问题：\n如果客户想要收回原始设备，客户必须在发起升级换购后的 8 天内联系 Apple Store 商店提出取消请求。\n客户的收据会注明客户将在 14 天内收到退款。\nApple Store 在线商店\n如果客户请求退款的时间距今 15 天或以内，请向客户说明，客户将在 15 天内收到退款。如果客户问起，请参考以下信息来回答客户的问题：\n如果客户想要收回原始设备，客户必须在发起升级换购后的 8 天内联系 Apple Store 在线商店提出取消请求。\n客户的收据会注明客户将在 15 天内收到退款。\n\n若超过以上时限未收到退款，请联系 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "New 客户此前联系 Apple 申请 AC+ 退款。AA 同事为客户提交了 AC+ 退款请求。在等待退款到账过程中，客户反悔，想要取消 AC+ 退款，请问怎么办？",
            answer: "在 AA 同事 提交退款请求后，原始 AppleCare+ 服务计划保障将无法恢复。如果客户仍然符合 AppleCare+ 服务计划购买条件，客户可以重新购买这项计划。无需联系 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户在中国大陆的 Apple Store 商店，或 Apple Store 在线商店购买了 AC+，自购买之日起距今未超过 14 天。此时，客户想申请 AC+ 退款，如何处理？",
            answer: "如果客户符合以下情形，请指引客户联系销售点，无需联系 AA：\n通过 Apple Store 商店或 Apple Store 在线商店全额付款购买，并在购买后 14 天内请求退款\n在 14 天之内，如果客户想将设备和 AC+ 都进行退款退货，也请客户直接联系销售方。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户在中国大陆的 Apple Store 商店，或 Apple Store 在线商店购买了 AC+，且自购买之日起第 15 天或更长时间，想要申请 AC+ 退款，如何处理？",
            answer: "请再次确认客户诉求和购买日期。\n如果确定来电咨询日期为自购买之日起第 15 天或更长时间，请升级 AA。\n同时，联系 AA 前建议收集以下信息：\n- 购买时间是否在 14 天内\n- 购买地点\n- 退款诉求\n- 设备序列号"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户在中国大陆天猫 Apple Store 官方旗舰店购买了产品和 AC+，想要申请 AC+ 退款但保留产品，如何处理？",
            answer: "当天猫 Apple Store 官方旗舰店订单处于准备发货/已发货/已交货/已取货的状态是，如果客户选择保留产品，只想为 AC+ 退款，请在 Core 中联系 Tmall Agreement Admin Support 天猫官方旗舰店支持团队 队列。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "New 客户在中国大陆 Apple 授权经销商购买了 AC+，想要申请退款，如何处理？",
            answer: "如果符合以下所有条件，请联系 AA：\n客户 31 天前或更长时间前通过大陆的 Apple 授权经销商全额付费全额付款购买\n原始销售点已停业\n客户持有持有包含所有必要元素的购买凭证或发票（其中 AppleCare+ 服务计划价格需列为单独的行项目）\n你已收集客户的购买凭证\n\n对于其他情形，指引客户联系销售点"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户在台湾并购买了台湾的 AC+，想要申请退款，如何处理？",
            answer: "如果客户符合以下情形，请指引客户联系销售点：\n通过 Apple Store 商店或 Apple Store 在线商店全额付款购买，并在购买后 14 天内请求退款\n从第三方经销商购买\n\n对于其他情形，由于客户 在台湾购买的 AC+ 需要由台湾 AA 专门处理 ，其他 AA 团队无法提供支持。请联系台湾 AA，即 JAPAC Taiwan Mandarin Agreement Admin 队列。同时，建议客户提供“保单收据”。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "粤语客户申请 AC+ 退款时，是否必须联系 Cantonese AA？如果 Cantonese AA 处于非工作时间无法被联系，只有 Mandarin AA 可以联系怎么办？",
            answer: "如果粤语客户能够说普通话，可以联系 Mandarin AA。Mandarin AA 可以处理除台湾以外的 JAPAC 所有 AC+ 退款。台湾 AC+ 请联系台湾 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户想要申请 ACS 退款。",
            answer: "请参考 125034，根据不同 ACS 协议建议客户联系合作伙伴。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户对于 AC+ 退款金额有疑问，包括但不限于：\n之前已经使用过 AC+ 维修，客户想知道具体的可退金额\n已经办理了 AC+ 退款，但对于退款比例存疑\nNew 若客户未曾使用 AC+ 进行任何维修，您可以分享以下退款准则给客户：",
            answer: "当取消定期付款 AppleCare 计划时 ，根据客户取消定期付款 AppleCare 计划的时间，以下退款准则可能适用：\n如果客户在定期付款的 AppleCare 计划开始后的 30 天内取消计划，客户将获得全额退款。\n定期付款的计划开始 30 天后，如果你立即取消按月或按年付费的 AppleCare 计划，你将根据 AppleCare 计划保障的未到期天数按比例获得退款。\n根据客户购买 AppleCare 计划时所在的国家或地区，客户的按月或按年付费计划可能会保持有效，直到已付费的最后一个月或一年结束。然后，计划将取消，并且不会提供退款。\n\n当取消固定期限 AppleCare 计划时 ，根据客户取消 AppleCare 计划的时间，以下退款准则可能适用：\n如果客户在购买 AppleCare 计划之日起的 30 天内取消这项计划，那么在扣除所有已提供服务的相应费用后，你会获得其余全部退款\n如果客户在购买 AppleCare 计划的 30 天后取消这项计划，则我们会根据 AppleCare 计划保障的未到期天数按比例退款，并扣除所有已提供服务的相应费用\n\n请注意，退款准则可能会因客户所在的国家、地区、州或省/自治区/直辖市而异。如果客户想要了解 具体确切的 AC+ 退款金额 ，请联系 AA。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户通过 iPhone 年年焕新计划，从 Apple Store 商店或 Apple Store 在线商店购买了设备，后续产生了退货。现在客户希望恢复年年焕新资格，请问怎么办？",
            answer: "请建议客户联系销售方，即 Apple Store 商店或 Apple Store 在线商店，无需升级 AA"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "中国大陆地区客户在澳门购买了 AC+，想要退款，但客户没有当地的银行卡，请问怎么办？",
            answer: "如果客户可以提供澳门的付款方式，请升级 AA 处理。\n请勿为中国大陆、香港、澳门或台湾的客户处理跨境退款。如果客户提出疑问，请向客户说明，付款方式必须为原始购买国家或地区的付款方式。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议取消和退款",
            question: "客户的设备维修未完成，但想要申请 AC+ 退款，该怎么办？",
            answer: "请建议客户先等待维修完成，再继续处理 AC+ 退款。这是因为 AC+ 退款，在计算按比例退款时，必须扣除使用协议进行维修的相关费用。不要猜测客户的最终退款金额。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "协议转移",
            question: "New 客户设备在维修后进行了整机更换。客户想了解原有设备的 AC+ 何时会更新到更换的设备上？",
            answer: "这是 AC+ 协议从一个产品转移到另一个产品。通常，AppleCare 协议保障会自动转移至更换设备。请向客户说明，转移将在维修完成后的 72 小时内进行。如果保障没有自动转移，请查看维修记录，并确认是不是需要更正维修链。"
        ),
        ChorusFAQEntry(
            pageId: "7982276",
            category: "AA FAQ",
            subCategory: "其他",
            question: "New 如何快速确认客户的协议和购买来源？",
            answer: "可以通过 Core 来确认协议类型。\n在“交互记录”中展开“相关信息”，点击受影响的产品；在出现的“历史记录”中，查看客户协议。若历史记录较多，可通过“筛选器”>“协议”来更改视图。\n在历史记录中可能会出现一个或以上更多的协议。请始终以最新的协议为准。\n\n根据 Apple 协议编号的开头字符及具体特征，您可以快速判断其购买渠道，常见开头的协议编号和对应规则如下：\n27 开头 ：编号共 11 位，且均为数字。购买来源：Apple 支持、设备端系统或面向客户的系统购买的。\n32，或 5400 开头 ：编号共 12 位，且均为数字。购买来源：Apple 授权经销商购买的。\n56、57、62、63、78 或 L 开头 ：编号共有 10 位。购买来源： Apple Store 在线商店、Apple 支持（技术解决方案）或天猫（仅限中国大陆）。\n970 开头 ：编号共 15 位，且均为数字。购买来源：Apple Store 商店或 Apple Store 在线商店购买但在 Apple Store 商店取货\n\n以上为最常见协议编号开头。如果客户的协议编号开头与以上内容不同，请向客户确认，再继续处理。请不要因为客户的协议编号不属于以上常见协议编号而拒绝客户。"
        ),
        
        // MARK: - 5. SDA (Page 7861236)
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "申诉指引与范围",
            question: "建议客户填写服务申诉链接前，需要注意哪些事项？",
            answer: "建议客户填写服务申诉链接前，请注意以下事项：\n• 持有相应产品以及 AASP 或 Apple Store 商店提供的“退回发件人”(RTS) 信函。只有在收集到产品和 RTS 信函后，才可让客户提交请求。\n• 提交申诉时，请填写准确的设备序列号。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "业务范围与分类",
            question: "SDA 处理的业务范围是什么？",
            answer: "仅中国大陆地区的返厂维修被拒的设备。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "业务范围与分类",
            question: "SDA 处理的案例类型分类有哪些？",
            answer: "SDA 处理的案例类型分类包括：\n• 不符合维修条件（篡改）\n• 重新报价（Re-quote）\n• 无故障退回（NTF）\n• 灾难性损坏（BER）\n• 无 POP\n• Other（Offline RTS）"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "时效与预期",
            question: "能否具体告知客户 SDA 具体的回复时间？",
            answer: "否。除了规程 124483 说明的“客户会在 5 个工作日内接到回电”外，其他 SDA 后续跟进回复时间请勿设置任何时间预期。并且申诉人在提交完申诉后，提示界面会提示客户回复预期。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "客户常见咨询",
            question: "SDA 收到申诉后回复的时效是多久？",
            answer: "客户在提交后，五个工作日内，SDA 会电话联系客户。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "客户常见咨询",
            question: "SDA 的工作时间是什么？",
            answer: "周一至周五 早上 9:00 - 晚上 6:00（法定节假日除外）。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "申诉指引与范围",
            question: "客户是否需要在返厂后取回设备再提交申诉？",
            answer: "是。根据规程 124483，建议客户申诉时，已经从 AASP 和 ARS 拿到“产品服务摘要”以及自己的设备。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "进度与跟进",
            question: "如果客户没有接到 SDA 电话怎么办？",
            answer: "• 如果在 5 个工作日内：请客户耐心等待，并且查看预留邮箱里的邮件，是否有 SDA 发送的邮件信息指引。\n• 超过 5 个工作日后：Advisor 可以转发案例至 Work-list，SDA Advisor 会在 2 个工作日内联系客户。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "进度与跟进",
            question: "SDA 已经与客户接洽，客户现在可以通过什么样的方式找回之前的工作人员？",
            answer: "SDA 在首次跟进客户案例后，会发送跟进邮件至客户邮箱，客户可以回复邮件找到之前跟进的 SDA 工作人员。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "进度与跟进",
            question: "客户提交申诉后是否可以更换来电号码？",
            answer: "可以。在 5 个工作日内如果 SDA 没有电话联系到客户，会发送邮件至客户预留的邮箱，请客户查看预留邮箱里的邮件，回复正确电话即可。\n⚠️ 注意：T1-T2 Advisor 所登记的客户号码，SDA 无法直接联系。"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "业务范围与分类",
            question: "哪些案例不在 SDA 处理范围内（Out of SDA Scope）？",
            answer: "以下情况不在 SDA 处理范围内：\n• 设备已完成维修\n• 维修已经取消，未返厂\n• 设备未返厂，Carry-in 订单"
        ),
        ChorusFAQEntry(
            pageId: "7861236",
            category: "SDA",
            subCategory: "申诉指引与范围",
            question: "哪些属于重复 SDA 案例（Repeat Case），切勿建议客户再次提交申诉？",
            answer: "当看到以下情况时，切勿建议客户再次提交申诉：\n• SDA 正在跟进中\n• SDA 已关闭案例，并已给到客户最终答复"
        ),
        
        // MARK: - 6. Apple TV (Page 7550958)
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "隔空播放与镜像",
            question: "在中国大陆，是否可以将 iPhone 或 iPad 使用“隔空播放”串流分享到 Apple TV？",
            answer: "“隔空播放”功能使用与其他地区相同，如果出现与技术文档或用户手册不符的情况，属于非预期行为。若根据知识库文章协助客户未能解决，且非硬件问题，可以 RTA。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "隔空播放与镜像",
            question: "客户使用“隔空播放”投屏到 Apple TV 会断开连接，Apple TV 在中国大陆能正常使用“隔空播放”功能吗？",
            answer: "“隔空播放”功能使用与其他地区相同，如果出现与技术文档或用户手册不符的情况，属于非预期行为。若根据知识库文章协助客户未能解决，且非硬件问题，可以 RTA。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "隔空播放与镜像",
            question: "客户可以将 iPhone 声音“隔空播放”到 HomePod mini，但无法“隔空播放”到 Apple TV，这是预期现象吗？",
            answer: "“隔空播放”功能使用与其他地区相同，如果出现与技术文档或用户手册不符的情况，属于非预期行为。若根据知识库文章协助客户未能解决，且非硬件问题，可以 RTA。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "Apple 账户与媒体服务",
            question: "在中国大陆在 Apple TV 上使用国外 Apple 账户登入连国内网络，能否正常使用 Apple TV+、Fitness+ 等未在大陆提供的服务？",
            answer: "媒体服务的提供情况是跟着账号的国家／地区，如果客户表示不能使用某国家／地区账号的服务，出现与技术文档或用户手册不符的情况，且非硬件问题，可以 RTA。\n根据客户使用的账户参考 [118205 Apple 媒体服务的提供情况](core://articleId=118205&locale=zh_CN) 判断是否提供对应的服务。如果服务情况出现异常，则按照正常流程进行故障诊断。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "Apple 账户与媒体服务",
            question: "中国大陆的 Apple 账户可以在 Apple TV 上使用哪些服务？有哪些功能会有限制？",
            answer: "参考 [118205 Apple 媒体服务的提供情况](core://articleId=118205&locale=zh_CN)，使用中国大陆 Apple 账户的话，中国大陆 Apple 账户有提供什么服务，就能使用什么服务。\n建议以技术文章（KBase）和手册或其他内部资源为准，如果客户描述的情况并未在相关文档手册中描述，即属于非预期现象，请进行基本故障排查以及在必要时升级 RTA。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "Apple 账户与媒体服务",
            question: "客户表示自己在中国大陆，想创建国外的 Apple 账户来使用未在大陆提供的媒体服务，应如何向客户说明？",
            answer: "说明理解客户的需求，然后提供正确资讯。\n条款内容：“你可以在你所在国家或居住所在地 (‘居住国家或地区’) 获取并使用我们的服务。为使用服务而在特定国家或地区建立账户，视同您已指定该地区为您的所在国家。” 取自：[Apple 媒体服务条款和条件](https://www.apple.com.cn/legal/internet-services/itunes/cn/terms.html)。\n\n话术参考：「我了解您的需求，您希望可以在中国大陆使用其它国家的账户。关于 Apple 账户的创建，会有些条款和基本信息需要设置，不同国家地区的帐户提供的服务会有所不同；另外，每个国家可以使用的媒体服务可能不太一样，服务是否能正常使用，要看各个服务提供商。稍后我会寄送相关资讯给您。」（寄送 [Apple 媒体服务条款和条件](https://www.apple.com.cn/legal/internet-services/itunes/cn/terms.html) 及 [108647](core://articleId=108647&locale=zh_CN)）"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "Apple 账户与媒体服务",
            question: "客户询问 Apple TV 是否可以安装 VPN？如何在 Apple TV 上下载 VPN？",
            answer: "根据 [CP405358 技术支持 Advisor（技术顾问）支持范围](core://articleId=CP405358&locale=zh_CN)，安装 VPN 未在 Apple TV 支持范围里。告知客户 Apple TV 目前可用的网络连接方式不支援 VPN。\n\n话术参考：「Apple TV 连接网络的方式有有线和无线网络。如果您在 tvOS 15.4 之后的版本，可以从网页浏览器登入的限制 Wi-Fi 网络。目前不支援使用 VPN。」\n⚠️ 提醒：请勿在互动中与客户谈论 VPN 相关的事宜，例如如何设置、如何取得 VPN 等。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "普通话 Advisor 若接到 Apple TV 案例，该如何处理？",
            answer: "请依照 [CP405358 技术支持 Advisor（技术顾问）支持范围](core://articleId=CP405358&locale=zh_CN) 中的准则提供支持。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "中国大陆客户的 Apple TV 需要维修，但中国大陆不提供此服务时，应该如何说明？",
            answer: "异地维修政策的 SOP 都已经整合到 [CP400089 Core 中的服务选项](core://articleId=CP400089&locale=zh_CN)。请从 Core 的服务查找器中选择地点／产品，Core 会根据相关信息显示推荐的可用服务选项。\n告知客户线上已提供充足的故障诊断，硬件方面将需要由服务提供商协助。告知客户需要前往有提供 Apple TV 维修服务的国家或地区进行。\n\n话术参考：「谢谢您的耐心配合，目前我们在线上能进行的软件相关的故障诊断都完成了，比较可惜问题还是没有解决。接下来会建议送修以检测硬件方面的问题。很遗憾在中国大陆还没有提供 Apple TV 的维修服务，如果您希望进行维修，可以选择在有提供 Apple TV 维修服务的国家或地区进行。」\n相关资源｜[CP400089 Core 中的服务选项](core://articleId=CP400089&locale=zh_CN)"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "线上客户操作不顺利，可以推荐客户前往中国大陆的 Apple Store 零售店或 AASP 取得协助吗？",
            answer: "中国大陆的 ARS（直营店）及 ASP（授权店）无法提供支持，因为没有贩售此产品，没有相关培训及产品知识可帮助客户。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "Apple TV 上的“辅助使用”问题，是否需要转接至普通话“辅助控制”队列？",
            answer: "请参考 [CP403435 对辅助功能案例提供支持](core://articleId=CP403435&locale=zh_CN)、[CP401339 来自具有辅助功能需求的客户的联系](core://articleId=CP401339&locale=zh_CN)、[CP400440 转接来电](core://articleId=CP400440&locale=zh_CN) 中的内容提供支持和转接。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "当客户将 Apple TV 与 HomePod 或其他智慧家电搭配使用，此类 HomeKit 问题该如何处理？",
            answer: "请依照 [CP405358 技术支持 Advisor（技术顾问）支持范围](core://articleId=CP405358&locale=zh_CN) 中的准则提供支持。"
        ),
        ChorusFAQEntry(
            pageId: "7550958",
            category: "Apple TV",
            subCategory: "服务支持与维修规程",
            question: "客户问到与 Apple Fitness+ 相关的问题，中国大陆并无提供此媒体服务，我们应该如何支持客户？",
            answer: "如同中国客户在 Apple Watch 使用美国 Apple 账户且有订阅 Apple Fitness+ 而致电询问的问题一样，根据规程提供支持即可。\n如果您遇到与 Apple Fitness+ 相关的问题，无法使用现有的文稿来解决客户问题、出现与技术文档或用户手册不符的情况，且非硬件问题，可以 RTA。"
        )
    ]
    
    /// Syncs and updates all FAQ items from Chorus into WorkbenchStore & iCloud shared folder
    public func syncChorusAll(into store: WorkbenchStore) -> Int {
        isSyncing = true
        var importedCount = 0
        var updatedCount = 0
        
        for entry in Self.allEntries {
            let q = entry.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = entry.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract related Core article ID if present
            var relatedId: String? = nil
            let pattern = #"(?<=\b)(10\d{4}|20\d{4}|30\d{4}|\d{6}|HT\d{6}|CP\d{6})(?=\b)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: a, options: [], range: NSRange(location: 0, length: a.utf16.count)),
               let r = Range(match.range, in: a) {
                relatedId = String(a[r])
            }
            
            var tags = [entry.category]
            if !entry.subCategory.isEmpty {
                tags.append(entry.subCategory)
            }
            
            if let existingIndex = store.faqItems.firstIndex(where: { $0.question == q }) {
                store.faqItems[existingIndex].category = entry.category
                store.faqItems[existingIndex].answer = a
                store.faqItems[existingIndex].tags = tags
                store.faqItems[existingIndex].relatedArticleId = relatedId
                store.faqItems[existingIndex].updatedAt = Date()
                updatedCount += 1
            } else {
                let newFAQ = FAQItem(
                    question: q,
                    answer: a,
                    category: entry.category,
                    tags: tags,
                    relatedArticleId: relatedId,
                    author: store.currentUser.name,
                    updatedAt: Date()
                )
                store.faqItems.append(newFAQ)
                importedCount += 1
            }
        }
        
        store.faqItems.sort { $0.updatedAt > $1.updatedAt }
        store.saveData()
        
        // Save to iCloud shared folder if connected
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let faqDir = baseURL.appendingPathComponent("faq", isDirectory: true)
            let encoder = JSONEncoder()
            for item in store.faqItems {
                let fileURL = faqDir.appendingPathComponent("faq_\(item.id.uuidString).json")
                if let data = try? encoder.encode(item) {
                    try? data.write(to: fileURL)
                }
            }
        }
        
        self.lastSyncTime = Date()
        UserDefaults.standard.set(self.lastSyncTime, forKey: lastSyncTimeKey)
        self.isSyncing = false
        
        if importedCount > 0 {
            self.lastSyncResult = "成功从 Chorus (RCC/ARS/BTS/AA/SDA/Apple TV) 提取并同步 \(importedCount) 条问答！"
        } else {
            self.lastSyncResult = "Chorus 知识库校验完成，已刷新全部 \(updatedCount) 条问答至最新状态。"
        }
        
        return importedCount + updatedCount
    }
    
    /// Syncs and updates a specific Chorus category into WorkbenchStore & iCloud shared folder
    public func syncChorusCategory(_ category: String, into store: WorkbenchStore) -> Int {
        isSyncing = true
        var importedCount = 0
        var updatedCount = 0
        
        let matchingEntries = Self.allEntries.filter { $0.category == category || $0.pageId == category }
        for entry in matchingEntries {
            let q = entry.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = entry.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var relatedId: String? = nil
            let pattern = #"(?<=\b)(10\d{4}|20\d{4}|30\d{4}|\d{6}|HT\d{6}|CP\d{6})(?=\b)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: a, options: [], range: NSRange(location: 0, length: a.utf16.count)),
               let r = Range(match.range, in: a) {
                relatedId = String(a[r])
            }
            
            var tags = [entry.category]
            if !entry.subCategory.isEmpty {
                tags.append(entry.subCategory)
            }
            
            if let existingIndex = store.faqItems.firstIndex(where: { $0.question == q }) {
                store.faqItems[existingIndex].category = entry.category
                store.faqItems[existingIndex].answer = a
                store.faqItems[existingIndex].tags = tags
                store.faqItems[existingIndex].relatedArticleId = relatedId
                store.faqItems[existingIndex].updatedAt = Date()
                updatedCount += 1
            } else {
                let newFAQ = FAQItem(
                    question: q,
                    answer: a,
                    category: entry.category,
                    tags: tags,
                    relatedArticleId: relatedId,
                    author: store.currentUser.name,
                    updatedAt: Date()
                )
                store.faqItems.append(newFAQ)
                importedCount += 1
            }
        }
        
        store.faqItems.sort { $0.updatedAt > $1.updatedAt }
        store.saveData()
        
        if let baseURL = SharedFolderSyncService.shared.sharedFolderURL, SharedFolderSyncService.shared.isConnected {
            let faqDir = baseURL.appendingPathComponent("faq", isDirectory: true)
            let encoder = JSONEncoder()
            for item in store.faqItems {
                let fileURL = faqDir.appendingPathComponent("faq_\(item.id.uuidString).json")
                if let data = try? encoder.encode(item) {
                    try? data.write(to: fileURL)
                }
            }
        }
        
        self.lastSyncTime = Date()
        UserDefaults.standard.set(self.lastSyncTime, forKey: lastSyncTimeKey)
        self.isSyncing = false
        
        if importedCount > 0 {
            self.lastSyncResult = "成功从 Chorus 提取并同步 \(importedCount) 条「\(category)」问答！"
        } else {
            self.lastSyncResult = "「\(category)」知识库校验完成，已刷新全部 \(updatedCount) 条问答至最新状态。"
        }
        
        return importedCount + updatedCount
    }
}
