PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_demographics.csv"
OUT = PatientDemo
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_microbial_resistance.csv"
OUT = Resistance
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_cohort.csv"
OUT = Labculture
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_prior_med.csv"
OUT = Prio_Med
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_antibiotic_class_exposure.csv"
OUT = Antibiotic_Expos
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_labs.csv"
OUT = Labreport
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;
PROC IMPORT DATAFILE = "C:/Users/parek/Downloads/microbiology_cultures_priorprocedures.csv"
OUT = PriorProc
DBMS = CSV
REPLACE;
GETNAMES = YES;
RUN;

DATA cohort_clean;
SET Labculture;
IF susceptibility = "Resistant" THEN resistant = 1;
ELSE IF susceptibility = "Susceptible" THEN resistant = 0;
ELSE resistant = .;
RUN;  

DATA cohort_clean;
SET cohort_clean;
WHERE resistant IN (0,1);
RUN;

PROC SORT DATA=cohort_clean;
BY order_proc_id_coded organism antibiotic;
RUN; 
 
PROC SQL;
CREATE TABLE cohort_unique AS
SELECT
    anon_id,
    pat_enc_csn_id_coded,
    order_proc_id_coded,
    organism,
    antibiotic,
    MAX(resistant) AS resistant
FROM cohort_clean
GROUP BY anon_id, pat_enc_csn_id_coded, order_proc_id_coded, organism, antibiotic;
QUIT;
DATA cohort_unique;
SET cohort_unique;
IF SUBSTR(organism,1,3) = 'ZZZ'
THEN organism = SUBSTR(organism,4);
RUN;

PROC SQL;
CREATE TABLE demo AS
SELECT DISTINCT anon_id, age, gender
FROM PatientDemo;
QUIT;

PROC SQL;
CREATE TABLE analysis_base AS
SELECT a.*, b.age, b.gender
FROM cohort_unique a
LEFT JOIN demo b
ON a.anon_id = b.anon_id;
QUIT;

PROC SQL;
CREATE TABLE abx AS
SELECT
anon_id,
pat_enc_csn_id_coded,
order_proc_id_coded,
COUNT(*) AS prior_abx_count
FROM Antibiotic_Expos
WHERE time_to_culturetime BETWEEN -90 AND 0
GROUP BY anon_id, pat_enc_csn_id_coded, order_proc_id_coded;
QUIT;

PROC SQL;
CREATE TABLE analysis_full AS
SELECT a.*, b.prior_abx_count
FROM analysis_base a
LEFT JOIN abx b
ON a.order_proc_id_coded = b.order_proc_id_coded;
QUIT;

PROC CONTENTS DATA = analysis_full;
RUN;

/* Filter OUT intrinsically resistant combos 
   Focus on where resistance VARIES - more interesting clinically */
PROC SQL;
CREATE TABLE variable_resistance AS
SELECT
    organism,
    antibiotic,
    COUNT(*) AS total_tests,
    SUM(resistant) AS resistant_tests,
    ROUND((SUM(resistant)/COUNT(*))*100, 2) AS resistance_rate_pct
FROM analysis_full
GROUP BY organism, antibiotic
HAVING total_tests >= 30
    AND resistance_rate_pct < 100  /* Exclude intrinsic */
    AND resistance_rate_pct > 0    /* Exclude always susceptible */
ORDER BY resistance_rate_pct DESC;
QUIT;

PROC PRINT DATA=variable_resistance (OBS=20) NOOBS LABEL;
TITLE "Clinically Meaningful Variable Resistance Rates (excl. intrinsic)";
LABEL resistance_rate_pct = "Resistance Rate (%)"
      total_tests = "Total Tests"
      resistant_tests = "Resistant Count";
RUN;

PROC FREQ DATA=analysis_full;
TABLES age * resistant
/ CHISQ
NOROW
NOCOL
NOPERCENT;
WHERE resistant IN (0,1)
AND age IS NOT NULL;
TITLE "Step 2: Resistance Rate by Age Group";
RUN;

