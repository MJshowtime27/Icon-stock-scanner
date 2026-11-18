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
        if not results_df.empty:
        # Clean, readable table with styled green/red percentage changes
        display_df = results_df[["Ticker", "Name", "Price", "Change", "RelVol", "FloatM"]].copy()
        display_df.columns = ["Ticker", "Company", "Price ($)", "Day Gain (%)", "Rel Volume (x)", "Float (M)"]

        # Function to color green for positive, red for negative
        def color_gain_loss(val):
            color = "#00C805" if val > 0 else "#FF5000" if val < 0 else "inherit"
            return f"color: {color}; font-weight: 600;"

        styled_df = display_df.style.map(color_gain_loss, subset=["Day Gain (%)"])
        
        st.dataframe(styled_df, use_container_width=True, hide_index=True)

    if results:
        results_df = pd.DataFrame(results).sort_values(by="Rel Volume (x)", ascending=False)
        st.success(f"Found {len(results_df)} setups matching your 5 Pillars!")
        st.dataframe(results_df, use_container_width=True, hide_index=True)
    else:
        st.info("No tickers currently meet all 5 strict criteria. Markets may be quiet or scanning outside active hours.")
import streamlit as st
import yfinance as yf
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from streamlit_autorefresh import st_autorefresh
import google.generativeai as genai

