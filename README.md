# Antibiotic Resistance Analysis — Stanford Healthcare EHR Data (ARMD)
**Author:** Krishna Daxesh Parekh  
**Tools:** SAS (PROC SQL, PROC LOGISTIC, PROC FREQ, PROC MEANS, DATA Step)  
**Data Source:** Antibiotic Resistance Microbiology Dataset (ARMD), Stanford Healthcare, published on Dryad (2025)  
**Citation:** Nateghi Haredasht, Fateme et al. (2025). ARMD Dataset. Dryad. https://doi.org/10.5061/dryad.jq2bvq8kp

---

## Overview

This project conducts a comprehensive statistical analysis of antibiotic resistance patterns using real-world Electronic Health Record (EHR) data from Stanford Healthcare. The analysis combines microbiological culture data with patient demographics, prior antibiotic exposure, and prior medical procedures to identify independent predictors of antibiotic resistance.

The project is structured as a five-step analytical pipeline, progressing from descriptive resistance profiling to multivariable logistic regression and multi-drug resistance (MDR) classification.

---

## Clinical Problem

Antibiotic resistance is a global health emergency. Clinicians selecting empiric antibiotic therapy need to know:
- Which organisms are most resistant and to which drugs?
- Which patients are at highest risk of resistant infections?
- Which prior antibiotic classes drive resistance most strongly?
- Which medical procedures are associated with higher resistance rates?
- Which organisms qualify as multi-drug resistant?

This analysis answers each of these questions using data from 2,119,956 culture-antibiotic observations.

---

## Dataset

| File Used | Purpose |
|-----------|---------|
| microbiology_cultures_cohort.csv | Core culture and susceptibility data |
| microbiology_cultures_demographics.csv | Patient age and gender |
| microbiology_cultures_antibiotic_class_exposure.csv | Prior antibiotic class exposure with timing |
| microbiology_cultures_priorprocedures.csv | Prior medical procedures |
| microbiology_cultures_labs.csv | Laboratory results |
| microbiology_cultures_microbial_resistance.csv | Resistance timeline data |

**Key variables:**
- `resistant` — Binary outcome (1=Resistant, 0=Susceptible)
- `organism` — Identified microorganism
- `antibiotic` — Drug tested
- `age` — Age group bins (HIPAA de-identified)
- `gender` — Binary encoded (0 or 1, unspecified)
- `time_to_culturetime` — Days between exposure and culture order

---

## Analytical Pipeline

```
Step 1 → Resistance Profiling
Step 2 → Demographic Analysis
Step 3 → Antibiotic Class Exposure Analysis
Step 4 → Multivariable Logistic Regression
Step 5 → Multi-Drug Resistance (MDR) Analysis
Step 6 → Prior Procedure Analysis
```

---

## Data Preparation

### Key Decisions
- **Intermediate susceptibility excluded** — only Resistant (1) and Susceptible (0) retained
- **Deduplication** — MAX(resistant) per organism-antibiotic pair per culture order
- **Demographics join** — corrected to join on `anon_id` only, not encounter level, to preserve full population
- **Antibiotic exposure** — restricted to 90-day window prior to culture (clinically validated selection pressure window)
- **Procedure flags** — no time restriction applied (procedures like dialysis represent ongoing clinical state)
- **ZZZ prefix organisms** — standardized using SUBSTR to merge duplicate EHR entries

---

## Results

### Step 1 — Resistance Profiling
**Total observations:** 2,119,956  
**Overall resistance rate:** 17.5%

Top clinically meaningful variable resistance rates (excluding intrinsic resistance):

| Organism | Antibiotic | Total Tests | Resistance Rate |
|----------|------------|-------------|-----------------|
| Achromobacter Xylosoxidans | Aztreonam | 848 | 98% |
| Klebsiella Oxytoca | Ampicillin | 2,370 | 98% |
| Enterobacter Cloacae | Cefuroxime | 562 | 98% |
| Achromobacter Xylosoxidans | Gentamicin | 837 | 96% |
| Achromobacter Xylosoxidans | Amikacin | 780 | 96% |

