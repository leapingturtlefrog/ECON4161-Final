################################################################################
############## ECON 4161 Final Project | Table 3 Replication Code ##############
####### Clean Data, Compute Coef Values, and Compare to Table 3 in Paper #######
################################################################################

############################## ENVIRONMENT SETUP ##############################
rm(list=ls())

# Package Setup
library(dplyr)
library(modelsummary)
library(AER)
library(here)

############################## READ IN DATA ##############################
df <- read.csv(here("data", "401k.csv"))

############################## DATA CATEGORICAL VARS ##############################
inc_labels  <- c("<$10K","$10-20K","$20-30K","$30-40K","$40-50K","$50-75K",">$75K")
age_labels  <- c("<30","30-35","36-44","45-54","55+")
df <- df %>%
  mutate(
    inc_cat  = factor(max.col(select(., i1:i7)),  levels = 1:7, labels = inc_labels),
    age_cat  = factor(max.col(select(., a1:a5)),  levels = 1:5, labels = age_labels),
  educ_cat = cut(
    educ,
    breaks = c(-Inf, 11.5, 12.5, 15.5, Inf),
    labels = c("<12","12","13-15",">=16")
  )
  )

############################## INC CATEGORY CLEANING (NEGATIVES) ##############################

# Rows 1658 and 4637 have i1-i7 all set to 0 due to negative income.
# With raw data, this results in 636 <$10k observations, but Table 3 has 638 observations.
# Thus, I assume the i1 creation logic was flawed (or at least inconsistent with the creation of Table 3)
# Therefore, I fix them here by setting their inc_cat to <$10k.
df <- df %>%
  mutate(
    inc_cat = factor(
      case_when(
        inc < 0     ~ inc_labels[1],        # negative incomes --> "<$10K"
        TRUE        ~ as.character(inc_cat)
      ),
      levels = inc_labels
    )
  )

############################## COMPUTE COEFS / REPLICATE TABLE 3 ##############################

# Generalized vars so I can loop thru stuff quickly and cleanly
wealth_vars = c("net_tfa", "net_n401", "tw")
full_covars    <- c("age_cat","inc_cat","fsize",
                    "educ_cat","marr","twoearn","db","pira","hown")
inc_covars     <- c("age_cat","inc","fsize",
                    "educ_cat","marr","twoearn","db","pira","hown")
income_levels <- levels(df$inc_cat)

# Empty results df
results_df <- data.frame(
  Sample = character(),
  N = integer(),
  First_Stage = numeric(),
  net_tfa_OLS = numeric(), net_tfa_IV = numeric(),
  net_n401_OLS = numeric(), net_n401_IV = numeric(),
  tw_OLS = numeric(), tw_IV = numeric(),
  stringsAsFactors = FALSE
)

# Formula builder helper
make_formulas <- function(y, covars, instr_covars) {
  ols_fm <- reformulate(c("p401", covars), response = y)
  iv_fm  <- as.formula(
    paste0(y, " ~ p401 + ", paste(covars, collapse = " + "),
           " | e401 + ", paste(instr_covars, collapse = " + "))
  )
  list(ols = ols_fm, iv = iv_fm)
}

