# 01_descriptivo.R
library(terra)
library(tidyverse)

source("R/importData.R")

variables <- list(
  list(nombre = "pp",       carpeta = "FLDAS_Rainf_f_tavg_comp"),
  list(nombre = "et",       carpeta = "FLDAS_Evap_tavg_comp"),
  list(nombre = "hs_0_10",  carpeta = "FLDAS_SoilMoi00_10cm_tavg_comp"),
  list(nombre = "hs_10_40", carpeta = "FLDAS_SoilMoi10_40cm_tavg_comp"),
  list(nombre = "hs_40_100",carpeta = "FLDAS_SoilMoi40_100cm_tavg_comp"),
  list(nombre = "hs_100_200",carpeta = "FLDAS_SoilMoi100_200cm_tavg_comp")
)

dir.create("output/descriptivo", recursive = TRUE, showWarnings = FALSE)

for (var in variables) {
  cat("Procesando:", var$nombre, "\n")
  
  datos <- importData(var$carpeta)
  coords <- datos[, 1:2]
  valores <- datos[, -(1:2)]
  
  media  <- apply(valores, 1, mean, na.rm = TRUE)
  desvio <- apply(valores, 1, sd,   na.rm = TRUE)
  minimo <- apply(valores, 1, min,  na.rm = TRUE)
  maximo <- apply(valores, 1, max,  na.rm = TRUE)
  
  df <- data.frame(coords, media, desvio, minimo, maximo)
  r  <- rast(df, crs = "EPSG:4326")
  
  writeRaster(r, paste0("output/descriptivo/", var$nombre, "_descriptivo.tif"),
              overwrite = TRUE)
  
  cat("  Guardado:", var$nombre, "_descriptivo.tif\n")
}