library(terra)
library(tidyverse)
library(readxl)
library(robustbase)
library(lmtest)
source("R/importData.R")
source("R/datosPixel.R")
source("R/datosOMIXOM.R")
source("R/datosINTA.R")

# MISMO ANÁLISIS QUE analisis_corto.R, PERO CON TODAS LAS ESTACIONES JUNTAS

# CARPETA ET: FLDAS_Evap_tavg_comp
# CARPETA PP: FLDAS_Rainf_f_tavg_comp

rm(list = ls()[sapply(mget(ls(), envir = globalenv()), function(x) !is.function(x))])
cat("\014")

carpeta_fldas <- "FLDAS_Rainf_f_tavg_comp"

# Une los datos de campo de una estación con su píxel de FLDAS
unirEstacion <- function(datos_campo, coord_x, coord_y) {
  datos_fldas <- datosPixel(coord_x = coord_x, coord_y = coord_y, variable = "pp",
                            nombre_carpeta = carpeta_fldas)
  datos_est <- merge(datos_campo, datos_fldas, by = "fecha", all = FALSE)
  datos_est$fecha <- NULL
  datos_est
}

# UNA LÍNEA POR ESTACIÓN (completar coordenadas y descomentar las que falten)
datos <- rbind(
  unirEstacion(datosOMIXOM("data/raw_data/DATOS_OMIXOM/LaPaz.xlsx",
                           variable = "Precipitación"),
               coord_x = 65.05, coord_y = 32.25)
  #, unirEstacion(datosOMIXOM("data/raw_data/DATOS_OMIXOM/SanPedro.xlsx",
  #                           variable = "Precipitación"),
  #               coord_x = XX.XX, coord_y = XX.XX)
  #, unirEstacion(datosINTA("data/raw_data/DATOS_INTA_SMN/INTA_Tilisarao.csv",
  #                         nombre_variable = "PP", proveedor = "INTA"),
  #               coord_x = XX.XX, coord_y = XX.XX)
  #, unirEstacion(datosINTA("data/raw_data/DATOS_INTA_SMN/SMN_SanLuis.csv",
  #                         nombre_variable = "PP", proveedor = "SMN"),
  #               coord_x = XX.XX, coord_y = XX.XX)
)

attach(datos)

# PRE-ANALISIS
shapiro.test(valor_campo)
shapiro.test(valor_fldas)

# PRUEBA DE CORRELACIÓN NO PARAMÉTRICA
cor.test(valor_campo, valor_fldas, alternative = "two.sided", method = "spearman")
cor.test(valor_campo, valor_fldas, alternative = "two.sided", method = "kendall")

# MODELO LINEAL ROBUSTO
lmrobusto <- lmrob(valor_campo ~ valor_fldas, data = datos)
summary(lmrobusto)

plot(valor_fldas, valor_campo, main = "Todas las estaciones")
abline(lmrobusto, col = "blue", lwd = 2)
abline(a = 0, b = 1, col = "red", lty = 2)
legend("topleft", legend = c("y = x", "Ajuste robusto"),
       col = c("red", "blue"), lty = c(2, 1), lwd = 2)

detach(datos)