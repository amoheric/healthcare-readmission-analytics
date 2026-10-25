"""Predictive modeling results for the healthcare readmission project."""

import pandas as pd
import streamlit as st

from utils.data_loader import load_model_report, load_model_comparison


st.set_page_config(
    page_title="Predictive Modeling | Healthcare Readmission Analytics",
    page_icon="📈",
    layout="wide",
)

st.title("Predictive Modeling")
st.caption("Optimized Random Forest | Patient-disjoint held-out test evaluation")

st.info(
    "This page reports retrospective research results. "
    "The model is not externally validated or approved for clinical use."
)

report = load_model_report("optimized_rf_test_metrics")

metrics = report["metrics"]
counts = report["confusion_matrix"]

st.subheader("Optimized Random Forest — Held-Out Test")

st.write(
    "The Random Forest configuration was selected using development "
    "data. Its classification threshold was locked using the "
    "validation partition before evaluation on the held-out test set."
)

st.warning(
    "Evaluation-history note: Notebook 05 evaluated baseline models "
    "on the held-out test partition before Notebook 06 evaluated the "
    "optimized Random Forest on that same partition. The test patients "
    "were separate from development patients, but the test set was "
    "not strictly untouched or single-use. Interpret these results "
    "as retrospective held-out performance, not an independent "
    "external validation."
)

st.caption(
    f"Model candidate: {report['model_candidate']} | "
    f"Threshold: {report['threshold']:.2f} | "
    f"Test encounters: {report['test_encounters']:,}"
)

col1, col2, col3, col4 = st.columns(4)

col1.metric(
    "ROC-AUC",
    f"{metrics['roc_auc']:.4f}",
)

col2.metric(
    "Average Precision",
    f"{metrics['average_precision']:.4f}",
)

col3.metric(
    "Sensitivity",
    f"{metrics['sensitivity']:.2%}",
)

col4.metric(
    "Specificity",
    f"{metrics['specificity']:.2%}",
)

st.divider()

st.subheader("Complete Performance Summary")

metric_labels = {
    "roc_auc": "ROC-AUC",
    "average_precision": "Average precision",
    "brier_score": "Brier score",
    "balanced_accuracy": "Balanced accuracy",
    "precision": "Precision",
    "sensitivity": "Sensitivity",
    "specificity": "Specificity",
    "f1": "F1 score",
}

performance_table = pd.DataFrame(
    {
        "Performance Measure": [
            metric_labels[key] for key in metric_labels
        ],
        "Value": [
            metrics[key] for key in metric_labels
        ],
    }
)

st.dataframe(
    performance_table,
    hide_index=True,
    width="stretch",
    column_config={
        "Performance Measure": st.column_config.TextColumn(
            "Performance Measure",
            width="medium",
        ),
        "Value": st.column_config.NumberColumn(
            "Value",
            format="%.4f",
        ),
    },
)

st.caption(
    "ROC-AUC and average precision describe ranking performance. "
    "Brier score measures probability error. Sensitivity, specificity, "
    "precision, balanced accuracy, and F1 depend on the locked "
    "classification threshold."
)

st.divider()

st.subheader("Baseline vs. Optimized Random Forest")

st.write(
    "Compare the original Random Forest baseline with the "
    "optimized Random Forest using their documented held-out "
    "test results."
)

comparison = load_model_comparison(
    "rf_baseline_comparison"
)

comparison_display = comparison[
    [
        "metric_label",
        "baseline_rf",
        "optimized_rf",
        "absolute_change",
    ]
].copy()

comparison_display.columns = [
    "Performance Measure",
    "Baseline RF",
    "Optimized RF",
    "Change",
]

st.caption(
    "Baseline threshold: 0.44 | "
    "Optimized threshold: 0.43 | "
    "Change = optimized minus baseline"
)

st.dataframe(
    comparison_display,
    hide_index=True,
    width="stretch",
    column_config={
        "Performance Measure": st.column_config.TextColumn(
            "Performance Measure",
            width="medium",
        ),
        "Baseline RF": st.column_config.NumberColumn(
            "Baseline RF",
            format="%.4f",
        ),
        "Optimized RF": st.column_config.NumberColumn(
            "Optimized RF",
            format="%.4f",
        ),
        "Change": st.column_config.NumberColumn(
            "Change",
            format="%+.4f",
        ),
    },
)

comparison_indexed = comparison.set_index("metric")

sensitivity_change = float(
    comparison_indexed.loc[
        "sensitivity", "absolute_change"
    ]
)

specificity_change = float(
    comparison_indexed.loc[
        "specificity", "absolute_change"
    ]
)

st.info(
    "At their respective locked thresholds, optimization "
    f"changed sensitivity by {sensitivity_change * 100:+.2f} "
    "percentage points and specificity by "
    f"{specificity_change * 100:+.2f} percentage points. "
    "Higher sensitivity was accompanied by lower specificity."
)

st.caption(
    "The reported changes are descriptive differences between "
    "two held-out evaluations. They are not claims of statistical "
    "significance. A lower Brier score indicates lower "
    "probability-prediction error."
)

st.divider()

st.subheader("Confusion Matrix")

st.write(
    "The confusion matrix summarizes the optimized model's "
    "classifications on the held-out test partition."
)

confusion_table = pd.DataFrame(
    {
        "Actual Outcome": [
            "Not readmitted within 30 days",
            "Readmitted within 30 days",
        ],
        "Predicted Negative": [
            counts["tn"],
            counts["fn"],
        ],
        "Predicted Positive": [
            counts["fp"],
            counts["tp"],
        ],
    }
)

st.dataframe(
    confusion_table,
    hide_index=True,
    width="stretch",
    column_config={
        "Actual Outcome": st.column_config.TextColumn(
            "Actual Outcome",
            width="large",
        ),
        "Predicted Negative": st.column_config.NumberColumn(
            "Predicted Negative",
            format="%d",
        ),
        "Predicted Positive": st.column_config.NumberColumn(
            "Predicted Positive",
            format="%d",
        ),
    },
)

st.caption(
    "True negatives: "
    f"{counts['tn']:,} | "
    "False positives: "
    f"{counts['fp']:,} | "
    "False negatives: "
    f"{counts['fn']:,} | "
    "True positives: "
    f"{counts['tp']:,}"
)

st.warning(
    "At the locked threshold, the model identified approximately "
    "75% of readmissions but classified many non-readmission "
    "encounters as positive. These results describe a research "
    "screening scenario, not an operational clinical recommendation."
)

st.divider()

st.subheader("Evaluation Boundaries")

st.markdown(
    """
    - **Model:** Optimized Random Forest, candidate 3.
    - **Evaluation:** Held-out test partition containing 15,219 encounters.
    - **Threshold selection:** Development-stage validation partition.
    - **Reported performance:** Historical research results, not real-time predictions.
    - **Generalization:** External validation has not been performed.
    - **Clinical application:** Not validated for clinical deployment.
    - **Privacy:** Only aggregate evaluation statistics are displayed.
    """
)

st.caption(
    "Research source: Notebook 06 — Model Optimization. "
    "Evaluation metrics are loaded from the validated aggregate JSON export."
)
