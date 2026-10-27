# PASA UNA SERIE DIARIA A MENSUAL
# Recibe un vector de fechas y uno de valores diarios.
# Devuelve una fila por mes con:
#   fecha                primer día del mes
#   valor_campo          suma (PP, ET) o promedio (T) de los días con dato
#   porcentaje_completo  días presentes en el archivo / días del mes
#   porcentaje_na        días sin dato (NA) / días presentes en el archivo
# Los datos ya tienen que haber pasado por el control de calidad
# (R/controlCalidad.R: fechas repetidas, negativos, máxima <= mínima).
# El filtro de meses incompletos NO se hace acá, sino en
# scripts/01_preprocesamiento.R (umbral en R/config.R).

agregarMensual <- function(fecha, valor, funcion = c("sum", "mean")) {
  funcion <- match.arg(funcion)

  tibble(fecha = fecha, valor = valor) %>%
    filter(!is.na(fecha)) %>%
    mutate(mes = floor_date(fecha, "month")) %>%
    group_by(mes) %>%
    summarise(
      total_dias  = n(),
      na_dias     = sum(is.na(valor)),
      valor_campo = if (funcion == "sum") sum(valor, na.rm = TRUE)
                    else mean(valor, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      porcentaje_completo = total_dias / days_in_month(mes),
      porcentaje_na       = na_dias / total_dias
    ) %>%
    transmute(fecha = mes, valor_campo, porcentaje_completo, porcentaje_na)
}
