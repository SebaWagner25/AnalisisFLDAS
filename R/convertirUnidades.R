convertir_unidades <- function(valores, variable, fechas, espesor_cm = NULL){
  
  if (variable %in% c("pp", "et")) {
    dias_mes <- days_in_month(fechas)
    segundos_mes <- dias_mes * 86400
    return(valores * segundos_mes)
  }
  else if (variable == "hs"){
    espesores <- c(10, 30, 60, 100)
    if (is.null(espesor_cm)){
      stop("Indicar espesor de suelo para convertir la humedad de suelo a mm.")
    }
    if (!espesor_cm %in% espesores){
      stop("Espesor debe ser 10 (0-10cm), 30 (10-40cm), 60 (40-100cm) o 100 (100-200cm)")
    }
    espesor_mm <- espesor_cm * 10
    return(valores * espesor_mm)
  } else {
    stop("La variable debe ser 'pp', 'et' o 'hs'.")
  }
  }
