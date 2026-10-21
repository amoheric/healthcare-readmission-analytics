"""Validated data loading for the Healthcare Readmission Streamlit app."""

from pathlib import Path
from copy import deepcopy
import json
import math

import pandas as pd
import streamlit as st


APP_ROOT = Path(__file__).resolve().parents[1]

SQL_EXPORT_DIR = APP_ROOT / "data" / "sql_exports"


APPROVED_DATASETS = {
    "readmission_kpi": [
        "total_encounters",
        "readmitted_30d_encounters",
        "non_readmitted_30d_encounters",
        "readmission_rate_pct",
    ],
    "readmission_by_partition": [
        "source_partition",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
    ],
    "readmission_by_age": [
        "age_group",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
        "volume_flag",
    ],
    "readmission_by_gender": [
        "gender",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
        "volume_flag",
    ],
    "readmission_by_race": [
        "race",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
        "volume_flag",
    ],
    "readmission_by_admission_type": [
        "admission_type_description",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
    ],
    "readmission_by_los": [
        "length_of_stay_days",
        "total_encounters",
        "readmitted_30d_encounters",
        "readmission_rate_pct",
    ],
    "utilization_by_outcome": [
        "readmitted_within_30_days",
        "total_encounters",
        "avg_length_of_stay",
        "avg_lab_procedures",
        "avg_procedures",
        "avg_medications",
        "avg_outpatient_visits",
        "avg_emergency_visits",
        "avg_inpatient_visits",
        "avg_diagnoses",
    ],
    "data_completeness": [
        "a1c_not_recorded_pct",
        "max_glucose_not_recorded_pct",
        "race_unknown_pct",
    ],
}

@st.cache_data(show_spinner=False)
def load_sql_export(dataset_name: str) -> pd.DataFrame:
    """Load an approved, locally stored PostgreSQL reporting export."""

    if dataset_name not in APPROVED_DATASETS:
        raise ValueError(
            f"Dataset '{dataset_name}' is not approved for loading."
        )

    path = SQL_EXPORT_DIR / f"{dataset_name}.csv"

    if not path.is_file():
        raise FileNotFoundError(
            f"Required dashboard dataset is missing: {path}"
        )

    dataframe = pd.read_csv(path)

    expected_columns = APPROVED_DATASETS[dataset_name]

    if list(dataframe.columns) != expected_columns:
        raise ValueError(
            f"Unexpected schema for dataset '{dataset_name}'."
        )

    if dataframe.empty:
        raise ValueError(
            f"Dataset '{dataset_name}' contains no data."
        )

    return dataframe.copy()


# Approved aggregate-only machine-learning reporting artifacts.
MODEL_EXPORT_DIR = APP_ROOT / "data" / "model_exports"

APPROVED_MODEL_REPORTS = {
    "optimized_rf_test_metrics": {
        "model": "Optimized Random Forest",
        "evaluation_type": "Held-out test",
        "threshold": 0.43,
        "test_encounters": 15219,
    }
}

MODEL_METRICS = (
    "roc_auc",
    "average_precision",
    "brier_score",
    "balanced_accuracy",
    "precision",
    "sensitivity",
    "specificity",
    "f1",
)

CONFUSION_KEYS = ("tn", "fp", "fn", "tp")


