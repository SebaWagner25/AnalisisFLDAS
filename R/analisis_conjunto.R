library(tidyverse)
library(readxl)
library(robustbase)
library(terra)

source("R/importData.R")
source("R/datosPixel.R")
source("R/convertirUnidades.R")
source("R/datosCampo.R")
source("R/datosOMIXOM.R")

# MISMO ANÁLISIS QUE scripts/02_validacion.R, PERO CON TODAS LAS ESTACIONES
# JUNTAS: para cada variable se apilan los datos de todas las estaciones
# y se hace un único análisis.

# ─── CONFIGURACIÓN DE ESTACIONES ────────────────────────────────────────────

estaciones_df <- read.csv("data/estaciones.csv", stringsAsFactors = FALSE)

estaciones <- split(estaciones_df, seq(nrow(estaciones_df))) %>%
  map(function(fila) {
    list(
      id        = fila$id,
      nombre    = fila$nombre,
      proveedor = fila$proveedor,
      archivo   = file.path("data",
                            ifelse(fila$proveedor == "OMIXOM",
                                   "DATOS_OMIXOM",
                                   "DATOS_INTA_SMN"),
                            fila$archivo),
      x         = fila$x,
      y         = fila$y,
      vars      = strsplit(fila$vars, ";")[[1]]
    )
  })

carpetas_fldas <- list(
  pp = "FLDAS_Rainf_f_tavg_comp",
  et = "FLDAS_Evap_tavg_comp",
  t  = "FLDAS_Tair_f_tavg_comp"
)

# Unidades por variable (para etiquetas de gráficos)
unidades_var <- list(
  pp = "mm/mes",
  et = "mm/mes",
  t  = "°C"
)

# ─── FUNCIONES AUXILIARES (iguales a 02_validacion.R) ───────────────────────

cargar_campo <- function(estacion, variable) {
  var_omixom_map <- list(pp = "Precipitación", et = "Evapotranspiración", t = "Temperatura")
  var_campo_map  <- list(pp = "PP", et = "ET", t = "T")

  var_omixom <- var_omixom_map[[variable]]
  nombre_col <- var_campo_map[[variable]]

  if (is.null(var_omixom) || is.null(nombre_col)) {
    stop("Variable no soportada en cargar_campo(): ", variable)
  }

  if (estacion$proveedor == "OMIXOM") {
    datosOMIXOM(estacion$archivo, variable = var_omixom)
  } else {
    datosCampo(estacion$archivo,
               nombre_variable = nombre_col,
               proveedor = estacion$proveedor)
  }
}

analizar <- function(datos, variable) {

  # Normalidad
  sw_campo <- shapiro.test(datos$valor_campo)
  sw_fldas <- shapiro.test(datos$valor_fldas)

  # Correlación
  sp <- cor.test(datos$valor_campo, datos$valor_fldas, method = "spearman")
  ke <- cor.test(datos$valor_campo, datos$valor_fldas, method = "kendall")

  # Regresión robusta
  lmrob_fit <- lmrob(valor_campo ~ valor_fldas, data = datos)
  sum_lmrob <- summary(lmrob_fit)

  list(
    variable   = toupper(variable),
    n_estaciones = n_distinct(datos$estacion),
    n          = nrow(datos),
    sw_campo_p = sw_campo$p.value,
    sw_fldas_p = sw_fldas$p.value,
    spearman   = sp$estimate,
    sp_pvalor  = sp$p.value,
    kendall    = ke$estimate,
    ke_pvalor  = ke$p.value,
    pendiente  = coef(lmrob_fit)[2],
    intercepto = coef(lmrob_fit)[1],
    r2_adj     = sum_lmrob$adj.r.squared,
    bias = mean(datos$valor_fldas - datos$valor_campo, na.rm = TRUE),
    rmse = sqrt(mean((datos$valor_fldas - datos$valor_campo)^2, na.rm = TRUE))
  )
}

