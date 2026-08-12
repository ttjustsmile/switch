import SwiftUI

/// 出厂配色。
///
/// 这里是**默认值**，不是最终值 —— 用户在设置页改过的部分存在 `Appearance` 里。
/// 凡是用户能调的（字色、两边气泡、侧栏、输入框），下面都写成 `var` 并从
/// `look` 那份快照里取；没改过时 `look` 自己会落回这里的出厂色。
///
/// ⚠️ 别把这些改回 `let` 常量。改回去等于用户在设置页调什么都不生效。
public enum Theme {

    // MARK: - 固定色（用户调不到的）

    public static let surface = Color(hex: 0xF9F9F7)
    /// 选中态那一点强调色（勾、边框、"恢复默认"那行字）
    public static let accent = Color(hex: 0xDA7756)

    /// 字色的出厂值。不是纯黑 —— 纯黑压在浅色壁纸上偏硬。
    public static let inkDefault = Color(hex: 0x201F1D)

    /// 气泡出厂色。深色那两只是用户把字改成白色、又没单独调过气泡时的兜底：
    /// 白气泡配白字整屏是空的，那不是"用户选的样子"，是个坏状态。
    public static let bubbleOther = Color.white
    public static let bubbleMine = Color(hex: 0xF7D1E4)
    public static let bubbleOtherDark = Color(hex: 0x2B2A28)
    public static let bubbleMineDark = Color(hex: 0x6E2E46)

    public static let sidebarFillDefault = Color(hex: 0xFAE5EE)
    public static let sidebarFillDark = Color(hex: 0x3A2A31)

    /// 气泡投影。⚠️ CSS 的 blur-radius 是 SwiftUI shadow radius 的两倍，
    /// 照着网页抄 `0 1px 3px` 时 radius 要写 1.5 而不是 3。
    public static let bubbleShadow = Color(hex: 0x201F1D).opacity(0.06)
    public static let shadowRadius: CGFloat = 1.5

    // MARK: - 跟着用户设置走的

    public static var ink: Color { look.ink }
    public static var textPrimary: Color { look.ink }
    public static var textSecondary: Color { look.ink.opacity(0.62) }
    public static var textFaint: Color { look.ink.opacity(0.42) }
    public static var border: Color { look.ink.opacity(0.10) }
    public static var borderStrong: Color { look.ink.opacity(0.18) }

    /// 半透明卡片和圆钮的底。永远站在字色的对面。
    public static var panelFill: Color { look.panel }
    /// 输入框那条。跟侧栏同色 —— 这两块看着得是一套的。
    public static var composerFill: Color { look.composer }
    public static var controlRim: Color { look.rim }
    public static var sidebarFill: Color { look.sidebar }

    /// 列表里选中那一条的底：侧栏色压深两号。
    /// 跟着侧栏本身的颜色走，而不是一块跟环境脱节的固定色。
    public static var rowActive: Color { look.sidebar.shaded(2) }
    public static var rowInk: Color { look.ink }
    public static let rowRadius: CGFloat = 10
    public static var sectionColor: Color { look.ink.opacity(0.62) }

    // MARK: - 内置壁纸
    //
    // ⚠️ 这里读的是 **App Bundle 里的图**。仓库里不含任何壁纸文件，
    // 你要自己把图拖进 Assets.xcassets 或 Bundle，然后把名字写进下面这个数组。
    // 数组留空时设置页只会显示一个"＋"（从相册加），不会崩。
    //
    // 想让壁纸走服务器（多端共用同一批图）就改 `WallCache.builtinImage`，
    // 那儿只有一处要动。

    public static let walls: [String] = [
        // "wall-1", "wall-2", "wall-3", "wall-4", "wall-5",
    ]

    /// 侧栏那层贴图的名字。没有就留 nil，侧栏是纯色。
    public static let sidebarTexture: String? = nil
}

// MARK: - 小工具

extension Color {
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 往暗里挪 `steps` 号。一号 = 亮度 −9% + 饱和 +6%，
    /// 跟 `BubbleTint` 那根明暗杆同一个方向。
    ///
    /// ⚠️ 底色本来就很暗时不能再往下压：黑上加黑等于没有选中态。
    /// 那种情况原样往**亮**里挪同样的量，"差一档"这个观感才留得住。
    public func shaded(_ steps: Int) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard steps > 0,
              UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        else { return self }

        let n = CGFloat(steps)
        let darker = b > 0.30
        return Color(uiColor: UIColor(
            hue: h,
            saturation: min(1, darker ? s * (1 + 0.06 * n) : s),
            brightness: darker ? max(0.05, b - 0.09 * n) : min(1, b + 0.09 * n),
            alpha: a
        ))
    }
}

/// 聊天气泡的形状：靠头像那一侧的上角是小圆角，其余三个大圆角。
///
/// 只在设置页的预览里用到 —— 换成你自己 App 的气泡形状即可，
/// 这个类型不参与主题逻辑。
public struct BubbleShape: Shape {
    public let mine: Bool
    private let tip: CGFloat = 4
    private let round: CGFloat = 10

    public init(mine: Bool) { self.mine = mine }

    public func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: mine ? round : tip,
            bottomLeadingRadius: round,
            bottomTrailingRadius: round,
            topTrailingRadius: mine ? tip : round,
            style: .continuous
        )
        .path(in: rect)
    }
}
