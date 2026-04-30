# Análisis FLDAS - San Luis

Validación y análisis de datos del modelo **FLDAS Global** (Famine Early Warning Systems Network Land Data Assimilation System) para la provincia de San Luis, Argentina.

Se comparan datos de FLDAS con datos medidos en estaciones meteorológicas de campo y se aplica el algoritmo BEAST (Bayesian 
Estimator of Abrupt change, Seasonality, and Trend) para detectar cambios y tendencias en series temporales de variables hidrometeorológicas.

**Variables analizadas:**
- Precipitación (PP)
- Evapotranspiración (ET)
- Temperatura del aire cerca de la superficie (T)
- Humedad de suelo (0-10, 10-40, 40-100 y 100-200 cm)

**Período:** 1982-2024  

## Requisitos

### R
```r
install.packages(c("terra", "tidyverse", "readxl", "robustbase",
                   "lmtest", "Rbeast", "parallel"))
```

### Python
```bash
pip install xarray rioxarray pandas numpy netcdf4
```

### Software externo
- **CDO** (Climate Data Operators) — procesamiento de archivos NetCDF
- **GrADS** (opcional) — visualización de archivos NetCDF

## Datos usados

- Archivos `.tif` de FLDAS organizados en carpetas por variable dentro de `data/`

| Carpeta | Variable |
|---------|----------|
| `FLDAS_Rainf_f_tavg_comp` | Precipitación |
| `FLDAS_Evap_tavg_comp` | Evapotranspiración |
| `FLDAS_Tair_f_tavg_comp` | Temperatura del aire cerca de la superficie |
| `FLDAS_SoilMoi00_10cm_tavg_comp` | Humedad de suelo 0-10 cm |
| `FLDAS_SoilMoi10_40cm_tavg_comp` | Humedad de suelo 10-40 cm |
| `FLDAS_SoilMoi40_100cm_tavg_comp` | Humedad de suelo 40-100 cm |
| `FLDAS_SoilMoi100_200cm_tavg_comp` | Humedad de suelo 100-200 cm |

- Datos de campo de las estaciones listadas en `estaciones.csv`

## Uso

### Generación de isolíneas 
#### 1. Conversión de archivos FLDAS a NetCDF
```bash
python python/tiff_a_cdf.py --variable pp
python python/tiff_a_cdf.py --variable et
python python/tiff_a_cdf.py --variable t
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
bash cdo/hs.sh hs_0_10
bash cdo/hs.sh hs_10_40
bash cdo/hs.sh hs_40_100
bash cdo/hs.sh hs_100_200
```

#### 3. Gráficos en python
```py
python python/graficos.py
```

### Análisis
Abrir `00_ANALISIS.Rproj` en RStudio y correr los scripts en orden 
desde la raíz del proyecto:

| Script | Descripción | Output |
|--------|-------------|--------|
| `scripts/01_descriptivo.R` | Estadísticas descriptivas por píxel | Rasters en `output/descriptivo/` |
| `scripts/02_validacion.R` | Validación FLDAS vs campo | Gráficos y tabla en `output/validacion/` |
| `scripts/03_beast.R` | Detección de cambios con BEAST | Rasters y gráficos en `output/beast/` |
| `scripts/04_correlaciones.R` | Correlaciones entre variables | Tablas en `output/correlaciones/` |

## Referencias

Schulzweida, Uwe. (2023). CDO User Guide (2.3.0). Zenodo. https://doi.org/10.5281/zenodo.10020800

Zhao, K., et al. (2019). Detecting change-point, trend, and seasonality in 
satellite time series data to track abrupt changes and nonlinear dynamics. 
*Remote Sensing of Environment*, 232, 111300.
