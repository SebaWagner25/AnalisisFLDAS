# GUARDA VARIAS TABLAS EN UN EXCEL (una hoja por tabla)
# hojas:    lista con nombre -> data.frame (el nombre de cada elemento es el de la hoja)
# archivo:  ruta del .xlsx de salida
# resaltar: (opcional) lista con nombre de hoja -> filas de la tabla a resaltar
#           en rojo claro (ej.: list(Outliers = c(1, 4)))
# Cada hoja lleva títulos en negrita, la primera fila fija, filtros en cada
# columna y el ancho de columna ajustado al contenido.

escribirExcel <- function(hojas, archivo, resaltar = list()) {
  wb <- createWorkbook()
  estilo_titulo <- createStyle(textDecoration = "bold", fgFill = "#DCE6F1",
                               border = "Bottom", halign = "center", wrapText = TRUE)

  for (nombre in names(hojas)) {
    tabla <- hojas[[nombre]]
    if (is.null(tabla) || nrow(tabla) == 0) next
    addWorksheet(wb, nombre)
    writeData(wb, nombre, tabla, headerStyle = estilo_titulo)
    freezePane(wb, nombre, firstRow = TRUE)                  # fija la fila de títulos
    addFilter(wb, nombre, rows = 1, cols = seq_along(tabla)) # filtros en cada columna
    # Ancho de cada columna según su texto más largo (título o valores)
    anchos <- sapply(seq_along(tabla), function(j)
      max(nchar(names(tabla)[j]), nchar(format(tabla[[j]])), na.rm = TRUE) + 2)
    setColWidths(wb, nombre, cols = seq_along(tabla), widths = anchos)
    # Filas resaltadas (+1 por la fila de títulos)
    filas <- resaltar[[nombre]]
    if (length(filas) > 0) {
      addStyle(wb, nombre, createStyle(fgFill = "#F8CBAD"),
               rows = filas + 1, cols = seq_along(tabla), gridExpand = TRUE)
    }
  }

  saveWorkbook(wb, archivo, overwrite = TRUE)
}