@st.cache_data(show_spinner=False)
def load_model_report(report_name: str) -> dict:
    """Load and validate an approved aggregate model-evaluation report."""

    if report_name not in APPROVED_MODEL_REPORTS:
        raise ValueError(
            f"Model report '{report_name}' is not approved."
        )

    path = MODEL_EXPORT_DIR / f"{report_name}.json"

    if not path.is_file():
        raise FileNotFoundError(
            f"Required model report is missing: {path}"
        )

    with path.open("r", encoding="utf-8") as file:
        report = json.load(file)

    if not isinstance(report, dict):
        raise ValueError("Model report must contain a JSON object.")

    contract = APPROVED_MODEL_REPORTS[report_name]

    for field, expected in contract.items():
        if report.get(field) != expected:
            raise ValueError(
                f"Unexpected model report value: {field}"
            )

    if report.get("threshold_selection") != "Validation partition":
        raise ValueError("Unexpected threshold-selection provenance.")

    if report.get("source_notebook") != "06_model_optimization.ipynb":
        raise ValueError("Unexpected model source notebook.")

    if report.get("source_artifact") != "notebook06_optimization_metadata.json":
        raise ValueError("Unexpected model source artifact.")

    metrics = report.get("metrics")
    counts = report.get("confusion_matrix")

    if not isinstance(metrics, dict):
        raise ValueError("Missing model performance metrics.")

    if not isinstance(counts, dict):
        raise ValueError("Missing confusion matrix.")

    if set(metrics) != set(MODEL_METRICS):
        raise ValueError("Unexpected model performance schema.")

    if set(counts) != set(CONFUSION_KEYS):
        raise ValueError("Unexpected confusion-matrix schema.")

    for metric in MODEL_METRICS:
        value = metrics[metric]

        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(value)
            or not 0 <= value <= 1
        ):
            raise ValueError(f"Invalid model metric: {metric}")

    for key in CONFUSION_KEYS:
        value = counts[key]

        if (
            isinstance(value, bool)
            or not isinstance(value, int)
            or value < 0
        ):
            raise ValueError(f"Invalid confusion count: {key}")

    tn, fp, fn, tp = (
        counts[key] for key in CONFUSION_KEYS
    )

    if tn + fp + fn + tp != report["test_encounters"]:
        raise ValueError("Confusion-matrix total does not reconcile.")

    if not all((tp + fn, tn + fp, tp + fp)):
        raise ValueError("Invalid confusion-matrix denominators.")

    calculated = {
        "sensitivity": tp / (tp + fn),
        "specificity": tn / (tn + fp),
        "precision": tp / (tp + fp),
        "balanced_accuracy": (
            tp / (tp + fn) + tn / (tn + fp)
        ) / 2,
        "f1": 2 * tp / (2 * tp + fp + fn),
    }

    for metric, expected in calculated.items():
        if not math.isclose(
            metrics[metric],
            expected,
            rel_tol=0,
            abs_tol=1e-10,
        ):
            raise ValueError(
                f"Model metric does not reconcile: {metric}"
            )

    return deepcopy(report)



APPROVED_MODEL_COMPARISONS = {
    "rf_baseline_comparison": [
        "metric",
        "metric_label",
        "baseline_rf",
        "optimized_rf",
        "absolute_change",
    ]
}


@st.cache_data(show_spinner=False)
def load_model_comparison(comparison_name: str) -> pd.DataFrame:
    """Load and validate an approved aggregate model comparison."""

    if comparison_name not in APPROVED_MODEL_COMPARISONS:
        raise ValueError(
            f"Model comparison '{comparison_name}' is not approved."
        )

    path = MODEL_EXPORT_DIR / f"{comparison_name}.csv"

    if not path.is_file():
        raise FileNotFoundError(
            f"Required model comparison is missing: {path}"
        )

    dataframe = pd.read_csv(path)

    expected_columns = APPROVED_MODEL_COMPARISONS[comparison_name]

    if list(dataframe.columns) != expected_columns:
        raise ValueError("Unexpected model comparison schema.")

    if len(dataframe) != len(MODEL_METRICS):
        raise ValueError("Unexpected number of comparison metrics.")

    if (
        dataframe["metric"].isna().any()
        or dataframe["metric_label"].isna().any()
        or not dataframe["metric"].is_unique
        or set(dataframe["metric"]) != set(MODEL_METRICS)
    ):
        raise ValueError("Invalid model comparison metric registry.")

    numeric_columns = [
        "baseline_rf",
        "optimized_rf",
        "absolute_change",
    ]

    import numpy as np

    for column in numeric_columns:
        if (
            not pd.api.types.is_numeric_dtype(dataframe[column])
            or not np.isfinite(dataframe[column].to_numpy()).all()
        ):
            raise ValueError(
                f"Invalid comparison values: {column}"
            )

    for column in ["baseline_rf", "optimized_rf"]:
        if not dataframe[column].between(0, 1).all():
            raise ValueError(
                f"Metric outside expected range: {column}"
            )

    calculated_change = (
        dataframe["optimized_rf"] - dataframe["baseline_rf"]
    )

    if not np.allclose(
        calculated_change,
        dataframe["absolute_change"],
        rtol=0,
        atol=1e-12,
    ):
        raise ValueError(
            "Model comparison differences do not reconcile."
        )

    optimized_report = load_model_report(
        "optimized_rf_test_metrics"
    )

    for row in dataframe.itertuples(index=False):
        expected_value = optimized_report["metrics"][row.metric]

        if not np.isclose(
            row.optimized_rf,
            expected_value,
            rtol=0,
            atol=1e-12,
        ):
            raise ValueError(
                f"Optimized result mismatch: {row.metric}"
            )

    return dataframe.copy()





SUBGROUP_PERFORMANCE_COLUMNS = [
    "subgroup_column",
    "subgroup_value",
    "encounters",
    "positives",
    "negatives",
    "prevalence",
    "roc_auc",
    "average_precision",
    "brier_score",
    "sensitivity",
    "specificity",
    "false_positive_rate",
    "precision",
    "npv",
    "balanced_accuracy",
    "f1",
    "predicted_positive_rate",
    "tn",
    "fp",
    "fn",
    "tp",
    "sufficient_sample",
]

