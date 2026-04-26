# IMPORTA LOS DATOS (RASTERS), LES ASIGNA EL NOMBRE VARIABLE_FECHA Y DEVUELVE UNA MATRIZ

importData <- function(nombre_carpeta){
  # Listo los nombres de los archivos de la carpeta
  archivos <- list.files(path = paste0("data/", nombre_carpeta), 
                         pattern = "\\.tif[f]?$", full.names = TRUE)
  # Extraigo la fecha de cada uno
  fecha <- str_extract(basename(archivos), "\\d{6}")
  fecha <- as.Date(paste0(fecha, "01"),
                   format = "%Y%m%d")
  # Importo los rasters con 'terra'
  rasters <- rast(archivos)
  names(rasters) <- fecha
  # Los convierto a matriz
  df <- as.data.frame(rasters, xy = TRUE, na.rm = FALSE)
  r <- as.matrix(df)
  # Elimino filas con todos valores NA
  valores <- r[, -(1:2)]
  filas_validas <- !apply(valores, 1, function(fila) all(is.na(fila)))
  datos <- r[filas_validas, ]
  datos <- datos[, !duplicated(colnames(datos))]
  
  datos
}
