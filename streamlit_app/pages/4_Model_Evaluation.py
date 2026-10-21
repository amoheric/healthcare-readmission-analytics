"""Patient-grouped HGB model evaluation and responsible AI reporting."""

import altair as alt
import pandas as pd
import streamlit as st

from utils.data_loader import load_hgb_report


st.set_page_config(
    page_title="Model Evaluation | Healthcare Readmission Analytics",
    page_icon="📊",
    layout="wide",
)

st.title("Model Evaluation & Responsible AI")

st.caption(
    "Histogram Gradient Boosting | "
    "Patient-grouped out-of-fold development validation"
)

st.warning(
    "These results come from the development cohort, not an "
    "independent held-out test. The HGB model family and "
    "hyperparameters were previously selected using this cohort. "
    "Performance estimates are therefore not fully independent "
    "estimates of generalization. The model is not clinically "
    "validated or deployment-ready."
)

folds = load_hgb_report(
    "notebook07_fold_performance"
)

bootstrap = load_hgb_report(
    "notebook07_patient_bootstrap_summary"
)

summary = load_hgb_report(
    "notebook07_responsible_evaluation_summary"
)


def get_estimate(domain: str, result: str) -> float:
    """Retrieve one validated responsible-evaluation estimate."""

    rows = summary.loc[
        (summary["domain"] == domain)
        & (summary["result"] == result)
    ]

    if len(rows) != 1:
        raise ValueError(
            f"Expected one estimate for {domain}: {result}"
        )

    return float(rows.iloc[0]["estimate"])


roc_auc = get_estimate(
    "Group-aware discrimination",
    "ROC-AUC",
)

average_precision = get_estimate(
    "Group-aware ranking",
    "Average precision",
)

brier_score = get_estimate(
    "Probability accuracy",
    "Brier score",
)

development_encounters = int(
    folds["eval_encounters"].sum()
)

st.subheader("Overall Development Validation")

st.write(
    "Performance was estimated using five-fold "
    "StratifiedGroupKFold validation, grouping encounters "
    "by patient. Each encounter contributed to one "
    "out-of-fold evaluation."
)

st.caption(
    f"Development encounters: {development_encounters:,} | "
    "Unique patients: 60,790 | "
    "Validation folds: 5"
)

col1, col2, col3, col4 = st.columns(4)

col1.metric(
    "OOF ROC-AUC",
    f"{roc_auc:.4f}",
)

col2.metric(
    "Average Precision",
    f"{average_precision:.4f}",
)

col3.metric(
    "Brier Score",
    f"{brier_score:.4f}",
)

col4.metric(
    "Development Encounters",
    f"{development_encounters:,}",
)

st.divider()

st.subheader("Patient-Bootstrap Uncertainty")

st.write(
    "The 95% confidence intervals quantify patient-level "
    "sampling uncertainty for the existing out-of-fold "
    "predictions. They do not include model-refitting "
    "variability."
)

intervals = bootstrap[
    [
        "metric",
        "point_estimate",
        "ci_2.5%",
        "ci_97.5%",
    ]
].copy()

intervals.columns = [
    "Metric",
    "Point Estimate",
    "95% CI Lower",
    "95% CI Upper",
]

st.dataframe(
    intervals,
    hide_index=True,
    width="stretch",
    column_config={
        "Metric": st.column_config.TextColumn(
            "Metric",
            width="medium",
        ),
        "Point Estimate": st.column_config.NumberColumn(
            "Point Estimate",
            format="%.4f",
        ),
        "95% CI Lower": st.column_config.NumberColumn(
            "95% CI Lower",
            format="%.4f",
        ),
        "95% CI Upper": st.column_config.NumberColumn(
            "95% CI Upper",
            format="%.4f",
        ),
    },
)

st.caption(
    "Confidence intervals were obtained using 1,000 "
    "patient-bootstrap replicates. These intervals are "
    "conditional on the existing development-stage OOF predictions."
)

st.divider()

st.subheader("Five-Fold Validation Performance")

st.write(
    "Fold-level metrics allow examination of performance "
    "consistency across patient-separated evaluation partitions."
)

fold_metric_labels = {
    "roc_auc": "ROC-AUC",
    "average_precision": "Average precision",
    "brier_score": "Brier score",
}

selected_metric = st.selectbox(
    "Select a validation metric",
    options=list(fold_metric_labels),
    format_func=lambda key: fold_metric_labels[key],
    key="hgb_fold_metric",
)

chart_data = folds[
    ["fold", selected_metric]
].copy()