# --- PAGE SETUP ---
st.set_page_config(
    page_title="5 Pillars Scanner",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Hide default Streamlit developer footer/menu for a true app feel
st.markdown("""
    <style>
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    .block-container {padding-top: 1.5rem; padding-bottom: 2rem;}
    div[data-testid="stMetric"] {
        background-color: #151A24;
        border: 1px solid #252D3D;
        padding: 14px 18px;
        border-radius: 10px;
    }
    </style>
""", unsafe_allow_html=True)

# Auto-refresh every 30 minutes (1,800,000 ms)
st_autorefresh(interval=30 * 60 * 1000, key="scanner_refresh")

# ==========================================
# --- LOCKED 5 PILLARS CONFIGURATION ---
# ==========================================
WATCHLIST = [
    "AMC", "GME", "PLTR", "SOFI", "NIO", "RIOT", "MARA", "PLUG", 
    "SAVA", "VERU", "SPCE", "MULN", "BITF", "HIVE", "CLSK", "BTBT",
    "IONQ", "LAZR", "OPEN", "LUMN", "IRNT", "PROG", "BBIG", "CEI"
]
MIN_DAILY_CHANGE_PCT = 10.0   # Pillar 1 Updated: Up at least 10% on the day
MIN_REL_VOLUME = 3.0          # Pillar 2: 3x+ relative volume
MIN_PRICE = 2.00              # Pillar 4: Price between $2 and $20
MAX_PRICE = 20.00             # Pillar 4: Price between $2 and $20
MAX_FLOAT_SHARES = 20_000_000 # Pillar 5: Under 20M shares float
# ==========================================

# --- APP HEADER ---
col_title, col_badge = st.columns([4, 1])
with col_title:
    st.markdown("## 🎯 5 Pillars Momentum Scanner")
    st.caption("High-momentum low-float setups • Auto-updates every 30 minutes")
with col_badge:
    st.markdown("<div style='text-align:right; padding-top:12px;'><span style='background:#132A1C; color:#00C805; padding:6px 12px; border-radius:20px; font-size:0.85rem; font-weight:600;'>● LIVE SYNC</span></div>", unsafe_allow_html=True)

# --- TOP NAVIGATION TABS ---
tab_scanner, tab_ai, tab_rules = st.tabs(["📊 Live Scanner", "🤖 AI Trading Coach", "📋 Our 5 Pillars"])

# --- CACHED DATA FETCHER (30 Min Cache) ---
@st.cache_data(ttl=1800)
def fetch_stock_data(ticker):
    try:
        stock = yf.Ticker(ticker)
        df = stock.history(period="3mo", interval="1d")
        info = stock.info
        return df, info
    except Exception:
        return None, None

def run_scanner():
    results = []
    for ticker in WATCHLIST:
        df, info = fetch_stock_data(ticker)
        if df is not None and not df.empty and len(df) >= 20:
            try:
                df["AvgVol20"] = df["Volume"].rolling(20).mean()
                latest = df.iloc[-1]
                prev = df.iloc[-2]
                
                close = float(latest["Close"])
                prev_close = float(prev["Close"])
                pct_change = ((close - prev_close) / prev_close) * 100
                
                avg_vol = float(latest["AvgVol20"])
                vol = float(latest["Volume"])
                rel_vol = vol / avg_vol if avg_vol > 0 else 0
                float_shares = info.get("floatShares", info.get("sharesOutstanding", 0))

                if (
                    MIN_PRICE <= close <= MAX_PRICE
                    and pct_change >= MIN_DAILY_CHANGE_PCT
                    and rel_vol >= MIN_REL_VOLUME
                    and (0 < float_shares <= MAX_FLOAT_SHARES)
                ):
                    results.append({
                        "Ticker": ticker,
                        "Name": info.get("shortName", ticker),
                        "Price": round(close, 2),
                        "Change": round(pct_change, 2),
                        "RelVol": round(rel_vol, 2),
                        "FloatM": round(float_shares / 1_000_000, 2),
                        "Volume": int(vol)
                    })
            except Exception:
                pass
    return pd.DataFrame(results).sort_values(by="RelVol", ascending=False) if results else pd.DataFrame()

if "scan_results" not in st.session_state:
    st.session_state.scan_results = run_scanner()

# ==========================================
# TAB 1: CLEAN APP SCANNER & INSPECTOR
# ==========================================
with tab_scanner:
    results_df = st.session_state.scan_results

    # Top Summary Cards
    m1, m2, m3 = st.columns(3)
    m1.metric("Stocks Scanned", f"{len(WATCHLIST)} Tickers")
    m2.metric("Active Setups Found", f"{len(results_df)} Matches")
    top_mover = f"{results_df.iloc[0]['Ticker']} (+{results_df.iloc[0]['Change']}%)" if not results_df.empty else "Waiting for Volume"
    m3.metric("Top Mover Today", top_mover)

    st.markdown("---")

    if not results_df.empty:
        # Clean, readable table with green/red styling
        display_df = results_df[["Ticker", "Name", "Price", "Change", "RelVol", "FloatM"]].copy()
        display_df.columns = ["Ticker", "Company", "Price ($)", "Day Gain (%)", "Rel Volume (x)", "Float (M)"]

        def color_gain_loss(val):
            color = "#00C805" if val > 0 else "#FF5000" if val < 0 else "inherit"
            return f"color: {color}; font-weight: 600;"

        styled_df = display_df.style.map(color_gain_loss, subset=["Day Gain (%)"])
        st.dataframe(styled_df, use_container_width=True, hide_index=True)

        st.markdown("### 🔍 Inspect Setup")
        selected_ticker = st.segmented_control(
            "Tap a stock to load its chart, profile, and news:",
            options=results_df["Ticker"].tolist(),
            default=results_df["Ticker"].tolist()[0]
        )

        if selected_ticker:
            ticker_obj = yf.Ticker(selected_ticker)
            info = ticker_obj.info
            
            with st.container(border=True):
                c_head, c_tf = st.columns([2, 2])
                with c_head:
                    st.markdown(f"#### {info.get('shortName', selected_ticker)} (`{selected_ticker}`)")
                    st.caption(f"🌍 **{info.get('country', 'N/A')}** • 🏭 **{info.get('sector', 'N/A')}** ({info.get('industry', 'N/A')})")
                with c_tf:
                    timeframe = st.segmented_control(
                        "Timeframe",
                        ["Today (5m)", "1 Month", "3 Months"],
                        default="Today (5m)",
                        label_visibility="collapsed"
                    )

                if timeframe == "Today (5m)":
                    hist = ticker_obj.history(period="1d", interval="5m")
                elif timeframe == "1 Month":
                    hist = ticker_obj.history(period="1mo", interval="1d")
                else:
                    hist = ticker_obj.history(period="3mo", interval="1d")

                if not hist.empty:
                    fig = make_subplots(
                        rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.04, row_heights=[0.72, 0.28]
                    )
                    fig.add_trace(
                        go.Candlestick(
                            x=hist.index, open=hist["Open"], high=hist["High"],
                            low=hist["Low"], close=hist["Close"],
                            increasing_line_color="#00C805", decreasing_line_color="#FF5000",
                            name="Price"
                        ), row=1, col=1
                    )
                    fig.add_trace(
                        go.Bar(x=hist.index, y=hist["Volume"], marker_color="#3B82F6", opacity=0.6, name="Volume"),
                        row=2, col=1
                    )
                    fig.update_layout(
                        height=440,
                        template="plotly_dark",
                        paper_bgcolor="#151A24",
                        plot_bgcolor="#151A24",
                        xaxis_rangeslider_visible=False,
                        margin=dict(l=10, r=10, t=10, b=10),
                        showlegend=False
                    )
                    st.plotly_chart(fig, use_container_width=True)

                st.markdown("#### 📰 Latest Catalyst News")
                news_items = ticker_obj.news
                if news_items:
                    for article in news_items[:4]:
                        content = article.get("content", article)
                        title = content.get("title", "Market Update")
                        provider = content.get("provider", {}).get("displayName", content.get("publisher", "News"))
                        link = content.get("canonicalUrl", {}).get("url", content.get("link", "#"))
                        st.markdown(f"🔹 **[{title}]({link})** — *{provider}*")
                else:
                    st.caption("No recent headlines found for this ticker.")
    else:
        with st.container(border=True):
            st.markdown("#### ⏳ No Setups Matching All 5 Pillars Right Now")
            st.write("Our scanner only surfaces stocks hitting **+10% daily gains**, **3x+ relative volume**, **$2–$20 price**, and **<20M float**. The page automatically refreshes every 30 minutes.")

# ==========================================
# TAB 2: AI TRADING COACH
# ==========================================
with tab_ai:
    st.markdown("### 🤖 AI Trading Mentor")
    st.caption("Ask about chart patterns, risk-to-reward ratios, float rotation, or trading psychology.")

    api_key = None
    try:
        api_key = st.secrets["GEMINI_API_KEY"]
    except Exception:
        pass

    if not api_key:
        api_key = st.text_input("Enter Gemini API Key to unlock AI Chat:", type="password")

    if api_key:
        genai.configure(api_key=api_key)
        if "messages" not in st.session_state:
            st.session_state.messages = [
                {"role": "assistant", "content": "Welcome! Ask me anything about reading charts, managing risk, or spotting momentum setups."}
            ]

        for msg in st.session_state.messages:
            with st.chat_message(msg["role"]):
                st.markdown(msg["content"])

        if prompt := st.chat_input("Ask a question (e.g. 'Why does a low float make a stock move faster?')..."):
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)

            with st.chat_message("assistant"):
                with st.spinner("Analyzing..."):
                    try:
                        model = genai.GenerativeModel(
                            model_name="gemini-2.5-flash",
                            system_instruction="You are a sharp, supportive trading mentor. Explain stock market concepts, risk management (stop-losses, 1:2 risk-to-reward), and momentum trading clearly and concisely."
                        )
                        history = [
                            {"role": m["role"] if m["role"] == "user" else "model", "parts": [m["content"]]}
                            for m in st.session_state.messages[:-1]
                        ]
                        response = model.start_chat(history=history).send_message(prompt)
                        st.markdown(response.text)
                        st.session_state.messages.append({"role": "assistant", "content": response.text})
                    except Exception as e:
                        st.error(f"AI Error: {e}")

