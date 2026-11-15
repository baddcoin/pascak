function getLatestMs() begin
  var resp = http.get("https://data-api.binance.vision/api/v3/klines?symbol=BTCUSDT&interval=1m&limit=1");
  if resp == null then return 0;
  var data = jsonParse(resp.body);
  if data == null then return 0;
  if len(data) == 0 then return 0;
  return toFloat(data[0][0]);
end;

function fetchBatch(startMs, endMs, limit) begin
  var url = "https://data-api.binance.vision/api/v3/klines?symbol=BTCUSDT&interval=1m&startTime=" + str(startMs) + "&endTime=" + str(endMs) + "&limit=" + str(limit);
  var resp = http.get(url);
  if resp == null then return null;
  return jsonParse(resp.body);
end;

function addBatch(series, batch) begin
  if batch == null then return 0;
  var i = 0;
  var added = 0;
  while i < len(batch) do begin
    cryptoAdd(series, toFloat(batch[i][0]), toFloat(batch[i][1]), toFloat(batch[i][2]), toFloat(batch[i][3]), toFloat(batch[i][4]), toFloat(batch[i][5]));
    i = i + 1;
    added = added + 1;
  end;
  return added;
end;

function warmup(series, target) begin
  var latestMs = getLatestMs();
  if latestMs == 0 then return 0;
  var startMs = latestMs - (target + 2) * 60 * 1000;
  var added = 0;
  var batchStart = startMs;
  var iter = 0;
  while added < target and iter < 25 do begin
    var batchEnd = batchStart + 15 * 60 * 1000 - 1;
    var batch = fetchBatch(batchStart, batchEnd, 15);
    if batch == null then break;
    if len(batch) == 0 then break;
    added = added + addBatch(series, batch);
    batchStart = batchEnd + 1;
    iter = iter + 1;
    sleep(50);
  end;
  return added;
end;

function fetchChart() begin
  var resp = http.get("https://data-api.binance.vision/api/v3/klines?symbol=BTCUSDT&interval=1m&limit=15");
  if resp == null then return null;
  return jsonParse(resp.body);
end;

function drawCandles(candles, x0, y0, w, h) begin
  var n = len(candles);
  if n == 0 then return;
  var minP = toFloat(candles[0][3]);
  var maxP = toFloat(candles[0][2]);
  var maxVol = toFloat(candles[0][5]);
  var i = 1;
  while i < n do begin
    var lo = toFloat(candles[i][3]);
    var hi = toFloat(candles[i][2]);
    var vol = toFloat(candles[i][5]);
    if lo < minP then minP = lo;
    if hi > maxP then maxP = hi;
    if vol > maxVol then maxVol = vol;
    i = i + 1;
  end;
  var pad = (maxP - minP) * 0.05;
  minP = minP - pad;
  maxP = maxP + pad;
  var range = maxP - minP;
  if range == 0 then range = 1;
  var volH = h * 0.18;
  var priceH = h - volH - 10;
  var hdr = "H: " + str(maxP) + "  L: " + str(minP);
  gui2.text(x0 + 5, y0 - 18, hdr, 100, 120, 140);
  var gi = 0;
  while gi <= 4 do begin
    var gp = minP + (range * gi / 4);
    var gy = y0 + priceH - (gp - minP) / range * priceH;
    gui2.line(x0, gy, x0 + w, gy, 40, 40, 55);
    gi = gi + 1;
  end;
  var cw = w / n;
  i = 0;
  while i < n do begin
    var op = toFloat(candles[i][1]);
    var hi = toFloat(candles[i][2]);
    var lo = toFloat(candles[i][3]);
    var cl = toFloat(candles[i][4]);
    var vol = toFloat(candles[i][5]);
    var yH = y0 + priceH - (hi - minP) / range * priceH;
    var yL = y0 + priceH - (lo - minP) / range * priceH;
    var yO = y0 + priceH - (op - minP) / range * priceH;
    var yC = y0 + priceH - (cl - minP) / range * priceH;
    var cx = x0 + i * cw + cw / 2;
    gui2.line(cx, yH, cx, yL, 140, 140, 140);
    var bTop = yO;
    var bBot = yC;
    if bTop > bBot then begin
      var tmp = bTop;
      bTop = bBot;
      bBot = tmp;
    end;
    var bH = bBot - bTop;
    if bH < 1 then bH = 1;
    if cl >= op then
      gui2.rect(cx - cw / 2 + 1, bTop, cw - 2, bH, 0, 200, 100)
    else
      gui2.rect(cx - cw / 2 + 1, bTop, cw - 2, bH, 220, 50, 50);
    if maxVol > 0 then begin
      var vH = vol / maxVol * volH;
      var vy = y0 + priceH + 10 + volH - vH;
      if cl >= op then
        gui2.rect(cx - cw / 2 + 1, vy, cw - 2, vH, 30, 90, 60)
      else
        gui2.rect(cx - cw / 2 + 1, vy, cw - 2, vH, 120, 40, 40);
    end;
    i = i + 1;
  end;
