# PASO 4 - EVALUACIÓN INDIRECTA DE LA HUMEDAD DE SUELO DE FLDAS
# No hay mediciones de humedad de suelo en campo. Se compara un índice
# estandarizado de humedad de suelo (SSMI) de FLDAS con el índice estandarizado
# de precipitación (SPI) de las estaciones. La precipitación de FLDAS ya se
# validó en el paso 3. Dos análisis:
#   A. Capa 0-10 cm vs SPI-1 (Jung et al., 2020): sin quitar tendencias.
#   B. Columna 0-100 cm (capas 0-10 + 10-40 + 40-100) vs SPI de 1 a 12 meses
#      (Spennemann et al., 2015): series sin tendencia lineal, curva de
#      sensibilidad y resultados en la escala de máxima correlación regional.
#   En los dos, los análisis regionales no incluyen las estaciones de
#   EXCLUIR_GENERAL$hs (R/config.R); se informan solo por estación.
#   - Índices: spi() del paquete SPEI 1.7.2 (ver R/evaluacionHS.R).
#   - Estaciones: ESTACIONES_HS en R/config.R. Período: los meses de cada
#     estación en común con FLDAS (output/preprocesado/series.csv).
#   - Correlación con la misma regla de Shapiro-Wilk que scripts/03_validacion.R
#     (Pearson, o Spearman y Kendall) y su p-valor.
# Requiere haber corrido antes scripts/01_preprocesamiento.R.
# Salidas en output/evaluacion_hs/:
#   series_hs.png               A: SPI-1 y SSMI 0-10 cm en el tiempo, por estación
#   correlacion_mensual_hs.png  A: correlación por mes (promedio ± desvío entre estaciones)
#   sensibilidad_hs100.png      B: correlación según la escala del SPI
#   evaluacion_hs.xlsx          hojas de A (Índices, Por estación, Análisis regional,
#                               Normalidad, Por mes) y de B (0-100 ...)

library(tidyverse)
library(terra)
library(openxlsx)
library(SPEI)

if (packageVersion("SPEI") >= "1.8") {
  stop("Hace falta SPEI 1.7.2 (las 1.8.x dan -Inf en los meses sin lluvia). Instalar con: ",
       "remotes::install_github('sbegueria/SPEI@v1.7.2', upgrade = 'never')")
}

source("R/config.R")
source("R/importData.R")
source("R/convertirUnidades.R")
source("R/datosPixel.R")
source("R/validacion.R")
source("R/evaluacionHS.R")
source("R/escribirExcel.R")

dir.create("output/evaluacion_hs", recursive = TRUE, showWarnings = FALSE)

estaciones <- Filter(function(est) est$id %in% ESTACIONES_HS, cargarEstaciones())
nombre_est <- setNames(sapply(estaciones, `[[`, "nombre"), sapply(estaciones, `[[`, "id"))

pp <- read.csv("output/preprocesado/series.csv") %>%
  mutate(fecha = as.Date(fecha)) %>%
  filter(variable == "pp")

# Humedad de suelo de FLDAS de las tres primeras capas (se importa una vez)
capas  <- c("hs_0_10", "hs_10_40", "hs_40_100")
fldas  <- setNames(lapply(capas, function(capa) importData(CARPETAS_FLDAS[[capa]])), capas)

# Humedad de suelo (mm) de una capa en el píxel de la estación
hsCapa <- function(est, capa) {
  datosPixel(est$x, est$y, variable = "hs", espesor_cm = ESPESORES_HS[[capa]],
             datos = fldas[[capa]])
}

# Precipitación de campo y humedad de FLDAS de una estación, en los meses comunes
datosEstacion <- function(est, hs) {
  pp %>%
    filter(id == est$id) %>%
    select(fecha, pp_campo = valor_campo) %>%
    inner_join(hs, by = "fecha") %>%
    filter(!is.na(hs_fldas))
}

# Método según la regla de Shapiro-Wilk del paso 3 (normalidad: tabla con columna normal)
elegirMetodo <- function(normalidad) if (all(normalidad$normal)) "parametrico" else "no parametrico"
nombreCoef   <- function(metodo) if (metodo == "parametrico") "Pearson" else "Spearman"