# ==========================================
# TAB 3: OUR 5 PILLARS EXPLAINED
# ==========================================
with tab_rules:
    st.markdown("### 📋 How Our Scanner Picks Stocks")
    st.write("Every stock on this dashboard must pass all 5 strict rules before appearing:")
    
    c1, c2 = st.columns(2)
    with c1:
        with st.container(border=True):
            st.markdown("#### 1. Massive Daily Momentum (+10%)")
            st.write("The stock must be up at least **10% today**, proving strong institutional or retail buying pressure.")
        with st.container(border=True):
            st.markdown("#### 2. High Relative Volume (3x+)")
            st.write("Volume must be at least **3 times higher** than normal so we have the liquidity to trade efficiently.")
        with st.container(border=True):
            st.markdown("#### 3. News Catalyst")
            st.write("Every match includes a live news feed to verify the fundamental catalyst driving volume.")
    with c2:
        with st.container(border=True):
            st.markdown("#### 4. Sweet-Spot Price ($2 – $20)")
            st.write("Focused on stocks priced between **$2 and $20** for explosive percentage potential.")
        with st.container(border=True):
            st.markdown("#### 5. Low Supply (< 20M Float)")
            st.write("Restricted to companies with **under 20 million shares** available to trade—maximizing upward price velocity.")
