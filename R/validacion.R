# FUNCIONES DE VALIDACIÓN FLDAS vs CAMPO
# Las usa scripts/03_validacion.R, tanto por estación como en el análisis general.

# Calcula los estadísticos de validación.
# datos: data.frame con columnas valor_campo y valor_fldas
analizar <- function(datos) {

  campo <- datos$valor_campo
  fldas <- datos$valor_fldas

  # Normalidad (shapiro.test solo acepta entre 3 y 5000 datos)
  p_shapiro <- function(x) {
    if (length(x) < 3 || length(x) > 5000) return(NA_real_)
    shapiro.test(x)$p.value
  }

  # Correlaciones no paramétricas
  sp <- suppressWarnings(cor.test(campo, fldas, method = "spearman"))
  ke <- suppressWarnings(cor.test(campo, fldas, method = "kendall"))

  # Regresión robusta: campo en función de FLDAS
  ajuste <- lmrob(valor_campo ~ valor_fldas, data = datos)

  list(
    ajuste = ajuste,              # se usa para el gráfico
    tabla  = tibble(
      n          = nrow(datos),
      sw_campo_p = p_shapiro(campo),
      sw_fldas_p = p_shapiro(fldas),
      spearman   = unname(sp$estimate),
      sp_pvalor  = sp$p.value,
      kendall    = unname(ke$estimate),
      ke_pvalor  = ke$p.value,
      pendiente  = unname(coef(ajuste)[2]),
      intercepto = unname(coef(ajuste)[1]),
      r2_adj     = summary(ajuste)$adj.r.squared,
      bias       = mean(fldas - campo),
      pbias_pct  = 100 * sum(fldas - campo) / sum(campo),
      rmse       = sqrt(mean((fldas - campo)^2))
    )
  )
}

# Gráfico de dispersión FLDAS vs campo, con la recta 1:1 (punteada)
# y el ajuste robusto (rojo). Lo guarda en 'archivo'.
graficarValidacion <- function(datos, ajuste, titulo, unidad, archivo, subtitulo = NULL) {

  lim <- range(c(datos$valor_campo, datos$valor_fldas), na.rm = TRUE)

  p <- ggplot(datos, aes(x = valor_fldas, y = valor_campo)) +
    geom_point(size = 1.2, color = "#1B2A49") +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray40") +
    geom_abline(intercept = coef(ajuste)[1], slope = coef(ajuste)[2],
                color = "#B22222", linewidth = 1) +
    coord_fixed(ratio = 1, xlim = lim, ylim = lim) +
    labs(
      title   = titulo,
      x       = paste0("FLDAS (", unidad, ")"),
      y       = paste0("Campo (", unidad, ")"),
      caption = if (is.null(subtitulo)) paste0("n = ", nrow(datos)) else subtitulo
    ) +
    theme_light(base_size = 13) +
    theme(
      plot.title       = element_text(hjust = 0.5, face = "bold"),
      plot.caption     = element_text(hjust = 1),
      axis.title       = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )

  ggsave(archivo, plot = p, width = 6, height = 6, dpi = 300)
  p
}
