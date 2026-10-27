# DETECCIÓN DE OUTLIERS CON EL TEST DE TUKEY
# Calcula los límites a partir de los cuartiles (Q1, Q3) y el rango
# intercuartílico (RIC = Q3 - Q1) de toda la serie mensual de la estación:
#   outlier leve:     fuera de [Q1 - 1.5·RIC , Q3 + 1.5·RIC]
#   outlier extremo:  fuera de [Q1 - 3·RIC   , Q3 + 3·RIC]
# Solo MARCA los valores; no borra nada. Los meses a descartar se indican
# a mano en EXCLUIR_MESES (R/config.R) después de revisarlos.

# valores: vector numérico (serie mensual de una estación y variable)
# Devuelve un data.frame con los límites y la clasificación de cada valor:
#   tipo = NA (normal), "leve" o "extremo"
outliers <- function(valores) {
  q1  <- quantile(valores, 0.25, na.rm = TRUE, names = FALSE)
  q3  <- quantile(valores, 0.75, na.rm = TRUE, names = FALSE)
  ric <- q3 - q1

  lim_inf_leve    <- q1 - 1.5 * ric
  lim_sup_leve    <- q3 + 1.5 * ric
  lim_inf_extremo <- q1 - 3 * ric
  lim_sup_extremo <- q3 + 3 * ric

  tipo <- case_when(
    valores < lim_inf_extremo | valores > lim_sup_extremo ~ "extremo",
    valores < lim_inf_leve    | valores > lim_sup_leve    ~ "leve",
    TRUE                                                  ~ NA_character_
  )

  tibble(
    tipo            = tipo,
    lado            = ifelse(is.na(tipo), NA, ifelse(valores > q3, "superior", "inferior")),
    q1              = q1,
    q3              = q3,
    ric             = ric,
    lim_inf_leve    = lim_inf_leve,
    lim_sup_leve    = lim_sup_leve,
    lim_inf_extremo = lim_inf_extremo,
    lim_sup_extremo = lim_sup_extremo
  )
}