if not results_df.empty:
        # Clean, readable table with styled green/red percentage changes
        display_df = results_df[["Ticker", "Name", "Price", "Change", "RelVol", "FloatM"]].copy()
        display_df.columns = ["Ticker", "Company", "Price ($)", "Day Gain (%)", "Rel Volume (x)", "Float (M)"]

        # Function to color green for positive, red for negative
        def color_gain_loss(val):
            color = "#00C805" if val > 0 else "#FF5000" if val < 0 else "inherit"
            return f"color: {color}; font-weight: 600;"

        styled_df = display_df.style.map(color_gain_loss, subset=["Day Gain (%)"])
        
        st.dataframe(styled_df, use_container_width=True, hide_index=True)
import streamlit as st
import yfinance as yf
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from streamlit_autorefresh import st_autorefresh
import google.generativeai as genai
import os
from datetime import datetime

# --- PAGE SETUP ---
st.set_page_config(
    page_title="5 Pillars Trading Hub",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Hide default Streamlit developer footer/menu for a true website/app feel
st.markdown("""
    <style>
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    .block-container {padding-top: 1.5rem; padding-bottom: 2rem;}
    div[data-testid="stMetric"] {
        background-color: #151A24;
        border: 1px solid #252D3D;
        padding: 14px 18px;
        border-radius: 10px;
    }
    </style>
""", unsafe_allow_html=True)

# Auto-refresh every 30 minutes (1,800,000 ms)
st_autorefresh(interval=30 * 60 * 1000, key="scanner_refresh")

# ==========================================
# --- LOCKED 5 PILLARS CONFIGURATION ---
# ==========================================
WATCHLIST = [
    "AMC", "GME", "PLTR", "SOFI", "NIO", "RIOT", "MARA", "PLUG", 
    "SAVA", "VERU", "SPCE", "MULN", "BITF", "HIVE", "CLSK", "BTBT",
    "IONQ", "LAZR", "OPEN", "LUMN", "IRNT", "PROG", "BBIG", "CEI"
]
MIN_DAILY_CHANGE_PCT = 10.0   # Pillar 1: Up at least 10% on the day
MIN_REL_VOLUME = 3.0          # Pillar 2: 3x+ relative volume
MIN_PRICE = 2.00              # Pillar 4: Price between $2 and $20
MAX_PRICE = 20.00             # Pillar 4: Price between $2 and $20
MAX_FLOAT_SHARES = 20_000_000 # Pillar 5: Under 20M shares float
LEADERBOARD_FILE = "trade_logs.csv"
# ==========================================

# --- APP HEADER ---
col_title, col_badge = st.columns([4, 1])
with col_title:
    st.markdown("## 🎯 5 Pillars Trading Hub")
    st.caption("Live Low-Float Scanner • Team Profit Leaderboard • AI Trading Coach")
with col_badge:
    st.markdown("<div style='text-align:right; padding-top:12px;'><span style='background:#132A1C; color:#00C805; padding:6px 12px; border-radius:20px; font-size:0.85rem; font-weight:600;'>● LIVE SYNC</span></div>", unsafe_allow_html=True)

# --- TOP NAVIGATION TABS ---
tab_scanner, tab_leaderboard, tab_ai, tab_rules = st.tabs([
    "📊 Live Scanner", 
    "🏆 Profit Leaderboard", 
    "🤖 AI Trading Coach", 
    "📋 Our 5 Pillars"
])

# --- HELPER: LOAD & SAVE LEADERBOARD ---
def load_trades():
    if os.path.exists(LEADERBOARD_FILE):
        return pd.read_csv(LEADERBOARD_FILE)
    return pd.DataFrame(columns=["Date", "Trader", "Ticker", "Profit_Loss", "Notes"])

def save_trade(trader, ticker, pnl, notes):
    df = load_trades()
    new_row = pd.DataFrame([{
        "Date": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "Trader": trader.strip().title(),
        "Ticker": ticker.strip().upper(),
        "Profit_Loss": float(pnl),
        "Notes": notes.strip()
    }])
    df = pd.concat([df, new_row], ignore_index=True)
    df.to_csv(LEADERBOARD_FILE, index=False)

# --- CACHED DATA FETCHER (30 Min Cache) ---
@st.cache_data(ttl=1800)
def fetch_stock_data(ticker):
    try:
        stock = yf.Ticker(ticker)
        df = stock.history(period="3mo", interval="1d")
        info = stock.info
        return df, info
    except Exception:
        return None, None

def run_scanner():
    results = []
    for ticker in WATCHLIST:
        df, info = fetch_stock_data(ticker)
        if df is not None and not df.empty and len(df) >= 20:
            try:
                df["AvgVol20"] = df["Volume"].rolling(20).mean()
                latest = df.iloc[-1]
                prev = df.iloc[-2]
                
                close = float(latest["Close"])
                prev_close = float(prev["Close"])
                pct_change = ((close - prev_close) / prev_close) * 100
                
                avg_vol = float(latest["AvgVol20"])
                vol = float(latest["Volume"])
                rel_vol = vol / avg_vol if avg_vol > 0 else 0
                float_shares = info.get("floatShares", info.get("sharesOutstanding", 0))

                if (
                    MIN_PRICE <= close <= MAX_PRICE
                    and pct_change >= MIN_DAILY_CHANGE_PCT
                    and rel_vol >= MIN_REL_VOLUME
                    and (0 < float_shares <= MAX_FLOAT_SHARES)
                ):
                    results.append({
                        "Ticker": ticker,
                        "Name": info.get("shortName", ticker),
                        "Price": round(close, 2),
                        "Change": round(pct_change, 2),
                        "RelVol": round(rel_vol, 2),
                        "FloatM": round(float_shares / 1_000_000, 2),
                        "Volume": int(vol)
                    })
            except Exception:
                pass
    return pd.DataFrame(results).sort_values(by="RelVol", ascending=False) if results else pd.DataFrame()

if "scan_results" not in st.session_state:
    st.session_state.scan_results = run_scanner()

# ==========================================
# TAB 1: LIVE SCANNER & INSPECTOR
# ==========================================
with tab_scanner:
    results_df = st.session_state.scan_results

    m1, m2, m3 = st.columns(3)
    m1.metric("Stocks Scanned", f"{len(WATCHLIST)} Tickers")
    m2.metric("Active Setups Found", f"{len(results_df)} Matches")
    top_mover = f"{results_df.iloc[0]['Ticker']} (+{results_df.iloc[0]['Change']}%)" if not results_df.empty else "Waiting for Volume"
    m3.metric("Top Mover Today", top_mover)

    st.markdown("---")

    if not results_df.empty:
        display_df = results_df[["Ticker", "Name", "Price", "Change", "RelVol", "FloatM"]].copy()
        display_df.columns = ["Ticker", "Company", "Price ($)", "Day Gain (%)", "Rel Volume (x)", "Float (M)"]

        def color_gain_loss(val):
            color = "#00C805" if val > 0 else "#FF5000" if val < 0 else "inherit"
            return f"color: {color}; font-weight: 600;"

        styled_df = display_df.style.map(color_gain_loss, subset=["Day Gain (%)"])
        st.dataframe(styled_df, use_container_width=True, hide_index=True)

        st.markdown("### 🔍 Inspect Setup")
        selected_ticker = st.segmented_control(
            "Tap a stock to load its chart, profile, and news:",
            options=results_df["Ticker"].tolist(),
            default=results_df["Ticker"].tolist()[0]
        )

        if selected_ticker:
            ticker_obj = yf.Ticker(selected_ticker)
            info = ticker_obj.info
            
            with st.container(border=True):
                c_head, c_tf = st.columns([2, 2])
                with c_head:
                    st.markdown(f"#### {info.get('shortName', selected_ticker)} (`{selected_ticker}`)")
                    st.caption(f"🌍 **{info.get('country', 'N/A')}** • 🏭 **{info.get('sector', 'N/A')}** ({info.get('industry', 'N/A')})")
                with c_tf:
                    timeframe = st.segmented_control(
                        "Timeframe",
                        ["Today (5m)", "1 Month", "3 Months"],
                        default="Today (5m)",
                        label_visibility="collapsed"
                    )

                if timeframe == "Today (5m)":
                    hist = ticker_obj.history(period="1d", interval="5m")
                elif timeframe == "1 Month":
                    hist = ticker_obj.history(period="1mo", interval="1d")
                else:
                    hist = ticker_obj.history(period="3mo", interval="1d")

                if not hist.empty:
                    fig = make_subplots(
                        rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.04, row_heights=[0.72, 0.28]
                    )
                    fig.add_trace(
                        go.Candlestick(
                            x=hist.index, open=hist["Open"], high=hist["High"],
                            low=hist["Low"], close=hist["Close"],
                            increasing_line_color="#00C805", decreasing_line_color="#FF5000",
                            name="Price"
                        ), row=1, col=1
                    )
                    fig.add_trace(
                        go.Bar(x=hist.index, y=hist["Volume"], marker_color="#3B82F6", opacity=0.6, name="Volume"),
                        row=2, col=1
                    )
                    fig.update_layout(
                        height=440,
                        template="plotly_dark",
                        paper_bgcolor="#151A24",
                        plot_bgcolor="#151A24",
                        xaxis_rangeslider_visible=False,
                        margin=dict(l=10, r=10, t=10, b=10),
                        showlegend=False
                    )
                    st.plotly_chart(fig, use_container_width=True)

                st.markdown("#### 📰 Latest Catalyst News")
                news_items = ticker_obj.news
                if news_items:
                    for article in news_items[:4]:
                        content = article.get("content", article)
                        title = content.get("title", "Market Update")
                        provider = content.get("provider", {}).get("displayName", content.get("publisher", "News"))
                        link = content.get("canonicalUrl", {}).get("url", content.get("link", "#"))
                        st.markdown(f"🔹 **[{title}]({link})** — *{provider}*")
                else:
                    st.caption("No recent headlines found for this ticker.")
    else:
        with st.container(border=True):
            st.markdown("#### ⏳ No Setups Matching All 5 Pillars Right Now")
            st.write("Our scanner only surfaces stocks hitting **+10% daily gains**, **3x+ relative volume**, **$2–$20 price**, and **<20M float**. The page automatically refreshes every 30 minutes.")

# ==========================================
# TAB 2: PROFIT TRACKER & LEADERBOARD
# ==========================================
with tab_leaderboard:
    st.markdown("### 🏆 Team Profit Tracker & Leaderboard")
    st.caption("Log your closed trades to track your progress and compete on the leaderboard.")

    col_form, col_board = st.columns([1, 2])

    # Left Column: Log a Trade Form
    with col_form:
        with st.container(border=True):
            st.markdown("#### ➕ Log Your Trade")
            with st.form("log_trade_form", clear_on_submit=True):
                trader_name = st.text_input("Your Name / Nickname", placeholder="e.g., MJ")
                trade_ticker = st.text_input("Stock Ticker", placeholder="e.g., PLTR")
                pnl_amount = st.number_input("How much did you make/lose? ($)", value=0.0, step=10.0, help="Use a negative sign (e.g., -50) for a loss.")
                trade_notes = st.text_input("Setup / Notes (Optional)", placeholder="e.g., Caught 10% breakout + 3x vol")
                
                submitted = st.form_submit_button("Submit to Leaderboard", type="primary", use_container_width=True)
                if submitted:
                    if trader_name and trade_ticker:
                        save_trade(trader_name, trade_ticker, pnl_amount, trade_notes)
                        st.success(f"Logged {'+' if pnl_amount >= 0 else ''}${pnl_amount:,.2f} for {trader_name.title()}!")
                        st.rerun()
                    else:
                        st.error("Please enter both your name and the stock ticker.")

    # Right Column: Live Leaderboard Rankings & History
    with col_board:
        trades_df = load_trades()
        
        if not trades_df.empty:
            # Group by Trader for Leaderboard Standings
            leaderboard = trades_df.groupby("Trader").agg(
                Total_Profit=("Profit_Loss", "sum"),
                Trades_Count=("Profit_Loss", "count"),
                Wins=("Profit_Loss", lambda x: (x > 0).sum())
            ).reset_index()
            
            leaderboard["Win_Rate (%)"] = ((leaderboard["Wins"] / leaderboard["Trades_Count"]) * 100).round(1)
            leaderboard = leaderboard.sort_values(by="Total_Profit", ascending=False).reset_index(drop=True)
            leaderboard.index += 1 # Rank starts at 1

            # Top 3 Podium Cards
            st.markdown("#### 🥇 Top Traders Podium")
            p1, p2, p3 = st.columns(3)
            medals = ["🥇 1st Place", "🥈 2nd Place", "🥉 3rd Place"]
            cols = [p1, p2, p3]
            
            for idx in range(min(3, len(leaderboard))):
                row = leaderboard.iloc[idx]
                profit_str = f"${row['Total_Profit']:,.2f}" if row['Total_Profit'] >= 0 else f"-${abs(row['Total_Profit']):,.2f}"
                cols[idx].metric(
                    label=f"{medals[idx]}: {row['Trader']}",
                    value=profit_str,
                    delta=f"{row['Win_Rate (%)']}% Win Rate ({row['Trades_Count']} trades)"
                )

            st.markdown("#### 📊 Full Standings")
            display_lb = leaderboard[["Trader", "Total_Profit", "Win_Rate (%)", "Trades_Count"]].copy()
            display_lb.columns = ["Trader", "Net Profit ($)", "Win Rate (%)", "Total Trades"]
            
            def color_pnl(val):
                color = "#00C805" if val > 0 else "#FF5000" if val < 0 else "inherit"
                return f"color: {color}; font-weight: 600;"

            st.dataframe(
                display_lb.style.map(color_pnl, subset=["Net Profit ($)"]).format({"Net Profit ($)": "${:,.2f}"}),
                use_container_width=True
            )

            with st.expander("📜 Recent Trade Feed (All Members)", expanded=False):
                recent_df = trades_df.sort_values(by="Date", ascending=False)
                st.dataframe(
                    recent_df.style.map(color_pnl, subset=["Profit_Loss"]).format({"Profit_Loss": "${:,.2f}"}),
                    use_container_width=True,
                    hide_index=True
                )
        else:
            with st.container(border=True):
                st.markdown("#### 🚀 No Trades Logged Yet!")
                st.write("Be the first to log a trade on the left to claim the **#1 spot** on the leaderboard.")

# ==========================================
# TAB 3: AI TRADING COACH
# ==========================================
with tab_ai:
    st.markdown("### 🤖 AI Trading Mentor")
    st.caption("Ask about chart patterns, risk-to-reward ratios, float rotation, or trading psychology.")

    api_key = None
    try:
        api_key = st.secrets["GEMINI_API_KEY"]
    except Exception:
        pass

    if not api_key:
        api_key = st.text_input("Enter Gemini API Key to unlock AI Chat:", type="password")

    if api_key:
        genai.configure(api_key=api_key)
        if "messages" not in st.session_state:
            st.session_state.messages = [
                {"role": "assistant", "content": "Welcome! Ask me anything about reading charts, managing risk, or spotting momentum setups."}
            ]

        for msg in st.session_state.messages:
            with st.chat_message(msg["role"]):
                st.markdown(msg["content"])

        if prompt := st.chat_input("Ask a question (e.g. 'Why does a low float make a stock move faster?')..."):
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)

            with st.chat_message("assistant"):
                with st.spinner("Analyzing..."):
                    try:
                        model = genai.GenerativeModel(
                            model_name="gemini-2.5-flash",
                            system_instruction="You are a sharp, supportive trading mentor. Explain stock market concepts, risk management (stop-losses, 1:2 risk-to-reward), and momentum trading clearly and concisely."
                        )
                        history = [
                            {"role": m["role"] if m["role"] == "user" else "model", "parts": [m["content"]]}
                            for m in st.session_state.messages[:-1]
                        ]
                        response = model.start_chat(history=history).send_message(prompt)
                        st.markdown(response.text)
                        st.session_state.messages.append({"role": "assistant", "content": response.text})
                    except Exception as e:
                        st.error(f"AI Error: {e}")

# ==========================================
# TAB 4: OUR 5 PILLARS EXPLAINED
# ==========================================
with tab_rules:
    st.markdown("### 📋 How Our Scanner Picks Stocks")
    st.write("Every stock on this dashboard must pass all 5 strict rules before appearing:")
    
    c1, c2 = st.columns(2)
    with c1:
        with st.container(border=True):
            st.markdown("#### 1. Massive Daily Momentum (+10%)")
            st.write("The stock must be up at least **10% today**, proving strong institutional or retail buying pressure.")
        with st.container(border=True):
            st.markdown("#### 2. High Relative Volume (3x+)")
            st.write("Volume must be at least **3 times higher** than normal so we have the liquidity to trade efficiently.")
        with st.container(border=True):
            st.markdown("#### 3. News Catalyst")
            st.write("Every match includes a live news feed to verify the fundamental catalyst driving volume.")
    with c2:
        with st.container(border=True):
            st.markdown("#### 4. Sweet-Spot Price ($2 – $20)")
            st.write("Focused on stocks priced between **$2 and $20** for explosive percentage potential.")
        with st.container(border=True):
            st.markdown("#### 5. Low Supply
