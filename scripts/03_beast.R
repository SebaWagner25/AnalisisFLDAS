library(Rbeast)
library(terra)
library(tidyverse)

source("R/importData.R")
source("R/convertirUnidades.R")
source("R/applyBEAST.R")

variables <- list(
  list(nombre = "pp",        carpeta = "FLDAS_Rainf_f_tavg_comp"),
  list(nombre = "et",        carpeta = "FLDAS_Evap_tavg_comp"),
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
  if (var$nombre %in% c("pp", "et")) {
    fechas  <- as.Date(colnames(valores))
    valores <- t(apply(valores, 1, function(fila) {
      convertir_unidades(fila, variable = var$nombre, fechas = fechas)
    }))
    colnames(valores) <- as.character(fechas)
  }
  
  # Aplicar BEAST píxel a píxel
  cat("  Corriendo BEAST en", nrow(valores), "píxeles...\n")
  
  resultados <- t(apply(valores, 1, function(fila) {
    tryCatch(
      applyBEAST(as.numeric(fila)),
      error = function(e) rep(NA, 14)
    )
  }))
  
  # Armar data frame con coordenadas y resultados
  df <- data.frame(coords, resultados)
  r  <- rast(df, crs = "EPSG:4326")
  
  # Guardar raster completo
  writeRaster(r,
              paste0("output/beast/", var$nombre, "_beast.tif"),
              overwrite = TRUE)
  
  cat("  Guardado:", var$nombre, "_beast.tif\n")
}