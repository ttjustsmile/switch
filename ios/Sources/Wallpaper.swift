import SwiftUI
import UIKit

// MARK: - 一张壁纸的来路

/// 内置的（App Bundle 里）还是用户自己从相册加的（沙盒里）。
public enum WallSource: Hashable, Identifiable, Sendable {
    /// Bundle / Assets 里的图片名，写在 `Theme.walls` 里
    case builtin(String)
    /// 沙盒里的文件名
    case custom(String)

    public var id: String {
        switch self {
        case .builtin(let name): return "builtin:\(name)"
        case .custom(let name):  return "custom:\(name)"
        }
    }

    /// 存进 UserDefaults 的是这个 id，反过来也要认得回来
    public init?(id: String) {
        if id.hasPrefix("builtin:") { self = .builtin(String(id.dropFirst(8))) }
        else if id.hasPrefix("custom:") { self = .custom(String(id.dropFirst(7))) }
        else { return nil }
    }
}

// MARK: - 自己加的壁纸存哪儿

public enum WallFiles {
    /// ⚠️ 必须是 Application Support，**不能用 Caches**。
    /// Caches 里的东西系统缺空间时会直接删掉 —— 用户自己加的图就这么没了，
    /// 而且没有任何提示，表现成"壁纸自己变回默认的了"。
    ///
    /// 也别把这个路径挂成 `WallStore` 的静态成员：那个类是 @MainActor 的，
    /// 静态成员跟着主线程隔离，`WallCache` 那个 actor 里就取不到路径了。
    public static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    public static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }
}

// MARK: - 当前铺哪张

/// 现在铺的是哪张壁纸，以及用户自己加过哪些。
@MainActor
public final class WallStore: ObservableObject {
    public static let shared = WallStore()

    private static let pickKey = "wallpaperPick"       // WallSource.id
    private static let listKey = "wallpaperCustomList" // 自己加的文件名，按加入顺序

    @Published public private(set) var customs: [String] = []
    /// 用户挑过的那张。nil = 没挑过，用内置第一张。
    @Published public private(set) var choice: WallSource?

    private init() {
        let d = UserDefaults.standard
        // 文件可能被用户在「文件」App 里删了，或者换机时没跟过来 ——
        // 对不上的直接不列，否则格子里会出现一片永远加载不出来的灰
        customs = (d.array(forKey: Self.listKey) as? [String] ?? [])
            .filter { FileManager.default.fileExists(atPath: WallFiles.url($0).path) }

        if let raw = d.string(forKey: Self.pickKey),
           let c = WallSource(id: raw), exists(c) {
            choice = c
        }
    }

    /// 现在这张。内置列表为空且没加过图时返回 nil，调用方铺纯色兜底。
    public var current: WallSource? {
        if let choice { return choice }
        if let first = Theme.walls.first { return .builtin(first) }
        if let first = customs.first { return .custom(first) }
        return nil
    }

    public func pick(_ c: WallSource) {
        guard exists(c) else { return }
        choice = c
        UserDefaults.standard.set(c.id, forKey: Self.pickKey)
    }

    /// 随机换一张（Switch 按钮那种用法），**避开当前这张** ——
    /// 点了画面没变，用户会以为按钮坏了。
    public func shuffle() {
        let all = Theme.walls.map { WallSource.builtin($0) } + customs.map { WallSource.custom($0) }
        guard all.count > 1 else {
            if let one = all.first { pick(one) }
            return
        }
        let rest = all.filter { $0 != current }
        if let next = rest.randomElement() { pick(next) }
    }

    /// 从相册加一张。存盘 → 进列表 → 顺手选中
    /// （用户刚挑完图，当然是想马上看到）。
    @discardableResult
    public func addCustom(_ data: Data) -> Bool {
        guard let image = UIImage(data: data), let jpeg = Self.encode(image) else { return false }
        let name = "wall-\(UUID().uuidString.prefix(8).lowercased()).jpg"
        do { try jpeg.write(to: WallFiles.url(name)) } catch { return false }
        customs.append(name)
        UserDefaults.standard.set(customs, forKey: Self.listKey)
        pick(.custom(name))
        return true
    }

