# 03_ml_model.R ---------------------------------------------------------------
# PURPOSE
#   Benchmark six algorithms on household wealth (tw) and report both
#   train- and test-set RMSE.
#   Algorithms: OLS, OLS+ints, Lasso, Random-Forest, Neural-Net, **XGBoost**.
# -----------------------------------------------------------------------------


# ---- 0 · PACKAGES ------------------------------------------------------------
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(
  tidyverse, ranger, glmnet, caret, nnet, recipes, xgboost, here
)

set.seed(2025)   # reproducibility


# ---- 1 · DATA ----------------------------------------------------------------
clean_path <- here("data", "data_clean.rds")

if (file.exists(clean_path)) {
  df <- readRDS(clean_path)
} else {
  message("[WARN] data_clean.rds not found – reading raw CSV …")
  df <- read_csv(here("data", "401k.csv"), show_col_types = FALSE)
}

df <- df %>%
  mutate(
    tw   = as.numeric(tw),
    p401 = as.numeric(p401)
  ) %>%
  drop_na(tw, p401)


# ---- 2 · TRAIN / TEST SPLIT --------------------------------------------------
train_idx <- sample(nrow(df), 0.8 * nrow(df))
train     <- df[train_idx, ]
test      <- df[-train_idx, ]

xvars <- setdiff(names(df), "tw")   # predictors = all but outcome

rmse <- \(y, yhat) sqrt(mean((y - yhat)^2))


# -----------------------------------------------------------------------------#
# 3 · OLS (additive)                                                           #
# -----------------------------------------------------------------------------#
ols1 <- lm(tw ~ ., data = train[, c("tw", xvars)])
rmse1_tr <- rmse(train$tw, predict(ols1, train))
rmse1_te <- rmse(test$tw,  predict(ols1, test))


# -----------------------------------------------------------------------------#
# 4 · OLS + two interactions                                                   #
# -----------------------------------------------------------------------------#
ols2 <- lm(tw ~ . + p401:age + p401:inc, data = train[, c("tw", xvars)])
rmse2_tr <- rmse(train$tw, predict(ols2, train))
rmse2_te <- rmse(test$tw,  predict(ols2, test))


# -----------------------------------------------------------------------------#
# 5 · LASSO (all 2-way interactions)                                           #
# -----------------------------------------------------------------------------#
mm <- model.matrix(~ (. - tw)^2, data = df)[, -1]
las_cv <- cv.glmnet(mm[train_idx, ], train$tw, alpha = 1, nfolds = 10)

pred_las_tr <- predict(las_cv, mm[train_idx, ], s = "lambda.min")
pred_las_te <- predict(las_cv, mm[-train_idx, ], s = "lambda.min")

rmse3_tr <- rmse(train$tw, pred_las_tr)
rmse3_te <- rmse(test$tw,  pred_las_te)


# -----------------------------------------------------------------------------#
# 6 · RANDOM-FOREST                                                            #
# -----------------------------------------------------------------------------#
grid <- crossing(
  mtry          = c(floor(sqrt(length(xvars))), floor(length(xvars) / 3)),
  min_node_size = c(5, 10)
)

best <- grid %>%
  mutate(oob = pmap_dbl(list(mtry, min_node_size), \(m, n)
                        ranger(tw ~ ., data = train[, c("tw", xvars)],
                               num.trees = 1000, mtry = m, min.node.size = n,
                               oob.error = TRUE, save.memory = TRUE,
                               write.forest = FALSE, seed = 2025)$prediction.error
  )) %>%
  slice_min(oob, n = 1)

rf <- ranger(
  tw ~ ., data = train[, c("tw", xvars)],
  num.trees = 1000,
  mtry = best$mtry,
  min.node.size = best$min_node_size,
  importance = "permutation",
  seed = 2025
)

pred_rf_tr <- predict(rf, train[xvars])$predictions
pred_rf_te <- predict(rf, test [xvars])$predictions

