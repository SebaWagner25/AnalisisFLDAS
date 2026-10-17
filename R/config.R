# CONFIGURACIÓN GENERAL DEL PROYECTO
# Todos los scripts cargan este archivo. Si hay que cambiar un parámetro
# (umbral de datos faltantes, estaciones excluidas, etc.) se cambia SOLO acá.

# ─── VARIABLES FLDAS ────────────────────────────────────────────────────────
# Carpeta dentro de data/ donde están los .tif de cada variable
CARPETAS_FLDAS <- list(
  pp         = "FLDAS_Rainf_f_tavg_comp",
  et         = "FLDAS_Evap_tavg_comp",
  t          = "FLDAS_Tair_f_tavg_comp",
  hs_0_10    = "FLDAS_SoilMoi00_10cm_tavg_comp",
  hs_10_40   = "FLDAS_SoilMoi10_40cm_tavg_comp",
  hs_40_100  = "FLDAS_SoilMoi40_100cm_tavg_comp",
  hs_100_200 = "FLDAS_SoilMoi100_200cm_tavg_comp"
)

# Espesor (cm) de cada capa de suelo, para pasar humedad de suelo a mm
ESPESORES_HS <- list(hs_0_10 = 10, hs_10_40 = 30, hs_40_100 = 60, hs_100_200 = 100)

# Variables que se comparan con datos de campo (pasos 1 a 3)
VARIABLES_CAMPO <- c("pp", "et", "t")

# Unidades (para etiquetas de tablas y gráficos)
UNIDADES <- list(pp = "mm/mes", et = "mm/mes", t = "°C")

# ─── PREPROCESAMIENTO: DATOS FALTANTES ──────────────────────────────────────
# Un mes se descarta si:
#   - el archivo tiene menos del 50 % de los días del mes, o
#   - más del 50 % de los días presentes son faltantes (NA).
UMBRAL_FALTANTES <- 0.5

# ─── VALIDACIÓN GENERAL ─────────────────────────────────────────────────────
# Estaciones (id de estaciones.csv) que se dejan AFUERA de la validación
# general, por variable. Para no excluir ninguna: character(0)
EXCLUIR_GENERAL <- list(
  pp = character(0),
  et = c("VM"),
  t  = character(0)
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
