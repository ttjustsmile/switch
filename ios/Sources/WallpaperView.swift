import SwiftUI
import PhotosUI

/// 壁纸 + 配色设置页。
///
/// 版式抄微信「聊天壁纸」：上面一叠设置行，下面九宫格壁纸，「＋」跟在内置那些后面。
/// 浮层抄 iOS 主屏「自定义」：顶上一个**活的**预览，下面粗滑杆，拖的时候预览跟着变。
///
/// 改完立刻全局生效 —— 壁纸和配色都由 `Appearance` / `WallStore` 广播，
/// 所有页面共用同一层 `WallBackground`。
///
/// 自己套导航壳：
///
///     NavigationStack {
///         WallpaperView().navigationTitle("聊天壁纸")
///     }
public struct WallpaperView: View {
    @ObservedObject private var walls = WallStore.shared
    @ObservedObject private var look = Appearance.shared

    @State private var tweak: Tweak?
    @State private var photo: PhotosPickerItem?
    @State private var deleting: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let tileRadius: CGFloat = 14
    /// 格子按手机屏幕的比例站
    private let tileRatio: CGFloat = 0.62

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                settings
                wallpapers
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { WallBackground() }
        .sheet(item: $tweak) { TweakSheet(kind: $0) }
        // 相册选完立刻存盘并选中 —— 用户刚挑完图，当然是想马上看见
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                photo = nil
                guard let data else { return }
                walls.addCustom(data)
            }
        }
        .confirmationDialog(
            "删掉这张壁纸？",
            isPresented: Binding(get: { deleting != nil },
                                 set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("删掉", role: .destructive) {
                if let name = deleting { walls.removeCustom(name) }
                deleting = nil
            }
            Button("算了", role: .cancel) { deleting = nil }
        }
    }

    // MARK: - 上面那叠设置行

    private var settings: some View {
        VStack(spacing: 0) {
            row(TintTarget.incoming.title, swatch: look.color(.incoming)) { tweak = .tint(.incoming) }
            hairline
            row(TintTarget.outgoing.title, swatch: look.color(.outgoing)) { tweak = .tint(.outgoing) }
            hairline
            row("字体颜色", value: look.ink.title, swatch: look.ink.color) { tweak = .ink }
            hairline
            row("气泡透明度", value: "\(Int((look.bubbleOpacity * 100).rounded()))%") { tweak = .opacity }
            hairline
            row("背景模糊度", value: look.wallBlur < 0.5 ? "关" : "\(Int(look.wallBlur.rounded()))") { tweak = .blur }
            hairline
            row(TintTarget.sidebar.title, swatch: look.color(.sidebar)) { tweak = .tint(.sidebar) }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var hairline: some View {
        Rectangle().fill(Theme.border).frame(height: 1).padding(.leading, 16)
    }

    private func row(_ title: String, value: String? = nil, swatch: Color? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let swatch {
                    Circle()
                        .fill(swatch)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Theme.borderStrong, lineWidth: 1))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            // ⚠️ 不加这句的话，行里的空白处点不动 —— 只有文字和色点是可点的
            .contentShape(Rectangle())
        }
        .buttonStyle(FadeRow())
    }

    // MARK: - 壁纸格子

    private var wallpapers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("壁纸")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.sectionColor)
                .padding(.leading, 2)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Theme.walls, id: \.self) { tile(.builtin($0)) }
                // 「＋」固定跟在内置那几张后面，不放到最末尾 ——
                // 格子越加越多时手指记得住位置，不用每次翻到底去找
                addTile
                ForEach(walls.customs, id: \.self) { name in
                    tile(.custom(name)).contextMenu {
                        Button(role: .destructive) { deleting = name } label: {
                            Label("删掉", systemImage: "trash")
                        }
                    }
                }
            }

            Text("挑好的壁纸会用在所有界面。自己加的图长按可以删。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 2)
                .padding(.top, 2)
        }
    }

    private func tile(_ source: WallSource) -> some View {
        let on = walls.current == source
        let shape = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
        return Button { walls.pick(source) } label: {
            WallThumb(source: source)
                .aspectRatio(tileRatio, contentMode: .fit)
                .clipShape(shape)
                .overlay {
                    shape.stroke(on ? Theme.accent : Color.black.opacity(0.10),
                                 lineWidth: on ? 2.5 : 1)
                }
                .overlay {
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.accent))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// 一个虚线框 + 中间一个「＋」，点开相册。
    private var addTile: some View {
        let shape = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
        return PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
            ZStack {
                shape.fill(.white.opacity(0.45))
                shape.strokeBorder(Theme.borderStrong,
                                   style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Theme.borderStrong, lineWidth: 1.2))
            }
            .aspectRatio(tileRatio, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

/// 设置行按下去只淡一下，不整块变色 —— 上面那张卡是半透明的，
/// 铺一层底色会在壁纸上压出一块补丁。
private struct FadeRow: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}

// MARK: - 浮层

/// 浮层调的是哪一样。
public enum Tweak: Identifiable, Hashable {
    case tint(TintTarget)
    case ink, opacity, blur

    public var id: String {
        switch self {
        case .tint(let target): return "tint.\(target.rawValue)"
        case .ink: return "ink"
        case .opacity: return "opacity"
        case .blur: return "blur"
        }
    }

    var title: String {
        switch self {
        case .tint(let target): return target.title
        case .ink: return "字体颜色"
        case .opacity: return "气泡透明度"
        case .blur: return "背景模糊度"
        }
    }

    /// 预览里单独站出来的那一只气泡。字色 / 透明度 / 模糊度是两边一起变的，
    /// 所以都摆着；侧栏那档根本不是气泡，预览换成一小片侧栏。
    var focus: TintTarget? {
        if case .tint(let target) = self { return target }
        return nil
    }
    var isSidebar: Bool { focus == .sidebar }

    var height: CGFloat {
        switch self {
        case .tint: return 400
        case .ink:  return 365
        default:    return 300
        }
    }
}

private struct TweakSheet: View {
    let kind: Tweak

    @ObservedObject private var look = Appearance.shared

    var body: some View {
        VStack(spacing: 16) {
            Text(kind.title)
                .font(.system(size: 15, weight: .semibold))
                // ⚠️ 浮层里的字要用 `.secondary` 而不是 Theme.ink：
                // `presentationBackground(.regularMaterial)` 是浅色的，而且**不吃**
                // 内容里的 colorScheme override —— 用户选了白字的话，
                // Theme.ink 是白的，压在浅色毛玻璃上就看不见了。
                .foregroundStyle(.secondary)

            if kind.isSidebar {
                SidebarPreview()
            } else {
                // 字色那档把输入框也摆进来 —— 要看的就是这两样一起翻
                BubblePreview(focus: kind.focus, showComposer: kind == .ink)
            }

            controls

            // ⚠️ 这颗按钮原先摆在标题那一行的右边，怎么点都点不动 ——
            // sheet 顶上那个抓手（presentationDragIndicator）的热区一路盖到
            // 标题的高度，手指全被它吃掉。放到底下就没人跟它抢了。
            if case .tint(let target) = kind, !look.isDefault(target) {
                Button("恢复默认") { look.resetTint(target) }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .presentationDetents([.height(kind.height)])
        .presentationCornerRadius(30)
        .presentationBackground(.regularMaterial)
        .presentationDragIndicator(.visible)
    }

    // MARK: 控件

    @ViewBuilder
    private var controls: some View {
        switch kind {
        case .tint(let target): tintSliders(target)
        case .ink:              inkPicker
        case .opacity:          opacitySlider
        case .blur:             blurSlider
        }
    }

    private func tintSliders(_ target: TintTarget) -> some View {
        let tint = look.tint(target)
        return VStack(spacing: 12) {
            // 色相
            TweakSlider(
                value: Binding(
                    get: { tint.hue },
                    set: { look.setTint(Self.hued(tint, $0), for: target) }
                ),
                gradient: Self.rainbow,
                knob: tint.color
            )
            // 明暗：白 → 纯色 → 灰 → 黑。
            // 渐变直接画出这根杆子上每一处的**真实颜色**，所以灰和黑那一段
            // 是看得见的 —— 用户能一眼看出这根杆能调到哪儿。
            TweakSlider(
                value: Binding(
                    get: { tint.level },
                    set: { look.setTint(BubbleTint(hue: tint.hue, level: $0), for: target) }
                ),
                gradient: Self.depth(tint.hue),
                knob: tint.color
            )
        }
    }

    private var inkPicker: some View {
        HStack(spacing: 14) {
            ForEach(BubbleInk.allCases) { choice in
                Button { look.setInk(choice) } label: {
                    VStack(spacing: 8) {
                        Text("示例文字")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(choice.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(look.bubbleFill(mine: true))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(look.ink == choice
                                            ? Theme.accent : Color.black.opacity(0.10),
                                            lineWidth: look.ink == choice ? 2.5 : 1)
                            )
                        Text(choice.title)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var opacitySlider: some View {
        let range = Appearance.opacityRange
        let color = look.color(.outgoing)
        return TweakSlider(
            value: Binding(
                get: { (look.bubbleOpacity - range.lowerBound)
                       / (range.upperBound - range.lowerBound) },
                set: { look.setOpacity(range.lowerBound
                       + $0 * (range.upperBound - range.lowerBound)) }
            ),
            gradient: [color.opacity(range.lowerBound), color],
            knob: .white
        )
    }

    private var blurSlider: some View {
        let range = Appearance.blurRange
        return TweakSlider(
            value: Binding(
                get: { look.wallBlur / range.upperBound },
                set: { look.setBlur($0 * range.upperBound) }
            ),
            gradient: [.white, Color(hex: 0xB9B7B0)],
            knob: .white
        )
    }

    // MARK: 渐变

    private static let rainbow: [Color] = stride(from: 0.0, through: 1.0, by: 1.0 / 12.0)
        .map { Color(hue: $0, saturation: 0.85, brightness: 0.95) }

    /// 整根杆的真色：白 → 纯色 → 灰 → 黑，取 13 个点画渐变
    private static func depth(_ hue: Double) -> [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0)
            .map { BubbleTint(hue: hue, level: $0).color }
    }

    /// ⚠️ 纯白（和纯黑）那两头**没有色相可言** —— 停在那儿拖彩虹条，
    /// 屏幕上什么都不会变，用户会以为控件坏了。
    /// 所以从两头第一次拖色相时，顺手往中间挪一点点。
    private static func hued(_ tint: BubbleTint, _ hue: Double) -> BubbleTint {
        var level = tint.level
        if level < 0.03 { level = 0.07 }    // 白那头 → 一点点淡色
        if level > 0.97 { level = 0.9 }     // 黑那头 → 一点点暗色
        return BubbleTint(hue: hue, level: level)
    }
}

// MARK: - 预览

/// 浮层顶上那块活预览：当前壁纸 + 当前配色，拖滑杆时一起变。
private struct BubblePreview: View {
    /// 单独看哪一边。nil = 两边都摆出来。
    var focus: TintTarget?
    /// 顺带摆一条输入框（字色那档要看这两样是不是一起翻的）
    var showComposer = false

    @ObservedObject private var look = Appearance.shared
    @ObservedObject private var walls = WallStore.shared

    var body: some View {
        ZStack {
            // ⚠️ 预览只有真机的三分之一宽，模糊半径要按比例缩一下
            // 才是同一个观感 —— 原样给的话预览糊得多得多。
            WallThumb(source: walls.current, blur: look.wallBlur * 0.75)
            VStack(alignment: .leading, spacing: 8) {
                if focus != .outgoing { sample("今天天气不错", mine: false) }
                if focus != .incoming { sample("适合出去走走", mine: true) }
                if showComposer { composerSample.padding(.top, 4) }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: showComposer ? 168 : 132)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var composerSample: some View {
        HStack(spacing: 8) {
            Text("说点什么…")
                .font(.system(size: 13))
                .foregroundStyle(look.ink.color.opacity(0.75))
            Spacer(minLength: 0)
            Image(systemName: "mic")
                .font(.system(size: 12))
                .foregroundStyle(look.ink.color.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Theme.composerFill)
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Theme.controlRim, lineWidth: 1))
        )
    }

    private func sample(_ text: String, mine: Bool) -> some View {
        HStack(spacing: 0) {
            if mine { Spacer(minLength: 24) }
            Text(text)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(look.ink.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    BubbleShape(mine: mine)
                        .fill(look.bubbleFill(mine: mine))
                        .shadow(color: Theme.bubbleShadow, radius: Theme.shadowRadius, y: 1)
                )
            if !mine { Spacer(minLength: 24) }
        }
    }
}

/// 侧栏那档的预览：一小片侧栏（底色 + 贴图 + 两行导航 + 一条选中的会话），
/// 右边露出被推开的主界面和它底下那条输入框。
///
/// 摆这么全是因为侧栏这一档牵着三样东西：侧栏本身、选中条（压深两号）、
/// 输入框（同色）。拖杆的时候得能一眼看见这三块是不是一套的。
private struct SidebarPreview: View {
    @ObservedObject private var look = Appearance.shared
    @State private var texture: UIImage?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                row("搜索", "magnifyingglass")
                row("壁纸", "cube")
                sessionRow("会话标题")
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background {
                ZStack {
                    look.color(.sidebar)
                    if let texture {
                        Image(uiImage: texture)
                            .resizable()
                            .scaledToFill()
                            // 跟真侧栏同一套：底色不是出厂那层就正片叠底，
                            // 否则不透明的贴图会把用户调的颜色整个盖住
                            .blendMode(look.sidebarNeedsBlend ? .multiply : .normal)
                    }
                }
            }
            // 右边这条是被推开的主界面，看得出侧栏和主界面的关系；
            // 底下那截输入框跟侧栏同色，挨着摆才看得出"是一套的"
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Capsule()
                    .fill(Theme.composerFill)
                    .frame(height: 26)
                    .overlay(Capsule().stroke(Theme.controlRim, lineWidth: 1))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
            }
            .frame(width: 72)
        }
        .frame(height: 132)
        .background(WallThumb(source: WallStore.shared.current))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .task {
            guard let name = Theme.sidebarTexture else { return }
            texture = UIImage(named: name)
        }
    }

    private func row(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13))
            Text(title).font(.system(size: 14))
        }
        .foregroundStyle(Theme.textPrimary)
    }

    /// 列表里选中的那条：底色是侧栏色压深两号
    private func sessionRow(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14))
            .foregroundStyle(Theme.rowInk)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                    .fill(Theme.rowActive)
            )
            .padding(.trailing, 10)
    }
}

// MARK: - 滑杆

/// 粗滑杆：一条 56 高的胶囊，里面是渐变，白圆钮在上面跑。
/// 点哪儿跳哪儿，按住能拖。
private struct TweakSlider: View {
    @Binding var value: Double
    let gradient: [Color]
    var knob: Color = .white

    private let height: CGFloat = 56
    private let pad: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let size = height - pad * 2
            let travel = max(1, geo.size.width - size - pad * 2)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule().fill(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                )
                Circle()
                    .fill(knob)
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .offset(x: pad + travel * clamped(value))
            }
            .frame(height: height)
            .contentShape(Rectangle())
            // ⚠️ minimumDistance 必须是 0：默认值要求先拖动一小段才触发，
            // 于是"点一下让钮跳过去"这个操作完全失效，只能拖。
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    value = clamped((g.location.x - size / 2 - pad) / travel)
                }
            )
        }
        .frame(height: height)
    }

    private func clamped(_ x: Double) -> Double { min(max(x, 0), 1) }
}