rmse_rf_tr <- rmse(train$tw, pred_rf_tr)
rmse_rf_te <- rmse(test$tw,  pred_rf_te)


# -----------------------------------------------------------------------------#
# 7 · NEURAL-NET (caret + nnet)                                                #
# -----------------------------------------------------------------------------#
rec <- recipe(tw ~ ., data = train[, c("tw", xvars)]) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_zv(all_predictors()) %>%
  step_center(all_numeric_predictors()) %>%
  step_scale(all_numeric_predictors())

rec_prep <- prep(rec, training = train, retain = TRUE)
x_train  <- bake(rec_prep, train) %>% select(-tw)
x_test   <- bake(rec_prep, test ) %>% select(-tw)

nn_grid <- expand.grid(size = c(3, 5, 7), decay = c(0, 1e-4, 1e-3))
ctrl    <- trainControl(method = "cv", number = 5)

set.seed(2025)
nn <- train(
  x = x_train, y = train$tw,
  method = "nnet", tuneGrid = nn_grid, trControl = ctrl,
  linout = TRUE, trace = FALSE, maxit = 500
)

pred_nn_tr <- predict(nn, x_train)
pred_nn_te <- predict(nn, x_test)

rmse_nn_tr <- rmse(train$tw, pred_nn_tr)
rmse_nn_te <- rmse(test$tw,  pred_nn_te)


# -----------------------------------------------------------------------------#
# 8 · XGBOOST (gradient-boosted trees)                                         #
# -----------------------------------------------------------------------------#
mm_xgb <- model.matrix(~ . - 1, data = df[, xvars])  # sparse matrix

dtrain <- xgb.DMatrix(mm_xgb[train_idx, ], label = train$tw)
dtest  <- xgb.DMatrix(mm_xgb[-train_idx, ],  label = test$tw)

params <- list(
  objective = "reg:squarederror",
  eval_metric = "rmse",
  eta = 0.05,
  max_depth = 6,
  subsample = 0.8,
  colsample_bytree = 0.8,
  min_child_weight = 1
)

set.seed(2025)
cv <- xgb.cv(
  params = params, data = dtrain,
  nround = 2000, nfold = 5,
  early_stopping_rounds = 50,
  verbose = 0
)

best_rounds <- cv$best_iteration
xgb_fit <- xgb.train(
  params = params, data = dtrain,
  nround = best_rounds, verbose = 0
)

pred_xgb_tr <- predict(xgb_fit, dtrain)
pred_xgb_te <- predict(xgb_fit, dtest)

rmse_xgb_tr <- rmse(train$tw, pred_xgb_tr)
rmse_xgb_te <- rmse(test$tw,  pred_xgb_te)


# -----------------------------------------------------------------------------#
# 9 · PERFORMANCE TABLE                                                        #
# -----------------------------------------------------------------------------#
perf <- tibble(
  Model      = c("OLS-add", "OLS+ints", "Lasso",
                 "RF", "NN", "XGBoost"),
  Train_RMSE = c(rmse1_tr, rmse2_tr, rmse3_tr,
                 rmse_rf_tr, rmse_nn_tr, rmse_xgb_tr),
  Test_RMSE  = c(rmse1_te, rmse2_te, rmse3_te,
                 rmse_rf_te, rmse_nn_te, rmse_xgb_te)
)

print(perf)


# ---- 10 · SAVE ---------------------------------------------------------------
out_dir <- here("outputs")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

write_csv(perf, file.path(out_dir, "model_performance_train_test.csv"))
saveRDS(list(
  ols_add = ols1,
  ols_int = ols2,
  lasso   = las_cv,
  rf      = rf,
  nn      = nn,
  xgb     = xgb_fit
), file.path(out_dir, "all_models.rds"))

xgb.save(xgb_fit, file.path(out_dir, "xgboost_model.json"))

# ----------------------------------------------------------------------------- 
# End of 03_ml_model.R
