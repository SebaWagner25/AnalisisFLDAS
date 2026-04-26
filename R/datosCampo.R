datosCampo <- function(ruta_archivo, nombre_variable, proveedor = "INTA") {
  
  # Leer archivo
  datos <- read.csv2(ruta_archivo, 
                     na.strings = c("S/D", "s/d", "", "<0.1"),
                     colClasses = "character", 
                     stringsAsFactors = FALSE)
  
  datos$Fecha <- as.Date(datos$Fecha, format = ifelse(proveedor == "INTA","%d/%m/%Y","%Y-%m-%d"))
  datos[[nombre_variable]] <- ifelse(datos[[nombre_variable]] == "S/P", 0, datos[[nombre_variable]])
  
  # Convertir primera columna a fecha y extraer columna de valor
  datos_filtrados <- datos %>%
    transmute(
      fecha = Fecha,
      valor = .[[nombre_variable]]
    ) %>%
    mutate(anio_mes = floor_date(fecha, "month"))
  
  # Contar días disponibles por mes
  conteo <- datos_filtrados %>%
    group_by(anio_mes) %>%
    reframe(
      total_dias = n(),
      na_dias = sum(is.na(.data[["valor"]])),
      dias_mes = days_in_month(anio_mes),
      porcentaje_na = na_dias / total_dias,
      porcentaje_completo = total_dias / dias_mes
    )
  
  # Meses a descartar: incompletos o con más del 50% de NA
  meses_incompletos <- conteo %>%
    filter(porcentaje_completo < 0.5 | porcentaje_na > 0.5) %>%
    pull(anio_mes)
  
  # Filtrar datos, excluyendo primer y último mes si están incompletos
  datos_filtrados <- datos_filtrados %>%
    filter(!(anio_mes %in% meses_incompletos)) 
  
  datos_filtrados$valor <- as.numeric(datos_filtrados$valor)
  datos_filtrados <- datos_filtrados %>%
    select(-anio_mes) %>%
    mutate(fecha = floor_date(fecha, "month")) %>% 
    group_by(fecha) %>% 
    summarise(valor_campo = sum(valor, na.rm = TRUE)) %>% 
    ungroup()
  
  datos_filtrados
}
