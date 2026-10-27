# PASO 1 - PREPROCESAMIENTO
# Para cada estación y variable (PP, ET, T y TS = temperatura de suelo):
#   1. Lee los datos diarios de campo, les aplica el control de calidad
#      (R/controlCalidad.R) y los pasa a valores mensuales:
#        - fechas repetidas: se deja una (si los valores difieren, queda NA)
#        - PP y ET: valores negativos -> NA (también en FLDAS)
#        - temperaturas OMIXOM: máxima <= mínima -> NA
#   2. Descarta los meses incompletos (UMBRAL_FALTANTES, en R/config.R).
#   3. Marca outliers con el test de Tukey (leves: 1.5·RIC; extremos: 3·RIC)
#      y descarta los meses anotados a mano en EXCLUIR_MESES (R/config.R).
#   4. Extrae la serie FLDAS del píxel más cercano y la pasa a las mismas unidades
#      (PP y ET: kg/m²/s -> mm/mes; T y TS: K -> °C).
#      TS: temperatura de suelo de campo (OMIXOM) vs. FLDAS SoilTemp 0-10 cm
#      (o RadT, según CARPETA_TS_VALIDACION en R/config.R - BORRADOR).
#   5. Junta ambas series por fecha (solo meses con dato en las dos fuentes).
# Salidas en output/preprocesado/:
#   series.csv              series mensuales de todas las estaciones y variables
#                           (id, variable, fecha, valor_campo, valor_fldas),
#                           listas para los pasos 2 y 3
#   preprocesamiento.xlsx   hojas "Resumen faltantes" (meses conservados y
#                           descartados por estación), "Control de calidad"
#                           (datos diarios corregidos) y "Outliers" (meses
#                           marcados por el test de Tukey, para revisar)

library(tidyverse)
library(readxl)
library(terra)
library(openxlsx)

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")
source("R/controlCalidad.R")
source("R/agregarMensual.R")
source("R/datosCampo.R")
source("R/datosOMIXOM.R")
source("R/datosPixel.R")
source("R/outliers.R")
source("R/escribirExcel.R")

dir.create("output/preprocesado", recursive = TRUE, showWarnings = FALSE)

estaciones <- cargarEstaciones()

# Nombre de cada variable en los archivos de campo
nombre_omixom <- list(pp = "Precipitación", et = "Evapotranspiración", t = "Temperatura",
                      ts = "Temperatura de suelo")
nombre_csv    <- list(pp = "PP", et = "ET", t = "T")

leerCampo <- function(est, variable) {
  if (est$proveedor == "OMIXOM") {
    datosOMIXOM(est$archivo, variable = nombre_omixom[[variable]])
  } else {
    datosCampo(est$archivo, nombre_variable = nombre_csv[[variable]],
               proveedor = est$proveedor)
  }
}

resumen        <- list()
lista_control  <- list()
lista_outliers <- list()
lista_series   <- list()

for (var in VARIABLES_CAMPO) {

  cat("\n=== Variable:", toupper(var), "===\n")

  # Se importa FLDAS UNA sola vez por variable y se reutiliza para todas las estaciones
  # (TS: la carpeta se elige en R/config.R, CARPETA_TS_VALIDACION - BORRADOR)
  carpeta <- if (var == "ts") CARPETA_TS_VALIDACION else CARPETAS_FLDAS[[var]]
  cat("FLDAS:", carpeta, "\n")
  fldas <- importData(carpeta)

  for (est in estaciones) {
    if (!var %in% est$vars) next
    cat("Procesando:", est$nombre, "\n")

    tryCatch({
      # 1. Campo: datos diarios -> control de calidad -> serie mensual
      control <- controlCalidad(leerCampo(est, var), negativos = var %in% c("pp", "et"))
      if (nrow(control$problemas) > 0) {
        lista_control[[length(lista_control) + 1]] <- control$problemas %>%
          mutate(id = est$id, estacion = est$nombre, variable = toupper(var), .before = 1)
        cat("  Control de calidad:", nrow(control$problemas), "datos diarios corregidos\n")
      }
      campo <- agregarMensual(control$datos$fecha, control$datos$valor,
                              funcion = if (var %in% c("pp", "et")) "sum" else "mean")

      # 2. Filtro de meses incompletos (umbral en R/config.R)
      campo_ok <- campo %>%
        filter(porcentaje_completo >= UMBRAL_FALTANTES,
               porcentaje_na       <= UMBRAL_FALTANTES)

      # 3a. Outliers (test de Tukey) sobre la serie de campo. Solo se marcan.
      marcados <- bind_cols(campo_ok %>% select(fecha, valor_campo),
                            outliers(campo_ok$valor_campo)) %>%
        filter(!is.na(tipo))

      # 3b. Meses descartados a mano en R/config.R
      a_excluir <- EXCLUIR_MESES[[var]][[est$id]]
      if (is.null(a_excluir)) a_excluir <- character(0)
      no_encontrados <- setdiff(a_excluir, format(campo_ok$fecha, "%Y-%m"))
      if (length(no_encontrados) > 0) {
        cat("  AVISO: en EXCLUIR_MESES hay meses que no están en la serie:",
            paste(no_encontrados, collapse = ", "), "\n")
      }
      excluidos <- format(campo_ok$fecha, "%Y-%m") %in% a_excluir
      campo_ok  <- campo_ok[!excluidos, ]

      if (nrow(marcados) > 0) {
        lista_outliers[[length(lista_outliers) + 1]] <- marcados %>%
          mutate(id = est$id, estacion = est$nombre, variable = toupper(var),
                 excluido = format(fecha, "%Y-%m") %in% a_excluir, .before = 1)
        cat("  Outliers:", sum(marcados$tipo == "leve"), "leves,",
            sum(marcados$tipo == "extremo"), "extremos\n")
      }

      # 4. FLDAS en el píxel de la estación
      serie_fldas <- datosPixel(est$x, est$y, variable = var, datos = fldas)

      # PP y ET (mm/mes): valores negativos -> NA
      if (var %in% c("pp", "et")) {
        negativos <- !is.na(serie_fldas$valor_fldas) & serie_fldas$valor_fldas < 0
        if (any(negativos)) {
          cat("  FLDAS:", sum(negativos), "meses con valor negativo tomados como NA\n")
          serie_fldas$valor_fldas[negativos] <- NA
        }
      }

      # 5. Unir por fecha (solo meses presentes en ambas)
      datos <- inner_join(campo_ok %>% select(fecha, valor_campo),
                          serie_fldas, by = "fecha") %>%
        filter(!is.na(valor_campo), !is.na(valor_fldas)) %>%
        arrange(fecha)

      lista_series[[length(lista_series) + 1]] <- datos %>%
        mutate(id = est$id, variable = var, .before = 1)

      resumen[[length(resumen) + 1]] <- tibble(
        id                 = est$id,
        estacion           = est$nombre,
        variable           = toupper(var),
        inicio_campo       = min(campo$fecha),
        fin_campo          = max(campo$fecha),
        meses_campo        = nrow(campo),
        meses_incompletos  = nrow(campo) - nrow(campo_ok) - sum(excluidos),
        meses_excluidos    = sum(excluidos),
        meses_validos      = nrow(campo_ok),
        meses_comun_fldas  = nrow(datos)
      )
      cat("  Meses válidos:", nrow(campo_ok), "de", nrow(campo),
          "| en común con FLDAS:", nrow(datos), "\n")

    }, error = function(e) cat("  ERROR:", conditionMessage(e), "\n"))
  }
}

