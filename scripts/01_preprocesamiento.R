# PASO 1 - PREPROCESAMIENTO
# Para cada estación y variable (PP, ET, T):
#   1. Lee los datos diarios de campo y los pasa a valores mensuales.
#   2. Descarta los meses incompletos (UMBRAL_FALTANTES, en R/config.R).
#   3. Extrae la serie FLDAS del píxel más cercano y la pasa a las mismas unidades
#      (PP y ET: kg/m²/s -> mm/mes; T: K -> °C).
#   4. Junta ambas series por fecha (solo meses con dato en las dos fuentes).
# Salidas en output/preprocesado/:
#   <id>_<variable>.csv     serie mensual lista para los pasos 2 y 3
#   resumen_faltantes.csv   cuántos meses se conservaron y descartaron por estación

library(tidyverse)
library(readxl)
library(terra)

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")
source("R/agregarMensual.R")
source("R/datosCampo.R")
source("R/datosOMIXOM.R")
source("R/datosPixel.R")

dir.create("output/preprocesado", recursive = TRUE, showWarnings = FALSE)

estaciones <- cargarEstaciones()

# Nombre de cada variable en los archivos de campo
nombre_omixom <- list(pp = "Precipitación", et = "Evapotranspiración", t = "Temperatura")
nombre_csv    <- list(pp = "PP", et = "ET", t = "T")

leerCampo <- function(est, variable) {
  if (est$proveedor == "OMIXOM") {
    datosOMIXOM(est$archivo, variable = nombre_omixom[[variable]])
  } else {
    datosCampo(est$archivo, nombre_variable = nombre_csv[[variable]],
               proveedor = est$proveedor)
  }
}

resumen <- list()

for (var in VARIABLES_CAMPO) {

  cat("\n=== Variable:", toupper(var), "===\n")

  # Se importa FLDAS UNA sola vez por variable y se reutiliza para todas las estaciones
  fldas <- importData(CARPETAS_FLDAS[[var]])

  for (est in estaciones) {
    if (!var %in% est$vars) next
    cat("Procesando:", est$nombre, "\n")

    tryCatch({
      # 1. Campo: serie mensual con fracción de días faltantes
      campo <- leerCampo(est, var)

      # 2. Filtro de meses incompletos (umbral en R/config.R)
      campo_ok <- campo %>%
        filter(porcentaje_completo >= UMBRAL_FALTANTES,
               porcentaje_na       <= UMBRAL_FALTANTES)

      # 3. FLDAS en el píxel de la estación
      serie_fldas <- datosPixel(est$x, est$y, variable = var, datos = fldas)

      # 4. Unir por fecha (solo meses presentes en ambas)
      datos <- inner_join(campo_ok %>% select(fecha, valor_campo),
                          serie_fldas, by = "fecha") %>%
        filter(!is.na(valor_campo), !is.na(valor_fldas)) %>%
        arrange(fecha)

      write.csv(datos, file.path("output/preprocesado", paste0(est$id, "_", var, ".csv")),
                row.names = FALSE)

      resumen[[length(resumen) + 1]] <- tibble(
        id                 = est$id,
        estacion           = est$nombre,
        variable           = toupper(var),
        inicio_campo       = min(campo$fecha),
        fin_campo          = max(campo$fecha),
        meses_campo        = nrow(campo),
        meses_descartados  = nrow(campo) - nrow(campo_ok),
        meses_validos      = nrow(campo_ok),
        meses_comun_fldas  = nrow(datos)
      )
      cat("  Meses válidos:", nrow(campo_ok), "de", nrow(campo),
          "| en común con FLDAS:", nrow(datos), "\n")

    }, error = function(e) cat("  ERROR:", conditionMessage(e), "\n"))
  }
}

tabla_resumen <- bind_rows(resumen)
print(tabla_resumen, n = Inf)
write_csv2(tabla_resumen, "output/preprocesado/resumen_faltantes.csv")
cat("\nListo. Series guardadas en output/preprocesado/\n")
