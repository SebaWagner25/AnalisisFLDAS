# PASO 3 - VALIDACIÓN FLDAS vs CAMPO
# Usa las series que genera scripts/01_preprocesamiento.R (correr ese antes).
#   a) Por estación: un análisis por cada estación y variable.
#   b) General: para cada variable se apilan todas las estaciones y se hace
#      un único análisis (se pueden excluir estaciones en R/config.R).
# Elección del método según el test de Shapiro-Wilk (ALFA_SHAPIRO en R/config.R):
#   - Por estación: si al menos una estación (campo o FLDAS) no es normal, todas
#     las estaciones de esa variable se validan con el método no paramétrico.
#     Si todas son normales, con el paramétrico.
#   - General: la misma regla sobre los datos de todas las estaciones juntas.
# Paramétrico:    correlación de Pearson, regresión lineal (lm) y R².
# No paramétrico: correlación de Spearman y Kendall, regresión robusta (lmrob).
# En ambos casos: BIAS, PBIAS (%) y RMSE.
# Sesgo: test sobre las diferencias pareadas (FLDAS - campo) con el mismo criterio:
#   no paramétrico -> Wilcoxon de rangos con signo; paramétrico -> t pareado.
#   Además, el sesgo por mes del año (BIAS, PBIAS y el test para cada mes).
# Salidas en output/validacion/:
#   estaciones_<var>.png       dispersión FLDAS vs campo, un panel por estación
#   TODAS_<var>.png            dispersión con todas las estaciones juntas
#   sesgo_mensual_<var>.png    sesgo por mes del año (todas las estaciones juntas)
#   validacion.xlsx            hojas: Por estación, General, Normalidad, Sesgo por mes

library(tidyverse)
library(robustbase)
library(openxlsx)

source("R/config.R")
source("R/validacion.R")
source("R/escribirExcel.R")

dir.create("output/validacion", recursive = TRUE, showWarnings = FALSE)

estaciones <- cargarEstaciones()
todas_series <- read.csv("output/preprocesado/series.csv") %>% mutate(fecha = as.Date(fecha))

leerPreprocesado <- function(id_est, var) {
  datos <- todas_series %>% filter(id == id_est, variable == var) %>%
    select(fecha, valor_campo, valor_fldas)
  if (nrow(datos) == 0) NULL else datos
}

etiqueta <- c("parametrico" = "PARAMÉTRICO", "no parametrico" = "NO PARAMÉTRICO")

tabla_estaciones <- list()
tabla_general    <- list()
tabla_normalidad <- list()
tabla_sesgo_mes  <- list()

