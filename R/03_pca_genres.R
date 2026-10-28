# Question 3: how does an algorithm "hear" music?
# PCA on the audio features, then a check of whether human genres form distinct clusters.

source("R/00_setup.R")
library(factoextra)


# PCA ----
# Features are on very different scales (dB, BPM, 0-1), so they are standardised.
pca_res <- prcomp(df_clean[, audio_features], scale. = TRUE)
summary(pca_res)

p_scree <- fviz_eig(pca_res, addlabels = TRUE, ylim = c(0, 50),
                    barfill = "steelblue", barcolor = "black",
                    main = "Scree Plot: Proportion of Variance Explained",
                    xlab = "Principal Components", ylab = "Percentage of Explained Variance") +
  theme_project() +
  theme(plot.title = element_text(face = "bold", size = 22))
save_plot(p_scree, "q3_scree_plot.png")

print(round(pca_res$rotation[, 1:2], 3))


# Genres in the PCA space ----
target_genres <- c("Classical", "Country & Folk", "Pop & Dance", "Rap & Trap", "Electronic")

pca_df <- as_tibble(pca_res$x[, 1:2]) %>%
  mutate(Genre = df_clean$macro_genre) %>%
  filter(Genre %in% target_genres)

p_scatter <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Genre)) +
  geom_point(alpha = 0.3, size = 0.8) +
  stat_ellipse(level = 0.95, linetype = "dashed", linewidth = 1) +
  scale_color_brewer(palette = "Set1") +
  theme_project() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 18)) +
  labs(title = "Reality Check: Human Labels vs. Mathematical Reality",
       subtitle = "95% confidence ellipses of the macro-genres",
       x = "PC1", y = "PC2", color = "Market Segment")
save_plot(p_scatter, "q3_genre_scatter.png")

p_density <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Genre)) +
  geom_density_2d(alpha = 0.5) +
  stat_ellipse(aes(fill = Genre), geom = "polygon", alpha = 0.1) +
  scale_color_brewer(palette = "Set1") +
  scale_fill_brewer(palette = "Set1") +
  theme_project() +
  theme(legend.title = element_text(size = 13, face = "bold"),
        plot.subtitle = element_text(size = 15)) +
  labs(title = "The Reality Check: Genre Clustering",
       subtitle = "If genres occupy unique spaces, the labels are mathematically grounded",
       x = "PC1", y = "PC2")
save_plot(p_density, "q3_genre_clustering.png")