# ─── SALIDAS ────────────────────────────────────────────────────────────────

# 1. Series mensuales de todas las estaciones en un solo archivo
write.csv(bind_rows(lista_series), "output/preprocesado/series.csv", row.names = FALSE)

# 2. Resumen de faltantes
tabla_resumen <- bind_rows(resumen)
print(tabla_resumen, n = Inf)
tabla_resumen <- tabla_resumen %>%
  rename("Estación (id)" = id, "Estación" = estacion, "Variable" = variable,
         "Inicio campo" = inicio_campo, "Fin campo" = fin_campo,
         "Meses campo" = meses_campo, "Meses incompletos" = meses_incompletos,
         "Meses excluidos (config)" = meses_excluidos, "Meses válidos" = meses_validos,
         "Meses en común con FLDAS" = meses_comun_fldas)

# 3. Control de calidad (datos diarios corregidos)
tabla_control <- bind_rows(lista_control)
if (nrow(tabla_control) > 0) {
  cat("\nControl de calidad:\n")
  print(count(tabla_control, variable, id, control), n = Inf)
  tabla_control <- tabla_control %>%
    arrange(variable, id, fecha) %>%
    mutate(fecha = format(fecha, "%Y-%m-%d")) %>%
    rename("Estación (id)" = id, "Estación" = estacion, "Variable" = variable,
           "Fecha" = fecha, "Control" = control, "Detalle" = detalle)
}

# 4. Outliers (los extremos se resaltan en rojo claro)
tabla_outliers <- bind_rows(lista_outliers)
if (nrow(tabla_outliers) > 0) {
  tabla_outliers <- tabla_outliers %>%
    mutate(across(where(is.numeric), ~ round(.x, 2)),
           fecha = format(fecha, "%Y-%m")) %>%
    arrange(variable, tipo, id, fecha) %>%   # extremos primero
    rename("Estación (id)" = id, "Estación" = estacion, "Variable" = variable,
           "Excluido en config" = excluido, "Mes" = fecha, "Valor" = valor_campo,
           "Tipo" = tipo, "Lado" = lado, "Q1" = q1, "Q3" = q3, "RIC" = ric,
           "Lím. inf. leve" = lim_inf_leve, "Lím. sup. leve" = lim_sup_leve,
           "Lím. inf. extremo" = lim_inf_extremo, "Lím. sup. extremo" = lim_sup_extremo)
  cat("\nOutliers marcados:", sum(tabla_outliers$Tipo == "leve"), "leves y",
      sum(tabla_outliers$Tipo == "extremo"), "extremos\n")
}

escribirExcel(
  list("Resumen faltantes" = tabla_resumen, "Control de calidad" = tabla_control,
       "Outliers" = tabla_outliers),
  "output/preprocesado/preprocesamiento.xlsx",
  resaltar = list("Outliers" = if (nrow(tabla_outliers) > 0) which(tabla_outliers$Tipo == "extremo"))
)

cat("\nListo. Resultados en output/preprocesado/ (series.csv y preprocesamiento.xlsx)\n")
