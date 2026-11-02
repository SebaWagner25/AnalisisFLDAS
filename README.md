# Análisis FLDAS - San Luis

Validación y análisis de datos del modelo **FLDAS Global** (Famine Early Warning Systems Network Land Data Assimilation System) para la provincia de San Luis, Argentina.

Se comparan datos de FLDAS con datos medidos en estaciones meteorológicas de campo (SMN, INTA y OMIXOM), se evalúa de forma indirecta la humedad de suelo de FLDAS con el índice estandarizado de precipitación (SPI), se generan mapas descriptivos e isolíneas, y se aplica el algoritmo BEAST (Bayesian Estimator of Abrupt change, Seasonality, and Trend) para detectar cambios y tendencias.

**Variables analizadas:**
- Precipitación (PP)
- Evapotranspiración (ET)
- Temperatura del aire cerca de la superficie (T)
- Temperatura de suelo (TS): campo (estaciones OMIXOM) vs. temperatura de suelo 0-10 cm de FLDAS
- Temperatura de suelo (0-10, 10-40, 40-100 y 100-200 cm)
- Humedad de suelo 0-10 cm y columna 0-100 cm: evaluación indirecta con el SPI (paso 4)
- Humedad de suelo 100-200 cm (solo mapas, sin validación)

**Período FLDAS:** 1982-2024 (mensual)

## Requisitos

### R
```r
install.packages(c("terra", "tidyverse", "readxl", "robustbase", "openxlsx", "patchwork", "Rbeast", "remotes"))
# SPEI 1.7.2 (paso 4): las versiones 1.8.0 y 1.8.1 dan -Inf en los meses sin lluvia
remotes::install_github("sbegueria/SPEI@v1.7.2", upgrade = "never")
```

### Python
```bash
pip install xarray rioxarray pandas numpy netcdf4 matplotlib cartopy
```

### Software externo
- **CDO** (Climate Data Operators): procesamiento de archivos NetCDF
- **GrADS** (opcional): visualización de archivos NetCDF

## Estructura

```
R/                  funciones (no se corren solas; las cargan los scripts)
  config.R            parámetros del proyecto (umbral de faltantes, estaciones excluidas...)
  controlCalidad.R    control de calidad de los datos diarios de campo
  agregarMensual.R    pasa datos diarios a mensuales y calcula % de días faltantes
  outliers.R          marca outliers con el test de Tukey
  datosCampo.R        lee estaciones SMN e INTA (CSV)
  datosOMIXOM.R       lee estaciones OMIXOM (Excel)
  importData.R        lee los .tif de FLDAS
  datosPixel.R        extrae la serie FLDAS del píxel más cercano a una estación
  convertirUnidades.R conversión de unidades de FLDAS
  estadisticaDescriptiva.R
  validacion.R        estadísticos y gráficos de validación
  evaluacionHS.R      SPI-1 y SSMI (paquete SPEI), correlación por mes y gráficos del paso 4
  escribirExcel.R     guarda varias tablas en un Excel (una hoja por tabla)
  applyBeast.R        BEAST por píxel y gráficos
scripts/            análisis, se corren en orden (ver abajo)
  otros/              análisis complementarios que no forman parte del informe
python/             conversión .tif -> NetCDF y mapas con isolíneas
cdo/                procesamiento de los NetCDF con CDO (isolíneas)
data/               datos (no se suben a GitHub, salvo estaciones.csv)
output/             resultados (no se suben a GitHub)
```

## Datos usados

- Archivos `.tif` de FLDAS organizados en carpetas por variable dentro de `data/`

