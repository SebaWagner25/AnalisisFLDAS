datosPixel <- function(coord_x, coord_y, variable, nombre_carpeta, espesor_cm = NULL){
  datos <- importData(nombre_carpeta)
  datos <- as.data.frame(datos)
  
  fila <- datos %>%
    filter(abs(x - coord_x) < 0.05, abs(y - coord_y) < 0.05) %>% 
    select(-x, -y)

  patron <- "valor_"
  nombre_columna <- paste0(patron, "fldas")
  
  datos_fldas <- pivot_longer(
    fila,
    cols = everything(),                  # Todas las columnas excepto Año
    names_to = "fecha",
    values_to = paste0(patron, "fldas")
  )
  
  datos_fldas$fecha <- str_remove(datos_fldas$fecha, patron) 
  datos_fldas$fecha <- as.Date(datos_fldas$fecha)
  
  datos_fldas[[nombre_columna]] <- convertir_unidades(valores = datos_fldas[[nombre_columna]],
                                                      variable = variable,
                                                      fechas = datos_fldas$fecha,
                                                      espesor_cm = espesor_cm)
  return(datos_fldas)
}
