# Question 1: how is popularity distributed across the catalogue,
# and is it concentrated among a few hits?

source("R/00_setup.R")
library(skimr)
library(ineq)


# Overview ----
glimpse(raw)
skim(raw)
cat("Rows before deduplication:", nrow(raw), "\nRows after deduplication:", nrow(df_clean), "\n")


# Popularity distribution ----
p_hist <- ggplot(df_clean, aes(x = popularity)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  theme_project() +
  labs(title = "Distribution of Track Popularity", x = "Popularity Score", y = "Count")
save_plot(p_hist, "q1_popularity_distribution.png")

cat("Tracks with popularity = 0:", sum(df_clean$popularity == 0), "\n")


# Lorenz curve and Gini index ----
gini_pop <- ineq(df_clean$popularity, type = "Gini")
cat("Gini index:", round(gini_pop, 3), "\n")

lc_pop <- Lc(df_clean$popularity)
lorenz_df <- tibble(cum_tracks = lc_pop$p, cum_popularity = lc_pop$L)

p_lorenz <- ggplot(lorenz_df, aes(x = cum_tracks, y = cum_popularity)) +
  geom_ribbon(aes(ymin = cum_popularity, ymax = cum_tracks), fill = "steelblue", alpha = 0.5) +
  geom_abline(intercept = 0, slope = 1, color = "black", linetype = "dashed", linewidth = 1) +
  geom_line(color = "darkblue", linewidth = 1.2) +
  annotate("text", x = 0.5, y = 0.5, label = "Line of Equality", angle = 28, vjust = -0.5,
           fontface = "italic", size = 9) +
  annotate("text", x = 0.6, y = 0.25, label = "Lorenz Curve", angle = 32, vjust = -0.5,
           fontface = "italic", size = 9, color = "darkblue") +
  scale_x_continuous(labels = percent_format()) +
  scale_y_continuous(labels = percent_format()) +
  theme_project() +
  theme(plot.subtitle = element_text(size = 15, hjust = 0.5)) +
  labs(
    title = "The Lorenz Curve of Track Popularity",
    subtitle = paste("Gini Index =", round(gini_pop, 3)),
    x = "Cumulative Share of Tracks",
    y = "Cumulative Share of Total Popularity"
  )
save_plot(p_lorenz, "q1_lorenz_curve.png")


# Flops vs hits ----
df_status <- df_clean %>%
  mutate(
    commercial_status = case_when(
      popularity == 0 ~ "Flop",
      popularity >= 75 ~ "Hit",
      TRUE ~ "Mid"
    ),
    commercial_status = fct_relevel(commercial_status, "Flop", "Mid", "Hit"),
    duration_sec = duration_ms / 1000
  )

df_status %>%
  group_by(commercial_status) %>%
  summarise(
    count = n(),
    avg_danceability = mean(danceability),
    avg_energy = mean(energy),
    avg_acousticness = mean(acousticness)
  ) %>%
  print()

density_features <- c("danceability", "energy", "loudness", "speechiness",
                      "acousticness", "liveness", "valence")

p_flops <- df_status %>%
  filter(commercial_status != "Mid") %>%
  select(commercial_status, all_of(density_features)) %>%
  pivot_longer(-commercial_status, names_to = "audio_feature", values_to = "value") %>%
  ggplot(aes(x = value, fill = commercial_status)) +
  geom_density(adjust = 1.5, alpha = 0.7, color = "black") +
  facet_wrap(~ audio_feature, scales = "free", ncol = 3) +
  scale_fill_manual(values = c("Hit" = "firebrick2", "Flop" = "forestgreen")) +
  theme_project() +
  theme(strip.text = element_text(face = "bold", size = 10), legend.position = "bottom") +
  labs(title = "The Anatomy of a Flop", subtitle = "Acoustic Feature Distributions",
       x = "Feature Value", y = "Density", fill = "Commercial Status")
save_plot(p_flops, "q1_flops_vs_hits.png", height = 8)


# Duration and tempo ----
df_status %>%
  group_by(commercial_status) %>%
  summarise(
    count = n(),
    min = min(duration_sec),
    q25 = quantile(duration_sec, 0.25),
    median = median(duration_sec),
    mean = mean(duration_sec),
    q75 = quantile(duration_sec, 0.75),
    max = max(duration_sec)
  ) %>%
  mutate(across(where(is.numeric), ~ round(., 2))) %>%
  print()

p_duration <- ggplot(df_status, aes(x = commercial_status, y = duration_sec, fill = commercial_status)) +
  geom_boxplot(outlier.alpha = 0.1) +
  coord_cartesian(ylim = c(0, 500)) +
  theme_project() +
  theme(legend.position = "none") +
  labs(title = "Commercial Status and Duration", x = "Commercial Status", y = "Duration (Seconds)")
save_plot(p_duration, "q1_duration_by_status.png")

p_tempo <- ggplot(df_status, aes(x = commercial_status, y = tempo, fill = commercial_status)) +
  geom_boxplot(outlier.alpha = 0.1) +
  theme_project() +
  theme(legend.position = "none") +
  labs(title = "Commercial Status and Tempo", x = "Commercial Status", y = "Tempo (BPM)")
save_plot(p_tempo, "q1_tempo_by_status.png")


# Explicit vs clean ----
explicit_labels <- c("FALSE" = "Clean", "TRUE" = "Explicit")

p_explicit_features <- df_clean %>%
  select(explicit, all_of(density_features)) %>%
  pivot_longer(-explicit, names_to = "audio_feature", values_to = "value") %>%
  ggplot(aes(x = value, fill = explicit)) +
  geom_density(alpha = 0.8, color = "black") +
  facet_wrap(~ audio_feature, scales = "free", ncol = 3) +
  scale_fill_manual(values = c("FALSE" = "firebrick2", "TRUE" = "forestgreen"), labels = explicit_labels) +
  theme_project() +
  theme(strip.text = element_text(face = "bold", size = 10), legend.position = "bottom") +
  labs(title = "Explicit Content Effect", subtitle = "Acoustic Feature Distributions",
       x = "Feature Value", y = "Density", fill = "Content")
save_plot(p_explicit_features, "q1_explicit_features.png", height = 8)

p_explicit_hist <- ggplot(df_clean, aes(x = popularity, fill = explicit)) +
  geom_histogram(bins = 30, color = "white") +
  facet_wrap(~ explicit, labeller = as_labeller(explicit_labels)) +
  scale_fill_manual(values = c("FALSE" = "steelblue", "TRUE" = "firebrick2")) +
  theme_project() +
  theme(legend.position = "none") +
  labs(title = "Clean vs. Explicit Popularity", x = "Popularity Score", y = "Count")
save_plot(p_explicit_hist, "q1_explicit_popularity_hist.png")

p_explicit_pop <- ggplot(df_clean, aes(x = explicit, y = popularity, fill = explicit)) +
  geom_boxplot(alpha = 0.8, outlier.color = "grey50", outlier.alpha = 0.3) +
  scale_x_discrete(labels = explicit_labels) +
  scale_fill_brewer(palette = "Set1") +
  theme_project() +
  theme(legend.position = "none") +
  labs(title = "Popularity by Content Type", x = "Content", y = "Popularity Score")
save_plot(p_explicit_pop, "q1_explicit_popularity_box.png")
