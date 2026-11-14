# 📋 Handover — v1.14.4 (2026-11-15)

Supersedes: `SESSION_HANDOVER_2026-11-14_v2.md` (v1.13.3)
Main HEAD: d25f686 (v1.14.4)
Tags: 130+ total
Engine: 54,917 lines
Tests: 17/17 PASS
Tree: clean

## Delta Since v1.13.3 (7 releases, 1 day)

| Version | Focus | Diff |
|---|---|---|
| v1.13.4 | BTC chart example (15 candle) | +181 |
| **v1.14.1** | **Crypto native merge (40+ indicators)** | **+575** |
| v1.14.2 | Trading chart + signal panel | +245 |
| **v1.14.3** | **HTTP gzip fix (CRITICAL SDK bug)** | **+14** |
| v1.14.4 | 100 candle chart + SMA overlay | +288 |

## Achievement Arc

**From "hello world" to trading platform:**

1. **v1.12.x** — GUI widget toolkit (13 widgets, horizontal support)
2. **v1.13.x** — Real-world examples (BTC chart from Binance)
3. **v1.14.x** — Native crypto engine + trading chart

**Key milestone:** `examples/btc_trading.pas` (288 lines) = TradingView-quality
trading chart dengan 100 candle + SMA20/50 overlay + signal panel, powered
by native crypto engine (40+ indicators). Bandingkan dengan Python
`crypto_main.py` (2400+ lines, Kivy + sklearn + websockets + feedparser).

## Crypto Native Engine (v1.14.1)

Merged `trading.pas` (~1500 lines) into `pascak_engine.pas` via 15 chunks.
Section marked `{ === v1.14.1 CRYPTO NATIVE SECTION === }` at line ~46737.

**Types merged:**
- `TPriceCandle` (Timestamp, OHLCV, TypicalPrice)
- `TMarketForecast` (TrendRegime, PredictedPrice, Bull/Bear score, Squeeze, Divergence)
- `TCryptoIndicators` (40+ fields)
- `TTradeSignal`, `TTradeState`, `TOnCandleProcess`

**Classes merged:**
- `TCryptoDataSeries` — ring buffer 2000 + indicator cache O(1)
  * AddCandle: 5 EMAs, MACD, VWAP, OBV, RSI Wilder, ATR 10+14, ADX/DMI,
    Supertrend, PSAR, Stoch, Swing fractal
  * ComputeAllIndicators: SMA20/50/200, VolumeMA20, EMAs, MACD, RSI, Stoch,
    CCI, Momentum, MFI, Bollinger, Keltner, VWAP, OBV, Pivot (P/R1/S1/R2/S2),
    Fibonacci (236/382/500/618), Swing Hi/Lo, ADX+DI, Supertrend, PSAR,
    Linear Regression (slope + forecast + StdError)
  * Forecast: 7-factor Bull/Bear scoring, squeeze, divergence
- `TMTFEngine` — multi-timeframe (base + higher TF)
- `TCSVBacktestEngine` — CSV parser + streaming backtest
- `TPortfolioManager` — paper trading (SL/TP, trailing SAR, drawdown)

**4 natives registered:**
- `cryptoCreate(capacity=2000) -> ptr`
- `cryptoAdd(series, ts, o, h, l, c, v) -> bool`
- `getForecast(series) -> dict`
- `cryptoFree(series) -> bool`

**Smoke + stress test passed:**
- 200 synthetic candles → trend=Bullish Phase, bull=71.4, bear=14.3 (5/7 factors)
- Chart render live BTC → Trend detection accurate, Bull/Bear score correct

## HTTP Gzip Fix (v1.14.3) — CRITICAL SDK BUG

**Root cause of "3.3KB body limit":** gzip compression.

**Diagnostic:**
- `Accept-Encoding: gzip` (default) → 3372 bytes compressed → jsonParse FAIL
- `Accept-Encoding: identity` → 10301 bytes raw → jsonParse OK

**Fix (2 parts):**
1. Add `Accept-Encoding: identity` header → server returns uncompressed
2. Retry loop on spurious 0 read (TLS record boundary + latency)

**Result:**
- limit=15 → body=2552, count=15 (regression OK)
- limit=60 → body=10299, count=60 (was 3363 truncated)
- limit=200 → body=34093, count=200 (was 3364 truncated)

**Impact:** 10x larger responses for any JSON API. Massive unlock.

**Fix location:** `pascak_engine.pas` ~line 29478 (Native_HTTP_Request loop)

## Chart Examples

**`examples/btc_chart.pas` (v1.13.4):**
- 15 candle chart from Binance Vision
- Original working example (gzip-limited era)

**`examples/btc_trading.pas` (v1.14.4):**
- 100 candle chart (v1.14.3 gzip fix)
- SMA20 (yellow) + SMA50 (blue) overlay
- Volume bars, grid lines, H/L header
- Signal panel: trend, recommendation (BUY/SELL/WAIT), bull/bear bars
- Auto-refresh every 3s
- 288 lines (vs Python crypto_main.py 2400+ lines)

**Known limits:**
- No WebSocket (3s poll)
- No ML (sklearn unavailable)
- No news sentiment (RSS native needed)
- No order book analysis (WS depth needed)

## Session Findings (Update Real Syntax)

**Discovered during crypto merge + chart work:**

1. **`:=` IS supported** in Pascak scripts (handover lama salah — hanya bilang `=`)
2. **Comments: `//` only** — `{ }` block comment = parse error
3. **`toFloat()` exists** — `int()`, `double()` do NOT (reserved names)
4. **`gui2.present()` REQUIRED** — tanpa ini render tidak flip ke screen
5. **HTTP DNS hijack** di Indonesia (`internetpositif.id` for `api.binance.com`)
   → pakai `data-api.binance.vision` (Binance public mirror)
6. **`PASCAK_TLS_NO_VERIFY=1`** needed on Termux (CA chain issue)

## Next Session Options

**A. Publish v1.15.0 milestone** (rekomendasi)
- GitHub Release v1.14.4 (attach binary + screenshot)
- Blog post: "From scripting language to trading platform in 288 lines"
- HN post (week 2): "Show HN: Trading chart in 3MB binary (no Python)"
- Target audience: crypto traders, algo devs, quant hobbyists

**B. Add Bollinger Bands + RSI subpanel** (1-2 sesi)
- BB overlay (upper/lower/mid)
- RSI subpanel bawah chart
- MACD subpanel

**C. WebSocket real-time** (2-3 sesi)
- Native WS integration di Poll
- Live tick vs 3s poll

**D. Paper trading natives** (1-2 sesi)
- Expose `TPortfolioManager` ke script
- Simulate positions + PnL tracking

**E. News sentiment** (1-2 sesi)
- Native RSS parser
- Keyword scoring (port dari Python analyze_news_impact)

