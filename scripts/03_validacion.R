# PASO 3 - VALIDACIÓN FLDAS vs CAMPO
# Usa las series que genera scripts/01_preprocesamiento.R (correr ese antes).
#   a) Por estación: un análisis por cada estación y variable.
#   b) General: para cada variable se apilan todas las estaciones y se hace
#      un único análisis (se pueden excluir estaciones en R/config.R).
# Estadísticos: normalidad (Shapiro-Wilk), correlación de Spearman y Kendall,
# regresión robusta (lmrob), BIAS, PBIAS (%) y RMSE.
# Salidas en output/validacion/:
#   por_estacion/<id>_<var>.png    tabla_por_estacion.csv
#   general/TODAS_<var>.png        tabla_general.csv

library(tidyverse)
library(robustbase)

source("R/config.R")
source("R/validacion.R")

dir.create("output/validacion/por_estacion", recursive = TRUE, showWarnings = FALSE)
dir.create("output/validacion/general",      recursive = TRUE, showWarnings = FALSE)

estaciones <- cargarEstaciones()

leerPreprocesado <- function(id, var) {
  archivo <- file.path("output/preprocesado", paste0(id, "_", var, ".csv"))
  if (!file.exists(archivo)) return(NULL)
  read.csv(archivo) %>% mutate(fecha = as.Date(fecha))
}

# ─── a) POR ESTACIÓN ────────────────────────────────────────────────────────

tabla_estaciones <- list()

for (est in estaciones) {
  for (var in intersect(est$vars, VARIABLES_CAMPO)) {

    datos <- leerPreprocesado(est$id, var)
    if (is.null(datos) || nrow(datos) < 4) {
      cat("Sin datos suficientes:", est$nombre, "-", var, "\n")
      next
    }
    cat("Validando:", est$nombre, "-", var, "(n =", nrow(datos), ")\n")

    tryCatch({
      res <- analizar(datos)
      graficarValidacion(datos, res$ajuste,
                         titulo  = paste(est$nombre, "-", toupper(var)),
                         unidad  = UNIDADES[[var]],
                         archivo = paste0("output/validacion/por_estacion/",
                                          est$id, "_", var, ".png"))
      tabla_estaciones[[length(tabla_estaciones) + 1]] <- res$tabla %>%
        mutate(estacion = est$nombre, id = est$id, variable = toupper(var), .before = 1)
    }, error = function(e) cat("  ERROR:", conditionMessage(e), "\n"))
  }
}

# ─── b) GENERAL (todas las estaciones juntas) ──────────────────────────────

tabla_general <- list()

for (var in VARIABLES_CAMPO) {

  excluidas <- EXCLUIR_GENERAL[[var]]
  datos_var <- list()

  for (est in estaciones) {
    if (!var %in% est$vars || est$id %in% excluidas) next
    datos <- leerPreprocesado(est$id, var)
    if (!is.null(datos)) datos_var[[length(datos_var) + 1]] <- datos %>% mutate(estacion = est$id)
  }
  datos_todas <- bind_rows(datos_var)

  if (nrow(datos_todas) < 4) next
  cat("Validación general:", toupper(var), "(n =", nrow(datos_todas), ")\n")

  res <- analizar(datos_todas)

  # Si se excluyeron estaciones, el gráfico lleva otro nombre (ej. TODAS_et_sin_VM.png)
  sufijo <- if (length(excluidas) > 0) paste0("_sin_", paste(excluidas, collapse = "_")) else ""
  graficarValidacion(datos_todas, res$ajuste,
                     titulo    = paste("Todas las estaciones -", toupper(var)),
                     unidad    = UNIDADES[[var]],
                     archivo   = paste0("output/validacion/general/TODAS_", var, sufijo, ".png"),
                     subtitulo = paste0("n = ", nrow(datos_todas), " (",
                                        n_distinct(datos_todas$estacion), " estaciones)"))

  tabla_general[[length(tabla_general) + 1]] <- res$tabla %>%
    mutate(variable     = toupper(var),
           excluidas    = paste(excluidas, collapse = ", "),
           n_estaciones = n_distinct(datos_todas$estacion), .before = 1)
}

# ─── TABLAS ─────────────────────────────────────────────────────────────────

# Nombres de columnas para el informe
nombres <- c(
  "Estación" = "estacion", "Variable" = "variable", "Excluidas" = "excluidas",
  "Estaciones" = "n_estaciones", "n" = "n",
  "p Shapiro (campo)" = "sw_campo_p", "p Shapiro (FLDAS)" = "sw_fldas_p",
  "ρ Spearman" = "spearman", "p-valor (Sp)" = "sp_pvalor",
  "τ Kendall" = "kendall", "p-valor (Ke)" = "ke_pvalor",
  "Pendiente" = "pendiente", "Intercepto" = "intercepto", "R² ajustado" = "r2_adj",
  "BIAS" = "bias", "PBIAS (%)" = "pbias_pct", "RMSE" = "rmse"
)

tabla_est <- bind_rows(tabla_estaciones) %>% select(-id) %>% rename(any_of(nombres))
tabla_gen <- bind_rows(tabla_general) %>% rename(any_of(nombres))

print(tabla_est, n = Inf, width = Inf)
print(tabla_gen, width = Inf)

write.csv(tabla_est, "output/validacion/tabla_por_estacion.csv", row.names = FALSE)
write.csv(tabla_gen, "output/validacion/tabla_general.csv",      row.names = FALSE)
cat("\nListo. Resultados en output/validacion/\n")
