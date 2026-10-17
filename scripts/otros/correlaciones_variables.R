# EXTRA (fuera de los pasos del informe) - CORRELACIONES ENTRE VARIABLES FLDAS
# En el píxel de cada estación, correlaciona las variables FLDAS entre sí
# (Spearman y Kendall) y promedia entre estaciones.
# Salidas en output/correlaciones/

library(terra)
library(tidyverse)

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")
source("R/datosPixel.R")

# ── CONFIGURACIÓN ────────────────────────────────────────────────────────────

variables <- CARPETAS_FLDAS
espesores <- ESPESORES_HS

combinaciones <- list(
  c("pp",        "et"),
  c("pp",        "t"),
  c("pp",        "hs_0_10"),
  c("pp",        "hs_10_40"),
  c("pp",        "hs_40_100"),
  c("pp",        "hs_100_200"),
  c("et",        "t"),
  c("et",        "hs_0_10"),
  c("et",        "hs_10_40"),
  c("et",        "hs_40_100"),
  c("et",        "hs_100_200"),
  c("t",         "hs_0_10"),
  c("t",         "hs_10_40"),
  c("t",         "hs_40_100"),
  c("t",         "hs_100_200"),
  c("hs_0_10",   "hs_10_40"),
  c("hs_0_10",   "hs_40_100"),
  c("hs_0_10",   "hs_100_200"),
  c("hs_10_40",  "hs_40_100"),
  c("hs_10_40",  "hs_100_200"),
  c("hs_40_100", "hs_100_200")
)

estaciones_df <- read.csv("data/estaciones.csv", stringsAsFactors = FALSE,
                          fileEncoding = "UTF-8-BOM")
dir.create("output/correlaciones", recursive = TRUE, showWarnings = FALSE)

# ── CARGAR CADA VARIABLE Y EXTRAER PÍXELES DE ESTACIONES ────────────────────

cat("Cargando variables FLDAS...\n")
series <- list()  # series[[variable]][[estacion_id]] = vector numérico

for (nombre in names(variables)) {
  cat("  Cargando:", nombre, "\n")
  
  datos  <- importData(variables[[nombre]])
  fechas <- as.Date(colnames(datos)[-(1:2)])
  
  series[[nombre]] <- list()
  
  for (i in 1:nrow(estaciones_df)) {
    est <- estaciones_df[i, ]
    
    # Píxel más cercano a la estación (ver R/datosPixel.R)
    i <- tryCatch(pixelCercano(datos, est$x, est$y), error = function(e) NA)
    if (is.na(i)) next
    
    y <- as.numeric(datos[i, -(1:2)])
    
    # Convertir unidades
    if (nombre %in% c("pp", "et", "t")) {
      y <- convertir_unidades(y, variable = nombre, fechas = fechas)
    } else {
      y <- convertir_unidades(y, variable = "hs", fechas = fechas,
                              espesor_cm = espesores[[nombre]])
    }
    
    series[[nombre]][[est$id]] <- data.frame(fecha = fechas, valor = y)
  }
}

# ── CALCULAR CORRELACIONES POR ESTACIÓN ──────────────────────────────────────

cat("Calculando correlaciones...\n")
resultados <- list()

for (est in estaciones_df$id) {
  for (comb in combinaciones) {
    var1 <- comb[1]
    var2 <- comb[2]
    df1 <- series[[var1]][[est]]
    df2 <- series[[var2]][[est]]
    
    if (is.null(df1) || is.null(df2)) next
    
    # Alinear por fecha
    df <- inner_join(df1, df2, by = "fecha", suffix = c("_1", "_2"))
    
    if (nrow(df) < 3) next
    
    sp <- cor.test(df$valor_1, df$valor_2, method = "spearman")
    ke <- cor.test(df$valor_1, df$valor_2, method = "kendall")
    
    resultados[[length(resultados) + 1]] <- data.frame(
      estacion  = est,
      var1      = var1,
      var2      = var2,
      n         = nrow(df),
      spearman  = round(sp$estimate, 3),
      sp_pvalor = round(sp$p.value, 4),
      kendall   = round(ke$estimate, 3),
      ke_pvalor = round(ke$p.value, 4)
    )
  }
}

tabla_estaciones <- bind_rows(resultados)

# ── PROMEDIO ENTRE ESTACIONES ────────────────────────────────────────────────

tabla_promedio <- tabla_estaciones %>%
  group_by(var1, var2) %>%
  summarise(
    spearman_medio  = round(mean(spearman,  na.rm = TRUE), 3),
    spearman_sd     = round(sd(spearman,    na.rm = TRUE), 3),
    kendall_medio   = round(mean(kendall,   na.rm = TRUE), 3),
    kendall_sd      = round(sd(kendall,     na.rm = TRUE), 3),
    .groups = "drop"
  )

# ── GUARDAR ──────────────────────────────────────────────────────────────────

write.csv(tabla_estaciones, "output/correlaciones/correlaciones_por_estacion.csv",
          row.names = FALSE)
write.csv(tabla_promedio,   "output/correlaciones/correlaciones_promedio.csv",
          row.names = FALSE)

cat("Listo. Resultados guardados en output/correlaciones/\n")
print(tabla_promedio)