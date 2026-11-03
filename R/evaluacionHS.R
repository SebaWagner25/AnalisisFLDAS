# FUNCIONES PARA LA EVALUACIÓN INDIRECTA DE LA HUMEDAD DE SUELO (paso 4)
# Las usa scripts/04_evaluacion_HS.R.

# ─── ÍNDICE ESTANDARIZADO (SPI-1 y SSMI) ────────────────────────────────────
# spi() del paquete SPEI 1.7.2 (Beguería y Vicente-Serrano, 2017), con
# distribución Gamma (McKee et al., 1993). Para cada mes calendario
# ajusta la Gamma a los meses con valor > 0 y pasa la probabilidad acumulada,
# corregida por la proporción de meses con valor 0, a una normal estándar.
# Se usa igual para la lluvia (SPI) y para la humedad de suelo (SSMI).
# Las versiones 1.8.0 y 1.8.1 no aplican esa corrección: los meses con 0 dan -Inf.
# fechas, valores: serie mensual (puede tener meses faltantes)
# min_datos: años mínimos con dato en cada mes calendario; si hay menos, NA.
# escala:    meses acumulados (1 = SPI-1, 3 = SPI-3, ...)
indiceEstandarizado <- function(fechas, valores, min_datos = 10, escala = 1) {

  # spi() necesita una serie mensual continua: los meses faltantes van como NA
  serie <- tibble(fecha = seq(min(fechas), max(fechas), by = "month")) %>%
    left_join(tibble(fecha = fechas, valor = valores), by = "fecha")

  # capture.output() evita que spi() llene la consola de mensajes
  invisible(capture.output(
    ajuste <- spi(ts(serie$valor, start = c(year(min(fechas)), month(min(fechas))),
                     frequency = 12),
                  scale = escala, distribution = "Gamma", na.rm = TRUE)
  ))
  indice <- as.numeric(ajuste$fitted)[match(fechas, serie$fecha)]

  # Meses calendario con pocos años de datos -> NA
  anios_por_mes <- table(factor(month(fechas[!is.na(valores)]), levels = 1:12))
  indice[month(fechas) %in% which(anios_por_mes < min_datos)] <- NA
  indice
}

# Quita la tendencia lineal de una serie (residuos de valor ~ tiempo), como
# hace Spennemann et al. (2015) antes de correlacionar
quitarTendencia <- function(fechas, x) {
  ok <- !is.na(x)
  r  <- rep(NA_real_, length(x))
  r[ok] <- resid(lm(x[ok] ~ as.numeric(fechas[ok])))
  r
}

# ─── CORRELACIÓN ────────────────────────────────────────────────────────────
# Solo la correlación y su significancia, como en Jung et al. (2020) y
# Spennemann et al. (2015). No se usan recta ajustada, RMSE ni BIAS: suponen
# que los dos índices deberían valer lo mismo, y miden cosas distintas.
# metodo: "parametrico" -> Pearson; "no parametrico" -> Spearman y Kendall
#         (igual que el paso 3)
# datos:  data.frame con valor_campo (SPI-1) y valor_fldas (SSMI)
correlacion <- function(datos, metodo) {
  test <- function(tipo) suppressWarnings(
    cor.test(datos$valor_campo, datos$valor_fldas, method = tipo))
  tipo <- if (metodo == "parametrico") "pearson" else "spearman"
  ct   <- test(tipo)
  ke   <- if (metodo == "parametrico") NULL else test("kendall")
  tibble(metodo   = tipo, n = nrow(datos),
         r        = unname(ct$estimate), p_valor = ct$p.value,
         tau      = if (is.null(ke)) NA_real_ else unname(ke$estimate),
         p_kendall = if (is.null(ke)) NA_real_ else ke$p.value)
}

# Correlación para cada mes del año (como la Fig. 5 de Jung et al., 2020)
correlacionPorMes <- function(datos, metodo) {
  datos %>%
    mutate(mes = factor(month(fecha), levels = 1:12,
                        labels = c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                                   "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"))) %>%
    group_by(mes) %>%
    group_modify(~ correlacion(.x, metodo)) %>%
    ungroup()
}

# ─── GRÁFICOS ───────────────────────────────────────────────────────────────
# El SPI y el SSMI no miden lo mismo (anomalía de lluvia vs anomalía de humedad),
# así que no se grafican uno contra el otro con recta 1:1: se usan los gráficos
# de los artículos de referencia.

# Series temporales de SPI-1 y SSMI, un panel por estación con su correlación
# (como la Fig. 6 de Spennemann et al., 2015).
# Serie temporal de la humedad de suelo de FLDAS, un panel por capa y una
# línea por estación: línea fina = valor mensual; línea gruesa = media móvil
# de 12 meses (centrada). Muestra cómo la humedad se suaviza y se retrasa con
# la profundidad. Describe la dinámica temporal, no valida los valores.
# datos: data.frame con estacion, capa, fecha y valor (m³/m³)
graficarCapasHS <- function(datos, archivo) {
  etiquetas <- c(hs_0_10 = "0-10 cm", hs_10_40 = "10-40 cm",
                 hs_40_100 = "40-100 cm", hs_100_200 = "100-200 cm")
  datos <- datos %>%
    mutate(capa = factor(etiquetas[capa], levels = etiquetas)) %>%
    group_by(estacion, capa) %>%
    arrange(fecha, .by_group = TRUE) %>%
    mutate(movil = as.numeric(stats::filter(valor, rep(1 / 12, 12), sides = 2))) %>%
    ungroup()

  p <- ggplot(datos, aes(x = fecha, y = valor, color = estacion)) +
    geom_line(alpha = 0.25, linewidth = 0.3, na.rm = TRUE) +
    geom_line(aes(y = movil), linewidth = 0.8, na.rm = TRUE) +
    facet_wrap(~ capa, ncol = 1) +
    labs(title = "Humedad de suelo de FLDAS por capa",
         subtitle = "Línea fina: valor mensual. Línea gruesa: media móvil de 12 meses.",
         x = NULL, y = "Humedad de suelo (m³/m³)", color = NULL) +
    theme_light(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          plot.subtitle = element_text(hjust = 0.5),
          strip.text = element_text(face = "bold"),
          legend.position = "bottom", panel.grid.minor = element_blank())

  ggsave(archivo, plot = p, width = 11, height = 9, dpi = 300)
  p
}

