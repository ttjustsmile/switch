import SwiftUI
import UIKit

// MARK: - 一处颜色 = 两根滑杆

/// 用户能调的每一处颜色都只由两根滑杆决定：色相 + 明暗。
/// 版式抄 iOS 主屏「自定义」那个浮层。
///
/// ⚠️ 第二根杆是**完整的明暗轴**，不是饱和度：
///
///     0 ─────── 0.5 ─────── 1
///     白        纯色         黑
///
/// 后半段一路掉饱和，所以往暗里拖会经过灰。
/// 第一版只做了「白 → 纯色」，滑到头也调不出灰和黑 —— 用户一眼就发现了，
/// 原话是"色块里缺少了灰色黑色那一段过渡"。别改回去。
public struct BubbleTint: Equatable, Sendable {
    /// 彩虹条上的位置，0...1
    public var hue: Double
    /// 明暗轴上的位置，0...1（0 白 / 0.5 纯 / 1 黑）
    public var level: Double

    /// 最纯那一点的亮度。给到 1 的话高饱和会亮得晃眼，
    /// 0.82 是照气泡的实际观感定的。
    private static let pureBrightness = 0.82

    public var uiColor: UIColor {
        let h = CGFloat(hue)
        if level <= 0.5 {
            // 白 → 纯色
            let f = level / 0.5
            return UIColor(hue: h,
                           saturation: CGFloat(f),
                           brightness: CGFloat(1 - (1 - Self.pureBrightness) * f),
                           alpha: 1)
        }
        // 纯色 → 灰 → 黑。掉饱和比掉亮度快（平方），
        // 中段才有灰味，不是一路暗红。
        let f = (level - 0.5) / 0.5
        return UIColor(hue: h,
                       saturation: CGFloat(pow(1 - f, 2)),
                       brightness: CGFloat(Self.pureBrightness * (1 - f)),
                       alpha: 1)
    }

    public var color: Color { Color(uiColor: uiColor) }

    public init(hue: Double, level: Double) {
        self.hue = min(max(hue, 0), 1)
        self.level = min(max(level, 0), 1)
    }

    /// 把一个现成的颜色拆回两根滑杆的位置 —— 打开浮层时滑杆得停在对的地方，
    /// 而不是每次都从 0 开始。
    public init(_ color: Color) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let level = Double(b) >= Self.pureBrightness
            ? 0.5 * Double(s)                                   // 亮的那半段：饱和度就是位置
            : 0.5 + 0.5 * (1 - Double(b) / Self.pureBrightness)  // 暗的那半段：看亮度掉了多少
        self.init(hue: Double(h), level: level)
    }
}

// MARK: - 能调哪几处

/// 可调色的位置。想加一处（比如导航栏）就在这儿加一个 case，
/// 其余地方跟着编译报错走一遍就行。
public enum TintTarget: String, Identifiable, Hashable, CaseIterable, Sendable {
    /// 对方的气泡（左边）
    case incoming
    /// 自己的气泡（右边）
    case outgoing
    case sidebar

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .incoming: return "对方气泡"
        case .outgoing: return "我的气泡"
        case .sidebar:  return "侧栏颜色"
        }
    }
}

/// 正文字色。**只给黑白两个** —— 中间那些灰在花纹壁纸上都糊成一团。
///
/// ⚠️ 这不只是气泡里的字，是**全局**的：侧栏、面板标题、时间戳、输入框……
/// 落地靠下面 `Look` 那份快照，`Theme.ink` / `textPrimary` / `textSecondary`
/// / `textFaint` / `border` 全都读它。
public enum BubbleInk: String, CaseIterable, Identifiable, Sendable {
    case black, white

    public var id: String { rawValue }
    public var title: String { self == .black ? "黑" : "白" }

    /// 黑那档用出厂墨色（#201F1D），不是纯黑
    public var color: Color { self == .black ? Theme.inkDefault : .white }

    /// 跟字色相反的那一面。字白 → 底黑，字黑 → 底白。
    /// **底色永远站在字色的对面** —— 这条贯穿整套配色，别绕过它。
    public var opposite: Color { self == .black ? .white : Theme.inkDefault }
}

// MARK: - 非隔离快照

