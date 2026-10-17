# PASO 2 - ESTADÍSTICA DESCRIPTIVA
# Usa las series que genera scripts/01_preprocesamiento.R (correr ese antes).
# Para cada estación y variable, y también para todas las estaciones juntas:
#   tablas (cobertura, resumen, resumen por mes) y gráficos (serie, boxplot,
#   histograma, boxplot mensual, ciclo anual) comparando Campo vs FLDAS.
# Salidas en output/descriptivo/:
#   estaciones/   archivos por estación (<id>_<VAR>_...)
#   general/      archivos con todas las estaciones juntas (TODAS_<VAR>_...)
#   resumen_estaciones.csv, cobertura_estaciones.csv, resumen_general.csv

library(tidyverse)

source("R/config.R")
source("R/estadisticaDescriptiva.R")

estaciones <- cargarEstaciones()

resumenes  <- list()
coberturas <- list()
generales  <- list()

for (var in VARIABLES_CAMPO) {

  cat("\n=== Variable:", toupper(var), "===\n")
  datos_var <- list()

  # ── Por estación ──────────────────────────────────────────────────
  for (est in estaciones) {
    archivo <- file.path("output/preprocesado", paste0(est$id, "_", var, ".csv"))
    if (!file.exists(archivo)) next

    datos <- read.csv(archivo) %>% mutate(fecha = as.Date(fecha))
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
  }
}

write_csv2(bind_rows(resumenes),  "output/descriptivo/resumen_estaciones.csv")
write_csv2(bind_rows(coberturas), "output/descriptivo/cobertura_estaciones.csv")
write_csv2(bind_rows(generales),  "output/descriptivo/resumen_general.csv")

cat("\nListo. Resultados en output/descriptivo/\n")
