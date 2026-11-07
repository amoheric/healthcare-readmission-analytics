"""Regression tests for the public dashboard's low-volume rate presentation.

Uses only published aggregate exports. No patient-level information.
Run with: python -m unittest discover -s streamlit_app/tests -v
"""
import ast
import sys
import unittest
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "streamlit_app"
sys.path.insert(0, str(APP))
from utils.small_group_presentation import (  # noqa: E402
    MIN_RATE_DENOMINATOR,
    add_display_rate_columns,
)


class RateDisplayTests(unittest.TestCase):
    def load(self, name):
        return pd.read_csv(APP / "data" / "sql_exports" / (name + ".csv"))

    def test_threshold_boundaries_and_no_input_mutation(self):
        data = pd.DataFrame({
            "total_encounters": [0, 1, 19, 29, 30, 100],
            "readmission_rate_pct": [0.0, 0.0, 0.0, 10.0, 20.0, 12.0],
        })
        original = data.copy(deep=True)
        got = add_display_rate_columns(data)
        self.assertEqual(MIN_RATE_DENOMINATOR, 30)
        self.assertEqual(got["rate_displayable"].tolist(), [False]*4 + [True]*2)
        self.assertTrue(got["display_rate_pct"].iloc[:4].isna().all())
        self.assertEqual(got["display_rate_pct"].iloc[4:].tolist(), [20.0, 12.0])
        pd.testing.assert_frame_equal(data, original)

    def test_invalid_count_rejected(self):
        for count in [-1, None]:
            frame = pd.DataFrame({
                "total_encounters": [count],
                "readmission_rate_pct": [10.0],
            })
            with self.assertRaises(ValueError):
                add_display_rate_columns(frame)

    def test_gender_public_export(self):
        source = self.load("readmission_by_gender")
        out = add_display_rate_columns(source)
        self.assertEqual(int(source.total_encounters.sum()), 86547)
        self.assertEqual(int(source.readmitted_30d_encounters.sum()), 9677)
        included = out.loc[out["rate_displayable"], "gender"].tolist()
        self.assertEqual(set(included), {"Female", "Male"})
        small = out.loc[out.gender == "Unknown/Invalid"].iloc[0]
        self.assertEqual(int(small.total_encounters), 1)
        self.assertTrue(pd.isna(small.display_rate_pct))
        # The original aggregate is intentionally not suppressed.
        self.assertEqual(float(source.loc[source.gender=="Unknown/Invalid","readmission_rate_pct"].iloc[0]), 0.0)

    def test_admission_public_export(self):
        source = self.load("readmission_by_admission_type")
        out = add_display_rate_columns(source)
        self.assertEqual(int(source.total_encounters.sum()), 86547)
        self.assertEqual(int(source.readmitted_30d_encounters.sum()), 9677)
        self.assertEqual(int(out.rate_displayable.sum()), 6)
        for category, count in [("Trauma Center", 19), ("Newborn", 10)]:
            row = out.loc[out.admission_type_description == category].iloc[0]
            self.assertEqual(int(row.total_encounters), count)
            self.assertTrue(pd.isna(row.display_rate_pct))
        kept = out.loc[out.rate_displayable]
        self.assertTrue((kept.display_rate_pct == kept.readmission_rate_pct).all())

    def test_updated_pages_parse(self):
        for name in ("1_Patient_Demographics.py", "2_Healthcare_Utilization.py"):
            ast.parse((APP / "pages" / name).read_text(encoding="utf-8"))


class StreamlitPageSmokeTests(unittest.TestCase):
    def test_updated_pages_render_without_exceptions(self):
        from streamlit.testing.v1 import AppTest
        for name in ("1_Patient_Demographics.py", "2_Healthcare_Utilization.py"):
            with self.subTest(page=name):
                report = AppTest.from_file(str(APP / "pages" / name)).run(timeout=45)
                self.assertFalse(
                    list(report.exception),
                    "Streamlit exception when rendering " + name
                    + ": " + str([str(e.message) for e in report.exception])
                )


class RenderedRateContentTests(unittest.TestCase):
    """Verify the data actually passed to chart rendering and shown in tables.

    AppTest does not expose stable first-class chart-data assertions. A spy
    therefore captures Altair chart objects at st.altair_chart's display
    boundary while Streamlit's own AppTest renders the real pages.
    """

    def run_page(self, name):
        from unittest.mock import patch
        import streamlit as st
        from streamlit.testing.v1 import AppTest

        charts = []
        actual_render = st.altair_chart

        def observe_chart(chart, *args, **kwargs):
            charts.append(chart)
            return actual_render(chart, *args, **kwargs)

        with patch.object(st, "altair_chart", side_effect=observe_chart):
            page = AppTest.from_file(str(APP / "pages" / name)).run(timeout=45)

        self.assertFalse(
            list(page.exception),
            "Streamlit page exception: " + str([e.message for e in page.exception]),
        )
        return page, charts

    def assert_chart_encoding(self, chart):
        # This assertion fails if the chart accidentally switches to the
        # original, unmasked readmission_rate_pct column.
        spec = chart.to_dict()
        self.assertEqual(spec["encoding"]["x"]["field"], "display_rate_pct")

    def test_gender_displayed_chart_and_table_exclude_small_rate(self):
        page, charts = self.run_page("1_Patient_Demographics.py")
        # All three tabs execute: age, gender, race.
        self.assertEqual(len(charts), 3)
        gender_chart = charts[1]
        self.assert_chart_encoding(gender_chart)
        self.assertEqual(set(gender_chart.data["gender"]), {"Female", "Male"})
        self.assertFalse(gender_chart.data["display_rate_pct"].isna().any())

        # The public table keeps the source count for reconciliation but
        # must not publish an unreliable rate for the n=1 category.
        displayed_gender = page.dataframe[1].value
        self.assertEqual(len(displayed_gender), 3)
        small = displayed_gender.loc[
            displayed_gender["Category"] == "Unknown/Invalid"
        ].iloc[0]
        self.assertEqual(int(small["Encounters"]), 1)
        self.assertTrue(pd.isna(small["Rate (%)"]))
        self.assertEqual(small["Caution"], "Rate not displayed (n < 30)")

    def test_admission_displayed_chart_and_table_exclude_small_rates(self):
        page, charts = self.run_page("2_Healthcare_Utilization.py")
        # Admission tab's bar chart is the first chart in the page.
        self.assertGreaterEqual(len(charts), 1)
        admission_chart = charts[0]
        self.assert_chart_encoding(admission_chart)
        self.assertEqual(len(admission_chart.data), 6)
        categories = set(admission_chart.data["admission_type_description"])
        self.assertNotIn("Trauma Center", categories)
        self.assertNotIn("Newborn", categories)
        self.assertFalse(admission_chart.data["display_rate_pct"].isna().any())

        displayed_admissions = page.dataframe[0].value
        self.assertEqual(len(displayed_admissions), 8)
        for category, count in (("Trauma Center", 19), ("Newborn", 10)):
            small = displayed_admissions.loc[
                displayed_admissions["Admission Type"] == category
            ].iloc[0]
            self.assertEqual(int(small["Encounters"]), count)
            self.assertTrue(pd.isna(small["Rate (%)"]))
            self.assertEqual(
                small["Interpretation"], "Rate not displayed (n < 30)"
            )


if __name__ == "__main__":
    unittest.main()
