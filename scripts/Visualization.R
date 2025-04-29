# install.packages("ggplot2")
# import packages
library(ggplot2)

# read data
data <- read.csv("401k.csv")

# altered graph of distribution from PSet 1, switching net total assets for total wealth
p401_density_plot <- ggplot(data, aes(x = tw, fill = as.factor(p401))) +
  geom_density(alpha = 0.5) +
  labs(title = "Distribution of Total Wealth by 401(k) Participation",
       x = "Total Wealth", y = "Density", fill = "401(k) Participation") +
  theme_minimal()

p401_density_plot
