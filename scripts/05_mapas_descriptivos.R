# PASO 5 - MAPAS DESCRIPTIVOS (rasters para graficar)
# Para cada variable FLDAS calcula, píxel por píxel, estadísticos de toda la
# serie y los guarda como .tif multibanda (una banda por estadístico).
# Estos .tif son la entrada de los mapas (el código de gráficos en Python
# se agregará en python/). Las isolíneas se generan aparte con cdo/*.sh.
# Salidas en output/mapas/:
#   mensual/<var>_mensual_descriptivo.tif  media, desvío, mín, máx y fecha (AAAAMM) de mín y máx
#   mensual/<var>_climatologia.tif         media de cada mes del año (12 bandas)
#   anual/<var>_anual_descriptivo.tif      lo mismo con valores anuales
# Unidades: PP y ET en mm/mes (anual: PP y ET acumuladas, en mm/año),
#           T y temperatura de suelo (4 capas) en °C,
#           humedad de suelo sin convertir (m³/m³, como viene en FLDAS).

library(terra)
library(tidyverse)

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")

variables <- lapply(names(CARPETAS_FLDAS), function(v)
  list(nombre = v, carpeta = CARPETAS_FLDAS[[v]]))

# Píxeles sin ningún dato en un período dan Inf/-Inf en mínimos y máximos:
# se guardan como NA (sin dato)
sinInfinitos <- function(df) {
  df[] <- lapply(df, function(z) replace(z, is.infinite(z), NA))
  df
}

dir.create("output/mapas/mensual", recursive = TRUE, showWarnings = FALSE)
dir.create("output/mapas/anual",   recursive = TRUE, showWarnings = FALSE)

for (var in variables) {
  cat("Procesando:", var$nombre, "\n")
  
  datos <- importData(var$carpeta)
  coords <- datos[, 1:2]
  valores <- datos[, -(1:2)]
  
  # Convertir unidades si corresponde
  if (seConvierte(var$nombre)) {
    fechas <- as.Date(colnames(valores))
    valores <- t(apply(valores, 1, function(fila) {
      convertir_unidades(fila, variable = var$nombre, fechas = fechas)
    }))
    colnames(valores) <- as.character(fechas)
  }
  
  # ── MENSUAL ──────────────────────────────────────────────────────
  media  <- apply(valores, 1, mean, na.rm = TRUE)
  desvio <- apply(valores, 1, sd,   na.rm = TRUE)
  minimo <- apply(valores, 1, min,  na.rm = TRUE)
  maximo <- apply(valores, 1, max,  na.rm = TRUE)
  
  fechas_col    <- as.Date(colnames(valores))
  idx_min       <- apply(valores, 1, which.min)
  idx_max       <- apply(valores, 1, which.max)
  fecha_min_num <- as.integer(format(fechas_col[idx_min], "%Y%m"))
  fecha_max_num <- as.integer(format(fechas_col[idx_max], "%Y%m"))
  
  df_mensual <- data.frame(coords, media, desvio, minimo, maximo,
                           fecha_min_num, fecha_max_num)
  df_mensual <- sinInfinitos(df_mensual)
  r_mensual  <- rast(df_mensual, crs = "EPSG:4326")
  writeRaster(r_mensual, 
              paste0("output/mapas/mensual/", var$nombre, "_mensual_descriptivo.tif"),
              overwrite = TRUE)
  
  # ── ANUAL ─────────────────────────────────────────────────────────
  fechas_col <- as.Date(colnames(valores))
  anios      <- format(fechas_col, "%Y")
  
  # Agregar por año: suma para PP y ET (mm/año), promedio para el resto
  valores_anuales <- sapply(unique(anios), function(a) {
    cols <- valores[, anios == a, drop = FALSE]
    if (var$nombre %in% c("pp", "et")) {
      rowSums(cols, na.rm = TRUE)
    } else {
      rowMeans(cols, na.rm = TRUE)
    }
  })

  media_a  <- apply(valores_anuales, 1, mean, na.rm = TRUE)
  desvio_a <- apply(valores_anuales, 1, sd,   na.rm = TRUE)
  minimo_a <- apply(valores_anuales, 1, min,  na.rm = TRUE)
  maximo_a <- apply(valores_anuales, 1, max,  na.rm = TRUE)

  anios_unicos  <- unique(anios)
  idx_min_a     <- apply(valores_anuales, 1, which.min)
  idx_max_a     <- apply(valores_anuales, 1, which.max)
  fecha_min_a   <- as.integer(anios_unicos[idx_min_a])
  fecha_max_a   <- as.integer(anios_unicos[idx_max_a])

  df_anual <- data.frame(coords, media_a, desvio_a, minimo_a, maximo_a,
                         fecha_min_a, fecha_max_a)

  # ── EXTREMOS ANUALES (solo para temperaturas: T y TS) ─────────────
  # Para cada año, temperatura del mes más cálido y del mes más frío.
  # Después promediamos esas series anuales entre años.
  if (esTemperatura(var$nombre)) {
    tmax_anual <- sapply(anios_unicos, function(a) {
      cols <- valores[, anios == a, drop = FALSE]
      apply(cols, 1, max, na.rm = TRUE)
    })
    tmin_anual <- sapply(anios_unicos, function(a) {
      cols <- valores[, anios == a, drop = FALSE]
      apply(cols, 1, min, na.rm = TRUE)
    })

    tmax_media <- apply(tmax_anual, 1, mean, na.rm = TRUE)
    tmax_sd    <- apply(tmax_anual, 1, sd,   na.rm = TRUE)
    tmin_media <- apply(tmin_anual, 1, mean, na.rm = TRUE)
    tmin_sd    <- apply(tmin_anual, 1, sd,   na.rm = TRUE)

    df_anual <- data.frame(df_anual,
                           tmax_media, tmax_sd,
                           tmin_media, tmin_sd)
  }

  df_anual <- sinInfinitos(df_anual)
  r_anual  <- rast(df_anual, crs = "EPSG:4326")
  writeRaster(r_anual,
              paste0("output/mapas/anual/", var$nombre, "_anual_descriptivo.tif"),
              overwrite = TRUE)

  cat("  Guardado:", var$nombre, "_mensual y _anual\n")
  
  # ── CLIMATOLOGÍA MENSUAL ──────────────────────────────────────────
  meses <- format(fechas_col, "%m")
  
  valores_clim <- sapply(sprintf("%02d", 1:12), function(m) {
    cols <- valores[, meses == m, drop = FALSE]
    rowMeans(cols, na.rm = TRUE)
  })
  
  colnames(valores_clim) <- c("ene", "feb", "mar", "abr", "may", "jun",
                              "jul", "ago", "sep", "oct", "nov", "dic")
  
  df_clim <- data.frame(coords, valores_clim)
  r_clim  <- rast(df_clim, crs = "EPSG:4326")
  writeRaster(r_clim,
              paste0("output/mapas/mensual/", var$nombre, "_climatologia.tif"),
              overwrite = TRUE)
  
  cat("  Guardado:", var$nombre, "_climatologia\n")
}
