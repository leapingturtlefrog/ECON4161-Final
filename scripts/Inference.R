# Variables:
# p401      : participation in 401(k)
# e401      : eligibility for 401(k)
# a401      : 401(k) assets
# tw        : total wealth (in US $)
# tfa       : financial assets (in US $)
# net_tfa   : net financial assets (in US $)
# nifa      : non-401k financial assets (in US $)
# net_nifa  : net non-401k financial assets
# net_n401  : net non-401(k) assets (in US $)
# ira       : individual retirement account (IRA)
# inc       : income (in US $)
# age       : age
# fsize     : family size
# marr      : married
# pira      : participation in IRA
# db        : defined benefit pension
# hown      : home owner
# educ      : education (in years)
# male      : male
# twoearn   : two earners
# nohs, hs, smcol, col : dummies for education: no high-school, high-school, some
# college, college
# hmort     : home mortage (in US $)
# hequity   : home equity (in US $)
# hval      : home value (in US $)


# install.packages("AER")
# Load required package
library(AER)

data <- read.csv("401k.csv")

# 2SLS formula using manual interaction terms (Formula apparently would work)
iv_formula <- tw ~ p401 + a401 + tfa + net_tfa + nifa + net_nifa + net_n401 +
  ira + inc + age + fsize + marr + pira + db + hown + educ + male + twoearn +
  hmort + hequity + hval + 
  p401:e401 + p401:a401 + p401:tfa + p401:net_tfa + p401:nifa + p401:net_nifa + 
  p401:net_n401 + p401:ira + p401:inc + p401:age + p401:fsize + p401:marr + 
  p401:pira + p401:db + p401:hown + p401:educ + p401:male + p401:twoearn + 
  p401:hmort + p401:hequity + p401:hval + 
  a401:e401 + e401 + a401 + tfa + net_tfa + nifa + net_nifa + net_n401 +
  ira + inc + age + fsize + marr + pira + db + hown + educ + male + twoearn +
  hmort + hequity + hval |
  e401 + a401 + tfa + net_tfa + nifa + net_nifa + net_n401 +
  ira + inc + age + fsize + marr + pira + db + hown + educ + male + twoearn +
  hmort + hequity + hval + 
  e401:a401 + e401:tfa + e401:net_tfa + e401:nifa + e401:net_nifa + 
  e401:net_n401 + e401:ira + e401:inc + e401:age + e401:fsize + e401:marr + 
  e401:pira + e401:db + e401:hown + e401:educ + e401:male + e401:twoearn + 
  e401:hmort + e401:hequity + e401:hval

# ivreg for 2SLS
iv_model <- ivreg(iv_formula, data = data)

# Summary of the model
summary(iv_model)

# Check F-stat (Yes they are fine)
summary(iv_model, diagnostics = TRUE)