# datos: data.frame con estacion, fecha, valor_campo (SPI-1) y valor_fldas (SSMI)
# coef:  data.frame con estacion y etiqueta (texto del coeficiente)
graficarSeriesHS <- function(datos, coef, archivo) {
  datos <- datos %>%
    left_join(coef, by = "estacion") %>%
    mutate(panel = paste0(estacion, " (", etiqueta, ")")) %>%
    group_by(panel) %>%
    complete(fecha = seq(min(fecha), max(fecha), by = "month")) %>%  # huecos sin unir
    ungroup() %>%
    pivot_longer(c(valor_campo, valor_fldas), names_to = "indice", values_to = "valor") %>%
    mutate(indice = recode(indice, valor_campo = "SPI-1 campo",
                           valor_fldas = "SSMI FLDAS 0-10 cm"))

  p <- ggplot(datos, aes(x = fecha, y = valor, color = indice)) +
    geom_hline(yintercept = 0, color = "gray60") +
    geom_line(linewidth = 0.4, na.rm = TRUE) +
    scale_color_manual(values = c("SPI-1 campo" = "#1B2A49",
                                  "SSMI FLDAS 0-10 cm" = "#B22222"), name = NULL) +
    facet_wrap(~ panel, ncol = 1) +
    labs(title = "SPI-1 de campo y SSMI de FLDAS por estación",
         x = NULL, y = "Índice estandarizado") +
    theme_light(base_size = 11) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.position = "bottom", panel.grid.minor = element_blank())

  ggsave(archivo, plot = p, width = 10, height = 2.2 * n_distinct(datos$panel) + 1.2, dpi = 300)
  p
}

# Correlación SSMI vs SPI-1 por mes del año: barra = promedio de las estaciones,
# error = ±1 desvío estándar entre estaciones (como la Fig. 5 de Jung et al., 2020).
# tabla: salida de correlacionPorMes() de cada estación, con la columna estacion
graficarCorrelacionMensualHS <- function(tabla, archivo, nombre_coef) {
  resumen <- tabla %>%
    group_by(mes) %>%
    summarise(media = mean(r, na.rm = TRUE), desvio = sd(r, na.rm = TRUE))

  p <- ggplot(resumen, aes(x = mes, y = media)) +
    geom_col(fill = "#1B2A49", width = 0.7) +
    geom_errorbar(aes(ymin = media - desvio, ymax = media + desvio), width = 0.25) +
    labs(title = "Correlación SSMI FLDAS vs SPI-1 campo por mes",
         x = NULL, y = paste("Correlación de", nombre_coef),
         caption = "Barra: promedio de las estaciones. Error: ±1 desvío estándar.") +
    theme_light(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          panel.grid.minor = element_blank())

  ggsave(archivo, plot = p, width = 8, height = 5, dpi = 300)
  p
}

# Curva de sensibilidad: correlación entre el SSMI de 0-100 cm y el SPI de
# 1 a 12 meses, una línea por estación y la regional (fila NOMBRE_REGIONAL: las
# estaciones no excluidas juntas) en negro, con la escala de máxima correlación
# regional marcada (como la Fig. 2 de Spennemann et al., 2015).
# tabla:            data.frame con estacion, escala y r
# nombre_regional:  cómo se llama la línea regional en la leyenda
graficarSensibilidad <- function(tabla, escala_max, nombre_coef, archivo,
                                 nombre_regional = NOMBRE_REGIONAL) {
  estaciones <- setdiff(unique(tabla$estacion), nombre_regional)
  colores    <- c(setNames(scales::hue_pal()(length(estaciones)), estaciones),
                  setNames("black", nombre_regional))

  p <- ggplot(tabla, aes(x = escala, y = r, color = estacion)) +
    geom_vline(xintercept = escala_max, linetype = "dashed", color = "gray50") +
    geom_line(aes(linewidth = estacion == nombre_regional)) +
    geom_point(size = 1.8) +
    scale_color_manual(values = colores, name = NULL) +
    scale_linewidth_manual(values = c("FALSE" = 0.6, "TRUE" = 1.3), guide = "none") +
    scale_x_continuous(breaks = 1:12) +
    labs(title = "Correlación SSMI FLDAS 0-100 cm vs SPI de campo según la escala",
         x = "Escala del SPI (meses)", y = paste("Correlación de", nombre_coef),
         caption = paste0("Línea punteada: máximo regional (SPI-", escala_max, ").")) +
    theme_light(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.position = "bottom", panel.grid.minor = element_blank())

  ggsave(archivo, plot = p, width = 8, height = 5.5, dpi = 300)
  p
}
