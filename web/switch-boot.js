/* ==========================================================================
 * Switch — 防首屏闪烁的引导脚本
 * ==========================================================================
 *
 * ⚠️ 这段必须**内联**写进 <head>，而且要在样式表之前。整套东西里
 * 最容易被"优化"掉、一优化就出问题的就是它。
 *
 * 为什么不能像 switch.js 那样用 <script src>：
 *
 *   外链脚本要等一次网络往返。在它回来之前，--chat-wallpaper 是空的、
 *   data-chat-bg 也没挂上 —— 于是首屏先按默认色渲染一帧（浅色主题下是
 *   一片白），拿到值之后再重画成用户上次挑的深色壁纸。用户看到的就是
 *   开屏白闪一下。冷启动、弱网、Service Worker 没命中时尤其明显。
 *
 * 为什么要在样式表之前：
 *
 *   要赶在浏览器第一次算样式**之前**把 data-chat-bg 挂到 <html> 上。
 *   晚一步，第一帧就已经按没有这个属性的规则算完了。
 *
 * 为什么整段包在 try 里：
 *
 *   Safari 无痕模式下读 localStorage 直接抛异常。不兜住的话，
 *   <head> 里一个未捕获的异常会让后面的初始化整串不执行。
 * ========================================================================== */

(function () {
  /* ⚠️ 这份列表要和 switch.js 里那份保持一致。
   * 两处都写确实是重复，但没有更好的办法：这段必须内联、必须先跑，
   * 而 switch.js 是后加载的，这时候还引用不到它。改图记得改两处。 */
  var WALLS = [
    'assets/wall-1.jpg?v=1',
    'assets/wall-2.jpg?v=1',
    'assets/wall-3.jpg?v=1',
    'assets/wall-4.jpg?v=1',
    'assets/wall-5.jpg?v=1'
  ];
  var THEMES = ['light', 'light', 'light', 'light', 'light'];

  var idx = 0;
  try {
    idx = parseInt(localStorage.getItem('chatWallpaper'), 10);
    if (!isFinite(idx) || idx < 0 || idx >= WALLS.length) idx = 0;
  } catch (e) {
    idx = 0;
  }

  var root = document.documentElement;
  root.setAttribute('data-chat-bg', THEMES[idx] || 'light');
  root.setAttribute('data-wallpaper', String(idx));
  root.style.setProperty('--chat-wallpaper', 'url(' + WALLS[idx] + ')');
})();
