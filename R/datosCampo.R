# LEE LOS DATOS DIARIOS DE ESTACIONES INTA / SMN (CSV separado por ";")
# Y DEVUELVE LA SERIE MENSUAL (ver agregarMensual.R)
#
# Códigos especiales de los archivos SMN:
#   "S/P"  = sin precipitación                -> 0 mm   (solo columna PP)
#   "<0.1" = precipitación inapreciable/traza -> 0 mm   (solo columna PP)
#   "S/D"  = sin dato                         -> faltante (NA)
# En la columna T, "S/P" no tiene sentido y se toma como faltante.
# Los decimales pueden venir con punto (PP) o con coma (T): se aceptan ambos.

datosCampo <- function(ruta_archivo, nombre_variable, proveedor = "INTA") {

  datos <- read.csv2(ruta_archivo,
                     colClasses   = "character",
                     na.strings   = c("", "S/D", "s/d"),
                     fileEncoding = "UTF-8-BOM")   # algunos archivos traen BOM

  formato_fecha <- if (proveedor == "INTA") "%d/%m/%Y" else "%Y-%m-%d"
  fecha <- as.Date(datos$Fecha, format = formato_fecha)

  texto <- trimws(datos[[nombre_variable]])
  if (nombre_variable == "PP") {
    texto[toupper(texto) %in% c("S/P", "<0.1")] <- "0"
  }
  valor <- suppressWarnings(as.numeric(gsub(",", ".", texto)))

  # Avisar si quedó algún valor raro que no se pudo leer como número
  raros <- unique(texto[!is.na(texto) & is.na(valor)])
  if (length(raros) > 0) {
    message("  ", basename(ruta_archivo), " (", nombre_variable,
            "): valores no numéricos tomados como faltantes: ",
            paste(raros, collapse = ", "))
  }

  agregarMensual(fecha, valor,
                 funcion = if (nombre_variable == "T") "mean" else "sum")
}