**Key finding:** Achromobacter xylosoxidans showed near-universal resistance across four antibiotic classes including last-resort aminoglycosides (Amikacin 96%), identifying it as a priority MDR organism for stewardship intervention.

---

### Step 2 — Demographic Analysis

**Age:**
- Chi-square = 660.26, df=8, p<0.0001
- Cramer's V = 0.017 (negligible effect)
- Resistance range: 16.2% (90+) to 18.1% (55-64)
- **Interpretation:** Statistically significant but clinically negligible. Age explains less than 2% of resistance variation.

**Gender:**
- Chi-square = 12100.14, df=1, p<0.0001
- Cramer's V = 0.074 (weak but 4x stronger than age)
- Gender 0: 15.8% resistance | Gender 1: 22.2% resistance
- **Interpretation:** Gender group 1 shows 6.4% higher absolute resistance rate. Strongest demographic predictor.

---

### Step 3 — Antibiotic Class Exposure Analysis

| Antibiotic Class | With Prior Exposure | Without Prior Exposure | Additional Risk |
|-----------------|--------------------|-----------------------|-----------------|
| Macrolide Lincosamide | 24% | 16% | **+8%** |
| Aminoglycoside | 26% | 18% | **+8%** |
| Glycopeptide | 24% | 18% | **+6%** |
| Beta Lactam | 18% | 16% | +2% |
| Fluoroquinolone | 18% | 18% | **0%** |

**Key findings:**
- Macrolide and Aminoglycoside exposure each associated with +8% additional resistance risk despite representing only 12% and 3.4% of total prescriptions respectively
- Fluoroquinolone showed zero additional risk — consistent with resistance saturation given it is the second most prescribed class (18% of all exposures)
- Beta Lactam minimal impact despite being most prescribed class (32.9%) — further evidence of saturation

---

### Step 4 — Multivariable Logistic Regression

**Model:** Binary logistic regression, outcome = P(resistant=1)  
**Sample:** 2,119,956 observations  
**C-statistic:** 0.559

| Predictor | Odds Ratio | 95% CI | Interpretation |
|-----------|-----------|--------|----------------|
| age_num | 0.982 | 0.980-0.984 | Slightly protective per age group |
| gender 1 vs 0 | 1.472 | 1.461-1.484 | 47% higher resistance odds |
| prior_betalactam | 1.018 | 1.010-1.026 | Negligible effect |
| prior_fluoroquinolone | 0.982 | 0.974-0.989 | Slightly protective — saturation confirmed |
| prior_macrolide | 1.465 | 1.449-1.482 | 46.5% higher resistance odds |
| prior_glycopeptide | 1.277 | 1.258-1.296 | 27.7% higher resistance odds |
| prior_aminoglycoside | 1.413 | 1.384-1.442 | 41.3% higher resistance odds |

**Key findings:**
- Prior Macrolide exposure is the strongest antibiotic class predictor (OR=1.465)
- Gender is the strongest overall predictor (OR=1.472)
- Age shows a marginally protective effect (OR=0.982) — contrasting with conventional assumptions, likely reflecting survivor bias and better targeted therapy in elderly inpatients
- Fluoroquinolone OR<1.0 confirms resistance saturation — endemic regardless of exposure
- C-statistic 0.559 indicates demographics and antibiotic exposure alone are insufficient predictors; comorbidities and ward setting would improve model performance

---

### Step 5 — MDR Analysis

MDR defined as: resistant to 3 or more antibiotics per isolate

