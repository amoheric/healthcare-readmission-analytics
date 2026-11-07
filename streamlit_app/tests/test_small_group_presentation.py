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


if __name__ == "__main__":
    unittest.main()