chart_data.columns = ["Fold", "Value"]

chart_data["Fold"] = chart_data["Fold"].map(
    lambda fold: f"Fold {int(fold)}"
)

chart = (
    alt.Chart(chart_data)
    .mark_bar()
    .encode(
        x=alt.X(
            "Fold:N",
            title="Patient-grouped validation fold",
            sort=[
                "Fold 1",
                "Fold 2",
                "Fold 3",
                "Fold 4",
                "Fold 5",
            ],
            axis=alt.Axis(labelAngle=0),
        ),
        y=alt.Y(
            "Value:Q",
            title=fold_metric_labels[selected_metric],
            scale=alt.Scale(zero=True),
        ),
        tooltip=[
            alt.Tooltip("Fold:N", title="Validation fold"),
            alt.Tooltip("Value:Q", format=".4f"),
        ],
    )
    .properties(height=320)
)

st.altair_chart(
    chart,
    width="stretch",
)

fold_table = folds[
    [
        "fold",
        "eval_encounters",
        "eval_patients",
        "roc_auc",
        "average_precision",
        "brier_score",
    ]
].copy()

fold_table.columns = [
    "Fold",
    "Evaluation Encounters",
    "Evaluation Patients",
    "ROC-AUC",
    "Average Precision",
    "Brier Score",
]

st.dataframe(
    fold_table,
    hide_index=True,
    width="stretch",
    column_config={
        "Fold": st.column_config.NumberColumn(
            "Fold",
            format="%d",
        ),
        "Evaluation Encounters": st.column_config.NumberColumn(
            "Evaluation Encounters",
            format="%d",
        ),
        "Evaluation Patients": st.column_config.NumberColumn(
            "Evaluation Patients",
            format="%d",
        ),
        "ROC-AUC": st.column_config.NumberColumn(
            "ROC-AUC",
            format="%.4f",
        ),
        "Average Precision": st.column_config.NumberColumn(
            "Average Precision",
            format="%.4f",
        ),
        "Brier Score": st.column_config.NumberColumn(
            "Brier Score",
            format="%.4f",
        ),
    },
)

st.info(
    "Fold-level performance was relatively consistent, "
    "but the overall discrimination remains moderate. "
    "These results should not be presented as independent "
    "external validation."
)

st.divider()

st.subheader("Calibration & Screening Performance")

st.write(
    "Calibration summarizes the agreement between predicted "
    "probabilities and observed outcomes. Screening metrics describe "
    "classification behavior at the locked development threshold."
)

calibration_values = {
    "Expected calibration error": get_estimate(
        "Calibration", "Expected calibration error"
    ),
    "Calibration intercept": get_estimate(
        "Calibration", "Calibration intercept"
    ),
    "Calibration slope": get_estimate(
        "Calibration", "Calibration slope"
    ),
}

st.markdown("#### Probability Calibration")

calibration_table = pd.DataFrame(
    {
        "Measure": list(calibration_values),
        "Estimate": list(calibration_values.values()),
    }
)

st.dataframe(
    calibration_table,
    hide_index=True,
    width="stretch",
    column_config={
        "Measure": st.column_config.TextColumn(
            "Measure", width="medium"
        ),
        "Estimate": st.column_config.NumberColumn(
            "Estimate", format="%.4f"
        ),
    },
)

st.caption(
    "Expected calibration error summarizes aggregate calibration "
    "across probability bins. Calibration intercept and slope assess "
    "systematic calibration deviations. Low aggregate calibration "
    "error does not guarantee reliable probabilities for every subgroup."
)

st.markdown("#### Development Screening Operating Point")

threshold = get_estimate(
    "Screening operating point", "Locked threshold"
)

screening_sensitivity = get_estimate(
    "Screening operating point", "Sensitivity"
)

screening_specificity = get_estimate(
    "Screening operating point", "Specificity"
)

predicted_positive_rate = get_estimate(
    "Screening burden", "Predicted-positive rate"
)

st.caption(
    f"Locked development threshold: {threshold:.3f}"
)

screen1, screen2, screen3 = st.columns(3)

screen1.metric(
    "Sensitivity",
    f"{screening_sensitivity:.2%}",
)

screen2.metric(
    "Specificity",
    f"{screening_specificity:.2%}",
)

screen3.metric(
    "Predicted-Positive Rate",
    f"{predicted_positive_rate:.2%}",
)

st.info(
    "At the development-stage threshold, approximately "
    f"{screening_sensitivity:.0%} of observed readmissions "
    "were classified as positive. However, approximately "
    f"{predicted_positive_rate:.0%} of all development encounters "
    "received a positive classification. This indicates a "
    "substantial potential screening burden."
)

