# LEE LOS EXCEL DE ESTACIONES OMIXOM (una hoja por variable)
# Y DEVUELVE LA SERIE MENSUAL (ver agregarMensual.R)
# variable: "Precipitación", "Evapotranspiración" o "Temperatura"

datosOMIXOM <- function(ruta_archivo, variable) {

  # Patrón para identificar la hoja correcta
  patron_hoja <- switch(variable,
    "Precipitación" = "^Registro de lluvia",
    "Temperatura"   = "^Temperatura °C",   # para no tomar 'Temperatura de suelo'
    paste0("^", variable)
  )

  hoja <- grep(patron_hoja, excel_sheets(ruta_archivo), value = TRUE)[1]
  if (is.na(hoja)) stop("No se encontró una hoja para la variable: ", variable)

  # Las primeras 6 filas son encabezado (nombre de estación, coordenadas, etc.)
  datos <- read_excel(ruta_archivo, sheet = hoja, skip = 6, col_types = "text")

  # Columna con el valor diario, según la variable
  if (variable == "Temperatura") {
    columna <- "Promedio"
  } else {
    columna <- intersect(c("Total mm/día", "Lluvia de 9hs a 9hs [mm]"),
                         colnames(datos))[1]
  }
  if (is.na(columna) || !columna %in% colnames(datos)) {
    stop("No se encontró una columna válida de ", variable, " en la hoja '", hoja, "'")
  }

  fecha <- as.Date(datos$Fecha, format = "%d/%m/%Y")
  valor <- suppressWarnings(as.numeric(gsub(",", ".", datos[[columna]])))

  agregarMensual(fecha, valor,
                 funcion = if (variable == "Temperatura") "mean" else "sum")
}
