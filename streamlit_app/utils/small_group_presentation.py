"""Presentation-only guard for low-denominator descriptive subgroup rates.

This is NOT statistical inference, anonymization, or disclosure control.
Approved aggregate exports remain unchanged and may reveal small counts.
"""

import pandas as pd


MIN_RATE_DENOMINATOR = 30


def add_display_rate_columns(frame: pd.DataFrame) -> pd.DataFrame:
    """Return a copy with rate display masked when a subgroup has n < 30."""
    result = frame.copy()
    counts = pd.to_numeric(result["total_encounters"], errors="raise")
    rates = pd.to_numeric(result["readmission_rate_pct"], errors="raise")
    if counts.isna().any() or (counts < 0).any():
        raise ValueError("Invalid subgroup encounter counts")
    result["rate_displayable"] = counts >= MIN_RATE_DENOMINATOR
    result["display_rate_pct"] = rates.where(result["rate_displayable"])
    return result