| Carpeta | Variable |
|---------|----------|
| `FLDAS_Rainf_f_tavg_comp` | Precipitación |
| `FLDAS_Evap_tavg_comp` | Evapotranspiración |
| `FLDAS_Tair_f_tavg_comp` | Temperatura del aire cerca de la superficie |
| `FLDAS_SoilTemp00_10cm_tavg_comp` | Temperatura de suelo 0-10 cm (se compara con temperatura de suelo de campo) |
| `FLDAS_SoilTemp10_40cm_tavg_comp` | Temperatura de suelo 10-40 cm |
| `FLDAS_SoilTemp40_100cm_tavg_comp` | Temperatura de suelo 40-100 cm |
| `FLDAS_SoilTemp100_200cm_tavg_comp` | Temperatura de suelo 100-200 cm |
| `FLDAS_SoilMoi00_10cm_tavg_comp` | Humedad de suelo 0-10 cm (se evalúa con el SPI, paso 4) |
| `FLDAS_SoilMoi10_40cm_tavg_comp` | Humedad de suelo 10-40 cm |
| `FLDAS_SoilMoi40_100cm_tavg_comp` | Humedad de suelo 40-100 cm |
| `FLDAS_SoilMoi100_200cm_tavg_comp` | Humedad de suelo 100-200 cm |

- Datos diarios de campo de las estaciones listadas en `data/estaciones.csv`
  (`data/DATOS_INTA_SMN/` y `data/DATOS_OMIXOM/`)

## Flujo de trabajo

Abrir `00_ANALISIS.Rproj` en RStudio y correr los scripts en orden desde la raíz del proyecto.

| Paso | Script | Qué hace | Salida |
|------|--------|----------|--------|
| 1 | `scripts/01_preprocesamiento.R` | Lee los datos de campo, pasa a valores mensuales, descarta meses incompletos, extrae FLDAS en cada estación y convierte unidades | `output/preprocesado/` (`series.csv` y `preprocesamiento.xlsx`) |
| 2 | `scripts/02_descriptivo.R` | Estadística descriptiva Campo vs FLDAS, por estación y general | `output/descriptivo/` (una figura por estación y variable, una general por variable y `descriptivo.xlsx`) |
| 3 | `scripts/03_validacion.R` | Validación FLDAS vs campo, por estación y general | `output/validacion/` (figuras por variable y `validacion.xlsx`) |
| 4 | `scripts/04_evaluacion_HS.R` | Evaluación indirecta de la humedad de suelo de FLDAS: SSMI vs SPI de las estaciones (0-10 cm y 0-100 cm) | `output/evaluacion_hs/` (figuras y `evaluacion_hs.xlsx`) |
| 5 | `scripts/05_mapas_descriptivos.R` + `python/` + `cdo/` | Mapas descriptivos e isolíneas | `output/mapas/`, `data/nc/` |
| 6 | `scripts/06_beast.R` | Tendencias y cambios abruptos con BEAST (probablemente pase a otro proyecto) | `output/beast/` |

No se hizo corrección de sesgo: la validación del paso 3 indicó que no hacía falta.

### Paso 1: criterios de preprocesamiento
- Códigos SMN: `S/P` (sin precipitación) y `<0.1` (traza) se toman como 0 mm; `S/D` (sin dato) como faltante.
- PP y ET mensuales = suma diaria; T mensual = promedio diario.
- Control de calidad de los datos diarios de campo (hoja "Control de calidad" de
  `output/preprocesado/preprocesamiento.xlsx`):
  - Fechas repetidas: si tienen el mismo valor se deja una; si los valores difieren, ese día queda como faltante (NA).
  - PP y ET: valores negativos se toman como faltantes (NA). También los mensuales negativos de FLDAS.
  - Temperaturas OMIXOM (aire y suelo): si la máxima del día es menor o igual a la mínima, ese día queda como faltante (NA).
- Se descarta un mes si el archivo tiene menos del 50 % de sus días o si más del 50 %
  de los días son faltantes (`UMBRAL_FALTANTES` en `R/config.R`).
- Outliers: se marcan con el test de Tukey sobre la serie mensual de cada estación
  (leves: fuera de Q1 − 1,5·RIC / Q3 + 1,5·RIC; extremos: fuera de Q1 − 3·RIC / Q3 + 3·RIC)
  en la hoja "Outliers" de `output/preprocesado/preprocesamiento.xlsx`. No se borran solos: los meses a descartar
  se anotan en `EXCLUIR_MESES` (`R/config.R`).
- FLDAS: PP y ET de kg/m²/s a mm/mes; T y TS de K a °C. Se usa el píxel más cercano a la estación.

