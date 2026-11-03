# PASO 4 - EVALUACIÓN INDIRECTA DE LA HUMEDAD DE SUELO DE FLDAS
# No hay mediciones de humedad de suelo en campo. Se compara un índice
# estandarizado de humedad de suelo (SSMI) de FLDAS con el índice estandarizado
# de precipitación (SPI) de las estaciones. La precipitación de FLDAS ya se
# validó en el paso 3. Primero se grafica la humedad de las 4 capas en el
# tiempo (cómo se propaga en profundidad) y después hay dos análisis:
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
#   capas_hs.png                humedad de suelo de FLDAS de las 4 capas en el tiempo, por estación
#   series_hs.png               A: SPI-1 y SSMI 0-10 cm en el tiempo, por estación
#   correlacion_mensual_hs.png  A: correlación por mes (promedio ± desvío entre estaciones)
#   sensibilidad_hs100.png      B: correlación según la escala del SPI
#   evaluacion_hs.xlsx          mismo formato que validacion.xlsx (paso 3). A y B en las
#                               mismas hojas, separables con el filtro de las columnas
#                               "Análisis" y "Escala SPI (meses)": Por estación, Análisis
#                               regional y Normalidad (A y B), Por mes (A) y Sensibilidad (B)

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

# Humedad de suelo de FLDAS de las 4 capas (se importa una vez).
# Los análisis B (0-100 cm) usan las tres primeras.
capas_todas <- names(ESPESORES_HS)
capas       <- c("hs_0_10", "hs_10_40", "hs_40_100")
fldas       <- setNames(lapply(capas_todas, function(capa) importData(CARPETAS_FLDAS[[capa]])),
                        capas_todas)

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

# ═══ HUMEDAD DE SUELO POR CAPA (serie temporal) ════════════════════════════
# En m³/m³ (como los mapas del paso 5), para comparar capas de distinto espesor:
# hsCapa() da mm, se divide por el espesor de la capa en mm.
graficarCapasHS(
  datos   = map_dfr(estaciones, function(est) map_dfr(capas_todas, function(capa) {
              espesor_mm <- ESPESORES_HS[[capa]] * 10
              hsCapa(est, capa) %>%
                transmute(estacion = nombre_est[[est$id]], capa = capa, fecha,
                          valor = valor_fldas / espesor_mm)
            })),
  archivo = "output/evaluacion_hs/capas_hs.png")

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
# Mismo formato que validacion.xlsx (paso 3): columna "Método" (parametrico /
# no parametrico), p de Shapiro y los coeficientes con los mismos nombres.
# Los análisis A y B van en las mismas hojas: la columna "Análisis" (el mismo
# texto en todas las hojas) y la escala del SPI permiten filtrar cada uno.

analisis_A <- "A. Jung (0-10 cm)"
analisis_B <- "B. Spennemann (0-100 cm)"

# Pasa la salida de correlacion() a las columnas del paso 3
formatoValidacion <- function(df) {
  df %>%
    mutate(
      metodo    = ifelse(metodo == "pearson", "parametrico", "no parametrico"),
      pearson   = ifelse(metodo == "parametrico", r, NA_real_),
      pe_pvalor = ifelse(metodo == "parametrico", p_valor, NA_real_),
      spearman  = ifelse(metodo == "no parametrico", r, NA_real_),
      sp_pvalor = ifelse(metodo == "no parametrico", p_valor, NA_real_),
      kendall   = tau,
      ke_pvalor = p_kendall
    ) %>%
    select(-r, -p_valor, -tau, -p_kendall)
}

nombres <- c(
  "Estación" = "estacion", "Estación (id)" = "id", "Análisis" = "analisis",
  "Excluidas" = "excluidas", "Estaciones" = "n_estaciones",
  "Método" = "metodo", "n" = "n", "Mes" = "mes", "Escala SPI (meses)" = "escala",
  "p Shapiro (campo)" = "sw_campo_p", "p Shapiro (FLDAS)" = "sw_fldas_p",
  "Normal (campo y FLDAS)" = "normal",
  "r Pearson" = "pearson", "p-valor (Pe)" = "pe_pvalor",
  "ρ Spearman" = "spearman", "p-valor (Sp)" = "sp_pvalor",
  "τ Kendall" = "kendall", "p-valor (Ke)" = "ke_pvalor"
)
# Quita las columnas vacías (las del método que no se usó) y renombra
nombrar <- function(df) df %>% select(where(~ !all(is.na(.x)))) %>% rename(any_of(nombres))

# p de Shapiro de unos datos (SPI de campo y SSMI de FLDAS)
shapiroDatos <- function(d) tibble(sw_campo_p = pShapiro(d$valor_campo),
                                   sw_fldas_p = pShapiro(d$valor_fldas))

# Por estación: A (0-10 cm, SPI-1) y B (0-100 cm, en la escala de máxima correlación regional)
hoja_est <- bind_rows(
  map_dfr(names(series), function(id) bind_cols(
    tibble(estacion = nombre_est[[id]], analisis = analisis_A, escala = 1L),
    shapiroDatos(series[[id]]),
    correlacion(series[[id]], metodo_est))),
  map_dfr(names(datos_100), function(id) bind_cols(
    tibble(estacion = nombre_est[[id]], analisis = analisis_B, escala = escala_max),
    shapiroDatos(datos_100[[id]] %>% filter(escala == escala_max)),
    correlacion(datos_100[[id]] %>% filter(escala == escala_max), metodo_100)))
) %>% formatoValidacion() %>% relocate(metodo, n, .after = escala)

# Análisis regional: A y B (sin las estaciones excluidas)
regional_B <- todas_100 %>% filter(!id %in% excluidas, escala == escala_max)
hoja_reg <- bind_rows(
  bind_cols(tibble(analisis = analisis_A, escala = 1L), shapiroDatos(datos_todas),
            correlacion(datos_todas, metodo_gen)),
  bind_cols(tibble(analisis = analisis_B, escala = escala_max), shapiroDatos(regional_B),
            correlacion(regional_B, metodo_100))
) %>%
  mutate(excluidas = paste(excluidas, collapse = ", "),
         n_estaciones = n_distinct(datos_todas$estacion), .after = escala) %>%
  formatoValidacion() %>% relocate(metodo, n, .after = n_estaciones)

# Normalidad de cada estación: A (escala 1) y B (cada escala del SPI)
hoja_norm <- bind_rows(
  normalidad %>% mutate(analisis = analisis_A, escala = 1L),
  normalidad_100 %>% mutate(analisis = analisis_B)
) %>% relocate(id, analisis, escala)

escribirExcel(
  list("Por estación"       = nombrar(hoja_est),
       "Análisis regional"  = nombrar(hoja_reg),
       "Normalidad"         = nombrar(hoja_norm),
       "Por mes"            = nombrar(tabla_mes %>% formatoValidacion() %>%
                                        mutate(analisis = analisis_A, escala = 1L, .after = estacion)),
       "Sensibilidad"       = nombrar(sensibilidad %>% formatoValidacion() %>%
                                        mutate(analisis = analisis_B, .after = estacion))),
  "output/evaluacion_hs/evaluacion_hs.xlsx"
)
cat("\nListo. Resultados en output/evaluacion_hs/\n")
