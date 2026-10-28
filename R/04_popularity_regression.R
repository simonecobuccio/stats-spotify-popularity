# Question 4: can popularity be predicted from audio features?
# Multiple linear regression, 10-fold cross-validation with interactions, Lasso.

source("R/00_setup.R")
library(caret)
library(glmnet)
library(broom)

theme_regression <- function() {
  theme_project() +
    theme(axis.text.x = element_text(face = "bold", size = 13),
          axis.text.y = element_text(face = "bold", size = 13),
          legend.title = element_text(size = 13, face = "bold"),
          plot.subtitle = element_text(size = 15, hjust = 0.5))
}

impact_fill <- scale_fill_manual(values = c("TRUE" = "#1DB954", "FALSE" = "#E91E63"),
                                 labels = c("TRUE" = "Premium", "FALSE" = "Penalty"),
                                 name = "Effect Type")


# Preparation ----
# key and mode are left out: they are categorical codes, not quantities.
df_model <- df_clean %>%
  select(popularity, all_of(audio_features), explicit) %>%
  mutate(explicit = as.numeric(explicit)) %>%
  drop_na() %>%
  mutate(across(-popularity, ~ as.numeric(scale(.))))


# Multiple linear regression ----
baseline_model <- lm(popularity ~ ., data = df_model)
summary(baseline_model)

mlr_coefs <- tidy(baseline_model) %>%
  filter(term != "(Intercept)")

p_mlr <- ggplot(mlr_coefs, aes(x = reorder(term, estimate), y = estimate, fill = estimate > 0)) +
  geom_col(width = 0.7) +
  geom_label(aes(label = round(estimate, 2)), fontface = "bold", fill = "white") +
  coord_flip() +
  impact_fill +
  theme_regression() +
  labs(title = "Baseline Valuation: Unpenalized Drivers",
       subtitle = "Multiple Linear Regression Coefficients (All Features)",
       x = "Audio Feature", y = "Estimated Impact on Popularity")
save_plot(p_mlr, "q4_mlr_coefficients.png")


# 10-fold cross-validation ----
# Baseline model plus the two strongest feature interactions found in question 2.
cv_model <- train(
  popularity ~ . + loudness:energy + acousticness:energy,
  data = df_model,
  method = "lm",
  trControl = trainControl(method = "cv", number = 10)
)
print(cv_model$results)

cv_r2 <- round(100 * cv_model$results$Rsquared, 2)

cv_variance <- tibble(
  Component = c("Audio Physics (Explained)", "Market Noise & Culture (Unexplained)"),
  Percentage = c(cv_r2, 100 - cv_r2)
)

p_variance <- ggplot(cv_variance, aes(x = "", y = Percentage, fill = Component)) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(Percentage, "%"), group = Component), position = position_stack(vjust = 0.5),
             fontface = "bold", fill = "white", size = 7, show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = c("Audio Physics (Explained)" = "#1DB954",
                               "Market Noise & Culture (Unexplained)" = "grey70")) +
  theme_regression() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), legend.position = "top") +
  labs(title = "The Reality of Market Noise",
       subtitle = paste0("10-Fold CV R-Squared = ", round(cv_model$results$Rsquared, 4)),
       x = NULL, y = "Percentage of Variance (%)")
save_plot(p_variance, "q4_cv_variance.png")


# Lasso ----
x <- model.matrix(popularity ~ ., df_model)[, -1]
y <- df_model$popularity

cv_lasso <- cv.glmnet(x, y, alpha = 1)

png(file.path(fig_dir, "q4_lasso_cv.png"), width = 1500, height = 1000, res = 150)
plot(cv_lasso)
dev.off()

# Coefficients at lambda.1se, keeping those with |coefficient| >= 0.1
lasso_drivers <- coef(cv_lasso, s = "lambda.1se") %>%
  as.matrix() %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  rename(Coefficient = 2) %>%
  filter(Feature != "(Intercept)", abs(Coefficient) >= 0.1) %>%
  arrange(desc(abs(Coefficient)))
print(lasso_drivers)

p_lasso <- ggplot(lasso_drivers, aes(x = reorder(Feature, Coefficient), y = Coefficient, fill = Coefficient > 0)) +
  geom_col() +
  geom_label(aes(label = round(Coefficient, 2)), fontface = "bold", fill = "white") +
  coord_flip() +
  impact_fill +
  theme_regression() +
  labs(title = "Drivers of Commercial Success",
       subtitle = "Features surviving Lasso shrinkage, with |coefficient| > 0.1",
       x = "Audio Feature", y = "Impact on Popularity Score")
save_plot(p_lasso, "q4_lasso_drivers.png")

lasso_r2 <- cv_lasso$glmnet.fit$dev.ratio[cv_lasso$index["1se", ]]
cat("Lasso deviance explained at lambda.1se:", round(lasso_r2, 4), "\n")
