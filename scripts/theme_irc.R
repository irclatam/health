# theme_irc.R
# Shared ggplot2 theme and colour palettes for the IRC Latin America health dashboard.
# Source this file at the top of each dashboard section:  source("scripts/theme_irc.R")
#
# COLOURS ARE PROVISIONAL — update here when the IRC Latam brand palette is finalised.
# One change here propagates across all 26 charts.

library(ggplot2)
library(showtext)

font_add_google("Inter", "Inter")
font_add_google("Roboto Mono", "Roboto Mono")
showtext_auto()

# ── Country palette ────────────────────────────────────────────────────────────
# Atlassian palette, matching the IRC Latam Shiny app.

pal_country <- c(
  Ecuador = "#22A06B",
  Mexico  = "#357DE8",
  Peru    = "#AF59E1"
)

scale_colour_country <- function(...) scale_colour_manual(values = pal_country, ...)
scale_fill_country   <- function(...) scale_fill_manual(values = pal_country, ...)

# ── Sex palette ───────────────────────────────────────────────────────────────
# Used for population pyramids and any chart encoding sex within a panel.
# Rule 3 applies: second categorical variable within a facet → purpose-specific palette.

pal_sex <- c(Women = "#1B7F8A", Men = "#A3CDD4", Other = "grey50")

scale_fill_sex   <- function(...) scale_fill_manual(values = pal_sex, ...)
scale_colour_sex <- function(...) scale_colour_manual(values = pal_sex, ...)

# ── SSR service type palette ───────────────────────────────────────────────────
# Used in Chart 3.1 only — the one chart where service type is the fill variable.
# ColorBrewer Dark2.

pal_service <- c(
  "Family planning"  = "#1B9E77",
  "Prenatal care"    = "#D95F02",
  "ITS/STI"          = "#7570B3",
  "Cancer screening" = "#E7298A",
  "GBV services"     = "#E6AB02",
  "SSR counselling"  = "#A6761D"
)

# ── Safeguarding highlight ─────────────────────────────────────────────────────
# Under-18 bar in Charts 3.4 and 7.4 only. Never reuse for other purposes.

col_highlight <- "#E53935"

# ── Base theme ─────────────────────────────────────────────────────────────────

theme_irc <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(family = "Inter"),
      axis.text.x      = element_text(family = "Roboto Mono", size = rel(0.9)),
      axis.text.y      = element_text(size = rel(0.9)),
      axis.title       = element_text(size = rel(1.0)),
      strip.text       = element_text(size = rel(1.0), face = "bold"),
      legend.position  = "top",
      legend.title     = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92"),
      plot.caption     = element_text(size = rel(0.75), colour = "grey50", hjust = 0)
    )
}

theme_set(theme_irc())
