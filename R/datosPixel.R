# EXTRAE DE FLDAS LA SERIE MENSUAL DEL PÍXEL MÁS CERCANO A UNA ESTACIÓN

# Devuelve el número de fila (de la matriz de importData) del píxel más
# cercano a (coord_x, coord_y). Si el más cercano está a más de dist_max
# grados (FLDAS tiene píxeles de 0.1°), da error.
pixelCercano <- function(datos, coord_x, coord_y, dist_max = 0.1) {
  distancia <- sqrt((datos[, "x"] - coord_x)^2 + (datos[, "y"] - coord_y)^2)
  i <- which.min(distancia)
  if (length(i) == 0 || distancia[i] > dist_max) {
    stop("No hay píxel FLDAS con datos cerca de (", coord_x, ", ", coord_y, ")")
  }
  i
}

# datos: matriz que devuelve importData(). Si no se pasa, se importa la
# carpeta (más lento: conviene importar una vez y reutilizar).
datosPixel <- function(coord_x, coord_y, variable, nombre_carpeta = NULL,
                       espesor_cm = NULL, datos = NULL) {

  if (is.null(datos)) datos <- importData(nombre_carpeta)

  i      <- pixelCercano(datos, coord_x, coord_y)
  valores <- as.numeric(datos[i, -(1:2)])
  fechas  <- as.Date(colnames(datos)[-(1:2)])

  tibble(
    fecha       = fechas,
    valor_fldas = convertir_unidades(valores, variable = variable,
                                     fechas = fechas, espesor_cm = espesor_cm)
  )
}
