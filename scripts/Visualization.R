# install.packages("ggplot2")
# import packages
library(dplyr)
library(ggplot2)
library(cluster)

# read data
data <- read.csv("401k.csv")

################################################################################
### Distribution from PSet 1, switching net total assets for total wealth
p401_density_plot <- ggplot(data, aes(x = tw, fill = as.factor(p401))) +
  geom_density(alpha = 0.5) +
  labs(title = "Distribution of Total Wealth by 401(k) Participation",
       x = "Total Wealth", y = "Density", fill = "401(k) Participation") +
  theme_minimal()

p401_density_plot

################################################################################
### Clustering
# Select relevant data
vars <- data %>%
  select(p401, a401, tfa, net_tfa, nifa, net_nifa, net_n401, ira, inc, age,
         fsize, marr, pira, db, hown, educ, male, twoearn, hmort, hequity, hval)

# Standardize the numeric variables
vars_scaled <- scale(vars)

# Run k-means clustering (Set to 5)
set.seed(0)
kmeans_result <- kmeans(vars_scaled, centers = 5, nstart = 25)

# PCA for 2D plotting
pca_result <- prcomp(vars_scaled)
pca_data <- as.data.frame(pca_result$x[, 1:2])
pca_data$cluster <- as.factor(kmeans_result$cluster)

# Ploting clusters
cluster_plot <- ggplot(pca_data, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(alpha = 0.7, size = 2) +
  labs(title = "K-means Clustering of Households",
       x = "Principal Component 1",
       y = "Principal Component 2") +
  theme_minimal() +
  scale_color_brewer(palette = "Set1")

cluster_plot

################################################################################
### PCA Variance:
# Calculate variance explained
pve <- (pca_result$sdev)^2 / sum(pca_result$sdev^2)
cum_pve <- cumsum(pve)

# PVE data frame
pve_df <- data.frame(
  PC = factor(1:length(pve)),
  PVE = pve,
  Cumulative_PVE = cum_pve
)

# Plot variance explained
variance_explained_plot <-ggplot(pve_df[1:10, ], aes(x = PC)) +
  geom_line(aes(y = Cumulative_PVE, group = 1), color = "#ff7f0e", linewidth = 1.2) +
  geom_point(aes(y = Cumulative_PVE), color = "#ff7f0e", size = 2) +
  geom_line(aes(y = PVE, group = 2), color = "#1f77b4", linewidth = 1.2) +
  geom_point(aes(y = PVE), color = "#1f77b4", size = 2) +
  labs(
    title = "Proportion of Variance Explained by Principal Components",
    y = "Variance Explained",
    x = "Principal Component"
  ) +
  scale_y_continuous(sec.axis = sec_axis(~ ., name = "Cumulative Variance Explained")) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    axis.title.y.right = element_text(color = "#ff7f0e")
  )

variance_explained_plot

################################################################################
### Heatmap Correlation
# Compute correlation matrix
cor_matrix <- cor(vars, use = "pairwise.complete.obs")

# Mask upper triangle and diagonal (duplicates & perfect correlation)
cor_matrix[lower.tri(cor_matrix, diag = TRUE)] <- NA

# Plot heatmap
corr_heatmap <- heatmap(cor_matrix,
        Colv = NA,
        Rowv = NA,
        scale = "none",
        na.rm = TRUE,
        margins = c(8, 8),
        main = "Correlation Heatmap")


