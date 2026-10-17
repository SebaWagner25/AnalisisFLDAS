# ESTADÍSTICA DESCRIPTIVA PREVIA A LA VALIDACIÓN
# Recibe la serie preprocesada de una estación (columnas: fecha, valor_campo,
# valor_fldas), tal como la guarda scripts/01_preprocesamiento.R.
# Devuelve una lista con tablas y gráficos, y además los guarda en disco
# (tablas en CSV con ";" y coma decimal, listas para abrir en Excel).
# conjunto = TRUE: datos de varias estaciones apilados (análisis general).
#   En ese caso no se calcula la cobertura ni el gráfico de serie temporal,
#   porque las fechas se repiten entre estaciones.

# --- Funciones auxiliares ---------------------------------------------------

# Coeficiente de asimetría (muestral). > 0: cola larga hacia valores altos
asimetria <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x); m <- mean(x); s <- sd(x)
  (n / ((n - 1) * (n - 2))) * sum(((x - m) / s)^3)
}

# Curtosis en exceso (muestral). 0 = como una normal; > 0: colas más pesadas
curtosis <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x); m <- mean(x); s <- sd(x)
  (n * (n + 1) / ((n - 1) * (n - 2) * (n - 3))) * sum(((x - m) / s)^4) -
    3 * (n - 1)^2 / ((n - 2) * (n - 3))
}

MESES <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
           "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

# --- Función principal ------------------------------------------------------

estadisticaDescriptiva <- function(datos, nombre_estacion, variable,
                                   unidad = "mm/mes",
                                   carpeta_salida = "output/descriptivo",
                                   conjunto = FALSE) {

  dir.create(carpeta_salida, recursive = TRUE, showWarnings = FALSE)
  prefijo <- file.path(carpeta_salida, paste0(nombre_estacion, "_", variable))
  titulo  <- paste0(variable, " - ", nombre_estacion)

  # Pasar a formato largo: una columna "fuente" (Campo / FLDAS) y una "valor"
  datos_largo <- datos %>%
    select(fecha, valor_campo, valor_fldas) %>%
    pivot_longer(c(valor_campo, valor_fldas),
                 names_to = "fuente", values_to = "valor") %>%
    mutate(fuente = recode(fuente, valor_campo = "Campo", valor_fldas = "FLDAS"),
           mes = factor(month(fecha), levels = 1:12, labels = MESES))

  # 1. COBERTURA TEMPORAL (período común después del merge)
  if (conjunto) {
    cobertura <- tibble(estacion = nombre_estacion, variable = variable,
                        n_estaciones = n_distinct(datos$estacion),
                        meses_con_datos = nrow(datos))
  } else {
  meses_esperados <- length(seq(min(datos$fecha), max(datos$fecha), by = "month"))
  cobertura <- tibble(
    estacion        = nombre_estacion,
    variable        = variable,
    fecha_inicio    = min(datos$fecha),
    fecha_fin       = max(datos$fecha),
    meses_con_datos = nrow(datos),
    meses_esperados = meses_esperados,
    completitud_pct = round(100 * nrow(datos) / meses_esperados, 1)
  )
  }

  # 2. RESUMEN GENERAL POR FUENTE
  resumen <- datos_largo %>%
    group_by(fuente) %>%
    summarise(
      n            = sum(!is.na(valor)),
      media        = mean(valor, na.rm = TRUE),
      mediana      = median(valor, na.rm = TRUE),
      desvio       = sd(valor, na.rm = TRUE),
      cv_pct       = 100 * desvio / media,
      minimo       = min(valor, na.rm = TRUE),
      p10          = quantile(valor, 0.10, na.rm = TRUE),
      p25          = quantile(valor, 0.25, na.rm = TRUE),
      p75          = quantile(valor, 0.75, na.rm = TRUE),
      p90          = quantile(valor, 0.90, na.rm = TRUE),
      maximo       = max(valor, na.rm = TRUE),
      ric          = IQR(valor, na.rm = TRUE),
      asimetria    = asimetria(valor),
      curtosis     = curtosis(valor),
      meses_cero_pct = 100 * mean(valor == 0, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 2)))

  # 3. RESUMEN POR MES DEL AÑO (ciclo anual / climatología)
  por_mes <- datos_largo %>%
    group_by(fuente, mes) %>%
    summarise(
      n       = sum(!is.na(valor)),
      media   = mean(valor, na.rm = TRUE),
      mediana = median(valor, na.rm = TRUE),
      desvio  = sd(valor, na.rm = TRUE),
      p25     = quantile(valor, 0.25, na.rm = TRUE),
      p75     = quantile(valor, 0.75, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 2)))

  # Guardar tablas
  write_csv2(cobertura, paste0(prefijo, "_cobertura.csv"))
  write_csv2(resumen,   paste0(prefijo, "_resumen.csv"))
  write_csv2(por_mes,   paste0(prefijo, "_por_mes.csv"))

  # 4. GRÁFICOS
  etiqueta_y <- paste0(variable, " (", unidad, ")")
  colores <- c(Campo = "#1B2A49", FLDAS = "#B22222")
  tema <- theme_light(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.title = element_blank())

  g_serie <- ggplot(datos_largo, aes(fecha, valor, color = fuente)) +
    geom_line(linewidth = 0.5) +
    scale_color_manual(values = colores) +
    labs(title = paste("Serie temporal -", titulo), x = NULL, y = etiqueta_y) +
    tema

  g_box <- ggplot(datos_largo, aes(fuente, valor, fill = fuente)) +
    geom_boxplot(alpha = 0.6, outlier.colour = "black") +
    scale_fill_manual(values = colores) +
    labs(title = paste("Boxplot -", titulo), x = NULL, y = etiqueta_y) +
    tema + theme(legend.position = "none")

  g_hist <- ggplot(datos_largo, aes(valor, fill = fuente)) +
    geom_histogram(bins = 25, color = "white", alpha = 0.8) +
    facet_wrap(~ fuente, ncol = 1) +
    scale_fill_manual(values = colores) +
    labs(title = paste("Histograma -", titulo), x = etiqueta_y, y = "Frecuencia") +
    tema + theme(legend.position = "none")

  g_box_mes <- ggplot(datos_largo, aes(mes, valor, fill = fuente)) +
    geom_boxplot(alpha = 0.6, outlier.size = 0.8) +
    scale_fill_manual(values = colores) +
    labs(title = paste("Distribución mensual -", titulo), x = NULL, y = etiqueta_y) +
    tema

  g_ciclo <- ggplot(por_mes, aes(mes, media, color = fuente, group = fuente)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    scale_color_manual(values = colores) +
    labs(title = paste("Ciclo anual medio -", titulo), x = NULL, y = etiqueta_y) +
    tema

  graficos <- list(serie = g_serie, boxplot = g_box, histograma = g_hist,
                   boxplot_mes = g_box_mes, ciclo_anual = g_ciclo)
  if (conjunto) graficos$serie <- NULL

  for (nombre in names(graficos)) {
    ggsave(paste0(prefijo, "_", nombre, ".png"), graficos[[nombre]],
           width = 8, height = 5, dpi = 300)
  }

  list(cobertura = cobertura, resumen = resumen, por_mes = por_mes,
       graficos = graficos)
}
