# install.packages("ggplot2")
# import packages
library(ggplot2)

# read data
data <- read.csv("401k.csv")

# form graph of distribution from PSet 1
p401_density_plot <- ggplot(data, aes(x = net_tfa, fill = as.factor(p401))) +
  geom_density(alpha = 0.5) +
  labs(title = "Distribution of Net Financial Assets by 401(k) Participation",
       x = "Net Financial Assets", y = "Density", fill = "401(k) Participation") +
  theme_minimal()

p401_density_plot
