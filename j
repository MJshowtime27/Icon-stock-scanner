import streamlit as st
import yfinance as yf
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from streamlit_autorefresh import st_autorefresh
import google.generativeai as genai

st.set_page_config(page_title="5 Pillars Trading Suite & AI Coach", layout="wide")

# --- AUTO-REFRESH CONFIGURATION (Every 30 Minutes) ---
st_autorefresh(interval=30 * 60 * 1000, key="market_scanner_refresh")

st.title("🎯 5 Pillars Stock Scanner & AI Trading Coach")
st.caption("🔒 Locked to your 5 rules • 🔄 Auto-updates every 30 mins • 🤖 Built-in AI Trading Assistant.")

# ==========================================
# --- YOUR 5 PILLARS (Locked Rules) ---
# ==========================================
WATCHLIST = [
    "AMC", "GME", "PLTR", "SOFI", "NIO", "RIOT", "MARA", "PLUG", 
    "SAVA", "VERU", "SPCE", "MULN", "BITF", "HIVE", "CLSK", "BTBT",
    "IONQ", "LAZR", "OPEN", "LUMN", "IRNT", "PROG", "BBIG", "CEI"
]
MIN_DAILY_CHANGE_PCT = 5.0    
MIN_REL_VOLUME = 3.0          
MIN_PRICE = 2.00              
MAX_PRICE = 20.00             
MAX_FLOAT_SHARES = 20_000_000 
# ==========================================

# --- APP LAYOUT TABS ---
tab_scanner, tab_ai_coach = st.tabs(["📈 Live 5 Pillars Scanner", "🤖 AI Trading Coach & Knowledge Q&A"])

# ==========================================
# TAB 1: SCANNER & INSPECTOR
# ==========================================
with tab_scanner:
    with st.expander("View Your 5 Pillars Criteria", expanded=False):
        st.markdown(f"""
        * **Auto-Refresh:** Active (Refreshes data & runs scan every 30 minutes)
        * **Momentum:** Daily change $\\ge$ `{MIN_DAILY_CHANGE_PCT}%`
        * **Relative Volume:** $\\ge$ `{MIN_REL_VOLUME}x` average volume
        * **Price Range:** Between `${MIN_PRICE:.2f}` and `${MAX_PRICE:.2f}`
        * **Low Float:** Under `{MAX_FLOAT_SHARES:,}` available shares
        """)

    @st.cache_data(ttl=1800)
    def fetch_stock_data(ticker):
        try:
            stock = yf.Ticker(ticker)
            df = stock.history(period="3mo", interval="1d")
            info = stock.info
            return df, info
        except Exception:
            return None, None

    if "scan_results" not in st.session_state:
        st.session_state.scan_results = None

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
                            "Price ($)": round(close, 2),
                            "Day Change (%)": round(pct_change, 2),
                            "Rel Volume (x)": round(rel_vol, 2),
                            "Float (M)": round(float_shares / 1_000_000, 2),
                            "Volume": int(vol)
                        })
                except Exception:
                    pass
                    
        if results:
            st.session_state.scan_results = pd.DataFrame(results).sort_values(
                by="Rel Volume (x)", ascending=False
            )
        else:
            st.session_state.scan_results = pd.DataFrame()

    run_scanner()

    if st.session_state.scan_results is not None:
        results_df = st.session_state.scan_results
        
        if not results_df.empty:
            st.success(f"Found {len(results_df)} setups matching your 5 Pillars!")
            st.dataframe(results_df, use_container_width=True, hide_index=True)

            st.divider()
            st.subheader("🔍 Stock Inspector (Chart, Country, Industry & News)")
            
            selected_ticker = st.selectbox(
                "Select a matched stock to inspect:",
                options=results_df["Ticker"].tolist()
            )

            if selected_ticker:
                with st.spinner(f"Loading data for {selected_ticker}..."):
                    ticker_obj = yf.Ticker(selected_ticker)
                    info = ticker_obj.info
                    
                    company_name = info.get("shortName", selected_ticker)
                    country = info.get("country", "Unknown")
                    sector = info.get("sector", "Unknown")
                    industry = info.get("industry", "Unknown")

                    st.markdown(f"### {company_name} ({selected_ticker})")
                    col1, col2, col3 = st.columns(3)
                    col1.metric("Country", country)
                    col2.metric("Sector", sector)
                    col3.metric("Industry", industry)

                    chart_timeframe = st.radio(
                        "Chart Timeframe",
                        ["Intraday (5m - Today)", "1 Month (Daily)", "3 Months (Daily)"],
                        horizontal=True
                    )
                    
                    if chart_timeframe == "Intraday (5m - Today)":
                        hist = ticker_obj.history(period="1d", interval="5m")
                    elif chart_timeframe == "1 Month (Daily)":
                        hist = ticker_obj.history(period="1mo", interval="1d")
                    else:
                        hist = ticker_obj.history(period="3mo", interval="1d")

                    if not hist.empty:
                        fig = make_subplots(
                            rows=2, cols=1, shared_xaxes=True,
                            vertical_spacing=0.05, row_heights=[0.7, 0.3]
                        )
                        fig.add_trace(
                            go.Candlestick(
                                x=hist.index,
                                open=hist["Open"], high=hist["High"],
                                low=hist["Low"], close=hist["Close"],
                                name="Price"
                            ),
                            row=1, col=1
                        )
                        fig.add_trace(
                            go.Bar(x=hist.index, y=hist["Volume"], name="Volume", marker_color="rgba(100, 149, 237, 0.6)"),
                            row=2, col=1
                        )
                        fig.update_layout(
                            height=500,
                            xaxis_rangeslider_visible=False,
                            margin=dict(l=10, r=10, t=30, b=10),
                            showlegend=False
                        )
                        st.plotly_chart(fig, use_container_width=True)

                    st.markdown("#### 📰 Latest News & Catalysts")
                    news_items = ticker_obj.news
                    if news_items:
                        for article in news_items[:6]:
                            content = article.get("content", article)
                            title = content.get("title", "No Title")
                            provider = content.get("provider", {}).get("displayName", content.get("publisher", "News"))
                            link = content.get("canonicalUrl", {}).get("url", content.get("link", "#"))
                            
                            st.markdown(f"- **[{title}]({link})** — *{provider}*")
                    else:
                        st.write("No recent news headlines returned for this ticker.")
        else:
            st.info("No tickers currently meet all 5 strict criteria right now. The scanner will automatically check again in 30 minutes.")