# loop over “Full Sample” plus each income bin
samples <- c("Full Sample", income_levels)
for (s in samples) {
  if (s == "Full Sample"){
    df_sub <- df
    covars <- full_covars
    instr_covars <- full_covars
  } else {
    df_sub <- filter(df, inc_cat == s)
    covars <- inc_covars
    instr_covars <- inc_covars
  }
  Nsub <- nrow(df_sub)
  
  # 1) First‐stage: p401 ~ e401 + controls
  fs_model <- lm(
    reformulate(c("e401", instr_covars), response="p401"),
    data = df_sub
  )
  fs_coef <- round(coef(fs_model)["e401"], 3)
  
  # 2) OLS & IV for each wealth var
  ols_coefs <- iv_coefs <- setNames(numeric(length(wealth_vars)), wealth_vars)
  for(y in wealth_vars){
    formulas <- make_formulas(y, covars, instr_covars)
    ols_model <- lm(formulas$ols, data = df_sub)
    iv_model  <- ivreg(formulas$iv, data = df_sub)
    ols_val <- coef(ols_model)["p401"]
    iv_val  <- coef(iv_model)["p401"]
    
    ols_coefs[y] <- if (abs(ols_val) >= 1) round(ols_val) else round(ols_val, 3)
    iv_coefs[y]  <- if (abs(iv_val)  >= 1) round(iv_val)  else round(iv_val, 3)
  }
  
  # 3) Add Sample to results_df
  results_df <- rbind(
    results_df,
    data.frame(
      Sample       = s,
      N            = Nsub,
      First_Stage   = fs_coef,
      net_tfa_OLS  = ols_coefs["net_tfa"],
      net_tfa_IV   = iv_coefs["net_tfa"],
      net_n401_OLS = ols_coefs["net_n401"],
      net_n401_IV  = iv_coefs["net_n401"],
      tw_OLS       = ols_coefs["tw"],
      tw_IV        = iv_coefs["tw"],
      stringsAsFactors = FALSE
    )
  )
}

############################## PRINT COMPUTED RESULTS ##############################
print('Computed Results (Rounded)')
print(results_df, row.names=FALSE)

############################## COMPARE TO PAPER'S VALUES ##############################

# Expected values (hard-coded from paper)
expected_df <- tribble(
  ~Sample,        ~N,    ~First_Stage, ~net_tfa_OLS, ~net_tfa_IV, ~net_n401_OLS, ~net_n401_IV, ~tw_OLS, ~tw_IV,
  "Full Sample",  9915,     0.697,           14250,             13087,             778,               -355,             10694,       9259,
  "<$10K",         638,      0.711,            9843,              9149,             4093,               3443,             20464,     17224,
  "$10-20K",      1948,      0.650,            5591,              5352,            -759,               -917,              4729,      6138,
  "$20-30K",      2074,      0.627,            7083,              4143,             448,              -2518,              5462,     0.183,
  "$30-40K",      1712,      0.672,           12136,             10273,            1077,               -909,             10683,      4881,
  "$40-50K",      1204,      0.723,           12858,              9980,             500,              -2479,             13470,     13205,
  "$50-75K",      1572,      0.744,           20800,             21920,            1803,                2985,             12881,     12202,
  ">$75K",         767,      0.831,           23103,             24013,           -6735,               -5252,              5514,     10470
)

diff_df <- results_df %>%
  rename_with(~ paste0(.x, "_comp"), -Sample) %>%
  left_join(
    expected_df %>% rename_with(~ paste0(.x, "_exp"), -Sample),
    by = c("Sample")
  )

diff_df <- diff_df %>%
  mutate(
    N_diff           = N_comp            - N_exp,
    First_Stage_diff  = First_Stage_comp  - First_Stage_exp,
    net_tfa_OLS_diff  = net_tfa_OLS_comp  - net_tfa_OLS_exp,
    net_tfa_IV_diff   = net_tfa_IV_comp   - net_tfa_IV_exp,
    net_n401_OLS_diff = net_n401_OLS_comp - net_n401_OLS_exp,
    net_n401_IV_diff  = net_n401_IV_comp  - net_n401_IV_exp,
    tw_OLS_diff       = tw_OLS_comp       - tw_OLS_exp,
    tw_IV_diff        = tw_IV_comp        - tw_IV_exp
  ) %>% select(Sample, ends_with("_diff"))

############################## PRINT COMPARISON DIFFERENCES ##############################
print('Differences (Actual - Expected)')
print(diff_df, row.names=FALSE)

############################## SAVE DIFFERENCES ################################
write.csv(results_df, here("report", "replication_results.csv"), row.names = F)
write.csv(diff_df, here("report", "replication_differences.csv"), row.names = F)