PROC FREQ DATA = analysis_full;
TABLES gender * resistant
/ CHISQ
NOROW
NOCOL
NOPERCENT;
WHERE resistant IN (0,1)
AND age is NOT NULL;
TITLE " Resistance Rate by Gender";
RUN;
/* Build antibiotic class flags */
PROC SQL;
CREATE TABLE abx_class_flags AS
SELECT
anon_id,
pat_enc_csn_id_coded,
order_proc_id_coded,

/* Beta Lactam */
MAX(CASE WHEN antibiotic_class = 'Beta Lactam'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_betalactam,

/* Fluoroquinolone */
MAX(CASE WHEN antibiotic_class = 'Fluoroquinolone'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_fluoroquinolone,

/* Macrolide Lincosamide */
MAX(CASE WHEN antibiotic_class = 'Macrolide Lincosamide'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_macrolide,

/* Glycopeptide - Vancomycin class */
MAX(CASE WHEN antibiotic_class = 'Glycopeptide'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_glycopeptide,

/* Aminoglycoside */
MAX(CASE WHEN antibiotic_class = 'Aminoglycoside'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_aminoglycoside,

/* Combination Antibiotic */
MAX(CASE WHEN antibiotic_class = 'Combination Antibiotic'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_combination,

/* Nitrofuran */
MAX(CASE WHEN antibiotic_class = 'Nitrofuran'
AND time_to_culturetime BETWEEN -90 AND 0
THEN 1 ELSE 0 END) AS prior_nitrofuran

FROM Antibiotic_Expos
GROUP BY anon_id, pat_enc_csn_id_coded, order_proc_id_coded;
QUIT;
PROC SQL;
CREATE TABLE analysis_full AS
SELECT
    a.*,
    COALESCE(b.prior_betalactam, 0)       AS prior_betalactam,
    COALESCE(b.prior_fluoroquinolone, 0)  AS prior_fluoroquinolone,
    COALESCE(b.prior_macrolide, 0)        AS prior_macrolide,
    COALESCE(b.prior_glycopeptide, 0)     AS prior_glycopeptide,
    COALESCE(b.prior_aminoglycoside, 0)   AS prior_aminoglycoside,
    COALESCE(b.prior_combination, 0)      AS prior_combination,
    COALESCE(b.prior_nitrofuran, 0)       AS prior_nitrofuran
FROM analysis_full a
LEFT JOIN abx_class_flags b
ON  a.anon_id              = b.anon_id
AND a.pat_enc_csn_id_coded = b.pat_enc_csn_id_coded
AND a.order_proc_id_coded  = b.order_proc_id_coded;
QUIT;
PROC MEANS DATA=analysis_full 
    N NMISS SUM MEAN MAXDEC=3;
VAR prior_betalactam prior_fluoroquinolone 
    prior_macrolide prior_glycopeptide
    prior_aminoglycoside prior_combination
    prior_nitrofuran;
TITLE "Step 4: Antibiotic Class Flag Verification";
RUN;
PROC FREQ DATA=analysis_full;
    TABLES prior_betalactam * resistant
    / CHISQ RELRISK RISKDIFF NOROW NOCOL NOPERCENT;
    WHERE resistant IN (0,1);
TITLE "Prior Beta Lactam Exposure vs Resistance";
RUN;
PROC FREQ DATA=analysis_full;
    TABLES prior_fluoroquinolone * resistant
    / CHISQ RELRISK RISKDIFF NOROW NOCOL NOPERCENT;
    WHERE resistant IN (0,1);
TITLE "Prior Fluoroquinolone Exposure vs Resistance";
RUN;
PROC FREQ DATA=analysis_full;
    TABLES prior_macrolide * resistant
    / CHISQ RELRISK RISKDIFF NOROW NOCOL NOPERCENT;
    WHERE resistant IN (0,1);
TITLE "Prior Macrolide Exposure vs Resistance";
RUN;
PROC FREQ DATA=analysis_full;
    TABLES prior_glycopeptide * resistant
    / CHISQ RELRISK RISKDIFF NOROW NOCOL NOPERCENT;
    WHERE resistant IN (0,1);
TITLE "Prior Glycopeptide Exposure vs Resistance";
RUN;
PROC FREQ DATA=analysis_full;
    TABLES prior_aminoglycoside * resistant
    / CHISQ RELRISK RISKDIFF NOROW NOCOL NOPERCENT;
    WHERE resistant IN (0,1);
TITLE "Prior Aminoglycoside Exposure vs Resistance";
RUN;
/* Build a clean summary comparing all classes */
PROC SQL;
CREATE TABLE class_summary AS
SELECT 
    'Beta Lactam' AS antibiotic_class,
    COUNT(*) AS total,
    SUM(CASE WHEN prior_betalactam = 1 
             AND resistant = 1 THEN 1 ELSE 0 END) AS exposed_resistant,
    SUM(CASE WHEN prior_betalactam = 1 THEN 1 ELSE 0 END) AS total_exposed,
    ROUND((SUM(CASE WHEN prior_betalactam = 1 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_betalactam = 1 THEN 1 ELSE 0 END))*100,2) 
               AS resistance_rate_exposed,
    ROUND((SUM(CASE WHEN prior_betalactam = 0 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_betalactam = 0 THEN 1 ELSE 0 END))*100,2) 
               AS resistance_rate_unexposed
FROM analysis_full WHERE resistant IN (0,1)

UNION ALL

SELECT 
    'Fluoroquinolone',
    COUNT(*),
    SUM(CASE WHEN prior_fluoroquinolone = 1 AND resistant = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN prior_fluoroquinolone = 1 THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN prior_fluoroquinolone = 1 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_fluoroquinolone = 1 THEN 1 ELSE 0 END))*100,2),
    ROUND((SUM(CASE WHEN prior_fluoroquinolone = 0 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_fluoroquinolone = 0 THEN 1 ELSE 0 END))*100,2)
FROM analysis_full WHERE resistant IN (0,1)

UNION ALL

SELECT 
    'Macrolide Lincosamide',
    COUNT(*),
    SUM(CASE WHEN prior_macrolide = 1 AND resistant = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN prior_macrolide = 1 THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN prior_macrolide = 1 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_macrolide = 1 THEN 1 ELSE 0 END))*100,2),
    ROUND((SUM(CASE WHEN prior_macrolide = 0 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_macrolide = 0 THEN 1 ELSE 0 END))*100,2)
FROM analysis_full WHERE resistant IN (0,1)

UNION ALL

SELECT 
    'Glycopeptide',
    COUNT(*),
    SUM(CASE WHEN prior_glycopeptide = 1 AND resistant = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN prior_glycopeptide = 1 THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN prior_glycopeptide = 1 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_glycopeptide = 1 THEN 1 ELSE 0 END))*100,2),
    ROUND((SUM(CASE WHEN prior_glycopeptide = 0 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_glycopeptide = 0 THEN 1 ELSE 0 END))*100,2)
