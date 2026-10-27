# LEE LOS EXCEL DE ESTACIONES OMIXOM (una hoja por variable)
# Devuelve la serie DIARIA: tabla con fecha y valor (en temperaturas, también
# tmin y tmax, para el control de calidad máxima > mínima).
# (el control de calidad y el paso a mensual se hacen en scripts/01_preprocesamiento.R)
# variable: "Precipitación", "Evapotranspiración", "Temperatura" o "Temperatura de suelo"

datosOMIXOM <- function(ruta_archivo, variable) {

  # Patrón para identificar la hoja correcta
  patron_hoja <- switch(variable,
    "Precipitación" = "^Registro de lluvia",
    "Temperatura"   = "^Temperatura °C",   # para no tomar 'Temperatura de suelo'
    "Temperatura de suelo" = "^Temperatura de suelo",
    paste0("^", variable)
  )

  hoja <- grep(patron_hoja, excel_sheets(ruta_archivo), value = TRUE)[1]
  if (is.na(hoja)) stop("No se encontró una hoja para la variable: ", variable)

  # Las primeras 6 filas son encabezado (nombre de estación, coordenadas, etc.)
  datos <- read_excel(ruta_archivo, sheet = hoja, skip = 6, col_types = "text")

  # Columna con el valor diario, según la variable
  es_temperatura <- variable %in% c("Temperatura", "Temperatura de suelo")
  if (es_temperatura) {
    columna <- "Promedio"
  } else {
    columna <- intersect(c("Total mm/día", "Lluvia de 9hs a 9hs [mm]"),
                         colnames(datos))[1]
  }
  if (is.na(columna) || !columna %in% colnames(datos)) {
    stop("No se encontró una columna válida de ", variable, " en la hoja '", hoja, "'")
  }

  aNumero <- function(x) suppressWarnings(as.numeric(gsub(",", ".", x)))

  diario <- tibble(fecha = as.Date(datos$Fecha, format = "%d/%m/%Y"),
                   valor = aNumero(datos[[columna]]))

  # Temperaturas: se agregan la mínima y la máxima del día (si están)
  if (es_temperatura && all(c("Mínimo", "Máximo") %in% colnames(datos))) {
    diario$tmin <- aNumero(datos[["Mínimo"]])
    diario$tmax <- aNumero(datos[["Máximo"]])
  }
  diario
}
