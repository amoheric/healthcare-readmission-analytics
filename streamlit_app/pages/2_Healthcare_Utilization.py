"""Healthcare utilization and hospital operations dashboard."""

import altair as alt
import pandas as pd
import streamlit as st

from utils.data_loader import load_sql_export


st.set_page_config(
    page_title="Healthcare Utilization | Hospital Readmission Analytics",
    page_icon="🏥",
    layout="wide",
)

st.title("Healthcare Utilization & Hospital Operations")

st.markdown(
    "Explore historical hospital admission patterns, length of stay, "
    "prior healthcare utilization, and data completeness."
)

st.info(
    "All findings describe the training and validation development "
    "cohort. Observed associations do not establish causation."
)


# ---------------------------------------------------------------
# LOAD VALIDATED REPORTING DATA
# ---------------------------------------------------------------

try:
    admissions = load_sql_export(
        "readmission_by_admission_type"
    )

    length_of_stay = load_sql_export(
        "readmission_by_los"
    )

    utilization = load_sql_export(
        "utilization_by_outcome"
    )

    completeness = load_sql_export(
        "data_completeness"
    )

except (FileNotFoundError, ValueError) as error:
    st.error(f"Unable to load validated reporting data: {error}")
    st.stop()


# ---------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------

admission_tab, los_tab, utilization_tab, quality_tab = st.tabs(
    [
        "Admission Types",
        "Length of Stay",
        "Healthcare Utilization",
        "Data Completeness",
    ]
)


# ---------------------------------------------------------------
# ADMISSION TYPES
# ---------------------------------------------------------------

with admission_tab:

    st.subheader("Readmission Patterns by Admission Type")

    st.caption(
        "Admission categories reflect the historical source data. "
        "Low-volume categories require careful interpretation."
    )

    admission_chart = (
        alt.Chart(admissions)
        .mark_bar()
        .encode(
            x=alt.X(
                "readmission_rate_pct:Q",
                title="Observed 30-day readmission rate (%)",
                scale=alt.Scale(domainMin=0),
            ),
            y=alt.Y(
                "admission_type_description:N",
                title=None,
                sort="-x",
            ),
            tooltip=[
                alt.Tooltip(
                    "admission_type_description:N",
                    title="Admission type",
                ),
                alt.Tooltip(
                    "total_encounters:Q",
                    title="Encounters",
                    format=",",
                ),
                alt.Tooltip(
                    "readmitted_30d_encounters:Q",
                    title="Readmissions",
                    format=",",
                ),
                alt.Tooltip(
                    "readmission_rate_pct:Q",
                    title="Readmission rate (%)",
                    format=".2f",
                ),
            ],
        )
        .properties(height=350)
    )

    st.altair_chart(admission_chart, width="stretch")

    admission_display = admissions.rename(
        columns={
            "admission_type_description": "Admission Type",
            "total_encounters": "Encounters",
            "readmitted_30d_encounters": "Readmissions",
            "readmission_rate_pct": "Rate (%)",
        }
    )

    st.dataframe(
        admission_display,
        hide_index=True,
        width="stretch",
    )

    small_admission_groups = admissions.loc[
        (admissions["total_encounters"] < 100)
        | (admissions["readmitted_30d_encounters"] < 20)
    ]

    if not small_admission_groups.empty:
        st.warning(
            "Some admission categories contain fewer than 100 "
            "encounters or fewer than 20 readmissions. Their rates "
            "should not be used for broad comparisons."
        )


# ---------------------------------------------------------------
# LENGTH OF STAY
# ---------------------------------------------------------------

with los_tab:

    st.subheader("Readmission Rate by Length of Stay")

    st.caption(
        "Length of stay is measured in days. Rates are unadjusted "
        "and should not be interpreted as causal effects."
    )

    los_chart = (
        alt.Chart(length_of_stay)
        .mark_line(point=True)
        .encode(
            x=alt.X(
                "length_of_stay_days:Q",
                title="Hospital length of stay (days)",
                scale=alt.Scale(zero=False),
            ),
            y=alt.Y(
                "readmission_rate_pct:Q",
                title="Observed 30-day readmission rate (%)",
                scale=alt.Scale(zero=True),
            ),
            tooltip=[
                alt.Tooltip(
                    "length_of_stay_days:Q",
                    title="Days",
                ),
                alt.Tooltip(
                    "total_encounters:Q",
                    title="Encounters",
                    format=",",
                ),
                alt.Tooltip(
                    "readmitted_30d_encounters:Q",
                    title="Readmissions",
                    format=",",
                ),
                alt.Tooltip(
                    "readmission_rate_pct:Q",
                    title="Readmission rate (%)",
                    format=".2f",
                ),
            ],
        )
        .properties(height=350)
    )

    st.altair_chart(los_chart, width="stretch")

    st.dataframe(
        length_of_stay.rename(
            columns={
                "length_of_stay_days": "Days",
                "total_encounters": "Encounters",
                "readmitted_30d_encounters": "Readmissions",
                "readmission_rate_pct": "Rate (%)",
            }
        ),
        hide_index=True,
        width="stretch",
    )


# ---------------------------------------------------------------
# HEALTHCARE UTILIZATION
# ---------------------------------------------------------------