    public func removeCustom(_ name: String) {
        customs.removeAll { $0 == name }
        UserDefaults.standard.set(customs, forKey: Self.listKey)
        try? FileManager.default.removeItem(at: WallFiles.url(name))
        if choice == .custom(name) {
            choice = nil
            UserDefaults.standard.removeObject(forKey: Self.pickKey)
        }
        Task { await WallCache.shared.drop(.custom(name)) }
    }

    private func exists(_ c: WallSource) -> Bool {
        switch c {
        case .builtin(let name): return Theme.walls.contains(name)
        case .custom(let name):  return customs.contains(name)
        }
    }

    /// 相册原图可能是 4000px 的 HEIC，铺一整屏用不到那么大 ——
    /// 长边压到 2400 再存 JPEG，省内存也省磁盘。顺手把 HEIC 转掉：
    /// `UIImage` 读得了，但每次解码都慢一截。
    private static func encode(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 2400
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image.jpegData(compressionQuality: 0.9) }

        let scale = maxSide / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.9)
    }
}

// MARK: - 解码缓存

/// 壁纸图的缓存。
///
/// ⚠️ 这一层不是可选的优化。壁纸同时出现在：整屏背景、设置页九宫格里的每一格、
/// 浮层里的预览。没有缓存的话同一张图会被并发解码十几次 —— 打开设置页会明显卡一下，
/// 内存也会瞬间冲高。
public actor WallCache {
    public static let shared = WallCache()

    private var memory: [WallSource: UIImage] = [:]

    public func image(for source: WallSource) async -> UIImage? {
        if let hit = memory[source] { return hit }

        let image: UIImage?
        switch source {
        case .builtin(let name):
            image = Self.builtinImage(name)
        case .custom(let name):
            image = (try? Data(contentsOf: WallFiles.url(name))).flatMap(UIImage.init(data:))
        }
        if let image { memory[source] = image }
        return image
    }

    /// 内置壁纸从哪儿读。
    ///
    /// 现在是 Bundle / Assets。想改成走服务器（多端共用同一批图）只改这一处：
    /// 换成一次 URLSession 请求 + 一份磁盘缓存即可，其余代码不用动。
    private static func builtinImage(_ name: String) -> UIImage? {
        UIImage(named: name)
    }

    public func drop(_ source: WallSource) {
        memory[source] = nil
    }
}

// MARK: - 铺在整屏后面的那一层

/// 当前壁纸 + 用户调的模糊度。放在页面最底下。
///
/// ⚠️ 模糊必须给 `opaque: true`。默认那个会把图**边缘之外**当透明来采样，
/// 于是四条边各糊出一圈越来越淡的白边，模糊度拉大时特别明显 ——
/// 看着像壁纸没铺满。
public struct WallBackground: View {
    @ObservedObject private var walls = WallStore.shared
    @ObservedObject private var look = Appearance.shared

    @State private var image: UIImage?

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 图还没解出来时先垫一层底色，别闪白
                Theme.surface
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: look.wallBlur, opaque: true)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .task(id: walls.current) {
            guard let source = walls.current else { image = nil; return }
            image = await WallCache.shared.image(for: source)
        }
    }
}

/// 设置页九宫格里的一格，以及浮层预览里那块小图。
public struct WallThumb: View {
    public let source: WallSource?
    /// 浮层预览里要跟着「背景模糊度」一起糊；九宫格本身不糊，
    /// 糊了就认不出是哪张了。
    public var blur: Double = 0

    @State private var image: UIImage?

    public init(source: WallSource?, blur: Double = 0) {
        self.source = source
        self.blur = blur
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.surface
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: blur, opaque: true)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: source) {
            guard let source else { image = nil; return }
            image = await WallCache.shared.image(for: source)
        }
    }
}