FROM analysis_full WHERE resistant IN (0,1)

UNION ALL

SELECT 
    'Aminoglycoside',
    COUNT(*),
    SUM(CASE WHEN prior_aminoglycoside = 1 AND resistant = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN prior_aminoglycoside = 1 THEN 1 ELSE 0 END),
    ROUND((SUM(CASE WHEN prior_aminoglycoside = 1 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_aminoglycoside = 1 THEN 1 ELSE 0 END))*100,2),
    ROUND((SUM(CASE WHEN prior_aminoglycoside = 0 
                    AND resistant = 1 THEN 1 ELSE 0 END) /
           SUM(CASE WHEN prior_aminoglycoside = 0 THEN 1 ELSE 0 END))*100,2)
FROM analysis_full WHERE resistant IN (0,1);
QUIT;
DATA class_summary;
SET class_summary;
rate_difference = resistance_rate_exposed - resistance_rate_unexposed;
LABEL 
    antibiotic_class        = "Antibiotic Class"
    resistance_rate_exposed = "Resistance Rate if Exposed (%)"
    resistance_rate_unexposed = "Resistance Rate if Not Exposed (%)"
    rate_difference         = "Difference (%)";
RUN;

PROC SORT DATA=class_summary;
BY DESCENDING rate_difference;
RUN;

