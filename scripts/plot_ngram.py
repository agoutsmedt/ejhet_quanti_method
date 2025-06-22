import plotly.express as px
import pandas as pd

# Lecture du fichier Parquet contenant les fréquences relatives
REL_FREQ_PARQUET = "relative_freq_merged_by_year.parquet"
df = pd.read_parquet(REL_FREQ_PARQUET)

def plot_token(token_query):
    token_query = token_query.lower()
    data = df[df["token"] == token_query]
    
    if data.empty:
        print(f"❌ Token '{token_query}' not found.")
        return

    data = data.sort_values("year")

    fig = px.line(
        data,
        x="year",
        y="relative_freq",
        title=f"Relative Frequency of '{token_query}' over Time",
        labels={"year": "Year", "relative_freq": "Relative Frequency"},
        markers=True,
    )

    fig.update_layout(
        xaxis=dict(dtick=5),
        template="plotly_white",
        hovermode="x unified"
    )

    fig.show()
