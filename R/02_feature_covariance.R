# Question 2: are there standard production rules?
# Correlation between audio features and how it changes across macro-genres.

source("R/00_setup.R")
library(corrplot)


# Correlation matrix ----
cor_matrix <- df_clean %>%
  select(popularity, danceability, energy, loudness, acousticness, instrumentalness, valence, tempo) %>%
  cor(use = "complete.obs")

print(sort(cor_matrix[, "popularity"], decreasing = TRUE))

png(file.path(fig_dir, "q2_correlation_matrix.png"), width = 1500, height = 1500, res = 150)
corrplot(cor_matrix, method = "color", type = "full", tl.col = "black", tl.srt = 45,
         addCoef.col = "black", number.digits = 2, number.cex = 1.1, mar = c(0, 0, 2, 0),
         title = "Correlation of Audio Features")
dev.off()


# Covariance by macro-genre ----
genre_colors <- c(
  "Electronic"         = "#2c3e50",
  "Hip-Hop"            = "#c0392b",
  "Pop & Dance"        = "#e056fd",
  "Mood"               = "#2980b9",
  "Rock & Alternative" = "#8B0A50",
  "Country & Folk"     = "#f1c40f",
  "Latin"              = "#228B22",
  "Jazz & Blues"       = "#d35400",
  "Classical"          = "#1abc9c",
  "Rap & Trap"         = "#9b59b6",
  "Other"              = "#7f8c8d"
)

# Correlation of x and y within each macro-genre, keeping the n strongest
genre_correlations <- function(x, y, strongest = c("positive", "negative"), n = 8) {
  strongest <- match.arg(strongest)
  df_clean %>%
    group_by(macro_genre) %>%
    summarise(r = cor(.data[[x]], .data[[y]], use = "complete.obs")) %>%
    arrange(if (strongest == "positive") desc(r) else r) %>%
    slice(1:n) %>%
    mutate(label_text = paste0("r = ", round(r, 2)))
}

# Restrict the data to those genres and order the facets by r
facet_by_genre <- function(cors) {
  levels_order <- cors$macro_genre
  list(
    data = df_clean %>%
      filter(macro_genre %in% levels_order) %>%
      mutate(macro_genre = factor(macro_genre, levels = levels_order)),
    labels = cors %>% mutate(macro_genre = factor(macro_genre, levels = levels_order))
  )
}


## Energy vs loudness (positive) ----
cor_pos <- genre_correlations("loudness", "energy", "positive")
print(cor_pos)
pos <- facet_by_genre(cor_pos)

p_pos <- ggplot(pos$data, aes(x = loudness, y = energy, color = macro_genre)) +
  geom_point(alpha = 0.2, size = 0.5) +
  geom_smooth(method = "lm", formula = y ~ x, color = "black", linewidth = 0.7, se = FALSE) +
  geom_label(data = pos$labels, aes(x = -Inf, y = Inf, label = label_text),
             hjust = -0.2, vjust = 1.5, inherit.aes = FALSE, fontface = "bold", size = 3.5) +
  facet_wrap(~ macro_genre) +
  scale_color_manual(values = genre_colors) +
  theme_project() +
  theme(legend.position = "none", strip.text = element_text(face = "bold", size = 10)) +
  labs(title = "The Shifting Nature of Audio Physics",
       subtitle = "Positive Covariance: Energy vs. Loudness",
       x = "Loudness (dB)", y = "Energy")
save_plot(p_pos, "q2_energy_vs_loudness.png", height = 8)


## Energy vs acousticness (negative) ----
cor_neg <- genre_correlations("energy", "acousticness", "negative")
print(cor_neg)
neg <- facet_by_genre(cor_neg)

p_neg <- ggplot(neg$data, aes(x = acousticness, y = energy, color = macro_genre)) +
  geom_point(alpha = 0.2, size = 0.5) +
  geom_smooth(method = "lm", formula = y ~ x, color = "black", linewidth = 0.7, se = FALSE) +
  geom_label(data = neg$labels, aes(x = Inf, y = Inf, label = label_text),
             hjust = 1.2, vjust = 1.5, inherit.aes = FALSE, fontface = "bold", size = 3.5) +
  facet_wrap(~ macro_genre) +
  scale_color_manual(values = genre_colors) +
  theme_project() +
  theme(legend.position = "none", strip.text = element_text(face = "bold", size = 10)) +
  labs(title = "The Acoustic Ceiling",
       subtitle = "Negative Covariance: Energy vs. Acousticness",
       x = "Acousticness", y = "Energy")
save_plot(p_neg, "q2_energy_vs_acousticness.png", height = 8)