with utilization_tab:

    st.subheader("Healthcare Utilization by Readmission Outcome")

    st.markdown(
        "Compare average historical utilization measures for "
        "encounters with and without readmission within 30 days."
    )

    metric_labels = {
        "avg_length_of_stay": "Length of stay",
        "avg_lab_procedures": "Lab procedures",
        "avg_procedures": "Procedures",
        "avg_medications": "Medications",
        "avg_outpatient_visits": "Prior outpatient visits",
        "avg_emergency_visits": "Prior emergency visits",
        "avg_inpatient_visits": "Prior inpatient visits",
        "avg_diagnoses": "Diagnoses",
    }

    selected_metric = st.selectbox(
        "Select a utilization measure",
        options=list(metric_labels),
        format_func=lambda metric: metric_labels[metric],
    )

    comparison = utilization[
        ["readmitted_within_30_days", selected_metric]
    ].copy()

    comparison["Outcome"] = comparison[
        "readmitted_within_30_days"
    ].map(
        {
            0: "Not readmitted within 30 days",
            1: "Readmitted within 30 days",
        }
    )

    comparison["Average"] = comparison[selected_metric]

    comparison_chart = (
        alt.Chart(comparison)
        .mark_bar()
        .encode(
            x=alt.X(
                "Average:Q",
                title=f"Average {metric_labels[selected_metric].lower()}",
                scale=alt.Scale(zero=True),
            ),
            y=alt.Y(
                "Outcome:N",
                title=None,
                sort=[
                    "Not readmitted within 30 days",
                    "Readmitted within 30 days",
                ],
                axis=alt.Axis(labelLimit=250),
            ),
            tooltip=[
                alt.Tooltip("Outcome:N"),
                alt.Tooltip(
                    "Average:Q",
                    title="Average",
                    format=".2f",
                ),
            ],
        )
        .properties(height=350)
    )

    st.altair_chart(comparison_chart, width="stretch")

    st.caption(
        "These are descriptive group averages, not causal "
        "effects or adjusted estimates."
    )

    # Present each utilization measure as a comparison row.
    outcome_index = utilization.set_index(
        "readmitted_within_30_days"
    )

    assert set(outcome_index.index) == {0, 1}
    assert outcome_index.index.is_unique

    comparison_table = pd.DataFrame(
        {
            "Utilization Measure": [
                metric_labels[metric]
                for metric in metric_labels
            ],
            "Not Readmitted": [
                float(outcome_index.loc[0, metric])
                for metric in metric_labels
            ],
            "Readmitted": [
                float(outcome_index.loc[1, metric])
                for metric in metric_labels
            ],
        }
    )

    st.dataframe(
        comparison_table,
        hide_index=True,
        width="stretch",
        column_config={
            "Utilization Measure": st.column_config.TextColumn(
                "Utilization Measure", width="medium"
            ),
            "Not Readmitted": st.column_config.NumberColumn(
                "Not Readmitted", format="%.2f"
            ),
            "Readmitted": st.column_config.NumberColumn(
                "Readmitted", format="%.2f"
            ),
        },
    )


# ---------------------------------------------------------------
# DATA COMPLETENESS
# ---------------------------------------------------------------

with quality_tab:

    st.subheader("Data Completeness and Documentation")

    st.markdown(
        "Selected indicators describe how often information was "
        "unrecorded or categorized as unknown in the source data."
    )

    quality_metrics = {
        "A1C not recorded": float(
            completeness.iloc[0]["a1c_not_recorded_pct"]
        ),
        "Maximum glucose not recorded": float(
            completeness.iloc[0]["max_glucose_not_recorded_pct"]
        ),
        "Race unknown": float(
            completeness.iloc[0]["race_unknown_pct"]
        ),
    }

    quality_df = pd.DataFrame(
        {
            "Indicator": list(quality_metrics),
            "Percentage": list(quality_metrics.values()),
        }
    )

    quality_chart = (
        alt.Chart(quality_df)
        .mark_bar()
        .encode(
            x=alt.X(
                "Percentage:Q",
                title="Percentage (%)",
                scale=alt.Scale(domain=[0, 100]),
            ),
            y=alt.Y(
                "Indicator:N",
                title=None,
                sort=None,
                axis=alt.Axis(labelLimit=250),
            ),
            tooltip=[
                alt.Tooltip("Indicator:N"),
                alt.Tooltip(
                    "Percentage:Q",
                    title="Percentage (%)",
                    format=".2f",
                ),
            ],
        )
        .properties(height=260)
    )

    st.altair_chart(quality_chart, width="stretch")

    st.dataframe(
        quality_df,
        hide_index=True,
        width="stretch",
    )

    st.warning(
        "Not recorded does not necessarily mean that a laboratory "
        "test was not performed. These fields have substantial "
        "documentation limitations."
    )


# ---------------------------------------------------------------
# METHODOLOGICAL CONTEXT
# ---------------------------------------------------------------

st.divider()

with st.expander("Methodology and Interpretation"):
    st.markdown(
        """
        - All results describe historical development-cohort encounters.
        - Individuals may contribute multiple encounters.
        - Readmission percentages are descriptive and unadjusted.
        - Utilization averages do not represent causal effects.
        - Small admission categories may produce unstable rates.
        - Missing documentation limits clinical interpretation.
        - These visualizations are not intended for patient-care decisions.
        """
    )

st.caption(
    "Source: Validated PostgreSQL reporting summaries derived "
    "from the UCI Diabetes 130-US Hospitals dataset."
)
