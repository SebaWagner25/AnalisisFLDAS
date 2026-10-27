# Análisis FLDAS - San Luis

Validación y análisis de datos del modelo **FLDAS Global** (Famine Early Warning Systems Network Land Data Assimilation System) para la provincia de San Luis, Argentina.

Se comparan datos de FLDAS con datos medidos en estaciones meteorológicas de campo (SMN, INTA y OMIXOM), se generan mapas descriptivos e isolíneas, y se aplica el algoritmo BEAST (Bayesian Estimator of Abrupt change, Seasonality, and Trend) para detectar cambios y tendencias.

**Variables analizadas:**
- Precipitación (PP)
- Evapotranspiración (ET)
- Temperatura del aire cerca de la superficie (T)
- Temperatura de suelo (TS): campo (estaciones OMIXOM) vs. temperatura de suelo 0-10 cm de FLDAS
- Temperatura de suelo (0-10, 10-40, 40-100 y 100-200 cm)
- Humedad de suelo 10-40, 40-100 y 100-200 cm (solo mapas, sin validación)

**Período FLDAS:** 1982-2024 (mensual)

## Requisitos

### R
```r
install.packages(c("terra", "tidyverse", "readxl", "robustbase", "openxlsx", "patchwork", "Rbeast"))
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
| `FLDAS_SoilMoi00_10cm_tavg_comp` | Humedad de suelo 0-10 cm |
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
| 4 | *(pendiente)* | Corrección de sesgo, si la validación indica que hace falta | |
| 5 | `scripts/05_mapas_descriptivos.R` + `python/` + `cdo/` | Mapas descriptivos e isolíneas | `output/mapas/`, `data/nc/` |
| 6 | `scripts/06_beast.R` | Tendencias y cambios abruptos con BEAST (probablemente pase a otro proyecto) | `output/beast/` |

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

Schulzweida, Uwe. (2023). CDO User Guide (2.3.0). Zenodo. https://doi.org/10.5281/zenodo.10020800

Zhao, K., et al. (2019). Detecting change-point, trend, and seasonality in
satellite time series data to track abrupt changes and nonlinear dynamics.
*Remote Sensing of Environment*, 232, 111300.