PROC PRINT DATA=class_summary NOOBS LABEL;
TITLE "Step 6: Resistance Rates by Prior Antibiotic Class Exposure";
RUN;

PROC PRINT DATA = analysis_full (OBS= 5);
RUN;

DATA analysis_2;
SET analysis_full;
SELECT (age);
WHEN ("18-24 years")  age_num = 1;
WHEN ("25-34 years")  age_num = 2;
WHEN ("35-44 years")  age_num = 3;
WHEN ("45-54 years")  age_num = 4;
WHEN ("55-64 years")  age_num = 5;
WHEN ("65-74 years")  age_num = 6;
WHEN ("75-84 years")  age_num = 7;
WHEN ("85-89 years")  age_num = 8;
WHEN ("90+") age_num = 9;
OTHERWISE age_num = .;
END;
IF resistant NOT IN (0,1) THEN DELETE;
IF age_num = .            THEN DELETE;
IF gender NOT IN ('0','1') THEN DELETE;
RUN;
/* Check row count and variables */
PROC MEANS DATA=analysis_2 
    N NMISS MIN MAX MEAN;
VAR resistant age_num 
    prior_betalactam 
    prior_fluoroquinolone
    prior_macrolide 
    prior_glycopeptide
    prior_aminoglycoside;
TITLE "Variable Check Before Logistic Regression";
RUN;
PROC LOGISTIC DATA=analysis_2 DESCENDING;
CLASS gender (REF='0') / PARAM=REF;
MODEL resistant = age_num 
gender
prior_betalactam
prior_fluoroquinolone
prior_macrolide
prior_glycopeptide
prior_aminoglycoside
/ CLODDS=WALD;
ODDSRATIO age_num;
ODDSRATIO gender;
ODDSRATIO prior_betalactam;
ODDSRATIO prior_fluoroquinolone;
ODDSRATIO prior_macrolide;
ODDSRATIO prior_glycopeptide;
ODDSRATIO prior_aminoglycoside;
TITLE "Full Model: Demographics + Antibiotic Exposure vs Resistance";
RUN;

PROC SQL;
CREATE TABLE mdr_calc AS
SELECT
anon_id,
organism,
COUNT(*) AS ab_tested,
SUM(resistant) AS ab_resistant,
CASE WHEN SUM(resistant) >= 3
THEN 1 ELSE 0 END AS MDR_flag
FROM analysis_2
WHERE resistant IN (0,1)
GROUP BY anon_id, organism
HAVING ab_tested >= 3;
QUIT;

PROC SQL;
CREATE TABLE mdr_summary AS
SELECT
organism,
COUNT(*) AS total_isolates,
SUM(MDR_flag) AS MDR_isolates,
ROUND((SUM(MDR_flag)/COUNT(*))*100, 2) AS MDR_rate_pct
FROM mdr_calc
GROUP BY organism
HAVING total_isolates >= 10
ORDER BY MDR_rate_pct DESC;
QUIT;

PROC PRINT DATA=mdr_summary (OBS=15) NOOBS LABEL;
TITLE "Step 5: Top 15 Organisms by MDR Rate";
LABEL MDR_rate_pct = "MDR Rate (%)"
total_isolates = "Total Isolates"
MDR_isolates = "MDR Isolates";
RUN;