| Organism | Total Isolates | MDR Isolates | MDR Rate |
|----------|---------------|--------------|----------|
| Chryseobacterium Indologenes | 23 | 23 | 100% |
| Escherichia Coli (CAR) | 15 | 15 | 100% |
| Providencia Rettgeri | 80 | 78 | 98% |
| Proteus Vulgaris | 113 | 110 | 98% |
| Achromobacter Xylosoxidans | 192 | 185 | 96% |
| Morganella Morganii | 542 | 523 | 96% |
| MRSA | 790 | 737 | 94% |
| Serratia Marcescens | 741 | 656 | 88% |
| Enterobacter Cloacae | 1,581 | 1,288 | 82% |
| Klebsiella Aerogenes | 558 | 451 | 80% |

**Key findings:**
- Carbapenem-Resistant E.coli (CAR) at 100% MDR — most dangerous finding; last-resort antibiotics failing; WHO Priority 1 pathogen
- Enterobacter cloacae contributes the highest absolute MDR burden: 1,288 isolates from 1,581 total (82%)
- MRSA 94% MDR across 790 isolates — confirms treatment limited to Vancomycin and Linezolid
- Serratia marcescens 88% MDR across 741 isolates — major hospital-acquired stewardship concern

---

### Step 6 — Prior Procedure Analysis

| Procedure | With Procedure | Without Procedure | Additional Risk | Patients |
|-----------|---------------|-------------------|-----------------|---------|
| Mechanical Ventilation | 26% | 16% | **+10%** | 134,844 |
| CVC | 24% | 16% | **+8%** | 432,960 |
| Dialysis | 26% | 18% | **+8%** | 44,431 |
| Parenteral Nutrition | 24% | 18% | **+6%** | 71,823 |
| Urethral Catheter | 22% | 18% | **+4%** | 192,298 |
| Surgical Procedure | 18% | 18% | **0%** | 563,684 |

**Key findings:**
- Mechanical ventilation associated with the highest additional resistance risk (+10%), consistent with ICU-based MDR organism burden and ventilator-associated pneumonia pathophysiology
- CVC adds +8% risk through biofilm formation and direct bloodstream access
- Surgical procedure shows zero additional risk — short-course prophylactic antibiotics and community organism involvement limit selection pressure
- Parallels antibiotic saturation pattern: most ubiquitous exposures (surgery, fluoroquinolones) show no additional resistance signal

---

## Stewardship Implications

```
1. Restrict Macrolide prescribing
   Biggest modifiable resistance driver (+8%, OR=1.465)
   Stop empiric Azithromycin for viral infections

2. Protect Aminoglycosides
   High impact despite low use (+8%, OR=1.413)
   Reserve strictly for culture-proven need

3. Fluoroquinolone restriction may be too late
   Resistance fully saturated in this population
   Redirect stewardship focus to Macrolides

4. Target ICU and ventilated patients
   Mechanical ventilation adds +10% resistance risk
   Highest yield population for stewardship intervention

5. Urgent surveillance for Carbapenem-Resistant E.coli
   100% MDR rate — no standard treatment options
   Requires immediate infection control escalation
```

---

## Limitations

- Gender encoding does not specify biological sex — directional interpretation not possible
- C-statistic 0.559 indicates model incompleteness — comorbidities, ward setting, and organism-specific factors not included
- Age bins prevent granular age analysis
- Temporal jittering of dates prevents exact collection period determination
- Procedure flags have no time restriction — ongoing procedures (dialysis) vs completed procedures (surgery) treated equally
- Single institution data (Stanford Healthcare) — generalizability to other populations requires validation

---

## Repository Structure

```
├── ARMD_Analysis.sas       — Full SAS code
├── README.md               — This file
└── outputs/
    ├── resistance_table.png
    ├── forest_plot.png
    ├── mdr_table.png
    └── procedure_table.png
```

---

## Skills Demonstrated

- Large-scale EHR data cleaning and transformation in SAS
- Multi-table join architecture with composite keys
- Binary outcome variable engineering
- Antibiotic exposure window definition (90-day clinical standard)
- Multivariable logistic regression with odds ratio interpretation
- Effect size reporting (Cramer's V, C-statistic)
- MDR classification using RETAIN-based accumulation logic
- Clinical interpretation of statistical findings
- Antimicrobial stewardship application of analytical results
