#!/bin/bash
# Procesamiento CDO - Humedad de suelo
# Uso: bash cdo/hs.sh hs_0_10
#      bash cdo/hs.sh hs_10_40
#      bash cdo/hs.sh hs_40_100
#      bash cdo/hs.sh hs_100_200

CAPA=$1

if [ -z "$CAPA" ]; then
    echo "Error: indicar la capa. Ejemplo: bash cdo/hs.sh hs_0_10"
    exit 1
fi

VAR="data/nc/$CAPA"

# 1. Renombrar coordenadas
cdo chname,x,lon,y,lat $VAR/humedad_suelo_${CAPA#hs_}.nc $VAR/${CAPA}_coords.nc

# 2. Eliminar estaciones incompletas
cdo seldate,1982-03-01,2024-11-01 $VAR/${CAPA}_coords.nc $VAR/${CAPA}_filtrado.nc

# 3. Media anual
cdo yearmean $VAR/${CAPA}_coords.nc $VAR/${CAPA}_anual.nc

# 4. Media estacional por año
cdo seasmean $VAR/${CAPA}_filtrado.nc $VAR/${CAPA}_estacional.nc

# 5. Medias históricas por estación
cdo timmean -select,season=DJF $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_verano.nc
cdo timmean -select,season=MAM $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_otonio.nc
cdo timmean -select,season=JJA $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_invierno.nc
cdo timmean -select,season=SON $VAR/${CAPA}_estacional.nc $VAR/${CAPA}_primavera.nc

# Eliminar archivos intermedios
rm $VAR/${CAPA}_filtrado.nc $VAR/${CAPA}_estacional.nc

echo "Listo. Archivos generados en $VAR"