PROC PRINT DATA=PriorProc (OBS=5) NOOBS;
TITLE "First 5 Rows of Prior Procedures";
RUN;
PROC FREQ DATA=PriorProc ORDER=FREQ;
TABLES procedure_description;
TITLE "All Procedure Names and Frequencies";
RUN;
PROC MEANS DATA=PriorProc
MIN MAX MEAN MEDIAN;
VAR procedure_time_to_culturetime;
TITLE "Timing Distribution of Prior Procedures";
RUN;

PROC SQL;
CREATE TABLE analysis_3 AS
SELECT
a.anon_id,
a.pat_enc_csn_id_coded,
a.order_proc_id_coded,
a.organism,
a.antibiotic,
a.resistant,
a.age,
a.gender,
COALESCE(b.prior_betalactam, 0) AS prior_betalactam,
COALESCE(b.prior_fluoroquinolone, 0) AS prior_fluoroquinolone,
COALESCE(b.prior_macrolide, 0) AS prior_macrolide,
COALESCE(b.prior_glycopeptide, 0) AS prior_glycopeptide,
COALESCE(b.prior_aminoglycoside, 0) AS prior_aminoglycoside,
COALESCE(c.prior_cvc, 0) AS prior_cvc,
COALESCE(c.prior_mechvent, 0) AS prior_mechvent,
COALESCE(c.prior_catheter, 0) AS prior_catheter,
COALESCE(c.prior_dialysis, 0) AS prior_dialysis,
COALESCE(c.prior_surgery, 0) AS prior_surgery,
COALESCE(c.prior_pn, 0) AS prior_pn
FROM analysis_base a
LEFT JOIN abx_class_flags b
ON a.anon_id = b.anon_id
AND a.pat_enc_csn_id_coded = b.pat_enc_csn_id_coded
AND a.order_proc_id_coded = b.order_proc_id_coded
LEFT JOIN proc_flags c
ON a.anon_id = c.anon_id
AND a.pat_enc_csn_id_coded = c.pat_enc_csn_id_coded
AND a.order_proc_id_coded = c.order_proc_id_coded;
QUIT;
DATA analysis_3;
SET analysis_3;
SELECT (age);
WHEN ("18-24 years") age_num = 1;
WHEN ("25-34 years") age_num = 2;
WHEN ("35-44 years") age_num = 3;
WHEN ("45-54 years") age_num = 4;
WHEN ("55-64 years") age_num = 5;
WHEN ("65-74 years") age_num = 6;
WHEN ("75-84 years") age_num = 7;
WHEN ("85-89 years") age_num = 8;
WHEN ("90+") age_num = 9;
OTHERWISE age_num = .;
END;
IF resistant NOT IN (0,1) THEN DELETE;
IF age_num = . THEN DELETE;
IF gender NOT IN ('0','1') THEN DELETE;
RUN;
PROC MEANS DATA=analysis_3
N NMISS MEAN SUM MAXDEC=3;
VAR resistant age_num
prior_betalactam prior_fluoroquinolone
prior_macrolide prior_glycopeptide
prior_aminoglycoside
prior_cvc prior_mechvent
prior_catheter prior_dialysis
prior_surgery prior_pn;
TITLE "Analysis 3 Full Variable Check";
RUN;

PROC SQL;
CREATE TABLE proc_summary AS
SELECT
'CVC' AS procedure,
COUNT(*) AS total,
SUM(CASE WHEN prior_cvc = 1
AND resistant = 1 THEN 1 ELSE 0 END) AS exposed_resistant,
SUM(CASE WHEN prior_cvc = 1
THEN 1 ELSE 0 END) AS total_exposed,
ROUND((SUM(CASE WHEN prior_cvc = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_cvc = 1
THEN 1 ELSE 0 END))*100,2) AS rate_exposed,
ROUND((SUM(CASE WHEN prior_cvc = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_cvc = 0
THEN 1 ELSE 0 END))*100,2) AS rate_unexposed
FROM analysis_3 WHERE resistant IN (0,1)