# ==========================================
# TAB 2: AI TRADING COACH & KNOWLEDGE Q&A
# ==========================================
with tab_ai_coach:
    st.subheader("🤖 AI Trading Coach & Knowledge Assistant")
    st.markdown("Ask any question about trading strategies, risk management, candlestick patterns, or market mechanics. Powered by Gemini.")

    # Configure API Key (Safely checks Streamlit Secrets first, then sidebar input)
    api_key = None
    try:
        api_key = st.secrets["GEMINI_API_KEY"]
    except Exception:
        pass

    if not api_key:
        api_key = st.sidebar.text_input("Enter Gemini API Key for AI Chat", type="password")

    if api_key:
        genai.configure(api_key=api_key)
        
        # Initialize chat history
        if "messages" not in st.session_state:
            st.session_state.messages = [
                {
                    "role": "assistant",
                    "content": "Hey! I'm your AI Trading Coach. Ask me anything about reading charts, risk management, liquidity, or executing your 5 Pillars strategy."
                }
            ]

        # Display chat messages
        for message in st.session_state.messages:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])

        # Accept user input
        if prompt := st.chat_input("Ask a trading question (e.g., 'How do I calculate risk-to-reward?')..."):
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)

            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    try:
                        # Use Gemini model for trading education & coaching
                        model = genai.GenerativeModel(
                            model_name="gemini-1.5-flash",
                            system_instruction="You are an expert trading coach and mentor. Help users understand technical analysis, stock market mechanics, risk management (like stop-losses and 1:2 risk-to-reward ratios), and trading psychology. Keep answers concise, actionable, and educational."
                        )
                        # Format history for Gemini chat
                        chat_history = [
                            {"role": m["role"] if m["role"] == "user" else "model", "parts": [m["content"]]}
                            for m in st.session_state.messages[:-1]
                        ]
                        chat = model.start_chat(history=chat_history)
                        response = chat.send_message(prompt)
                        
                        ai_reply = response.text
                        st.markdown(ai_reply)
                        st.session_state.messages.append({"role": "assistant", "content": ai_reply})
                    except Exception as e:
                        error_msg = f"Error generating response: {e}. Please check your API key."
                        st.error(error_msg)
    else:
        st.warning("⚠️ Please provide a Gemini API key in your Streamlit Secrets or enter it in the sidebar to activate the AI Trading Coach.")
        st.markdown("""
        **How to set it up for your friends automatically:**
        1. Get a free API key from Google AI Studio.
        2. In your Streamlit Cloud app dashboard, go to **Settings > Secrets**.
        3. Add your key like this:
           ```toml
           GEMINI_API_KEY = "your_actual_api_key_here"
           ```
        Once saved, anyone who opens your link can chat with the AI coach instantly without needing their own key!
        """)