# ═══ A. CAPA 0-10 cm vs SPI-1 (Jung et al., 2020) ═══════════════════════════
# valor_campo = SPI-1 de la estación, valor_fldas = SSMI de FLDAS (mismos
# nombres que en el paso 3, para usar las funciones de R/validacion.R)

series <- list()
for (est in estaciones) {
  series[[est$id]] <- datosEstacion(est, hsCapa(est, "hs_0_10") %>% rename(hs_fldas = valor_fldas)) %>%
    mutate(valor_campo = indiceEstandarizado(fecha, pp_campo, MIN_ANIOS_INDICE),
           valor_fldas = indiceEstandarizado(fecha, hs_fldas, MIN_ANIOS_INDICE)) %>%
    filter(!is.na(valor_campo), !is.na(valor_fldas))
  cat(est$nombre, ":", format(min(series[[est$id]]$fecha), "%Y-%m"), "a",
      format(max(series[[est$id]]$fecha), "%Y-%m"), "|", nrow(series[[est$id]]), "meses\n")
}

# A.1 Por estación
normalidad <- map_dfr(names(series), function(id) tibble(
  id         = id,
  n          = nrow(series[[id]]),
  sw_campo_p = pShapiro(series[[id]]$valor_campo),
  sw_fldas_p = pShapiro(series[[id]]$valor_fldas),
  normal     = sonNormales(series[[id]], ALFA_SHAPIRO)
))
metodo_est <- elegirMetodo(normalidad)
cat("A. Por estación: método", metodo_est, "\n")

tabla_est <- map_dfr(names(series), function(id)
  correlacion(series[[id]], metodo_est) %>% mutate(estacion = nombre_est[[id]], .before = 1))
tabla_mes <- map_dfr(names(series), function(id)
  correlacionPorMes(series[[id]], metodo_est) %>% mutate(estacion = nombre_est[[id]], .before = 1))

graficarSeriesHS(
  datos   = bind_rows(lapply(names(series), function(id)
              series[[id]] %>% mutate(estacion = nombre_est[[id]]))),
  coef    = tabla_est %>% transmute(estacion,
                                    etiqueta = paste(nombreCoef(metodo_est), "=", round(r, 2))),
  archivo = "output/evaluacion_hs/series_hs.png")

# Sin las estaciones excluidas de los análisis regionales (resume entre estaciones)
graficarCorrelacionMensualHS(tabla_mes %>% filter(!estacion %in% nombre_est[EXCLUIR_GENERAL$hs]),
                             archivo     = "output/evaluacion_hs/correlacion_mensual_hs.png",
                             nombre_coef = nombreCoef(metodo_est))

# A.2 General (todas las estaciones juntas, salvo las excluidas)
excluidas   <- EXCLUIR_GENERAL$hs
datos_todas <- bind_rows(lapply(names(series), function(id)
  series[[id]] %>% mutate(estacion = id))) %>%
  filter(!estacion %in% excluidas)

metodo_gen <- if (sonNormales(datos_todas, ALFA_SHAPIRO)) "parametrico" else "no parametrico"
cat("A. General (n =", nrow(datos_todas), "): método", metodo_gen, "\n")
tabla_gen <- correlacion(datos_todas, metodo_gen) %>%
  mutate(excluidas = paste(excluidas, collapse = ", "),
         n_estaciones = n_distinct(datos_todas$estacion), .before = 1)
tabla_mes <- bind_rows(tabla_mes, correlacionPorMes(datos_todas, metodo_gen) %>%
                         mutate(estacion = NOMBRE_REGIONAL, .before = 1))

# ═══ B. COLUMNA 0-100 cm vs SPI DE 1 A 12 MESES (Spennemann et al., 2015) ═══