for (var in VARIABLES_CAMPO) {

  cat("\n=== Variable:", toupper(var), "===\n")

  # ─── a) POR ESTACIÓN ──────────────────────────────────────────────────────

  # 1. Leer las series de todas las estaciones que miden esta variable
  series <- list()
  for (est in estaciones) {
    if (!var %in% est$vars) next
    datos <- leerPreprocesado(est$id, var)
    if (is.null(datos) || nrow(datos) < 4) {
      cat("Sin datos suficientes:", est$nombre, "\n")
      next
    }
    series[[est$id]] <- datos
  }
  if (length(series) == 0) next

  # 2. Normalidad de cada estación (campo y FLDAS)
  normalidad <- map_dfr(names(series), function(id) tibble(
    id         = id,
    variable   = toupper(var),
    n          = nrow(series[[id]]),
    sw_campo_p = pShapiro(series[[id]]$valor_campo),
    sw_fldas_p = pShapiro(series[[id]]$valor_fldas),
    normal     = sonNormales(series[[id]], ALFA_SHAPIRO)
  ))
  tabla_normalidad[[length(tabla_normalidad) + 1]] <- normalidad

  # 3. Método para TODAS las estaciones de esta variable
  metodo_est <- if (all(normalidad$normal)) "parametrico" else "no parametrico"
  cat("Por estación:", sum(!normalidad$normal), "de", nrow(normalidad),
      "estaciones no normales -> método", etiqueta[metodo_est], "\n")

  # 4. Validar cada estación con ese método
  rectas <- list()
  for (est in estaciones) {
    datos <- series[[est$id]]
    if (is.null(datos)) next
    tryCatch({
      res <- analizar(datos, metodo_est)
      rectas[[length(rectas) + 1]] <- tibble(estacion   = est$nombre,
                                             intercepto = coef(res$ajuste)[1],
                                             pendiente  = coef(res$ajuste)[2])
      tabla_estaciones[[length(tabla_estaciones) + 1]] <- res$tabla %>%
        mutate(estacion = est$nombre, variable = toupper(var), .before = 1)
      tabla_sesgo_mes[[length(tabla_sesgo_mes) + 1]] <- sesgoPorMes(datos, metodo_est) %>%
        mutate(estacion = est$nombre, variable = toupper(var), .before = 1)
    }, error = function(e) cat("  ERROR", est$nombre, ":", conditionMessage(e), "\n"))
  }

  # 5. Una figura con un panel por estación
  nombre_est <- setNames(sapply(estaciones, `[[`, "nombre"), sapply(estaciones, `[[`, "id"))
  graficarValidacionEstaciones(
    datos   = bind_rows(lapply(names(series), function(id)
                series[[id]] %>% mutate(estacion = nombre_est[[id]]))),
    rectas  = bind_rows(rectas),
    titulo  = paste0(toupper(var), " - FLDAS vs campo por estación (método ",
                     tolower(etiqueta[metodo_est]), ")"),
    unidad  = UNIDADES[[var]],
    archivo = paste0("output/validacion/estaciones_", var, ".png"))

  # ─── b) GENERAL (todas las estaciones juntas) ────────────────────────────

  excluidas   <- EXCLUIR_GENERAL[[var]]
  datos_todas <- bind_rows(lapply(names(series), function(id)
    series[[id]] %>% mutate(estacion = id))) %>%
    filter(!estacion %in% excluidas)

  if (nrow(datos_todas) < 4) next

  # Misma regla, aplicada a los datos apilados
  metodo_gen <- if (sonNormales(datos_todas, ALFA_SHAPIRO)) "parametrico" else "no parametrico"
  cat("General (n =", nrow(datos_todas), ") -> método", etiqueta[metodo_gen], "\n")

  res <- analizar(datos_todas, metodo_gen)

  # Si se excluyeron estaciones, el gráfico lleva otro nombre (ej. TODAS_et_sin_VM.png)
  sufijo <- if (length(excluidas) > 0) paste0("_sin_", paste(excluidas, collapse = "_")) else ""
  graficarValidacion(datos_todas, res$ajuste,
                     titulo    = paste("Todas las estaciones -", toupper(var)),
                     unidad    = UNIDADES[[var]],
                     archivo   = paste0("output/validacion/TODAS_", var, sufijo, ".png"),
                     subtitulo = paste0("n = ", nrow(datos_todas), " (",
                                        n_distinct(datos_todas$estacion), " estaciones)"))

  sesgo_mes <- sesgoPorMes(datos_todas, metodo_gen)
  graficarSesgoMensual(sesgo_mes,
                       titulo  = paste("Sesgo por mes - Todas las estaciones -", toupper(var)),
                       unidad  = UNIDADES[[var]],
                       archivo = paste0("output/validacion/sesgo_mensual_", var, sufijo, ".png"),
                       alfa    = ALFA_SHAPIRO)
  tabla_sesgo_mes[[length(tabla_sesgo_mes) + 1]] <- sesgo_mes %>%
    mutate(estacion = "TODAS", variable = toupper(var), .before = 1)

  tabla_general[[length(tabla_general) + 1]] <- res$tabla %>%
    mutate(variable     = toupper(var),
           excluidas    = paste(excluidas, collapse = ", "),
           n_estaciones = n_distinct(datos_todas$estacion), .before = 1)
}

# ─── TABLAS ─────────────────────────────────────────────────────────────────

# Nombres de columnas para el informe
nombres <- c(
  "Estación" = "estacion", "Variable" = "variable", "Excluidas" = "excluidas",
  "Estaciones" = "n_estaciones", "Método" = "metodo", "n" = "n",
  "p Shapiro (campo)" = "sw_campo_p", "p Shapiro (FLDAS)" = "sw_fldas_p",
  "r Pearson" = "pearson", "p-valor (Pe)" = "pe_pvalor",
  "ρ Spearman" = "spearman", "p-valor (Sp)" = "sp_pvalor",
  "τ Kendall" = "kendall", "p-valor (Ke)" = "ke_pvalor",
  "Pendiente" = "pendiente", "Intercepto" = "intercepto",
  "R²" = "r2", "R² ajustado (robusto)" = "r2_adj_rob",
  "BIAS" = "bias", "PBIAS (%)" = "pbias_pct", "RMSE" = "rmse",
  "Test diferencias" = "test_dif", "Estadístico (dif.)" = "est_dif",
  "p-valor (dif.)" = "p_dif",
  "Mes" = "mes", "Media campo" = "media_campo", "Media FLDAS" = "media_fldas",
  "Test" = "test"
)

# Quita las columnas que quedaron vacías (las del método que no se usó)
quitarVacias <- function(df) df %>% select(where(~ !all(is.na(.x))))

tabla_est  <- bind_rows(tabla_estaciones) %>% rename(any_of(nombres))
tabla_gen  <- bind_rows(tabla_general)    %>% rename(any_of(nombres))
tabla_norm <- bind_rows(tabla_normalidad) %>%
  rename("Estación (id)" = id, "Variable" = variable, "n" = n,
         "p Shapiro (campo)" = sw_campo_p, "p Shapiro (FLDAS)" = sw_fldas_p,
         "Normal (campo y FLDAS)" = normal)

print(quitarVacias(tabla_est), n = Inf, width = Inf)
print(quitarVacias(tabla_gen), width = Inf)

escribirExcel(
  list(
    "Por estación"  = quitarVacias(tabla_est),
    "General"       = quitarVacias(tabla_gen),
    "Normalidad"    = tabla_norm,
    "Sesgo por mes" = bind_rows(tabla_sesgo_mes) %>% rename(any_of(nombres))
  ),
  "output/validacion/validacion.xlsx"
)
cat("\nListo. Resultados en output/validacion/ (figuras .png y validacion.xlsx)\n")
