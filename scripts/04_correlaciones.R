library(terra)
library(tidyverse)

source("R/importData.R")
source("R/convertirUnidades.R")

# ── CONFIGURACIÓN ────────────────────────────────────────────────────────────

variables <- list(
  pp         = "FLDAS_Rainf_f_tavg_comp",
  et         = "FLDAS_Evap_tavg_comp",
  hs_0_10    = "FLDAS_SoilMoi00_10cm_tavg_comp",
  hs_10_40   = "FLDAS_SoilMoi10_40cm_tavg_comp",
  hs_40_100  = "FLDAS_SoilMoi40_100cm_tavg_comp",
  hs_100_200 = "FLDAS_SoilMoi100_200cm_tavg_comp"
)

espesores <- list(
  hs_0_10    = 10,
  hs_10_40   = 30,
  hs_40_100  = 60,
  hs_100_200 = 100
)

combinaciones <- list(
  c("pp",        "et"),
  c("pp",        "hs_0_10"),
  c("pp",        "hs_10_40"),
  c("pp",        "hs_40_100"),
  c("pp",        "hs_100_200"),
  c("et",        "hs_0_10"),
  c("et",        "hs_10_40"),
  c("et",        "hs_40_100"),
  c("et",        "hs_100_200"),
  c("hs_0_10",   "hs_10_40"),
  c("hs_0_10",   "hs_40_100"),
  c("hs_0_10",   "hs_100_200"),
  c("hs_10_40",  "hs_40_100"),
  c("hs_10_40",  "hs_100_200"),
  c("hs_40_100", "hs_100_200")
)

estaciones_df <- read.csv("estaciones.csv", stringsAsFactors = FALSE)
dir.create("output/correlaciones", recursive = TRUE, showWarnings = FALSE)

# ── CARGAR CADA VARIABLE Y EXTRAER PÍXELES DE ESTACIONES ────────────────────

cat("Cargando variables FLDAS...\n")
series <- list()  # series[[variable]][[estacion_id]] = vector numérico

for (nombre in names(variables)) {
  cat("  Cargando:", nombre, "\n")
  
  datos <- importData(variables[[nombre]])
  datos <- as.data.frame(datos)
  fechas <- as.Date(colnames(datos)[-(1:2)])
  
  series[[nombre]] <- list()
  
  for (i in 1:nrow(estaciones_df)) {
    est <- estaciones_df[i, ]
    
    fila <- datos %>%
      filter(abs(x - est$x) < 0.05, abs(y - est$y) < 0.05) %>%
      select(-x, -y)
    
    if (nrow(fila) == 0) next
    
    y <- as.numeric(fila)
    
    # Convertir unidades
    if (nombre %in% c("pp", "et")) {
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