### Paso 3: elección del método de validación
Según el test de Shapiro-Wilk (nivel `ALFA_SHAPIRO` en `R/config.R`, 0,05):
- **Por estación:** si al menos una estación (serie de campo o FLDAS) no es normal, todas las
  estaciones de esa variable se validan con el método **no paramétrico** (Spearman, Kendall,
  regresión robusta). Si todas son normales, con el **paramétrico** (Pearson, regresión lineal, R²).
- **General:** la misma regla sobre los datos de todas las estaciones juntas.
- El resultado del test de cada estación queda en la hoja "Normalidad" de `output/validacion/validacion.xlsx`.
- **Sesgo:** test sobre las diferencias pareadas (FLDAS − campo) con el mismo criterio
  (Wilcoxon de rangos con signo si es no paramétrico, t pareado si es paramétrico),
  para toda la serie y para cada mes del año (hoja "Sesgo por mes" de `validacion.xlsx`
  y `output/validacion/sesgo_mensual_<var>.png`).

### Paso 4: evaluación indirecta de la humedad de suelo
No hay mediciones de humedad de suelo en campo (las del SNIH están fuera del área de estudio).
Se compara un índice estandarizado de humedad de suelo (SSMI) de FLDAS con el índice estandarizado
de precipitación (SPI) de las estaciones. La precipitación de FLDAS no se vuelve a evaluar: ya se
validó en el paso 3. Dos análisis:
- **A. Capa 0-10 cm vs SPI-1** (Jung et al., 2020): sin quitar tendencias, los 12 meses del año.
  Correlación por estación, general y por mes del año.
- **B. Columna 0-100 cm vs SPI de 1 a 12 meses** (Spennemann et al., 2015): la humedad de 0-100 cm
  es la suma (en mm) de las capas 0-10, 10-40 y 40-100 cm, las mismas del modelo Noah que usa ese
  trabajo. A las dos series se les quita la tendencia lineal antes de correlacionar. La curva de
  sensibilidad (correlación según la escala del SPI) define la escala de análisis: la de máxima
  correlación regional (`ESCALAS_SPI` en `R/config.R`). Spennemann eligió SPI-3 por criterio
  agronómico para una región húmeda; acá la escala se elige con los datos.

Criterios comunes:
- **Estaciones:** `ESTACIONES_HS` en `R/config.R` (SL, VR, VM y SR): las que tienen al menos
  ~20 años de precipitación en común con FLDAS. TL y las OMIXOM tienen 10 años o menos.
- **Período:** todos los meses de cada estación en común con FLDAS (los de `series.csv`).
  El SPI y el SSMI de una estación se calculan sobre los mismos meses.
- **SPI y SSMI:** función `spi()` del paquete SPEI, versión 1.7.2 (Beguería y Vicente-Serrano, 2017),
  con distribución Gamma (McKee et al., 1993). Para cada mes calendario se ajusta la Gamma a los
  meses con valor mayor a 0 y la probabilidad acumulada, corregida por la proporción de meses con
  valor 0, se pasa a una normal estándar. El SSMI se calcula igual, aplicado a la humedad de suelo.
- **Versión de SPEI:** se usa la 1.7.2 porque en las versiones 1.8.0 y 1.8.1 la corrección por meses
  con valor 0 no se aplica y esos meses dan −Inf. El script se detiene si encuentra otra versión.
- Un mes calendario necesita al menos `MIN_ANIOS_INDICE` años con dato (10); si no, sus índices quedan NA.
- **Estadísticos:** solo la correlación y su p-valor, como en ambos trabajos. Con la misma regla de
  Shapiro-Wilk que el paso 3: Pearson si es paramétrico; Spearman y Kendall si no. No se usan recta
  ajustada, RMSE ni BIAS, porque suponen que los dos índices deberían valer lo mismo y miden cosas
  distintas (anomalía de lluvia y de humedad de suelo).
