"""Healthcare Readmission Analytics — Interactive Research Dashboard."""

import pandas as pd
import streamlit as st

from utils.data_loader import load_sql_export


st.set_page_config(
    page_title="Hospital Readmission Analytics",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded",
)


# ---------------------------------------------------------------------
# HEADER
# ---------------------------------------------------------------------

st.title("🏥 Hospital Readmission Analytics")

st.markdown(
    "**Interactive Research Dashboard | "
    "Diabetes Hospital Readmission Analysis**"
)

st.caption(
    "Historical UCI Diabetes 130-US Hospitals dataset (1999–2008). "
    "Descriptive statistics represent the training and validation "
    "development cohort, not the independent test partition."
)

st.divider()


# ---------------------------------------------------------------------
# LOAD VALIDATED DATA
# ---------------------------------------------------------------------

try:
    kpi = load_sql_export("readmission_kpi")
except (FileNotFoundError, ValueError) as error:
    st.error(f"Unable to load validated KPI data: {error}")
    st.stop()

row = kpi.iloc[0]

total_encounters = int(row["total_encounters"])
readmitted = int(row["readmitted_30d_encounters"])
not_readmitted = int(row["non_readmitted_30d_encounters"])
readmission_rate = float(row["readmission_rate_pct"])


# ---------------------------------------------------------------------
# EXECUTIVE KPI CARDS
# ---------------------------------------------------------------------

st.subheader("Executive Overview")

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        label="Hospital Encounters",
        value=f"{total_encounters:,}",
    )

with col2:
    st.metric(
        label="Readmitted Within 30 Days",
        value=f"{readmitted:,}",
    )

with col3:
    st.metric(
        label="Other Encounters",
        value=f"{not_readmitted:,}",
    )

with col4:
    st.metric(
        label="Observed Readmission Rate",
        value=f"{readmission_rate:.2f}%",
    )

st.divider()


# ---------------------------------------------------------------------
# OUTCOME DISTRIBUTION
# ---------------------------------------------------------------------

st.subheader("30-Day Readmission Outcome Distribution")

outcome_data = pd.DataFrame(
    {
        "Outcome": [
            "Readmitted within 30 days",
            "Other encounters",
        ],
        "Encounters": [
            readmitted,
            not_readmitted,
        ],
    }
)

st.bar_chart(
    outcome_data,
    x="Outcome",
    y="Encounters",
    horizontal=True,
    sort=False,
)

st.caption(
    "Counts represent hospital encounters, not unique patients. "
    "The 'Other encounters' category includes encounters not "
    "classified as readmitted within 30 days."
)


# ---------------------------------------------------------------------
# RESEARCH CONTEXT
# ---------------------------------------------------------------------

st.subheader("About This Research")

st.markdown(
    """
    This project examines historical hospital encounter records from
    the UCI Diabetes 130-US Hospitals dataset.

    It integrates exploratory data analysis, feature engineering,
    machine learning, patient-aware validation, PostgreSQL reporting,
    and interactive analytical visualization.

    **Research objective:** Investigate patterns associated with
    hospital readmission within 30 days and evaluate the performance
    and limitations of predictive models.
    """
)

with st.expander("Methodology and Important Limitations"):
    st.markdown(
        """
        - Descriptive statistics represent the development cohort
          comprising training and validation encounters.
        - The dataset contains historical hospital encounters rather
          than a contemporary representative U.S. patient population.
        - Encounter counts do not represent unique patient counts.
        - Observed associations should not be interpreted as causal.
        - Model evaluation results will be presented separately from
          descriptive population statistics.
        - This dashboard is intended for research and portfolio
          demonstration, not clinical decision-making.
        """
    )


# ---------------------------------------------------------------------
# FOOTER
# ---------------------------------------------------------------------

st.divider()

st.caption(
    "Healthcare Readmission Analytics | "
    "Python • PostgreSQL • Machine Learning • Streamlit"
)
