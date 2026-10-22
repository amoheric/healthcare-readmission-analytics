"""Patient demographics — descriptive hospital readmission analysis."""

import altair as alt
import pandas as pd
import streamlit as st

from utils.data_loader import load_sql_export


st.set_page_config(
    page_title="Patient Demographics | Hospital Readmission Analytics",
    page_icon="🏥",
    layout="wide",
)

st.title("Patient Demographics")

st.markdown(
    "Explore historical 30-day readmission patterns by age, "
    "gender, and race in the development cohort."
)

st.info(
    "These results describe hospital encounters, not unique patients. "
    "Comparisons are unadjusted and do not establish causation "
    "or measure predictive-model fairness."
)


@st.cache_data(show_spinner=False)
def prepare_demographics(dataset_name, category_column):
    """Load and annotate an approved demographic summary."""

    df = load_sql_export(dataset_name).copy()

    df["total_encounters"] = pd.to_numeric(
        df["total_encounters"], errors="raise"
    )

    df["readmitted_30d_encounters"] = pd.to_numeric(
        df["readmitted_30d_encounters"], errors="raise"
    )

    df["readmission_rate_pct"] = pd.to_numeric(
        df["readmission_rate_pct"], errors="raise"
    )

    df["presentation_caution"] = (
        (df["total_encounters"] < 100)
        | (df["readmitted_30d_encounters"] < 20)
    )

    df[category_column] = df[category_column].astype(str)

    return df


def show_demographic_analysis(
    dataframe, category_column, title, order=None
):
    """Render a labeled readmission comparison and supporting table."""

    st.subheader(title)

    chart = (
        alt.Chart(dataframe)
        .mark_bar()
        .encode(
            x=alt.X(
                "readmission_rate_pct:Q",
                title="Observed 30-day readmission rate (%)",
                scale=alt.Scale(domainMin=0),
            ),
            y=alt.Y(
                f"{category_column}:N",
                title=None,
                sort=order if order else "-x",
            ),
            tooltip=[
                alt.Tooltip(
                    f"{category_column}:N",
                    title="Category",
                ),
                alt.Tooltip(
                    "total_encounters:Q",
                    title="Encounters",
                    format=",",
                ),
                alt.Tooltip(
                    "readmitted_30d_encounters:Q",
                    title="30-day readmissions",
                    format=",",
                ),
                alt.Tooltip(
                    "readmission_rate_pct:Q",
                    title="Observed rate (%)",
                    format=".2f",
                ),
            ],
        )
        .properties(height=max(240, len(dataframe) * 38))
    )

    st.altair_chart(chart, width="stretch")

    display = dataframe[
        [
            category_column,
            "total_encounters",
            "readmitted_30d_encounters",
            "readmission_rate_pct",
            "volume_flag",
            "presentation_caution",
        ]
    ].copy()

    display["presentation_caution"] = display[
        "presentation_caution"
    ].map({True: "Review small group", False: ""})

    display = display.rename(
        columns={
            category_column: "Category",
            "total_encounters": "Encounters",
            "readmitted_30d_encounters": "Readmissions",
            "readmission_rate_pct": "Rate (%)",
            "volume_flag": "SQL Volume Flag",
            "presentation_caution": "Caution",
        }
    )

    st.dataframe(
        display,
        hide_index=True,
        width="stretch",
        column_config={
            "Category": st.column_config.TextColumn(
                "Category", width="small"
            ),
            "Encounters": st.column_config.NumberColumn(
                "Encounters", format="%d", width="small"
            ),
            "Readmissions": st.column_config.NumberColumn(
                "Readmissions", format="%d", width="small"
            ),
            "Rate (%)": st.column_config.NumberColumn(
                "Rate (%)", format="%.2f", width="small"
            ),
            "SQL Volume Flag": st.column_config.TextColumn(
                "SQL Volume Flag", width="medium"
            ),
            "Caution": st.column_config.TextColumn(
                "Caution", width="medium"
            ),
        },
    )

    if dataframe["presentation_caution"].any():
        st.warning(
            "Some categories have fewer than 100 encounters or "
            "fewer than 20 observed readmissions. Interpret their "
            "percentages cautiously."
        )


try:
    age = prepare_demographics(
        "readmission_by_age", "age_group"
    )

    gender = prepare_demographics(
        "readmission_by_gender", "gender"
    )

    race = prepare_demographics(
        "readmission_by_race", "race"
    )

except (FileNotFoundError, ValueError, KeyError) as error:
    st.error(f"Unable to load validated demographic data: {error}")
    st.stop()


age_tab, gender_tab, race_tab = st.tabs(
    ["Age Analysis", "Gender Analysis", "Race Analysis"]
)

with age_tab:
    age_order = [
        "[0-10)",
        "[10-20)",
        "[20-30)",
        "[30-40)",
        "[40-50)",
        "[50-60)",
        "[60-70)",
        "[70-80)",
        "[80-90)",
        "[90-100)",
    ]

    show_demographic_analysis(
        age, "age_group", "Readmission Patterns by Age", age_order
    )

with gender_tab:
    show_demographic_analysis(
        gender, "gender", "Readmission Patterns by Gender"
    )

with race_tab:
    show_demographic_analysis(
        race, "race", "Readmission Patterns by Race"
    )


st.divider()

with st.expander("Interpretation and Methodological Limitations"):
    st.markdown(
        """
        - All rates describe historical development-cohort encounters.
        - Individuals may contribute more than one encounter.
        - Percentages are unadjusted descriptive measures.
        - Group differences do not establish causation.
        - A small number of events can produce unstable percentages.
        - Presentation cautions are not formal statistical tests.
        - Original SQL volume flags are retained for transparency.
        - Demographic outcome differences are not measures of
          machine-learning model fairness.
        - Results should not guide individual patient care.
        """
    )

st.caption(
    "Source: Validated PostgreSQL reporting summaries derived "
    "from the UCI Diabetes 130-US Hospitals dataset."
)
