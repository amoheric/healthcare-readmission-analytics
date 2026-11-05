# Small-category display policy — November 2026

**Purpose:** prevent misleading percentages from very low-denominator subgroups in descriptive charts. This is a **communication convention**, not privacy suppression, de-identification, statistical confidence, or compliance certification.

## Source and denominator

The reporting population is the **C0 development cohort** (86,547 encounters, 9,677 recorded readmissions within 30 days); it is distinct from the revised C2 model-evaluation population.

The source is the historical [UCI Diabetes 130-US Hospitals dataset](https://doi.org/10.24432/C5230J), published under CC BY 4.0. UCI states that patient age, gender and race are potentially sensitive; aggregation does **not** remove all privacy risk.

## Rule for rate presentation

- For categories with **fewer than 30 encounters**, omit their **rate estimate** from comparative charts and tables; label **“Rate not displayed (n < 30)”**.
- Preserve unmodified source aggregates, row totals and data contracts for numerical reconciliation. This is **not an attempt to conceal** the small counts.
- Continue to flag groups with **fewer than 100 encounters or fewer than 20 observed outcomes** as potentially unstable even when the rate remains visible.
- The cutoff of 30 is a pragmatic visualization convention, **not** a validated variance threshold, privacy safe harbor or an endorsement of comparisons involving n ≥ 30.
- A formal disclosure-control policy, if required, must consider complementary suppression, multiple linked aggregates, data provenance and jurisdictional requirements. Hiding isolated percentages while publishing their counts is **not** disclosure protection.

## Specific categories

| Public export | Category | Encounters | Readmissions | Rate display |
| --- | --- | ---: | ---: | --- |
| Gender | Unknown/Invalid | 1 | 0 | Omit rate; display caution |
| Admission type | Trauma Center | 19 | 0 | Omit rate; display caution |
| Admission type | Newborn | 10 | 1 | Omit rate; display caution |

The full underlying derived CSV exports remain available to support reproducibility and may allow these rates to be calculated. Do **not** describe this change as preventing reconstruction, achieving anonymization or passing a formal privacy assessment.

## Implementation

- **Streamlit:** the draft branch applies the same denominator-based display rule in the demographics and admission-type views while retaining the approved aggregate exports. Code and display should be tested after deployment before final sign-off.
- **Power BI:** the PBIX binary must be edited in Power BI Desktop. Apply a *visual-level* filter of **total_encounters ≥ 30** to the Gender and Admission Type rate charts and add a clear note that low-volume rate categories are not charted. This should not change the overall cohort KPI or underlying view totals. Verify after editing and recapture a clean screenshot.
- **Older screenshots:** an existing screenshot can still show rates for these categories. Do not claim the Power BI change is applied until the actual PBIX and new screenshot have been inspected.

## Release decision

The public portfolio may be described as **retrospective educational/research work with explicit low-sample and privacy limitations**. It is **not** clinically deployable or certified for sensitive-data disclosure. This policy resolves a specific *misinterpretation* issue; formal privacy review remains separate.