st.warning(
    "The threshold was selected for a development-stage "
    "screening objective. These results have not been "
    "externally validated and should not be interpreted "
    "as a clinical screening recommendation."
)

st.divider()

st.subheader("Responsible AI & Subgroup Robustness")

st.write(
    "Explore descriptive differences in HGB development-stage "
    "performance across demographic groups. Results are based "
    "on patient-grouped out-of-fold predictions."
)

attribute_files = {
    "Gender": "notebook07_gender_subgroup_performance",
    "Race": "notebook07_race_subgroup_performance",
    "Age": "notebook07_age_subgroup_performance",
}

subgroup_metrics = {
    "ROC-AUC": "roc_auc",
    "Sensitivity": "sensitivity",
    "Specificity": "specificity",
    "False-positive rate": "false_positive_rate",
    "Predicted-positive rate": "predicted_positive_rate",
}

attribute_col, metric_col = st.columns(2)

with attribute_col:
    selected_attribute = st.selectbox(
        "Demographic attribute",
        options=list(attribute_files),
        key="hgb_subgroup_attribute",
    )

with metric_col:
    selected_subgroup_metric = st.selectbox(
        "Performance measure",
        options=list(subgroup_metrics),
        key="hgb_subgroup_metric",
    )

subgroup_data = load_hgb_report(
    attribute_files[selected_attribute]
)

metric_column = subgroup_metrics[selected_subgroup_metric]

supported_groups = subgroup_data.loc[
    subgroup_data["sufficient_sample"] == True
].copy()

unsupported_groups = subgroup_data.loc[
    subgroup_data["sufficient_sample"] == False
].copy()

chart_data = supported_groups[
    [
        "subgroup_value",
        "encounters",
        "positives",
        metric_column,
    ]
].copy()

chart_data.columns = [
    "Group",
    "Encounters",
    "Readmissions",
    "Performance",
]

chart_data["Performance (%)"] = (
    chart_data["Performance"] * 100
)

st.markdown(
    f"#### {selected_subgroup_metric} by {selected_attribute}"
)

chart = (
    alt.Chart(chart_data)
    .mark_bar()
    .encode(
        x=alt.X(
            "Performance (%):Q",
            title=f"{selected_subgroup_metric} (%)",
            scale=alt.Scale(domain=[0, 100]),
        ),
        y=alt.Y(
            "Group:N",
            title=None,
            sort="-x",
            axis=alt.Axis(labelLimit=200),
        ),
        tooltip=[
            alt.Tooltip("Group:N"),
            alt.Tooltip(
                "Performance (%):Q",
                title=f"{selected_subgroup_metric} (%)",
                format=".2f",
            ),
            alt.Tooltip(
                "Encounters:Q",
                format=",",
            ),
            alt.Tooltip(
                "Readmissions:Q",
                format=",",
            ),
        ],
    )
    .properties(
        height=max(240, len(chart_data) * 42)
    )
)

st.altair_chart(
    chart,
    width="stretch",
)

st.markdown("#### Subgroup Sample Sizes and Performance")

display_data = subgroup_data[
    [
        "subgroup_value",
        "encounters",
        "positives",
        "sufficient_sample",
        metric_column,
    ]
].copy()

display_data.columns = [
    "Group",
    "Encounters",
    "Readmissions",
    "Sufficient Sample",
    "Performance",
]

# Presentation-only formatting; source metrics remain numeric.
# Do not display performance estimates for insufficient-sample groups.
display_data["Performance"] = display_data.apply(
    lambda row: (
        "Insufficient sample"
        if not bool(row["Sufficient Sample"])
        else (
            f'{row["Performance"] * 100:.2f}'
            if pd.notna(row["Performance"])
            else "Not estimated"
        )
    ),
    axis=1,
)

st.dataframe(
    display_data,
    hide_index=True,
    width="stretch",
    column_config={
        "Group": st.column_config.TextColumn(
            "Group", width="medium"
        ),
        "Encounters": st.column_config.NumberColumn(
            "Encounters", format="%d"
        ),
        "Readmissions": st.column_config.NumberColumn(
            "Readmissions", format="%d"
        ),
        "Sufficient Sample": st.column_config.CheckboxColumn(
            "Sufficient Sample"
        ),
        "Performance": st.column_config.TextColumn(
            f"{selected_subgroup_metric} (%)",
            width="medium",
        ),
    },
)