- **Gráficos:** los de los trabajos de referencia, no dispersión con recta 1:1:
  - `series_hs.png` (A): SPI-1 y SSMI 0-10 cm en el tiempo, por estación (Fig. 6 de Spennemann et al., 2015).
  - `correlacion_mensual_hs.png` (A): correlación por mes, promedio ± desvío entre estaciones, sin las
    de `EXCLUIR_GENERAL$hs` (como la Fig. 5 de Jung et al., 2020).
  - `sensibilidad_hs100.png` (B): correlación según la escala del SPI, por estación y para el conjunto
    de estaciones SMN (Fig. 2 de Spennemann et al., 2015).
- **Análisis regionales (A y B):** se apilan las estaciones, salvo las de `EXCLUIR_GENERAL$hs`.
  VM se informa solo por estación (como la ET en el paso 3): FLDAS trata su píxel como urbano y
  su humedad del perfil profundo no responde a la lluvia.

### Paso 5: isolíneas
#### 1. Conversión de archivos FLDAS a NetCDF
```bash
python python/tiff_a_cdf.py --variable pp
python python/tiff_a_cdf.py --variable et
python python/tiff_a_cdf.py --variable t
python python/tiff_a_cdf.py --variable ts
python python/tiff_a_cdf.py --variable ts_10_40
python python/tiff_a_cdf.py --variable ts_40_100
python python/tiff_a_cdf.py --variable ts_100_200
python python/tiff_a_cdf.py --variable hs_0_10
python python/tiff_a_cdf.py --variable hs_10_40
python python/tiff_a_cdf.py --variable hs_40_100
python python/tiff_a_cdf.py --variable hs_100_200
```

#### 2. Procesamiento con CDO
```bash
bash cdo/pp.sh
bash cdo/et.sh
bash cdo/t.sh
bash cdo/ts.sh
bash cdo/ts.sh ts_10_40
bash cdo/ts.sh ts_40_100
bash cdo/ts.sh ts_100_200
bash cdo/hs.sh hs_0_10
bash cdo/hs.sh hs_10_40
bash cdo/hs.sh hs_40_100
bash cdo/hs.sh hs_100_200
```

#### 3. Mapas con isolíneas
```bash
python python/isolineas.py --variable pp et t ts
python python/isolineas.py --variable ts_10_40 ts_40_100 ts_100_200
python python/isolineas.py --variable hs_0_10 hs_10_40 hs_40_100 hs_100_200
```
Salida en `output/mapas/isolineas/<variable>/`: un mapa por estación del año (misma escala
para las 4), la media anual y un mapa por año. Los límites de departamentos y provincias se
leen de `data/shp/departamento.shp` y `data/shp/provincia.shp` (si no están, los mapas se
hacen sin ellos).

## Referencias

Beguería, S., y Vicente-Serrano, S. M. (2017). *SPEI: Calculation of the Standardised Precipitation-Evapotranspiration Index* (Versión 1.7.2) [Paquete de R]. https://github.com/sbegueria/SPEI

Jung, H. C., Kang, D.-H., Kim, E., Getirana, A., Yoon, Y., Kumar, S., Peters-Lidard, C. D., y Hwang, E. (2020). Towards a soil moisture drought monitoring system for South Korea. *Journal of Hydrology*, *589*, 125176. https://doi.org/10.1016/j.jhydrol.2020.125176

McKee, T. B., Doesken, N. J., y Kleist, J. (1993). The relationship of drought frequency and duration to time scales. En *Proceedings of the 8th Conference on Applied Climatology* (pp. 179–184). American Meteorological Society.

Schulzweida, Uwe. (2023). CDO User Guide (2.3.0). Zenodo. https://doi.org/10.5281/zenodo.10020800

Spennemann, P. C., Rivera, J. A., Saulo, A. C., y Penalba, O. C. (2015). A comparison of GLDAS soil moisture anomalies against standardized precipitation index and multisatellite estimations over South America. *Journal of Hydrometeorology*, *16*(1), 158–171. https://doi.org/10.1175/JHM-D-13-0190.1

Zhao, K., et al. (2019). Detecting change-point, trend, and seasonality in
satellite time series data to track abrupt changes and nonlinear dynamics.
*Remote Sensing of Environment*, 232, 111300.
