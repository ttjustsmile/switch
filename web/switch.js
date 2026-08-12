/* ==========================================================================
 * Switch — 壁纸切换
 * ==========================================================================
 *
 * 用法：
 *   1. <head> 里内联 switch-boot.js（必须内联、必须在 CSS 之前，见那个文件）
 *   2. 页面里放一个 <div id="chatBg"></div>
 *   3. 引入这个文件，给你的按钮接上 Switch.random()
 *
 *   Switch.set(2)      切到第 3 张
 *   Switch.random()    随机换一张（不会换到当前这张）
 *   Switch.next()      按顺序下一张
 *   Switch.current()   当前下标
 * ========================================================================== */

(function (global) {
  'use strict';

  /* 你的壁纸列表。换成自己的路径。
   *
   * ⚠️ 每张图后面那个 ?v=N 不是摆设：壁纸改图但不改名时，
   * 用户浏览器和 Service Worker 里的旧图会一直顶着，怎么刷新都是老的。
   * 换图记得把版本号 +1。 */
  var WALLS = [
    'assets/wall-1.jpg?v=1',
    'assets/wall-2.jpg?v=1',
    'assets/wall-3.jpg?v=1',
    'assets/wall-4.jpg?v=1',
    'assets/wall-5.jpg?v=1'
  ];

  /* 每张图配的是浅色主题还是深色主题（决定 data-chat-bg 的值）。
   * 长度和 WALLS 对齐；给 null 表示沿用上一次的判断。
   * 全是浅色图的话整个数组填 'light' 就行。 */
  var THEMES = ['light', 'light', 'light', 'light', 'light'];

  var STORE_KEY = 'chatWallpaper';
  var THEME_KEY = 'chatBgMode';

  function clampIndex(i) {
    var n = WALLS.length;
    if (!n) return 0;
    /* 先取模再加一轮：JS 的 % 对负数返回负数，直接用会拿到 -1 */
    return ((i % n) + n) % n;
  }

  function readStored() {
    try {
      var i = parseInt(localStorage.getItem(STORE_KEY), 10);
      return isFinite(i) ? clampIndex(i) : 0;
    } catch (e) {
      /* 隐私模式下 localStorage 直接抛异常，不能让它拦住壁纸 */
      return 0;
    }
  }

  function apply(idx) {
    idx = clampIndex(idx);
    var theme = THEMES[idx] || 'light';
    var root = document.documentElement;

    root.setAttribute('data-chat-bg', theme);
    root.setAttribute('data-wallpaper', String(idx));
    root.style.setProperty('--chat-wallpaper', 'url(' + WALLS[idx] + ')');

    try {
      localStorage.setItem(STORE_KEY, String(idx));
      localStorage.setItem(THEME_KEY, theme);
    } catch (e) {
      /* 存不上就算了，这一次的切换照样生效 */
    }
    return idx;
  }

  function current() {
    var attr = parseInt(document.documentElement.getAttribute('data-wallpaper'), 10);
    return isFinite(attr) ? attr : readStored();
  }

  function random() {
    var cur = current();
    if (WALLS.length < 2) return apply(cur);

    /* 随机但**避开当前这张** —— 点了按钮画面没变，用户会以为按钮坏了。
     * 用 while + 次数上限而不是"从剩下的里面挑"：写法短，而且列表只有
     * 一张时不会死循环。 */
    var next = cur;
    var guard = 0;
    while (next === cur && guard++ < 8) {
      next = Math.floor(Math.random() * WALLS.length);
    }
    return apply(next);
  }

  function next() {
    return apply(current() + 1);
  }

  /* 预加载：不做的话第一次切到某张图会先白一下再出现。
   * 用 <link rel="preload"> 而不是 new Image()，让浏览器自己排优先级。 */
  function preload() {
    if (!document.head) return;
    WALLS.forEach(function (src) {
      var link = document.createElement('link');
      link.rel = 'preload';
      link.as = 'image';
      link.href = src;
      document.head.appendChild(link);
    });
  }

  global.Switch = {
    walls: WALLS,
    themes: THEMES,
    set: apply,
    random: random,
    next: next,
    current: current,
    preload: preload
  };
})(window);