UNION ALL

SELECT 'Mechanical Ventilation',
COUNT(*),
SUM(CASE WHEN prior_mechvent = 1
AND resistant = 1 THEN 1 ELSE 0 END),
SUM(CASE WHEN prior_mechvent = 1
THEN 1 ELSE 0 END),
ROUND((SUM(CASE WHEN prior_mechvent = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_mechvent = 1
THEN 1 ELSE 0 END))*100,2),
ROUND((SUM(CASE WHEN prior_mechvent = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_mechvent = 0
THEN 1 ELSE 0 END))*100,2)
FROM analysis_3 WHERE resistant IN (0,1)

UNION ALL

SELECT 'Urethral Catheter',
COUNT(*),
SUM(CASE WHEN prior_catheter = 1
AND resistant = 1 THEN 1 ELSE 0 END),
SUM(CASE WHEN prior_catheter = 1
THEN 1 ELSE 0 END),
ROUND((SUM(CASE WHEN prior_catheter = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_catheter = 1
THEN 1 ELSE 0 END))*100,2),
ROUND((SUM(CASE WHEN prior_catheter = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_catheter = 0
THEN 1 ELSE 0 END))*100,2)
FROM analysis_3 WHERE resistant IN (0,1)

UNION ALL

SELECT 'Dialysis',
COUNT(*),
SUM(CASE WHEN prior_dialysis = 1
AND resistant = 1 THEN 1 ELSE 0 END),
SUM(CASE WHEN prior_dialysis = 1
THEN 1 ELSE 0 END),
ROUND((SUM(CASE WHEN prior_dialysis = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_dialysis = 1
THEN 1 ELSE 0 END))*100,2),
ROUND((SUM(CASE WHEN prior_dialysis = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_dialysis = 0
THEN 1 ELSE 0 END))*100,2)
FROM analysis_3 WHERE resistant IN (0,1)

UNION ALL

SELECT 'Surgical Procedure',
COUNT(*),
SUM(CASE WHEN prior_surgery = 1
AND resistant = 1 THEN 1 ELSE 0 END),
SUM(CASE WHEN prior_surgery = 1
THEN 1 ELSE 0 END),
ROUND((SUM(CASE WHEN prior_surgery = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_surgery = 1
THEN 1 ELSE 0 END))*100,2),
ROUND((SUM(CASE WHEN prior_surgery = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_surgery = 0
THEN 1 ELSE 0 END))*100,2)
FROM analysis_3 WHERE resistant IN (0,1)

UNION ALL

SELECT 'Parenteral Nutrition',
COUNT(*),
SUM(CASE WHEN prior_pn = 1
AND resistant = 1 THEN 1 ELSE 0 END),
SUM(CASE WHEN prior_pn = 1
THEN 1 ELSE 0 END),
ROUND((SUM(CASE WHEN prior_pn = 1
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_pn = 1
THEN 1 ELSE 0 END))*100,2),
ROUND((SUM(CASE WHEN prior_pn = 0
AND resistant = 1 THEN 1 ELSE 0 END)/
SUM(CASE WHEN prior_pn = 0
THEN 1 ELSE 0 END))*100,2)
FROM analysis_3 WHERE resistant IN (0,1);
QUIT;

DATA proc_summary;
SET proc_summary;
difference = rate_exposed - rate_unexposed;
LABEL
procedure = "Procedure"
rate_exposed = "Resistance if Exposed (%)"
rate_unexposed = "Resistance if Not Exposed (%)"
difference = "Difference (%)";
RUN;

PROC SORT DATA=proc_summary;
BY DESCENDING difference;
RUN;

PROC PRINT DATA=proc_summary NOOBS LABEL;
TITLE "Resistance Rates by Prior Procedure";
RUN;
