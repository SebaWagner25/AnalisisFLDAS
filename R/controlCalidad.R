# CONTROL DE CALIDAD DE LOS DATOS DIARIOS DE CAMPO
# Se aplica antes de pasar a valores mensuales (scripts/01_preprocesamiento.R).
# Recibe una tabla diaria con columnas fecha y valor (y, en temperaturas de
# OMIXOM, también tmin y tmax). Controles:
#   1. Fechas repetidas: si todas las filas de esa fecha tienen el mismo valor,
#      se deja una sola; si tienen valores distintos, se deja una con el valor
#      como faltante (NA), porque no se sabe cuál es el correcto.
#   2. Valores negativos (solo PP y ET, negativos = TRUE): se toman como NA.
#   3. Temperatura máxima menor o igual a la mínima (si hay tmin y tmax):
#      el dato del día se toma como NA.
# Devuelve una lista con:
#   datos      la tabla diaria corregida (fecha, valor), una fila por fecha
#   problemas  una fila por cada dato corregido (fecha, control, detalle)

controlCalidad <- function(diario, negativos = FALSE) {

  diario    <- diario %>% filter(!is.na(fecha))
  # Tabla de problemas (empieza vacía y se le agregan filas en cada control)
  problemas <- list(tibble(fecha = as.Date(character(0)),
                           control = character(0), detalle = character(0)))

  # 1. Fechas repetidas
  repetidas <- diario %>%
    group_by(fecha) %>%
    filter(n() > 1) %>%
    summarise(n = n(),
              iguales = n_distinct(valor) == 1,
              detalle = paste(valor, collapse = " / "),
              .groups = "drop")
  if (nrow(repetidas) > 0) {
    problemas$repetidas <- repetidas %>%
      transmute(fecha,
                control = ifelse(iguales, "Fecha repetida (mismo valor: se deja una)",
                                          "Fecha repetida (valores distintos: NA)"),
                detalle = paste0(n, " filas: ", detalle))
    diario <- diario %>%
      distinct(fecha, .keep_all = TRUE) %>%
      mutate(valor = ifelse(fecha %in% repetidas$fecha[!repetidas$iguales],
                            NA, valor))
  }

  # 2. Valores negativos (PP y ET)
  if (negativos) {
    es_negativo <- !is.na(diario$valor) & diario$valor < 0
    problemas$negativos <- tibble(fecha   = diario$fecha[es_negativo],
                                  control = "Valor negativo: NA",
                                  detalle = as.character(diario$valor[es_negativo]))
    diario$valor[es_negativo] <- NA
  }

  # 3. Temperatura máxima <= mínima
  if (all(c("tmin", "tmax") %in% names(diario))) {
    invertida <- !is.na(diario$tmin) & !is.na(diario$tmax) & diario$tmax <= diario$tmin
    problemas$temperatura <- tibble(fecha   = diario$fecha[invertida],
                                    control = "Máxima <= mínima: NA",
                                    detalle = paste0("máx ", diario$tmax[invertida],
                                                     " / mín ", diario$tmin[invertida]))
    diario$valor[invertida] <- NA
  }

  list(datos     = diario %>% select(fecha, valor) %>% arrange(fecha),
       problemas = bind_rows(problemas))
}
