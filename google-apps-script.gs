/**
 * Kome flyer – cầu nối Google Sheets → công cụ flyer.
 * Dán toàn bộ file này vào Tiện ích mở rộng → Apps Script của file campaign, Lưu,
 * rồi Triển khai → Quản lý triển khai → Chỉnh sửa → Phiên bản mới → Triển khai.
 * Xem hướng dẫn chi tiết trong HUONG-DAN.txt.
 *
 * Chỉ trả về các cột in lên flyer (mã, tên, danh mục, giá cũ/giá sale lẻ, %OFF, EXP) của các tab tháng
 * (tên dạng 2026/10…). Giá vốn, lãi, tồn kho và các tab khác KHÔNG bao giờ được gửi ra.
 *
 * ?action=list                 → {tabs:[{name, gid}]}
 * ?action=weeks&gid=…          → {name, gid, weeks:[{week, period, count}]}
 * ?gid=…&week=…                → {name, gid, week, period, rows:[[header…], …]}
 * ?callback=fn                 → JSONP
 */
var TAB_RE = /^\d{4}\s*\/\s*\d{1,2}/;          // tab tháng: 2026/10, 2025/7（西村担当）…
// cột cần lấy: [tiêu đề gửi cho flyer, các tên cột có thể gặp trong sheet]
var COLS = [
  ['週目', ['週目']],
  ['%OFF', ['%OFF', 'OFF']],
  ['商品コード', ['商品コード']],
  ['区分', ['食品分類名', '区分', '分類']],
  ['商品名', ['商品名']],
  ['税込旧価格', ['税込旧価格（円）', '税込旧価格']],
  ['税込セール価格', ['バラー税込セール価格（円）', 'バラ税込セール価格（円）', '税込セール価格（円）', '税込セール価格']],
  ['EXP', ['EXP', '賞味期限']]
];

function doGet(e) {
  var p = (e && e.parameter) || {};
  var out;
  try {
    var tabs = SpreadsheetApp.getActiveSpreadsheet().getSheets().filter(function (s) {
      return !s.isSheetHidden() && TAB_RE.test(s.getName());
    });
    if (p.action === 'list') {
      out = {tabs: tabs.map(function (s) { return {name: s.getName(), gid: s.getSheetId()}; })};
    } else {
      var sh = tabs.filter(function (s) { return String(s.getSheetId()) === String(p.gid); })[0];
      if (!sh) throw new Error('Không có tab tháng này');
      var t = readTab(sh);
      if (p.action === 'weeks') {
        out = {name: sh.getName(), gid: sh.getSheetId(), weeks: t.weeks};
      } else {
        var w = String(p.week || '');
        var body = t.rows.filter(function (r) { return !w || r.week === w; }).map(function (r) { return r.cells; });
        var info = t.weeks.filter(function (x) { return x.week === w; })[0];
        out = {name: sh.getName(), gid: sh.getSheetId(), week: w, period: info ? info.period : '',
               rows: [COLS.map(function (c) { return c[0]; })].concat(body)};
      }
    }
  } catch (err) {
    out = {error: String(err && err.message || err)};
  }
  var json = JSON.stringify(out);
  var cb = String(p.callback || '');
  if (/^[A-Za-z_$][\w$]{0,63}$/.test(cb)) {
    return ContentService.createTextOutput(cb + '(' + json + ');').setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(json).setMimeType(ContentService.MimeType.JSON);
}

function clean(s) { return String(s).replace(/\s+/g, '').replace(/（/g, '(').replace(/）/g, ')'); }

function readTab(sh) {
  var all = sh.getDataRange().getDisplayValues();
  // dòng tiêu đề = dòng đầu tiên (trong 15 dòng) có ô 商品コード
  var h = -1;
  for (var i = 0; i < Math.min(15, all.length) && h < 0; i++) {
    if (all[i].some(function (c) { return clean(c) === '商品コード'; })) h = i;
  }
  if (h < 0) throw new Error('Không tìm thấy dòng tiêu đề (商品コード) trong tab ' + sh.getName());
  var head = all[h].map(clean);
  var idx = COLS.map(function (c) {
    for (var k = 0; k < c[1].length; k++) {
      var j = head.indexOf(clean(c[1][k]));
      if (j >= 0) return j;
    }
    return -1;
  });
  var iWeek = idx[0], iCode = idx[2];
  var iPeriod = head.indexOf('期間');
  var rows = [], weeks = [], wmap = {}, cur = '';
  for (var r = h + 1; r < all.length; r++) {
    var row = all[r];
    if (iWeek >= 0 && row[iWeek] !== '') cur = String(row[iWeek]).trim();
    var wk = iWeek >= 0 ? cur : '';
    if (!wmap[wk]) { wmap[wk] = {week: wk, period: '', count: 0}; weeks.push(wmap[wk]); }
    // 期間 có thể nằm ở dòng 合計 hoặc dòng sản phẩm đầu tiên của tuần
    if (iPeriod >= 0 && row[iPeriod] && !wmap[wk].period) wmap[wk].period = String(row[iPeriod]).trim();
    var code = String(row[iCode] || '').trim();
    if (!code || code === '合計') continue;
    wmap[wk].count++;
    rows.push({week: wk, cells: idx.map(function (j) { return j >= 0 ? row[j] : ''; })});
  }
  return {rows: rows, weeks: weeks};
}
