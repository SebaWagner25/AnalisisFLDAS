# PASO 6 - BEAST (tendencias y cambios abruptos)
# NOTA: este paso probablemente pase a otro proyecto/repositorio.
# Aplica BEAST píxel por píxel a cada variable FLDAS y guarda un .tif con
# la pendiente de la tendencia, su probabilidad de ser cero (tend_pvalor) y
# los 3 cambios más probables en tendencia y estacionalidad.
# Después grafica BEAST en el píxel de cada estación.
# Salidas en output/beast/

library(Rbeast)
library(terra)
library(tidyverse)
library(parallel)
n_cores <- detectCores() - 1

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")
source("R/datosPixel.R")
source("R/applyBeast.R")

variables <- lapply(names(CARPETAS_FLDAS), function(v)
  list(nombre = v, carpeta = CARPETAS_FLDAS[[v]]))

dir.create("output/beast", recursive = TRUE, showWarnings = FALSE)

for (var in variables) {
  cat("Procesando:", var$nombre, "\n")
  
  datos  <- importData(var$carpeta)
  coords <- datos[, 1:2]
  valores <- datos[, -(1:2)]
  
  # Convertir unidades si corresponde
  if (seConvierte(var$nombre)) {
    fechas  <- as.Date(colnames(valores))
    valores <- t(apply(valores, 1, function(fila) {
      convertir_unidades(fila, variable = var$nombre, fechas = fechas)
    }))
    colnames(valores) <- as.character(fechas)
  }
  
  # Aplicar BEAST píxel a píxel en paralelo
  cat("  Corriendo BEAST en", nrow(valores), "píxeles con", n_cores, "núcleos...\n")
  tiempo_inicio <- proc.time()
  
  cl <- makeCluster(n_cores)
  clusterEvalQ(cl, library(Rbeast))
  clusterExport(cl, "applyBEAST")
  
  resultados <- t(parApply(cl, valores, 1, function(fila) {
    tryCatch(
      applyBEAST(as.numeric(fila)),
      error = function(e) rep(NA, 16)
    )
  }))
  
  stopCluster(cl)
  colnames(resultados) <- names(applyBEAST(as.numeric(valores[1, ])))
  
  tiempo_total <- round((proc.time() - tiempo_inicio)["elapsed"] / 60, 1)
  cat("  Tiempo total:", tiempo_total, "minutos\n")
  
  # Armar data frame con coordenadas y resultados
  df <- data.frame(coords, resultados)
  r  <- rast(df, crs = "EPSG:4326")
  
  # Guardar raster completo
  writeRaster(r,
              paste0("output/beast/", var$nombre, "_beast.tif"),
              overwrite = TRUE)
  
  cat("  Guardado:", var$nombre, "_beast.tif\n")
}



# ── GRÁFICOS DE PÍXELES CON ESTACIONES ──────────────────────────────────────

carpetas_fldas <- CARPETAS_FLDAS
estaciones     <- cargarEstaciones()

dir.create("output/beast/estaciones", recursive = TRUE, showWarnings = FALSE)

for (est in estaciones) {
  for (var in names(carpetas_fldas)) {
    
    cat("Graficando:", est$nombre, "-", var, "\n")
    
    nombre_archivo <- paste0("output/beast/estaciones/", 
                             est$id, "_", var, "_beast.png")
    
    png(nombre_archivo, width = 1200, height = 800, res = 120)
    graficarBEAST(coord_x       = est$x,
                  coord_y       = est$y,
                  variable      = var,
                  nombre_carpeta = carpetas_fldas[[var]])
    dev.off()
    
    cat("  Guardado:", nombre_archivo, "\n")
  }
}