if not unsupported_groups.empty:
    excluded_names = ", ".join(
        unsupported_groups["subgroup_value"].astype(str)
    )

    st.warning(
        "Insufficient-sample groups were excluded from the "
        f"comparison chart: {excluded_names}. "
        "They remain visible in the supporting table. "
        "Undefined measures are retained as missing."
    )

st.caption(
    "Displayed estimates are descriptive. Differences may reflect "
    "sample size, outcome prevalence, or other characteristics. "
    "They do not establish causality or clinical fairness."
)

st.divider()

st.subheader("Prespecified Subgroup Contrasts")

st.write(
    "Patient-bootstrap confidence intervals describe uncertainty "
    "in four prespecified performance differences. These contrasts "
    "are distinct from the minimum-to-maximum subgroup ranges."
)

contrasts = load_hgb_report(
    "notebook07_fairness_contrast_bootstrap"
)

contrast_labels = {
    "Gender: Female - Male": "Female minus Male",
    "Race: AfricanAmerican - Caucasian":
        "AfricanAmerican minus Caucasian",
    "Adult age: 70+ - 20-49": "Age 70+ minus Age 20-49",
}

selected_contrast = st.selectbox(
    "Select a prespecified comparison",
    options=list(contrast_labels),
    format_func=lambda key: contrast_labels[key],
    key="hgb_bootstrap_contrast",
)

selected_results = contrasts.loc[
    contrasts["contrast"] == selected_contrast
].copy()

metric_names = {
    "roc_auc": "ROC-AUC",
    "sensitivity": "Sensitivity",
    "false_positive_rate": "False-positive rate",
    "predicted_positive_rate": "Predicted-positive rate",
}

assert set(selected_results["metric"]) == set(metric_names)

selected_results["Measure"] = (
    selected_results["metric"].map(metric_names)
)

selected_results["Difference"] = (
    selected_results["point_difference"]
)

selected_results["95% CI Lower"] = (
    selected_results["ci_2.5%"]
)

selected_results["95% CI Upper"] = (
    selected_results["ci_97.5%"]
)

selected_results["Interval Includes Zero"] = (
    selected_results["ci_includes_zero"]
)

contrast_table = selected_results[
    [
        "Measure",
        "Difference",
        "95% CI Lower",
        "95% CI Upper",
        "Interval Includes Zero",
    ]
]

st.dataframe(
    contrast_table,
    hide_index=True,
    width="stretch",
    column_config={
        "Measure": st.column_config.TextColumn(
            "Measure", width="medium"
        ),
        "Difference": st.column_config.NumberColumn(
            "Difference", format="%+.4f"
        ),
        "95% CI Lower": st.column_config.NumberColumn(
            "95% CI Lower", format="%+.4f"
        ),
        "95% CI Upper": st.column_config.NumberColumn(
            "95% CI Upper", format="%+.4f"
        ),
        "Interval Includes Zero": st.column_config.CheckboxColumn(
            "Interval Includes Zero"
        ),
    },
)

st.caption(
    "Differences are expressed on the original metric scale. "
    "For rate-based measures, multiply by 100 to interpret "
    "the difference in percentage points."
)

if selected_contrast == "Adult age: 70+ - 20-49":
    st.warning(
        "The prespecified older-adult comparison shows lower "
        "ROC-AUC and a higher false-positive rate for encounters "
        "aged 70+. These development-stage findings warrant "
        "further investigation and external validation."
    )

st.info(
    "Confidence intervals describe patient-bootstrap sampling "
    "uncertainty for fixed out-of-fold predictions. They exclude "
    "model-refitting variability. An interval excluding zero "
    "does not by itself establish causality, clinical significance, "
    "or discriminatory treatment."
)

st.divider()

st.subheader("Evaluation Boundaries")

st.markdown(
    """
    - **Model:** Histogram Gradient Boosting.
    - **Evaluation:** Five-fold patient-grouped OOF validation.
    - **Development cohort:** 86,547 encounters from 60,790 patients.
    - **Patient separation:** `patient_nbr` used for fold grouping.
    - **Independent held-out test:** Not evaluated in Notebook 07.
    - **Model selection:** HGB family and hyperparameters previously
      selected using the development cohort.
    - **Bootstrap uncertainty:** Conditional on fixed OOF predictions.
    - **Clinical use:** Not externally validated or deployment-ready.
    - **Privacy:** Aggregate reporting statistics only.
    """
)

st.caption(
    "Research source: Notebook 07 — Model Validation. "
    "All metrics are loaded from approved aggregate reporting exports."
)
