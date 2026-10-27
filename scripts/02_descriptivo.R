# PASO 2 - ESTADÍSTICA DESCRIPTIVA
# Usa las series que genera scripts/01_preprocesamiento.R (correr ese antes).
# Para cada estación y variable, y también para todas las estaciones juntas,
# compara Campo vs FLDAS con tablas y una figura de paneles (serie temporal,
# boxplot, histograma, ciclo anual y distribución mensual).
# Salidas en output/descriptivo/:
#   estaciones/<id>_<VAR>.png   figura de cada estación y variable
#   general/TODAS_<VAR>.png     figura con todas las estaciones juntas
#   descriptivo.xlsx            todas las tablas: Resumen general, Resumen por
#                               estación, Por mes - general, Por mes - estaciones,
#                               Cobertura

library(tidyverse)
library(openxlsx)
library(patchwork)

source("R/config.R")
source("R/estadisticaDescriptiva.R")
source("R/escribirExcel.R")

estaciones <- cargarEstaciones()
series     <- read.csv("output/preprocesado/series.csv") %>% mutate(fecha = as.Date(fecha))

resumenes   <- list()
coberturas  <- list()
generales   <- list()
por_mes_est <- list()
por_mes_gen <- list()

for (var in VARIABLES_CAMPO) {

  cat("\n=== Variable:", toupper(var), "===\n")
  datos_var <- list()

  # ── Por estación ──────────────────────────────────────────────────
  for (est in estaciones) {
    datos <- series %>% filter(id == est$id, variable == var)
    if (nrow(datos) == 0) next
    if (nrow(datos) < 4) {
      cat("  ", est$id, ": muy pocos datos, se omite\n")
      next
    }
    cat("  ", est$id, "(n =", nrow(datos), ")\n")

    res <- estadisticaDescriptiva(datos, nombre_estacion = est$id,
                                  variable = toupper(var),
                                  unidad = UNIDADES[[var]],
                                  carpeta_salida = "output/descriptivo/estaciones")

    resumenes[[length(resumenes) + 1]]   <- res$resumen %>%
      mutate(estacion = est$id, variable = toupper(var), .before = 1)
    coberturas[[length(coberturas) + 1]] <- res$cobertura
    por_mes_est[[length(por_mes_est) + 1]] <- res$por_mes %>%
      mutate(estacion = est$id, variable = toupper(var), .before = 1)

    datos_var[[length(datos_var) + 1]] <- datos %>% mutate(estacion = est$id)
  }

  # ── General: todas las estaciones juntas ──────────────────────────
  datos_todas <- bind_rows(datos_var)
  if (nrow(datos_todas) >= 4) {
    res <- estadisticaDescriptiva(datos_todas, nombre_estacion = "TODAS",
                                  variable = toupper(var),
                                  unidad = UNIDADES[[var]],
                                  carpeta_salida = "output/descriptivo/general",
                                  conjunto = TRUE)
    generales[[length(generales) + 1]] <- res$resumen %>%
      mutate(variable = toupper(var),
             n_estaciones = n_distinct(datos_todas$estacion), .before = 1)
    por_mes_gen[[length(por_mes_gen) + 1]] <- res$por_mes %>%
      mutate(variable = toupper(var), .before = 1)
  }
}

# ─── EXCEL CON TODAS LAS TABLAS ─────────────────────────────────────────────

# Nombres de columnas para el Excel
nombres_excel <- c(
  "Variable" = "variable", "Estación" = "estacion", "Estaciones" = "n_estaciones",
  "Fuente" = "fuente", "Mes" = "mes", "n" = "n",
  "Media" = "media", "Mediana" = "mediana", "Desvío" = "desvio", "CV (%)" = "cv_pct",
  "Mínimo" = "minimo", "P10" = "p10", "P25" = "p25", "P75" = "p75", "P90" = "p90",
  "Máximo" = "maximo", "RIC" = "ric", "Asimetría" = "asimetria", "Curtosis" = "curtosis",
  "Meses con 0 (%)" = "meses_cero_pct",
  "Inicio" = "fecha_inicio", "Fin" = "fecha_fin", "Meses con datos" = "meses_con_datos",
  "Meses esperados" = "meses_esperados", "Completitud (%)" = "completitud_pct"
)

# Agrega la unidad de cada variable (al lado de "variable") y pone los títulos
prepararTabla <- function(df) {
  df %>%
    mutate(unidad = unlist(UNIDADES[tolower(variable)]), .after = variable) %>%
    rename(any_of(c(nombres_excel, "Unidad" = "unidad")))
}

escribirExcel(
  list(
    "Resumen general"      = bind_rows(generales)   %>% prepararTabla(),
    "Resumen por estación" = bind_rows(resumenes)   %>% prepararTabla(),
    "Por mes - general"    = bind_rows(por_mes_gen) %>% prepararTabla(),
    "Por mes - estaciones" = bind_rows(por_mes_est) %>% prepararTabla(),
    "Cobertura"            = bind_rows(coberturas)  %>% prepararTabla()
  ),
  "output/descriptivo/descriptivo.xlsx"
)

cat("\nListo. Resultados en output/descriptivo/ (figuras .png y descriptivo.xlsx)\n")
