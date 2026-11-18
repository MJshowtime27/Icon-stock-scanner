import streamlit as st
import yfinance as yf
import pandas as pd

st.set_page_config(page_title="5 Pillars Stock Scanner", layout="wide")
st.title("🎯 5 Pillars Custom Stock Scanner")
st.caption("Locked to your 5 core rules for momentum, low float, and explosive setups.")

# ==========================================
# --- YOUR 5 PILLARS (Locked Rules) ---
# ==========================================
# Broad watchlist of small/mid-cap high-momentum and news-driven tickers
WATCHLIST = [
    "AMC", "GME", "PLTR", "SOFI", "NIO", "RIOT", "MARA", "PLUG", 
    "SAVA", "VERU", "SPCE", "MULN", "BITF", "HIVE", "CLSK", "BTBT",
    "IONQ", "LAZR", "OPEN", "LUMN", "IRNT", "PROG", "BBIG", "CEI"
]
MIN_DAILY_CHANGE_PCT = 5.0   # Pillar 1: Up at least 5% on the day
MIN_REL_VOLUME = 3.0         # Pillar 2: Relative volume at least 3x normal
MIN_PRICE = 2.00             # Pillar 4: Price between $2 and $20
MAX_PRICE = 20.00            # Pillar 4: Price between $2 and $20
MAX_FLOAT_SHARES = 20_000_000 # Pillar 5: Less than 20 million shares float
# ==========================================

with st.expander("View Your 5 Pillars Criteria", expanded=False):
    st.markdown(f"""
    1. **Momentum:** Daily change $\\ge$ `{MIN_DAILY_CHANGE_PCT}%`
    2. **Relative Volume:** $\\ge$ `{MIN_REL_VOLUME}x` average volume
    3. **Catalyst / News:** Filtered via volume/momentum surge (check news tab on matches)
    4. **Price Range:** Between `${MIN_PRICE:.2f}` and `${MAX_PRICE:.2f}`
    5. **Low Float:** Under `{MAX_FLOAT_SHARES:,}` available shares (Float)
    """)

if st.button("Run 5 Pillars Scan", type="primary"):
    results = []
    progress = st.progress(0)

    for i, ticker in enumerate(WATCHLIST):
        try:
            stock = yf.Ticker(ticker)
            df = stock.history(period="3mo", interval="1d")
            
            if len(df) >= 20:
                # Calculate metrics
                df["AvgVol20"] = df["Volume"].rolling(20).mean()
                
                latest = df.iloc[-1]
                prev = df.iloc[-2]
                
                close = float(latest["Close"])
                prev_close = float(prev["Close"])
                pct_change = ((close - prev_close) / prev_close) * 100
                
                avg_vol = float(latest["AvgVol20"])
                vol = float(latest["Volume"])
                rel_vol = vol / avg_vol if avg_vol > 0 else 0
                
                # Fetch Float data safely
                info = stock.info
                float_shares = info.get("floatShares", info.get("sharesOutstanding", 0))

                # Check all 5 pillars
                if (
                    MIN_PRICE <= close <= MAX_PRICE
                    and pct_change >= MIN_DAILY_CHANGE_PCT
                    and rel_vol >= MIN_REL_VOLUME
                    and (0 < float_shares <= MAX_FLOAT_SHARES)
                ):
                    results.append({
                        "Ticker": ticker,
                        "Price ($)": round(close, 2),
                        "Day Change (%)": round(pct_change, 2),
                        "Rel Volume (x)": round(rel_vol, 2),
                        "Float (M)": round(float_shares / 1_000_000, 2),
                        "Volume": int(vol)
                    })
        except Exception:
            pass
        progress.progress((i + 1) / len(WATCHLIST))

    if results:
        results_df = pd.DataFrame(results).sort_values(by="Rel Volume (x)", ascending=False)
        st.success(f"Found {len(results_df)} setups matching your 5 Pillars!")
        st.dataframe(results_df, use_container_width=True, hide_index=True)
    else:
        st.info("No tickers currently meet all 5 strict criteria. Markets may be quiet or scanning outside active hours.")
