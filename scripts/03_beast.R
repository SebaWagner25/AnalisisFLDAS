library(Rbeast)
library(terra)
library(tidyverse)
library(parallel)
n_cores <- detectCores() - 1

source("R/importData.R")
source("R/convertirUnidades.R")
source("R/applyBEAST.R")

variables <- list(
  list(nombre = "pp",        carpeta = "FLDAS_Rainf_f_tavg_comp"),
  list(nombre = "et",        carpeta = "FLDAS_Evap_tavg_comp"),
  list(nombre = "t",         carpeta = "FLDAS_Tair_f_tavg_comp"),
  list(nombre = "hs_0_10",   carpeta = "FLDAS_SoilMoi00_10cm_tavg_comp"),
  list(nombre = "hs_10_40",  carpeta = "FLDAS_SoilMoi10_40cm_tavg_comp"),
  list(nombre = "hs_40_100", carpeta = "FLDAS_SoilMoi40_100cm_tavg_comp"),
  list(nombre = "hs_100_200",carpeta = "FLDAS_SoilMoi100_200cm_tavg_comp")
)

dir.create("output/beast", recursive = TRUE, showWarnings = FALSE)

for (var in variables) {
  cat("Procesando:", var$nombre, "\n")
  
  datos  <- importData(var$carpeta)
  coords <- datos[, 1:2]
  valores <- datos[, -(1:2)]
  
  # Convertir unidades si corresponde
  if (var$nombre %in% c("pp", "et", "t")) {
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

carpetas_fldas <- list(
  pp        = "FLDAS_Rainf_f_tavg_comp",
  et        = "FLDAS_Evap_tavg_comp",
  t         = "FLDAS_Tair_f_tavg_comp",
  hs_0_10   = "FLDAS_SoilMoi00_10cm_tavg_comp",
  hs_10_40  = "FLDAS_SoilMoi10_40cm_tavg_comp",
  hs_40_100 = "FLDAS_SoilMoi40_100cm_tavg_comp",
  hs_100_200= "FLDAS_SoilMoi100_200cm_tavg_comp"
)

estaciones_df <- read.csv("estaciones.csv", stringsAsFactors = FALSE)
estaciones    <- split(estaciones_df, seq(nrow(estaciones_df))) %>%
  map(function(fila) list(
    id        = fila$id,
    nombre    = fila$nombre,
    x         = fila$x,
    y         = fila$y,
    vars      = strsplit(as.character(fila$vars), ";")[[1]]
  ))

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
