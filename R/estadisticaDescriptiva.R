# ESTADÍSTICA DESCRIPTIVA PREVIA A LA VALIDACIÓN
# Recibe la serie preprocesada de una estación (columnas: fecha, valor_campo,
# valor_fldas), tal como la guarda scripts/01_preprocesamiento.R.
# Devuelve una lista con las tablas (cobertura, resumen, por_mes) y la figura.
# Los gráficos (serie, boxplot, histograma, ciclo anual y distribución mensual)
# se guardan juntos en UNA figura con paneles: <carpeta_salida>/<estación>_<VAR>.png
# (requiere el paquete patchwork). Las tablas NO se guardan acá: las junta
# scripts/02_descriptivo.R en descriptivo.xlsx.
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
                                   unidad,
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

  # 4. GRÁFICOS
  etiqueta_y <- paste0(variable, " (", unidad, ")")
  colores <- c(Campo = "#1B2A49", FLDAS = "#B22222")
  tema <- theme_light(base_size = 12) +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"),
          legend.title = element_blank())

  # Serie temporal: se completan los meses sin dato con NA para que la línea
  # se corte ahí (si no, geom_line une los extremos del hueco con una recta).
  # Los puntos permiten ver los meses aislados (sin vecinos con dato).
  serie_completa <- datos_largo %>%
    select(fecha, fuente, valor) %>%
    complete(fecha = seq(min(fecha), max(fecha), by = "month"), fuente)

  g_serie <- ggplot(serie_completa, aes(fecha, valor, color = fuente)) +
    geom_line(linewidth = 0.5, na.rm = TRUE) +
    geom_point(size = 0.6, na.rm = TRUE) +
    scale_color_manual(values = colores) +
    labs(title = "Serie temporal", x = NULL, y = etiqueta_y) +
    tema + theme(legend.position = "none")

  g_box <- ggplot(datos_largo, aes(fuente, valor, fill = fuente)) +
    geom_boxplot(alpha = 0.6, outlier.colour = "black") +
    scale_fill_manual(values = colores) +
    labs(title = "Boxplot", x = NULL, y = etiqueta_y) +
    tema + theme(legend.position = "none")

  g_hist <- ggplot(datos_largo, aes(valor, fill = fuente)) +
    geom_histogram(bins = 25, color = "white", alpha = 0.8) +
    facet_wrap(~ fuente, ncol = 1) +
    scale_fill_manual(values = colores) +
    labs(title = "Histograma", x = etiqueta_y, y = "Frecuencia") +
    tema + theme(legend.position = "none")

  g_box_mes <- ggplot(datos_largo, aes(mes, valor, fill = fuente)) +
    geom_boxplot(alpha = 0.6, outlier.size = 0.8) +
    scale_fill_manual(values = colores) +
    labs(title = "Distribución mensual", x = NULL, y = etiqueta_y) +
    tema + theme(legend.position = "none")

  g_ciclo <- ggplot(por_mes, aes(mes, media, color = fuente, group = fuente)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    scale_color_manual(values = colores) +
    labs(title = "Ciclo anual medio", x = NULL, y = etiqueta_y) +
    tema

  # Una sola figura con todos los paneles (patchwork: "/" apila, "|" pone al lado).
  # Con varias estaciones juntas no va la serie temporal (las fechas se repiten).
  fila_medio <- g_box | g_hist | g_ciclo
  figura <- if (conjunto) fila_medio / g_box_mes else g_serie / fila_medio / g_box_mes
  # La leyenda (Campo / FLDAS) se muestra una sola vez, la del ciclo anual, abajo
  figura <- figura +
    plot_layout(guides = "collect") +
    plot_annotation(title = titulo,
                    theme = theme(plot.title = element_text(face = "bold", hjust = 0.5,
                                                            size = 16),
                                  legend.position = "bottom"))

  ggsave(paste0(prefijo, ".png"), figura,
         width = 12, height = if (conjunto) 9 else 12, dpi = 300)

  list(cobertura = cobertura, resumen = resumen, por_mes = por_mes,
       figura = figura)
}
