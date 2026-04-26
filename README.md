# Análisis FLDAS - San Luis

Validación y análisis de datos del modelo hidrológico **FLDAS** (Famine Early 
Warning Systems Network Land Data Assimilation System) para la provincia de 
San Luis, Argentina.

## Descripción

Este proyecto compara datos satelitales de FLDAS contra datos medidos en 
estaciones meteorológicas de campo, y aplica el algoritmo BEAST (Bayesian 
Estimator of Abrupt change, Seasonality, and Trend) para detectar cambios 
y tendencias en series temporales de variables hidrometeorológicas.

**Variables analizadas:**
- Precipitación (PP)
- Evapotranspiración (ET)
- Humedad de suelo (0-10, 10-40, 40-100 y 100-200 cm)

**Período:** 1982-2024  
**Área de estudio:** Provincia de San Luis, Argentina

## Estructura del proyecto
├── R/                    # Funciones de carga y procesamiento
│   ├── importData.R      # Carga archivos .tif y convierte a matriz
│   ├── datosPixel.R      # Extrae píxel más cercano a una coordenada
│   ├── convertirUnidades.R # Conversión de unidades por variable
│   ├── datosCampo_CSV.R  # Carga datos de campo INTA/SMN (CSV)
│   ├── datosOMIXOM.R     # Carga datos de campo OMIXOM (Excel)
│   └── applyBEAST.R      # Aplica BEAST a una serie temporal
├── scripts/              # Scripts de análisis (correr en orden)
│   ├── 01_descriptivo.R  # Estadísticas descriptivas
│   ├── 02_validacion.R   # Validación FLDAS vs campo
│   ├── 03_beast.R        # Detección de cambios con BEAST
│   └── 04_correlaciones.R # Correlaciones entre variables
├── cdo/                  # Scripts de procesamiento con CDO
│   ├── pp.sh             # Procesamiento precipitación
│   ├── et.sh             # Procesamiento evapotranspiración
│   └── hs.sh             # Procesamiento humedad de suelo
├── python/               # Conversión de archivos
│   └── tiff_a_cdf.py     # Convierte .tif a NetCDF
├── data/                 # Datos (no incluidos en el repositorio)
├── output/               # Resultados generados (no incluidos)
└── estaciones.csv        # Metadatos de estaciones de campo
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

## Datos necesarios

Los datos no están incluidos en el repositorio por su tamaño. Se necesitan:

- Archivos `.tif` de FLDAS descargados desde 
  [NASA GES DISC](https://disc.gsfc.nasa.gov/), organizados en carpetas 
  por variable dentro de `data/`
- Datos de campo de las estaciones listadas en `estaciones.csv`

Las carpetas de datos esperadas dentro de `data/` son:

| Carpeta | Variable |
|---------|----------|
| `FLDAS_Rainf_f_tavg_comp` | Precipitación |
| `FLDAS_Evap_tavg_comp` | Evapotranspiración |
| `FLDAS_SoilMoi00_10cm_tavg_comp` | Humedad de suelo 0-10 cm |
| `FLDAS_SoilMoi10_40cm_tavg_comp` | Humedad de suelo 10-40 cm |
| `FLDAS_SoilMoi40_100cm_tavg_comp` | Humedad de suelo 40-100 cm |
| `FLDAS_SoilMoi100_200cm_tavg_comp` | Humedad de suelo 100-200 cm |

## Orden de ejecución

### 1. Conversión de archivos FLDAS a NetCDF
```bash
python python/tiff_a_cdf.py --variable pp
python python/tiff_a_cdf.py --variable et
python python/tiff_a_cdf.py --variable hs_0_10
python python/tiff_a_cdf.py --variable hs_10_40
python python/tiff_a_cdf.py --variable hs_40_100
python python/tiff_a_cdf.py --variable hs_100_200
```

### 2. Procesamiento con CDO
```bash
bash cdo/pp.sh
bash cdo/et.sh
bash cdo/hs.sh hs_0_10
bash cdo/hs.sh hs_10_40
bash cdo/hs.sh hs_40_100
bash cdo/hs.sh hs_100_200
```

### 3. Análisis en R
Abrir `00_ANALISIS.Rproj` en RStudio y correr los scripts en orden 
desde la raíz del proyecto:

| Script | Descripción | Output |
|--------|-------------|--------|
| `scripts/01_descriptivo.R` | Estadísticas descriptivas por píxel | Rasters en `output/descriptivo/` |
| `scripts/02_validacion.R` | Validación FLDAS vs campo | Gráficos y tabla en `output/validacion/` |
| `scripts/03_beast.R` | Detección de cambios con BEAST | Rasters y gráficos en `output/beast/` |
| `scripts/04_correlaciones.R` | Correlaciones entre variables | Tablas en `output/correlaciones/` |

## Estaciones de campo

Las estaciones utilizadas se listan en `estaciones.csv`. Los proveedores son:

- **INTA** — Instituto Nacional de Tecnología Agropecuaria
- **SMN** — Servicio Meteorológico Nacional  
- **OMIXOM** — Observatorio Meteorológico Integrado de Cuyo y Oeste Medio

## Referencia algoritmo BEAST

Zhao, K., et al. (2019). Detecting change-point, trend, and seasonality in 
satellite time series data to track abrupt changes and nonlinear dynamics. 
*Remote Sensing of Environment*, 232, 111300.