/// 只做展示的一份普通全局值。
///
/// ⚠️ 为什么不直接读 `Appearance.shared`：
/// `Theme` 里那些颜色会在 `ButtonStyle`、`Canvas` 闭包这类**不带主线程隔离**的
/// 上下文里被读到，直接摸 @MainActor 的单例过不了并发检查。
/// 所以每次改动都把结果同步到这份普通值上：只在主线程写，读的地方全在渲染路径上。
public struct Look: Sendable {
    public var ink: Color = Theme.inkDefault
    /// 字是不是白的。⚠️ 别拿 `ink == .white` 去猜 ——
    /// `Color` 的相等判定看的是它**怎么构造的**，两个看着一样的白可能不相等。
    public var whiteInk = false
    /// 半透明卡片 / 圆钮的底。字黑 → 白 55%，字白 → 黑 45%。
    public var panel: Color = .white.opacity(0.55)
    /// 输入框那条。跟侧栏同色 —— 这两块看着得是一套的。
    public var composer: Color = Theme.sidebarFillDefault
    /// 输入框和小控件的描边
    public var rim: Color = .black.opacity(0.10)
    public var sidebar: Color = Theme.sidebarFillDefault
    /// 侧栏是不是被改过色 —— 改过就不能再原样铺那张贴图（见 `sidebarNeedsBlend`）
    public var sidebarCustom = false

    /// 从存盘里现算一份。跟 `Appearance.sync()` 是同一套算法，
    /// 别改一处漏一处。
    public static var stored: Look {
        let d = UserDefaults.standard
        let ink = BubbleInk(rawValue: d.string(forKey: LookKey.ink) ?? "") ?? .black
        let sidebarTint = LookKey.read(.sidebar, d)
        let sidebar = sidebarTint?.color ?? Appearance.factory(.sidebar, ink)
        return Look(
            ink: ink.color,
            whiteInk: ink == .white,
            panel: ink.opposite.opacity(ink == .white ? 0.45 : 0.55),
            composer: sidebar,
            rim: ink == .white ? Color.white.opacity(0.22) : Color.black.opacity(0.10),
            sidebar: sidebar,
            sidebarCustom: sidebarTint != nil
        )
    }
}

/// UserDefaults 里的键。`Appearance` 和 `Look.stored` 共用。
public enum LookKey {
    public static let tint = "bubbleTint"       // + ".incoming.hue" / ".incoming.level"
    public static let ink = "bubbleInk"
    public static let opacity = "bubbleOpacity"
    public static let blur = "wallBlur"

    /// 读一处颜色的两根滑杆位置。
    ///
    /// 那个 `.amount` 分支是给老版本兜的：早期存的是「白→纯色」那根杆（本质是
    /// 饱和度），正好是新明暗轴的**前半段** —— 折一半搬过来，
    /// 用户调好的颜色不用重调。这种迁移比"清空重来"值得多写五行。
    public static func read(_ target: TintTarget, _ d: UserDefaults) -> BubbleTint? {
        guard let hue = d.object(forKey: "\(tint).\(target.rawValue).hue") as? Double
        else { return nil }
        if let level = d.object(forKey: "\(tint).\(target.rawValue).level") as? Double {
            return BubbleTint(hue: hue, level: level)
        }
        if let amount = d.object(forKey: "\(tint).\(target.rawValue).amount") as? Double {
            return BubbleTint(hue: hue, level: amount / 2)
        }
        return nil
    }
}

/// 读的地方到处都是，写只有 `Appearance` 一处（主线程）。
///
/// ⚠️ 初值直接从 UserDefaults 读，不等 `Appearance.shared` 被谁碰一下才成型 ——
/// 开屏第一帧（登录页、闪屏）没人订阅 `Appearance`，那时候要是读到出厂黑，
/// 用户设的白字要等进了主界面才生效，中间闪一下。
public nonisolated(unsafe) var look = Look.stored

// MARK: - 主体

@MainActor
public final class Appearance: ObservableObject {
    public static let shared = Appearance()

    /// nil = 用户没调过这一处，用出厂色。
    ///
    /// 存两根滑杆的位置而不是直接存 RGB：默认那几只就不走明暗公式，
    /// 免得"一次没动过"的出厂色也被公式挪掉 1~2/255。
    @Published public private(set) var incoming: BubbleTint?
    @Published public private(set) var outgoing: BubbleTint?
    @Published public private(set) var sidebar: BubbleTint?
    @Published public private(set) var ink: BubbleInk
    /// 气泡底色的不透明度。下限 0.2 —— 再淡下去字就飘在壁纸上认不出来了。
    @Published public private(set) var bubbleOpacity: Double
    /// 壁纸的模糊半径（pt）
    @Published public private(set) var wallBlur: Double

    public static let opacityRange: ClosedRange<Double> = 0.2...1
    public static let blurRange: ClosedRange<Double> = 0...24

