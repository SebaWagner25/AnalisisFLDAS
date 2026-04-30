datosOMIXOM <- function(ruta_archivo, variable){

  # Patrón para identificar la hoja correcta
  if (variable == "Precipitación") {
    variable_a_extraer <- "^Registro de lluvia"
  } else if (variable == "Temperatura") {
    # Forzar 'Temperatura °C' para no capturar 'Temperatura de suelo °C'
    variable_a_extraer <- "^Temperatura °C"
  } else {
    variable_a_extraer <- paste0("^", variable)
  }

  hoja <- grep(variable_a_extraer, excel_sheets(ruta_archivo), value = TRUE)[1]
  if (is.na(hoja)) {
    stop("No se encontró una hoja para la variable: ", variable)
  }
  datos <- read_excel(ruta_archivo, sheet = hoja, skip = 6, col_types = "text")
  datos[[1]] <- as.Date(datos[[1]], format = "%d/%m/%Y")
  datos[[3]] <- as.numeric(datos[[3]])

  # Identificar columna de valores y agregador mensual según variable
  if (variable == "Temperatura") {
    if (!"Promedio" %in% colnames(datos)) {
      stop("No se encontró la columna 'Promedio' en la hoja de Temperatura.")
    }
    columna_valores <- "Promedio"
    agregador <- "mean"
  } else if ("Total mm/día" %in% colnames(datos)) {
    columna_valores <- "Total mm/día"
    agregador <- "sum"
  } else if ("Lluvia de 9hs a 9hs [mm]" %in% colnames(datos)) {
    columna_valores <- "Lluvia de 9hs a 9hs [mm]"
    agregador <- "sum"
  } else {
    stop(paste0("No se encontró una columna válida de ", variable))
  }

  # Agrupar por año-mes y calcular porcentaje de NA y si el mes está completo

  datos <- datos %>%
    mutate(anio_mes = floor_date(datos[[1]], "month"))
  conteo <- datos %>%
    group_by(anio_mes) %>%
    reframe(
      total_dias = n(),
      na_dias = sum(is.na(.data[[columna_valores]])),
      dias_mes = days_in_month(anio_mes),
      porcentaje_na = na_dias / total_dias,
      porcentaje_completo = total_dias / dias_mes
    )



  # Meses a descartar: incompletos o con más del 50% de NA
  meses_incompletos <- conteo %>%
    filter(porcentaje_completo < 0.5 | porcentaje_na > 0.5) %>%
    pull(anio_mes)

  # Filtrar datos, excluyendo primer y último mes si están incompletos
  datos_filtrados <- datos %>%
    filter(!(anio_mes %in% meses_incompletos))


  datos_filtrados <- datos_filtrados %>%
    rename_with(~"valor", .cols = all_of(columna_valores))
  datos_filtrados$valor <- as.numeric(datos_filtrados$valor)

  # Agregar mensualmente: sumar (PP/ET) o promediar (T)
  if (agregador == "mean") {
    datos_filtrados <- datos_filtrados %>%
      select(-anio_mes) %>%
      mutate(fecha = floor_date(Fecha, "month")) %>%
      group_by(fecha) %>%
      summarise(valor_campo = mean(valor, na.rm = TRUE)) %>%
      ungroup()
  } else {
    datos_filtrados <- datos_filtrados %>%
      select(-anio_mes) %>%
      mutate(fecha = floor_date(Fecha, "month")) %>%
      group_by(fecha) %>%
      summarise(valor_campo = sum(valor, na.rm = TRUE)) %>%
      ungroup()
  }

  datos_filtrados
}
