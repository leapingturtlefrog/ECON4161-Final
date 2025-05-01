# 03_ml_model.R ---------------------------------------------------------------
# PURPOSE: Predict household wealth & estimate the causal effect of 401(k)
#          participation.  We compare three linear baselines with a
#          tuned Random-Forest and a Causal Forest.
# -----------------------------------------------------------------------------


# ---- 0. Packages -------------------------------------------------------------
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(
  tidyverse,    # data wrangling & ggplot2
  ranger,       # fast random forest
  grf,          # causal forest
  glmnet,       # lasso / ridge
  modelsummary, # quick regression tables
  here          # reproducible file paths
)

set.seed(2025)                 # full reproducibility


# ---- 1. Data -----------------------------------------------------------------
clean_path <- here("data", "data_clean.rds")
if (file.exists(clean_path)) {
  df <- readRDS(clean_path)
} else {
  message("[WARN] data_clean.rds not found – reading raw CSV for now …")
  df <- read_csv(here("data", "401k.csv"), show_col_types = FALSE)
}

df <- df %>%                                   # keep relevant vars & types
  mutate(
    tw   = as.numeric(tw),   # outcome
    p401 = as.numeric(p401)  # treatment (0/1)
  ) %>%
  drop_na(tw, p401)

# Simple 80/20 split -----------------------------------------------------------
train_idx <- sample(nrow(df), 0.8 * nrow(df))
train     <- df[train_idx, ]
test      <- df[-train_idx, ]

outcome <- "tw"
treat   <- "p401"
xvars   <- setdiff(names(df), c(outcome, treat))


# ---- 2. Baseline linear models ----------------------------------------------
## (i) Additive OLS
ols1  <- lm(tw ~ p401 + ., data = train)
pred1 <- predict(ols1, newdata = test)
rmse1 <- sqrt(mean((test$tw - pred1)^2))

## (ii) OLS with hand interactions (age & income as examples)
ols2  <- lm(tw ~ p401 * age + p401 * inc + ., data = train)
pred2 <- predict(ols2, newdata = test)
rmse2 <- sqrt(mean((test$tw - pred2)^2))

## (iii) Lasso on two-way interactions (matrix built once for all rows)
mm_full  <- model.matrix(~ p401 + .^2, data = df)[, -1]   # drop intercept
mm_train <- mm_full[train_idx, ]
mm_test  <- mm_full[-train_idx,  ]

lasso <- cv.glmnet(mm_train, train$tw, alpha = 1, nfolds = 10)
pred3 <- predict(lasso, newx = mm_test, s = "lambda.min")
rmse3 <- sqrt(mean((test$tw - pred3)^2))


# ---- 3. Random-Forest hyper-parameter search ---------------------------------
param_grid <- crossing(
  mtry          = c(floor(sqrt(length(xvars))), floor(length(xvars) / 3)),
  min_node_size = c(5, 10)
)

oob_tbl <- param_grid %>%
  mutate(
    oob_mse = pmap_dbl(list(mtry, min_node_size), ~ {
      ranger(
        tw ~ .,
        data          = train %>% select(all_of(c(outcome, xvars))),
        num.trees     = 1000,
        mtry          = ..1,
        min.node.size = ..2,
        seed          = 2025,
        oob.error     = TRUE,
        save.memory   = TRUE,
        write.forest  = FALSE
      )$prediction.error
    })
  )

best_params <- oob_tbl %>% slice_min(oob_mse, n = 1)

# ---- 4. Fit final RF ---------------------------------------------------------
rf_mod <- ranger(
  tw ~ .,
  data          = train %>% select(all_of(c(outcome, xvars))),
  num.trees     = 1000,
  mtry          = best_params$mtry,
  min.node.size = best_params$min_node_size,
  importance    = "permutation",
  seed          = 2025
)

pred_rf <- predict(rf_mod, data = test %>% select(all_of(xvars)))$predictions
rmse_rf <- sqrt(mean((test$tw - pred_rf)^2))
mae_rf  <- mean(abs(test$tw - pred_rf))

perf_tbl <- tibble(
  Model = c("OLS-additive", "OLS+ints", "Lasso", "Random Forest"),
  RMSE  = c(rmse1, rmse2, rmse3, rmse_rf)
)
print(perf_tbl)


# ---- 5. Causal Forest --------------------------------------------------------
Y <- train[[outcome]]
W <- train[[treat]]
X <- train %>%
  select(all_of(xvars)) %>%
  mutate(across(where(is.character), as.factor)) %>%
  as.matrix()

cf_mod <- causal_forest(
  X, Y, W,
  num.trees = 2000,
  honesty   = TRUE,
  seed      = 2025
)

ate_cf <- average_treatment_effect(cf_mod)
print(ate_cf)

# Optional heterogeneity by income quintile -----------------------------------
if ("inc" %in% names(train)) {
  het_tbl <- tibble(
    Income_Q = factor(ntile(train$inc, 5)),
    Tau_Hat  = as.numeric(cf_mod$predictions)
  ) %>%
    group_by(Income_Q) %>%
    summarise(Mean_Effect = mean(Tau_Hat), .groups = "drop")
  print(het_tbl)
}


# ---- 6. Variable Importance --------------------------------------------------
imp <- enframe(rf_mod$variable.importance, name = "Variable", value = "Importance") %>%
  arrange(desc(Importance)) %>%
  slice_head(n = 20)

imp_plot <- ggplot(imp, aes(reorder(Variable, Importance), Importance)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Random-Forest Variable Importance (Top 20)",
    x = NULL, y = "Permutation Importance"
  )


# ---- 7. Save artefacts -------------------------------------------------------
out_dir <- here("outputs")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

ggsave(file.path(out_dir, "var_importance_rf.png"), imp_plot, width = 7, height = 5)

saveRDS(rf_mod, file.path(out_dir, "rf_model.rds"))
saveRDS(cf_mod, file.path(out_dir, "causal_forest_model.rds"))

write_csv(perf_tbl,   file.path(out_dir, "rf_vs_ols_performance.csv"))
write_csv(best_params %>% select(mtry, min_node_size, oob_mse),
          file.path(out_dir, "rf_best_params.csv"))
if (exists("het_tbl")) write_csv(het_tbl, file.path(out_dir, "heterogeneity_income.csv"))

# ----------------------------------------------------------------------------- 
# End of 03_ml_model.R
