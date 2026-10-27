#!/bin/bash
# Procesamiento CDO - Temperatura de suelo (SoilTemp*_tavg)
# Uso (correr desde la raíz del proyecto):
#   bash cdo/ts.sh              capa 0-10 cm (equivale a: bash cdo/ts.sh ts)
#   bash cdo/ts.sh ts_10_40
#   bash cdo/ts.sh ts_40_100
#   bash cdo/ts.sh ts_100_200
# Antes: python python/tiff_a_cdf.py --variable <capa>

CAPA=${1:-ts}

case $CAPA in
    ts)         NOMBRE="temperatura_suelo_0_10" ;;
    ts_10_40)   NOMBRE="temperatura_suelo_10_40" ;;
    ts_40_100)  NOMBRE="temperatura_suelo_40_100" ;;
    ts_100_200) NOMBRE="temperatura_suelo_100_200" ;;
    *) echo "Error: capa no válida ($CAPA). Opciones: ts, ts_10_40, ts_40_100, ts_100_200"; exit 1 ;;
esac

VAR="data/nc/$CAPA"

# 1. Renombrar coordenadas
cdo chname,x,lon,y,lat $VAR/$NOMBRE.nc $VAR/${CAPA}_coords.nc

# 2. Convertir unidades (Kelvin → °C)
cdo subc,273.15 $VAR/${CAPA}_coords.nc $VAR/${CAPA}_celsius.nc

# 3. Eliminar estaciones incompletas
cdo seldate,1982-03-01,2024-11-01 $VAR/${CAPA}_celsius.nc $VAR/${CAPA}_filtrado.nc

# 4. Media anual
cdo yearmean $VAR/${CAPA}_celsius.nc $VAR/${CAPA}_anual.nc

# 5. Media estacional por año
cdo seasmean $VAR/${CAPA}_filtrado.nc $VAR/${CAPA}_estacional.nc

# 6. Medias históricas por estación
cdo timmean -select,season=DJF $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_verano.nc
cdo timmean -select,season=MAM $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_otonio.nc
cdo timmean -select,season=JJA $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_invierno.nc
cdo timmean -select,season=SON $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_primavera.nc

# 7. Climatología mensual
cdo ymonmean $VAR/${CAPA}_celsius.nc $VAR/${CAPA}_mensual.nc

# Eliminar archivos intermedios
rm $VAR/${CAPA}_coords.nc $VAR/${CAPA}_filtrado.nc $VAR/${CAPA}_estacional.nc

echo "Listo. Archivos generados en $VAR"
