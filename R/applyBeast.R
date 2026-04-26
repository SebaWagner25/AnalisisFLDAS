applyBEAST <- function(y, umbral_cp = 0.5, umbral_tend_cero = 0.05, max_cp = 3) {
  
  # Correr BEAST
  o <- beast(y,
             start   = 1982,
             deltat  = 1/12,
             season  = "harmonic",
             period  = 12,
             quiet   = TRUE)
  
  # ── TENDENCIA ────────────────────────────────────────────────────
  # Pendiente media
  tend_pendiente <- mean(o$trend$slp, na.rm = TRUE)
  
  # Significancia: probabilidad de que la pendiente NO sea cero
  # slpSgnZeroPr = prob de pendiente = 0, así que 1 - eso = prob de tendencia real
  tend_pvalor <- mean(o$trend$slpSgnZeroPr, na.rm = TRUE)
  
  # Changepoints de tendencia significativos
  cp_tend_validos <- which(!is.nan(o$trend$cpPr) & o$trend$cpPr >= umbral_cp)
  cp_tend_fecha   <- o$trend$cp[cp_tend_validos]
  cp_tend_prob    <- o$trend$cpPr[cp_tend_validos]
  
  # Ordenar por probabilidad descendente
  if (length(cp_tend_prob) > 0) {
    ord           <- order(cp_tend_prob, decreasing = TRUE)
    cp_tend_fecha <- cp_tend_fecha[ord]
    cp_tend_prob  <- cp_tend_prob[ord]
  }
  
  # Convertir año decimal a YYYYMM (ej: 2018.5 → 201807)
  decimal_a_yyyymm <- function(x) {
    anio <- floor(x)
    mes  <- round((x - anio) * 12) + 1
    as.integer(anio * 100 + mes)
  }
  
  cp_tend_fecha <- decimal_a_yyyymm(cp_tend_fecha)
  
  # Rellenar hasta max_cp con NA
  cp_tend_fecha <- c(cp_tend_fecha, rep(NA, max_cp))[1:max_cp]
  cp_tend_prob  <- c(cp_tend_prob,  rep(NA, max_cp))[1:max_cp]
  
  # ── ESTACIONALIDAD ───────────────────────────────────────────────
  cp_seas_validos <- which(!is.nan(o$season$cpPr) & o$season$cpPr >= umbral_cp)
  cp_seas_fecha   <- o$season$cp[cp_seas_validos]
  cp_seas_prob    <- o$season$cpPr[cp_seas_validos]
  
  if (length(cp_seas_prob) > 0) {
    ord           <- order(cp_seas_prob, decreasing = TRUE)
    cp_seas_fecha <- cp_seas_fecha[ord]
    cp_seas_prob  <- cp_seas_prob[ord]
  }
  
  cp_seas_fecha <- decimal_a_yyyymm(cp_seas_fecha)
  cp_seas_fecha <- c(cp_seas_fecha, rep(NA, max_cp))[1:max_cp]
  cp_seas_prob  <- c(cp_seas_prob,  rep(NA, max_cp))[1:max_cp]
  
  # ── RESULTADO ────────────────────────────────────────────────────
  c(
    tend_pendiente = tend_pendiente,
    tend_pvalor    = tend_pvalor,
    tend_cp1_fecha = cp_tend_fecha[1], tend_cp1_prob = cp_tend_prob[1],
    tend_cp2_fecha = cp_tend_fecha[2], tend_cp2_prob = cp_tend_prob[2],
    tend_cp3_fecha = cp_tend_fecha[3], tend_cp3_prob = cp_tend_prob[3],
    seas_cp1_fecha = cp_seas_fecha[1], seas_cp1_prob = cp_seas_prob[1],
    seas_cp2_fecha = cp_seas_fecha[2], seas_cp2_prob = cp_seas_prob[2],
    seas_cp3_fecha = cp_seas_fecha[3], seas_cp3_prob = cp_seas_prob[3],
    tend_ncp = length(cp_tend_validos),
    seas_ncp = length(cp_seas_validos)
  )
}

# ── GRAFICAR EN PIXELES PARTICULARES ────────────────────────────────────────────────────


graficarBEAST <- function(coord_x, coord_y, variable, nombre_carpeta, 
                          espesor_cm = NULL) {
  
  datos  <- importData(nombre_carpeta)
  datos  <- as.data.frame(datos)
  
  fila <- datos %>%
    filter(abs(x - coord_x) < 0.05, abs(y - coord_y) < 0.05) %>%
    select(-x, -y)
  
  y      <- as.numeric(fila)
  fechas <- as.Date(colnames(fila))
  
  if (variable %in% c("pp", "et")) {
    y <- convertir_unidades(y, variable = variable, fechas = fechas)
  }
  
  o <- beast(y,
             start   = 1982,
             deltat  = 1/12,
             season  = "harmonic",
             period  = 12,
             quiet   = TRUE)
  
  plot(o)
}


# USO DESDE CONSOLA: 

#source("R/importData.R")
#source("R/convertirUnidades.R")
#source("R/applyBEAST.R")
#graficarBEAST(coord_x = -65.37, coord_y = -33.75,
#              variable = "pp",
#              nombre_carpeta = "FLDAS_Rainf_f_tavg_comp")