# CONFIGURACIÓN GENERAL DEL PROYECTO
# Todos los scripts cargan este archivo. Si hay que cambiar un parámetro
# (umbral de datos faltantes, estaciones excluidas, etc.) se cambia SOLO acá.

# ─── VARIABLES FLDAS ────────────────────────────────────────────────────────
# Carpeta dentro de data/ donde están los .tif de cada variable
CARPETAS_FLDAS <- list(
  pp         = "FLDAS_Rainf_f_tavg_comp",
  et         = "FLDAS_Evap_tavg_comp",
  t          = "FLDAS_Tair_f_tavg_comp",
  ts         = "FLDAS_SoilTemp00_10cm_tavg_comp",  # temperatura de suelo 0-10 cm
  ts_10_40   = "FLDAS_SoilTemp10_40cm_tavg_comp",  # (las capas más profundas
  ts_40_100  = "FLDAS_SoilTemp40_100cm_tavg_comp", #  solo se usan en mapas
  ts_100_200 = "FLDAS_SoilTemp100_200cm_tavg_comp",#  y BEAST, no se validan)
  hs_0_10    = "FLDAS_SoilMoi00_10cm_tavg_comp",
  hs_10_40   = "FLDAS_SoilMoi10_40cm_tavg_comp",
  hs_40_100  = "FLDAS_SoilMoi40_100cm_tavg_comp",
  hs_100_200 = "FLDAS_SoilMoi100_200cm_tavg_comp"
)

# ─── BORRADOR: FUENTE FLDAS PARA VALIDAR LA TEMPERATURA DE SUELO ────────────
# Prueba: validar la temperatura de suelo de campo (TS) contra la temperatura
# radiativa de la superficie de FLDAS (RadT) en lugar de SoilTemp 0-10 cm.
# Solo cambia los pasos 1 a 3; los mapas y BEAST siguen usando SoilTemp.
# Para volver al original, comentar la línea de RadT y descomentar la de SoilTemp.
CARPETA_TS_VALIDACION <- CARPETAS_FLDAS$ts          # SoilTemp 0-10 cm (original)
# CARPETA_TS_VALIDACION <- "FLDAS_RadT_tavg_comp"         # RadT (borrador)

# Espesor (cm) de cada capa de suelo, para pasar humedad de suelo a mm
ESPESORES_HS <- list(hs_0_10 = 10, hs_10_40 = 30, hs_40_100 = 60, hs_100_200 = 100)

# Variables que se comparan con datos de campo (pasos 1 a 3)
VARIABLES_CAMPO <- c("pp", "et", "t", "ts")

# Unidades (para etiquetas de tablas y gráficos)
UNIDADES <- list(pp = "mm/mes", et = "mm/mes", t = "°C", ts = "°C")

# ─── PREPROCESAMIENTO: DATOS FALTANTES ──────────────────────────────────────
# Un mes se descarta si:
#   - el archivo tiene menos del 50 % de los días del mes, o
#   - más del 50 % de los días presentes son faltantes (NA).
UMBRAL_FALTANTES <- 0.5

# ─── PREPROCESAMIENTO: MESES DESCARTADOS A MANO ─────────────────────────────
# scripts/01_preprocesamiento.R marca los outliers (test de Tukey) en la hoja
# "Outliers" de output/preprocesado/preprocesamiento.xlsx. Después de revisarlos, los meses que se
# decida descartar se anotan acá, por variable y por estación (id de
# estaciones.csv), con formato "AAAA-MM". Conviene dejar el motivo en un comentario.
# Ejemplo:
#   pp = list(
#     OX1 = c("2020-11"),
#     SL  = c("1985-07", "2004-05")
#   ),
EXCLUIR_MESES <- list(
  pp = list(
    OX1 = c("2020-11")
  ),
  et = list(),
  t  = list(),
  ts = list(
    OX2 = c("2020-10", "2020-11", "2020-12")
  )
)

# ─── VALIDACIÓN: ELECCIÓN DEL MÉTODO ────────────────────────────────────────
# Test de Shapiro-Wilk sobre las series de campo y FLDAS (nivel de significancia):
#  - Por estación: si AL MENOS UNA estación (campo o FLDAS) no es normal
#    (p < ALFA_SHAPIRO), todas las estaciones de esa variable se validan con el
#    método NO PARAMÉTRICO (Spearman, Kendall, regresión robusta).
#    Si todas son normales: PARAMÉTRICO (Pearson, regresión lineal y R²).
#  - General (todas juntas): la misma regla, aplicada a los datos apilados.
ALFA_SHAPIRO <- 0.05

# ─── VALIDACIÓN GENERAL ─────────────────────────────────────────────────────
# Estaciones (id de estaciones.csv) que se dejan AFUERA de la validación
# general, por variable. Para no excluir ninguna: character(0)
EXCLUIR_GENERAL <- list(
  pp = character(0),
  et = c("VM"),
  t  = character(0),
  ts = c("OX1")
)

# ─── ESTACIONES ─────────────────────────────────────────────────────────────
# Lee data/estaciones.csv y devuelve una lista con una entrada por estación
cargarEstaciones <- function(ruta = "data/estaciones.csv") {
  df <- read.csv(ruta, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
  lapply(seq_len(nrow(df)), function(i) {
    fila <- df[i, ]
    list(
      id        = fila$id,
      nombre    = fila$nombre,
      proveedor = fila$proveedor,
      archivo   = file.path("data",
                            ifelse(fila$proveedor == "OMIXOM",
                                   "DATOS_OMIXOM", "DATOS_INTA_SMN"),
                            fila$archivo),
      x         = fila$x,
      y         = fila$y,
      vars      = strsplit(fila$vars, ";")[[1]]
    )
  })
}