# Approved aggregate-only HGB evaluation reports.
APPROVED_HGB_REPORTS = {
    "notebook07_fold_performance": {
        "columns": [
            "fold",
            "train_encounters",
            "eval_encounters",
            "train_patients",
            "eval_patients",
            "transformed_features",
            "eval_prevalence",
            "roc_auc",
            "average_precision",
            "brier_score",
            "fit_evaluation_seconds",
        ],
        "rows": 5,
    },
    "notebook07_patient_bootstrap_summary": {
        "columns": [
            "metric",
            "point_estimate",
            "bootstrap_mean",
            "bootstrap_std",
            "ci_2.5%",
            "ci_97.5%",
        ],
        "rows": 3,
    },
    "notebook07_responsible_evaluation_summary": {
        "columns": [
            "domain",
            "result",
            "estimate",
            "interpretation",
        ],
        "rows": 16,
    },
    "notebook07_age_subgroup_performance": {
        "columns": SUBGROUP_PERFORMANCE_COLUMNS,
        "rows": 10,
    },
    "notebook07_gender_subgroup_performance": {
        "columns": SUBGROUP_PERFORMANCE_COLUMNS,
        "rows": 3,
    },
    "notebook07_race_subgroup_performance": {
        "columns": SUBGROUP_PERFORMANCE_COLUMNS,
        "rows": 6,
    },
    "notebook07_fairness_contrast_bootstrap": {
        "columns": [
            "contrast",
            "metric",
            "point_difference",
            "bootstrap_mean",
            "bootstrap_std",
            "ci_2.5%",
            "ci_97.5%",
            "ci_includes_zero",
        ],
        "rows": 12,
    },
    "notebook07_subgroup_disparity_summary": {
        "columns": [
            "attribute",
            "metric",
            "minimum_group",
            "minimum_value",
            "maximum_group",
            "maximum_value",
            "absolute_range",
            "groups_compared",
        ],
        "rows": 15,
    },
}