graficar <- function(datos, variable, lmrob_fit) {

  lim <- range(c(datos$valor_campo, datos$valor_fldas), na.rm = TRUE)

  unidad <- unidades_var[[variable]]
  if (is.null(unidad)) unidad <- ""

  p <- ggplot(datos, aes(x = valor_fldas, y = valor_campo)) +
    geom_point(size = 1.2, color = "#1B2A49") +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray40") +
    geom_abline(intercept = coef(lmrob_fit)[1], slope = coef(lmrob_fit)[2],
                color = "#B22222", linewidth = 1) +
    coord_fixed(ratio = 1, xlim = lim, ylim = lim) +
    labs(
      title   = paste("Todas las estaciones -", toupper(variable)),
      x       = paste0("FLDAS (", unidad, ")"),
      y       = paste0("Campo (", unidad, ")"),
      caption = paste0("n = ", nrow(datos),
                       " (", n_distinct(datos$estacion), " estaciones)")
    ) +
    theme_light(base_size = 13) +
    theme(
      plot.title       = element_text(hjust = 0.5, face = "bold"),
      plot.caption     = element_text(hjust = 1),
      axis.title       = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )

  nombre_archivo <- paste0("output/validacion/TODAS_", variable, ".png")
  ggsave(nombre_archivo, plot = p, width = 6, height = 6, dpi = 300)
  p
}

# ─── LOOP PRINCIPAL ─────────────────────────────────────────────────────────

dir.create("output/validacion", recursive = TRUE, showWarnings = FALSE)

resultados <- list()

for (var in names(carpetas_fldas)) {

  cat("\n=== Variable:", toupper(var), "===\n")

  # 1. Juntar los datos de todas las estaciones que miden esta variable
  datos_var <- list()

  for (est in estaciones) {
    if (!var %in% est$vars) next

    cat("Cargando:", est$nombre, "\n")

    tryCatch({
      datos_campo <- cargar_campo(est, var)
      datos_fldas <- datosPixel(coord_x = est$x, coord_y = est$y,
                                variable = var,
                                nombre_carpeta = carpetas_fldas[[var]])

      datos <- merge(datos_campo, datos_fldas, by = "fecha", all = FALSE)
      cat("  Filas después del merge:", nrow(datos), "\n")
      datos$fecha    <- NULL
      datos$estacion <- est$nombre

      datos_var[[length(datos_var) + 1]] <- datos

    }, error = function(e) {
      cat("  ERROR:", conditionMessage(e), "\n")
    })
  }

  datos_todas <- bind_rows(datos_var)

  if (nrow(datos_todas) < 3) {
    cat("  Sin datos suficientes para", toupper(var), "\n")
    next
  }

  # 2. Un único análisis con todas las estaciones juntas
  res       <- analizar(datos_todas, var)
  lmrob_fit <- lmrob(valor_campo ~ valor_fldas, data = datos_todas)
  graficar(datos_todas, var, lmrob_fit)

  resultados[[length(resultados) + 1]] <- res
}

# ─── TABLA RESUMEN ──────────────────────────────────────────────────────────

tabla <- bind_rows(resultados) %>%
  select(variable, n_estaciones, n, spearman, sp_pvalor, kendall, ke_pvalor,
         pendiente, r2_adj, bias, rmse) %>%
  rename(
    "Variable"     = variable,
    "Estaciones"   = n_estaciones,
    "n"            = n,
    "ρ Spearman"   = spearman,
    "p-valor (Sp)" = sp_pvalor,
    "τ Kendall"    = kendall,
    "p-valor (Ke)" = ke_pvalor,
    "Pendiente"    = pendiente,
    "R² ajustado"  = r2_adj,
    "BIAS"         = bias,
    "RMSE"         = rmse
  )

print(tabla)

write.csv(tabla, "output/validacion/tabla_resultados_conjunto.csv", row.names = FALSE)
cat("\nTabla guardada en output/validacion/tabla_resultados_conjunto.csv\n")
