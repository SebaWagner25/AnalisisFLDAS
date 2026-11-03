# FUNCIONES DE VALIDACIÓN FLDAS vs CAMPO
# Las usa scripts/03_validacion.R, tanto por estación como en el análisis general.

# p-valor del test de Shapiro-Wilk (shapiro.test solo acepta entre 3 y 5000 datos;
# fuera de ese rango devuelve NA)
pShapiro <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 3 || length(x) > 5000) return(NA_real_)
  shapiro.test(x)$p.value
}

# ¿Son normales las series de campo y FLDAS? (ambas deben serlo)
# Si el test no se pudo calcular (NA), se considera NO normal.
sonNormales <- function(datos, alfa) {
  p <- c(pShapiro(datos$valor_campo), pShapiro(datos$valor_fldas))
  all(!is.na(p) & p >= alfa)
}

# Sesgo por mes del año (enero ... diciembre).
# datos: data.frame con fecha, valor_campo y valor_fldas
sesgoPorMes <- function(datos) {
  datos %>%
    mutate(mes = month(fecha)) %>%
    group_by(mes) %>%
    summarise(
      n           = n(),
      media_campo = mean(valor_campo),
      media_fldas = mean(valor_fldas),
      bias        = mean(valor_fldas - valor_campo),
      pbias_pct   = 100 * sum(valor_fldas - valor_campo) / sum(valor_campo),
      .groups = "drop"
    ) %>%
    mutate(mes = factor(mes, levels = 1:12,
                        labels = c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                   "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))
}

# Calcula los estadísticos de validación.
# datos:  data.frame con columnas valor_campo y valor_fldas
# metodo: "parametrico"    -> correlación de Pearson y regresión lineal (lm), R²
#         "no parametrico" -> correlación de Spearman y Kendall, regresión robusta (lmrob)
analizar <- function(datos, metodo = c("no parametrico", "parametrico")) {
  metodo <- match.arg(metodo)

  campo <- datos$valor_campo
  fldas <- datos$valor_fldas

  # Valores que se completan según el método (los demás quedan NA)
  pearson <- pe_p <- spearman <- sp_p <- kendall <- ke_p <- r2 <- r2_adj_rob <- NA_real_

  if (metodo == "parametrico") {
    pe      <- cor.test(campo, fldas, method = "pearson")
    pearson <- unname(pe$estimate)
    pe_p    <- pe$p.value
    ajuste  <- lm(valor_campo ~ valor_fldas, data = datos)
    r2      <- summary(ajuste)$r.squared
  } else {
    sp       <- suppressWarnings(cor.test(campo, fldas, method = "spearman"))
    ke       <- suppressWarnings(cor.test(campo, fldas, method = "kendall"))
    spearman <- unname(sp$estimate); sp_p <- sp$p.value
    kendall  <- unname(ke$estimate); ke_p <- ke$p.value
    ajuste   <- lmrob(valor_campo ~ valor_fldas, data = datos)
    r2_adj_rob <- summary(ajuste)$adj.r.squared
  }

  list(
    ajuste = ajuste,              # se usa para el gráfico
    tabla  = tibble(
      metodo     = metodo,
      n          = nrow(datos),
      sw_campo_p = pShapiro(campo),
      sw_fldas_p = pShapiro(fldas),
      pearson    = pearson,
      pe_pvalor  = pe_p,
      spearman   = spearman,
      sp_pvalor  = sp_p,
      kendall    = kendall,
      ke_pvalor  = ke_p,
      pendiente  = unname(coef(ajuste)[2]),
      intercepto = unname(coef(ajuste)[1]),
      r2         = r2,
      r2_adj_rob = r2_adj_rob,
      bias       = mean(fldas - campo),
      pbias_pct  = 100 * sum(fldas - campo) / sum(campo),
      rmse       = sqrt(mean((fldas - campo)^2)),
      mae        = mean(abs(fldas - campo))
    )
  )
}

# Gráfico del sesgo por mes (barras): positivo = FLDAS sobrestima.
# archivo = NULL: no lo guarda (sirve para armar una figura con varios paneles).
graficarSesgoMensual <- function(sesgo_mes, titulo, unidad, archivo = NULL) {
  sesgo_mes <- sesgo_mes %>%
    mutate(signo = ifelse(bias >= 0, "FLDAS sobrestima", "FLDAS subestima"))

  p <- ggplot(sesgo_mes, aes(x = mes, y = bias, fill = signo)) +
    geom_col(width = 0.75) +
    geom_hline(yintercept = 0, color = "gray30") +
    scale_fill_manual(values = c("FLDAS sobrestima" = "#B22222",
                                 "FLDAS subestima"  = "#1B2A49"), name = NULL) +
    labs(title = titulo, x = NULL, y = paste0("BIAS (", unidad, ")"),
         caption = "BIAS = media(FLDAS - campo)") +
    theme_light(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.position = "bottom", panel.grid.minor = element_blank())

  if (!is.null(archivo)) ggsave(archivo, plot = p, width = 8, height = 5, dpi = 300)
  p
}

# Dispersión FLDAS vs campo de TODAS las estaciones de una variable, en una
# sola figura con un panel por estación (cada panel con su recta 1:1 punteada
# y su recta ajustada en rojo).
# datos:  data.frame con estacion, valor_campo y valor_fldas
# rectas: data.frame con estacion, intercepto y pendiente (una fila por estación)
graficarValidacionEstaciones <- function(datos, rectas, titulo, unidad, archivo) {

  # Etiqueta de cada panel con el n de la estación
  etiquetas <- datos %>% count(estacion) %>%
    mutate(panel = paste0(estacion, " (n = ", n, ")"))
  datos  <- datos  %>% left_join(etiquetas %>% select(estacion, panel), by = "estacion")
  rectas <- rectas %>% left_join(etiquetas %>% select(estacion, panel), by = "estacion")

  # Mismo rango en ambos ejes dentro de cada panel (para que la 1:1 sea la diagonal)
  limites <- datos %>% group_by(panel) %>%
    summarise(minimo = min(c(valor_campo, valor_fldas), na.rm = TRUE),
              maximo = max(c(valor_campo, valor_fldas), na.rm = TRUE), .groups = "drop") %>%
    pivot_longer(c(minimo, maximo), values_to = "lim")

  n_paneles <- n_distinct(datos$panel)
  n_col     <- min(4, n_paneles)
  n_filas   <- ceiling(n_paneles / n_col)

  p <- ggplot(datos, aes(x = valor_fldas, y = valor_campo)) +
    geom_blank(data = limites, aes(x = lim, y = lim)) +
    geom_point(size = 1, color = "#1B2A49") +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray40") +
    geom_abline(data = rectas, aes(intercept = intercepto, slope = pendiente),
                color = "#B22222", linewidth = 0.9) +
    facet_wrap(~ panel, scales = "free", ncol = n_col) +
    labs(title = titulo,
         x = paste0("FLDAS (", unidad, ")"), y = paste0("Campo (", unidad, ")"),
         caption = "Punteada: recta 1:1. Roja: recta ajustada.") +
    theme_light(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          axis.title = element_text(face = "bold"),
          aspect.ratio = 1, panel.grid.minor = element_blank())

  ggsave(archivo, plot = p, width = 3.2 * n_col + 1, height = 3.2 * n_filas + 1.2, dpi = 300)
  p
}

# Gráfico de dispersión FLDAS vs campo, con la recta 1:1 (punteada)
# y la recta ajustada (roja: lineal o robusta según el método). Lo guarda en 'archivo'
# (archivo = NULL: no lo guarda, sirve para armar una figura con varios paneles).
graficarValidacion <- function(datos, ajuste, titulo, unidad, archivo = NULL, subtitulo = NULL) {

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

  if (!is.null(archivo)) ggsave(archivo, plot = p, width = 6, height = 6, dpi = 300)
  p
}