@st.cache_data(show_spinner=False)
def load_hgb_report(report_name: str) -> pd.DataFrame:
    """Load an approved aggregate HGB development-evaluation report."""

    if report_name not in APPROVED_HGB_REPORTS:
        raise ValueError(
            f"HGB report '{report_name}' is not approved."
        )

    path = MODEL_EXPORT_DIR / f"{report_name}.csv"

    if not path.is_file():
        raise FileNotFoundError(
            f"Required HGB report is missing: {path}"
        )

    dataframe = pd.read_csv(path)

    contract = APPROVED_HGB_REPORTS[report_name]

    if list(dataframe.columns) != contract["columns"]:
        raise ValueError(
            f"Unexpected HGB report schema: {report_name}"
        )

    if len(dataframe) != contract["rows"]:
        raise ValueError(
            f"Unexpected HGB report row count: {report_name}"
        )

    is_detailed_subgroup = report_name in {
        "notebook07_age_subgroup_performance",
        "notebook07_gender_subgroup_performance",
        "notebook07_race_subgroup_performance",
    }

    if not is_detailed_subgroup and dataframe.isna().any().any():
        raise ValueError(
            f"Missing data in HGB report: {report_name}"
        )

    if is_detailed_subgroup:
        if dataframe[
            [
                "subgroup_column",
                "subgroup_value",
                "encounters",
                "positives",
                "negatives",
                "sufficient_sample",
            ]
        ].isna().any().any():
            raise ValueError("Missing essential subgroup fields.")

        supported = dataframe.loc[
            dataframe["sufficient_sample"] == True
        ]

        metric_columns = [
            "roc_auc",
            "average_precision",
            "brier_score",
            "sensitivity",
            "specificity",
        ]

        if supported[metric_columns].isna().any().any():
            raise ValueError(
                "Missing performance metrics in supported subgroups."
            )

        if int(dataframe["encounters"].sum()) != 86547:
            raise ValueError("Subgroup encounter totals do not reconcile.")

        if int(dataframe["positives"].sum()) != 9677:
            raise ValueError("Subgroup positive totals do not reconcile.")

        if not (
            dataframe["positives"] + dataframe["negatives"]
            == dataframe["encounters"]
        ).all():
            raise ValueError("Subgroup outcome counts do not reconcile.")

        if not (
            dataframe["tn"] + dataframe["fp"]
            + dataframe["fn"] + dataframe["tp"]
            == dataframe["encounters"]
        ).all():
            raise ValueError("Subgroup confusion counts do not reconcile.")

        if not (
            dataframe["tp"] + dataframe["fn"]
            == dataframe["positives"]
        ).all():
            raise ValueError("Subgroup positive counts do not reconcile.")

        if not (
            dataframe["tn"] + dataframe["fp"]
            == dataframe["negatives"]
        ).all():
            raise ValueError("Subgroup negative counts do not reconcile.")

    import numpy as np

    numeric_columns = dataframe.select_dtypes(
        include="number"
    ).columns

    for column in numeric_columns:
        values = dataframe[column].to_numpy(dtype=float)

        # Infinite values are never valid in reporting datasets.
        if np.isinf(values).any():
            raise ValueError(
                f"Infinite values in {report_name}: {column}"
            )

        if is_detailed_subgroup:
            # Missing numeric values are permitted only for
            # insufficient-sample groups and only in performance
            # metrics—not in counts or other essential fields.
            performance_columns = {
                "roc_auc",
                "average_precision",
                "brier_score",
                "sensitivity",
                "specificity",
                "false_positive_rate",
                "precision",
                "npv",
                "balanced_accuracy",
                "f1",
                "predicted_positive_rate",
            }

            missing = dataframe[column].isna()

            if missing.any():
                if column not in performance_columns:
                    raise ValueError(
                        f"Unexpected missing values: {column}"
                    )

                unsupported = (
                    dataframe["sufficient_sample"] == False
                )

                if not (missing <= unsupported).all():
                    raise ValueError(
                        f"Missing values in supported groups: {column}"
                    )

        elif not np.isfinite(values).all():
            raise ValueError(
                f"Non-finite values in {report_name}: {column}"
            )

    if report_name == "notebook07_fold_performance":
        if set(dataframe["fold"]) != {1, 2, 3, 4, 5}:
            raise ValueError("Unexpected validation fold IDs.")

        if int(dataframe["eval_encounters"].sum()) != 86547:
            raise ValueError("Development encounter count mismatch.")

        if int(dataframe["eval_patients"].sum()) != 60790:
            raise ValueError("Development patient count mismatch.")

        for column in [
            "eval_prevalence",
            "roc_auc",
            "average_precision",
            "brier_score",
        ]:
            if not dataframe[column].between(0, 1).all():
                raise ValueError(
                    f"Invalid fold metric: {column}"
                )

    elif report_name == "notebook07_patient_bootstrap_summary":
        expected = {
            "ROC-AUC",
            "Average precision",
            "Brier score",
        }

        if set(dataframe["metric"]) != expected:
            raise ValueError("Unexpected bootstrap metric names.")

        if not (
            (
                dataframe["ci_2.5%"]
                <= dataframe["point_estimate"]
            )
            & (
                dataframe["point_estimate"]
                <= dataframe["ci_97.5%"]
            )
        ).all():
            raise ValueError(
                "Bootstrap point estimate falls outside CI."
            )

    elif report_name == "notebook07_responsible_evaluation_summary":
        if dataframe[["domain", "result"]].duplicated().any():
            raise ValueError("Duplicate responsible-evaluation metrics.")

    elif report_name == "notebook07_subgroup_disparity_summary":
        if set(dataframe["attribute"]) != {
            "gender", "race", "age"
        }:
            raise ValueError("Unexpected subgroup attributes.")

        if len(dataframe) != 15:
            raise ValueError("Unexpected subgroup summary length.")

        if not np.allclose(
            dataframe["absolute_range"],
            dataframe["maximum_value"]
            - dataframe["minimum_value"],
            rtol=0,
            atol=1e-10,
        ):
            raise ValueError(
                "Subgroup disparity ranges do not reconcile."
            )

    elif report_name == "notebook07_fairness_contrast_bootstrap":
        expected_contrasts = {
            "Gender: Female - Male",
            "Race: AfricanAmerican - Caucasian",
            "Adult age: 70+ - 20-49",
        }

        expected_metrics = {
            "roc_auc",
            "sensitivity",
            "false_positive_rate",
            "predicted_positive_rate",
        }

        if set(dataframe["contrast"]) != expected_contrasts:
            raise ValueError("Unexpected subgroup contrast names.")

        for contrast in expected_contrasts:
            subset = dataframe.loc[
                dataframe["contrast"] == contrast
            ]

            if set(subset["metric"]) != expected_metrics:
                raise ValueError("Unexpected contrast metric registry.")

        if not (
            dataframe["ci_2.5%"] <= dataframe["ci_97.5%"]
        ).all():
            raise ValueError("Invalid subgroup confidence intervals.")

        includes_zero = (
            (dataframe["ci_2.5%"] <= 0)
            & (dataframe["ci_97.5%"] >= 0)
        )

        if not (
            includes_zero.to_numpy()
            == dataframe["ci_includes_zero"].to_numpy()
        ).all():
            raise ValueError(
                "Subgroup confidence interval zero flags disagree."
            )

    return dataframe.copy()
