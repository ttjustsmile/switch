# Switch — iOS 版

SwiftUI 的壁纸 + 配色系统。用户能调的：

- 壁纸：内置九宫格 + 从相册加（长按删）
- 三处颜色：对方气泡 / 我的气泡 / 侧栏，每处两根滑杆（色相 + 明暗）
- 全局字色：黑 / 白两档
- 气泡透明度、背景模糊度

改完立刻全局生效 —— 所有页面共用同一层 `WallBackground`，配色由 `Appearance` 广播。

## 装

iOS 17+。四个文件，直接拖进项目，或者当 Swift Package 加。

```swift
NavigationStack {
    WallpaperView().navigationTitle("聊天壁纸")
}
```

页面背景铺上这一层：

```swift
YourView().background { WallBackground() }
```

气泡填色走这里，别自己写死：

```swift
.background(BubbleShape(mine: mine).fill(Appearance.shared.bubbleFill(mine: mine)))
```

## 放壁纸

图拖进 `Assets.xcassets`，名字写进 `Theme.swift`：

```swift
public static let walls: [String] = ["wall-1", "wall-2", "wall-3"]
```

留空也能跑，设置页只显示一个"＋"。

想让壁纸走服务器（多端共用同一批图）：只改 `WallCache.builtinImage` 一处，换成一次网络请求 + 磁盘缓存，其余代码不动。

## 四个文件

| 文件 | 管什么 |
|---|---|
| `Theme.swift` | 出厂配色 token。用户能调的那些写成 `var`，从 `look` 快照取 |
| `Appearance.swift` | 配色状态机：两根滑杆的模型、字色、存取、`Look` 快照 |
| `Wallpaper.swift` | 壁纸来源、沙盒存取、解码缓存、铺在屏幕后面那一层 |
| `WallpaperView.swift` | 设置页 UI：设置行、九宫格、调色浮层、粗滑杆 |

## 接自己的 App 要动的地方

1. `Theme.walls` 填内置壁纸名
2. `TintTarget` 的三个 case 是"哪几处能调色"。想加一处（比如导航栏）就加个 case，跟着编译报错走一遍
3. `Theme` 里那些 `var` 是全局色的出口，你的组件从这里取色就自动跟着用户设置走

## 为什么有 `look` 这个全局变量

```swift
public nonisolated(unsafe) var look = Look.stored
```

看着像个坏味道，但它是必须的：`Theme` 里那些颜色会在 `ButtonStyle`、`Canvas` 闭包这类**不带主线程隔离**的上下文里被读到，直接摸 `@MainActor` 的 `Appearance.shared` 过不了并发检查。

所以是这个约定：**只在主线程写（`Appearance.sync()` 一处），读的地方全在渲染路径上。**

初值直接从 `UserDefaults` 读，不等 `Appearance.shared` 被谁碰一下才成型 —— 开屏第一帧（闪屏、登录页）没人订阅 `Appearance`，那时候要是读到出厂黑，用户设的白字要等进主界面才生效，中间闪一下。

## 踩过的坑（注释里都有，这里挑几条要紧的）

**自己加的壁纸不能放 Caches。** 系统缺空间时直接删掉且无提示，表现成"壁纸自己变回默认的了"。要放 Application Support。

**模糊必须 `blur(radius:opaque: true)`。** 默认那个会把图边缘之外当透明采样，四条边各糊出一圈白边，模糊度拉大时特别明显，看着像壁纸没铺满。

**侧栏贴图要正片叠底。** 贴图本身不透明，原样铺会把用户调的底色整个盖住 —— 底色一旦不是出厂那层就必须 `.blendMode(.multiply)`。

**浮层里的字用 `.secondary`，不能用 `Theme.ink`。** `presentationBackground(.regularMaterial)` 是浅色的且不吃内容里的 colorScheme override，用户选了白字的话压上去就看不见了。

**"恢复默认"别放标题那一行。** `presentationDragIndicator` 的热区一路盖到标题高度，放那儿的按钮怎么点都点不动。

**滑杆的 `DragGesture(minimumDistance: 0)`。** 默认值要求先拖一小段才触发，于是"点一下让钮跳过去"完全失效，只能拖。

**设置行要 `.contentShape(Rectangle())`。** 不加的话只有文字和色点可点，行里的空白处点不动。

**预览里的模糊要按比例缩。** 预览只有真机三分之一宽，模糊半径原样给的话预览糊得多得多，调出来的值到了真机上不是那个观感。
