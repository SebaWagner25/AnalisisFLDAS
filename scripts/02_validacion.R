library(tidyverse)
library(readxl)
library(robustbase)
library(terra)

source("R/importData.R")
source("R/datosPixel.R")
source("R/convertirUnidades.R")
source("R/datosCampo.R")
source("R/datosOMIXOM.R")

# ─── CONFIGURACIÓN DE ESTACIONES ────────────────────────────────────────────

estaciones_df <- read.csv("estaciones.csv", stringsAsFactors = FALSE)

estaciones <- split(estaciones_df, seq(nrow(estaciones_df))) %>%
  map(function(fila) {
    list(
      id       = fila$id,
      nombre   = fila$nombre,
      proveedor = fila$proveedor,
      archivo = file.path("data", 
                          ifelse(fila$proveedor == "OMIXOM", 
                                 "DATOS_OMIXOM", 
                                 "DATOS_INTA_SMN"), 
                          fila$archivo),
      x        = fila$x,
      y        = fila$y,
      vars     = strsplit(fila$vars, ";")[[1]]
    )
  })

carpetas_fldas <- list(
  pp = "FLDAS_Rainf_f_tavg_comp",
  et = "FLDAS_Evap_tavg_comp"
)

# ─── FUNCIONES AUXILIARES ───────────────────────────────────────────────────

cargar_campo <- function(estacion, variable) {
  var_omixom <- ifelse(variable == "pp", "Precipitación", "Evapotranspiración")
  
  if (estacion$proveedor == "OMIXOM") {
    datosOMIXOM(estacion$archivo, variable = var_omixom)
  } else {
    nombre_col <- ifelse(variable == "pp", "PP", "ET")
    datosCampo(estacion$archivo, 
               nombre_variable = nombre_col,
               proveedor = estacion$proveedor)
  }
}

analizar <- function(datos, estacion, variable) {
  
  # Normalidad
  sw_campo <- shapiro.test(datos$valor_campo)
  sw_fldas <- shapiro.test(datos$valor_fldas)
  
  # Correlación
  sp <- cor.test(datos$valor_campo, datos$valor_fldas, method = "spearman")
  ke <- cor.test(datos$valor_campo, datos$valor_fldas, method = "kendall")
  
  # Regresión robusta
  lmrob_fit <- lmrob(valor_campo ~ valor_fldas, data = datos)
  sum_lmrob  <- summary(lmrob_fit)
  
  list(
    estacion   = estacion$nombre,
    id         = estacion$id,
    variable   = toupper(variable),
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

graficar <- function(datos, estacion, variable, lmrob_fit) {
  
  lim <- range(c(datos$valor_campo, datos$valor_fldas), na.rm = TRUE)
  
  p <- ggplot(datos, aes(x = valor_fldas, y = valor_campo)) +
    geom_point(size = 1.2, color = "#1B2A49") +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray40") +
    geom_abline(intercept = coef(lmrob_fit)[1], slope = coef(lmrob_fit)[2],
                color = "#B22222", linewidth = 1) +
    coord_fixed(ratio = 1, xlim = lim, ylim = lim) +
    labs(
      title    = paste(estacion$nombre, "-", toupper(variable)),
      x        = "FLDAS (mm/mes)",
      y        = "Campo (mm/mes)",
      caption  = paste0("n = ", nrow(datos))
    ) +
    theme_light(base_size = 13) +
    theme(
      plot.title    = element_text(hjust = 0.5, face = "bold"),
      plot.caption  = element_text(hjust = 1),
      axis.title    = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )
  
  nombre_archivo <- paste0("output/validacion/", estacion$id, "_", variable, ".png")
  ggsave(nombre_archivo, plot = p, width = 6, height = 6, dpi = 300)
  p
}

# ─── LOOP PRINCIPAL ─────────────────────────────────────────────────────────

dir.create("output/validacion", recursive = TRUE, showWarnings = FALSE)

resultados <- list()

for (est in estaciones) {
  for (var in est$vars) {
    
    cat("Procesando:", est$nombre, "-", var, "\n")
    
    tryCatch({
      # Cargar datos
      datos_campo <- cargar_campo(est, var)
      datos_fldas <- datosPixel(coord_x = est$x, coord_y = est$y,
                                variable = var,
                                nombre_carpeta = carpetas_fldas[[var]])
      
      datos <- merge(datos_campo, datos_fldas, by = "fecha", all = FALSE)
      cat("  Filas después del merge:", nrow(datos), "\n")
      datos$fecha <- NULL
      
      # Analizar
      res       <- analizar(datos, est, var)
      lmrob_fit <- lmrob(valor_campo ~ valor_fldas, data = datos)
      
      # Graficar
      graficar(datos, est, var, lmrob_fit)
      
      resultados[[length(resultados) + 1]] <- res
      
    }, error = function(e) {
      cat("  ERROR:", conditionMessage(e), "\n")
    })
  }
}

# ─── TABLA RESUMEN ──────────────────────────────────────────────────────────

tabla <- bind_rows(resultados) %>%
  select(estacion, variable, n, spearman, sp_pvalor, kendall, ke_pvalor,
         pendiente, r2_adj, bias, rmse) %>%
  rename(
    "Estación"          = estacion,
    "Variable"          = variable,
    "n"                 = n,
    "ρ Spearman"        = spearman,
    "p-valor (Sp)"      = sp_pvalor,
    "τ Kendall"         = kendall,
    "p-valor (Ke)"      = ke_pvalor,
    "Pendiente"         = pendiente,
    "R² ajustado"       = r2_adj,
    "BIAS"              = bias,
    "RMSE"              = rmse
  )

print(tabla)

write.csv(tabla, "output/validacion/tabla_resultados.csv", row.names = FALSE)
cat("\nTabla guardada en output/validacion/tabla_resultados.csv\n")
