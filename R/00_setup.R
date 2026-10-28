# Shared setup: packages, plot theme, data loading and deduplication.
# Every analysis script sources this file. Run the scripts from the repository root.

library(tidyverse)
library(ggthemes)
library(scales)

set.seed(123)

fig_dir <- "figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

save_plot <- function(plot, name, width = 10, height = 6.5) {
  ggsave(file.path(fig_dir, name), plot, width = width, height = height, dpi = 150)
}


# Plot theme ----
theme_project <- function() {
  theme_fivethirtyeight() %+replace%
    theme(
      axis.title.x = element_text(color = "black", margin = margin(t = 30, b = 8), face = "bold", size = 15),
      axis.title.y = element_text(color = "black", margin = margin(r = 25, l = 8), face = "bold", size = 15, angle = 90),
      axis.text = element_text(color = "grey30"),
      axis.text.x = element_text(face = "bold", size = 9),
      axis.text.y = element_text(face = "bold", size = 9),
      legend.text = element_text(size = 8),
      legend.title = element_text(size = 10, face = "bold"),
      panel.background = element_rect("grey98"),
      plot.background = element_rect("grey98"),
      plot.title = element_text(margin = margin(b = 15, t = 10), face = "bold", size = 25, hjust = 0.5),
      plot.subtitle = element_text(size = 10, hjust = 0, margin = margin(b = 10)),
      plot.margin = unit(c(0.5, 1, 0, 0.2), "inches"),
      panel.grid.major = element_line(color = "gray80", linetype = "dashed"),
      legend.key = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "whitesmoke"),
      legend.box.background = element_rect(color = "black"),
      panel.spacing = unit(10, "points")
    )
}


# Data ----
raw <- read_csv("data/spotify_tracks.csv", show_col_types = FALSE) %>%
  select(-1)


# Macro-genres ----
# The 114 original genres (1,000 tracks each) are grouped into 11 macro-genres.
# Patterns are evaluated in order, so the first match wins.
add_macro_genre <- function(df) {
  df %>%
    mutate(
      macro_genre = case_when(
        str_detect(track_genre, "(?i)ambient|chill|sleep|study|new-age|sad|romance|children|kids") ~ "Mood",
        str_detect(track_genre, "(?i)pop|club|party|disco|happy|^dance$|j-dance") ~ "Pop & Dance",
        str_detect(track_genre, "(?i)electronic|techno|house|dubstep|edm|trance|electro|drum-and-bass|hardstyle|idm|trip-hop|breakbeat|garage|industrial") ~ "Electronic",
        str_detect(track_genre, "(?i)rock|metal|punk|grunge|emo|goth|hardcore|grindcore|indie") ~ "Rock & Alternative",
        str_detect(track_genre, "(?i)rap|trap|r-n-b|soul|funk|groove") ~ "Rap & Trap",
        str_detect(track_genre, "(?i)latin|reggaeton|salsa|reggae|ska|dancehall|^dub$|brazil|forro|mpb|pagode|samba|sertanejo|tango|spanish") ~ "Latin",
        str_detect(track_genre, "(?i)country|folk|bluegrass|acoustic|honky-tonk|songwriter|guitar") ~ "Country & Folk",
        str_detect(track_genre, "(?i)classical|opera|piano") ~ "Classical",
        str_detect(track_genre, "(?i)jazz|blues|gospel") ~ "Jazz & Blues",
        str_detect(track_genre, "(?i)hip-hop") ~ "Hip-Hop",
        TRUE ~ "Other"
      )
    )
}


# Deduplication ----
# A track listed under several genres appears once per genre. For each track_id
# we keep the row whose macro-genre has the highest average popularity.
macro_avg_popularity <- raw %>%
  add_macro_genre() %>%
  group_by(macro_genre) %>%
  summarise(avg_pop = mean(popularity, na.rm = TRUE))

df_clean <- raw %>%
  add_macro_genre() %>%
  left_join(macro_avg_popularity, by = "macro_genre") %>%
  group_by(track_id) %>%
  arrange(desc(avg_pop)) %>%
  slice(1) %>%
  ungroup() %>%
  select(-avg_pop)

audio_features <- c("danceability", "energy", "loudness", "speechiness", "acousticness",
                    "instrumentalness", "liveness", "valence", "tempo")