datos_100 <- list()
for (est in estaciones) {
  # Humedad de 0-100 cm = suma de las tres capas (mm)
  hs100 <- map_dfr(capas, function(capa) hsCapa(est, capa)) %>%
    group_by(fecha) %>%
    summarise(hs_fldas = sum(valor_fldas))
  base  <- datosEstacion(est, hs100)
  ssmi  <- quitarTendencia(base$fecha, indiceEstandarizado(base$fecha, base$hs_fldas, MIN_ANIOS_INDICE))

  datos_100[[est$id]] <- map_dfr(ESCALAS_SPI, function(k) tibble(
    escala      = k,
    fecha       = base$fecha,
    valor_campo = quitarTendencia(base$fecha, indiceEstandarizado(base$fecha, base$pp_campo,
                                                                  MIN_ANIOS_INDICE, escala = k)),
    valor_fldas = ssmi
  )) %>% filter(!is.na(valor_campo), !is.na(valor_fldas))
}
todas_100 <- bind_rows(datos_100, .id = "id")

# B.1 Normalidad de cada estación y escala; un solo método para toda la curva
normalidad_100 <- todas_100 %>%
  group_by(id, escala) %>%
  summarise(n = n(), sw_campo_p = pShapiro(valor_campo), sw_fldas_p = pShapiro(valor_fldas),
            .groups = "drop") %>%
  mutate(normal = !is.na(sw_campo_p) & !is.na(sw_fldas_p) &
           sw_campo_p >= ALFA_SHAPIRO & sw_fldas_p >= ALFA_SHAPIRO)
metodo_100 <- elegirMetodo(normalidad_100)

# B.2 Curva de sensibilidad: correlación por estación y regional (sin las
#     estaciones excluidas) para cada escala
sensibilidad <- bind_rows(
  todas_100 %>% group_by(id, escala) %>% group_modify(~ correlacion(.x, metodo_100)) %>%
    ungroup() %>% mutate(estacion = unname(nombre_est[id]), .before = 1) %>% select(-id),
  todas_100 %>% filter(!id %in% excluidas) %>%
    group_by(escala) %>% group_modify(~ correlacion(.x, metodo_100)) %>%
    ungroup() %>% mutate(estacion = NOMBRE_REGIONAL, .before = 1)
)
escala_max <- sensibilidad %>% filter(estacion == NOMBRE_REGIONAL) %>% slice_max(r, n = 1) %>% pull(escala)
cat("B. Método", metodo_100, "| escala de máxima correlación regional: SPI-", escala_max, "\n")

graficarSensibilidad(sensibilidad, escala_max, nombreCoef(metodo_100),
                     archivo = "output/evaluacion_hs/sensibilidad_hs100.png")

# ═══ TABLAS ═════════════════════════════════════════════════════════════════

nombres <- c(
  "Estación" = "estacion", "Excluidas" = "excluidas", "Estaciones" = "n_estaciones",
  "Correlación" = "metodo", "n" = "n", "Mes" = "mes", "Escala SPI (meses)" = "escala",
  "r" = "r", "p-valor" = "p_valor", "τ Kendall" = "tau", "p-valor (Kendall)" = "p_kendall",
  "p Shapiro (SPI)" = "sw_campo_p", "p Shapiro (SSMI)" = "sw_fldas_p",
  "Normal (ambos)" = "normal", "Estación (id)" = "id"
)
# Quita las columnas vacías (Kendall, si el método es paramétrico) y renombra
nombrar <- function(df) df %>% select(where(~ !all(is.na(.x)))) %>% rename(any_of(nombres))

indices <- bind_rows(series, .id = "id") %>%
  transmute("Estación (id)" = id, "Mes" = format(fecha, "%Y-%m"),
            "PP campo (mm/mes)" = pp_campo, "HS FLDAS 0-10 cm (mm)" = round(hs_fldas, 2),
            "SPI-1 campo" = round(valor_campo, 3), "SSMI FLDAS" = round(valor_fldas, 3))

escribirExcel(
  list("Índices"            = indices,
       "Por estación"       = nombrar(tabla_est),
       "Análisis regional"  = nombrar(tabla_gen),
       "Normalidad"         = nombrar(normalidad),
       "Por mes"            = nombrar(tabla_mes),
       "0-100 resultado"    = nombrar(sensibilidad %>% filter(escala == escala_max)),
       "0-100 sensibilidad" = nombrar(sensibilidad),
       "0-100 normalidad"   = nombrar(normalidad_100)),
  "output/evaluacion_hs/evaluacion_hs.xlsx"
)
cat("\nListo. Resultados en output/evaluacion_hs/\n")