end;

function drawSignal(fc, x, y) begin
  var trend = fc["TrendRegime"];
  var bull = fc["BullScore"];
  var bear = fc["BearScore"];
  var squeeze = fc["IsSqueezeActive"];
  var predicted = fc["PredictedPrice"];
  var div = fc["DivergenceSignal"];
  var rec = "WAIT";
  var rc1 = 200;
  var rc2 = 200;
  var rc3 = 100;
  var diff = bull - bear;
  if diff > 15 then begin
    rec = "BUY";
    rc1 = 0;
    rc2 = 220;
    rc3 = 100;
  end else if diff < -15 then begin
    rec = "SELL";
    rc1 = 220;
    rc2 = 50;
    rc3 = 50;
  end else if squeeze then begin
    rec = "WAIT (SQUEEZE)";
    rc1 = 100;
    rc2 = 180;
    rc3 = 255;
  end;
  gui2.text(x, y, "=== SIGNAL ===", 220, 220, 100);
  gui2.text(x, y + 25, "Trend: " + trend, 220, 220, 220);
  gui2.text(x, y + 50, "Recommendation: " + rec, rc1, rc2, rc3);
  gui2.text(x, y + 75, "Bull: " + str(bull) + "  Bear: " + str(bear), 180, 180, 200);
  gui2.text(x, y + 100, "Predicted: " + str(predicted), 220, 200, 100);
  var subY = y + 125;
  if squeeze then begin
    gui2.text(x, subY, ">>> SQUEEZE (breakout imminent)", 100, 180, 255);
    subY = subY + 25;
  end;
  if div == 1 then begin
    gui2.text(x, subY, ">>> Bullish Divergence", 100, 220, 100);
    subY = subY + 25;
  end else if div == -1 then begin
    gui2.text(x, subY, ">>> Bearish Divergence", 220, 100, 100);
    subY = subY + 25;
  end;
  var barY = y + 180;
  gui2.rect(x, barY, 300, 15, 60, 60, 60);
  var bp = bull;
  if bp > 100 then bp = 100;
  if bp < 0 then bp = 0;
  gui2.rect(x, barY, 300 * bp / 100, 15, 0, 200, 100);
  gui2.text(x + 310, barY, "Bull " + str(bp), 100, 220, 100);
  gui2.rect(x, barY + 22, 300, 15, 60, 60, 60);
  var bep = bear;
  if bep > 100 then bep = 100;
  if bep < 0 then bep = 0;
  gui2.rect(x, barY + 22, 300 * bep / 100, 15, 220, 50, 50);
  gui2.text(x + 310, barY + 22, "Bear " + str(bep), 220, 100, 100);
end;

begin
  gui2.init();
  gui2.setFont("/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf", 14);
  gui2.window("BTC Trading - Stable", 1000, 750);
  println("=== Batched warmup (100 candles via 14x fetch) ===");
  var series = cryptoCreate(300);
  var total = warmup(series, 250);
  println("Warmed: " + str(total) + " candles");
  var chart = fetchChart();
  var lastMs = 0;
  if chart != null then
    if len(chart) > 0 then
      lastMs = toFloat(chart[len(chart) - 1][0]);
  println("Chart loaded: " + str(len(chart)) + " candles");
  var frame = 0;
  var lastRefresh = 0;
  var ev = "";
  while ev <> "quit" do begin
    ev = gui2.poll();
    if (frame - lastRefresh) >= 180 then begin
      var newChart = fetchChart();
      if newChart != null then begin
        var j = 0;
        while j < len(newChart) do begin
          var ts = toFloat(newChart[j][0]);
          if ts > lastMs then begin
            cryptoAdd(series, ts, toFloat(newChart[j][1]), toFloat(newChart[j][2]), toFloat(newChart[j][3]), toFloat(newChart[j][4]), toFloat(newChart[j][5]));
            lastMs = ts;
          end;
          j = j + 1;
        end;
        chart = newChart;
      end;
      lastRefresh = frame;
    end;
    gui2.clear(15, 15, 25);
    if chart != null then
      if len(chart) > 0 then begin
        drawCandles(chart, 20, 60, 960, 400);
        var p = toFloat(chart[len(chart) - 1][4]);
        var op = toFloat(chart[len(chart) - 1][1]);
        if p >= op then
          gui2.text(20, 15, "BTC/USDT 1m  " + str(p) + " USDT", 0, 220, 100)
        else
          gui2.text(20, 15, "BTC/USDT 1m  " + str(p) + " USDT", 220, 50, 50);
      end;
    var fc = getForecast(series);
    if fc != null then
      drawSignal(fc, 20, 490);
    gui2.text(20, 720, "100 candles | SMA20/50 | batched fetch | ESC to quit", 130, 130, 130);
    gui2.present();
    frame = frame + 1;
  end;
  cryptoFree(series);
  println("Session closed.");
end.
