# Switch — Web 版

聊天界面的壁纸切换。一颗按钮换一张背景图，整套主题颜色跟着翻。

先打开 `demo.html` 看效果（直接双击就行，不用起服务器）。demo 里的壁纸是 CSS 渐变占位，仓库里不含任何图片。

## 装

三步。

**1. 引导脚本内联进 `<head>`，放在样式表之前**

```html
<head>
  <script>
    /* 把 switch-boot.js 的内容原样粘在这里 */
  </script>
  <link rel="stylesheet" href="switch.css">
</head>
```

⚠️ 这一步不能省，也不能改成 `<script src="switch-boot.js">`。理由写在那个文件的顶部注释里，一句话版本：外链要等一次网络往返，在它回来之前首屏已经按默认色渲染过一帧了，用户看到的就是开屏白闪一下。

**2. 页面里放一个空的壁纸层**

```html
<body class="chat-ready">
  <div id="chatBg" aria-hidden="true"></div>
  ...
</body>
```

它必须是空元素。`z-index: 15` 压在内容下面，`pointer-events: none` 不吃点击。你的层级不一样就改 `switch.css` 里那一个数。

`chat-ready` 这个 class 是给首屏用的：加上它壁纸才显示。慢网络下没有这一步会先看到一张孤零零的壁纸，再"啪"地长出界面。

**3. 接按钮**

```html
<script src="switch.js"></script>
<script>
  document.getElementById('yourButton').onclick = () => Switch.random();
</script>
```

## 换成自己的图

把图放 `assets/`，然后改**两个地方**（`switch.js` 和 `switch-boot.js` 各有一份 `WALLS`）：

```js
var WALLS = [
  'assets/wall-1.jpg?v=1',
  'assets/wall-2.jpg?v=1'
];
var THEMES = ['light', 'dark'];   // 每张图配浅色还是深色主题
```

两处重复确实丑，但没有更好的办法：引导脚本必须内联且最先跑，那时候还引用不到 `switch.js`。

⚠️ 路径后面那个 `?v=1` 不是摆设。改图但不改文件名时，浏览器缓存和 Service Worker 里的旧图会一直顶着，怎么刷新都是老的。**换图记得把版本号 +1**。

## API

```js
Switch.random()    // 随机换一张，不会换到当前这张
Switch.next()      // 按顺序下一张
Switch.set(2)      // 切到第 3 张
Switch.current()   // 当前下标
Switch.preload()   // 预加载全部壁纸（可选，避免第一次切换时白一下）
```

## 主题变量

壁纸是浅色图就在 `THEMES` 里标 `'light'`，深色图标 `'dark'`。切换时 `<html>` 上的 `data-chat-bg` 跟着变，下面这些变量整套翻：

| 变量 | 用途 |
|---|---|
| `--bg-primary` / `--bg-surface` / `--bg-sunken` | 页面底、卡片底、按下态 |
| `--text-primary` / `--text-secondary` / `--text-faint` | 正文 / 次要 / 更淡 |
| `--border` / `--border-strong` | 描边两档 |
| `--shadow-soft` | 卡片投影 |
| `--composer-ink` / `--composer-ink-faint` | **输入框内部**的字（见下） |

**组件里一律用变量，不要写死色号** —— 写死的那些换到深色壁纸时会变成白底白字。

### ⚠️ 输入框那两个变量是唯一不跟主题翻的

`--composer-ink` 和 `--composer-ink-faint` 在深色主题下**仍然是深色**，因为输入框底色两套主题下都是浅的（深色壁纸上摆一条深色输入框会整个糊进背景，找不到该往哪儿打字）。

这里踩过一次：图省事给 placeholder 用了 `--text-secondary`，深色主题下就成了白底上一行浅灰字，基本看不见 —— 而那恰恰是最需要看清的一行。

**规律**：凡是底色不跟主题翻的控件，它的字色也必须单独开一档。

## 两条设计上的硬规矩

**壁纸铺在独立的 fixed 层，不是 `body` 的 background。** body 背景会跟着文档滚，长对话滚到底图就跑没了。fixed 层钉在视口上，字滚背景不动。另外侧栏推开主内容时，这一层要跟主内容吃同一个 transform，壁纸才会跟着被推走，而不是穿帮地停在原地。

**所有全屏面板铺的是同一个 `var(--chat-wallpaper)`。** 加新面板就把选择器加进 `switch.css` 里那条列表，别各自写死一张图 —— 写死的那些在换图之后会集体对不上。

## 一个不显眼但必须留着的东西

```css
html[data-chat-bg] body { isolation: isolate; }
```

不是装饰。壁纸层用了 `z-index`，如果 body 不开一个新的层叠上下文，页面里任何一个带 `mix-blend-mode` / `filter` 的元素都可能把这一层的叠放顺序算歪，表现是壁纸偶发盖住内容或整片变黑。
