#!/bin/bash
# Procesamiento CDO - Evapotranspiración
# Uso: bash cdo/et.sh (correr desde la raíz del proyecto)

VAR="data/nc/et"

# 1. Renombrar coordenadas
cdo chname,x,lon,y,lat $VAR/evapotranspiracion.nc $VAR/et_coords.nc

# 2. Convertir unidades (kg/m²/s → mm/mes)
cdo mulc,86400 -muldpm $VAR/et_coords.nc $VAR/et_mm.nc

# 3. Eliminar estaciones incompletas
cdo seldate,1982-03-01,2024-11-30 $VAR/et_mm.nc $VAR/et_filtrado.nc

# 4. Media anual
cdo yearmean $VAR/et_filtrado.nc $VAR/et_anual.nc

# 5. Media estacional por año
cdo seasmean $VAR/et_filtrado.nc $VAR/et_estacional.nc

# 6. Medias históricas por estación
cdo timmean -select,season=DJF $VAR/et_estacional.nc $VAR/et_verano.nc
cdo timmean -select,season=MAM $VAR/et_estacional.nc $VAR/et_otonio.nc
cdo timmean -select,season=JJA $VAR/et_estacional.nc $VAR/et_invierno.nc
cdo timmean -select,season=SON $VAR/et_estacional.nc $VAR/et_primavera.nc

echo "Listo. Archivos generados en $VAR"