    private init() {
        let d = UserDefaults.standard
        incoming = LookKey.read(.incoming, d)
        outgoing = LookKey.read(.outgoing, d)
        sidebar = LookKey.read(.sidebar, d)
        ink = BubbleInk(rawValue: d.string(forKey: LookKey.ink) ?? "") ?? .black
        bubbleOpacity = (d.object(forKey: LookKey.opacity) as? Double) ?? 1
        wallBlur = (d.object(forKey: LookKey.blur) as? Double) ?? 0
        sync()
    }

    // MARK: 读

    public func color(_ target: TintTarget) -> Color {
        tintValue(target)?.color ?? Self.factory(target, ink)
    }

    /// 没单独调过的那几处用哪个出厂色。
    ///
    /// ⚠️ **跟着字色翻**：白字配出厂的白气泡是一屏看不见的字 ——
    /// 那不是用户选的样子，是个坏状态。
    /// 用户一旦自己调过某一处，就完全听他们的，不再走这儿。
    public nonisolated static func factory(_ target: TintTarget, _ ink: BubbleInk) -> Color {
        let white = ink == .white
        switch target {
        case .incoming: return white ? Theme.bubbleOtherDark : Theme.bubbleOther
        case .outgoing: return white ? Theme.bubbleMineDark : Theme.bubbleMine
        case .sidebar:  return white ? Theme.sidebarFillDark : Theme.sidebarFillDefault
        }
    }

    /// 气泡真正填的那层：颜色 + 用户调的透明度。
    public func bubbleFill(mine: Bool) -> Color {
        color(mine ? .outgoing : .incoming).opacity(bubbleOpacity)
    }

    /// 打开浮层时两根滑杆停哪儿 —— 没调过就从出厂色拆回来。
    public func tint(_ target: TintTarget) -> BubbleTint {
        tintValue(target) ?? BubbleTint(Self.factory(target, ink))
    }

    /// 侧栏那张贴图要不要正片叠底。
    ///
    /// ⚠️ 贴图本身是**不透明**的，原样铺上去会把底色整个盖住 ——
    /// 底色一旦不是出厂那层（用户自己改了色，或者选了白字自动翻暗），就必须叠。
    public var sidebarNeedsBlend: Bool { sidebar != nil || ink == .white }

    /// 这一处是不是还在出厂状态（「恢复默认」要不要出现）
    public func isDefault(_ target: TintTarget) -> Bool { tintValue(target) == nil }

    private func tintValue(_ target: TintTarget) -> BubbleTint? {
        switch target {
        case .incoming: return incoming
        case .outgoing: return outgoing
        case .sidebar:  return sidebar
        }
    }

    // MARK: 写

    public func setTint(_ tint: BubbleTint, for target: TintTarget) {
        switch target {
        case .incoming: incoming = tint
        case .outgoing: outgoing = tint
        case .sidebar:  sidebar = tint
        }
        let d = UserDefaults.standard
        d.set(tint.hue, forKey: "\(LookKey.tint).\(target.rawValue).hue")
        d.set(tint.level, forKey: "\(LookKey.tint).\(target.rawValue).level")
        sync()
    }

    public func resetTint(_ target: TintTarget) {
        switch target {
        case .incoming: incoming = nil
        case .outgoing: outgoing = nil
        case .sidebar:  sidebar = nil
        }
        let d = UserDefaults.standard
        d.removeObject(forKey: "\(LookKey.tint).\(target.rawValue).hue")
        d.removeObject(forKey: "\(LookKey.tint).\(target.rawValue).level")
        d.removeObject(forKey: "\(LookKey.tint).\(target.rawValue).amount")
        sync()
    }

    public func setInk(_ value: BubbleInk) {
        ink = value
        UserDefaults.standard.set(value.rawValue, forKey: LookKey.ink)
        sync()
    }

    public func setOpacity(_ value: Double) {
        bubbleOpacity = min(max(value, Self.opacityRange.lowerBound),
                            Self.opacityRange.upperBound)
        UserDefaults.standard.set(bubbleOpacity, forKey: LookKey.opacity)
    }

    public func setBlur(_ value: Double) {
        wallBlur = min(max(value, Self.blurRange.lowerBound), Self.blurRange.upperBound)
        UserDefaults.standard.set(wallBlur, forKey: LookKey.blur)
    }

    /// 把「字色 → 配套底色」这套推给那份非隔离快照。
    private func sync() { look = Look.stored }
}
